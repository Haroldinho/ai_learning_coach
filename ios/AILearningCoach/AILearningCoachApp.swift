import SwiftUI

@main
struct AILearningCoachApp: App {
    @StateObject private var dataController = DataController()
    @StateObject private var notificationManager = NotificationManager()
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(dataController)
                .environmentObject(notificationManager)
                .onAppear {
                    notificationManager.requestAuthorization()
                }
        }
    }
}
