import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .unauthorized: "Session expired. Please log in again."
        case .serverError(let msg): msg
        case .networkError(let err): err.localizedDescription
        case .decodingError(let err): "Failed to parse response: \(err.localizedDescription)"
        }
    }
}

@MainActor
final class APIClient: Sendable {
    static let shared = APIClient()

    // Configure these for your server
    #if DEBUG
    let baseURL = "http://localhost:8080"
    #else
    let baseURL = "https://api.multica.ai"
    #endif

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    var token: String? {
        get { KeychainHelper.read(key: "auth_token") }
        set {
            if let newValue {
                KeychainHelper.save(key: "auth_token", value: newValue)
            } else {
                KeychainHelper.delete(key: "auth_token")
            }
        }
    }

    var workspaceId: String? {
        get { UserDefaults.standard.string(forKey: "workspace_id") }
        set { UserDefaults.standard.set(newValue, forKey: "workspace_id") }
    }

    // MARK: - Auth

    func sendCode(email: String) async throws {
        let body = ["email": email]
        let _: EmptyResponse = try await post("/auth/send-code", body: body, authenticated: false)
    }

    func verifyCode(email: String, code: String) async throws -> AuthResponse {
        let body = ["email": email, "code": code]
        return try await post("/auth/verify-code", body: body, authenticated: false)
    }

    // MARK: - Workspaces

    func listWorkspaces() async throws -> [Workspace] {
        try await get("/api/workspaces")
    }

    func getWorkspace(_ id: String) async throws -> Workspace {
        try await get("/api/workspaces/\(id)")
    }

    // MARK: - Issues

    func listIssues(
        status: String? = nil,
        priority: String? = nil,
        assigneeId: String? = nil,
        limit: Int = 200,
        offset: Int = 0
    ) async throws -> [Issue] {
        var params: [(String, String)] = [
            ("limit", "\(limit)"),
            ("offset", "\(offset)"),
        ]
        if let status { params.append(("status", status)) }
        if let priority { params.append(("priority", priority)) }
        if let assigneeId { params.append(("assignee_id", assigneeId)) }
        return try await get("/api/issues", queryItems: params)
    }

    func getIssue(_ id: String) async throws -> Issue {
        try await get("/api/issues/\(id)")
    }

    func createIssue(_ req: CreateIssueRequest) async throws -> Issue {
        try await post("/api/issues", body: req)
    }

    func updateIssue(_ id: String, _ req: UpdateIssueRequest) async throws -> Issue {
        try await put("/api/issues/\(id)", body: req)
    }

    func deleteIssue(_ id: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "/api/issues/\(id)")
    }

    // MARK: - Comments

    func listComments(issueId: String) async throws -> [Comment] {
        try await get("/api/issues/\(issueId)/comments")
    }

    func createComment(issueId: String, content: String, parentId: String? = nil) async throws -> Comment {
        var body: [String: String] = ["content": content]
        if let parentId { body["parent_id"] = parentId }
        return try await post("/api/issues/\(issueId)/comments", body: body)
    }

    // MARK: - Members & Agents

    func listMembers(workspaceId: String) async throws -> [Member] {
        try await get("/api/workspaces/\(workspaceId)/members")
    }

    func listAgents() async throws -> [Agent] {
        try await get("/api/agents")
    }

    // MARK: - Tasks

    func getActiveTask(issueId: String) async throws -> AgentTask? {
        do {
            return try await get("/api/issues/\(issueId)/active-task")
        } catch APIError.serverError {
            return nil
        }
    }

    func listTaskRuns(issueId: String) async throws -> [AgentTask] {
        try await get("/api/issues/\(issueId)/task-runs")
    }

    func listTaskMessages(taskId: String) async throws -> [TaskMessage] {
        try await get("/api/tasks/\(taskId)/messages")
    }

    func cancelTask(issueId: String, taskId: String) async throws {
        let _: EmptyResponse = try await post("/api/issues/\(issueId)/tasks/\(taskId)/cancel", body: EmptyBody())
    }

    // MARK: - Timeline

    func listTimeline(issueId: String) async throws -> [TimelineEntry] {
        try await get("/api/issues/\(issueId)/timeline")
    }

    // MARK: - Networking Helpers

    private func get<T: Decodable>(_ path: String, queryItems: [(String, String)] = []) async throws -> T {
        try await request("GET", path: path, queryItems: queryItems)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B, authenticated: Bool = true) async throws -> T {
        try await request("POST", path: path, body: body, authenticated: authenticated)
    }

    private func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await request("PUT", path: path, body: body)
    }

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        queryItems: [(String, String)] = [],
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if authenticated {
            guard let token else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let workspaceId, authenticated {
            request.setValue(workspaceId, forHTTPHeaderField: "X-Workspace-ID")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) : (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            if let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorBody.error)
            }
            throw APIError.serverError("Server error (\(httpResponse.statusCode))")
        }

        // Handle empty responses
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

struct EmptyResponse: Decodable {}
struct EmptyBody: Encodable {}
struct ErrorResponse: Decodable {
    let error: String
}

struct TimelineEntry: Codable, Identifiable, Sendable {
    let id: String
    let issueId: String?
    let actorType: String?
    let actorId: String?
    let action: String?
    let field: String?
    let oldValue: String?
    let newValue: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, action, field
        case issueId = "issue_id"
        case actorType = "actor_type"
        case actorId = "actor_id"
        case oldValue = "old_value"
        case newValue = "new_value"
        case createdAt = "created_at"
    }
}
