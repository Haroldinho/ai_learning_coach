import SwiftUI

#if os(macOS)
import AppKit

struct DockTileView: View {
    let count: Int
    
    var body: some View {
        ZStack {
            // App Icon
            if let image = NSImage(named: "NSApplicationIcon") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback if icon not found
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.accentColor)
                    .overlay(
                        Text("ICARUS")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
            
            // Badge
            if count > 0 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(count > 20 ? Color.red : Color.blue)
                            )
                            .shadow(radius: 5)
                            .offset(x: 10, y: -10)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: 256, height: 256)
        .padding(10)
    }
}
#endif
