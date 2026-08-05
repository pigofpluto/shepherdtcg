import SwiftUI

/// Where everything sits on the playmat.
///
/// Positions are **fractions of the mat image** (0…1), measured off
/// `Art/Playmat/playmat v3.png`, so they stay correct at every device size.
/// `TCGMatchView` aspect-fits the mat once and converts through `Frame`.
///
/// This is the single place board positions are written down. Animations need
/// named destinations — "the card flies to the Altar" has to resolve to a rect —
/// so every zone, including the ones drawn as counters, has an entry here.
///
/// The mat is **not** a simple mirror: the Deck/Discard pair swaps order between
/// the halves, and the Event column runs foe 1·2 → shared 3 → your 2·1. So each
/// side is written out rather than reflected.
enum MatLayout {

    /// Native aspect of `playmat v4.jpg` (4096 × 2240) — identical to the v3
    /// mock it replaced, so the fractions below carried over unchanged.
    static let aspect: CGFloat = 4096.0 / 2240.0

    /// A printed card slot — every card on the mat is drawn at this size.
    static let cardSize = CGSize(width: 0.071, height: 0.152)

    enum Slot {
        case deck, discard, altar, manaPool, hand, end
        case camp(Int)              // 0…3 — slot 0 is the Guardian
        case relic(Int)             // 0…1
        case event(Int)             // 0…2, where 2 is the shared finale
        case element(Element)
    }

    // MARK: Slot centres

    /// Centre of a slot, in mat fractions.
    static func center(_ slot: Slot, for side: PlayerSide) -> CGPoint {
        let mine = side == .you
        switch slot {
        case .end:
            return CGPoint(x: 0.048, y: 0.502)          // shared — the END rock

        case .deck:
            return CGPoint(x: 0.052, y: mine ? 0.891 : 0.103)
        case .discard:
            return CGPoint(x: 0.052, y: mine ? 0.729 : 0.272)

        case .camp(let i):
            let col: CGFloat = (i % 2 == 0) ? 0.150 : 0.232
            let rows: [CGFloat] = mine ? [0.618, 0.795] : [0.209, 0.385]
            return CGPoint(x: col, y: rows[min(i / 2, 1)])

        case .manaPool:
            return CGPoint(x: 0.329, y: mine ? 0.871 : 0.107)

        case .hand:
            return CGPoint(x: mine ? 0.520 : 0.535, y: mine ? 0.887 : 0.103)

        case .relic(let i):
            // The two Relic boxes are printed slightly staggered, not level.
            let slots: [CGPoint] = mine
                ? [CGPoint(x: 0.703, y: 0.883), CGPoint(x: 0.773, y: 0.895)]
                : [CGPoint(x: 0.709, y: 0.110), CGPoint(x: 0.778, y: 0.101)]
            return slots[min(i, 1)]

        case .altar:
            return CGPoint(x: 0.771, y: mine ? 0.635 : 0.344)

        case .event(let i):
            // Reading down the column: foe 1, foe 2, shared 3, your 2, your 1.
            let ys: [CGFloat] = mine ? [0.792, 0.646, 0.502] : [0.211, 0.355, 0.502]
            return CGPoint(x: 0.893, y: ys[min(i, 2)])

        case .element(let e):
            let cols: [CGFloat] = mine ? [0.842, 0.893, 0.952] : [0.841, 0.893, 0.948]
            let i = [Element.air, .land, .sea].firstIndex(of: e) ?? 0
            return CGPoint(x: cols[i], y: mine ? 0.917 : 0.083)
        }
    }

    /// Frontier is an open band, not printed slots — cards fan from the centre.
    static func frontierCenter(_ i: Int, of count: Int, for side: PlayerSide) -> CGPoint {
        let spacing: CGFloat = 0.075
        let mid = CGFloat(count - 1) / 2
        return CGPoint(x: 0.52 + (CGFloat(i) - mid) * spacing,
                       y: side == .you ? 0.66 : 0.34)
    }

    /// Where one hand card sits, and how far it's tilted.
    struct HandSlot {
        let center: CGPoint
        let angle: Angle
    }

