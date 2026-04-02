import Foundation

@MainActor
@Observable
final class IssueDetailViewModel {
    var issue: Issue
    var comments: [Comment] = []
    var taskRuns: [AgentTask] = []
    var activeTask: AgentTask?
    var taskMessages: [TaskMessage] = []
    var isLoading = false
    var error: String?

    init(issue: Issue) {
        self.issue = issue
    }

    func loadAll() async {
        isLoading = true
        do {
            async let commentsResult = APIClient.shared.listComments(issueId: issue.id)
            async let taskRunsResult = APIClient.shared.listTaskRuns(issueId: issue.id)
            async let activeTaskResult = APIClient.shared.getActiveTask(issueId: issue.id)

            comments = try await commentsResult
            taskRuns = try await taskRunsResult
            activeTask = try await activeTaskResult

            // Load messages for active task
            if let task = activeTask {
                taskMessages = try await APIClient.shared.listTaskMessages(taskId: task.id)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func updateStatus(_ status: IssueStatus) async {
        do {
            let updated = try await APIClient.shared.updateIssue(issue.id, UpdateIssueRequest(status: status.rawValue))
            issue = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updatePriority(_ priority: IssuePriority) async {
        do {
            let updated = try await APIClient.shared.updateIssue(issue.id, UpdateIssueRequest(priority: priority.rawValue))
            issue = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateAssignee(type: String?, id: String?) async {
        do {
            let updated = try await APIClient.shared.updateIssue(issue.id, UpdateIssueRequest(
                assigneeType: type ?? "",
                assigneeId: id ?? ""
            ))
            issue = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateTitle(_ title: String) async {
        do {
            let updated = try await APIClient.shared.updateIssue(issue.id, UpdateIssueRequest(title: title))
            issue = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addComment(_ content: String) async {
        do {
            let comment = try await APIClient.shared.createComment(issueId: issue.id, content: content)
            comments.append(comment)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadTaskMessages(taskId: String) async {
        do {
            taskMessages = try await APIClient.shared.listTaskMessages(taskId: taskId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setupRealtimeUpdates() {
        let issueId = issue.id
        WebSocketClient.shared.on("task:message") { [weak self] event in
            Task { @MainActor in
                guard let self,
                      let payload = event.payload["issue_id"] as? String,
                      payload == issueId else { return }
                // Reload messages for active task
                if let task = self.activeTask {
                    await self.loadTaskMessages(taskId: task.id)
                }
            }
        }

        WebSocketClient.shared.onPrefix("task") { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                await self.loadAll()
            }
        }

        WebSocketClient.shared.onPrefix("comment") { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                self.comments = (try? await APIClient.shared.listComments(issueId: issueId)) ?? self.comments
            }
        }

        WebSocketClient.shared.on("issue:updated") { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if let updated = try? await APIClient.shared.getIssue(issueId) {
                    self.issue = updated
                }
            }
        }
    }
}
