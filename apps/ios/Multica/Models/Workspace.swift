import Foundation

struct Workspace: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let issuePrefix: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case issuePrefix = "issue_prefix"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkspaceRepo: Codable, Sendable {
    let url: String
    let description: String?
}
