# Project Status

**Last updated:** 2026-07-26

Bible TCG — a 2-player hot-seat trading card game. Race to the Promised Land by
overcoming 3 Events. iOS 17+, SwiftUI, generated with xcodegen.

`Resources/bible-tcg-rules.md` is the **canonical vocabulary and rules**. Card
text uses only terms defined there. Read it before changing any card.

---

## Build, run, test

```bash
xcodegen generate                     # after adding/removing source files
open BibleTCG.xcodeproj               # then ⌘R
./Tests/run-probe.sh                  # 77 headless engine checks
```

`Tests/` is deliberately **not** in `project.yml` sources, so it never ships in
the app. `run-probe.sh` compiles the models, card library and engine for macOS
alongside `Tests/EngineProbe.swift` and asserts every rule directly — far more
reliable than hunting for a card in a randomly-shuffled match.

---

## What changed this session

The session began as "wire up the unimplemented card abilities". Reading the
files first surfaced that ~10 terms used in card text were never defined, several
were used inconsistently, and two cards referenced a **blocking** mechanic that
was never written. So the work ran in three phases.

### Phase 1 — Terminology canon

Rules rewritten in `Resources/bible-tcg-rules.md` and mirrored into
`Resources/cards.json`:

- **Guard became a static keyword**, not a trigger: "active only while this card
  is in your Basecamp." Triggers dropped to five (Play, March, Raid, Sacrifice, Death).
- **Blocking deleted.** Eagle and Champion rewritten.
- **attack / defend** replace "fight". **Creature** is always capitalized and
  always means the card type.
- **damaged** = below max Health. **lowest Health** = how "weakest" is measured.
  **overnight** = in play throughout the opponent's entire turn.
- Element points are written **`+N <Element> points`** only, with a documented
  stacking order (base → flat → multiplier).
- Effects are **unscoped** — no "Your"; an unnamed side means your own cards.
- **Sacrifice baseline written down for the first time:** a Sacrificed Creature
  gives +1 point of its Element.

Card text rewritten accordingly across ~30 cards. Code renames: `.animal` →
`.creature`, `.item` → `.relic`, `Category` → `Discipline`,
`TCGCardType.isCreature` → `hasStats` (it meant Human‖Creature, which now reads
as a contradiction). `CardInstance.isCreature` kept its name and finally means
what it says.

### Phase 2 — Mechanics corrections

- **Mana is now berries.** The engine used to auto-ramp (`maxMana + 1`, free,
  every turn). It now matches the design: you start at **0**, and once per turn
  you may **eat** a card from hand for a permanent berry, usable the same turn.
  Mana refills to your berry count each turn; cap 10, after which eating stops.
  `cards.json` had specified this all along (`discardForManaPerTurn`) — the
  engine had simply never implemented it.
- **Altar is a real zone.** Sacrificed Creatures go there, not straight to the
  discard. Clearing an Event flushes it.
- **Events unlock one at a time.** Only Event 1 starts face-up; clearing it
  reveals Event 2. Event 3 is shared — whoever unlocks it reveals it to *both*
  players, but a player who hasn't cleared their own 1 and 2 can see it without
  being able to clear it. Clearing subtracts exactly the requirement (surplus
  carries) and **cascades** if the banked points reach further.
- **Relics:** 2 per deck (was 4), 2 board slots enforced, permanent once played.
- **Shield refreshes** at the start of its controller's turn. Granted Shields
  carry an expiry and lapse in turn-end cleanup.
- **One death path.** Serpent and Jael used to bypass Death triggers by removing
  cards directly; everything now routes through `destroy()`.
- Fixed the log-name bug — both players' Event clears used to read "You
  overcame…" because both boards were constructed with `isAI: false`.
  `PlayerBoard` now carries its `side`.

### Phase 3 — Abilities wired

- **Layered stats** on `CardInstance`. Printed values live on the card; on top
  sit `bonus*` (permanent), `temp*` (end of turn), `aura*` (recomputed every
  settle). `damage` replaced the stored `health` field, so `health` is derived.
  Continuous Guard effects can now be rebuilt from scratch without leaking when
  their source leaves play. **Views needed no changes** — the property names
  `attack` / `health` / `maxHealth` survived as computed properties.
- **`settle()`** recomputes auras, resolves deaths, and repeats until stable.
  The loop matters: losing an aura can drop max Health to at or below damage,
  killing a card, which can remove another aura source.
- **`effectiveCost()`** used by both `canPlay` and `play`, covering Whale, Camel
  and Ark of the Covenant. Discounted costs render green in hand.
- **`endOfTurnCleanup()`** expires temp buffs, granted Shields, double-damage
  charges and Eagle's unblockable flag.
- Every ability that fires now writes a line to the match log.

---

## Module state

