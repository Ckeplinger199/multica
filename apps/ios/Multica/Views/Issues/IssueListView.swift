import SwiftUI

struct IssueListView: View {
    @Bindable var viewModel: IssueListViewModel
    @Bindable var workspaceVM: WorkspaceViewModel
    @State private var showCreateIssue = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.issues.isEmpty {
                    ProgressView("Loading issues...")
                } else if viewModel.filteredIssues.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    issueList
                }
            }
            .navigationTitle(workspaceVM.selectedWorkspace?.name ?? "Issues")
            .searchable(text: $viewModel.searchText, prompt: "Search issues...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateIssue = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All") { viewModel.statusFilter = nil }
                        Divider()
                        ForEach(IssueStatus.allCases, id: \.self) { status in
                            Button {
                                viewModel.statusFilter = status
                            } label: {
                                Label(status.label, systemImage: status.iconName)
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.statusFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Switch Workspace") {
                            workspaceVM.selectedWorkspace = nil
                        }
                        Button("Logout", role: .destructive) {
                            NotificationCenter.default.post(name: .logout, object: nil)
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showCreateIssue) {
                CreateIssueView(workspaceVM: workspaceVM) { newIssue in
                    viewModel.issues.insert(newIssue, at: 0)
                }
            }
            .task {
                await viewModel.loadIssues()
            }
        }
    }

    private var issueList: some View {
        List {
            ForEach(viewModel.issuesByStatus, id: \.0) { status, issues in
                Section {
                    ForEach(issues) { issue in
                        NavigationLink(value: issue) {
                            IssueRowView(
                                issue: issue,
                                assigneeName: workspaceVM.assigneeName(type: issue.assigneeType, id: issue.assigneeId)
                            )
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let issue = issues[index]
                            Task { await viewModel.deleteIssue(issue) }
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        StatusIcon(status: status, size: 14)
                        Text(status.label)
                            .font(.caption.weight(.semibold))
                        Text("\(issues.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Issue.self) { issue in
            IssueDetailView(
                viewModel: IssueDetailViewModel(issue: issue),
                workspaceVM: workspaceVM
            )
        }
    }
}

extension Notification.Name {
    static let logout = Notification.Name("logout")
}
