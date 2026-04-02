import Foundation

enum IssueStatus: String, Codable, CaseIterable, Sendable {
    case backlog
    case todo
    case inProgress = "in_progress"
    case inReview = "in_review"
    case done
    case blocked
    case cancelled

    var label: String {
        switch self {
        case .backlog: "Backlog"
        case .todo: "Todo"
        case .inProgress: "In Progress"
        case .inReview: "In Review"
        case .done: "Done"
        case .blocked: "Blocked"
        case .cancelled: "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .backlog: "circle.dashed"
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .inReview: "eye.circle"
        case .done: "checkmark.circle.fill"
        case .blocked: "xmark.circle"
        case .cancelled: "minus.circle"
        }
    }

    var color: String {
        switch self {
        case .backlog: "gray"
        case .todo: "gray"
        case .inProgress: "yellow"
        case .inReview: "blue"
        case .done: "green"
        case .blocked: "red"
        case .cancelled: "gray"
        }
    }
}

enum IssuePriority: String, Codable, CaseIterable, Sendable {
    case urgent
    case high
    case medium
    case low
    case none

    var label: String {
        switch self {
        case .urgent: "Urgent"
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .none: "None"
        }
    }

    var iconName: String {
        switch self {
        case .urgent: "exclamationmark.3"
        case .high: "exclamationmark.2"
        case .medium: "exclamationmark"
        case .low: "minus"
        case .none: "minus"
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgent: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        case .none: 4
        }
    }
}

struct Issue: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let workspaceId: String
    let number: Int
    let identifier: String
    let title: String
    let description: String?
    let status: IssueStatus
    let priority: IssuePriority
    let assigneeType: String?
    let assigneeId: String?
    let creatorType: String
    let creatorId: String
    let parentIssueId: String?
    let position: Int
    let dueDate: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, number, identifier, title, description, status, priority, position
        case workspaceId = "workspace_id"
        case assigneeType = "assignee_type"
        case assigneeId = "assignee_id"
        case creatorType = "creator_type"
        case creatorId = "creator_id"
        case parentIssueId = "parent_issue_id"
        case dueDate = "due_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isAssignedToAgent: Bool {
        assigneeType == "agent"
    }
}

struct CreateIssueRequest: Codable, Sendable {
    let title: String
    let description: String?
    let status: String?
    let priority: String?
    let assigneeType: String?
    let assigneeId: String?

    enum CodingKeys: String, CodingKey {
        case title, description, status, priority
        case assigneeType = "assignee_type"
        case assigneeId = "assignee_id"
    }
}

struct UpdateIssueRequest: Codable, Sendable {
    var title: String?
    var description: String?
    var status: String?
    var priority: String?
    var assigneeType: String?
    var assigneeId: String?

    enum CodingKeys: String, CodingKey {
        case title, description, status, priority
        case assigneeType = "assignee_type"
        case assigneeId = "assignee_id"
    }
}
