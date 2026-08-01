import SwiftUI
import UIKit

/// Landscape match board laid out on the Playmat V3 template.
/// Tap a hand card to play it; tap a Camp/Frontier card for its actions.
///
/// Every position comes from `MatLayout`, and every card carries a
/// `matchedGeometryEffect` keyed on its `CardInstance.id`, so a card moving
/// between zones slides instead of disappearing and reappearing. The engine
/// pauses between steps (see `MatchViewModel.beat`), which is what gives the
/// board time to show each one.
struct TCGMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MatchViewModel()
    @State private var chosen: CardInstance?
    /// Shared by every zone so cards can fly between them.
    @Namespace private var cardNS

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width
            ZStack {
                Color(red: 0.12, green: 0.11, blue: 0.10).ignoresSafeArea()

                if portrait {
                    rotateHint
                } else {
                    let f = MatLayout.Frame(in: geo.size)
                    board(f)
                    logLine(f)
                    CueOverlay(cues: vm.cues,
                               anchor: { cueAnchor($0, f) },
                               scale: f.size.height)
                    controls
                    if let c = chosen, !vm.busy { actionBar(for: c, in: geo.size) }
                    if vm.awaitingHandoff, vm.winner == nil { handoffOverlay }
                    if let w = vm.winner { resultOverlay(winner: w) }
                }
            }
        }
        .statusBarHidden()
        .onAppear { requestOrientation(.landscape) }
        .onDisappear { requestOrientation(.portrait) }
        // A locked board can't have a live selection.
        .onChange(of: vm.busy) { _, busy in if busy { chosen = nil } }
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

    private func board(_ f: MatLayout.Frame) -> some View {
        ZStack {
            Image("playmat").resizable().scaledToFit()
                .frame(width: f.size.width, height: f.size.height)
                .position(x: f.origin.x + f.size.width / 2, y: f.origin.y + f.size.height / 2)

            ForEach([PlayerSide.foe, .you], id: \.self) { side in
                piles(side, f)
                camp(side, f)
                frontier(side, f)
                relics(side, f)
                hand(side, f)
                readouts(side, f)
            }

            events(f)
            endRock(f)
        }
    }

    /// Deck, Discard and Altar — the destinations that make draw, death and
    /// Sacrifice animations possible.
    @ViewBuilder
    private func piles(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)

        DeckStack(count: b.deck.count, size: f.card)
            .position(f.point(.deck, side))

        CardStack(cards: b.discard, size: f.card, namespace: cardNS)
            .position(f.point(.discard, side))

        AltarStack(cards: b.altar, size: f.card, namespace: cardNS)
            .position(f.point(.altar, side))
    }

    @ViewBuilder
    private func camp(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        ForEach(Array(b.basecamp.prefix(4).enumerated()), id: \.element.id) { i, c in
            card(c, side: side, size: f.card, guardian: i == 0)
                .position(f.point(.camp(i), side))
        }
    }

    @ViewBuilder
    private func frontier(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        ForEach(Array(b.frontier.prefix(5).enumerated()), id: \.element.id) { i, c in
            card(c, side: side, size: f.card)
                .offset(lungeOffset(for: c, f))
                .position(f.point(MatLayout.frontierCenter(i, of: b.frontier.count, for: side)))
        }
    }

    @ViewBuilder
    private func relics(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        ForEach(Array(b.relics.prefix(2).enumerated()), id: \.element.id) { i, c in
            card(c, side: side, size: f.relicCard)
                .position(f.point(.relic(i), side))
        }
    }

    /// Only the active player's hand is face-up — this is a hot-seat game.
    @ViewBuilder
    private func hand(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        let open = side == vm.turnSide && !vm.awaitingHandoff
        ForEach(Array(b.hand.enumerated()), id: \.element.id) { i, c in
            MiniCard(inst: c, w: f.card.width, h: f.card.height,
                     showCost: open,
                     cost: open ? vm.effectiveCost(c.card, for: b) : nil,
                     selected: chosen?.id == c.id,
                     playable: open && vm.canPlay(c, on: side),
                     faceDown: !open,
                     dying: isDying(c))
                .matchedGeometryEffect(id: c.id, in: cardNS)
                .onTapGesture { if open { chosen = (chosen?.id == c.id) ? nil : c } }
                .position(f.point(MatLayout.handCenter(i, of: b.hand.count, for: side)))
        }
    }

    /// Mana / berries beside the Frontier, plus the three element counters.
    @ViewBuilder
    private func readouts(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        manaHex("\(b.mana)/\(b.berries)", f.point(.mana, side), f)
        ForEach([Element.air, .land, .sea], id: \.self) { e in
            counter("\(b.elements[e] ?? 0)", f.point(.element(e), side), f)
        }
    }

    /// Five printed slots: foe 1·2 down the top, the shared finale in the
    /// middle, your 2·1 along the bottom.
    @ViewBuilder
    private func events(_ f: MatLayout.Frame) -> some View {
        ForEach([PlayerSide.foe, .you], id: \.self) { side in
            let b = vm.board(side)
            ForEach(0..<2, id: \.self) { i in
                if b.events.indices.contains(i) {
                    eventBadge(b.events[i], f.point(.event(i), side), f)
                }
            }
        }
        if vm.you.events.count > 2 {
            eventBadge(vm.you.events[2], f.point(.event(2), .you), f)
        }
    }

    /// The END rock on the mat is the end-turn button.
    private func endRock(_ f: MatLayout.Frame) -> some View {
        let live = vm.winner == nil && !vm.awaitingHandoff && !vm.busy
        return Button {
            Task { await vm.endTurn() }
            chosen = nil
        } label: {
            RoundedRectangle(cornerRadius: f.scaled(0.02), style: .continuous)
                .fill(Theme.sage.opacity(live ? 0.28 : 0))
                .overlay(RoundedRectangle(cornerRadius: f.scaled(0.02))
                    .strokeBorder(Theme.gold.opacity(live ? 0.85 : 0), lineWidth: 2))
                .frame(width: f.size.width * 0.085, height: f.size.height * 0.17)
        }
        .disabled(!live)
        .position(f.point(.end, .you))
    }

    @ViewBuilder
    private func card(_ inst: CardInstance, side: PlayerSide, size: CGSize,
                      guardian: Bool = false) -> some View {
        MiniCard(inst: inst, w: size.width, h: size.height,
                 selected: chosen?.id == inst.id, guardian: guardian,
                 dying: isDying(inst))
            .matchedGeometryEffect(id: inst.id, in: cardNS)
            .onTapGesture { tap(inst, side: side) }
    }

    // MARK: Animation support

    /// A card the engine has marked for death this beat.
    private func isDying(_ inst: CardInstance) -> Bool {
        vm.cues.contains { $0.card == inst.id && $0.isDeath }
    }

    /// While an attack is in flight the attacker leans a third of the way
    /// toward whatever it's hitting.
    private func lungeOffset(for inst: CardInstance, _ f: MatLayout.Frame) -> CGSize {
        guard let l = vm.lunge, l.attacker == inst.id,
              let from = position(of: inst.id, f),
              let target = l.target, let to = position(of: target, f) else { return .zero }
        return CGSize(width: (to.x - from.x) * 0.33, height: (to.y - from.y) * 0.33)
    }

    /// Where a card currently sits on the mat, whichever zone it's in.
    private func position(of id: UUID, _ f: MatLayout.Frame) -> CGPoint? {
        for side in [PlayerSide.you, .foe] {
            let b = vm.board(side)
            if let i = b.basecamp.firstIndex(where: { $0.id == id }) {
                return f.point(.camp(min(i, 3)), side)
            }
            if let i = b.frontier.firstIndex(where: { $0.id == id }) {
                return f.point(MatLayout.frontierCenter(i, of: b.frontier.count, for: side))
            }
            if let i = b.relics.firstIndex(where: { $0.id == id }) {
                return f.point(.relic(min(i, 1)), side)
            }
            if let i = b.hand.firstIndex(where: { $0.id == id }) {
                return f.point(MatLayout.handCenter(i, of: b.hand.count, for: side))
            }
            if b.altar.contains(where: { $0.id == id }) { return f.point(.altar, side) }
            if b.discard.contains(where: { $0.id == id }) { return f.point(.discard, side) }
        }
        return nil
    }

    /// Card-tagged cues sit on their card; board-level ones sit on the counter
    /// they affect.
    private func cueAnchor(_ cue: VisualCue, _ f: MatLayout.Frame) -> CGPoint? {
        if let id = cue.card { return position(of: id, f) }
        switch cue.kind {
        case .points(let e, _): return f.point(.element(e), cue.side)
        case .berry:            return f.point(.mana, cue.side)
        default:                return nil
        }
    }

    // MARK: Small board widgets

    private func counter(_ text: String, _ p: CGPoint, _ f: MatLayout.Frame) -> some View {
        Text(text)
            .font(.system(size: f.scaled(0.036), weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .padding(.horizontal, f.scaled(0.014)).padding(.vertical, f.scaled(0.006))
            .background(Color.black.opacity(0.5), in: Capsule())
            .position(p)
    }

    private func manaHex(_ text: String, _ p: CGPoint, _ f: MatLayout.Frame) -> some View {
        Text(text)
            .font(.system(size: f.scaled(0.045), weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .padding(.horizontal, f.scaled(0.02)).padding(.vertical, f.scaled(0.008))
            .background(Color(red: 0.10, green: 0.35, blue: 0.60).opacity(0.85), in: Capsule())
            .position(p)
    }

    @ViewBuilder
    private func eventBadge(_ ev: EventProgress, _ p: CGPoint, _ f: MatLayout.Frame) -> some View {
        HStack(spacing: f.scaled(0.008)) {
            if ev.cleared {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.sage)
                    .font(.system(size: f.scaled(0.055)))
            } else if !ev.revealed {
                Image(systemName: "questionmark.circle.fill").foregroundStyle(.white.opacity(0.7))
                    .font(.system(size: f.scaled(0.055)))
            } else {
                ForEach(Array(ev.card.requirement.enumerated()), id: \.offset) { _, r in
                    HStack(spacing: 0) {
                        Image(systemName: r.element.icon).font(.system(size: f.scaled(0.026)))
                        Text("\(r.count)").font(.system(size: f.scaled(0.032), weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, f.scaled(0.010)).padding(.vertical, f.scaled(0.004))
                    .background(r.element.color.opacity(0.95), in: Capsule())
                }
            }
        }
        .padding(.horizontal, f.scaled(0.010)).padding(.vertical, f.scaled(0.006))
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: f.scaled(0.02)))
        .scaleEffect(ev.cleared ? 1.0 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: ev.cleared)
        .position(p)
    }

    // MARK: Controls / actions

    /// The mat is aspect-fit, so it letterboxes at the sides in landscape.
    /// Chrome lives in that margin — anything placed over the mat itself covers
    /// a printed slot (the turn pill used to sit on the foe's element counters,
    /// and the log line on your deck count).
    private var controls: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2)
                            .foregroundStyle(.white.opacity(0.8)).shadow(radius: 3)
                    }
                    Text("\(vm.name(of: vm.turnSide))\nTurn \(vm.turnNumber)")
                        .font(.caption2.bold()).multilineTextAlignment(.center)
                        .foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 5)
                        .background((vm.turnSide == .you ? Theme.sage : Theme.clay).opacity(0.92),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Spacer()
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    /// The match log rides the printed "Frontier" divider across the middle of
    /// the mat — the one band that never holds a card. It steps aside for the
    /// action bar, which claims the same spot when a card is selected.
    @ViewBuilder
    private func logLine(_ f: MatLayout.Frame) -> some View {
        if chosen == nil, let last = vm.log.last {
            Text(last)
                .font(.system(size: f.scaled(0.036), weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .padding(.horizontal, f.scaled(0.018)).padding(.vertical, f.scaled(0.008))
                .background(Color.black.opacity(0.5), in: Capsule())
                .position(f.point(CGPoint(x: 0.50, y: 0.505)))
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }

    private func actionBar(for c: CardInstance, in size: CGSize) -> some View {
        let side = vm.turnSide
        return HStack(spacing: 10) {
            if c.zone == .hand {
                if vm.canPlay(c, on: side) {
                    actionButton("Play", "hand.tap.fill") { Task { await vm.play(c, on: side) }; chosen = nil }
                }
                if vm.canEat(c, on: side) {
                    actionButton("Eat", "leaf.fill") { Task { await vm.eat(c, on: side) }; chosen = nil }
                }
                if !vm.canPlay(c, on: side) && !vm.canEat(c, on: side) {
                    Text(vm.activeBoard.ateThisTurn ? "Already ate this turn" : "Not enough mana")
                        .font(.caption2.bold()).foregroundStyle(.white)
                }
            } else if c.zone == .basecamp {
                if vm.canMarch(c, on: side) {
                    actionButton("March", "figure.walk") { Task { await vm.march(c, on: side) }; chosen = nil }
                }
                if vm.canSacrifice(c, on: side) {
                    actionButton("Sacrifice", "flame.fill") { Task { await vm.sacrifice(c, on: side) }; chosen = nil }
                }
            } else if c.zone == .frontier {
                if c.canAct && (vm.inactiveBoard.frontier.isEmpty || c.unblockable) {
                    actionButton("Raid", "bolt.fill") { Task { await vm.attack(c, target: nil, on: side) }; chosen = nil }
                } else if c.canAct {
                    Text("Tap an enemy").font(.caption2.bold()).foregroundStyle(.white)
                }
                if vm.canSacrifice(c, on: side) {
                    actionButton("Sacrifice", "flame.fill") { Task { await vm.sacrifice(c, on: side) }; chosen = nil }
                }
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
        guard vm.winner == nil, !vm.awaitingHandoff, !vm.busy else { return }
        if side != vm.turnSide {
            if let atk = chosen, atk.zone == .frontier, inst.zone == .frontier {
                Task { await vm.attack(atk, target: inst, on: vm.turnSide) }
                chosen = nil
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
                Button {
                    Task { await vm.confirmHandoff() }
                    chosen = nil
                } label: {
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
