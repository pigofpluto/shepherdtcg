import Foundation

// Headless probe for the Bible TCG engine. Drives MatchViewModel directly with
// stacked boards so each rule can be asserted instead of hunted for in a match.

var passed = 0, failed = 0

func check(_ label: String, _ cond: @autoclosure () -> Bool, _ detail: @autoclosure () -> String = "") {
    if cond() { passed += 1; print("  ok   \(label)") }
    else { failed += 1; print("  FAIL \(label)\(detail().isEmpty ? "" : "  — \(detail())")") }
}

func section(_ s: String) { print("\n== \(s) ==") }

@MainActor
func card(_ id: String, turn: Int = 1) -> CardInstance {
    CardInstance(CardLibrary.card(id: id)!, turn: turn)
}

/// Force the engine to run settle()/auras without caring what action does it.
@MainActor
func poke(_ vm: MatchViewModel, _ side: PlayerSide) async {
    let b = vm.board(side)
    b.convertedThisTurn = false
    b.manaPool.removeAll()
    let filler = card("sparrow")
    b.hand.append(filler)
    await vm.convert(filler, on: side)
}

/// Stock a Mana Pool directly. Mana is derived from the Pool's size, so tests
/// that just need spendable mana have to put cards in it rather than set a number.
@MainActor
func fillPool(_ b: PlayerBoard, _ n: Int) {
    b.manaPool.removeAll()
    for _ in 0..<n {
        let c = card("watchman")
        c.zone = .manaPool
        b.manaPool.append(c)
    }
    b.mana = b.maxMana
}

@MainActor
func freshMatch() async -> MatchViewModel {
    let vm = MatchViewModel()
    // Headless: no animation pauses, no cue-expiry tasks left dangling.
    vm.instant = true
    // Cards are dealt by the preparing phase now, not by init. Run it so the
    // match is in a playable state, then clear the board for the test to stack.
    await vm.runPreparation()
    // Neutral three-element ladder so a single-element Sacrifice in a non-Event
    // test can't accidentally clear a randomly-dealt Event and flush the Altar.
    let inert = CardLibrary.card(id: "the-tribulation")!
    for b in [vm.you, vm.foe] {
        b.hand.removeAll(); b.basecamp.removeAll(); b.frontier.removeAll()
        b.altar.removeAll(); b.discard.removeAll(); b.relics.removeAll()
        b.elements = [.air: 0, .sea: 0, .land: 0]
        b.events = (0..<3).map { EventProgress(inert, revealed: $0 == 0) }
        // Preparation deployed a Basecamp and we just emptied it. Without this
        // the next settle() calls the match lost on the empty-Basecamp rule, and
        // every later action silently no-ops on its `winner == nil` guard.
        b.everDeployed = false
    }
    return vm
}

