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

/// Assessment result after completing a quiz or exam
struct AssessmentResult: Codable {
    let score: Double
    let correctConcepts: [String]
    let missedConcepts: [String]
    let feedback: String
    let excelledAt: String?
    let improvementAreas: String?
    let challenges: String?
    let passed: Bool
    
    enum CodingKeys: String, CodingKey {
        case score, feedback, passed
        case correctConcepts = "correct_concepts"
        case missedConcepts = "missed_concepts"
        case excelledAt = "excelled_at"
        case improvementAreas = "improvement_areas"
        case challenges
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
