import SwiftUI

struct PlanEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataController: DataController
    
    let projectId: String
    @State private var milestones: [Project.Milestone]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editMilestone: Project.Milestone?
    
    init(project: Project) {
        self.projectId = project.id
        self._milestones = State(initialValue: project.milestones)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Learning Roadmap")) {
                    ForEach(milestones) { milestone in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(milestone.title)
                                    .font(.headline)
                                Text(milestone.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundStyle(.blue)
                        }
                        .contentShape(Rectangle()) // Make entire row tappable
                        .onTapGesture {
                            editMilestone = milestone
                        }
                    }
                    .onMove(perform: moveMilestones)
                    .onDelete(perform: deleteMilestones)
                }
                
                Section(footer: Text("Changes will be saved to the cloud.")) {
                    Button {
                        Task {
                            await saveChanges()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Refine Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                EditButton()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $editMilestone) { milestone in
                MilestoneEditSheet(milestone: milestone) { updated in
                    if let index = milestones.firstIndex(where: { $0.id == milestone.id }) {
                        milestones[index] = updated
                    }
                }
            }
        }
    }
    
    private func moveMilestones(from source: IndexSet, to destination: Int) {
        milestones.move(fromOffsets: source, toOffset: destination)
    }
    
    private func deleteMilestones(at offsets: IndexSet) {
        milestones.remove(atOffsets: offsets)
    }
    
    private func saveChanges() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await APIService.shared.updateProjectPlan(projectId: projectId, milestones: milestones)
            
            // Refresh local state by re-fetching full details (since response is partial)
            let fullProject = try await APIService.shared.getProjectDetails(projectId: projectId)
            dataController.saveCurrentProject(fullProject)
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MilestoneEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var milestone: Project.Milestone
    var onSave: (Project.Milestone) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $milestone.title)
                    TextField("Description", text: $milestone.description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Duration (Days)")) {
                    Stepper("\(milestone.durationDays) days", value: $milestone.durationDays, in: 1...7)
                }
            }
            .navigationTitle("Edit Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(milestone)
                        dismiss()
                    }
                }
            }
        }
    }
}
