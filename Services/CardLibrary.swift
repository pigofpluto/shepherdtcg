import Foundation

/// The Bible-TCG card set (element/keyword design). Hard-coded in Swift like the
/// legacy `ContentDatabase` to keep the bundle flat and avoid codesign issues.
///
/// Stat guide: Human ATK+HP = 2×cost. Named Human (the `h_` ids) = 2×cost + 1.
/// Creature ATK+HP = 2×cost − 1, minimum 2.
/// Two documented exceptions: Leviathan (15, formula 13) and Lamb (3, formula 2).
/// Card text follows the vocabulary in `Resources/bible-tcg-rules.md`.
enum CardLibrary {

    static let all: [TCGCard] = creatures + humans + relics + events

    static func cards(of type: TCGCardType) -> [TCGCard] { all.filter { $0.type == type } }
    static func card(id: String) -> TCGCard? { all.first { $0.id == id } }

    // MARK: - Creatures (25)  ·  element = air / sea / land

    static let creatures: [TCGCard] = [
        TCGCard(id: "sparrow", name: "Sparrow", type: .creature, cost: 1, attack: 1, health: 1,
                element: .air, ability: "Sacrifice: Draw a card."),
        TCGCard(id: "tide-pool-crab", name: "Tide Pool Crab", type: .creature, cost: 1, attack: 0, health: 2,
                element: .sea),
        TCGCard(id: "raven", name: "Raven", type: .creature, cost: 2, attack: 2, health: 1,
                element: .air, ability: "Play: Look at the top card of your deck. Sacrifice: A Wisdom Human you control draws a card."),
        TCGCard(id: "minnow-shoal", name: "Minnow Shoal", type: .creature, cost: 2, attack: 1, health: 2,
                element: .sea, ability: "Sacrifice: +2 Sea points."),
        TCGCard(id: "locust", name: "Locust", type: .creature, cost: 2, attack: 2, health: 1,
                element: .air, ability: "Sacrifice: Deal 1 damage to target enemy Frontier Creature."),
        TCGCard(id: "wild-boar", name: "Wild Boar", type: .creature, cost: 3, attack: 3, health: 2,
                element: .land, keywords: ["charge"], ability: "Charge."),
        TCGCard(id: "golden-jackal", name: "Golden Jackal", type: .creature, cost: 3, attack: 3, health: 2,
                element: .land,
                ability: "Death: Deal 1 damage to the Creature that killed it. Sacrifice: Give a Courage Human +1 attack."),
        TCGCard(id: "owl", name: "Owl", type: .creature, cost: 3, attack: 2, health: 3,
                element: .air, keywords: ["guard"],
                ability: "Guard: The first Human that Marches to the Frontier each turn gains Shield until end of turn."),
        TCGCard(id: "river-otter", name: "River Otter", type: .creature, cost: 3, attack: 3, health: 2,
                element: .sea, ability: "Sacrifice: Return a Human from your discard to your hand."),
        TCGCard(id: "stone-ram", name: "Stone Ram", type: .creature, cost: 3, attack: 2, health: 3,
                element: .land, keywords: ["charge"], ability: "Charge."),
        TCGCard(id: "lion", name: "Lion", type: .creature, cost: 4, attack: 4, health: 3,
                element: .land, keywords: ["guard"], ability: "Guard: The Guardian gets +2/+0."),
        TCGCard(id: "eagle", name: "Eagle", type: .creature, cost: 4, attack: 3, health: 4,
                element: .air, ability: "March: This Creature may attack the enemy Guardian even if the enemy Frontier is occupied."),
        TCGCard(id: "great-fish", name: "Great Fish", type: .creature, cost: 4, attack: 3, health: 4,
                element: .sea, ability: "Sacrifice: Deal 4 damage split among any number of enemy Frontier Creatures."),
        TCGCard(id: "behemoth-calf", name: "Behemoth Calf", type: .creature, cost: 4, attack: 4, health: 3,
                element: .land),
        TCGCard(id: "serpent", name: "Serpent", type: .creature, cost: 5, attack: 5, health: 4,
                element: .land, ability: "Sacrifice: Destroy an enemy Frontier Creature with 3 or less Health."),
        TCGCard(id: "whale", name: "Whale", type: .creature, cost: 5, attack: 4, health: 5,
                element: .sea, keywords: ["guard"], ability: "Guard: Sea Creatures cost 1 less to play."),
        TCGCard(id: "griffin-vulture", name: "Griffin Vulture", type: .creature, cost: 5, attack: 5, health: 4,
                element: .air, ability: "Death: Draw a card."),
        TCGCard(id: "kraken", name: "Kraken", type: .creature, cost: 6, attack: 6, health: 5,
                element: .sea, ability: "Sacrifice: +3 Sea points."),
        TCGCard(id: "great-bear", name: "Great Bear", type: .creature, cost: 6, attack: 5, health: 6,
                element: .land, ability: "Sacrifice: Give a Strength Human +2/+3."),
        TCGCard(id: "leviathan", name: "Leviathan", type: .creature, cost: 7, attack: 9, health: 6,
                element: .land),

        // ── Named Creatures (restored; have their own art) ──
        TCGCard(id: "ant", name: "Ant", type: .creature, cost: 1, attack: 1, health: 1,
                element: .land, ability: "Sacrifice: +2 Land points."),
        TCGCard(id: "dove", name: "Dove", type: .creature, cost: 2, attack: 1, health: 2,
                element: .air, ability: "Sacrifice: Give a Human Shield until your next turn."),
        TCGCard(id: "lamb", name: "Lamb", type: .creature, cost: 1, attack: 1, health: 2,
                element: .land, ability: "Sacrifice: Give a Human +0/+2."),
        TCGCard(id: "donkey", name: "Donkey", type: .creature, cost: 3, attack: 2, health: 3,
                element: .land, ability: "Play: Draw a card."),
        TCGCard(id: "camel", name: "Camel", type: .creature, cost: 4, attack: 2, health: 5,
                element: .land, keywords: ["guard"], ability: "Guard: Land Creatures cost 1 less to play."),
    ]

