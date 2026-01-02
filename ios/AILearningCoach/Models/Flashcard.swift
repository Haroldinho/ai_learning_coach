import Foundation
import SwiftData

/// Flashcard model with SM-2 spaced repetition data
@Model
final class Flashcard: Identifiable {
    var id: UUID
    var front: String
    var back: String
    var tags: [String]
    var projectId: String
    
    // SM-2 Algorithm properties
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var nextReviewDate: Date
    var lastReviewDate: Date?
    
    // Sync tracking
    var needsSync: Bool
    var lastSyncDate: Date?
    
    init(
        id: UUID = UUID(),
        front: String,
        back: String,
        tags: [String] = [],
        projectId: String,
        easeFactor: Double = 2.5,
        interval: Int = 1,
        repetitions: Int = 0,
        nextReviewDate: Date = Date()
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.tags = tags
        self.projectId = projectId
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.needsSync = false
    }
}

/// API Response model for flashcards
struct FlashcardResponse: Codable {
    let id: Int
    let front: String
    let back: String
    let tags: [String]
    let easeFactor: Double
    let interval: Int
    let repetitions: Int
    let nextReviewDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, front, back, tags
        case easeFactor = "ease_factor"
        case interval, repetitions
        case nextReviewDate = "next_review_date"
    }
}

/// Flashcard review request for syncing
struct FlashcardReviewRequest: Codable {
    let cardId: Int
    let quality: Int
    
    enum CodingKeys: String, CodingKey {
        case cardId = "card_id"
        case quality
    }
}
