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
    var selected: Bool = false
    var playable: Bool = false
    var guardian: Bool = false
    /// Face-down — used for the opponent's hand and the Deck stack.
    var faceDown: Bool = false
    /// Set while the card is doomed, so it can flash before it leaves the board.
    var dying: Bool = false

    var body: some View {
        ZStack {
            if faceDown {
                cardBack
            } else {
                face
            }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: h * 0.08, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: h * 0.08).strokeBorder(
            borderColor, lineWidth: selected || playable || guardian ? 2.5 : 1))
        .overlay {
            // Impact flash — a doomed card whites out for its final beat.
            RoundedRectangle(cornerRadius: h * 0.08, style: .continuous)
                .fill(.white)
                .opacity(dying ? 0.55 : 0)
        }
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        .scaleEffect(dying ? 0.88 : 1)
        .saturation(dying ? 0.2 : 1)
        .animation(.easeOut(duration: 0.22), value: dying)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: inst.attack)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: inst.health)
        .animation(.spring(response: 0.30, dampingFraction: 0.7), value: inst.maxHealth)
        .animation(.easeOut(duration: 0.25), value: inst.shield)
    }

    private var borderColor: Color {
        if selected { return Theme.gold }
        if playable { return .green }
        if guardian { return .orange.opacity(0.9) }
        return .black.opacity(0.35)
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
