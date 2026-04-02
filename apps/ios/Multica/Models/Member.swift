import Foundation

struct Member: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let workspaceId: String
    let role: String
    let user: User?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, role, user
        case userId = "user_id"
        case workspaceId = "workspace_id"
        case createdAt = "created_at"
    }

    var displayName: String {
        user?.name ?? "Unknown"
    }
}

/// Unified type for displaying assignees (either member or agent)
enum Assignee: Identifiable, Hashable, Sendable {
    case member(Member)
    case agent(Agent)

    var id: String {
        switch self {
        case .member(let m): m.id
        case .agent(let a): a.id
        }
    }

    var name: String {
        switch self {
        case .member(let m): m.displayName
        case .agent(let a): a.name
        }
    }

    var typeName: String {
        switch self {
        case .member: "member"
        case .agent: "agent"
        }
    }

    var entityId: String {
        switch self {
        case .member(let m): m.userId
        case .agent(let a): a.id
        }
    }
}
