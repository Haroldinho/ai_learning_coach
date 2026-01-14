import SwiftUI

/// Anki-style flashcard study view with SM-2 algorithm
struct FlashcardStudyView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var flashcards: [Flashcard] = []
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var isLoading = false
    @State private var showComplete = false
    @State private var studyStats = StudyStats()
    
    struct StudyStats {
        var reviewed = 0
        var correct = 0
        var incorrect = 0
    }
    
    var currentCard: Flashcard? {
        guard currentIndex < flashcards.count else { return nil }
        return flashcards[currentIndex]
    }
    
    var dueCount: Int {
        flashcards.filter { SpacedRepetition.isDue($0) }.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if flashcards.isEmpty {
                    emptyState
                } else if showComplete {
                    completionView
                } else if let card = currentCard {
                    studyView(card: card)
                } else {
                    allDoneView
                }
            }
            .navigationTitle("Flashcard Study")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Flashcard Study")
                            .font(.headline)
                        if let project = dataController.currentProject {
                            Text(project.title.count > 75 ? String(project.title.prefix(72)) + "..." : project.title)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
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
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Due count badge
                        if dueCount > 0 {
                            Text("\(dueCount) due")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentCoral)
                                .cornerRadius(12)
                        }
                        
                        // Sync button
                        Button(action: syncProgress) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.accentTeal)
                        }
                        
                        // Download/Generate button
                        Button(action: {
                            Task { await generateFlashcards() }
                        }) {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.accentTeal)
                        }
                    }
                }
            }
            .onAppear {
                loadFlashcards()
            }
            .onChange(of: dataController.currentProject) { oldValue, newValue in
                if oldValue?.id != newValue?.id {
                    // Project changed, reload flashcards
                    currentIndex = 0
                    isFlipped = false
                    showComplete = false
                    loadFlashcards()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading flashcards...")
                .foregroundColor(.secondaryText)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient.violetGradient)
            
            Text("No Flashcards Yet")
                .font(.headline2)
                .foregroundColor(.primaryText)
            
            Text("Select a project and generate flashcards to start studying")
                .font(.body2)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if dataController.currentProject != nil {
                Button("Generate Flashcards") {
                    Task { await generateFlashcards() }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
    
    private var allDoneView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.success)
            
            Text("All Caught Up! 🎉")
                .font(.largeTitle2)
                .foregroundColor(.primaryText)
            
            Text("No cards are due for review right now")
                .font(.body2)
                .foregroundColor(.secondaryText)
            
            Button("Review All Cards") {
                // Reset to review all
                currentIndex = 0
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 32) {
            // Celebration icon
            Image(systemName: "star.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(LinearGradient.coralGradient)
            
            Text("Session Complete!")
                .font(.largeTitle2)
                .foregroundColor(.primaryText)
            
            // Stats
            VStack(spacing: 16) {
                StatRow(icon: "checkmark.circle.fill", label: "Reviewed", value: "\(studyStats.reviewed)", color: .accentTeal)
                StatRow(icon: "hand.thumbsup.fill", label: "Got Right", value: "\(studyStats.correct)", color: .success)
                StatRow(icon: "arrow.counterclockwise", label: "Need Practice", value: "\(studyStats.incorrect)", color: .warning)
            }
            .padding()
            .cardStyle()
            .padding(.horizontal)
            
            Button("Study More") {
                resetSession()
            }
            .buttonStyle(PrimaryButtonStyle(gradient: .violetGradient))
        }
    }
    
    private func studyView(card: Flashcard) -> some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack {
                Text("Card \(currentIndex + 1) of \(flashcards.count)")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                // Session stats
                HStack(spacing: 8) {
                    Label("\(studyStats.correct)", systemImage: "checkmark")
                        .foregroundColor(.success)
                    Label("\(studyStats.incorrect)", systemImage: "xmark")
                        .foregroundColor(.error)
                }
                .font(.caption2)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Flashcard
            FlashcardView(
                front: card.front,
                back: card.back,
                isFlipped: $isFlipped
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isFlipped.toggle()
                }
            }
            
            Spacer()
            
            // Rating buttons (only show when flipped)
            if isFlipped {
                ratingButtons(for: card)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Tap card to reveal answer")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
                    .padding()
            }
        }
        .padding()
    }
    
    private func ratingButtons(for card: Flashcard) -> some View {
        HStack(spacing: 12) {
            ForEach(SpacedRepetition.ReviewQuality.allCases, id: \.rawValue) { quality in
                VStack(spacing: 4) {
                    Button(quality.displayName) {
                        rateCard(card, quality: quality)
                    }
                    .buttonStyle(RatingButtonStyle(color: colorForQuality(quality)))
                    
                    Text(quality.intervalDescription(
                        currentInterval: card.interval,
                        easeFactor: card.easeFactor
                    ))
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
                }
            }
        }
        .padding()
    }
    
    private func colorForQuality(_ quality: SpacedRepetition.ReviewQuality) -> Color {
        switch quality {
        case .again: return .error
        case .hard: return .warning
        case .good: return .success
        case .easy: return .accentTeal
        }
    }
    
    // MARK: - Actions
    
    private func loadFlashcards() {
        guard let projectId = dataController.currentProject?.id else { return }
        
        // Load from local storage
        flashcards = dataController.fetchDueFlashcards(for: projectId)
        
        // If no due cards, load all
        if flashcards.isEmpty {
            flashcards = dataController.fetchFlashcards(for: projectId)
        }
        
        // Sort by priority
        flashcards = SpacedRepetition.sortByPriority(flashcards)
    }
    
    private func generateFlashcards() async {
        guard let projectId = dataController.currentProject?.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Try to load remediation cards first
            let remediationCards = try await APIService.shared.getRemediationFlashcards(projectId: projectId)
            
            if !remediationCards.isEmpty {
                // User has remediation cards available
                dataController.saveFlashcards(from: remediationCards, projectId: projectId)
                loadFlashcards()
                return
            }
            
            // Otherwise load regular flashcards
            let flashcardResponses = try await APIService.shared.getFlashcards(projectId: projectId)
            dataController.saveFlashcards(from: flashcardResponses, projectId: projectId)
            loadFlashcards()
        } catch {
            print("Failed to generate flashcards: \(error)")
        }
    }
    
    private func rateCard(_ card: Flashcard, quality: SpacedRepetition.ReviewQuality) {
        // Update stats
        studyStats.reviewed += 1
        if quality.rawValue >= 3 {
            studyStats.correct += 1
        } else {
            studyStats.incorrect += 1
        }
        
        // Apply SM-2 algorithm
        dataController.reviewFlashcard(card, quality: quality)
        
        // Move to next card
        withAnimation {
            isFlipped = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if currentIndex < flashcards.count - 1 {
                currentIndex += 1
            } else {
                showComplete = true
            }
        }
    }
    
    private func syncProgress() {
        guard let projectId = dataController.currentProject?.id else { return }
        
        let unsyncedCards = dataController.getUnsyncedFlashcards(for: projectId)
        
        Task {
            // Create review requests for syncing
            let reviews = unsyncedCards.enumerated().map { index, _ in
                FlashcardReviewRequest(cardId: index, quality: 3)
            }
            
            try? await APIService.shared.syncFlashcardProgress(
                projectId: projectId,
                reviews: reviews,
                timestamp: Date()
            )
            
            // Mark as synced
            dataController.markAsSynced(unsyncedCards)
        }
    }
    
    private func resetSession() {
        currentIndex = 0
        studyStats = StudyStats()
        showComplete = false
        loadFlashcards()
    }
}

// MARK: - Flashcard View Component

struct FlashcardView: View {
    let front: String
    let back: String
    @Binding var isFlipped: Bool
    
    var body: some View {
        ZStack {
            // Front
            cardContent(text: front, label: "QUESTION")
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
            
            // Back
            cardContent(text: back, label: "ANSWER")
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }
    
    private func cardContent(text: String, label: String) -> some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondaryText)
                .tracking(2)
            
            Spacer()
            
            Text(text)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.cardShadow, radius: 12, x: 0, y: 6)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
                .foregroundColor(.secondaryText)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
        }
    }
}

#Preview {
    FlashcardStudyView()
        .environmentObject(DataController())
        .environmentObject(NotificationManager())
}
