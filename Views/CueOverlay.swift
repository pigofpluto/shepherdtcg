import SwiftUI

/// Renders the engine's transient cues — floating damage numbers, heals, shield
/// breaks, banked points — anchored to whatever they happened to.
///
/// Cues carry a card id or, for board-level events, just a side. `anchor`
/// resolves either to a point on the mat; the view model expires the cue itself.
struct CueOverlay: View {
    let cues: [VisualCue]
    /// Where a given card currently sits, if it's still somewhere visible.
    let anchor: (VisualCue) -> CGPoint?
    let scale: CGFloat

    var body: some View {
        ZStack {
            ForEach(cues) { cue in
                if let p = anchor(cue) {
                    CueLabel(kind: cue.kind, scale: scale)
                        .position(p)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.4).combined(with: .opacity),
                            removal: .opacity))
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cues.count)
    }
}

/// One cue, drifting upward as it fades.
private struct CueLabel: View {
    let kind: VisualCue.Kind
    let scale: CGFloat
    @State private var rise = false

    var body: some View {
        content
            .font(.system(size: scale * 0.055, weight: .black, design: .rounded))
            .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
            .offset(y: rise ? -scale * 0.075 : 0)
            .opacity(rise ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) { rise = true }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .damage(let n):
            Text("−\(n)").foregroundStyle(Color(red: 1.0, green: 0.34, blue: 0.28))
        case .heal(let n):
            Text("+\(n)").foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.50))
        case .buff(let a, let h):
            Text(buffText(a, h)).foregroundStyle(Theme.gold)
        case .shieldBreak:
            Image(systemName: "shield.slash.fill")
                .font(.system(size: scale * 0.055)).foregroundStyle(.cyan)
        case .death:
            Image(systemName: "xmark")
                .font(.system(size: scale * 0.05, weight: .black)).foregroundStyle(.white.opacity(0.9))
        case .points(let e, let n):
            HStack(spacing: scale * 0.008) {
                Image(systemName: e.icon)
                Text("+\(n)")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, scale * 0.016).padding(.vertical, scale * 0.006)
            .background(e.color.opacity(0.95), in: Capsule())
        case .berry:
            Image(systemName: "leaf.fill")
                .font(.system(size: scale * 0.05)).foregroundStyle(Theme.sage)
        case .draw:
            EmptyView()      // the card itself flying from the deck is the cue
        }
    }

    private func buffText(_ a: Int, _ h: Int) -> String {
        if a != 0 && h != 0 { return "+\(a)/+\(h)" }
        if a != 0 { return "+\(a) ATK" }
        return "+\(h) HP"
    }
}
