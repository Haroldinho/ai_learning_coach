import Foundation

/// API Service for communicating with the FastAPI backend
class APIService {
    static let shared = APIService()
    
    // Configure for local development
    private var baseURL: String {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        // For physical devices, use your Mac's local IP
        return "http://localhost:8000"
        #endif
    }
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        encoder = JSONEncoder()
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
    
    /// Check if backend is reachable
    func checkConnection() async -> Bool {
        guard let url = URL(string: "\(baseURL)/") else { return false }
        
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
