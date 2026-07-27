import Foundation

// MARK: - TCG card model (v2 — element/keyword design)
//
// Card DATA only; the match engine lives in ViewModels/MatchViewModel.swift.
// Vocabulary follows Resources/bible-tcg-rules.md.

enum TCGCardType: String, CaseIterable {
    case human
    case creature
    case event
    case relic

    var displayName: String { rawValue.capitalized }

    /// True for cards with an attack / health stat line (Humans and Creatures).
    /// Deliberately not called `isCreature` — Creature is a specific card type.
    var hasStats: Bool { self == .human || self == .creature }
}

/// Human discipline.
enum Discipline: String, CaseIterable {
    case wisdom, courage, strength
    var displayName: String { rawValue.capitalized }
}

/// Creature element. Events are cleared by accumulating element points.
enum Element: String, CaseIterable {
    case air, sea, land
    var displayName: String { rawValue.capitalized }
}

/// One element cost of an Event, e.g. `.init(.sea, 3)` = "3 Sea".
struct ElementReq: Equatable {
    let element: Element
    let count: Int
    init(_ element: Element, _ count: Int) { self.element = element; self.count = count }
}

/// One playable card. `id` doubles as the art asset name.
struct TCGCard: Identifiable, Equatable {
    let id: String
    let name: String
    let type: TCGCardType
    let cost: Int

    // Humans and Creatures only; 0 for events and relics.
    let attack: Int
    let health: Int

    let discipline: Discipline?      // humans
    let element: Element?            // creatures
    let requirement: [ElementReq]    // events (element gate)
    let keywords: [String]           // static keywords: charge, shield, guard
    let ability: String              // display text (combined trigger text / relic rules)

    init(id: String, name: String, type: TCGCardType, cost: Int,
         attack: Int = 0, health: Int = 0,
         discipline: Discipline? = nil, element: Element? = nil,
         requirement: [ElementReq] = [], keywords: [String] = [], ability: String = "") {
        self.id = id; self.name = name; self.type = type; self.cost = cost
        self.attack = attack; self.health = health
        self.discipline = discipline; self.element = element
        self.requirement = requirement; self.keywords = keywords; self.ability = ability
    }

    /// Guard abilities are live only while the card sits in the Basecamp.
    var hasGuard: Bool { keywords.contains("guard") }

    static func == (lhs: TCGCard, rhs: TCGCard) -> Bool { lhs.id == rhs.id }
}
