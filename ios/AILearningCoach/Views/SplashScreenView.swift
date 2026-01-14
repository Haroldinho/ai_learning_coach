import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var opacity = 0.3
    @State private var scale = 0.8
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image("icarus_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 44))
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    Text("AI Learning Coach")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(opacity)
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.2)) {
                    self.opacity = 1.0
                    self.scale = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(DataController())
        .environmentObject(NotificationManager())
}
