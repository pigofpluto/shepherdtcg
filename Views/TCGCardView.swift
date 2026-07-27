import SwiftUI
import UIKit

// MARK: - Display helpers

extension Discipline {
    /// Face color for the discipline gem, frame accent, and placeholder tint.
    var color: Color {
        switch self {
        case .wisdom:   return Color(red: 0.22, green: 0.40, blue: 0.68)  // blue
        case .courage:  return Color(red: 0.72, green: 0.20, blue: 0.20)  // crimson
        case .strength: return Color(red: 0.82, green: 0.52, blue: 0.16)  // amber
        }
    }

    var icon: String {
        switch self {
        case .wisdom:   return "book.closed.fill"
        case .courage:  return "shield.fill"
        case .strength: return "hand.raised.fill"
        }
    }
}

extension Element {
    var color: Color {
        switch self {
        case .air:  return Color(red: 0.42, green: 0.66, blue: 0.86)  // sky
        case .sea:  return Color(red: 0.16, green: 0.48, blue: 0.60)  // deep teal
        case .land: return Color(red: 0.44, green: 0.54, blue: 0.26)  // earthy green
        }
    }

    var icon: String {
        switch self {
        case .air:  return "wind"
        case .sea:  return "water.waves"
        case .land: return "mountain.2.fill"
        }
    }
}

extension TCGCardType {
    var icon: String {
        switch self {
        case .human:    return "person.fill"
        case .creature: return "pawprint.fill"
        case .event:    return "map.fill"
        case .relic:    return "wand.and.stars"
        }
    }
}

extension TCGCard {
    /// Accent used for frame borders and placeholders — discipline (Humans),
    /// element (Creatures), else gold (Relics/Events).
    var accent: Color { discipline?.color ?? element?.color ?? Theme.gold }
}

// MARK: - Card face

/// Renders one TCG card. Humans and Creatures use the ornate `card_frame`
/// overlay with the portrait shown in its oval window; Events and Relics use a
/// simpler procedural face. Real portrait art loads from `UIImage(named: card.id)`.
struct TCGCardView: View {
    let card: TCGCard

    /// Portrait aspect of the Human / Creature / Relic frames (1760×2396).
    static let portraitAspect: CGFloat = 1760.0 / 2396.0
    /// Landscape aspect of the event banner border (1200×896).
    static let eventAspect: CGFloat = 1200.0 / 896.0

    /// Card shape depends on type: events are landscape, everything else portrait.
    private var aspect: CGFloat { card.type == .event ? Self.eventAspect : Self.portraitAspect }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Group {
                switch card.type {
                case .human:    framedFace(w: w, h: h, frame: "card_frame")
                case .creature: framedFace(w: w, h: h, frame: "card_frame_animal")
                case .event:    eventFace(w: w, h: h)
                case .relic:    proceduralFace(w: w)
                }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
    }

    // MARK: Framed face (Humans & Creatures)

