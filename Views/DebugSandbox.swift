#if DEBUG
import Foundation

/// A stacked board for checking animation and layout by eye.
///
/// Reaching combat in a real match takes seven turns of ramping the Mana Pool, which
/// makes visual iteration on the choreography painfully slow. This drops you
/// straight into a position with cards in every zone, mana to spend, and an
/// Event one Sacrifice away from clearing.
///
/// Opt-in only, and compiled out of release builds entirely:
///
/// ```bash
/// xcrun simctl launch --terminate-running-process \
///   booted com.bibletcg.app --sandbox
/// ```
///
/// It never runs unless that argument (or `TCG_SANDBOX=1`) is present, so a
/// normal launch — including from Xcode — is unaffected.
enum DebugSandbox {

    static var isRequested: Bool {
        CommandLine.arguments.contains("--sandbox")
            || ProcessInfo.processInfo.environment["TCG_SANDBOX"] == "1"
    }

    /// Stack both boards. Called from `MatchViewModel.setup()` before the first
    /// turn begins, so the normal turn-start path still runs over the top.
    @MainActor
    static func apply(you: PlayerBoard, foe: PlayerBoard, turn: Int) {
        func make(_ id: String) -> CardInstance? {
            guard let c = CardLibrary.card(id: id) else { return nil }
            return CardInstance(c, turn: turn)
        }
        func place(_ ids: [String], into zone: MatchZone, on b: PlayerBoard) {
            for id in ids {
                guard let inst = make(id) else { continue }
                inst.zone = zone
                inst.enteredOn = 0          // old enough to March and act
                inst.canAct = true
                switch zone {
                case .basecamp: b.basecamp.append(inst)
                case .frontier: b.frontier.append(inst)
                case .hand:     b.hand.append(inst)
                default:        break
                }
            }
        }

        for b in [you, foe] {
            b.hand.removeAll(); b.basecamp.removeAll(); b.frontier.removeAll()
            b.altar.removeAll(); b.discard.removeAll()
            b.everDeployed = true
        }

        // You: a Guardian, an Elder whose aura props up the Frontier Humans,
        // and Creatures to Sacrifice. Removing the Elder is the cascade test.
        place(["craftsman", "elder", "lion"], into: .basecamp, on: you)
        place(["soldier", "wild-boar", "sparrow"], into: .frontier, on: you)
        place(["locust", "great-fish", "kraken", "camel"], into: .hand, on: you)

        // Them: something to hit, and something that hits back.
        place(["h_goliath", "watchman"], into: .basecamp, on: foe)
        place(["watchman", "griffin-vulture"], into: .frontier, on: foe)
        place(["soldier", "raven"], into: .hand, on: foe)

        // Mana comes from the size of the Pool, so it has to be stocked with
        // real cards rather than set as a number.
        for b in [you, foe] {
            for _ in 0..<8 {
                guard let filler = make("watchman") else { continue }
                filler.zone = .manaPool
                b.manaPool.append(filler)
            }
            b.mana = b.maxMana
        }

        // One Sacrifice short of clearing Event 1, so the Altar sweep and the
        // badge stamp can be watched without grinding points.
        if let need = you.events.first?.card.requirement.first {
            you.elements[need.element] = max(0, need.count - 1)
        }
    }
}
#endif
