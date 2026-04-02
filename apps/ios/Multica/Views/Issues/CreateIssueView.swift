import SwiftUI

struct CreateIssueView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var workspaceVM: WorkspaceViewModel
    var onCreate: (Issue) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var status: IssueStatus = .todo
    @State private var priority: IssuePriority = .none
    @State private var selectedAssignee: Assignee?
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Properties") {
                    // Status picker
                    Picker("Status", selection: $status) {
                        ForEach(IssueStatus.allCases, id: \.self) { s in
                            Label(s.label, systemImage: s.iconName).tag(s)
                        }
                    }

                    // Priority picker
                    Picker("Priority", selection: $priority) {
                        ForEach(IssuePriority.allCases, id: \.self) { p in
                            Label(p.label, systemImage: p.iconName).tag(p)
                        }
                    }

                    // Assignee picker
                    Picker("Assignee", selection: $selectedAssignee) {
                        Text("Unassigned").tag(nil as Assignee?)
                        ForEach(workspaceVM.assignees) { assignee in
                            Label(
                                assignee.name,
                                systemImage: assignee.typeName == "agent" ? "cpu" : "person"
                            ).tag(assignee as Assignee?)
                        }
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createIssue() }
                    }
                    .disabled(title.isEmpty || isSubmitting)
                }
            }
        }
    }

    private func createIssue() async {
        isSubmitting = true
        error = nil
        do {
            let request = CreateIssueRequest(
                title: title,
                description: description.isEmpty ? nil : description,
                status: status.rawValue,
                priority: priority.rawValue,
                assigneeType: selectedAssignee?.typeName,
                assigneeId: selectedAssignee?.entityId
            )
            let issue = try await APIClient.shared.createIssue(request)
            onCreate(issue)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSubmitting = false
    }
}
