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
    let id: UUID
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID() // Generate a unique ID for UI tracking
        text = try container.decode(String.self, forKey: .text)
        explanation = try container.decode(String.self, forKey: .explanation)
        userAnswer = try container.decode(String.self, forKey: .userAnswer)
        correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
        isCorrect = try container.decode(Bool.self, forKey: .isCorrect)
    }
    
    // For previews/testing
    init(text: String, userAnswer: String, correctAnswer: String, explanation: String, isCorrect: Bool) {
        self.id = UUID()
        self.text = text
        self.userAnswer = userAnswer
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.isCorrect = isCorrect
    }
}

/// Assessment result after completing a quiz or exam
struct AssessmentResult: Codable {
    let score: Double
    let correctConcepts: [String]
    let missedConcepts: [String]
    var questionResults: [QuestionResult] = []
    let feedback: String
    let excelledAt: String?
    let improvementAreas: String?
    let challenges: String?
    let passed: Bool
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Double.self, forKey: .score)
        correctConcepts = try container.decode([String].self, forKey: .correctConcepts)
        missedConcepts = try container.decode([String].self, forKey: .missedConcepts)
        questionResults = try container.decodeIfPresent([QuestionResult].self, forKey: .questionResults) ?? []
        feedback = try container.decode(String.self, forKey: .feedback)
        excelledAt = try container.decodeIfPresent(String.self, forKey: .excelledAt)
        improvementAreas = try container.decodeIfPresent(String.self, forKey: .improvementAreas)
        challenges = try container.decodeIfPresent(String.self, forKey: .challenges)
        passed = try container.decode(Bool.self, forKey: .passed)
    }
    
    // Default initializer for previews/testing
    init(score: Double, correctConcepts: [String], missedConcepts: [String], questionResults: [QuestionResult], feedback: String, excelledAt: String?, improvementAreas: String?, challenges: String?, passed: Bool) {
        self.score = score
        self.correctConcepts = correctConcepts
        self.missedConcepts = missedConcepts
        self.questionResults = questionResults
        self.feedback = feedback
        self.excelledAt = excelledAt
        self.improvementAreas = improvementAreas
        self.challenges = challenges
        self.passed = passed
    }
    
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
