import Foundation

// MARK: - Match models (hot-seat TCG engine)
//
// Rules from Resources/bible-tcg-rules.md / cards.json:
// zones Basecamp(4, slot 0 = Guardian) / Frontier(5) / Altar; hand 7; mana comes
// from berries you gain by eating cards; overcome your 3 Events in order by
// banking element points from Sacrificing Creatures; lose if your Basecamp empties.

enum PlayerSide { case you, foe }

enum MatchZone { case deck, hand, basecamp, frontier, altar, discard }

/// A short-lived visual cue — a floating damage number, a shield shattering, a
/// point gain drifting toward its counter. Board state records that a card took
/// 3 damage; it can't record that a red `−3` should rise off it, so the engine
/// publishes these alongside the state and the view renders them on the card.
///
/// Cues expire on their own. They are never read back by the rules.
struct VisualCue: Identifiable {
    enum Kind {
        case damage(Int)
        case heal(Int)
        case buff(attack: Int, health: Int)
        case shieldBreak
        case death
        case points(Element, Int)
        case berry
        case draw
    }

    let id = UUID()
    /// The `CardInstance` this cue belongs to, or `nil` for board-level cues
    /// (a berry gained, points banked) which anchor to their player's counter.
    let card: UUID?
    let side: PlayerSide
    let kind: Kind

    /// A card marked for death — the view flashes it before it leaves the board.
    var isDeath: Bool { if case .death = kind { return true }; return false }
}

/// A live copy of a card during a match (reference type for easy targeting).
///
/// Stats are **layered** rather than stored flat, so continuous effects (Guard
/// auras, Relics) can be recomputed from scratch each time the board changes
/// without leaking when their source leaves play.
final class CardInstance: Identifiable {
    let id = UUID()
    let card: TCGCard

    var bonusAttack = 0      // permanent  — Great Bear, Farmer, Blessings
    var bonusHealth = 0
    var tempAttack = 0       // until end of turn — Fisherman, Peter
    var tempHealth = 0
    var auraAttack = 0       // recomputed every settle() from Guard/Relic sources
    var auraHealth = 0
    var damage = 0           // damage taken; Health is derived from it

    var shield: Bool
    /// Turn number at which a *granted* Shield lapses. `nil` for a printed Shield,
    /// which instead refreshes at the start of its controller's turn.
    var shieldExpires: Int?

    var canAct: Bool              // may attack this turn
    var doubleDamageCharges = 0   // Warrior Chief
    var unblockable = false       // Eagle — may Raid past an occupied Frontier
    var killedBy: CardInstance?   // for Golden Jackal's Death trigger
    var enteredOn: Int            // turn it entered its current zone (overnight rule)
    var zone: MatchZone

    init(_ card: TCGCard, turn: Int) {
        self.card = card
        shield = card.keywords.contains("shield")
        canAct = card.keywords.contains("charge")
        enteredOn = turn
        zone = .hand
    }

    var attack: Int { max(0, card.attack + bonusAttack + tempAttack + auraAttack) }
    var maxHealth: Int { card.health + bonusHealth + tempHealth + auraHealth }
    var health: Int { maxHealth - damage }

    var isCreature: Bool { card.type == .creature }
    var isHuman: Bool { card.type == .human }
    var hasCharge: Bool { card.keywords.contains("charge") }
    var refreshesShield: Bool { card.keywords.contains("shield") }
    var isDamaged: Bool { damage > 0 }

    func heal(_ amount: Int) { damage = max(0, damage - amount) }
    func healToFull() { damage = 0 }
    func buff(attack a: Int, health h: Int) { bonusAttack += a; bonusHealth += h }
    func buffTemp(attack a: Int, health h: Int) { tempAttack += a; tempHealth += h }
    func grantShield(until turn: Int?) { shield = true; shieldExpires = turn }
}

/// Progress toward one Event.
final class EventProgress: Identifiable {
    let id = UUID()
    let card: TCGCard
    var cleared = false
    /// Face-up on the board. Event 3 can be revealed to a player who is not yet
    /// allowed to clear it — see `PlayerBoard.isUnlocked(_:)`.
    var revealed: Bool
    init(_ card: TCGCard, revealed: Bool) { self.card = card; self.revealed = revealed }

    /// True if the given element pool can pay this event's requirement.
    func affordable(by pool: [Element: Int]) -> Bool {
        card.requirement.allSatisfy { (pool[$0.element] ?? 0) >= $0.count }
    }
}

/// One player's board state.
final class PlayerBoard {
    let side: PlayerSide

    var deck: [TCGCard] = []
    var hand: [CardInstance] = []
    var basecamp: [CardInstance] = []      // slot 0 = Guardian
    var frontier: [CardInstance] = []
    var altar: [CardInstance] = []         // Sacrificed Creatures, until an Event clears
    var discard: [CardInstance] = []
    var relics: [CardInstance] = []

    /// Berries are permanent mana crystals, gained only by eating a card.
    /// Mana refills to the berry count at the start of each of your turns.
    var mana = 0
    var berries = 0

    var elements: [Element: Int] = [.air: 0, .sea: 0, .land: 0]
    var events: [EventProgress] = []

    /// True once a card has been placed in the Basecamp — the empty-Basecamp
    /// loss only applies after you've actually deployed.
    var everDeployed = false

    // Per-turn counters, reset in beginTurn.
    var ateThisTurn = false
    var playedCardThisTurn = false
    var humansMarchedThisTurn = 0
    var owlShieldGivenThisTurn = false

    init(side: PlayerSide) { self.side = side }

    var guardian: CardInstance? { basecamp.first }
    var allInPlay: [CardInstance] { basecamp + frontier }
    var clearedCount: Int { events.filter { $0.cleared }.count }
    var hasWon: Bool { events.count == 3 && events.allSatisfy { $0.cleared } }

    func hasRelic(_ id: String) -> Bool { relics.contains { $0.card.id == id } }

    /// The Event currently being raced — the first uncleared one.
    var currentEventIndex: Int? { events.firstIndex { !$0.cleared } }

    /// Events unlock in order: index 0 from the start, index *n* only once every
    /// earlier Event is cleared. Event 3 may be *revealed* well before it unlocks.
    func isUnlocked(_ index: Int) -> Bool {
        guard events.indices.contains(index) else { return false }
        return events.prefix(index).allSatisfy { $0.cleared }
    }
}
