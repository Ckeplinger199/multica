import SwiftUI

struct TaskMessagesView: View {
    let messages: [TaskMessage]
    let isLive: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            if messages.isEmpty {
                Text("No log messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }

            ForEach(messages) { message in
                TaskMessageRow(message: message)
            }

            if isLive && !messages.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Streaming...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }
}

struct TaskMessageRow: View {
    let message: TaskMessage
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch message.type {
            case .text:
                textMessage

            case .thinking:
                thinkingMessage

            case .toolUse:
                toolUseMessage

            case .toolResult:
                toolResultMessage

            case .error:
                errorMessage
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private var textMessage: some View {
        Text(message.content ?? "")
            .font(.caption.monospaced())
            .foregroundStyle(.primary)
    }

    private var thinkingMessage: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "brain")
                    .font(.caption2)
                Text("Thinking")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.purple.opacity(0.7))

            if let content = message.content, !content.isEmpty {
                Text(content)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 3)
                    .onTapGesture { isExpanded.toggle() }
            }
        }
    }

    private var toolUseMessage: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "wrench")
                    .font(.caption2)
                Text(message.tool ?? "Tool")
                    .font(.caption2.weight(.semibold).monospaced())
            }
            .foregroundStyle(.blue)

            if let content = message.content, !content.isEmpty {
                Text(content)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .onTapGesture { isExpanded.toggle() }
            }
        }
    }

    private var toolResultMessage: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.turn.down.left")
                    .font(.caption2)
                Text(message.tool ?? "Result")
                    .font(.caption2.weight(.medium).monospaced())
            }
            .foregroundStyle(.green)

            if let output = message.output, !output.isEmpty {
                Text(output)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 3)
                    .onTapGesture { isExpanded.toggle() }
            }
        }
    }

    private var errorMessage: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption2)
            Text(message.content ?? "Error")
                .font(.caption2.monospaced())
        }
        .foregroundStyle(.red)
    }
}
