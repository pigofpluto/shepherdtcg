import SwiftUI

/// A pile of cards sitting in one of the mat's printed slots.
///
/// Deck, Discard and Altar used to be bare text counters, which meant draw,
/// death and Sacrifice animations had nowhere to fly from or to. Each pile now
/// draws its top few cards, so `matchedGeometryEffect` has a real view to land on.
struct CardStack: View {
    let cards: [CardInstance]
    let size: CGSize
    var faceDown = false
    /// Cards fanned behind the top one, to read as a pile.
    var depth = 3
    var namespace: Namespace.ID
    /// Only the top card is matched — the ones beneath are static backing.
    var matchTop = true

    var body: some View {
        ZStack {
            emptySlot

            let shown = Array(cards.suffix(depth))
            ForEach(Array(shown.enumerated()), id: \.element.id) { i, c in
                let fromTop = shown.count - 1 - i
                let isTop = fromTop == 0
                MiniCard(inst: c, w: size.width, h: size.height, faceDown: faceDown)
                    .offset(x: CGFloat(fromTop) * -1.5, y: CGFloat(fromTop) * -1.5)
                    .modifier(MatchedIf(active: isTop && matchTop, id: c.id, ns: namespace))
                    .zIndex(Double(i))
            }

            if cards.count > 1 {
                Text("\(cards.count)")
                    .font(.system(size: size.height * 0.20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size.height * 0.07)
                    .padding(.vertical, size.height * 0.025)
                    .background(Color.black.opacity(0.62), in: Capsule())
                    .offset(y: size.height * 0.40)
                    .contentTransition(.numericText())
                    .zIndex(100)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: size.height * 0.08, style: .continuous)
            .strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    }
}

/// The draw pile. The deck is `[TCGCard]`, not live instances — cards only
/// become `CardInstance`s when drawn — so this is drawn from the count alone.
/// Its job is to be a visible place for drawn cards to come *from*.
struct DeckStack: View {
    let count: Int
    let size: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.height * 0.08, style: .continuous)
                .strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            ForEach(0..<min(count, 3), id: \.self) { i in
                RoundedRectangle(cornerRadius: size.height * 0.08, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.34, green: 0.24, blue: 0.15),
                                                  Color(red: 0.20, green: 0.14, blue: 0.09)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: size.height * 0.08)
                        .strokeBorder(.black.opacity(0.35), lineWidth: 1))
                    .frame(width: size.width, height: size.height)
                    .offset(x: CGFloat(i) * -1.5, y: CGFloat(i) * -1.5)
            }
            if count > 0 {
                Image(systemName: "leaf.fill")
                    .font(.system(size: size.height * 0.30))
                    .foregroundStyle(Theme.gold.opacity(0.55))
                Text("\(count)")
                    .font(.system(size: size.height * 0.20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size.height * 0.07)
                    .padding(.vertical, size.height * 0.025)
                    .background(Color.black.opacity(0.62), in: Capsule())
                    .offset(y: size.height * 0.40)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// `matchedGeometryEffect` can't be applied conditionally inline without
/// changing the view's type, so it goes through a modifier.
struct MatchedIf: ViewModifier {
    let active: Bool
    let id: UUID
    let ns: Namespace.ID

    func body(content: Content) -> some View {
        if active {
            content.matchedGeometryEffect(id: id, in: ns)
        } else {
            content
        }
    }
}

/// The Altar — Sacrificed Creatures rest here until an Event clears.
/// Drawn face-up, slightly scattered, since what's on it matters to the player.
struct AltarStack: View {
    let cards: [CardInstance]
    let size: CGSize
    var namespace: Namespace.ID

    var body: some View {
        ZStack {
            let shown = Array(cards.suffix(3))
            ForEach(Array(shown.enumerated()), id: \.element.id) { i, c in
                let fromTop = shown.count - 1 - i
                MiniCard(inst: c, w: size.width, h: size.height)
                    .rotationEffect(.degrees(Double(fromTop) * -5))
                    .offset(y: CGFloat(fromTop) * -3)
                    .modifier(MatchedIf(active: fromTop == 0, id: c.id, ns: namespace))
                    .zIndex(Double(i))
            }
            if cards.count > 1 {
                Text("\(cards.count)")
                    .font(.system(size: size.height * 0.22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size.height * 0.08)
                    .padding(.vertical, size.height * 0.03)
                    .background(Color.black.opacity(0.62), in: Capsule())
                    .offset(y: size.height * 0.42)
                    .contentTransition(.numericText())
                    .zIndex(100)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
