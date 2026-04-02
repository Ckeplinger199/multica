import SwiftUI

struct WorkspacePickerView: View {
    @Bindable var viewModel: WorkspaceViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading workspaces...")
                } else if viewModel.workspaces.isEmpty {
                    ContentUnavailableView(
                        "No Workspaces",
                        systemImage: "folder",
                        description: Text("You don't belong to any workspaces yet.")
                    )
                } else {
                    List(viewModel.workspaces) { workspace in
                        Button {
                            Task { await viewModel.selectWorkspace(workspace) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workspace.name)
                                        .font(.headline)
                                    if let desc = workspace.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Workspaces")
            .task {
                await viewModel.loadWorkspaces()
            }
        }
    }
}
