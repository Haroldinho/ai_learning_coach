import Foundation
import UserNotifications

/// Manager for push notifications
@MainActor
class NotificationManager: ObservableObject {
    @Published var isAuthorized = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    /// Request notification authorization
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
            
            if let error = error {
                if (error as NSError).code != 1 {
                    print("Notification authorization error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Flashcard Reminders
    
    /// Schedule a notification for due flashcards
    func scheduleFlashcardReminder(projectId: String, dueCount: Int, at date: Date) {
        guard isAuthorized, dueCount > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📚 Time to Study!"
        content.body = "You have \(dueCount) card\(dueCount == 1 ? "" : "s") ready for review."
        content.sound = .default
        content.badge = dueCount as NSNumber
        content.userInfo = ["projectId": projectId, "type": "flashcard"]
        
        // Schedule for the specified time
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "flashcard-\(projectId)-\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    /// Schedule daily morning reminder for flashcards
    func scheduleDailyReminder(projectId: String, hour: Int = 9, minute: Int = 0) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📚 Daily Study Time"
        content.body = "Don't break your streak! Review your flashcards today."
        content.sound = .default
        content.userInfo = ["projectId": projectId, "type": "daily"]
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily-\(projectId)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Diagnostic Reminders
    
    /// Schedule diagnostic assessment reminder (after 3 days)
    func scheduleDiagnosticReminder(projectId: String, milestoneTitle: String, startDate: Date) {
        guard isAuthorized else { return }
        
        let reminderDate = Calendar.current.date(byAdding: .day, value: 3, to: startDate) ?? startDate
        
        let content = UNMutableNotificationContent()
        content.title = "🩺 Time for a Diagnostic Check!"
        content.body = "You've been studying \"\(milestoneTitle)\" for 3 days. Ready to test your progress?"
        content.sound = .default
        content.userInfo = ["projectId": projectId, "type": "diagnostic"]
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "diagnostic-\(projectId)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Exam Notifications
    
    /// Notify when exam is ready
    func notifyExamReady(projectId: String, milestoneTitle: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📝 Your Assessment is Ready"
        content.body = "Time to prove your knowledge of \"\(milestoneTitle)\"!"
        content.sound = .default
        content.userInfo = ["projectId": projectId, "type": "exam"]
        
        // Immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "exam-\(projectId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Management
    
    /// Cancel all notifications for a project
    func cancelNotifications(for projectId: String) {
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.contains(projectId) }
                .map { $0.identifier }
            
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
    
    /// Clear badge count
    func clearBadge() {
        notificationCenter.setBadgeCount(0)
    }
}
