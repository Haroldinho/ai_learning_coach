import Foundation

/// API Service for communicating with the FastAPI backend
class APIService {
    static let shared = APIService()
    
    // API Configuration
    private static let renderURL = "https://ai-learning-coach-8iz1.onrender.com"
    private static let localURL = "http://localhost:8000"
    
    // The currently active URL, defaults to Render
    private(set) var baseURL: String = renderURL
    
    // Public getter for UI
    var currentUserID: String { return userID }
    
    // Unique ID for this user/device
    private var userID: String
    
    private var session: URLSession!
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        self.userID = UserPersistence.getUserID()
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        setupSession()
    }
    
    private func setupSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        
        // Add User ID to all request headers
        config.httpAdditionalHeaders = ["X-User-ID": userID]
        
        self.session = URLSession(configuration: config)
    }
    
    /// Update the current user identity and reset session
    func updateIdentity(newID: String) {
        self.userID = newID
        UserPersistence.setUserID(newID)
        setupSession()
        print("✅ Identity updated to: \(newID)")
    }
    
    // MARK: - Project Endpoints
    
    /// Fetch all projects
    func getProjects() async throws -> [ProjectResponse] {
        let url = URL(string: "\(baseURL)/projects")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode([ProjectResponse].self, from: data)
    }
    
    /// Create a new project
    func createProject(topic: String, existingPlan: String? = nil) async throws -> ProjectResponse {
        let url = URL(string: "\(baseURL)/projects")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "topic": topic,
            "existing_plan": existingPlan as Any
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode(ProjectResponse.self, from: data)
    }
    
    /// Get full project details including milestones
    func getProjectDetails(projectId: String) async throws -> Project {
        let url = URL(string: "\(baseURL)/projects/\(projectId)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode(Project.self, from: data)
    }
    
    /// Update project milestones
    func updateProjectPlan(projectId: String, milestones: [Project.Milestone]) async throws -> ProjectResponse {
        let url = URL(string: "\(baseURL)/projects/\(projectId)/plan")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "milestones": milestones.map { [
                "title": $0.title,
                "description": $0.description,
                "concepts": $0.concepts,
                "duration_days": $0.durationDays
            ] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode(ProjectResponse.self, from: data)
    }
    
    // MARK: - Flashcard Endpoints
    
    /// Get flashcards for a project
    func getFlashcards(projectId: String) async throws -> [FlashcardResponse] {
        let url = URL(string: "\(baseURL)/projects/\(projectId)/flashcards")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode([FlashcardResponse].self, from: data)
    }
    
    /// Get remediation flashcards
    func getRemediationFlashcards(projectId: String) async throws -> [FlashcardResponse] {
        let url = URL(string: "\(baseURL)/projects/\(projectId)/flashcards/remediation")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode([FlashcardResponse].self, from: data)
    }
    
    /// Sync offline flashcard reviews
    func syncFlashcardProgress(projectId: String, reviews: [FlashcardReviewRequest], timestamp: Date) async throws {
        let url = URL(string: "\(baseURL)/projects/\(projectId)/flashcards/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "reviews": reviews.map { ["card_id": $0.cardId, "quality": $0.quality] },
            "last_sync_timestamp": formatter.string(from: timestamp)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }
    
    // MARK: - Diagnostic Endpoints
    
    /// Get diagnostic quiz
    func getDiagnosticQuiz(projectId: String) async throws -> [Question] {
        let url = URL(string: "\(baseURL)/projects/\(projectId)/diagnostic")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode([Question].self, from: data)
    }
    
    /// Submit diagnostic answers
    func submitDiagnostic(projectId: String, answers: [String]) async throws -> AssessmentResult {
        let url = URL(string: "\(baseURL)/projects/\(projectId)/diagnostic")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["answers": answers]
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode(AssessmentResult.self, from: data)
    }
    
    // MARK: - Exam Endpoints
    
    /// Get exam for current milestone
    func getExam(projectId: String) async throws -> [Question] {
        let url = URL(string: "\(baseURL)/projects/\(projectId)/exam")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode([Question].self, from: data)
    }
    
    /// Submit exam answers
    func submitExam(projectId: String, answers: [String]) async throws -> AssessmentResult {
        let url = URL(string: "\(baseURL)/projects/\(projectId)/exam")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["answers": answers]
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try decoder.decode(AssessmentResult.self, from: data)
    }
    
    /// Check if backend is reachable and switch to fallback if necessary
    func checkConnection() async -> Bool {
        // 1. Try currently active URL
        if await verifyURL(baseURL) {
            return true
        }
        
        // 2. If it fails, try the fallback
        let fallbackURL = (baseURL == APIService.renderURL) ? APIService.localURL : APIService.renderURL
        print("⚠️ Primary API (\(baseURL)) unreachable. Trying fallback: \(fallbackURL)")
        
        if await verifyURL(fallbackURL) {
            baseURL = fallbackURL
            print("✅ Switched to fallback API: \(baseURL)")
            return true
        }
        
        return false
    }
    
    private func verifyURL(_ urlString: String) async -> Bool {
        guard let url = URL(string: "\(urlString)/") else { return false }
        
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case serverError
    case notFound
    case networkError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .serverError:
            return "Server error. Please try again."
        case .notFound:
            return "Resource not found."
        case .networkError:
            return "Network error. Check your connection."
        case .decodingError:
            return "Failed to process server response."
        }
    }
}

