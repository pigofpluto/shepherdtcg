import SwiftUI
import UIKit

/// A card as it appears on the playmat.
///
/// Stat changes animate rather than snap: `MatchViewModel` publishes once per
/// animation beat, so the `.animation(_, value:)` modifiers below have a fresh
/// value to interpolate toward each time. That's why `CardInstance` doesn't need
/// to be observable itself — it's read fresh on every bump.
struct MiniCard: View {
    let inst: CardInstance
    var w: CGFloat = 58
    var h: CGFloat = 80
    var showCost: Bool = false
    /// Cost after Guard/Relic discounts — may be lower than the printed cost.
    var cost: Int? = nil
    var playable: Bool = false
    var guardian: Bool = false
    /// In the Frontier with its attack still unspent. Glows so you can see at a
    /// glance which of your cards haven't swung yet this turn.
    var readyToAttack: Bool = false
    /// Face-down — used for the opponent's hand and the Deck stack.
    var faceDown: Bool = false
    /// Set while the card is doomed, so it can flash before it leaves the board.
    var dying: Bool = false
    /// Being carried by the player's finger — rides above the board, enlarged.
    var lifted: Bool = false
    /// A legal place to drop what's being dragged.
    var validTarget: Bool = false
    /// The target the finger is actually over.
    var hovered: Bool = false

    var body: some View {
        ZStack {
            // Swap face for back at the halfway point of the turn, so the card
            // reads as flipping over rather than cross-fading. Serves both the
            // Basecamp seeding and Relic unlocks.
            //
            // The back is counter-rotated: without it the container's 180° would
            // render the back mirrored.
            if faceDown {
                cardBack.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                face
            }
        }
        .rotation3DEffect(.degrees(faceDown ? 180 : 0),
                          axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .animation(.easeInOut(duration: 0.42), value: faceDown)
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: h * 0.08, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: h * 0.08).strokeBorder(
            borderColor, lineWidth: borderWidth))
        .overlay {
            // Impact flash — a doomed card whites out for its final beat.
            RoundedRectangle(cornerRadius: h * 0.08, style: .continuous)
                .fill(.white)
                .opacity(dying ? 0.55 : 0)
        }
        // A legal drop target glows; the one under the finger glows harder.
        // Failing both, a card that still has its attack carries a soft orange
        // glow, which goes out the moment it swings.
        .shadow(color: hovered ? Theme.gold
                     : (validTarget ? Theme.gold.opacity(0.65)
                     : (readyToAttack ? Self.readyOrange.opacity(0.75) : .clear)),
                radius: hovered ? 14 : (validTarget ? 8 : (readyToAttack ? 7 : 0)))
        .shadow(color: .black.opacity(lifted ? 0.55 : 0.4),
                radius: lifted ? 12 : 2, y: lifted ? 8 : 1)
        .scaleEffect(dying ? 0.88 : (lifted ? 1.35 : (hovered ? 1.06 : 1)))
        .saturation(dying ? 0.2 : 1)
        .animation(.easeOut(duration: 0.22), value: dying)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: lifted)
        .animation(.easeOut(duration: 0.15), value: hovered)
        .animation(.easeOut(duration: 0.15), value: validTarget)
        .animation(.easeOut(duration: 0.28), value: readyToAttack)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: inst.attack)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: inst.health)
        .animation(.spring(response: 0.30, dampingFraction: 0.7), value: inst.maxHealth)
        .animation(.easeOut(duration: 0.25), value: inst.shield)
    }

    /// Warmer and brighter than the Guardian's orange. The two never appear
    /// together — a Guardian sits in the Basecamp, and this only fires in the
    /// Frontier — but they shouldn't read as the same state either.
    private static let readyOrange = Color(red: 1.0, green: 0.58, blue: 0.16)

    private var borderColor: Color {
        if hovered || lifted { return Theme.gold }
        if validTarget { return Theme.gold.opacity(0.8) }
        if readyToAttack { return Self.readyOrange }
        if playable { return .green }
        if guardian { return .orange.opacity(0.9) }
        return .black.opacity(0.35)
    }

    private var borderWidth: CGFloat {
        if hovered || lifted { return 3 }
        if validTarget || readyToAttack || playable || guardian { return 2.5 }
        return 1
    }

    private var cardBack: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.34, green: 0.24, blue: 0.15),
                                    Color(red: 0.20, green: 0.14, blue: 0.09)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "leaf.fill")
                .font(.system(size: h * 0.30))
                .foregroundStyle(Theme.gold.opacity(0.55))
        }
    }

    private var face: some View {
        ZStack {
            Group {
                if let img = UIImage(named: inst.card.id) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [inst.card.accent.opacity(0.95), inst.card.accent.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)

            VStack(spacing: 0) {
                HStack {
                    if showCost {
                        let shown = cost ?? inst.card.cost
                        // Discounted costs read green so the saving is visible.
                        pip("\(shown)", shown < inst.card.cost
                            ? Color(red: 0.24, green: 0.55, blue: 0.28)
                            : Color(red: 0.20, green: 0.45, blue: 0.72))
                    }
                    Spacer()
                    if inst.shield {
                        Image(systemName: "shield.fill")
                            .font(.system(size: h * 0.12)).foregroundStyle(.cyan)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Spacer()
                Text(inst.card.name).font(.system(size: h * 0.10, weight: .bold))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                if inst.card.type.hasStats {
                    HStack {
                        pip("\(inst.attack)", Color(red: 0.80, green: 0.45, blue: 0.15))
                        Spacer()
                        pip("\(inst.health)", inst.health < inst.maxHealth ? .red : Color(red: 0.72, green: 0.20, blue: 0.20))
                    }
                }
            }
            .padding(h * 0.05)
        }
    }

    private func pip(_ s: String, _ c: Color) -> some View {
        Text(s).font(.system(size: h * 0.15, weight: .black, design: .rounded)).foregroundStyle(.white)
            .frame(width: h * 0.23, height: h * 0.23).background(Circle().fill(c))
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .contentTransition(.numericText())
    }
}
