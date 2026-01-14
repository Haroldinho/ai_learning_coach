import SwiftUI

/// Diagnostic mode view for knowledge assessment
struct DiagnosticView: View {
    @EnvironmentObject var dataController: DataController
    
    @State private var questions: [Question] = []
    @State private var currentIndex = 0
    @State private var answers: [String] = []
    @State private var currentAnswer = ""
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var result: AssessmentResult?
    @State private var errorMessage: String?
    
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
                    ResultView(result: result, onDismiss: resetQuiz)
                } else if questions.isEmpty {
                    startView
                } else if let question = currentQuestion {
                    questionView(question)
                } else {
                    reviewView
                }
            }
            .navigationTitle("Diagnostic")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    #if targetEnvironment(macCatalyst)
                    Image("icarus_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    #endif
                }
                
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Diagnostic")
                            .font(.headline)
                        if let project = dataController.currentProject {
                            Text(project.title.count > 75 ? String(project.title.prefix(72)) + "..." : project.title)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: dataController.currentProject) { oldValue, newValue in
                if oldValue?.id != newValue?.id {
                    // Project changed, reset quiz
                    resetQuiz()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(isSubmitting ? "Analyzing your answers..." : "Generating diagnostic quiz...")
                .foregroundColor(.secondaryText)
        }
    }
    
    private var startView: some View {
        VStack(spacing: 24) {
            Image(systemName: "stethoscope")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient.violetGradient)
            
            Text("Diagnostic Assessment")
                .font(.largeTitle2)
                .foregroundColor(.primaryText)
            
            Text("Take a quick 10-question quiz to assess your current knowledge level")
                .font(.body2)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if dataController.currentProject != nil {
                Button("Start Diagnostic") {
                    Task { await loadQuestions() }
                }
                .buttonStyle(PrimaryButtonStyle(gradient: .violetGradient))
            } else {
                Text("Please select a project first")
                    .font(.caption2)
                    .foregroundColor(.warning)
            }
        }
    }
    
    private func questionView(_ question: Question) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentViolet.opacity(0.2))
                    
                    Rectangle()
                        .fill(LinearGradient.violetGradient)
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
                                    .stroke(Color.accentViolet.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            
            // Bottom button
            VStack {
                Divider()
                
                Button(currentIndex == questions.count - 1 ? "Review Answers" : "Next Question") {
                    submitAnswer()
                }
                .buttonStyle(PrimaryButtonStyle(gradient: .violetGradient))
                .disabled(currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding()
            }
            .background(Color(.systemBackground))
        }
    }
    
    private var reviewView: some View {
        VStack(spacing: 0) {
            Text("Review Your Answers")
                .font(.headline2)
                .foregroundColor(.primaryText)
                .padding()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(questions) { question in
                        let index = questions.firstIndex(where: { $0.id == question.id }) ?? 0
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Q\(index + 1): \(question.text)")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            Text("Your answer: \(answers[safe: index] ?? "N/A")")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .cardStyle()
                    }
                }
                .padding()
            }
            
            VStack {
                Divider()
                
                Button("Submit for Grading") {
                    Task { await submitQuiz() }
                }
                .buttonStyle(PrimaryButtonStyle(gradient: .violetGradient))
                .padding()
            }
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Helpers
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner", "easy": return .success
        case "intermediate", "medium": return .warning
        case "advanced", "hard": return .error
        default: return .accentViolet
        }
    }
    
    // MARK: - Actions
    
    private func loadQuestions() async {
        guard let projectId = dataController.currentProject?.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            questions = try await APIService.shared.getDiagnosticQuiz(projectId: projectId)
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
            // Show review
            currentIndex = questions.count
        }
    }
    
    private func submitQuiz() async {
        guard let projectId = dataController.currentProject?.id else { return }
        
        isLoading = true
        isSubmitting = true
        defer { 
            isLoading = false
            isSubmitting = false
        }
        
        do {
            result = try await APIService.shared.submitDiagnostic(projectId: projectId, answers: answers)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func resetQuiz() {
        questions = []
        answers = []
        currentIndex = 0
        currentAnswer = ""
        result = nil
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    DiagnosticView()
        .environmentObject(DataController())
}
