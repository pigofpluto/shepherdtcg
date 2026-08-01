# Mana Pool, Preparing Phase, Relics & Targeting — engine spec

**Date:** 2026-07-28, revised 2026-08-01
**Status:** design agreed, not implemented
**For:** the engine/view session — none of this is implemented in the rules pass
that produced it.

The rules pass edited only `Resources/bible-tcg-rules.md`, `Resources/cards.json`
and `Services/CardLibrary.swift`. Everything below needs `MatchViewModel.swift`,
`MatchModels.swift` or `Views/`, which that session deliberately did not touch.

Six systems, in rough dependency order:

| § | System | Replaces |
|---|---|---|
| 1 | Mana Pool | berries |
| 2 / 2a | Preparing phase + deck construction | opening hand of 3 |
| 3 | Draw 2 per turn | draw 1 |
| 4 / 4a / 4b | Targeting, Event-unlocked Relics, element values | Creature-only targeting; Relics played from hand; flat +1 points |
| 5 | Samson scope check | — |

---

## 1. Mana Pool replaces berries

**Berries are removed entirely.** The auto-ramp they replaced is not coming back.

| Berry rule (now dead) | Mana Pool rule |
|---|---|
| Start at 0 berries | Start at **1** card in the Pool (from the preparing phase) |
| "Eat" a card → discard, +1 berry | "Convert" a card → **Mana Pool zone**, +1 mana |
| Eaten cards land in the discard | Converted cards land in the Pool and **never leave** |
| Mana refills to berry count | Mana refills to **Pool size** |
| Cap 10 berries | Cap **10 cards** in the Pool |
| Once per turn, optional | Once per turn, optional — unchanged |

### Why the zone matters

Under berries, an eaten card went to the discard, so River Otter
(`Sacrifice: Return a Human from your discard to your hand`) could recover it. The
Pool is a **separate zone from the discard**, so it can't. Any code that treats
"cards I've spent" as one bucket needs to distinguish them.

A card in the Pool is inert: its text does nothing, its stats do nothing, only its
existence counts toward mana. It should not appear in any query for cards in play,
in the discard, or in the Altar.

### Model changes

