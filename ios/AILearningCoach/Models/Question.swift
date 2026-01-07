import Foundation

/// Question model for diagnostic and exam modes
struct Question: Identifiable, Codable {
    let id: Int
    let text: String
    let difficulty: String
    let keyConcept: String
    var userAnswer: String?
    
    enum CodingKeys: String, CodingKey {
        case id, text, difficulty
        case keyConcept = "key_concept"
    }
    
    var difficultyColor: String {
        switch difficulty.lowercased() {
        case "beginner", "easy":
            return "success"
        case "intermediate", "medium":
            return "warning"
        case "advanced", "hard":
            return "error"
        default:
            return "accentTeal"
        }
    }
}

/// Result for an individual question
struct QuestionResult: Identifiable, Codable {
    var id: String { text } // Using text as UI ID for simplicity
    let text: String
    let userAnswer: String
    let correctAnswer: String
    let explanation: String
    let isCorrect: Bool
    
    enum CodingKeys: String, CodingKey {
        case text, explanation
        case userAnswer = "user_answer"
        case correctAnswer = "correct_answer"
        case isCorrect = "is_correct"
    }
}

/// Assessment result after completing a quiz or exam
struct AssessmentResult: Codable {
    let score: Double
    let correctConcepts: [String]
    let missedConcepts: [String]
    let questionResults: [QuestionResult]
    let feedback: String
    let excelledAt: String?
    let improvementAreas: String?
    let challenges: String?
    let passed: Bool
    
    enum CodingKeys: String, CodingKey {
        case score, feedback, passed, challenges
        case correctConcepts = "correct_concepts"
        case missedConcepts = "missed_concepts"
        case questionResults = "question_results"
        case excelledAt = "excelled_at"
        case improvementAreas = "improvement_areas"
    }
    
    var scorePercentage: Int {
        Int(score * 100)
    }
    
    var scoreColor: String {
        if score >= 0.8 {
            return "success"
        } else if score >= 0.6 {
            return "warning"
        } else {
            return "error"
        }
    }
}
