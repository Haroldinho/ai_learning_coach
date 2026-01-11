import SwiftUI

/// Home view showing project list and creation
struct HomeView: View {
    @EnvironmentObject var dataController: DataController
    @State private var projects: [ProjectResponse] = []
    @State private var isLoading = false
    @State private var showNewProject = false
    @State private var newTopic = ""
    @State private var errorMessage: String?
    @State private var isConnected = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading projects...")
                        .scaleEffect(1.2)
                } else if projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle("Learning Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewProject = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentTeal)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    connectionStatus
                }
            }
            .sheet(isPresented: $showNewProject) {
                newProjectSheet
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                await checkConnectionAndLoadProjects()
            }
            .refreshable {
                await loadProjects()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var connectionStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.success : Color.error)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Online" : "Offline")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient.tealGradient)
            
            Text("No Learning Projects Yet")
                .font(.headline2)
                .foregroundColor(.primaryText)
            
            Text("Start your learning journey by creating a new project")
                .font(.body2)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Create Project") {
                showNewProject = true
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
    
    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(projects, id: \.id) { project in
                    ProjectCard(project: project)
                        .onTapGesture {
                            selectProject(project)
                        }
                }
            }
            .padding()
        }
    }
    
    private var newProjectSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What would you like to learn?")
                        .font(.headline2)
                        .foregroundColor(.primaryText)
                    
                    TextField("e.g., Quantum Physics, Swift Programming", text: $newTopic)
                        .textFieldStyle(.roundedBorder)
                        .font(.body2)
                }
                .padding()
                
                Spacer()
                
                Button("Create Project") {
                    Task {
                        await createProject()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(newTopic.isEmpty)
                .padding()
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewProject = false
                        newTopic = ""
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func checkConnectionAndLoadProjects() async {
        isConnected = await APIService.shared.checkConnection()
        await loadProjects()
    }
    
    private func loadProjects() async {
        guard isConnected else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedProjects = try await APIService.shared.getProjects()
            // Deduplicate by ID
            var seen = Set<String>()
            self.projects = fetchedProjects.filter { seen.insert($0.id).inserted }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func createProject() async {
        guard !newTopic.isEmpty else { return }
        
        do {
            let project = try await APIService.shared.createProject(topic: newTopic)
            projects.append(project)
            showNewProject = false
            newTopic = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func selectProject(_ project: ProjectResponse) {
        // Fetch full project details with milestones
        Task {
            do {
                let fullProject = try await APIService.shared.getProjectDetails(projectId: project.id)
                // Save to persistence
                dataController.saveCurrentProject(fullProject)
            } catch {
                // Fallback: use ProjectResponse data
                let fallbackProject = Project(
                    id: project.id,
                    title: project.title,
                    smartGoal: project.smartGoal,
                    totalDurationDays: project.totalDurationDays,
                    currentMilestoneIndex: project.currentMilestoneIndex,
                    completedMilestones: project.completedMilestones,
                    milestones: project.milestones ?? []
                )
                dataController.saveCurrentProject(fallbackProject)
                errorMessage = "Partial project data loaded: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    @EnvironmentObject var dataController: DataController
    let project: ProjectResponse
    
    var isSelected: Bool {
        dataController.currentProject?.id == project.id
    }
    
    var progress: Double {
        guard !project.completedMilestones.isEmpty || project.currentMilestoneIndex > 0 else { return 0 }
        let duration = Double(project.totalDurationDays)
        guard duration > 0 else { return 0 }
        
        let val = Double(project.completedMilestones.count) / (duration / 3.0)
        return val.isFinite ? max(0, min(1, val)) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.headline2)
                        .foregroundColor(isSelected ? .accentTeal : .primaryText)
                        .lineLimit(2)
                    
                    Text("\(project.totalDurationDays) days")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                CircularProgressView(progress: progress)
                    .frame(width: 50, height: 50)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentTeal.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient.tealGradient)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
            
            Text("\(project.completedMilestones.count) milestones completed")
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentTeal : Color.clear, lineWidth: 2)
        )
        .cardStyle()
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentTeal.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient.tealGradient,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            Text("\(Int((progress.isFinite ? progress : 0) * 100))%")
                .font(.caption2)
                .foregroundColor(.accentTeal)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(DataController())
}