@main
struct Probe {
    @MainActor static func main() async {

        // ─────────────────────────────────────────────────────────────
        section("Mana — the Mana Pool")
        do {
            let vm = MatchViewModel()
            vm.instant = true
            await vm.runPreparation()
            check("starts with an empty Pool", vm.you.maxMana == 0 && vm.you.mana == 0)
            let c = vm.you.hand[0]
            check("can convert on turn 1", vm.canConvert(c, on: .you))
            await vm.convert(c, on: .you)
            check("converting gives 1 mana, usable now", vm.you.maxMana == 1 && vm.you.mana == 1)
            // The Pool is a separate zone from the discard — this is what stops
            // discard recursion recovering a card you spent as mana.
            check("converted card is in the Pool", vm.you.manaPool.contains { $0 === c })
            check("converted card is NOT in the discard", !vm.you.discard.contains { $0 === c })
            check("cannot convert twice in a turn", !vm.canConvert(vm.you.hand[0], on: .you))

            await vm.endTurn(); await vm.confirmHandoff()          // -> Player 2
            check("P2's Pool is still empty", vm.foe.maxMana == 0)
            await vm.endTurn(); await vm.confirmHandoff()          // -> Player 1
            check("Pool persists and mana refills", vm.you.maxMana == 1 && vm.you.mana == 1)

            fillPool(vm.you, 10)
            check("cannot convert at the 10-card Pool cap", !vm.canConvert(vm.you.hand[0], on: .you))
        }
        do {
            // The interaction the rules call out by name: River Otter returns a
            // Human from your *discard*, and a converted card never goes there.
            let vm = await freshMatch()
            let otter = card("river-otter")
            vm.you.frontier.append(otter); otter.zone = .frontier
            let human = card("craftsman")
            vm.you.hand.append(human)
            await vm.convert(human, on: .you)
            await vm.sacrifice(otter, on: .you)
            check("River Otter cannot recover a converted Human",
                  !vm.you.hand.contains { $0 === human } && vm.you.manaPool.contains { $0 === human })
        }

        // ─────────────────────────────────────────────────────────────
        section("Preparing phase")
        do {
            let vm = MatchViewModel()
            vm.instant = true
            await vm.runPreparation()

            check("both Basecamps hold 2 cards",
                  vm.you.basecamp.count == 2 && vm.foe.basecamp.count == 2)
            check("every seeded card costs 1",
                  (vm.you.basecamp + vm.foe.basecamp).allSatisfy { $0.card.cost == 1 })
            check("seeded cards are face-up",
                  (vm.you.basecamp + vm.foe.basecamp).allSatisfy { !$0.faceDown })
            let first = vm.turnSide, second: PlayerSide = first == .you ? .foe : .you
            check("both start at 0 mana", vm.you.maxMana == 0 && vm.foe.maxMana == 0)
            check("the match is playable", vm.phase == .playing)
            // Nothing is duplicated or lost: seeded cards and dealt cards both
            // come out of the same 28.
            check("cards are conserved out of the 28-card deck",
                  [vm.you, vm.foe].allSatisfy { $0.deck.count + $0.basecamp.count + $0.hand.count == 28 })

            // Going first is a real edge with a Pool that ramps every turn. The
            // second player is dealt one extra card to offset it — which shows
            // up when they actually take their first turn, since the player
            // going first has already drawn theirs.
            check("first player opens their turn with 4 cards",
                  vm.board(first).hand.count == 4, "got \(vm.board(first).hand.count)")
            await vm.endTurn(); await vm.confirmHandoff()
            check("second player opens their turn one card ahead",
                  vm.board(second).hand.count == 5, "got \(vm.board(second).hand.count)")
        }

        // ─────────────────────────────────────────────────────────────
        section("Relics unlock from Events")
        do {
            let vm = MatchViewModel()
            vm.instant = true
            await vm.runPreparation()
            check("both players hold 2 face-down Relics",
                  vm.you.relics.count == 2 && vm.you.faceDownRelics.count == 2
                      && vm.foe.faceDownRelics.count == 2)

            // The whole reason `hasRelic` checks face-up: both Relics are on the
            // board from turn 1, so without it every Relic in the game would be
            // live before it was ever unlocked.
            let inert = vm.you.relics.allSatisfy { !vm.you.hasRelic($0.card.id) }
            check("a face-down Relic is inert", inert)

            let target = vm.you.relics[0]
            target.faceDown = false
            check("turning it face-up switches it on", vm.you.hasRelic(target.card.id))
        }
        do {
            let vm = await freshMatch()
            let relics = MatchViewModel.buildRelics().map { c -> CardInstance in
                let i = CardInstance(c, turn: 0); i.faceDown = true; return i
            }
            vm.you.relics = relics
            // Two cheap Events so banked points clear both in one cascade — each
            // clear must unlock a Relic, not one between them.
            let cheap = CardLibrary.events.min { $0.requirement.count < $1.requirement.count }!
            vm.you.events = [EventProgress(cheap, revealed: true),
                             EventProgress(cheap, revealed: true),
                             EventProgress(cheap, revealed: false)]
            for req in cheap.requirement { vm.you.elements[req.element] = req.count * 2 }

            let anchor = card("craftsman"); anchor.zone = .basecamp
            vm.you.basecamp.append(anchor); vm.you.everDeployed = true
            let sparrow = card("sparrow"); sparrow.zone = .frontier
            vm.you.frontier.append(sparrow)
            await vm.sacrifice(sparrow, on: .you)

            check("a cascade of two clears unlocks two Relics",
                  vm.you.events.prefix(2).allSatisfy(\.cleared)
                      && vm.you.faceDownRelics.isEmpty,
                  "cleared \(vm.you.events.prefix(2).filter(\.cleared).count), "
                      + "\(vm.you.faceDownRelics.count) still face-down")
        }
        do {
            let vm = await freshMatch()
            fillPool(vm.you, 10)
            let relic = card("watchtower")
            vm.you.hand.append(relic)
            check("Relics cannot be played from hand", !vm.canPlay(relic, on: .you))
        }

        // ─────────────────────────────────────────────────────────────
        section("Cost hooks")
        do {
            let vm = await freshMatch()
            let whale = card("whale")
            vm.you.basecamp.append(whale); whale.zone = .basecamp
            let kraken = CardLibrary.card(id: "kraken")!      // Sea, cost 6
            check("Whale discounts Sea Creatures", vm.effectiveCost(kraken, for: vm.you) == 5)
            let boar = CardLibrary.card(id: "wild-boar")!     // Land, cost 3
            check("Whale does not discount Land", vm.effectiveCost(boar, for: vm.you) == 3)

            vm.you.basecamp.removeAll()
            let camel = card("camel")
            vm.you.basecamp.append(camel); camel.zone = .basecamp
            check("Camel discounts Land Creatures", vm.effectiveCost(boar, for: vm.you) == 2)

            let vm2 = await freshMatch()
            vm2.you.relics.append(card("ark-of-the-covenant"))
            check("Ark discounts the first card", vm2.effectiveCost(boar, for: vm2.you) == 2)
            vm2.you.playedCardThisTurn = true
            check("Ark does not discount the second", vm2.effectiveCost(boar, for: vm2.you) == 3)
        }

        // ─────────────────────────────────────────────────────────────
        section("Guard auras")
        do {
            let vm = await freshMatch()
            let elder = card("elder"), soldier = card("soldier")
            vm.you.basecamp.append(elder); elder.zone = .basecamp
            vm.you.frontier.append(soldier); soldier.zone = .frontier
            await poke(vm, .you)
            check("Elder gives Frontier Humans +0/+1", soldier.maxHealth == 3, "got \(soldier.maxHealth)")

            // A Human sitting at exactly the aura's worth of health dies when it lapses.
            soldier.damage = 2                       // 3 max - 2 = 1 health
            vm.you.basecamp.removeAll()              // Elder leaves
            await poke(vm, .you)
            check("aura retracts and kills the dependent card",
                  vm.you.frontier.isEmpty && vm.you.discard.contains { $0 === soldier })
        }
        do {
            let vm = await freshMatch()
            let elder = card("elder", turn: 0), soldier = card("soldier")
            let filler = card("watchman")
            vm.you.basecamp.append(contentsOf: [elder, filler])
            elder.zone = .basecamp; filler.zone = .basecamp
            vm.you.frontier.append(soldier); soldier.zone = .frontier
            await poke(vm, .you)
            check("Guard is live from the Basecamp", soldier.maxHealth == 3)
            await vm.march(elder, on: .you)
            check("Guard switches off once it Marches", soldier.maxHealth == 2, "got \(soldier.maxHealth)")
        }
        do {
            let vm = await freshMatch()
            let lion = card("lion"), guardian = card("craftsman")
            vm.you.basecamp.append(contentsOf: [guardian, lion])
            guardian.zone = .basecamp; lion.zone = .basecamp
            await poke(vm, .you)
            check("Lion gives the Guardian +2/+0", guardian.attack == 5, "got \(guardian.attack)")
            check("Lion does not buff itself when it isn't Guardian", lion.attack == 4)
        }
        do {
            let vm = await freshMatch()
            let deborah = card("h_deborah"), soldier = card("soldier")
            vm.you.basecamp.append(deborah); deborah.zone = .basecamp
            vm.you.frontier.append(soldier); soldier.zone = .frontier
            vm.you.relics.append(card("banner-of-courage"))
            await poke(vm, .you)
            check("Deborah + Banner stack on a Courage Human", soldier.attack == 6, "got \(soldier.attack)")
        }

        // ─────────────────────────────────────────────────────────────
        section("Raid triggers")
        do {
            let vm = await freshMatch()
            let judge = card("judge", turn: 0)
            vm.you.frontier.append(judge); judge.zone = .frontier; judge.canAct = true
            let target = card("craftsman")
            vm.foe.basecamp.append(target); target.zone = .basecamp
            vm.foe.deck = [CardLibrary.card(id: "sparrow")!]
            vm.you.deck = [CardLibrary.card(id: "sparrow")!]
            let before = vm.you.hand.count
            await vm.attack(judge, target: nil, on: .you)
            check("Judge draws on Raid", vm.you.hand.count == before + 1)
            check("Raid damages the Guardian", target.damage == 4, "got \(target.damage)")
        }
        do {
            let vm = await freshMatch()
            let champion = card("champion", turn: 0)
            vm.you.frontier.append(champion); champion.zone = .frontier; champion.canAct = true
            let guardian = card("h_goliath"), weak = card("watchman"), mid = card("craftsman")
            vm.foe.basecamp.append(contentsOf: [guardian, mid, weak])
            for c in vm.foe.basecamp { c.zone = .basecamp }
            await vm.attack(champion, target: nil, on: .you)
            check("Champion hits the Guardian", guardian.damage == 7, "got \(guardian.damage)")
            check("Champion also hits lowest-Health behind it",
                  vm.foe.discard.contains { $0 === weak }, "watchman should have died")
            check("Champion spares the healthier one", mid.damage == 0)
        }
        do {
            let vm = await freshMatch()
            let soldier = card("soldier", turn: 0)
            vm.you.frontier.append(soldier); soldier.zone = .frontier; soldier.canAct = true
            let g = card("h_goliath"); vm.foe.basecamp.append(g); g.zone = .basecamp
            vm.foe.relics.append(card("watchtower"))
            vm.foe.deck = [CardLibrary.card(id: "sparrow")!]
            let before = vm.foe.hand.count
            await vm.attack(soldier, target: nil, on: .you)
            check("Watchtower draws for the DEFENDER", vm.foe.hand.count == before + 1)
        }

        // ─────────────────────────────────────────────────────────────
        section("Shield")
        do {
            let vm = await freshMatch()
            let kg = card("kings-guard")
            vm.you.basecamp.append(kg); kg.zone = .basecamp
            check("printed Shield starts up", kg.shield)
            let attacker = card("soldier", turn: 0)
            vm.foe.frontier.append(attacker); attacker.zone = .frontier; attacker.canAct = true
            await vm.attack(attacker, target: nil, on: .foe)
            check("Shield absorbs the first hit", kg.damage == 0 && !kg.shield)
            await vm.endTurn(); await vm.confirmHandoff()          // -> Player 2's turn
            check("Shield stays down during the opponent's turn", !kg.shield)
            await vm.endTurn(); await vm.confirmHandoff()          // -> back to Player 1
            check("Shield refreshes on its owner's turn", kg.shield)
        }

        // ─────────────────────────────────────────────────────────────
        section("Creature-only targeting")
        do {
            let vm = await freshMatch()
            let locust = card("locust")
            vm.you.frontier.append(locust); locust.zone = .frontier
            let human = card("craftsman")
            vm.foe.frontier.append(human); human.zone = .frontier
            await vm.sacrifice(locust, on: .you)
            check("Locust cannot hit a Human in the Frontier", human.damage == 0)

            let vm2 = await freshMatch()
            let locust2 = card("locust")
            vm2.you.frontier.append(locust2); locust2.zone = .frontier
            let beast = card("behemoth-calf")
            vm2.foe.frontier.append(beast); beast.zone = .frontier
            await vm2.sacrifice(locust2, on: .you)
            check("Locust does hit a Creature", beast.damage == 1)
        }

        // ─────────────────────────────────────────────────────────────
        section("Death triggers")
        do {
            let vm = await freshMatch()
            let physician = card("physician"), other = card("craftsman")
            vm.you.frontier.append(contentsOf: [physician, other])
            physician.zone = .frontier; other.zone = .frontier
            other.damage = 3
            physician.damage = 99
            await poke(vm, .you)
            check("Physician's Death heals other Frontier Humans", other.damage == 1, "got \(other.damage)")
        }
        do {
            let vm = await freshMatch()
            let serpent = card("serpent")
            vm.you.frontier.append(serpent); serpent.zone = .frontier
            let vulture = card("griffin-vulture")     // Death: draw
            vulture.damage = 2                        // 4 hp -> 2, within Serpent's 3
            vm.foe.frontier.append(vulture); vulture.zone = .frontier
            vm.foe.deck = [CardLibrary.card(id: "sparrow")!]
            let before = vm.foe.hand.count
            await vm.sacrifice(serpent, on: .you)
            check("destroy() fires the victim's Death trigger", vm.foe.hand.count == before + 1)
        }

        // ─────────────────────────────────────────────────────────────
        section("Sacrifice points")
        do {
            let vm = await freshMatch()
            let kraken = card("kraken")
            vm.you.frontier.append(kraken); kraken.zone = .frontier
            let moses = card("h_moses")
            vm.you.basecamp.append(moses); moses.zone = .basecamp
            vm.you.relics.append(card("fish-net"))
            await vm.sacrifice(kraken, on: .you)
            check("Kraken + Moses + Fish Net = (3+1)x2 = 8", vm.you.elements[.sea] == 8,
                  "got \(vm.you.elements[.sea] ?? -1)")
            check("sacrificed Creature is on the Altar", vm.you.altar.contains { $0 === kraken })
        }

        // ─────────────────────────────────────────────────────────────
        section("Events")
        do {
            let dealt = MatchViewModel()      // untouched, to test the real deal
            check("only Event 1 starts revealed",
                  dealt.you.events[0].revealed && !dealt.you.events[1].revealed && !dealt.you.events[2].revealed)
            check("Event 3 is the shared finale",
                  dealt.you.events[2].card.id == "the-tribulation"
                  && dealt.foe.events[2].card.id == "the-tribulation")
            check("Events 1 and 2 differ between players",
                  dealt.you.events[0].card.id != dealt.foe.events[0].card.id)

            let vm = await freshMatch()

            // Stack a known ladder: 3 Sea, then 3 Land, then the shared finale.
            vm.you.events = [EventProgress(CardLibrary.card(id: "the-great-flood")!, revealed: true),
                             EventProgress(CardLibrary.card(id: "walls-of-jericho")!, revealed: false),
                             EventProgress(CardLibrary.card(id: "the-tribulation")!, revealed: false)]
            let crab = card("tide-pool-crab")
            vm.you.frontier.append(crab); crab.zone = .frontier
            vm.you.elements = [.sea: 4, .land: 0, .air: 0]   // 1 surplus after the flood
            vm.you.altar.append(card("sparrow"))
            await vm.sacrifice(crab, on: .you)                     // +1 Sea -> 5 Sea

            check("Event 1 clears", vm.you.events[0].cleared)
            check("surplus carries over", vm.you.elements[.sea] == 2, "got \(vm.you.elements[.sea] ?? -1)")
            check("Altar flushes to discard", vm.you.altar.isEmpty && vm.you.discard.count >= 2)
            check("Event 2 is revealed", vm.you.events[1].revealed)
            check("Event 2 not cleared (no Land)", !vm.you.events[1].cleared)
        }
        do {
            // Cascade: enough banked to clear Events 1 and 2 in one action.
            let vm = await freshMatch()
            vm.you.events = [EventProgress(CardLibrary.card(id: "the-great-flood")!, revealed: true),
                             EventProgress(CardLibrary.card(id: "walls-of-jericho")!, revealed: false),
                             EventProgress(CardLibrary.card(id: "the-tribulation")!, revealed: false)]
            let crab = card("tide-pool-crab")
            vm.you.frontier.append(crab); crab.zone = .frontier
            vm.you.elements = [.sea: 2, .land: 3, .air: 0]
            await vm.sacrifice(crab, on: .you)                     // +1 Sea -> 3 Sea, 3 Land
            check("clears cascade in one action",
                  vm.you.events[0].cleared && vm.you.events[1].cleared)
            check("Event 3 revealed to the clearing player", vm.you.events[2].revealed)
            check("Event 3 revealed to the OTHER player too", vm.foe.events[2].revealed)
            check("the other player still cannot clear it", vm.foe.currentEventIndex == 0)
            check("no premature win", vm.winner == nil)
        }
        do {
            // Full ladder to a win.
            let vm = await freshMatch()
            vm.you.events = [EventProgress(CardLibrary.card(id: "the-great-flood")!, revealed: true),
                             EventProgress(CardLibrary.card(id: "walls-of-jericho")!, revealed: false),
                             EventProgress(CardLibrary.card(id: "the-tribulation")!, revealed: false)]
            let crab = card("tide-pool-crab")
            vm.you.frontier.append(crab); crab.zone = .frontier
            vm.you.basecamp.append(card("craftsman"))
            vm.you.elements = [.sea: 4, .land: 5, .air: 2]
            await vm.sacrifice(crab, on: .you)
            check("clearing all three wins the match", vm.winner == .you, "winner=\(String(describing: vm.winner))")
        }

        // ─────────────────────────────────────────────────────────────
        section("Deck rules")
        do {
            var sawRelic = false, shortOnOnes = false
            for _ in 0..<200 {
                let deck = MatchViewModel.buildDeck()
                if deck.contains(where: { $0.type == .relic }) { sawRelic = true }
                if deck.filter({ $0.cost == 1 }).count < 2 { shortOnOnes = true }
            }
            check("deck is 28 cards", MatchViewModel.buildDeck().count == 28)
            // Relics are set aside face-down at game start, never shuffled in.
            check("decks contain no Relics", !sawRelic)
            // The preparing phase seeds the Basecamp from the deck's cost-1
            // cards, and only 6 of 69 bodies qualify — an unconstrained deck
            // comes up short about 1 game in 5.
            check("every deck holds at least 2 cost-1 cards", !shortOnOnes)
            check("a player is set aside exactly 2 Relics", MatchViewModel.buildRelics().count == 2)
        }

        // ─────────────────────────────────────────────────────────────
        section("March triggers")
        do {
            let vm = await freshMatch()
            let herald = card("herald", turn: 0), second = card("soldier", turn: 0)
            let anchor = card("craftsman", turn: 0)
            vm.you.basecamp.append(contentsOf: [anchor, herald, second])
            for c in vm.you.basecamp { c.zone = .basecamp }
            vm.you.deck = [CardLibrary.card(id: "sparrow")!, CardLibrary.card(id: "sparrow")!]
            var h = vm.you.hand.count
            await vm.march(herald, on: .you)
            check("Herald draws on the first Human March", vm.you.hand.count == h + 1)
            h = vm.you.hand.count
            await vm.march(second, on: .you)
            check("Herald does not draw for the second", vm.you.hand.count == h)
        }
        do {
            let vm = await freshMatch()
            let fisherman = card("fisherman", turn: 0), anchor = card("craftsman", turn: 0)
            let crab = card("tide-pool-crab")                 // a Sea Creature in play
            vm.you.basecamp.append(contentsOf: [anchor, fisherman, crab])
            for c in vm.you.basecamp { c.zone = .basecamp }
            await vm.march(fisherman, on: .you)
            check("Fisherman gains +1/+1 with a Sea Creature", fisherman.attack == 4 && fisherman.maxHealth == 4)
            await vm.endTurn()
            check("the buff expires at end of turn", fisherman.attack == 3 && fisherman.maxHealth == 3)
        }
        do {
            let vm = await freshMatch()
            let chief = card("warrior-chief", turn: 0), anchor = card("craftsman", turn: 0)
            vm.you.basecamp.append(contentsOf: [anchor, chief])
            for c in vm.you.basecamp { c.zone = .basecamp }
            let wall = card("leviathan"); vm.foe.frontier.append(wall); wall.zone = .frontier
            await vm.march(chief, on: .you)
            await vm.attack(chief, target: wall, on: .you)
            check("Warrior Chief's first attack is doubled", wall.damage == 12, "got \(wall.damage)")
        }
        do {
            let vm = await freshMatch()
            let eagle = card("eagle", turn: 0), anchor = card("craftsman", turn: 0)
            vm.you.basecamp.append(contentsOf: [anchor, eagle])
            for c in vm.you.basecamp { c.zone = .basecamp }
            let blocker = card("leviathan"); vm.foe.frontier.append(blocker); blocker.zone = .frontier
            let g = card("h_goliath"); vm.foe.basecamp.append(g); g.zone = .basecamp
            await vm.march(eagle, on: .you)
            check("Eagle is marked unblockable", eagle.unblockable)
            await vm.attack(eagle, target: nil, on: .you)
            check("Eagle Raids past an occupied Frontier", g.damage == 3, "got \(g.damage)")
        }

        // ─────────────────────────────────────────────────────────────
        section("Guard reactions")
        do {
            let vm = await freshMatch()
            let farmer = card("farmer"), priest = card("priest")
            vm.you.basecamp.append(contentsOf: [farmer, priest])
            for c in vm.you.basecamp { c.zone = .basecamp }
            priest.damage = 4
            let crab = card("tide-pool-crab"); vm.you.frontier.append(crab); crab.zone = .frontier
            await vm.sacrifice(crab, on: .you)
            check("Farmer gains +1/+0 per Sacrifice", farmer.attack == 2, "got \(farmer.attack)")
            check("Priest heals to full on Sacrifice", priest.damage == 0)
        }
        do {
            let vm = await freshMatch()
            let hp = card("high-priest")
            vm.you.basecamp.append(hp); hp.zone = .basecamp
            let dove = card("dove"); vm.you.frontier.append(dove); dove.zone = .frontier
            await vm.sacrifice(dove, on: .you)
            check("High Priest gains Shield when a Sacrifice targets it", hp.shield)
        }
        do {
            let vm = await freshMatch()
            let owl = card("owl"), h1 = card("soldier", turn: 0), h2 = card("centurion", turn: 0)
            vm.you.basecamp.append(contentsOf: [owl, h1, h2])
            for c in vm.you.basecamp { c.zone = .basecamp }
            await vm.march(h1, on: .you)
            check("Owl shields the first Human to March", h1.shield)
            await vm.march(h2, on: .you)
            check("Owl does not shield the second", !h2.shield)
        }
        do {
            let vm = await freshMatch()
            let prophet = card("prophet")
            vm.you.basecamp.append(prophet); prophet.zone = .basecamp
            vm.you.events = [EventProgress(CardLibrary.card(id: "the-great-flood")!, revealed: true),
                             EventProgress(CardLibrary.card(id: "the-tribulation")!, revealed: false),
                             EventProgress(CardLibrary.card(id: "the-tribulation")!, revealed: false)]
            vm.you.elements = [.sea: 2, .land: 0, .air: 0]
            vm.you.deck = [CardLibrary.card(id: "sparrow")!]
            let crab = card("tide-pool-crab"); vm.you.frontier.append(crab); crab.zone = .frontier
            let before = vm.you.hand.count
            await vm.sacrifice(crab, on: .you)
            check("Prophet draws when you overcome an Event", vm.you.hand.count == before + 1)
        }

        // ─────────────────────────────────────────────────────────────
        section("Death & removal detail")
        do {
            let vm = await freshMatch()
            let jackal = card("golden-jackal"), killer = card("leviathan")
            vm.you.frontier.append(jackal); jackal.zone = .frontier; jackal.canAct = true
            vm.foe.frontier.append(killer); killer.zone = .frontier
            await vm.attack(jackal, target: killer, on: .you)
            check("Golden Jackal dies to the Creature", vm.you.frontier.isEmpty)
            check("Golden Jackal bites its killer back", killer.damage == 4, "got \(killer.damage)")
        }
        do {
            let vm = await freshMatch()
            let samson = card("h_samson")
            vm.you.frontier.append(samson); samson.zone = .frontier
            let beast = card("leviathan"), human = card("h_goliath")
            vm.foe.frontier.append(contentsOf: [beast, human])
            for c in vm.foe.frontier { c.zone = .frontier }
            samson.damage = 99
            await poke(vm, .you)
            check("Samson hits Frontier Creatures", beast.damage == 3, "got \(beast.damage)")
            check("Samson spares Humans", human.damage == 0, "got \(human.damage)")
        }
        do {
            let vm = await freshMatch()
            fillPool(vm.you, 10)
            let jael = card("h_jael")
            vm.you.hand.append(jael)
            let healthy = card("behemoth-calf"), hurt = card("leviathan")
            hurt.damage = 1
            vm.foe.frontier.append(contentsOf: [healthy, hurt])
            for c in vm.foe.frontier { c.zone = .frontier }
            await vm.play(jael, on: .you)
            check("Jael destroys only a damaged Creature",
                  vm.foe.frontier.contains { $0 === healthy } && !vm.foe.frontier.contains { $0 === hurt })
        }

        // ─────────────────────────────────────────────────────────────
        section("Relics")
        do {
            let vm = await freshMatch()
            fillPool(vm.you, 10)
            vm.you.relics.append(contentsOf: [card("watchtower"), card("fish-net")])
            let third = card("altar-of-fire")
            vm.you.hand.append(third)
            check("cannot play a third Relic", !vm.canPlay(third, on: .you))
        }
        do {
            let vm = await freshMatch()
            fillPool(vm.you, 10)
            vm.you.relics.append(card("scroll-of-wisdom"))
            vm.you.deck = Array(repeating: CardLibrary.card(id: "sparrow")!, count: 5)
            // Watchman is Wisdom and vanilla, so the only draw can be the Scroll's.
            let watchman = card("watchman")
            vm.you.hand.append(watchman)
            let before = vm.you.hand.count
            await vm.play(watchman, on: .you)
            check("Scroll of Wisdom draws for a Wisdom Human",
                  vm.you.hand.count == before, "played -1, drew +1; got \(vm.you.hand.count) vs \(before)")

            // Control: a Courage Human gets nothing from the Scroll.
            let vmC = await freshMatch()
            fillPool(vmC.you, 10)
            vmC.you.relics.append(card("scroll-of-wisdom"))
            vmC.you.deck = Array(repeating: CardLibrary.card(id: "sparrow")!, count: 5)
            let esther = card("h_esther")         // Courage, vanilla besides Shield
            vmC.you.hand.append(esther)
            let beforeC = vmC.you.hand.count
            await vmC.play(esther, on: .you)
            check("Scroll of Wisdom ignores non-Wisdom Humans", vmC.you.hand.count == beforeC - 1)
        }
        do {
            let vm = await freshMatch()
            fillPool(vm.you, 10)
            vm.you.relics.append(card("banner-of-courage"))
            vm.you.basecamp.append(card("craftsman"))          // anchor so the wall allows a March
            vm.you.basecamp[0].zone = .basecamp
            let soldierless = card("h_esther")                 // Courage, no printed Charge
            vm.you.hand.append(soldierless)
            await vm.play(soldierless, on: .you)
            check("Banner of Courage grants Charge", vm.canMarch(soldierless, on: .you))
            // Derived from the card, not hardcoded — this asserts that Banner adds 1,
            // so rebalancing Esther can never break it. See the note in PROJECT_STATUS.
            let printedAttack = CardLibrary.card(id: "h_esther")!.attack
            check("Banner of Courage grants +1/+0", soldierless.attack == printedAttack + 1,
                  "got \(soldierless.attack), expected \(printedAttack + 1)")
        }

        // ─────────────────────────────────────────────────────────────
        section("Sacrifice odds and ends")
        do {
            let vm = await freshMatch()
            let sparrow = card("sparrow")
            vm.you.frontier.append(sparrow); sparrow.zone = .frontier
            vm.you.deck = [CardLibrary.card(id: "lion")!]
            let before = vm.you.hand.count
            await vm.sacrifice(sparrow, on: .you)
            check("Sparrow draws on Sacrifice", vm.you.hand.count == before + 1)
        }
        do {
            let vm = await freshMatch()
            let otter = card("river-otter")
            vm.you.frontier.append(otter); otter.zone = .frontier
            let deadHuman = card("craftsman")
            vm.you.discard.append(deadHuman)
            await vm.sacrifice(otter, on: .you)
            check("River Otter returns a Human from discard", vm.you.hand.contains { $0 === deadHuman })
        }

        print("\n\(passed) passed, \(failed) failed")
        exit(failed == 0 ? 0 : 1)
    }
}
