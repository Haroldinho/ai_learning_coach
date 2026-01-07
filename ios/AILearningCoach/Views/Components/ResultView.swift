import SwiftUI

/// Shared result view for diagnostic and exam assessments
struct ResultView: View {
    let result: AssessmentResult
    let onDismiss: () -> Void
    var showConfetti: Bool = false
    
    @State private var animateScore = false
    @State private var showDetails = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with score
                scoreHeader
                    .padding(.top, 40)
                
                // Pass/Fail indicator
                passFailBadge
                
                // Score breakdown
                if showDetails {
                    detailsSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Feedback sections
                feedbackSections
                
                // Question Results List
                questionResultsList
                
                // Action button
                Button("Continue") {
                    onDismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                animateScore = true
            }
            withAnimation(.easeInOut.delay(0.8)) {
                showDetails = true
            }
        }
    }
    
    // MARK: - Subviews
    
    private var scoreHeader: some View {
        VStack(spacing: 16) {
            // Large circular score
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0, to: animateScore ? result.score : 0)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: animateScore)
                
                VStack(spacing: 4) {
                    Text("\(result.scorePercentage)%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Text(scoreMessage)
                .font(.headline2)
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)
        }
    }
    
    private var passFailBadge: some View {
        HStack {
            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(result.passed ? "PASSED" : "NEEDS REVIEW")
                .fontWeight(.bold)
        }
        .font(.subheadline)
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(result.passed ? Color.success : Color.warning)
        .cornerRadius(20)
    }
    
    private var detailsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                // Correct count
                VStack {
                    Text("\(result.correctConcepts.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.success)
                    Text("Correct")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Missed count
                VStack {
                    Text("\(result.missedConcepts.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.error)
                    Text("Missed")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
            .padding()
            .cardStyle()
        }
    }
    
    private var feedbackSections: some View {
        VStack(spacing: 16) {
            // General feedback
            FeedbackCard(
                icon: "text.bubble.fill",
                title: "Feedback",
                content: result.feedback,
                color: .accentTeal
            )
            
            // Excelled at
            if let excelledAt = result.excelledAt, !excelledAt.isEmpty {
                FeedbackCard(
                    icon: "star.fill",
                    title: "You Excelled At",
                    content: excelledAt,
                    color: .accentGold
                )
            }
            
            // Improvement areas
            if let improvement = result.improvementAreas, !improvement.isEmpty {
                FeedbackCard(
                    icon: "arrow.up.circle.fill",
                    title: "Areas to Improve",
                    content: improvement,
                    color: .warning
                )
            }
            
            // Challenges
            if let challenges = result.challenges, !challenges.isEmpty {
                FeedbackCard(
                    icon: "flame.fill",
                    title: "Challenge Yourself",
                    content: challenges,
                    color: .accentCoral
                )
            }
        }
    }
    
    private var questionResultsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Breakdown")
                .font(.headline)
                .foregroundColor(.primaryText)
                .padding(.horizontal)
            
            ForEach(result.questionResults) { qResult in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Image(systemName: qResult.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(qResult.isCorrect ? Color.success : Color.error)
                        
                        Text(qResult.text)
                            .font(.body)
                            .foregroundColor(.primaryText)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Answer: \(qResult.userAnswer)")
                            .font(.subheadline)
                            .foregroundColor(qResult.isCorrect ? Color.success : Color.error)
                        
                        if !qResult.isCorrect {
                            Text("Correct Answer: \(qResult.correctAnswer)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primaryText)
                        }
                        
                        Text(qResult.explanation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.top, 2)
                    }
                    .padding(.leading, 28)
                }
                .padding()
                .cardStyle()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var scoreColor: Color {
        if result.score >= 0.8 {
            return .success
        } else if result.score >= 0.6 {
            return .warning
        } else {
            return .error
        }
    }
    
    private var scoreMessage: String {
        if result.score >= 0.9 {
            return "Outstanding! 🌟"
        } else if result.score >= 0.8 {
            return "Great Job! 👏"
        } else if result.score >= 0.6 {
            return "Good Effort! 💪"
        } else {
            return "Keep Practicing! 📚"
        }
    }
}

// MARK: - Feedback Card Component

struct FeedbackCard: View {
    let icon: String
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primaryText)
            }
            
            Text(content)
                .font(.body2)
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

#Preview {
    ResultView(
        result: AssessmentResult(
            score: 0.85,
            correctConcepts: ["Concept 1", "Concept 2", "Concept 3"],
            missedConcepts: ["Concept 4"],
            questionResults: [
                QuestionResult(text: "What is Concept 1?", userAnswer: "Correct Answer", correctAnswer: "Correct Answer", explanation: "Explanation for Concept 1", isCorrect: true),
                QuestionResult(text: "What is Concept 4?", userAnswer: "Wrong Answer", correctAnswer: "Right Answer", explanation: "Explanation for Concept 4", isCorrect: false)
            ],
            feedback: "Great performance! You've demonstrated solid understanding of the core concepts.",
            excelledAt: "You showed excellent grasp of fundamental principles and applied them correctly.",
            improvementAreas: "Consider reviewing advanced topics for deeper understanding.",
            challenges: "Try applying these concepts to real-world scenarios.",
            passed: true
        ),
        onDismiss: { }
    )
}
