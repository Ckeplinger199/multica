import SwiftUI

struct TaskRunsView: View {
    @Bindable var viewModel: IssueDetailViewModel

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if viewModel.taskRuns.isEmpty && !viewModel.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No agent runs yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Assign this issue to an agent to trigger execution.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }

            // Active task with live logs
            if let activeTask = viewModel.activeTask, activeTask.status.isActive {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Running")
                            .font(.subheadline.bold())
                            .foregroundStyle(.purple)
                        Spacer()
                        Text("Started \(relativeDate(activeTask.startedAt ?? activeTask.createdAt))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    TaskMessagesView(messages: viewModel.taskMessages, isLive: true)
                }
                .background(.purple.opacity(0.03))

                Divider()
            }

            // Historical runs
            ForEach(viewModel.taskRuns.filter { t in
                viewModel.activeTask.map { $0.id != t.id } ?? true
            }) { task in
                NavigationLink {
                    TaskRunDetailView(task: task)
                } label: {
                    TaskRunRow(task: task)
                }
                Divider().padding(.leading)
            }
        }
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

struct TaskRunRow: View {
    let task: AgentTask

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.status.iconName)
                .foregroundStyle(taskColor)
                .font(.body)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(task.status.label)
                        .font(.subheadline.weight(.medium))
                    if let error = task.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 12) {
                    Text(formatDate(task.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let started = task.startedAt, let completed = task.completedAt {
                        Text(duration(from: started, to: completed))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var taskColor: Color {
        switch task.status {
        case .completed: .green
        case .failed: .red
        case .running: .purple
        case .cancelled: .gray
        default: .secondary
        }
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return iso }
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func duration(from start: String, to end: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let s = formatter.date(from: start) ?? ISO8601DateFormatter().date(from: start),
              let e = formatter.date(from: end) ?? ISO8601DateFormatter().date(from: end) else { return "" }
        let interval = e.timeIntervalSince(s)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m \(Int(interval.truncatingRemainder(dividingBy: 60)))s" }
        return "\(Int(interval / 3600))h \(Int((interval.truncatingRemainder(dividingBy: 3600)) / 60))m"
    }
}

struct TaskRunDetailView: View {
    let task: AgentTask
    @State private var messages: [TaskMessage] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Task info header
                HStack {
                    Image(systemName: task.status.iconName)
                        .foregroundStyle(taskColor)
                    Text(task.status.label)
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)

                if let error = task.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Divider()

                if isLoading {
                    ProgressView("Loading execution log...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    TaskMessagesView(messages: messages, isLive: false)
                }
            }
            .padding(.top)
        }
        .navigationTitle("Run Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                messages = try await APIClient.shared.listTaskMessages(taskId: task.id)
            } catch {
                // silently fail
            }
            isLoading = false
        }
    }

    private var taskColor: Color {
        switch task.status {
        case .completed: .green
        case .failed: .red
        case .running: .purple
        case .cancelled: .gray
        default: .secondary
        }
    }
}
