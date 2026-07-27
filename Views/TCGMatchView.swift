import SwiftUI
import UIKit

/// Landscape match board laid out on the Playmat V2 template.
/// Tap a hand card to play it; tap a Camp/Frontier card for its actions.
struct TCGMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MatchViewModel()
    @State private var chosen: CardInstance?

    /// Native aspect of Playmat V2 (2286 × 1274).
    private let matAspect: CGFloat = 2286.0 / 1274.0

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width
            ZStack {
                Color(red: 0.12, green: 0.11, blue: 0.10).ignoresSafeArea()

                if portrait {
                    rotateHint
                } else {
                    board(in: geo.size)
                    controls
                    if let c = chosen { actionBar(for: c, in: geo.size) }
                    if vm.awaitingHandoff, vm.winner == nil { handoffOverlay }
                    if let w = vm.winner { resultOverlay(winner: w) }
                }
            }
        }
        .statusBarHidden()
        .onAppear { requestOrientation(.landscape) }
        .onDisappear { requestOrientation(.portrait) }
    }

    private var rotateHint: some View {
        VStack(spacing: 14) {
            Image(systemName: "rotate.right.fill").font(.system(size: 44)).foregroundStyle(Theme.gold)
            Text("Turn your phone sideways").font(.title3.bold()).foregroundStyle(.white)
            Text("The Promised Land is played in landscape.")
                .font(.footnote).foregroundStyle(.white.opacity(0.6))
            Button("Leave") { dismiss() }.padding(.top, 8).foregroundStyle(Theme.gold)
        }
    }

    // MARK: Board

    private func board(in size: CGSize) -> some View {
        // Aspect-fit the mat, then place everything as fractions of that rect.
        var mw = size.width, mh = size.width / matAspect
        if mh > size.height { mh = size.height; mw = size.height * matAspect }
        let ox = (size.width - mw) / 2, oy = (size.height - mh) / 2
        let cardW = mw * 0.082, cardH = mh * 0.19

        func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: ox + fx * mw, y: oy + fy * mh) }

        return ZStack {
            Image("playmat").resizable().scaledToFit()
                .frame(width: mw, height: mh).position(x: ox + mw / 2, y: oy + mh / 2)

            // ── Camps (4 slots each; slot 1 = Guardian) ──
            ForEach(Array(vm.foe.basecamp.prefix(4).enumerated()), id: \.element.id) { i, c in
                card(c, side: .foe, w: cardW, h: cardH)
                    .position(campPoint(i, mine: false, pt: pt))
            }
            ForEach(Array(vm.you.basecamp.prefix(4).enumerated()), id: \.element.id) { i, c in
                card(c, side: .you, w: cardW, h: cardH, guardian: i == 0)
                    .position(campPoint(i, mine: true, pt: pt))
            }

            // ── Frontiers ──
            ForEach(Array(vm.foe.frontier.prefix(5).enumerated()), id: \.element.id) { i, c in
                card(c, side: .foe, w: cardW, h: cardH)
                    .position(frontierPoint(i, count: vm.foe.frontier.count, y: 0.33, pt: pt))
            }
            ForEach(Array(vm.you.frontier.prefix(5).enumerated()), id: \.element.id) { i, c in
                card(c, side: .you, w: cardW, h: cardH)
                    .position(frontierPoint(i, count: vm.you.frontier.count, y: 0.68, pt: pt))
            }

            // ── Relics ──
            ForEach(Array(vm.foe.relics.prefix(2).enumerated()), id: \.element.id) { i, c in
                card(c, side: .foe, w: cardW * 0.9, h: cardH * 0.8)
                    .position(pt(i == 0 ? 0.388 : 0.460, 0.13))
            }
            ForEach(Array(vm.you.relics.prefix(2).enumerated()), id: \.element.id) { i, c in
                card(c, side: .you, w: cardW * 0.9, h: cardH * 0.8)
                    .position(pt(i == 0 ? 0.388 : 0.460, 0.865))
            }

            // ── Hands ── only the ACTIVE player's hand is face-up (hot seat).
            if !vm.awaitingHandoff {
                handStrip(cards: vm.activeBoard.hand, w: cardW, h: cardH, pt: pt)
            }
            counter("\(vm.inactiveBoard.hand.count) cards hidden", pt(0.663, 0.115), mh)

            // ── Deck / discard / altar / mana ──
            counter("\(vm.foe.deck.count)", pt(0.056, 0.26), mh)
            counter("\(vm.you.discard.count + vm.foe.discard.count)", pt(0.056, 0.50), mh)
            counter("\(vm.you.deck.count)", pt(0.056, 0.72), mh)
            manaHex("\(vm.foe.mana)/\(vm.foe.berries)", pt(0.055, 0.09), mh)
            manaHex("\(vm.you.mana)/\(vm.you.berries)", pt(0.055, 0.906), mh)
            counter("\(vm.you.altar.count)", pt(0.757, 0.49), mh)

            // ── Events column ── one Event at a time per player, plus the
            // shared finale in the middle (a `?` until someone unlocks it).
            eventBadge(currentEvent(vm.foe), pt(0.888, 0.20), mh)
            eventBadge(vm.you.events.count > 2 ? vm.you.events[2] : nil, pt(0.888, 0.50), mh)
            eventBadge(currentEvent(vm.you), pt(0.888, 0.80), mh)

            // ── Element counters (Air · Land · Sea) ──
            counter("\(vm.you.elements[.air] ?? 0)", pt(0.845, 0.937), mh)
            counter("\(vm.you.elements[.land] ?? 0)", pt(0.900, 0.937), mh)
            counter("\(vm.you.elements[.sea] ?? 0)", pt(0.955, 0.937), mh)
        }
    }

    /// The Event this player is currently racing, unless it's the shared finale
    /// (which gets its own badge in the middle of the column).
    private func currentEvent(_ b: PlayerBoard) -> EventProgress? {
        guard let i = b.currentEventIndex, i < 2 else { return nil }
        return b.events[i]
    }

    private func campPoint(_ i: Int, mine: Bool, pt: (CGFloat, CGFloat) -> CGPoint) -> CGPoint {
        let xs: [CGFloat] = [0.178, 0.276, 0.178, 0.276]
        let ys: [CGFloat] = mine ? [0.62, 0.62, 0.80, 0.80] : [0.16, 0.16, 0.39, 0.39]
        return pt(xs[i], ys[i])
    }

    private func frontierPoint(_ i: Int, count: Int, y: CGFloat, pt: (CGFloat, CGFloat) -> CGPoint) -> CGPoint {
        let spacing: CGFloat = 0.088
        let mid = CGFloat(count - 1) / 2
        return pt(0.52 + (CGFloat(i) - mid) * spacing, y)
    }

    private func handStrip(cards: [CardInstance], w: CGFloat, h: CGFloat,
                           pt: @escaping (CGFloat, CGFloat) -> CGPoint) -> some View {
        let spacing: CGFloat = min(0.072, 0.28 / CGFloat(max(cards.count, 1)))
        let mid = CGFloat(cards.count - 1) / 2
        return ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in
            MiniCard(inst: c, w: w, h: h, showCost: true,
                     cost: vm.effectiveCost(c.card, for: vm.activeBoard),
                     selected: chosen?.id == c.id,
                     playable: vm.canPlay(c, on: vm.turnSide))
                // Tap to select — the action bar offers Play or Eat.
                .onTapGesture { chosen = (chosen?.id == c.id) ? nil : c }
                .position(pt(0.665 + (CGFloat(i) - mid) * spacing, 0.897))
        }
    }

    @ViewBuilder
    private func card(_ inst: CardInstance, side: PlayerSide, w: CGFloat, h: CGFloat,
                      guardian: Bool = false) -> some View {
        MiniCard(inst: inst, w: w, h: h, selected: chosen?.id == inst.id, guardian: guardian)
            .onTapGesture { tap(inst, side: side) }
    }

    // MARK: Small board widgets

    private func counter(_ text: String, _ p: CGPoint, _ mh: CGFloat) -> some View {
        Text(text)
            .font(.system(size: mh * 0.032, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, mh * 0.016).padding(.vertical, mh * 0.008)
            .background(Color.black.opacity(0.45), in: Capsule())
            .position(p)
    }

    private func manaHex(_ text: String, _ p: CGPoint, _ mh: CGFloat) -> some View {
        Text(text)
            .font(.system(size: mh * 0.038, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, mh * 0.02).padding(.vertical, mh * 0.008)
            .background(Color(red: 0.20, green: 0.45, blue: 0.72).opacity(0.9), in: Capsule())
            .position(p)
    }

    @ViewBuilder
    private func eventBadge(_ ev: EventProgress?, _ p: CGPoint, _ mh: CGFloat) -> some View {
        if let ev {
            HStack(spacing: mh * 0.008) {
                if ev.cleared {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.sage)
                        .font(.system(size: mh * 0.05))
                } else if !ev.revealed {
                    Image(systemName: "questionmark.circle.fill").foregroundStyle(.white.opacity(0.7))
                        .font(.system(size: mh * 0.05))
                } else {
                    ForEach(Array(ev.card.requirement.enumerated()), id: \.offset) { _, r in
                        HStack(spacing: 0) {
                            Image(systemName: r.element.icon).font(.system(size: mh * 0.026))
                            Text("\(r.count)").font(.system(size: mh * 0.03, weight: .heavy))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, mh * 0.01).padding(.vertical, mh * 0.004)
                        .background(r.element.color.opacity(0.95), in: Capsule())
                    }
                }
            }
            .padding(.horizontal, mh * 0.01).padding(.vertical, mh * 0.006)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: mh * 0.02))
            .position(p)
        }
    }

    // MARK: Controls / actions

    private var controls: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                        .foregroundStyle(.white.opacity(0.8)).shadow(radius: 3)
                }
                Spacer()
                Text("\(vm.name(of: vm.turnSide)) · Turn \(vm.turnNumber)").font(.caption.bold())
                    .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                    .background((vm.turnSide == .you ? Theme.sage : Theme.clay).opacity(0.9), in: Capsule())
                Button { vm.endTurn(); chosen = nil } label: {
                    Text("End Turn").font(.subheadline.bold())
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Theme.sage, in: Capsule())
                        .foregroundStyle(.white)
                }
                .disabled(vm.awaitingHandoff)
            }
            Spacer()
            HStack {
                Text(vm.log.last ?? "").font(.caption2).foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.black.opacity(0.45), in: Capsule())
                Spacer()
            }
        }
        .padding(10)
    }

    private func actionBar(for c: CardInstance, in size: CGSize) -> some View {
        let side = vm.turnSide
        return HStack(spacing: 10) {
            if c.zone == .hand {
                if vm.canPlay(c, on: side) {
                    actionButton("Play", "hand.tap.fill") { vm.play(c, on: side); chosen = nil }
                }
                if vm.canEat(c, on: side) {
                    actionButton("Eat", "leaf.fill") { vm.eat(c, on: side); chosen = nil }
                }
                if !vm.canPlay(c, on: side) && !vm.canEat(c, on: side) {
                    Text(vm.activeBoard.ateThisTurn ? "Already ate this turn" : "Not enough mana")
                        .font(.caption2.bold()).foregroundStyle(.white)
                }
            } else if c.zone == .basecamp {
                if vm.canMarch(c, on: side) { actionButton("March", "figure.walk") { vm.march(c, on: side); chosen = nil } }
                if vm.canSacrifice(c, on: side) { actionButton("Sacrifice", "flame.fill") { vm.sacrifice(c, on: side); chosen = nil } }
            } else if c.zone == .frontier {
                if c.canAct && (vm.inactiveBoard.frontier.isEmpty || c.unblockable) {
                    actionButton("Raid", "bolt.fill") { vm.attack(c, target: nil, on: side); chosen = nil }
                } else if c.canAct {
                    Text("Tap an enemy").font(.caption2.bold()).foregroundStyle(.white)
                }
                if vm.canSacrifice(c, on: side) { actionButton("Sacrifice", "flame.fill") { vm.sacrifice(c, on: side); chosen = nil } }
            }
            actionButton("Cancel", "xmark") { chosen = nil }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .position(x: size.width / 2, y: size.height * 0.5)
    }

    private func actionButton(_ title: String, _ icon: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Label(title, systemImage: icon).font(.caption2.bold())
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.bark.opacity(0.85), in: Capsule())
                .foregroundStyle(.white)
        }
    }

    /// `side` is the owner of the tapped card. You act on your own cards and
    /// attack the other side's Frontier.
    private func tap(_ inst: CardInstance, side: PlayerSide) {
        guard vm.winner == nil, !vm.awaitingHandoff else { return }
        if side != vm.turnSide {
            if let atk = chosen, atk.zone == .frontier, inst.zone == .frontier {
                vm.attack(atk, target: inst, on: vm.turnSide); chosen = nil
            }
            return
        }
        chosen = (chosen?.id == inst.id) ? nil : inst
    }

    /// Shown between turns so the next player can take the phone without
    /// seeing the previous player's hand.
    private var handoffOverlay: some View {
        let next = vm.turnSide == .you ? PlayerSide.foe : PlayerSide.you
        return ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill").font(.system(size: 40)).foregroundStyle(Theme.gold)
                Text("Pass the phone to \(vm.name(of: next))")
                    .font(.title2.bold()).foregroundStyle(.white)
                Text("Hands are hidden until you're ready.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
                Button { vm.confirmHandoff(); chosen = nil } label: {
                    Text("I'm \(vm.name(of: next)) — Ready")
                        .font(.headline).padding(.horizontal, 26).padding(.vertical, 12)
                        .background(Theme.sage, in: Capsule()).foregroundStyle(.white)
                }
            }
        }
    }

    private func resultOverlay(winner: PlayerSide) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("\(vm.name(of: winner)) Wins")
                    .font(.system(size: 40, weight: .black, design: .serif))
                    .foregroundStyle(Theme.gold)
                Text(vm.log.last ?? "").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                Button { dismiss() } label: {
                    Text("Done").font(.headline).padding(.horizontal, 30).padding(.vertical, 10)
                        .background(Theme.sage, in: Capsule()).foregroundStyle(.white)
                }
            }
        }
    }

    private func requestOrientation(_ mask: UIInterfaceOrientationMask) {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

// MARK: - Mini card

private struct MiniCard: View {
    let inst: CardInstance
    var w: CGFloat = 58
    var h: CGFloat = 80
    var showCost: Bool = false
    /// Cost after Guard/Relic discounts — may be lower than the printed cost.
    var cost: Int? = nil
    var selected: Bool = false
    var playable: Bool = false
    var guardian: Bool = false

    var body: some View {
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
                    if inst.shield { Image(systemName: "shield.fill").font(.system(size: h * 0.12)).foregroundStyle(.cyan) }
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
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: h * 0.08, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: h * 0.08).strokeBorder(
            selected ? Theme.gold : (playable ? Color.green : (guardian ? Color.orange.opacity(0.9) : Color.black.opacity(0.35))),
            lineWidth: selected || playable || guardian ? 2.5 : 1))
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    private func pip(_ s: String, _ c: Color) -> some View {
        Text(s).font(.system(size: h * 0.15, weight: .black, design: .rounded)).foregroundStyle(.white)
            .frame(width: h * 0.23, height: h * 0.23).background(Circle().fill(c))
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
    }
}
