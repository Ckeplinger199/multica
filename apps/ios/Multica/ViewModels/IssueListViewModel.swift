import Foundation

@MainActor
@Observable
final class IssueListViewModel {
    var issues: [Issue] = []
    var isLoading = false
    var error: String?
    var statusFilter: IssueStatus?
    var searchText = ""

    var filteredIssues: [Issue] {
        var result = issues
        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.identifier.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    // Group issues by status for sectioned display
    var issuesByStatus: [(IssueStatus, [Issue])] {
        let grouped = Dictionary(grouping: filteredIssues, by: \.status)
        let order: [IssueStatus] = [.inProgress, .todo, .inReview, .blocked, .backlog, .done, .cancelled]
        return order.compactMap { status in
            guard let issues = grouped[status], !issues.isEmpty else { return nil }
            return (status, issues)
        }
    }

    func loadIssues() async {
        isLoading = true
        error = nil
        do {
            issues = try await APIClient.shared.listIssues()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        do {
            issues = try await APIClient.shared.listIssues()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteIssue(_ issue: Issue) async {
        do {
            try await APIClient.shared.deleteIssue(issue.id)
            issues.removeAll { $0.id == issue.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