    // MARK: - Humans (44)  ·  discipline = wisdom / courage / strength

    static let humans: [TCGCard] = [
        TCGCard(id: "shepherd-boy", name: "Shepherd Boy", type: .human, cost: 1, attack: 1, health: 1,
                discipline: .courage, ability: "Play: Look at the top card of your deck."),
        TCGCard(id: "field-hand", name: "Field Hand", type: .human, cost: 1, attack: 0, health: 2,
                discipline: .strength),
        TCGCard(id: "watchman", name: "Watchman", type: .human, cost: 2, attack: 1, health: 3,
                discipline: .wisdom),
        TCGCard(id: "young-scribe", name: "Young Scribe", type: .human, cost: 2, attack: 2, health: 2,
                discipline: .wisdom, ability: "Play: Draw a card, then discard a card."),
        TCGCard(id: "herald", name: "Herald", type: .human, cost: 2, attack: 2, health: 2,
                discipline: .courage, ability: "March: Draw a card if this is the first Human you've Marched this turn."),
        TCGCard(id: "farmer", name: "Farmer", type: .human, cost: 2, attack: 1, health: 3,
                discipline: .strength, keywords: ["guard"],
                ability: "Guard: Whenever you Sacrifice a Creature, this gains +1/+0."),
        TCGCard(id: "elder", name: "Elder", type: .human, cost: 3, attack: 2, health: 4,
                discipline: .wisdom, keywords: ["guard"], ability: "Guard: Humans in the Frontier get +0/+1."),
        TCGCard(id: "soldier", name: "Soldier", type: .human, cost: 3, attack: 4, health: 2,
                discipline: .courage, keywords: ["charge"], ability: "Charge."),
        TCGCard(id: "fisherman", name: "Fisherman", type: .human, cost: 3, attack: 3, health: 3,
                discipline: .courage, ability: "March: If you control a Sea Creature, this gains +1/+1 until end of turn."),
        TCGCard(id: "physician", name: "Physician", type: .human, cost: 3, attack: 2, health: 4,
                discipline: .wisdom, ability: "Death: Heal 2 on each other Human in the Frontier."),
        TCGCard(id: "priest", name: "Priest", type: .human, cost: 4, attack: 3, health: 5,
                discipline: .wisdom, keywords: ["guard"],
                ability: "Guard: Whenever you Sacrifice a Creature, this Human heals to full."),
        TCGCard(id: "judge", name: "Judge", type: .human, cost: 4, attack: 4, health: 4,
                discipline: .wisdom, ability: "Raid: Draw a card."),
        TCGCard(id: "centurion", name: "Centurion", type: .human, cost: 4, attack: 5, health: 3,
                discipline: .strength, keywords: ["charge"], ability: "Charge."),
        TCGCard(id: "craftsman", name: "Craftsman", type: .human, cost: 4, attack: 3, health: 5,
                discipline: .strength),
        TCGCard(id: "kings-guard", name: "King's Guard", type: .human, cost: 5, attack: 5, health: 5,
                discipline: .courage, keywords: ["shield"], ability: "Shield."),
        TCGCard(id: "prophet", name: "Prophet", type: .human, cost: 5, attack: 4, health: 6,
                discipline: .wisdom, keywords: ["guard"], ability: "Guard: Whenever you overcome an Event, draw a card."),
        TCGCard(id: "warrior-chief", name: "Warrior Chief", type: .human, cost: 5, attack: 6, health: 4,
                discipline: .strength, ability: "March: This Human deals double damage the first time it attacks this turn."),
        TCGCard(id: "high-priest", name: "High Priest", type: .human, cost: 6, attack: 5, health: 7,
                discipline: .wisdom, keywords: ["guard"],
                ability: "Guard: When a Creature's Sacrifice targets this Human, it also gains Shield until your next turn."),
        TCGCard(id: "champion", name: "Champion", type: .human, cost: 6, attack: 7, health: 5,
                discipline: .strength, ability: "Raid: Also deal this Human's Attack to the enemy Basecamp card with the lowest Health."),
        TCGCard(id: "anointed-king", name: "Anointed King", type: .human, cost: 7, attack: 7, health: 7,
                discipline: .courage),

        // ── Named characters (restored) ──
        // Wisdom
        TCGCard(id: "h_solomon", name: "Solomon", type: .human, cost: 5, attack: 3, health: 8,
                discipline: .wisdom, ability: "Play: Look at the top 2 cards of your deck; draw one."),
        TCGCard(id: "h_moses", name: "Moses", type: .human, cost: 6, attack: 5, health: 8,
                discipline: .wisdom, keywords: ["guard"], ability: "Guard: Sacrifices give +1 extra point."),
        TCGCard(id: "h_daniel", name: "Daniel", type: .human, cost: 4, attack: 3, health: 6,
                discipline: .wisdom, keywords: ["shield"], ability: "Shield."),
        TCGCard(id: "h_abraham", name: "Abraham", type: .human, cost: 5, attack: 4, health: 7,
                discipline: .wisdom, keywords: ["guard"], ability: "Guard: Other Humans get +0/+1."),
        TCGCard(id: "h_joseph", name: "Joseph", type: .human, cost: 4, attack: 3, health: 6,
                discipline: .wisdom, ability: "Play: Draw a card."),
        TCGCard(id: "h_paul", name: "Paul", type: .human, cost: 5, attack: 4, health: 7,
                discipline: .wisdom, ability: "Play: Draw a card, then discard a card."),
        TCGCard(id: "h_deborah", name: "Deborah", type: .human, cost: 4, attack: 3, health: 6,
                discipline: .wisdom, keywords: ["guard"], ability: "Guard: Courage Humans get +1/+0."),
        TCGCard(id: "h_isaiah", name: "Isaiah", type: .human, cost: 4, attack: 3, health: 6,
                discipline: .wisdom, ability: "Play: Look at the top card of your deck."),
        TCGCard(id: "h_eve", name: "Eve", type: .human, cost: 3, attack: 2, health: 5,
                discipline: .wisdom, ability: "Play: Both players draw a card."),
        TCGCard(id: "h_magi", name: "The Magi", type: .human, cost: 5, attack: 5, health: 6,
                discipline: .wisdom, ability: "Play: Draw a card."),
        // Courage
        TCGCard(id: "h_david", name: "David", type: .human, cost: 4, attack: 5, health: 4,
                discipline: .courage, keywords: ["charge"], ability: "Charge."),
        TCGCard(id: "h_joshua", name: "Joshua", type: .human, cost: 6, attack: 6, health: 7,
                discipline: .courage, ability: "March: Gains +2/+0 when it attacks the enemy Guardian."),
        TCGCard(id: "h_gideon", name: "Gideon", type: .human, cost: 3, attack: 4, health: 3,
                discipline: .courage, keywords: ["charge"], ability: "Charge."),
        TCGCard(id: "h_esther", name: "Esther", type: .human, cost: 4, attack: 3, health: 6,
                discipline: .courage, keywords: ["shield"], ability: "Shield."),
        TCGCard(id: "h_elijah", name: "Elijah", type: .human, cost: 5, attack: 5, health: 6,
                discipline: .courage, ability: "Play: Deal 3 damage to an enemy Frontier Creature."),
        TCGCard(id: "h_peter", name: "Peter", type: .human, cost: 5, attack: 6, health: 5,
                discipline: .courage, ability: "March: If you control a Sea Creature, gains +1/+1 until end of turn."),
        TCGCard(id: "h_baptist", name: "John the Baptist", type: .human, cost: 3, attack: 3, health: 4,
                discipline: .courage, ability: "Play: Draw a card."),
        TCGCard(id: "h_matthew", name: "Matthew", type: .human, cost: 3, attack: 3, health: 4,
                discipline: .courage, ability: "Play: Draw a card, then discard a card."),
        // Strength
        TCGCard(id: "h_samson", name: "Samson", type: .human, cost: 7, attack: 8, health: 7,
                discipline: .strength, ability: "Death: Deal 3 damage to all enemy Frontier Creatures."),
        TCGCard(id: "h_goliath", name: "Goliath", type: .human, cost: 7, attack: 7, health: 8,
                discipline: .strength),
        TCGCard(id: "h_benaiah", name: "Benaiah", type: .human, cost: 5, attack: 6, health: 5,
                discipline: .strength, keywords: ["charge"], ability: "Charge."),
        TCGCard(id: "h_caleb", name: "Caleb", type: .human, cost: 4, attack: 5, health: 4,
                discipline: .strength, keywords: ["charge"], ability: "Charge."),
        TCGCard(id: "h_jael", name: "Jael", type: .human, cost: 3, attack: 4, health: 3,
                discipline: .strength, ability: "Play: Destroy a damaged enemy Frontier Creature."),
        TCGCard(id: "h_nehemiah", name: "Nehemiah", type: .human, cost: 5, attack: 3, health: 8,
                discipline: .strength, keywords: ["guard"], ability: "Guard: The Guardian gets +0/+2."),
    ]