- `PlayerBoard` gains a `manaPool: [CardInstance]` (or `[TCGCard]` if instance
  identity isn't needed — but instances animate better; see below).
- `maxMana` becomes derived from `manaPool.count`, capped at 10.
- Remove `berries` and whatever `eat()` did with the discard.

### View changes

The playmat has a **blue pool rectangle beside each player's hand** — this is the
Mana Pool's printed slot.

- Add its rect to `Views/MatLayout.swift`, in mat fractions like every other slot,
  measured off the playmat art (not the V1 wireframe PDF).
- The Pool is a **drag target**: dragging a card from hand onto it converts that
  card. This is the primary interaction, replacing whatever button `eat()` had.
- The Pool should read as a card stack, like Deck / Discard / Altar in
  `Views/BoardStacks.swift`, so conversion has a destination to animate toward.
  Holding `CardInstance`s rather than counts is what makes
  `matchedGeometryEffect` work here, same reasoning as the existing stacks.
- Enforce the once-per-turn limit and the 10-card cap in the drag's accept check,
  not only in the model, so the drop is visibly refused.

---

## 2. Preparing phase

A new state **before turn 1**, run for both players, before the turn loop starts.

1. **Search the deck** for two cards costing 1 and place them in the Basecamp.
2. **Shuffle the deck.**
3. **Draw 5.**
4. **Convert 1** card from hand to the Mana Pool.
5. Keep the rest — opening hand is **4**.

Then **flip a coin** for who takes the first turn.

### Rules the implementation must honour

- **Guardian order.** The order cards are placed sets the Basecamp slots, so the
  first card placed is the Guardian. This falls out of the existing rule in
  `bible-tcg-rules.md` — no new mechanism, but the UI must let the player choose
  the order rather than placing them in deck order.
- **Deck search UI.** Step 1 is a search of the whole deck, not a choice from a
  dealt hand, so it needs a deck-browsing view. The deck-construction rule in §2a
  guarantees at least two cost-1 cards exist, so there is no failure case to handle.
- **Coin flip.** First player is random. Nothing currently compensates the second
  player — see the flag at the end of this section.
- Cost is **printed** cost. No discount source (Whale, Camel, Ark of the Covenant)
  can be in play during preparing, so `effectiveCost()` is moot here.

### Flag: first-player advantage is unaddressed

With draw 2 and a Mana Pool that ramps every turn, going first is a real edge and
nothing offsets it. Worth a rule eventually — an extra card, or letting the second
player convert twice on turn 1 — but it has not been decided, so implement the
plain coin flip and leave it.

## 2a. Deck construction

- A deck is **28 bodies** (Humans and Creatures).
- It must contain **at least 2 cards costing 1**.
- **Relics are no longer dealt into the deck.** Each deck's 2 Relics are set aside
  and start face-down in the Relic slots — see §4a.

This changes the existing generator, which builds 28 random distinct bodies plus 2
random Relics. It must now build 28 bodies subject to the cost-1 constraint, and
place the 2 Relics separately.

**Flag: the cost-1 pool is too small for this constraint.** Only **6 of 69 bodies
cost 1** — Sparrow, Tide Pool Crab, Ant, Lamb, Shepherd Boy, Field Hand. Requiring
two of them in every deck makes all six near-auto-includes. Adding more cost-1
bodies to the set would fix it; that's card design, not engine work.

### Sequencing

`init` can't await, and the existing setup path already works around this with
`beginTurnState` + `settleInstantly()`. The preparing phase needs player input from
both players, so it can't live in `setup()` — it wants to be a real state ahead of
turn 1, with a hot-seat handoff between the two players' preparations.

This is also the natural place to fix the existing gap where the opening hand
*appears* rather than being dealt.

---

## 3. Draw 2 per turn

Replaces draw 1. Draw **2** at the start of each of your turns.

This is what makes the Mana Pool work. Under berries you drew 1 and converted 1, so
your hand was pinned at its opening size for the whole game — by turn 5 you had 5
mana and 3 cards, and ramping past your curve was actively self-harming. Draw 2,
convert 1 is **net +1 card per turn**.

Two knock-ons to check:

- **Hand max is 7.** Drawing 2 hits the cap sooner. Whatever the engine does on
  overdraw today (discard, refuse, burn) is now a live rule rather than a rarity.
  It is not specified in the rules doc — worth specifying.
- **Deck depletion doubles.** 28 cards, minus 2 searched out and 5 drawn during
  preparing, at 2/turn is ~10 turns of draws. There is **no deck-out loss
  condition** in the rules — the only loss is an emptied Basecamp — so running out
  means you simply stop drawing. Confirm the engine doesn't crash or auto-lose on
  an empty deck.

---

## 4. Targeting: "Frontier Creature" → "Frontier card"

The vocabulary rule stands unchanged: **a Human in the Frontier is not a Creature.**
It still governs Sacrifice (only Creatures can be Sacrificed) and condition checks
like Fisherman's and Peter's "if you control a Sea Creature". What changes is only
which cards *name* Creature as a target.

The problem it caused: Creature-only removal barely has legal targets, because the
design wants Creatures Sacrificed for points rather than parked in the Frontier.
Golden Jackal's Death trigger is close to blank text — with 44 Humans against 25
Creatures, most things that kill it are Humans.

**The engine needs a "Frontier card" targeting path alongside the existing
Creature-only one.** These 6 cards move to it:

| Card | Current printed text | Should become |
|---|---|---|
| Golden Jackal | `Death: Deal 1 damage to the Creature that killed it.` | `…to the card that killed it.` |
| Samson | `Death: Deal 3 damage to all enemy Frontier Creatures.` | `…all enemy Frontier cards.` |
| Elijah | `Play: Deal 3 damage to an enemy Frontier Creature.` | `…an enemy Frontier card.` |
| Locust | `Sacrifice: Deal 1 damage to target enemy Frontier Creature.` | `…target enemy Frontier card.` |
| Great Fish | `Sacrifice: Deal 4 damage split among any number of enemy Frontier Creatures.` | `…enemy Frontier cards.` |
| Altar of Fire | `Whenever you Sacrifice a Creature, deal 1 damage to a random enemy Frontier Creature.` | `…a random enemy Frontier card.` |

**Serpent and Jael stay Creature-only** — deliberate. Both are hard removal
(`destroy`, not damage). Serpent destroying any Human with ≤3 Health, or Jael at
cost 3 destroying any damaged Human, would make wide Human boards unholdable.
Damage-based answers become universal; destroy effects stay narrow.

### Do not apply the text yet

**The printed text has deliberately NOT been changed** in `cards.json` or
`CardLibrary.swift`. It still says "Creature". This is so the files never claim
behaviour the engine doesn't deliver.

Apply the text changes in the table above **in the same change** that adds the
targeting path — not before.

---

## 4a. Relics unlocked by Events

Relics are **no longer played from hand and cost no mana**.

- Each deck's 2 Relics are set aside at game start, **face-down in the 2 Relic
  slots**, outside the 28-card deck.
- Clearing **Event 1** flips one Relic face-up — the player chooses which.
- Clearing **Event 2** flips the other.
- Clearing **Event 3** wins the game and grants nothing.
- A face-down Relic is inert: no text, no triggers, not visible to the opponent.
  Once flipped it is permanent and behaves exactly as Relics do today.

### Where this hooks in

The Event-clear path already exists — it subtracts the requirement, banks surplus,
flushes the Altar and reveals the next Event. The flip is one more step there.

**The cascade is the case to get right.** Clears already cascade: enough banked
points can clear Event 1 and the Event 2 it just revealed in a single action. That
must flip **one Relic per Event cleared**, so a double clear flips both, and the
player is asked which to flip first. Getting this wrong either drops a flip or
flips both without a choice.

Removing the play-from-hand path also removes whatever `canPlay`/`play` branch
handled `.relic`, and the 2-relic board-slot enforcement becomes a setup invariant
rather than a runtime check.

### Flag: Relic power is now unpriced

Cost was the only thing balancing the eight Relics against each other, and nothing
pays it now — Watchtower (was 2) and Shepherd's Staff (was 7) cost the same one
Event clear. The expensive ones are straight upgrades.

**Fish Net compounds worst.** "Sacrifices give double points" doubling a printed
element value of 3 is +6 from a single Creature, and it now arrives free after
Event 1 — exactly when doubling matters most for Events 2 and 3.

The printed `cost` field is **retained in the card data** and documented as unused,
pending a decision on whether to repurpose it. Do not strip it.

## 4b. Element values on Creatures

Every Creature gains a printed **element value from 1 to 3**, shown beside its
Element on the card face (`2 Sea`). Sacrificing it gives that many points of its
Element, replacing the flat +1 baseline.

- New field on `TCGCard` in `Models/`, alongside `element`.
- Rendered beside the Element on the card face — `TCGCardView` and `MiniCard`.
- `sacrificeValue` reads it as the **base amount**, step 1 of the existing modifier
  order. Steps 2 and 3 (Moses's flat +1, Fish Net's double) are unchanged.

**The values are not assigned yet** — the user is setting them separately. The
rules describe the mechanic; no Creature card carries a value.

**Minnow Shoal, Kraken and Ant will double-count.** They encode their value in
ability text today — `Sacrifice: +2 Sea points`, `+3 Sea points`, `+2 Land points`.
That text must be **deleted** in the same change that gives them printed values, or
they grant their printed value *and* their text value.

**Weight Sea above Land when assigning values.** Summed across all 10 Events,
demand is Sea 35.1% / Air 27.0% / Land 37.8%, while Creature supply is Sea 24.0% /
Air 28.0% / Land 48.0%. Sea is structurally short and Land long, independently of
this change.

## 5. Verify Samson's scope

Samson's text was corrected in this pass from
`Death: Deal 3 damage to all Frontier Creatures.` to
`Death: Deal 3 damage to all enemy Frontier Creatures.`

As printed before, the scope rule (`an effect that names no side refers to your own
cards`) meant a 7-cost Death trigger damaged **its own side**. Joshua and Eagle had
the same problem with "the Guardian" and were corrected the same way.

**Whether the engine ever matched the old text is unverified.** Confirm
`MatchViewModel`'s Samson handler targets the *enemy* Frontier, and likewise that
Joshua's `+2/+0` applies when attacking the *enemy* Guardian.

---

## Still open — not part of this spec

**The Event economy — element values are the fix, but the numbers need checking.**
A 28-body deck drawn at random from 25 Creatures / 44 Humans holds ~10 Creatures. At
the old flat +1 baseline that was **~11.8 points of supply** against **~12.9 of
demand** (two personal Events averaging 3.4 each, plus The Tribulation's 6), which
made the stated win condition roughly unreachable.

Printed element values of 1–3 close that gap and can overshoot it:

| Average element value | Expected supply | vs 12.9 demand |
|---|---|---|
| 1.0 (old baseline) | 11.8 | short |
| 1.5 | 15.2 | modest surplus |
| 2.0 | 20.3 | 1.6× |
| 2.5 | 25.4 | 2× |

A surplus is correct, not a bug — you can't Sacrifice your last Basecamp card,
Creatures converted to mana are deleted (~3–4 points over a game), you won't draw
your whole deck, and points in the wrong Element are dead. An average near **2.0**
is defensible. What matters more than the range is the **element distribution**;
see §4b.

Re-derive once values are assigned. Remaining levers, all in the rules files rather
than the engine: Event requirements, element values, and card costs.

**Relic levelling.** Removing Relic costs left the eight Relics unpriced against
each other — see §4a. Wants a follow-up balance pass.
