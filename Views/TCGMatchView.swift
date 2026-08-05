import SwiftUI
import UIKit

/// Landscape match board laid out on the Playmat V4 template.
///
/// **Drag to act, tap to look.** A card is carried to where it should end up —
/// hand to Camp to play, hand to the Mana Pool to convert, Camp to Frontier to
/// March, a Creature to the Altar to Sacrifice, a Frontier card onto an enemy to
/// attack. Releasing without moving opens the card enlarged instead.
///
/// Every position comes from `MatLayout`, and every card carries a
/// `matchedGeometryEffect` keyed on its `CardInstance.id`, so a card moving
/// between zones slides instead of disappearing and reappearing. The engine
/// pauses between steps (see `MatchViewModel.beat`), which is what gives the
/// board time to show each one.
struct TCGMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MatchViewModel()
    /// Shared by every zone so cards can fly between them.
    @Namespace private var cardNS

    @State private var drag: DragState?
    /// Everywhere the held card could legally go, lit up on pickup.
    @State private var validTargets: Set<DropTargetKey> = []
    @State private var inspecting: CardInstance?

    /// Coordinate space shared by the board layout and every drag gesture.
    private static let boardSpace = "board"

    /// The app is landscape-only (see `project.yml`), so the board never has to
    /// ask iOS to rotate and there's no portrait state to fall back to.
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.12, green: 0.11, blue: 0.10).ignoresSafeArea()

                let f = MatLayout.Frame(in: geo.size)
                board(f)
                convertingCard(f)
                logLine(f)
                if let d = drag, d.moved, d.from == .frontier { aimLine(d, f) }
                CueOverlay(cues: vm.cues,
                           anchor: { cueAnchor($0, f) },
                           scale: f.size.height)
                controls
                if vm.awaitingHandoff, vm.winner == nil { handoffOverlay }
                if let w = vm.winner { resultOverlay(winner: w) }
                if let inst = inspecting {
                    CardInspector(inst: inst) { inspecting = nil }
                }
            }
            // Drags report their location in this space, so gesture coordinates
            // and `MatLayout` slot positions are directly comparable. With
            // `.local` a drag would report points relative to the card being
            // dragged, and no drop target would ever match.
            .coordinateSpace(name: Self.boardSpace)
        }
        .statusBarHidden()
        // A locked board can't be holding a card.
        .onChange(of: vm.busy) { _, busy in if busy { drag = nil; validTargets = [] } }
    }

    // MARK: Board

    private func board(_ f: MatLayout.Frame) -> some View {
        ZStack {
            Image("playmat").resizable().scaledToFit()
                .frame(width: f.size.width, height: f.size.height)
                .position(x: f.origin.x + f.size.width / 2, y: f.origin.y + f.size.height / 2)

            dropZones(f)

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
            let p = f.point(.camp(i), side)
            card(c, side: side, size: f.card, at: p, f, guardian: i == 0)
                .position(p)
                .zIndex(drag?.card.id == c.id ? 100 : 0)
        }
    }

    @ViewBuilder
    private func frontier(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        ForEach(Array(b.frontier.prefix(5).enumerated()), id: \.element.id) { i, c in
            let p = f.point(MatLayout.frontierCenter(i, of: b.frontier.count, for: side))
            card(c, side: side, size: f.card, at: p, f)
                .offset(lungeOffset(for: c, f))
                .position(p)
                .zIndex(drag?.card.id == c.id ? 100 : 0)
        }
    }

    @ViewBuilder
    private func relics(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        ForEach(Array(b.relics.prefix(2).enumerated()), id: \.element.id) { i, c in
            let p = f.point(.relic(i), side)
            card(c, side: side, size: f.relicCard, at: p, f)
                .position(p)
                .zIndex(drag?.card.id == c.id ? 100 : 0)
        }
    }

    /// A card being converted, caught mid-dissolve over the Mana Pool.
    ///
    /// It carries the same `matchedGeometryEffect` id it had in hand, so it
    /// flies to the Pool rather than jumping there, then shrinks away — cards in
    /// the Pool are spent, so there's nothing to show once it lands.
    @ViewBuilder
    private func convertingCard(_ f: MatLayout.Frame) -> some View {
        if let inst = vm.converting {
            let side = vm.turnSide
            MiniCard(inst: inst, w: f.card.width, h: f.card.height)
                .matchedGeometryEffect(id: inst.id, in: cardNS)
                .scaleEffect(0.35)
                .opacity(0)
                .position(f.point(.manaPool, side))
                .allowsHitTesting(false)
                .transition(.identity)
        }
    }

    /// Where every card in play currently sits, so a drag can be aimed at one.
    private func cardPositions(_ f: MatLayout.Frame) -> [UUID: CGPoint] {
        var out: [UUID: CGPoint] = [:]
        for side in [PlayerSide.you, .foe] {
            let b = vm.board(side)
            for (i, c) in b.basecamp.prefix(4).enumerated() {
                out[c.id] = f.point(.camp(i), side)
            }
            for (i, c) in b.frontier.prefix(5).enumerated() {
                out[c.id] = f.point(MatLayout.frontierCenter(i, of: b.frontier.count, for: side))
            }
        }
        return out
    }

    /// Zones glow while a card is held so the legal destinations are visible
    /// before the player commits to one.
    @ViewBuilder
    private func dropZones(_ f: MatLayout.Frame) -> some View {
        if let d = drag, d.moved {
            let side = vm.turnSide
            let zones: [(DropTarget, CGRect)] = [
                (.camp(side),     MatLayout.campRegion(side)),
                (.relics(side),   MatLayout.relicRegion(side)),
                (.manaPool(side), MatLayout.manaPoolRegion(side)),
                (.frontier(side), MatLayout.frontierRegion(side)),
                (.altar(side),    MatLayout.altarRegion(side)),
            ]
            ForEach(Array(zones.enumerated()), id: \.offset) { _, z in
                if validTargets.contains(DropTargetKey(z.0)) {
                    let hovered = d.target == z.0
                    let r = f.rect(z.1)
                    RoundedRectangle(cornerRadius: f.scaled(0.03), style: .continuous)
                        .fill(Theme.gold.opacity(hovered ? 0.30 : 0.13))
                        .overlay(RoundedRectangle(cornerRadius: f.scaled(0.03), style: .continuous)
                            .strokeBorder(Theme.gold.opacity(hovered ? 0.95 : 0.5),
                                          lineWidth: hovered ? 3 : 2))
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .allowsHitTesting(false)
                        .animation(.easeOut(duration: 0.15), value: hovered)
                }
            }
        }
    }

    /// Only the active player's hand is face-up — this is a hot-seat game.
    /// Cards fan in an arc, and the one being picked up straightens while its
    /// neighbours slide aside.
    @ViewBuilder
    private func hand(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        let open = side == vm.turnSide && !vm.awaitingHandoff
        let liftedIndex = b.hand.firstIndex { $0.id == drag?.card.id }

        ForEach(Array(b.hand.enumerated()), id: \.element.id) { i, c in
            let slot = MatLayout.handSlot(i, of: b.hand.count, for: side, lifted: liftedIndex)
            let held = drag?.card.id == c.id

            // The gesture goes on the card itself, *before* `.position` — that
            // modifier expands to fill its parent, so attaching a gesture after
            // it would give every hand card a board-sized hit area.
            MiniCard(inst: c, w: f.card.width, h: f.card.height,
                     showCost: open,
                     cost: open ? vm.effectiveCost(c.card, for: b) : nil,
                     playable: open && drag == nil && vm.canPlay(c, on: side),
                     faceDown: !open,
                     dying: isDying(c),
                     lifted: held)
                .matchedGeometryEffect(id: c.id, in: cardNS)
                .rotationEffect(held ? .zero : slot.angle)
                .offset(held ? drag!.translation : .zero)
                .contentShape(Rectangle())
                .gesture(cardGesture(c, from: .hand, at: f.point(slot.center), f,
                                     draggable: open))
                .position(f.point(slot.center))
                // zIndex has to sit on the ZStack's actual child — the
                // positioned container — so a held card draws above the rest.
                .zIndex(held ? 100 : Double(i))
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: liftedIndex)
        }
    }

    /// The Mana Pool readout beside the Frontier, plus the three element counters.
    @ViewBuilder
    private func readouts(_ side: PlayerSide, _ f: MatLayout.Frame) -> some View {
        let b = vm.board(side)
        manaHex("\(b.mana)/\(b.maxMana)", f.point(.manaPool, side), f)
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

    /// A card in play. Yours can be picked up; the foe's can only be aimed at
    /// (and tapped to read).
    @ViewBuilder
    private func card(_ inst: CardInstance, side: PlayerSide, size: CGSize,
                      at anchor: CGPoint, _ f: MatLayout.Frame,
                      guardian: Bool = false) -> some View {
        let held = drag?.card.id == inst.id
        let key = DropTargetKey(.card(inst.id))
        let isValid = drag != nil && validTargets.contains(key)
        let isHovered = drag?.target == .card(inst.id)
        // Yours, in the Frontier, attack unspent. Basecamp cards also carry
        // `canAct` but have to March before they can fight, and the foe's keep
        // whatever they ended their own turn with — hence all three clauses.
        let ready = side == vm.turnSide && inst.zone == .frontier && inst.canAct

        MiniCard(inst: inst, w: size.width, h: size.height,
                 guardian: guardian,
                 readyToAttack: ready,
                 dying: isDying(inst),
                 lifted: held,
                 validTarget: isValid,
                 hovered: isHovered && isValid)
            .matchedGeometryEffect(id: inst.id, in: cardNS)
            .offset(held ? drag!.translation : .zero)
            .contentShape(Rectangle())
            .gesture(cardGesture(inst, from: inst.zone, at: anchor, f,
                                 draggable: side == vm.turnSide))
    }

    // MARK: Drag

    /// One gesture handles pick-up, carry and drop — and a release that barely
    /// moved is a tap, which opens the inspector. Stacking a separate
    /// `onTapGesture` alongside a `DragGesture` makes them fight over the touch,
    /// so both live here.
    private func cardGesture(_ inst: CardInstance, from zone: MatchZone,
                             at anchor: CGPoint, _ f: MatLayout.Frame,
                             draggable: Bool = true) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.boardSpace))
            .onChanged { g in
                guard !vm.busy, vm.winner == nil, !vm.awaitingHandoff else { return }
                guard draggable else { return }

                if drag?.card.id != inst.id {
                    drag = DragState(card: inst, from: zone, origin: anchor)
                    validTargets = resolver(f).validTargets(for: inst)
                }
                guard var d = drag else { return }
                d.translation = g.translation
                if d.exceedsThreshold(g.translation) { d.moved = true }
                d.target = d.moved ? resolver(f).target(at: g.location, dragging: inst) : nil
                drag = d
            }
            .onEnded { g in
                defer { drag = nil; validTargets = [] }

                // Barely moved, or not ours to move: a tap. Read the card.
                guard draggable, let d = drag, d.moved else {
                    inspecting = inst
                    return
                }
                let target = resolver(f).target(at: g.location, dragging: inst)
                guard let action = resolver(f).action(dropping: inst, on: target) else { return }
                perform(action, with: inst)
            }
    }

    private func resolver(_ f: MatLayout.Frame) -> DragResolver {
        DragResolver(vm: vm, frame: f, positions: cardPositions(f))
    }

    private func perform(_ action: DropAction, with inst: CardInstance) {
        let side = vm.turnSide
        Task {
            switch action {
            case .play:      await vm.play(inst, on: side)
            case .convert:   await vm.convert(inst, on: side)
            case .march:     await vm.march(inst, on: side)
            case .sacrifice: await vm.sacrifice(inst, on: side)
            case .attack(let id):
                let foe = vm.board(side == .you ? .foe : .you)
                let target = id.flatMap { tid in foe.frontier.first { $0.id == tid } }
                await vm.attack(inst, target: target, on: side)
            }
        }
    }

    /// A line from the attacker toward whatever the finger is over, so a Raid
    /// reads as aiming rather than as dragging a card off the board.
    private func aimLine(_ d: DragState, _ f: MatLayout.Frame) -> some View {
        let hit = d.target != nil
        return Path { p in
            p.move(to: d.origin)
            p.addLine(to: d.location)
        }
        .stroke(hit ? Theme.gold : Theme.gold.opacity(0.45),
                style: StrokeStyle(lineWidth: hit ? 5 : 3, lineCap: .round, dash: hit ? [] : [8, 7]))
        .allowsHitTesting(false)
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
                return f.point(MatLayout.handSlot(i, of: b.hand.count, for: side).center)
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
        case .manaGained:       return f.point(.manaPool, cue.side)
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
        if drag == nil, let last = vm.log.last {
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

}