    // MARK: - Relics (8)  ·  decks include up to 2

    static let relics: [TCGCard] = [
        TCGCard(id: "watchtower", name: "Watchtower", type: .relic, cost: 2,
                ability: "Whenever an enemy Raids your Basecamp, draw a card."),
        TCGCard(id: "ark-of-the-covenant", name: "Ark of the Covenant", type: .relic, cost: 5,
                ability: "The first card you play each turn costs 1 less."),
        TCGCard(id: "altar-of-fire", name: "Altar of Fire", type: .relic, cost: 6,
                ability: "Whenever you Sacrifice a Creature, deal 1 damage to a random enemy Frontier Creature."),
        TCGCard(id: "fish-net", name: "Fish Net", type: .relic, cost: 6,
                ability: "Sacrifices give double points."),
        TCGCard(id: "shepherds-staff", name: "Shepherd's Staff", type: .relic, cost: 7,
                ability: "Cards in the Frontier get +0/+2."),

        // ── Discipline relics ──
        TCGCard(id: "scroll-of-wisdom", name: "Scroll of Wisdom", type: .relic, cost: 3,
                ability: "Wisdom Humans have Play: Draw a card."),
        TCGCard(id: "banner-of-courage", name: "Banner of Courage", type: .relic, cost: 3,
                ability: "Courage Humans get +1/+0 and Charge."),
        TCGCard(id: "shield-of-strength", name: "Shield of Strength", type: .relic, cost: 3,
                ability: "Strength Humans get +0/+2."),
    ]