    // Layout anchors as fractions of the card, matched to the overlay art.
    // Humans use the gold `card_frame`; Creatures the green `card_frame_animal`
    // (asset name is historical — same slot geometry, transparent oval on both).
    private func framedFace(w: CGFloat, h: CGFloat, frame: String) -> some View {
        let ovalW = 0.635 * w, ovalH = 0.470 * h
        return ZStack {
            // Portrait in the oval window (top-aligned so faces show; placeholder until art arrives).
            Group {
                if let img = UIImage(named: card.id) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    TCGProceduralArt(card: card)
                }
            }
            .frame(width: ovalW, height: ovalH, alignment: .top)
            .clipShape(Ellipse())
            .position(x: 0.500 * w, y: 0.247 * h)

            // The ornate frame (its oval + card corners are cut to transparency,
            // so the portrait behind shows through).
            Image(frame).resizable().interpolation(.high)

            // Stat numbers, centered on the frame's gems (centroids measured from the art).
            statNumber(card.cost, w: w).position(x: 0.157 * w, y: 0.119 * h)   // blue = cost
            statNumber(card.attack, w: w).position(x: 0.168 * w, y: 0.886 * h) // green = attack
            statNumber(card.health, w: w).position(x: 0.874 * w, y: 0.835 * h) // red = heart body

            // Name on the gold banner — arched (concave-down) so it sits nicely in the ribbon.
            CurvedText(text: card.name, fontSize: 0.086 * w, radius: 1.3 * w,
                       color: Color(red: 0.26, green: 0.15, blue: 0.06), maxWidth: 0.52 * w)
                .position(x: 0.515 * w, y: 0.533 * h)

            // Discipline (human) or element (creature) chip, atop the parchment.
            disciplineChip(w: w).position(x: 0.500 * w, y: 0.640 * h)

            // Ability text on the parchment panel.
            if !card.ability.isEmpty {
                Text(card.ability)
                    .font(.system(size: 0.044 * w, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineLimit(4).minimumScaleFactor(0.4)
                    .frame(width: 0.62 * w)
                    .position(x: 0.500 * w, y: 0.795 * h)
            }
        }
    }

    // Small pill showing the human's discipline or the creature's element.
    @ViewBuilder
    private func disciplineChip(w: CGFloat) -> some View {
        let info: (String, String, Color)? = {
            if let c = card.discipline { return (c.icon, c.displayName, c.color) }
            if let e = card.element { return (e.icon, e.displayName, e.color) }
            return nil
        }()
        if let (icon, label, color) = info {
            HStack(spacing: 0.02 * w) {
                Image(systemName: icon).font(.system(size: 0.042 * w, weight: .bold))
                Text(label).font(.system(size: 0.046 * w, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 0.035 * w).padding(.vertical, 0.012 * w)
            .background(color.opacity(0.92), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1)
        }
    }

    private func statNumber(_ value: Int, w: CGFloat) -> some View {
        Text("\(value)")
            .font(.system(size: 0.10 * w, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.65), radius: 0.5, y: 1)
    }

    // MARK: Event face (landscape banner border)

    private func eventFace(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // Art over-fills the transparent window (measured x[0.107,0.894] y[0.166,0.849])
            // so no card background peeks out; the frame masks the overflow.
            Group {
                if let img = UIImage(named: card.id) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    TCGProceduralArt(card: card)
                }
            }
            .frame(width: 0.82 * w, height: 0.74 * h)
            .clipShape(RoundedRectangle(cornerRadius: 0.02 * w, style: .continuous))
            .position(x: 0.500 * w, y: 0.500 * h)

            // Ornate landscape border with the gold ribbon banner at top.
            Image("card_frame_event").resizable().interpolation(.high)

            // Name on the banner — arched (concave-down) to follow the ribbon.
            CurvedText(text: card.name, fontSize: 0.056 * w, radius: 1.0 * w,
                       color: Color(red: 0.26, green: 0.15, blue: 0.06), maxWidth: 0.42 * w)
                .position(x: 0.500 * w, y: 0.120 * h)

            // Element requirement pips (what you need to overcome it), over a scrim.
            HStack(spacing: 0.02 * w) {
                ForEach(Array(card.requirement.enumerated()), id: \.offset) { _, req in
                    HStack(spacing: 0.008 * w) {
                        Image(systemName: req.element.icon).font(.system(size: 0.04 * w, weight: .bold))
                        Text("×\(req.count)").font(.system(size: 0.044 * w, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 0.025 * w).padding(.vertical, 0.014 * w)
                    .background(req.element.color.opacity(0.92), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            .position(x: 0.500 * w, y: 0.80 * h)
        }
    }

    // MARK: Relic face (procedural)

    private func proceduralFace(w: CGFloat) -> some View {
        ZStack {
            artLayer(w: w)

            LinearGradient(
                colors: [.clear, .black.opacity(0.40), .black.opacity(0.88)],
                startPoint: .center, endPoint: .bottom)

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: w * 0.015) {
                    Text(card.name)
                        .font(.system(size: w * 0.10, weight: .black, design: .serif))
                        .foregroundStyle(.white).shadow(radius: 4)
                        .lineLimit(2).minimumScaleFactor(0.6)
                    Label(card.type.displayName, systemImage: card.type.icon)
                        .font(.system(size: w * 0.05, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    if !card.ability.isEmpty {
                        Text(card.ability)
                            .font(.system(size: w * 0.044, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(5).minimumScaleFactor(0.55)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, w * 0.16)
            }
            .padding(w * 0.06)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    gem(value: card.cost, icon: "drop.fill",
                        color: Color(red: 0.20, green: 0.45, blue: 0.72), w: w)
                }
            }
            .padding(w * 0.05)
        }
        .clipShape(RoundedRectangle(cornerRadius: w * 0.07, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: w * 0.07, style: .continuous)
            .strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: w * 0.07, style: .continuous)
            .strokeBorder(card.accent.opacity(0.75), lineWidth: 2.5).blur(radius: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
    }

    // A circular stat gem with an icon and a number.
    private func gem(value: Int, icon: String, color: Color, w: CGFloat) -> some View {
        ZStack {
            Circle().fill(color)
                .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            VStack(spacing: -w * 0.01) {
                Image(systemName: icon).font(.system(size: w * 0.05, weight: .bold))
                Text("\(value)").font(.system(size: w * 0.09, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
        }
        .frame(width: w * 0.20, height: w * 0.20)
    }

    // Real art if an asset named after the card id exists; otherwise placeholder.
    @ViewBuilder
    private func artLayer(w: CGFloat) -> some View {
        if let img = UIImage(named: card.id) {
            Image(uiImage: img).resizable().scaledToFill().clipped()
        } else {
            TCGProceduralArt(card: card)
        }
    }
}

// MARK: - Procedural placeholder

/// A polished, category-tinted stand-in shown until real oil-painting art is
/// dropped into Assets.xcassets under the card's id.
struct TCGProceduralArt: View {
    let card: TCGCard

    var body: some View {
        GeometryReader { geo in
            let accent = card.accent
            var rng = SeededRNG(seed: UInt64(bitPattern: Int64(card.id.hashValue)))
            let glowX = 0.3 + 0.4 * rng.unit()

            ZStack {
                // Base vertical gradient.
                LinearGradient(
                    colors: [accent.darker, accent.opacity(0.85), accent.darker.opacity(0.9)],
                    startPoint: .top, endPoint: .bottom)

                // Soft light glow, positioned by the seed.
                RadialGradient(
                    colors: [.white.opacity(0.35), .clear],
                    center: UnitPoint(x: glowX, y: 0.28),
                    startRadius: 0, endRadius: geo.size.width * 0.7)

                // Large faint discipline/element/type watermark.
                Image(systemName: card.discipline?.icon ?? card.element?.icon ?? card.type.icon)
                    .font(.system(size: geo.size.width * 0.62, weight: .black))
                    .foregroundStyle(.white.opacity(0.12))
                    .rotationEffect(.degrees(-8 + 16 * rng.unit()))
                    .offset(y: -geo.size.height * 0.05)

                // Vignette.
                RadialGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    center: .center,
                    startRadius: geo.size.width * 0.3, endRadius: geo.size.width * 0.75)
            }
        }
    }
}

// MARK: - Curved text

/// Lays each glyph along a shallow circular arc so a name follows a banner's curve,
/// auto-shrinking to fit `maxWidth`. `radius` sign sets concavity:
/// positive = arch (ends dip down), negative = sag/smile (ends rise up).
struct CurvedText: View {
    let text: String
    var fontSize: CGFloat
    var weight: Font.Weight = .heavy
    var radius: CGFloat
    var color: Color = .black
    var maxWidth: CGFloat

    private struct Glyph: Identifiable { let id: Int; let ch: String; let x: CGFloat; let y: CGFloat; let angle: Double }

    var body: some View {
        let layout = makeLayout()
        return ZStack {
            ForEach(layout.glyphs) { g in
                Text(g.ch)
                    .font(.system(size: layout.size, weight: weight, design: .serif))
                    .foregroundStyle(color)
                    .rotationEffect(.radians(g.angle))
                    .offset(x: g.x, y: g.y)
            }
        }
        .frame(width: maxWidth, height: fontSize * 1.9)
    }

    private func uiWeight() -> UIFont.Weight {
        switch weight {
        case .black: return .black
        case .heavy: return .heavy
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        default: return .regular
        }
    }

    private func serifFont(_ size: CGFloat) -> UIFont {
        let f = UIFont.systemFont(ofSize: size, weight: uiWeight())
        if let d = f.fontDescriptor.withDesign(.serif) { return UIFont(descriptor: d, size: size) }
        return f
    }

    private func makeLayout() -> (size: CGFloat, glyphs: [Glyph]) {
        let chars = text.map { String($0) }
        var size = fontSize
        var widths = chars.map { ($0 as NSString).size(withAttributes: [.font: serifFont(size)]).width }
        var total = widths.reduce(0, +)
        if total > maxWidth, total > 0 {
            let scale = maxWidth / total
            size *= scale
            widths = chars.map { ($0 as NSString).size(withAttributes: [.font: serifFont(size)]).width }
            total = widths.reduce(0, +)
        }
        var cum: CGFloat = 0
        var glyphs: [Glyph] = []
        for (i, ch) in chars.enumerated() {
            let centerOffset = cum + widths[i] / 2 - total / 2
            let angle = Double(centerOffset / radius)
            glyphs.append(Glyph(id: i, ch: ch,
                                x: radius * CGFloat(sin(angle)),
                                y: radius - radius * CGFloat(cos(angle)),
                                angle: angle))
            cum += widths[i]
        }
        return (size, glyphs)
    }
}

// MARK: - Small color utilities

private extension Color {
    var darker: Color { blend(with: .black, amount: 0.45) }
    var lighter: Color { blend(with: .white, amount: 0.35) }

    func blend(with other: Color, amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let t = CGFloat(amount)
        return Color(red: Double(ar + (br - ar) * t),
                     green: Double(ag + (bg - ag) * t),
                     blue: Double(ab + (bb - ab) * t))
    }
}
