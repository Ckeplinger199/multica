import Foundation

@MainActor
@Observable
final class WorkspaceViewModel {
    var workspaces: [Workspace] = []
    var selectedWorkspace: Workspace?
    var members: [Member] = []
    var agents: [Agent] = []
    var isLoading = false
    var error: String?

    var hasSelectedWorkspace: Bool {
        selectedWorkspace != nil
    }

    func loadWorkspaces() async {
        isLoading = true
        error = nil
        do {
            workspaces = try await APIClient.shared.listWorkspaces()
            // Auto-select if there's a saved workspace or only one
            if let savedId = APIClient.shared.workspaceId,
               let saved = workspaces.first(where: { $0.id == savedId }) {
                await selectWorkspace(saved)
            } else if workspaces.count == 1 {
                await selectWorkspace(workspaces[0])
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func selectWorkspace(_ workspace: Workspace) async {
        selectedWorkspace = workspace
        APIClient.shared.workspaceId = workspace.id
        WebSocketClient.shared.disconnect()
        WebSocketClient.shared.connect()
        await loadWorkspaceData()
    }

    func loadWorkspaceData() async {
        guard let workspace = selectedWorkspace else { return }
        do {
            async let membersResult = APIClient.shared.listMembers(workspaceId: workspace.id)
            async let agentsResult = APIClient.shared.listAgents()
            members = try await membersResult
            agents = try await agentsResult
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// All possible assignees (members + agents)
    var assignees: [Assignee] {
        let memberAssignees = members.map { Assignee.member($0) }
        let agentAssignees = agents.map { Assignee.agent($0) }
        return memberAssignees + agentAssignees
    }

    func assigneeName(type: String?, id: String?) -> String {
        guard let type, let id else { return "Unassigned" }
        if type == "agent" {
            return agents.first(where: { $0.id == id })?.name ?? "Agent"
        } else {
            return members.first(where: { $0.userId == id })?.displayName ?? "Member"
        }
    }
}
