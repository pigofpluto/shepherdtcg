import SwiftUI

/// Central palette — light cream-green background, dark brown ink, gold accents (Royal/Heraldic).
enum Theme {
    // Background (light cream-green — airy, like aged parchment with a green tint)
    static let bgSolid   = Color(red: 0.93, green: 0.94, blue: 0.88)

    // Earth tones
    static let sage      = Color(red: 0.28, green: 0.44, blue: 0.20)
    static let moss      = Color(red: 0.30, green: 0.42, blue: 0.22)
    static let clay      = Color(red: 0.72, green: 0.40, blue: 0.24)
    static let bark      = Color(red: 0.20, green: 0.15, blue: 0.11)
    static let gold      = Color(red: 0.80, green: 0.65, blue: 0.30)
    static let cream     = Color(red: 0.93, green: 0.90, blue: 0.82)
    static let parchment = Color(red: 0.86, green: 0.81, blue: 0.69)

    /// Primary action color.
    static let accent = sage
    /// Primary text color (dark brown — reads on light bg).
    static let text = bark

    static var background: Color { bgSolid }

    static func panel(_ opacity: Double = 0.06) -> Color { bark.opacity(opacity) }
}

/// Full-screen earthy backdrop used on every screen.
struct Backdrop: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

/// Primary button styling (sage fill, dark text).
struct EarthyButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .frame(maxWidth: .infinity)
            .padding()
            .background(.clear)
            .foregroundStyle(enabled ? Theme.text : Theme.text.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(enabled ? Theme.bark : Theme.bark.opacity(0.25), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