| Module | State |
|---|---|
| `Models/TCGCard.swift` | Stable. Card data + `Discipline` / `Element` / `TCGCardType`. |
| `Models/MatchModels.swift` | Rewritten. Layered stats, Altar zone, berries, per-turn counters, Event unlock helpers. |
| `Services/CardLibrary.swift` | 87 cards (25 Creatures, 44 Humans, 8 Relics, 10 Events). All text follows the canon. |
| `ViewModels/MatchViewModel.swift` | Rewritten. Full turn loop, berries, auras, all triggers. |
| `Views/TCGMatchView.swift` | Play/Eat action bar on hand cards, Altar counter, 3-badge event column, berry readout. |
| `Views/TCGCardView.swift` | Unchanged behaviour; rename fallout only. |
| `Views/CardCollectionView.swift` | Unchanged behaviour; rename fallout only. |
| `Resources/` | Rules + cards.json are canon. **Not bundled** — design docs only, not loaded at runtime. |
| `Tests/` | New. 77 headless engine checks. |
| `import-art.py` | Now knows all 87 ids (the 3 discipline Relics were missing). |

---

## Ability coverage

**Every card with printed ability text now resolves.** Full coverage by trigger:

| Trigger | Wired |
|---|---|
| **Play** | Shepherd Boy, Raven, Donkey, Joseph, Isaiah, John the Baptist, The Magi, Solomon, Young Scribe, Paul, Matthew, Eve, Elijah, Jael |
| **March** | Herald, Fisherman, Peter, Warrior Chief, Eagle |
| **Raid** | Judge, Champion, Joshua, Watchtower *(defender)* |
| **Sacrifice** | Sparrow, Locust, Great Fish, Serpent, Golden Jackal, Great Bear, Raven, Dove, Lamb, River Otter + point values (Minnow Shoal, Kraken, Ant) |
| **Death** | Griffin Vulture, Golden Jackal, Physician, Samson |
| **Guard — auras** | Lion, Nehemiah, Elder, Abraham, Deborah |
| **Guard — cost** | Whale, Camel |
| **Guard — reactive** | Farmer, Priest, High Priest, Prophet, Owl, Moses |
| **Relics** | All 8 |

### Simplified pending a choice UI

These resolve, but not exactly as printed — each needs player input the game has
no interface for yet:

| Card(s) | Printed | Actual |
|---|---|---|
| Shepherd Boy, Raven, Isaiah | "Look at the top card of your deck" | plain draw |
| Solomon | "Look at the top 2; draw one" | plain draw |
| Young Scribe, Paul, Matthew | "Draw a card, then discard a card" | draws, never discards |
| Great Fish | "4 damage **split among any number**" | all 4 to one target |

---

## Open TODOs

**Player-chosen targeting.** Every "target"/"chosen" ability auto-picks
(`strongestFrontierCreature`, `weakestFrontierCreature`, first matching Human,
or random). A targeting state machine in `TCGMatchView` would fix this *and* the
four simplified abilities above. This is the single largest remaining gap.

**Balance is untested after this session.** Two changes moved the numbers a lot
and neither has playtest data behind it:
- Creature-only targeting means **Humans in the Frontier can only be removed by
  combat**. Samson and Golden Jackal are notably weaker than they read.
- Berry mana makes ramp cost cards. Games start much slower — turn 1 is now
  always "eat, pass".

**Stat formula drift.** All 40 original starter cards satisfy `Human ATK+HP =
2×cost` / `Creature = 2×cost − 1`. **20 of the 24 restored named Humans do not**
(Moses −3, Solomon −2, Gideon/Caleb +2, most others ±1), plus Leviathan +2 and
Lamb +1. Unclear whether that's a deliberate premium for named characters or
drift. Untouched deliberately — it wants fresh playtest data.

Also unresolved: the formula's "(equal at cost 1)" clause is ambiguous — it
either means cost-1 Creatures match the Human total (2) or literally 1. Which
reading applies changes whether 2 or 5 cards are off-formula.

**`cards.json` covers only the starter 50**, while `CardLibrary.swift` has 87.
Kept deliberately (hand-synced, per decision) but the two will drift again. The
three cards whose text used to disagree three ways — Golden Jackal, Great Bear,
Raven — were resolved **in favour of the Swift version**, since that's what runs.

**Smaller items:**
- `frontierOverflow` (discard or Sacrifice to make room at the 5-card cap) is
  specified in `cards.json` but not implemented; `canMarch` just blocks.
- Long ability text clips on the card frame — Great Fish overruns its 4-line
  limit into the attack pip. Layout constraint in `TCGCardView.framedFace`.
- The playmat art has **5** printed Event slots; the sequential-Event change
  means only **3** badges are rendered (foe's current, shared Event 3, yours).
  The mat art should eventually be redrawn to match.
- Opening hand size (3, plus the turn-1 draw) is not specified anywhere.
- No deck builder — decks are 28 random distinct bodies + 2 random Relics.
- No AI opponent (removed earlier in favour of hot-seat).
- Cards have no flavour text or scripture references.
- **The project is not under version control.** `git init` would be worth doing
  before the next round of changes.
- 21 of 87 cards have art. Drop files into `Art/Cards/` and run
  `python3 import-art.py` — it reports what's still missing.
