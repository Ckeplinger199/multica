import Foundation

struct User: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String
    let avatarURL: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AuthResponse: Codable, Sendable {
    let token: String
    let user: User
}
