import Foundation
import SwiftData
import SwiftUI

/// Data controller managing local persistence with SwiftData
@MainActor
class DataController: ObservableObject {
    let container: ModelContainer
    
    @Published var currentProject: Project?
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        let schema = Schema([Flashcard.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        // Load last selected project
        currentProject = loadCurrentProject()
    }
    
    // MARK: - Project Persistence
    
    /// Save current project to UserDefaults
    func saveCurrentProject(_ project: Project) {
        currentProject = project
        if let encoded = try? JSONEncoder().encode(project) {
            UserDefaults.standard.set(encoded, forKey: "currentProject")
        }
    }
    
    /// Load current project from UserDefaults
    func loadCurrentProject() -> Project? {
        guard let data = UserDefaults.standard.data(forKey: "currentProject"),
              let project = try? JSONDecoder().decode(Project.self, from: data) else {
            return nil
        }
        return project
    }
    
    /// Clear current project
    func clearCurrentProject() {
        currentProject = nil
        UserDefaults.standard.removeObject(forKey: "currentProject")
    }
    
    // MARK: - Flashcard Operations
    
    /// Fetch all flashcards for a project
    func fetchFlashcards(for projectId: String) -> [Flashcard] {
        let descriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        
        do {
            return try container.mainContext.fetch(descriptor)
        } catch {
            print("Failed to fetch flashcards: \(error)")
            return []
        }
    }
    
    /// Fetch due flashcards for a project
    func fetchDueFlashcards(for projectId: String) -> [Flashcard] {
        let now = Date()
        let descriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate { $0.projectId == projectId && $0.nextReviewDate <= now },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        
        do {
            return try container.mainContext.fetch(descriptor)
        } catch {
            print("Failed to fetch due flashcards: \(error)")
            return []
        }
    }
    
    /// Save flashcards from API response with deduplication
    func saveFlashcards(from responses: [FlashcardResponse], projectId: String) {
        // First, check what cards already exist
        let existingCards = fetchFlashcards(for: projectId)
        let existingFronts = Set(existingCards.map { $0.front })
        
        // Only insert new cards
        for response in responses {
            // Skip if card with same front text already exists
            if existingFronts.contains(response.front) {
                continue
            }
            
            let flashcard = Flashcard(
                front: response.front,
                back: response.back,
                tags: response.tags,
                projectId: projectId,
                easeFactor: response.easeFactor,
                interval: response.interval,
                repetitions: response.repetitions
            )
            container.mainContext.insert(flashcard)
        }
        
        try? container.mainContext.save()
    }
    
    /// Update flashcard after review
    func reviewFlashcard(_ flashcard: Flashcard, quality: SpacedRepetition.ReviewQuality) {
        let result = SpacedRepetition.calculateNextReview(
            quality: quality.rawValue,
            easeFactor: flashcard.easeFactor,
            interval: flashcard.interval,
            repetitions: flashcard.repetitions
        )
        
        flashcard.easeFactor = result.easeFactor
        flashcard.interval = result.interval
        flashcard.repetitions = result.repetitions
        flashcard.nextReviewDate = result.nextReviewDate
        flashcard.lastReviewDate = Date()
        flashcard.needsSync = true
        
        try? container.mainContext.save()
    }
    
    /// Get count of due cards
    func getDueCardCount(for projectId: String) -> Int {
        return fetchDueFlashcards(for: projectId).count
    }
    
    /// Get flashcards that need syncing
    func getUnsyncedFlashcards(for projectId: String) -> [Flashcard] {
        let descriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate { $0.projectId == projectId && $0.needsSync == true }
        )
        
        do {
            return try container.mainContext.fetch(descriptor)
        } catch {
            print("Failed to fetch unsynced flashcards: \(error)")
            return []
        }
    }
    
    /// Mark flashcards as synced
    func markAsSynced(_ flashcards: [Flashcard]) {
        for flashcard in flashcards {
            flashcard.needsSync = false
            flashcard.lastSyncDate = Date()
        }
        try? container.mainContext.save()
    }
}

