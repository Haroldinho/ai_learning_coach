import SwiftUI
#if os(macOS)
import AppKit
#endif

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
                    
                    #if os(macOS)
                    // Delay slightly to ensure UIScene is ready
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                        updateDockTile(count: dataController.totalDueCount)
                    }
                    #endif
                }
                .onChange(of: dataController.totalDueCount) { newCount in
                    #if os(macOS)
                    updateDockTile(count: newCount)
                    #endif
                }
        }
    }
    
    #if os(macOS)
    private func updateDockTile(count: Int) {
        let dockTile = NSApp.dockTile
        
        if count == 0 {
            dockTile.contentView = nil
            dockTile.badgeLabel = nil
        } else {
            let view = DockTileView(count: count)
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(x: 0, y: 0, width: 256, height: 256)
            dockTile.contentView = hostingView
        }
        
        dockTile.display()
    }
    #endif
}
