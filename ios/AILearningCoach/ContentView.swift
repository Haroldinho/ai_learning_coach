import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataController: DataController
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home, study, diagnostic, exam
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .tag(Tab.home)
            
            FlashcardStudyView()
                .tabItem {
                    Label("Study", systemImage: "rectangle.stack.fill")
                }
                .tag(Tab.study)
            
            DiagnosticView()
                .tabItem {
                    Label("Diagnostic", systemImage: "stethoscope")
                }
                .tag(Tab.diagnostic)
            
            ExamView()
                .tabItem {
                    Label("Exam", systemImage: "checkmark.seal.fill")
                }
                .tag(Tab.exam)
        }
        .tint(Color.accentTeal)
    }
}

#Preview {
    ContentView()
        .environmentObject(DataController())
        .environmentObject(NotificationManager())
}
