import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Color Palette (Apple-style Light Mode with vibrant accents)
extension Color {
    // Primary accent colors
    static let accentTeal = Color(red: 0.0, green: 0.69, blue: 0.76)
    static let accentCoral = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let accentViolet = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let accentGold = Color(red: 1.0, green: 0.76, blue: 0.03)
    
    // Semantic colors
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let warning = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let error = Color(red: 1.0, green: 0.27, blue: 0.27)
    
    // Card backgrounds - cross-platform
    #if canImport(UIKit)
    static let cardBackground = Color(UIColor.systemBackground)
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(UIColor.secondaryLabel)
    #elseif canImport(AppKit)
    static let cardBackground = Color(NSColor.windowBackgroundColor)
    static let primaryText = Color(NSColor.labelColor)
    static let secondaryText = Color(NSColor.secondaryLabelColor)
    #endif
    
    static let cardShadow = Color.black.opacity(0.08)
}

// MARK: - Gradient Definitions
extension LinearGradient {
    static let tealGradient = LinearGradient(
        colors: [Color.accentTeal, Color.accentTeal.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let coralGradient = LinearGradient(
        colors: [Color.accentCoral, Color.accentCoral.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let violetGradient = LinearGradient(
        colors: [Color.accentViolet, Color.accentViolet.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Card Style Modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.cardShadow, radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = .tealGradient
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(gradient)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Rating Button Style (for flashcard ratings)
struct RatingButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(configuration.isPressed ? .white : color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isPressed ? color : color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Typography
extension Font {
    static let largeTitle2 = Font.system(size: 34, weight: .bold, design: .rounded)
    static let headline2 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let body2 = Font.system(size: 17, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 13, weight: .medium, design: .default)
}
