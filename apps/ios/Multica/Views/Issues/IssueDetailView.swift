import SwiftUI

struct IssueDetailView: View {
    @Bindable var viewModel: IssueDetailViewModel
    @Bindable var workspaceVM: WorkspaceViewModel
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                issueHeader
                Divider()
                propertiesSection
                Divider()

                // Tab bar
                Picker("", selection: $selectedTab) {
                    Text("Comments").tag(0)
                    Text("Activity").tag(1)
                    if viewModel.issue.isAssignedToAgent {
                        Text("Agent Runs").tag(2)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case 0:
                    CommentListView(viewModel: viewModel)
                case 1:
                    activitySection
                case 2:
                    TaskRunsView(viewModel: viewModel)
                default:
                    EmptyView()
                }
            }
        }
        .navigationTitle(viewModel.issue.identifier)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAll()
            viewModel.setupRealtimeUpdates()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    private var issueHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.issue.title)
                .font(.title2.bold())

            if let desc = viewModel.issue.description, !desc.isEmpty {
                Text(desc)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Active task banner
            if let task = viewModel.activeTask, task.status.isActive {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Agent is working on this issue...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("View Logs") {
                        selectedTab = 2
                    }
                    .font(.caption)
                }
                .padding(10)
                .background(.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }

    private var propertiesSection: some View {
        VStack(spacing: 0) {
            // Status
            propertyRow(label: "Status") {
                Menu {
                    ForEach(IssueStatus.allCases, id: \.self) { status in
                        Button {
                            Task { await viewModel.updateStatus(status) }
                        } label: {
                            Label(status.label, systemImage: status.iconName)
                        }
                    }
                } label: {
                    StatusBadge(status: viewModel.issue.status)
                }
            }
            Divider().padding(.leading)

            // Priority
            propertyRow(label: "Priority") {
                Menu {
                    ForEach(IssuePriority.allCases, id: \.self) { priority in
                        Button {
                            Task { await viewModel.updatePriority(priority) }
                        } label: {
                            Label(priority.label, systemImage: priority.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        PriorityIcon(priority: viewModel.issue.priority)
                        Text(viewModel.issue.priority.label)
                            .font(.subheadline)
                    }
                }
            }
            Divider().padding(.leading)

            // Assignee
            propertyRow(label: "Assignee") {
                Menu {
                    Button("Unassigned") {
                        Task { await viewModel.updateAssignee(type: nil, id: nil) }
                    }
                    Divider()
                    ForEach(workspaceVM.assignees) { assignee in
                        Button {
                            Task { await viewModel.updateAssignee(type: assignee.typeName, id: assignee.entityId) }
                        } label: {
                            Label(
                                assignee.name,
                                systemImage: assignee.typeName == "agent" ? "cpu" : "person"
                            )
                        }
                    }
                } label: {
                    let name = workspaceVM.assigneeName(type: viewModel.issue.assigneeType, id: viewModel.issue.assigneeId)
                    HStack(spacing: 6) {
                        AssigneeAvatar(type: viewModel.issue.assigneeType, name: name, size: 20)
                        Text(name)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func propertyRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            content()
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var activitySection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("Activity timeline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}
