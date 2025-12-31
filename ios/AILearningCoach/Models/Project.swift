import Foundation

/// Represents a learning project
struct Project: Identifiable, Codable {
    let id: String
    var title: String
    var smartGoal: String
    var totalDurationDays: Int
    var currentMilestoneIndex: Int
    var completedMilestones: [String]
    var milestones: [Milestone]
    
    struct Milestone: Identifiable, Codable {
        var id: String { title }
        let title: String
        let description: String
        let concepts: [String]
        let durationDays: Int
    }
}

/// API Response model
struct ProjectResponse: Codable {
    let id: String
    let title: String
    let smartGoal: String
    let totalDurationDays: Int
    let currentMilestoneIndex: Int
    let completedMilestones: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case smartGoal = "smart_goal"
        case totalDurationDays = "total_duration_days"
        case currentMilestoneIndex = "current_milestone_index"
        case completedMilestones = "completed_milestones"
    }
}
