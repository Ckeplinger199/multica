import SwiftUI

struct CommentListView: View {
    @Bindable var viewModel: IssueDetailViewModel
    @State private var newComment = ""
    @State private var isSending = false

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if viewModel.comments.isEmpty && !viewModel.isLoading {
                Text("No comments yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }

            ForEach(viewModel.comments) { comment in
                CommentRowView(comment: comment)
                if comment.id != viewModel.comments.last?.id {
                    Divider().padding(.leading, 48)
                }
            }

            // New comment input
            VStack(spacing: 8) {
                Divider()
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Add a comment...", text: $newComment, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)

                    Button {
                        Task { await sendComment() }
                    } label: {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    private func sendComment() async {
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        await viewModel.addComment(text)
        newComment = ""
        isSending = false
    }
}

struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AssigneeAvatar(
                type: comment.authorType,
                name: comment.authorName ?? "?",
                size: 28
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.authorName ?? (comment.isFromAgent ? "Agent" : "User"))
                        .font(.subheadline.bold())
                    if comment.isFromAgent {
                        Text("BOT")
                            .font(.caption2.bold())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Spacer()
                    Text(relativeDate(comment.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(comment.content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func relativeDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString) else {
            return ""
        }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