    // MARK: - Events (10)  ·  cleared by accumulating element points

    static let events: [TCGCard] = [
        TCGCard(id: "the-great-flood", name: "The Great Flood", type: .event, cost: 0,
                requirement: [ElementReq(.sea, 3)]),
        TCGCard(id: "plague-of-locusts", name: "Plague of Locusts", type: .event, cost: 0,
                requirement: [ElementReq(.air, 2), ElementReq(.land, 1)]),
        TCGCard(id: "the-red-sea", name: "The Red Sea", type: .event, cost: 0,
                requirement: [ElementReq(.sea, 2), ElementReq(.air, 1)]),
        TCGCard(id: "walls-of-jericho", name: "Walls of Jericho", type: .event, cost: 0,
                requirement: [ElementReq(.land, 3)]),
        TCGCard(id: "the-fiery-furnace", name: "The Fiery Furnace", type: .event, cost: 0,
                requirement: [ElementReq(.land, 2), ElementReq(.sea, 1)]),
        TCGCard(id: "the-lions-den", name: "The Lion's Den", type: .event, cost: 0,
                requirement: [ElementReq(.land, 3), ElementReq(.air, 1)]),
        TCGCard(id: "the-great-storm", name: "The Great Storm", type: .event, cost: 0,
                requirement: [ElementReq(.sea, 2), ElementReq(.air, 2)]),
        TCGCard(id: "tower-of-babylon", name: "Tower of Babylon", type: .event, cost: 0,
                requirement: [ElementReq(.air, 2), ElementReq(.land, 2)]),
        TCGCard(id: "the-whales-belly", name: "The Whale's Belly", type: .event, cost: 0,
                requirement: [ElementReq(.sea, 3), ElementReq(.land, 1)]),
        TCGCard(id: "the-tribulation", name: "The Tribulation", type: .event, cost: 0,
                requirement: [ElementReq(.air, 2), ElementReq(.land, 2), ElementReq(.sea, 2)]),
    ]
}
