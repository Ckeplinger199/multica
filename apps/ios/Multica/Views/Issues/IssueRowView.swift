import SwiftUI

struct IssueRowView: View {
    let issue: Issue
    let assigneeName: String

    var body: some View {
        HStack(spacing: 10) {
            StatusIcon(status: issue.status)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(issue.identifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    PriorityIcon(priority: issue.priority, size: 10)
                }

                Text(issue.title)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            Spacer()

            if issue.assigneeId != nil {
                AssigneeAvatar(
                    type: issue.assigneeType,
                    name: assigneeName,
                    size: 24
                )
            }
        }
        .padding(.vertical, 2)
    }
}
