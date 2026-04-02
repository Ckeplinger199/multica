import Foundation

struct TaskMessage: Codable, Identifiable, Sendable {
    let taskId: String
    let issueId: String?
    let seq: Int
    let type: MessageType
    let tool: String?
    let content: String?
    let input: [String: AnyCodable]?
    let output: String?

    var id: String { "\(taskId)-\(seq)" }

    enum CodingKeys: String, CodingKey {
        case seq, type, tool, content, input, output
        case taskId = "task_id"
        case issueId = "issue_id"
    }
}

enum MessageType: String, Codable, Sendable {
    case text
    case thinking
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case error
}

// Simple wrapper for heterogeneous JSON values
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}
