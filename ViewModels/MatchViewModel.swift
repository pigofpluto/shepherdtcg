import Foundation
import SwiftUI

/// Drives a hot-seat (pass-and-play) TCG match on one device. Both sides are
/// human; between turns the board waits on a handoff screen so the next player
/// can pick up the phone without seeing the other's hand.
///
/// Vocabulary and rules follow `Resources/bible-tcg-rules.md`.
@MainActor
final class MatchViewModel: ObservableObject {

    let you = PlayerBoard(side: .you)      // Player 1 (bottom of the mat)
    let foe = PlayerBoard(side: .foe)      // Player 2 (top of the mat)

    @Published private(set) var phase: MatchPhase = .preparing
    @Published private(set) var turnSide: PlayerSide = .you
    @Published private(set) var turnNumber = 1
    @Published private(set) var winner: PlayerSide?
    @Published private(set) var log: [String] = []
    @Published var selected: CardInstance?      // chosen attacker/actor

    /// True while the device is being passed — hands stay hidden until the
    /// incoming player taps "I'm ready".
    @Published private(set) var awaitingHandoff = false

    // MARK: Presentation

    /// Set while an action is playing out its animation. Input is locked for the
    /// duration — every `can…` guard reads it — so taps can't interleave with a
    /// half-resolved board.
    @Published private(set) var busy = false

    /// Floating numbers, flashes and other transient cues. Self-expiring.
    @Published private(set) var cues: [VisualCue] = []

    /// An attack in flight: the view leans the attacker toward its target.
    /// `target` is nil for a Raid, which lunges at the enemy Basecamp.
    @Published private(set) var lunge: Lunge?

    struct Lunge { let attacker: UUID; let target: UUID?; let side: PlayerSide }

    /// A card mid-conversion. It's already in the Pool as far as the rules are
    /// concerned; this just holds it for one beat so the view can fly it to the
    /// Pool and dissolve it, rather than having it blink out of the hand.
    @Published private(set) var converting: CardInstance?

    /// An Event clear waiting on the player to pick which Relic turns over.
    ///
    /// The engine is `async`, so asking a question is just suspending: it awaits
    /// a continuation that the view resumes on tap. No separate state machine —
    /// the rest of the Event clear picks up exactly where it left off.
    @Published private(set) var relicChoice: RelicChoice?

    struct RelicChoice {
        let side: PlayerSide
        let options: [CardInstance]
        let resume: (CardInstance) -> Void
    }

    /// Called by the view when the player taps a Relic to turn over.
    func chooseRelic(_ inst: CardInstance) {
        guard let choice = relicChoice,
              choice.options.contains(where: { $0.id == inst.id }) else { return }
        relicChoice = nil
        choice.resume(inst)
    }

    /// Skips every animation pause, so the headless probe runs at full speed and
    /// no cue-expiry tasks are left dangling. Set by `Tests/EngineProbe.swift`.
    var instant = false

