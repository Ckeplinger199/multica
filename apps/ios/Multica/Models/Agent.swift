import Foundation

struct Agent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let workspaceId: String
    let name: String
    let description: String
    let instructions: String?
    let avatarURL: String?
    let status: AgentStatus
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description, instructions, status
        case workspaceId = "workspace_id"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum AgentStatus: String, Codable, Sendable {
    case idle
    case working
    case blocked
    case error
    case offline
}
