import SwiftUI

/// Where a dragged card can be dropped.
///
/// Cards are their own targets so you can point at a specific defender; the
/// zones cover everything else. Resolution checks cards first — an enemy
/// Creature standing in the Frontier should mean "attack this one", not
/// "somewhere in their Frontier".
enum DropTarget: Equatable {
    case camp(PlayerSide)
    case frontier(PlayerSide)
    case manaPool(PlayerSide)
    case altar(PlayerSide)
    case relics(PlayerSide)
    case card(UUID)
}

/// What the player is currently holding.
///
/// `translation` is the live gesture offset; the view adds it to the card's
/// resting position, so the card follows the finger without the layout moving.
struct DragState {
    let card: CardInstance
    let from: MatchZone
    let origin: CGPoint          // resting position, in view points
    var translation: CGSize = .zero
    /// True once the finger has moved far enough to count as a drag rather
    /// than a tap. Until then the card lifts but nothing is being aimed.
    var moved = false
    var target: DropTarget?

    var location: CGPoint {
        CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
    }

    /// Below this the gesture is a tap, and opens the inspector instead.
    static let dragThreshold: CGFloat = 12

    func exceedsThreshold(_ t: CGSize) -> Bool {
        abs(t.width) > Self.dragThreshold || abs(t.height) > Self.dragThreshold
    }
}

/// The action a drop would perform. `nil` means the drop is not allowed, and
/// the card springs back.
enum DropAction: Equatable {
    case play
    case convert
    case march
    case sacrifice
    case attack(UUID?)      // nil target = Raid the Guardian
}

/// Resolves drags against the board. Pure decision-making — it reads the board
/// and the layout and says what a drop would do, but never mutates anything.
///
/// Legality is *not* re-implemented here: every answer defers to the same
/// `can…` methods the engine already uses, so the rules have exactly one home.
@MainActor
struct DragResolver {
    let vm: MatchViewModel
    let frame: MatLayout.Frame
    /// Where each card currently sits on screen, by id.
    let positions: [UUID: CGPoint]

    /// Which target the finger is over, if any.
    func target(at p: CGPoint, dragging card: CardInstance) -> DropTarget? {
        // Cards first — pointing at a defender beats the region behind it.
        for (id, centre) in positions where id != card.id {
            if frame.cardHitRect(at: centre).contains(p) { return .card(id) }
        }
        let side = vm.turnSide
        if frame.rect(MatLayout.manaPoolRegion(side)).contains(p) { return .manaPool(side) }
        if frame.rect(MatLayout.altarRegion(side)).contains(p)  { return .altar(side) }
        if frame.rect(MatLayout.relicRegion(side)).contains(p)  { return .relics(side) }
        if frame.rect(MatLayout.campRegion(side)).contains(p)   { return .camp(side) }
        if frame.rect(MatLayout.frontierRegion(side)).contains(p) { return .frontier(side) }
        return nil
    }

    /// What dropping `card` on `target` would do, or nil if it isn't allowed.
    func action(dropping card: CardInstance, on target: DropTarget?) -> DropAction? {
        guard let target, !vm.busy, vm.winner == nil, !vm.awaitingHandoff else { return nil }
        let side = vm.turnSide

        switch (card.zone, target) {
        case (.hand, .camp(let s)) where s == side:
            return card.card.type != .relic && vm.canPlay(card, on: side) ? .play : nil

        case (.hand, .relics(let s)) where s == side:
            return card.card.type == .relic && vm.canPlay(card, on: side) ? .play : nil

        case (.hand, .manaPool(let s)) where s == side:
            return vm.canConvert(card, on: side) ? .convert : nil

        case (.basecamp, .frontier(let s)) where s == side:
            return vm.canMarch(card, on: side) ? .march : nil

        case (.basecamp, .altar(let s)), (.frontier, .altar(let s)):
            return s == side && vm.canSacrifice(card, on: side) ? .sacrifice : nil

        case (.frontier, .card(let id)):
            return attackAction(from: card, ontoCardWith: id)

        default:
            return nil
        }
    }

    /// Every legal target for a card, so the board can light them up the moment
    /// it's picked up rather than making the player hunt.
    func validTargets(for card: CardInstance) -> Set<DropTargetKey> {
        var out: Set<DropTargetKey> = []
        let side = vm.turnSide
        let candidates: [DropTarget] = [
            .camp(side), .relics(side), .manaPool(side), .frontier(side), .altar(side),
        ] + vm.board(side == .you ? .foe : .you).allInPlay.map { .card($0.id) }

        for t in candidates where action(dropping: card, on: t) != nil {
            out.insert(DropTargetKey(t))
        }
        return out
    }

    /// A Frontier card dropped on an enemy card: a normal attack if the target
    /// is in their Frontier, or a Raid if it's their Guardian and the way is
    /// clear. Mirrors the guards inside `MatchViewModel.attack`.
    private func attackAction(from attacker: CardInstance, ontoCardWith id: UUID) -> DropAction? {
        guard attacker.canAct else { return nil }
        let foe = vm.board(vm.turnSide == .you ? .foe : .you)

        if let defender = foe.frontier.first(where: { $0.id == id }) {
            return .attack(defender.id)
        }
        // Raid: only past an empty Frontier, unless the attacker flies over it.
        if foe.guardian?.id == id, foe.frontier.isEmpty || attacker.unblockable {
            return .attack(nil)
        }
        return nil
    }
}

/// `DropTarget` boxed for use in a `Set` — `CGPoint`-free and hashable.
struct DropTargetKey: Hashable {
    private let raw: String
    init(_ t: DropTarget) {
        switch t {
        case .camp(let s):     raw = "camp\(s)"
        case .frontier(let s): raw = "frontier\(s)"
        case .manaPool(let s): raw = "manaPool\(s)"
        case .altar(let s):    raw = "altar\(s)"
        case .relics(let s):   raw = "relics\(s)"
        case .card(let id):    raw = "card\(id)"
        }
    }
}