    /// The hand fans in a shallow arc rather than a flat row: cards tilt away
    /// from the middle and the outer ones ride slightly lower, so a full hand of
    /// seven reads as a spread of cards instead of a strip.
    ///
    /// `lifted` is the index of a card currently being picked up. Its neighbours
    /// slide outward to leave a gap, and it straightens up itself.
    static func handSlot(_ i: Int, of count: Int, for side: PlayerSide,
                         lifted: Int? = nil) -> HandSlot {
        let anchor = center(.hand, for: side)
        // 0.075 clears the 0.071 card width, so a small hand doesn't overlap;
        // a full hand fans tighter to stay inside the printed panel.
        let spacing = min(0.075, 0.30 / CGFloat(max(count, 1)))
        let mid = CGFloat(count - 1) / 2
        var offset = CGFloat(i) - mid

        // Make room around the card being picked up.
        if let lifted, lifted != i {
            offset += (i < lifted ? -0.42 : 0.42)
        }

        // Tilt grows with distance from the middle; the arc dips the outer cards.
        let spread = min(CGFloat(count - 1), 6) / 2          // cap the fan at ±3 steps
        let t = spread == 0 ? 0 : offset / spread            // -1 … 1 across the hand
        let tilt = i == lifted ? 0 : t * 7                   // degrees
        let curve: CGFloat = 0.016
        let dip = i == lifted ? 0 : t * t * curve            // outer cards ride lower

        // The arc only ever pushes cards away from the middle of the screen, so
        // the whole fan is nudged back by half the curve to keep the outermost
        // card inside the printed hand panel rather than off the mat edge.
        let dipSign: CGFloat = side == .you ? 1 : -1
        let recentre = -curve / 2 * dipSign

        return HandSlot(center: CGPoint(x: anchor.x + offset * spacing,
                                        y: anchor.y + dip * dipSign + recentre),
                        angle: .degrees(Double(tilt)))
    }

    // MARK: Drop regions
    //
    // Where a dragged card can be released. These are deliberately more generous
    // than the printed slots — a Camp slot is only ~7% of the mat wide, which is
    // about 60pt on a phone, and asking someone to hit that mid-drag would be
    // miserable. Regions are in mat fractions, same space as everything else.

    static func campRegion(_ side: PlayerSide) -> CGRect {
        side == .you ? CGRect(x: 0.10, y: 0.53, width: 0.19, height: 0.36)
                     : CGRect(x: 0.10, y: 0.12, width: 0.19, height: 0.36)
    }

    /// The open green band on one player's half.
    static func frontierRegion(_ side: PlayerSide) -> CGRect {
        side == .you ? CGRect(x: 0.33, y: 0.52, width: 0.38, height: 0.26)
                     : CGRect(x: 0.33, y: 0.22, width: 0.38, height: 0.26)
    }

    static func manaPoolRegion(_ side: PlayerSide) -> CGRect {
        rect(around: center(.manaPool, for: side), width: 0.10, height: 0.24)
    }

    static func altarRegion(_ side: PlayerSide) -> CGRect {
        rect(around: center(.altar, for: side), width: 0.13, height: 0.26)
    }

    /// Both Relic boxes as one target — which slot a Relic lands in is the
    /// engine's business, not the player's.
    static func relicRegion(_ side: PlayerSide) -> CGRect {
        let a = center(.relic(0), for: side), b = center(.relic(1), for: side)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        return rect(around: mid, width: abs(b.x - a.x) + cardSize.width + 0.02,
                    height: cardSize.height + 0.04)
    }

    private static func rect(around c: CGPoint, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: c.x - width / 2, y: c.y - height / 2, width: width, height: height)
    }

    // MARK: Mapping to the screen

    /// The aspect-fit rect of the mat inside a view, plus fraction → point
    /// conversion. Everything on the board goes through this.
    struct Frame {
        let origin: CGPoint
        let size: CGSize

        init(in bounds: CGSize) {
            var w = bounds.width, h = bounds.width / MatLayout.aspect
            if h > bounds.height { h = bounds.height; w = bounds.height * MatLayout.aspect }
            size = CGSize(width: w, height: h)
            origin = CGPoint(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2)
        }

        func point(_ f: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + f.x * size.width, y: origin.y + f.y * size.height)
        }

        func point(_ slot: Slot, _ side: PlayerSide) -> CGPoint {
            point(MatLayout.center(slot, for: side))
        }

        /// A fraction-space rect in view points.
        func rect(_ f: CGRect) -> CGRect {
            CGRect(x: origin.x + f.minX * size.width,
                   y: origin.y + f.minY * size.height,
                   width: f.width * size.width,
                   height: f.height * size.height)
        }

        /// A card-sized hit area centred on a point already in view space.
        /// Slightly generous, so a drag doesn't have to land dead centre.
        func cardHitRect(at p: CGPoint) -> CGRect {
            let w = card.width * 1.15, h = card.height * 1.15
            return CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h)
        }

        /// A card drawn at the printed slot size.
        var card: CGSize {
            CGSize(width: MatLayout.cardSize.width * size.width,
                   height: MatLayout.cardSize.height * size.height)
        }

        /// Relics sit in slightly smaller printed boxes than Camp cards.
        var relicCard: CGSize {
            CGSize(width: card.width * 0.94, height: card.height * 0.86)
        }

        /// Scale for text that should grow with the mat.
        func scaled(_ f: CGFloat) -> CGFloat { size.height * f }
    }
}
