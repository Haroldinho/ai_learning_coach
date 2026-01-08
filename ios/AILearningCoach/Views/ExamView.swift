import SwiftUI

/// Examiner mode view for milestone assessments
struct ExamView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var questions: [Question] = []
    @State private var currentIndex = 0
    @State private var answers: [String] = []
    @State private var currentAnswer = ""
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var result: AssessmentResult?
    @State private var errorMessage: String?
    @State private var showConfirmStart = false
    
    var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let result = result {
                    ResultView(result: result, onDismiss: resetExam, showConfetti: result.passed)
                } else if questions.isEmpty {
                    startView
                } else if let question = currentQuestion {
                    examQuestionView(question)
                } else {
                    submitView
                }
            }
            .navigationTitle("Milestone Exam")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Milestone Exam")
                            .font(.headline)
                        if let project = dataController.currentProject {
                            Text(project.title.count > 75 ? String(project.title.prefix(72)) + "..." : project.title)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .alert("Start Exam?", isPresented: $showConfirmStart) {
                Button("Cancel", role: .cancel) { }
                Button("Start") {
                    Task { await loadExam() }
                }
            } message: {
                Text("This exam will test your knowledge of the current milestone. You'll need 80% to pass.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(isSubmitting ? "Grading your exam..." : "Generating exam questions...")
                .foregroundColor(.secondaryText)
        }
    }
    
    private var startView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient.coralGradient)
            
            Text("Milestone Exam")
                .font(.largeTitle2)
                .foregroundColor(.primaryText)
            
            if let project = dataController.currentProject {
                VStack(spacing: 8) {
                    Text("Testing: \(project.title)")
                        .font(.headline2)
                        .foregroundColor(.accentCoral)
                    
                    Text("10 questions • 80% to pass")
                        .font(.body2)
                        .foregroundColor(.secondaryText)
                }
                .padding()
                .cardStyle()
                .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Text("Ready to prove your knowledge?")
                    .font(.body2)
                    .foregroundColor(.secondaryText)
                
                if dataController.currentProject != nil {
                    Button("Begin Exam") {
                        showConfirmStart = true
                    }
                    .buttonStyle(PrimaryButtonStyle(gradient: .coralGradient))
                } else {
                    Text("Please select a project first")
                        .font(.caption2)
                        .foregroundColor(.warning)
                }
            }
        }
    }
    
    private func examQuestionView(_ question: Question) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentCoral.opacity(0.2))
                    
                    Rectangle()
                        .fill(LinearGradient.coralGradient)
                        .frame(width: geometry.size.width * progress)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 4)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Question header
                    HStack {
                        Text("Question \(currentIndex + 1) of \(questions.count)")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                        
                        // Type indicator
                        if currentIndex >= 7 {
                            Text("Active Recall")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentViolet)
                                .cornerRadius(8)
                        }
                        
                        // Difficulty badge
                        Text(question.difficulty.capitalized)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(difficultyColor(question.difficulty))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Question text
                    Text(question.text)
                        .font(.headline2)
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .cardStyle()
                        .padding(.horizontal)
                    
                    // Concept hint
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.accentGold)
                        Text("Testing: \(question.keyConcept)")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal)
                    
                    // Answer input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Answer")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                        
                        TextEditor(text: $currentAnswer)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentCoral.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            
            // Bottom button
            VStack {
                Divider()
                
                Button(currentIndex == questions.count - 1 ? "Review & Submit" : "Next") {
                    submitAnswer()
                }
                .buttonStyle(PrimaryButtonStyle(gradient: .coralGradient))
                .disabled(currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding()
            }
            .background(Color(.systemBackground))
        }
    }
    
    private var submitView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.accentCoral)
            
            Text("Ready to Submit?")
                .font(.headline2)
                .foregroundColor(.primaryText)
            
            Text("You've answered all \(questions.count) questions.")
                .font(.body2)
                .foregroundColor(.secondaryText)
            
            VStack(spacing: 12) {
                Button("Submit Exam") {
                    Task { await submitExam() }
                }
                .buttonStyle(PrimaryButtonStyle(gradient: .coralGradient))
                
                Button("Review Answers") {
                    currentIndex = 0
                    currentAnswer = answers[safe: 0] ?? ""
                }
                .foregroundColor(.accentCoral)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner", "easy": return .success
        case "intermediate", "medium": return .warning
        case "advanced", "hard": return .error
        default: return .accentCoral
        }
    }
    
    // MARK: - Actions
    
    private func loadExam() async {
        guard let projectId = dataController.currentProject?.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            questions = try await APIService.shared.getExam(projectId: projectId)
            answers = Array(repeating: "", count: questions.count)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func submitAnswer() {
        // Save current answer
        if currentIndex < answers.count {
            answers[currentIndex] = currentAnswer
        }
        
        // Move to next
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            currentAnswer = answers[safe: currentIndex] ?? ""
        } else {
            // Show submit view
            currentIndex = questions.count
        }
    }
    
    private func submitExam() async {
        guard let projectId = dataController.currentProject?.id else { return }
        
        isLoading = true
        isSubmitting = true
        defer { 
            isLoading = false
            isSubmitting = false
        }
        
        do {
            result = try await APIService.shared.submitExam(projectId: projectId, answers: answers)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func resetExam() {
        questions = []
        answers = []
        currentIndex = 0
        currentAnswer = ""
        result = nil
    }
}

#Preview {
    ExamView()
        .environmentObject(DataController())
        .environmentObject(NotificationManager())
}
