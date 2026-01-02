import Foundation

/// Helper to manage user-specific identifying information
struct UserPersistence {
    private static let userIDKey = "com.ailcoach.user_id"
    
    /// Returns the unique ID for this device/user.
    /// Generates one if it doesn't exist.
    static func getUserID() -> String {
        if let existingID = UserDefaults.standard.string(forKey: userIDKey) {
            return existingID
        }
        
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: userIDKey)
        return newID
    }
}
