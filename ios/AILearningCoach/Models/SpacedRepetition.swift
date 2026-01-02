import Foundation

/// SM-2 Spaced Repetition Algorithm Implementation
/// Based on the SuperMemo 2 algorithm by Piotr Wozniak
struct SpacedRepetition {
    
    /// Quality ratings for card review
    enum ReviewQuality: Int, CaseIterable {
        case again = 0      // Complete blackout, wrong answer
        case hard = 1       // Correct but very difficult
        case good = 3       // Correct with some hesitation
        case easy = 5       // Perfect recall
        
        var displayName: String {
            switch self {
            case .again: return "Again"
            case .hard: return "Hard"
            case .good: return "Good"
            case .easy: return "Easy"
            }
        }
        
        var colorName: String {
            switch self {
            case .again: return "error"
            case .hard: return "warning"
            case .good: return "success"
            case .easy: return "accentTeal"
            }
        }
        
        /// Estimated next review interval description
        func intervalDescription(currentInterval: Int, easeFactor: Double) -> String {
            let newData = SpacedRepetition.calculateNextReview(
                quality: self.rawValue,
                easeFactor: easeFactor,
                interval: currentInterval,
                repetitions: 1
            )
            
            if newData.interval == 1 {
                return "~10min"
            } else if newData.interval < 7 {
                return "~\(newData.interval)d"
            } else if newData.interval < 30 {
                return "~\(newData.interval / 7)w"
            } else {
                return "~\(newData.interval / 30)mo"
            }
        }
    }
    
    /// Result of SM-2 calculation
    struct ReviewResult {
        let easeFactor: Double
        let interval: Int
        let repetitions: Int
        let nextReviewDate: Date
    }
    
    /// Calculate next review parameters using SM-2 algorithm
    /// - Parameters:
    ///   - quality: User's rating (0-5)
    ///   - easeFactor: Current ease factor (default 2.5)
    ///   - interval: Current interval in days
    ///   - repetitions: Number of successful repetitions
    /// - Returns: Updated review data
    static func calculateNextReview(
        quality: Int,
        easeFactor: Double,
        interval: Int,
        repetitions: Int
    ) -> ReviewResult {
        var newEaseFactor = easeFactor
        var newInterval = interval
        var newRepetitions = repetitions
        
        // If quality < 3, reset the repetition count (card needs relearning)
        if quality < 3 {
            newRepetitions = 0
            newInterval = 1
        } else {
            // Successful recall
            if newRepetitions == 0 {
                newInterval = 1
            } else if newRepetitions == 1 {
                newInterval = 6
            } else {
                newInterval = Int(Double(interval) * newEaseFactor)
            }
            newRepetitions += 1
        }
        
        // Update ease factor (never go below 1.3)
        newEaseFactor = max(1.3, easeFactor + 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02))
        
        // Calculate next review date
        let nextDate = Calendar.current.date(byAdding: .day, value: newInterval, to: Date()) ?? Date()
        
        return ReviewResult(
            easeFactor: newEaseFactor,
            interval: newInterval,
            repetitions: newRepetitions,
            nextReviewDate: nextDate
        )
    }
    
    /// Check if a card is due for review
    static func isDue(_ flashcard: Flashcard) -> Bool {
        return flashcard.nextReviewDate <= Date()
    }
    
    /// Sort flashcards by priority (due first, then by overdue amount)
    static func sortByPriority(_ flashcards: [Flashcard]) -> [Flashcard] {
        return flashcards.sorted { card1, card2 in
            // Cards that are due come first
            let now = Date()
            let card1IsDue = card1.nextReviewDate <= now
            let card2IsDue = card2.nextReviewDate <= now
            
            if card1IsDue && !card2IsDue {
                return true
            } else if !card1IsDue && card2IsDue {
                return false
            } else {
                // Both due or both not due - sort by date
                return card1.nextReviewDate < card2.nextReviewDate
            }
        }
    }
    
    /// Check if a card should "graduate" (be removed from active review)
    /// A card graduates after reaching a certain interval threshold
    static func shouldGraduate(_ flashcard: Flashcard, threshold: Int = 90) -> Bool {
        return flashcard.interval >= threshold && flashcard.repetitions >= 5
    }
}
