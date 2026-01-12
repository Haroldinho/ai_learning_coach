import Foundation

/// Represents a learning project
struct Project: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var smartGoal: String
    var totalDurationDays: Int
    var currentMilestoneIndex: Int
    var completedMilestones: [String]
    var milestones: [Milestone]
    
    struct Milestone: Identifiable, Codable, Equatable {
        var id: String { title }
        var title: String
        var description: String
        var concepts: [String]
        var durationDays: Int
        
        enum CodingKeys: String, CodingKey {
            case title, description, concepts
            case durationDays = "duration_days"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, milestones
        case smartGoal = "smart_goal"
        case totalDurationDays = "total_duration_days"
        case currentMilestoneIndex = "current_milestone_index"
        case completedMilestones = "completed_milestones"
    }
}

/// API Response model - now matches full Project structure
struct ProjectResponse: Codable {
    let id: String
    let title: String
    let smartGoal: String
    let totalDurationDays: Int
    let currentMilestoneIndex: Int
    let completedMilestones: [String]
    let milestones: [Project.Milestone]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, milestones
        case smartGoal = "smart_goal"
        case totalDurationDays = "total_duration_days"
        case currentMilestoneIndex = "current_milestone_index"
        case completedMilestones = "completed_milestones"
    }
}

