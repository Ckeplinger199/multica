import Foundation

struct AgentTask: Codable, Identifiable, Sendable {
    let id: String
    let agentId: String
    let runtimeId: String?
    let issueId: String
    let status: TaskStatus
    let priority: Int?
    let dispatchedAt: String?
    let startedAt: String?
    let completedAt: String?
    let error: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, priority, error
        case agentId = "agent_id"
        case runtimeId = "runtime_id"
        case issueId = "issue_id"
        case dispatchedAt = "dispatched_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }
}

enum TaskStatus: String, Codable, Sendable {
    case queued
    case dispatched
    case running
    case completed
    case failed
    case cancelled

    var label: String {
        switch self {
        case .queued: "Queued"
        case .dispatched: "Dispatched"
        case .running: "Running"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .queued: "clock"
        case .dispatched: "arrow.right.circle"
        case .running: "play.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "minus.circle.fill"
        }
    }

    var isActive: Bool {
        self == .queued || self == .dispatched || self == .running
    }
}
