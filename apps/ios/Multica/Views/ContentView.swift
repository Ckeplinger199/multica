import SwiftUI

struct ContentView: View {
    @State private var authVM = AuthViewModel()
    @State private var workspaceVM = WorkspaceViewModel()
    @State private var issueListVM = IssueListViewModel()

    var body: some View {
        Group {
            if !authVM.isAuthenticated {
                LoginView(viewModel: authVM)
            } else if !workspaceVM.hasSelectedWorkspace {
                WorkspacePickerView(viewModel: workspaceVM)
            } else {
                IssueListView(viewModel: issueListVM, workspaceVM: workspaceVM)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .logout)) { _ in
            authVM.logout()
            workspaceVM.selectedWorkspace = nil
            issueListVM.issues = []
        }
        .onChange(of: workspaceVM.hasSelectedWorkspace) { _, hasWorkspace in
            if hasWorkspace {
                Task { await issueListVM.loadIssues() }
                setupRealtimeSync()
            }
        }
    }

    private func setupRealtimeSync() {
        WebSocketClient.shared.onPrefix("issue") { _ in
            Task { @MainActor in
                await issueListVM.refresh()
            }
        }
    }
}