    /// One animation beat: publish what just changed, then hold long enough to
    /// see it. Every pause in the engine goes through here.
    private func beat(_ ms: UInt64 = 280) async {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) { bump() }
        guard !instant else { return }
        try? await Task.sleep(nanoseconds: ms * 1_000_000)
    }

    private func cue(_ kind: VisualCue.Kind, on card: CardInstance? = nil, side: PlayerSide) {
        guard !instant else { return }
        let c = VisualCue(card: card?.id, side: side, kind: kind)
        cues.append(c)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            self?.cues.removeAll { $0.id == c.id }
        }
    }

    /// The side that owns a card in play — cues need it to pick an anchor.
    private func owner(of c: CardInstance) -> PlayerSide {
        you.allInPlay.contains(where: { $0 === c }) ? .you : .foe
    }

    /// The player whose turn it is (and whose hand is visible).
    var activeBoard: PlayerBoard { board(turnSide) }
    var inactiveBoard: PlayerBoard { opp(turnSide) }

    func name(of s: PlayerSide) -> String { s == .you ? "Player 1" : "Player 2" }

    private let handMax = 7
    private let basecampMax = 4
    private let frontierMax = 5
    private let relicMax = 2
    private let poolMax = 10

    init() { setup() }

    private func note(_ s: String) { log.append(s); if log.count > 40 { log.removeFirst() } }
    private func bump() { objectWillChange.send() }

    // MARK: Setup

    /// Decks, Events and face-down Relics. No cards are dealt here — that's the
    /// preparing phase, which needs to await and so can't run from `init`.
    private func setup() {
        for b in [you, foe] {
            b.deck = Self.buildDeck()
            // Relics sit face-down in their slots from the start, outside the
            // deck. They're inert until an Event clear turns one up.
            for card in Self.buildRelics() {
                let inst = CardInstance(card, turn: 0)
                inst.zone = .basecamp
                inst.faceDown = true
                b.relics.append(inst)
            }
        }

        // Events 1 and 2 are private per player; Event 3 is the shared finale.
        // Only Event 1 starts face-up — the rest unlock in order.
        let finale = CardLibrary.card(id: "the-tribulation")!
        let pool = CardLibrary.events.filter { $0.id != finale.id }.shuffled()
        you.events = [EventProgress(pool[0], revealed: true),
                      EventProgress(pool[1], revealed: false),
                      EventProgress(finale, revealed: false)]
        foe.events = [EventProgress(pool[2], revealed: true),
                      EventProgress(pool[3], revealed: false),
                      EventProgress(finale, revealed: false)]

        #if DEBUG
        // Opt-in stacked board for checking animation by eye — see DebugSandbox.
        if DebugSandbox.isRequested {
            DebugSandbox.apply(you: you, foe: foe, turn: turnNumber)
            phase = .playing
            beginTurnState(.you)
            settleInstantly()
        }
        #endif
    }

    /// 28 bodies, **guaranteed to hold at least two costing 1**.
    ///
    /// The preparing phase seeds each Basecamp from the deck's cost-1 cards, and
    /// only 6 of the 69 bodies cost 1 — an unconstrained draw comes up short
    /// about one game in five, which would leave a player with no Basecamp.
    static func buildDeck() -> [TCGCard] {
        let bodies = CardLibrary.creatures + CardLibrary.humans
        let ones = bodies.filter { $0.cost == 1 }.shuffled()
        let rest = bodies.filter { $0.cost != 1 }.shuffled()

        let seeded = Array(ones.prefix(2))
        let remainder = (Array(ones.dropFirst(2)) + rest).shuffled()
        return (seeded + remainder.prefix(28 - seeded.count)).shuffled()
    }

    /// The 2 Relics set aside for a player. Never shuffled into the deck.
    static func buildRelics() -> [TCGCard] {
        Array(CardLibrary.relics.shuffled().prefix(2))
    }

    // MARK: The preparing phase

    /// Runs once before turn 1, from a `.task` on the board view. Nothing here
    /// needs a decision, so it plays as one animated sequence.
    ///
    /// The coin flip happens **first** so the draw can compensate for it: the
    /// player going first takes 3 cards, the other takes 4. Going first is a real
    /// edge with a Pool that ramps every turn, and the extra card is what offsets it.
    func runPreparation() async {
        guard phase == .preparing, !busy else { return }
        busy = true
        defer { busy = false; bump() }

        // Deterministic headless, so the probe can reason about turn order.
        let first: PlayerSide = instant ? .you : (Bool.random() ? .you : .foe)
        turnSide = first
        note("\(name(of: first)) wins the toss and goes first")
        await beat(600)

        // Seed both Basecamps *before* anything is dealt. `buildDeck()` only
        // guarantees the deck holds 2+ cost-1 cards — it says nothing about
        // where in the deck they land, so dealing first could draw one into a
        // hand and leave the seed short. Seeding off an untouched deck is what
        // actually makes the guarantee hold.
        let second = opp(first).side
        for side in [first, second] { await seedBasecamp(board(side)) }

        // 3 to whoever goes first, 4 to the other — dealt alternately so both
        // hands fill together.
        for i in 0..<4 {
            if i < 3 { drawCard(board(first)) }
            drawCard(board(second))
            await beat(190)
        }
        note("\(name(of: second)) draws an extra card for going second")
        await beat(420)

        phase = .playing
        note("\(name(of: first)) — turn 1, 0/0 mana")
        beginTurnState(first)
        await beat(300)
        await settle()
    }

    /// Two of the deck's cost-1 cards, at random, flipped into the Basecamp.
    /// Slot 0 becomes the Guardian, so which lands first matters — it's random,
    /// same as the pick.
    private func seedBasecamp(_ b: PlayerBoard) async {
        let ones = b.deck.enumerated().filter { $0.element.cost == 1 }.shuffled().prefix(2)
        // Remove from the deck highest-index-first so earlier indices stay valid.
        for (idx, card) in ones.sorted(by: { $0.offset > $1.offset }) {
            b.deck.remove(at: idx)
            let inst = CardInstance(card, turn: 0)
            inst.zone = .basecamp
            inst.enteredOn = 0          // old enough to March on turn 1
            inst.faceDown = true
            b.basecamp.append(inst)
            b.everDeployed = true
            await beat(260)             // it slides out of the deck, still face-down

            inst.faceDown = false
            note("\(name(of: b.side)) sets out \(card.name)")
            await beat(340)             // and turns over
        }
    }

    // MARK: Turn flow

    func board(_ s: PlayerSide) -> PlayerBoard { s == .you ? you : foe }
    private func opp(_ s: PlayerSide) -> PlayerBoard { s == .you ? foe : you }
    private func opp(_ b: PlayerBoard) -> PlayerBoard { b === you ? foe : you }

    /// The rules half of beginning a turn, with no pauses — shared by `setup()`
    /// (which can't await) and the animated `beginTurn`.
    private func beginTurnState(_ s: PlayerSide) {
        turnSide = s
        let b = board(s)

        b.mana = b.maxMana                  // refill to your Pool size — no free ramp
        b.convertedThisTurn = false
        b.playedCardThisTurn = false
        b.humansMarchedThisTurn = 0
        b.owlShieldGivenThisTurn = false

        for c in b.allInPlay {
            c.canAct = true
            if c.refreshesShield { c.shield = true; c.shieldExpires = nil }
        }
        drawCard(b)
        note("\(name(of: s)) — turn \(turnNumber), \(b.mana)/\(b.maxMana) mana")
    }

    private func beginTurn(_ s: PlayerSide) async {
        beginTurnState(s)
        await beat(320)             // the drawn card lands in hand
        await settle()
    }

    /// End the active player's turn and hand the device over.
    func endTurn() async {
        guard winner == nil, !awaitingHandoff, !busy else { return }
        busy = true
        defer { busy = false; bump() }

        selected = nil
        await endOfTurnCleanup()
        awaitingHandoff = true      // hide hands until the next player is ready
    }

    /// The incoming player taps "I'm ready" on the handoff screen.
    func confirmHandoff() async {
        guard awaitingHandoff, !busy else { return }
        busy = true
        defer { busy = false; bump() }

        awaitingHandoff = false
        turnNumber += 1
        await beginTurn(turnSide == .you ? .foe : .you)
    }

    /// Expire everything that was only good "this turn".
    private func endOfTurnCleanup() async {
        for b in [you, foe] {
            for c in b.allInPlay {
                c.tempAttack = 0
                c.tempHealth = 0
                c.doubleDamageCharges = 0
                c.unblockable = false
                if let expiry = c.shieldExpires, turnNumber >= expiry {
                    c.shield = false
                    c.shieldExpires = nil
                }
            }
        }
        await settle()
    }

    @discardableResult
    private func drawCard(_ b: PlayerBoard) -> CardInstance? {
        guard !b.deck.isEmpty else { return nil }
        let inst = CardInstance(b.deck.removeFirst(), turn: turnNumber)
        if b.hand.count >= handMax {                            // burn overflow
            inst.zone = .discard
            b.discard.append(inst)
        } else {
            inst.zone = .hand
            b.hand.append(inst)
            cue(.draw, on: inst, side: b.side)
        }
        return inst
    }

    // MARK: Mana — the Mana Pool

    /// Once per turn you may convert a card from hand into your Mana Pool.
    func canConvert(_ inst: CardInstance, on s: PlayerSide) -> Bool {
        let b = board(s)
        guard winner == nil, !awaitingHandoff, !busy else { return false }
        return !b.convertedThisTurn && b.maxMana < poolMax && b.hand.contains { $0.id == inst.id }
    }

    /// Convert a card to mana. It goes to the **Pool, not the discard** — the
    /// two are separate zones, so a converted card can never be recovered.
    func convert(_ inst: CardInstance, on s: PlayerSide) async {
        let b = board(s)
        guard canConvert(inst, on: s),
              let idx = b.hand.firstIndex(where: { $0.id == inst.id }) else { return }
        busy = true
        defer { busy = false; converting = nil; bump() }

        b.hand.remove(at: idx)
        inst.zone = .manaPool
        b.manaPool.append(inst)
        b.convertedThisTurn = true
        // Held for one beat so the view can fly it to the Pool and dissolve it.
        converting = inst
        await beat(300)

        converting = nil
        b.mana += 1                  // the new mana is usable the same turn
        cue(.manaGained, side: s)
        note("\(name(of: s)) converts \(inst.card.name) — \(b.maxMana) mana")
        await beat(240)              // the mana readout ticks up
        await settle()
    }

    /// Cost after Guard discounts (Whale, Camel) and Ark of the Covenant.
    func effectiveCost(_ card: TCGCard, for b: PlayerBoard) -> Int {
        var cost = card.cost
        if card.type == .creature, let element = card.element {
            if element == .sea, b.basecamp.contains(where: { $0.card.id == "whale" }) { cost -= 1 }
            if element == .land, b.basecamp.contains(where: { $0.card.id == "camel" }) { cost -= 1 }
        }
        if !b.playedCardThisTurn, b.hasRelic("ark-of-the-covenant") { cost -= 1 }
        return max(0, cost)
    }

    // MARK: Player actions

    func canPlay(_ inst: CardInstance, on s: PlayerSide) -> Bool {
        let b = board(s)
        guard winner == nil, !awaitingHandoff, !busy else { return false }
        guard effectiveCost(inst.card, for: b) <= b.mana else { return false }
        switch inst.card.type {
        // Relics are never in hand — they're set aside face-down at game start
        // and turned up by clearing Events.
        case .relic:            return false
        case .human, .creature: return b.basecamp.count < basecampMax
        case .event:            return false      // events aren't played from hand
        }
    }

    func play(_ inst: CardInstance, on s: PlayerSide) async {
        let b = board(s)
        guard canPlay(inst, on: s), let idx = b.hand.firstIndex(where: { $0.id == inst.id }) else { return }
        busy = true
        defer { busy = false; bump() }

        let cost = effectiveCost(inst.card, for: b)     // before playedCardThisTurn flips
        b.hand.remove(at: idx)
        b.mana -= cost
        b.playedCardThisTurn = true
        inst.enteredOn = turnNumber
        inst.canAct = inst.hasCharge

        inst.zone = .basecamp
        b.basecamp.append(inst)
        b.everDeployed = true
        note("\(name(of: s)) plays \(inst.card.name)")
        await beat(300)                                 // the card slides into Camp

        // Scroll of Wisdom grants every Wisdom Human a Play: draw.
        if inst.isHuman, inst.card.discipline == .wisdom, b.hasRelic("scroll-of-wisdom") {
            drawCard(b); note("Scroll of Wisdom draws for \(inst.card.name)")
        }
        firePlay(inst, b)
        await beat()                                    // its Play ability resolves
        await settle()
    }

    /// Banner of Courage grants Charge to your Courage Humans.
    private func hasCharge(_ inst: CardInstance, _ b: PlayerBoard) -> Bool {
        if inst.hasCharge { return true }
        return inst.isHuman && inst.card.discipline == .courage && b.hasRelic("banner-of-courage")
    }

    /// Ready to March — plus the "wall": you may never voluntarily empty your
    /// Basecamp (that would forfeit), so the last Basecamp card can't March.
    func canMarch(_ inst: CardInstance, on s: PlayerSide) -> Bool {
        let b = board(s)
        guard winner == nil, !awaitingHandoff, !busy else { return false }
        return inst.zone == .basecamp
            && (inst.enteredOn < turnNumber || hasCharge(inst, b))
            && b.basecamp.count > 1
            && b.frontier.count < frontierMax
    }

    /// Same wall for Sacrifice: a Frontier Creature is always fair game, but the
    /// last card sitting in your Basecamp can't be sacrificed away.
    func canSacrifice(_ inst: CardInstance, on s: PlayerSide) -> Bool {
        let b = board(s)
        guard winner == nil, !awaitingHandoff, !busy, inst.isCreature else { return false }
        return inst.zone == .frontier || b.basecamp.count > 1
    }

    func march(_ inst: CardInstance, on s: PlayerSide) async {
        let b = board(s)
        guard canMarch(inst, on: s),
              let idx = b.basecamp.firstIndex(where: { $0.id == inst.id }) else { return }
        busy = true
        defer { busy = false; bump() }

        b.basecamp.remove(at: idx)
        inst.zone = .frontier
        inst.enteredOn = turnNumber
        inst.canAct = true
        b.frontier.append(inst)
        note("\(name(of: s)) marches \(inst.card.name)")
        await beat(320)                     // the card walks out to the Frontier

        if inst.isHuman {
            b.humansMarchedThisTurn += 1
            // Owl (Guard): arm the first Human to March each turn.
            if !b.owlShieldGivenThisTurn, b.basecamp.contains(where: { $0.card.id == "owl" }) {
                inst.grantShield(until: turnNumber)      // until end of this turn
                b.owlShieldGivenThisTurn = true
                note("Owl shields \(inst.card.name)")
            }
        }
        fireMarch(inst, b)
        await beat()                        // its March ability resolves
        await settle()
    }

    /// Attack an enemy Frontier card, or Raid the Guardian if `target` is nil.
    func attack(_ attacker: CardInstance, target: CardInstance?, on s: PlayerSide) async {
        let b = board(s), o = opp(s)
        guard winner == nil, !awaitingHandoff, !busy else { return }
        guard attacker.zone == .frontier, attacker.canAct else { return }
        // Resolve the Raid's victim up front so nothing is half-committed if the
        // lunge has no legal target.
        let victim: CardInstance?
        if let target {
            guard target.zone == .frontier else { return }
            victim = target
        } else {
            guard o.frontier.isEmpty || attacker.unblockable, let g = o.guardian else { return }
            victim = g
        }
        busy = true
        defer { busy = false; lunge = nil; bump() }

        attacker.canAct = false
        lunge = Lunge(attacker: attacker.id, target: victim?.id, side: s)
        await beat(200)                     // the attacker leans in

        if let target {
            deal(strikeDamage(attacker), to: target, from: attacker)
            deal(target.attack, to: attacker, from: target)      // the defender hits back
            note("\(attacker.card.name) attacks \(target.card.name)")
            lunge = nil
            await beat(340)                 // impact, damage numbers, recoil
        } else {
            let guardian = victim!
            var damage = strikeDamage(attacker)
            if attacker.card.id == "h_joshua" {
                damage += 2
                note("Joshua presses the Guardian")
            }
            deal(damage, to: guardian, from: attacker)           // Raid — no retaliation
            note("\(attacker.card.name) raids \(guardian.card.name)")
            lunge = nil
            await beat(340)
            fireRaid(attacker, b, defender: o)
            await beat()                    // its Raid ability resolves
        }
        await settle()
    }

    func sacrifice(_ inst: CardInstance, on s: PlayerSide) async {
        let b = board(s), o = opp(s)
        guard canSacrifice(inst, on: s) else { return }
        busy = true
        defer { busy = false; bump() }

        removeFromPlay(inst, b)
        inst.zone = .altar
        b.altar.append(inst)
        await beat(320)                     // the card arcs onto the Altar

        let (element, points) = sacrificeValue(inst, b)
        b.elements[element, default: 0] += points
        cue(.points(element, points), side: s)
        note("\(name(of: s)) sacrifices \(inst.card.name) (+\(points) \(element.displayName) points)")
        await beat(300)                     // the points drift to their counter

        fireSacrifice(inst, b)

        // Guard reactions to any Sacrifice.
        for h in b.basecamp where h.card.id == "farmer" {
            h.buff(attack: 1, health: 0)
            cue(.buff(attack: 1, health: 0), on: h, side: s)
            note("Farmer grows stronger")
        }
        for h in b.basecamp where h.card.id == "priest" && h.isDamaged {
            let healed = h.damage
            h.healToFull()
            cue(.heal(healed), on: h, side: s)
            note("Priest is restored")
        }
        if b.hasRelic("altar-of-fire"),
           let t = o.frontier.filter({ $0.isCreature }).randomElement() {
            deal(1, to: t, from: inst); note("Altar of Fire scorches \(t.card.name)")
        }
        await beat()                        // its Sacrifice ability resolves

        await overcomeEvents(b)
        await settle()
    }

    // MARK: Combat helpers

    /// Attack value for one strike, spending a Warrior Chief double-damage charge.
    private func strikeDamage(_ c: CardInstance) -> Int {
        if c.doubleDamageCharges > 0 {
            c.doubleDamageCharges -= 1
            return c.attack * 2
        }
        return c.attack
    }

    private func deal(_ amount: Int, to c: CardInstance, from source: CardInstance? = nil) {
        guard amount > 0 else { return }
        let side = owner(of: c)
        if c.shield {
            c.shield = false; c.shieldExpires = nil
            cue(.shieldBreak, on: c, side: side)
            return
        }
        c.damage += amount
        cue(.damage(amount), on: c, side: side)
        if c.health <= 0, c.killedBy == nil { c.killedBy = source }
    }

    private func removeFromPlay(_ inst: CardInstance, _ b: PlayerBoard) {
        b.basecamp.removeAll { $0.id == inst.id }
        b.frontier.removeAll { $0.id == inst.id }
    }

    /// The single death path — removal, discard, and the Death trigger. Effects
    /// that "destroy" a card route through here so Death always fires.
    private func destroy(_ inst: CardInstance, _ b: PlayerBoard) {
        removeFromPlay(inst, b)
        inst.zone = .discard
        b.discard.append(inst)
        note("\(inst.card.name) falls")
        fireDeath(inst, b)
    }

    @discardableResult
    private func cleanupDeaths() -> Bool {
        var died = false
        for b in [you, foe] {
            for c in b.allInPlay where c.health <= 0 {
                destroy(c, b)
                died = true
            }
        }
        return died
    }

    /// Everything currently at or below 0 Health, across both boards.
    private func dying() -> [(CardInstance, PlayerSide)] {
        [you, foe].flatMap { b in b.allInPlay.filter { $0.health <= 0 }.map { ($0, b.side) } }
    }

    /// Recompute auras, resolve any deaths they cause, and repeat until stable.
    /// Losing an aura can drop a card's max Health at or below its damage, which
    /// kills it, which can in turn remove another aura source.
    ///
    /// Each pass of that loop is one **wave**, and each wave gets its own beats —
    /// so "Locust stings X → X dies → Y loses Elder's aura → Y dies" plays out as
    /// separate steps instead of collapsing into a single frame.
    private func settle() async {
        for _ in 0..<4 {
            refreshAuras()
            let doomed = dying()
            if doomed.isEmpty { break }
            for (c, side) in doomed { cue(.death, on: c, side: side) }
            await beat(240)                 // the doomed cards flash
            cleanupDeaths()
            await beat(300)                 // and drop onto the discard
        }
        refreshAuras()
        checkEnd()
        bump()
    }

    /// The rules half of `settle()`, with no pauses — used at setup, where
    /// there's no one watching and `init` can't await.
    private func settleInstantly() {
        for _ in 0..<4 {
            refreshAuras()
            if !cleanupDeaths() { break }
        }
        refreshAuras()
        checkEnd()
        bump()
    }

    // MARK: Continuous effects (Guard auras + Relics)

    private func refreshAuras() {
        for b in [you, foe] {
            for c in b.allInPlay { c.auraAttack = 0; c.auraHealth = 0 }
        }
        for b in [you, foe] { applyAuras(b) }
    }

    private func applyAuras(_ b: PlayerBoard) {
        // Guard abilities are live only while their source sits in the Basecamp.
        for src in b.basecamp {
            switch src.card.id {
            case "lion":       b.guardian?.auraAttack += 2
            case "h_nehemiah": b.guardian?.auraHealth += 2
            case "elder":
                for c in b.frontier where c.isHuman { c.auraHealth += 1 }
            case "h_abraham":
                for c in b.allInPlay where c.isHuman && c !== src { c.auraHealth += 1 }
            case "h_deborah":
                for c in b.allInPlay where c.isHuman && c.card.discipline == .courage { c.auraAttack += 1 }
            default: break
            }
        }
        // Relics stay live for as long as they sit in their slot.
        if b.hasRelic("shepherds-staff") {
            for c in b.frontier { c.auraHealth += 2 }
        }
        if b.hasRelic("banner-of-courage") {
            for c in b.allInPlay where c.isHuman && c.card.discipline == .courage { c.auraAttack += 1 }
        }
        if b.hasRelic("shield-of-strength") {
            for c in b.allInPlay where c.isHuman && c.card.discipline == .strength { c.auraHealth += 2 }
        }
    }

    // MARK: Events / win-lose

    /// Base points, then flat modifiers, then multipliers — see rules doc.
    private func sacrificeValue(_ inst: CardInstance, _ b: PlayerBoard) -> (Element, Int) {
        var points: Int
        switch inst.card.id {
        case "minnow-shoal": points = 2
        case "kraken":       points = 3
        case "ant":          points = 2
        default:             points = 1
        }
        if b.basecamp.contains(where: { $0.card.id == "h_moses" }) { points += 1 }   // Guard
        if b.hasRelic("fish-net") { points *= 2 }
        return (inst.card.element ?? .land, points)
    }

    /// Events clear in order, one at a time. Clearing subtracts exactly the
    /// requirement (surplus carries), flushes the Altar, and reveals the next.
    /// Clears cascade while the banked points hold out.
    private func overcomeEvents(_ b: PlayerBoard) async {
        while let idx = b.currentEventIndex,
              b.isUnlocked(idx),
              b.events[idx].affordable(by: b.elements) {
            let event = b.events[idx]
            for req in event.card.requirement { b.elements[req.element, default: 0] -= req.count }
            event.cleared = true
            note("\(name(of: b.side)) overcame \(event.card.name)!")
            await beat(420)                 // the Event slot stamps cleared

            for c in b.altar { c.zone = .discard }
            b.discard.append(contentsOf: b.altar)
            b.altar.removeAll()
            await beat(320)                 // the Altar sweeps into the discard

            // Guard: Prophet draws whenever you overcome an Event.
            for h in b.basecamp where h.card.id == "prophet" {
                drawCard(b); note("Prophet draws")
            }

            // Clearing an Event turns over one of your face-down Relics. This
            // sits inside the cascade loop deliberately: banked points can clear
            // Event 1 and the Event 2 it just revealed in one action, and that
            // has to unlock a Relic for each — not one for both.
            await unlockRelic(b)

            // Reveal the next Event on this board.
            if b.events.indices.contains(idx + 1) { b.events[idx + 1].revealed = true }
            // Unlocking Event 3 reveals it to BOTH players — it's the shared finale.
            if idx == 1 {
                you.events[2].revealed = true
                foe.events[2].revealed = true
                note("The Tribulation is revealed to both players")
            }
        }
    }

    /// Turn one face-down Relic up. With two left the player picks; with one
    /// there's nothing to decide, so it just flips.
    ///
    /// The choice is only meaningful because the chooser shows both faces — decks
    /// are random, so a player has no other way to know what they're holding.
    private func unlockRelic(_ b: PlayerBoard) async {
        let hidden = b.faceDownRelics
        guard !hidden.isEmpty else { return }

        let pick: CardInstance
        if hidden.count == 1 || instant {
            pick = hidden[0]
        } else {
            pick = await withCheckedContinuation { cont in
                relicChoice = RelicChoice(side: b.side, options: hidden) { cont.resume(returning: $0) }
                bump()
            }
        }

        pick.faceDown = false
        note("\(name(of: b.side)) unlocks \(pick.card.name)")
        await beat(520)             // the Relic turns over in its slot
    }

    private func checkEnd() {
        guard winner == nil else { return }
        if you.hasWon { winner = .you; note("\(name(of: .you)) reaches the Promised Land!") }
        else if foe.hasWon { winner = .foe; note("\(name(of: .foe)) reaches the Promised Land!") }
        // Empty Basecamp = defeat. Safe to enforce because the March/Sacrifice
        // wall prevents you from ever emptying it voluntarily.
        else if you.everDeployed && you.basecamp.isEmpty {
            winner = .foe; note("\(name(of: .you))'s Basecamp has fallen.")
        } else if foe.everDeployed && foe.basecamp.isEmpty {
            winner = .you; note("\(name(of: .foe))'s Basecamp has fallen.")
        }
    }

    // MARK: Triggers

    private func firePlay(_ inst: CardInstance, _ b: PlayerBoard) {
        let o = opp(b)
        switch inst.card.id {
        case "shepherd-boy", "raven", "donkey", "h_joseph", "h_isaiah",
             "h_baptist", "h_magi", "h_solomon", "young-scribe", "h_paul", "h_matthew":
            drawCard(b)
        case "h_eve":
            drawCard(b); drawCard(o)
        case "h_elijah":
            if let t = strongestFrontierCreature(o) {
                deal(3, to: t, from: inst); note("Elijah calls down fire on \(t.card.name)")
            }
        case "h_jael":
            if let t = o.frontier.first(where: { $0.isCreature && $0.isDamaged }) {
                note("Jael finishes \(t.card.name)"); destroy(t, o)
            }
        default: break
        }
    }

    private func fireMarch(_ inst: CardInstance, _ b: PlayerBoard) {
        switch inst.card.id {
        case "herald":
            if b.humansMarchedThisTurn == 1 { drawCard(b); note("Herald draws") }
        case "fisherman", "h_peter":
            if b.allInPlay.contains(where: { $0.card.element == .sea }) {
                inst.buffTemp(attack: 1, health: 1)
                cue(.buff(attack: 1, health: 1), on: inst, side: b.side)
                note("\(inst.card.name) is emboldened")
            }
        case "warrior-chief":
            inst.doubleDamageCharges = 1; note("Warrior Chief readies a heavy blow")
        case "eagle":
            inst.unblockable = true; note("Eagle takes to the air")
        default: break
        }
    }

    private func fireRaid(_ attacker: CardInstance, _ b: PlayerBoard, defender o: PlayerBoard) {
        switch attacker.card.id {
        case "judge":
            drawCard(b); note("Judge draws")
        case "champion":
            // Everything behind the Guardian; lowest Health first.
            if let t = o.basecamp.dropFirst().min(by: { $0.health < $1.health }) {
                deal(attacker.attack, to: t, from: attacker)
                note("Champion also strikes \(t.card.name)")
            }
        default: break
        }
        // Watchtower belongs to the DEFENDER.
        if o.hasRelic("watchtower") {
            drawCard(o); note("Watchtower draws for \(name(of: o.side))")
        }
    }

    private func fireSacrifice(_ inst: CardInstance, _ b: PlayerBoard) {
        let o = opp(b)
        let nextTurn = turnNumber + 2      // "until your next turn"
        switch inst.card.id {
        case "sparrow":
            drawCard(b); note("Sparrow draws")
        case "locust":
            if let t = weakestFrontierCreature(o) {
                deal(1, to: t, from: inst); note("Locust stings \(t.card.name)")
            }
        case "great-fish":
            if let t = strongestFrontierCreature(o) {
                deal(4, to: t, from: inst); note("Great Fish crashes into \(t.card.name)")
            }
        case "serpent":
            if let t = o.frontier.first(where: { $0.isCreature && $0.health <= 3 }) {
                note("Serpent strikes down \(t.card.name)"); destroy(t, o)
            }
        case "golden-jackal":
            blessHuman(b, where: { $0.card.discipline == .courage }) {
                $0.buff(attack: 1, health: 0)
                self.cue(.buff(attack: 1, health: 0), on: $0, side: b.side)
            }
        case "great-bear":
            blessHuman(b, where: { $0.card.discipline == .strength }) {
                $0.buff(attack: 2, health: 3)
                self.cue(.buff(attack: 2, health: 3), on: $0, side: b.side)
            }
        case "raven":
            if blessHuman(b, where: { $0.card.discipline == .wisdom }, effect: { _ in }) != nil {
                drawCard(b); note("Raven's wisdom draws a card")
            }
        case "dove":
            blessHuman(b, where: { _ in true }) { $0.grantShield(until: nextTurn) }
        case "lamb":
            blessHuman(b, where: { _ in true }) {
                $0.buff(attack: 0, health: 2)
                self.cue(.buff(attack: 0, health: 2), on: $0, side: b.side)
            }
        case "river-otter":
            if let i = b.discard.firstIndex(where: { $0.isHuman }) {
                let h = b.discard.remove(at: i)
                h.zone = .hand
                if b.hand.count < handMax { b.hand.append(h); note("River Otter returns \(h.card.name)") }
                else { b.discard.append(h) }
            }
        default: break
        }
    }

    /// A Sacrifice ability that targets one of your Humans — a **Blessing**.
    /// Routed through one place so High Priest's Guard can react to all of them.
    @discardableResult
    private func blessHuman(_ b: PlayerBoard,
                            where pick: (CardInstance) -> Bool,
                            effect: (CardInstance) -> Void) -> CardInstance? {
        guard let h = b.allInPlay.first(where: { $0.isHuman && pick($0) }) else { return nil }
        effect(h)
        // Guard: High Priest also gains Shield when a Sacrifice targets it.
        if h.card.id == "high-priest", h.zone == .basecamp {
            h.grantShield(until: turnNumber + 2)
            note("High Priest is shielded")
        }
        return h
    }

    private func fireDeath(_ inst: CardInstance, _ b: PlayerBoard) {
        switch inst.card.id {
        case "griffin-vulture":
            drawCard(b); note("Griffin Vulture draws")
        case "golden-jackal":
            if let killer = inst.killedBy, killer.isCreature, killer.health > 0 {
                deal(1, to: killer, from: inst)
                note("Golden Jackal bites back at \(killer.card.name)")
            }
        case "physician":
            let hurt = b.frontier.filter { $0.isHuman && $0 !== inst && $0.isDamaged }
            for h in hurt {
                h.heal(2)
                cue(.heal(2), on: h, side: b.side)
            }
            if !hurt.isEmpty { note("Physician's last work heals the Frontier") }
        case "h_samson":
            for board in [you, foe] {
                for c in board.frontier where c.isCreature { deal(3, to: c, from: inst) }
            }
            note("Samson brings down the pillars")
        default: break
        }
    }

    // Targeting helpers. "Creature" means the card type — Humans in the Frontier
    // are never valid targets for Creature-targeting text.
    private func strongestFrontierCreature(_ b: PlayerBoard) -> CardInstance? {
        b.frontier.filter { $0.isCreature }.max(by: { $0.attack < $1.attack })
    }
    private func weakestFrontierCreature(_ b: PlayerBoard) -> CardInstance? {
        b.frontier.filter { $0.isCreature }.min(by: { $0.health < $1.health })
    }
}
