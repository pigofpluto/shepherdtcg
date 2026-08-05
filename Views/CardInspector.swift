import SwiftUI

/// Tap any card on the board to read it properly.
///
/// Board cards are drawn tiny — about 60pt wide — so their ability text isn't
/// legible in play. This shows the full printed card using the same ornate
/// `TCGCardView` the Collection screen renders.
///
/// The printed card can also *lie* about what's on the board: a Creature under
/// Elder's aura, carrying damage, or buffed by a Blessing has different numbers
/// than its face. Where they differ, the live values are shown beneath.
struct CardInspector: View {
    let inst: CardInstance
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            GeometryReader { geo in
                VStack(spacing: 10) {
                    TCGCardView(card: inst.card)
                        .frame(height: geo.size.height * (liveStats == nil ? 0.88 : 0.76))

                    if let liveStats {
                        HStack(spacing: 14) {
                            Text("On the board")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                            Text(liveStats)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.gold)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.black.opacity(0.55), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
            }
            .padding(.vertical, 14)
        }
        .transition(.opacity)
    }

    /// Current attack/health, but only when they differ from the printed values
    /// — otherwise the card face already tells the whole story.
    private var liveStats: String? {
        guard inst.card.type.hasStats else { return nil }
        let printedA = inst.card.attack, printedH = inst.card.health
        guard inst.attack != printedA || inst.health != printedH else { return nil }

        var s = "\(inst.attack) / \(inst.health)"
        if inst.health < inst.maxHealth { s += "  (max \(inst.maxHealth))" }
        if inst.shield { s += "  · Shield" }
        return s
    }
}
