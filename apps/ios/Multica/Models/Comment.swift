import Foundation

struct Comment: Codable, Identifiable, Sendable {
    let id: String
    let issueId: String
    let authorType: String
    let authorId: String
    let content: String
    let type: String
    let parentId: String?
    let attachments: [Attachment]?
    let createdAt: String
    let updatedAt: String

    // Joined fields from server
    let authorName: String?
    let authorAvatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, content, type, attachments
        case issueId = "issue_id"
        case authorType = "author_type"
        case authorId = "author_id"
        case parentId = "parent_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorName = "author_name"
        case authorAvatarURL = "author_avatar_url"
    }

    var isFromAgent: Bool {
        authorType == "agent"
    }
}

struct Attachment: Codable, Identifiable, Sendable {
    let id: String
    let filename: String
    let contentType: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id, filename, url
        case contentType = "content_type"
    }
}
