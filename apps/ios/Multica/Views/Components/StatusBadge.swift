import SwiftUI

struct StatusBadge: View {
    let status: IssueStatus

    var body: some View {
        Label(status.label, systemImage: status.iconName)
            .font(.caption)
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .backlog: .gray
        case .todo: .primary
        case .inProgress: .yellow
        case .inReview: .blue
        case .done: .green
        case .blocked: .red
        case .cancelled: .gray
        }
    }
}

struct StatusIcon: View {
    let status: IssueStatus
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: status.iconName)
            .font(.system(size: size))
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .backlog: .gray
        case .todo: .primary
        case .inProgress: .yellow
        case .inReview: .blue
        case .done: .green
        case .blocked: .red
        case .cancelled: .gray
        }
    }
}
