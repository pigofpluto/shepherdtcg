# Project Status

**Last updated:** 2026-08-05

Bible TCG — a 2-player hot-seat trading card game. Race to the Promised Land by
overcoming 3 Events. iOS 17+, SwiftUI, generated with xcodegen.

`Resources/bible-tcg-rules.md` is the **canonical vocabulary and rules**. Card
text uses only terms defined there. Read it before changing any card.

---

## Build, run, test

```bash
xcodegen generate                     # after adding/removing source files
open BibleTCG.xcodeproj               # then ⌘R
./Tests/run-probe.sh                  # 94 headless engine checks
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

- **Mana stopped auto-ramping.** The engine used to hand out `maxMana + 1` free
  every turn. It now costs you a card. *(That first landed as "berries"; it is
  now the Mana Pool — see below.)*
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
| `Models/MatchModels.swift` | Layered stats, Altar and Mana Pool zones, per-turn counters, Event unlock helpers. |
| `Services/CardLibrary.swift` | 87 cards (25 Creatures, 44 Humans, 8 Relics, 10 Events). All text follows the canon. |
| `ViewModels/MatchViewModel.swift` | Full turn loop, Mana Pool, auras, all triggers, async beats. |
| `Views/TCGMatchView.swift` | Rewritten for Playmat V4. Positions come from `MatLayout`; every card carries `matchedGeometryEffect`. |
| `Views/MatLayout.swift` | New. The single table of board positions, in mat fractions. |
| `Views/MiniCard.swift` | New. Extracted from `TCGMatchView`; animates its own stat changes. |
| `Views/BoardStacks.swift` | New. Deck / Discard / Altar piles. |
| `Views/CueOverlay.swift` | New. Floating damage, heal, points, shield-break. |
| `Views/DebugSandbox.swift` | New, `#if DEBUG`. Stacked board for checking animation by eye. |
| `Views/TCGCardView.swift` | Unchanged behaviour; rename fallout only. |
| `Views/CardCollectionView.swift` | Unchanged behaviour; rename fallout only. |
| `Resources/` | Rules + cards.json are canon. **Not bundled** — design docs only, not loaded at runtime. |
| `Tests/` | 94 headless engine checks, `async`. |
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
- Mana Pool ramp costs cards. Games start much slower — turn 1 is now
  always "convert, pass".

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
- Opening hand size (3, plus the turn-1 draw) is not specified anywhere.
- No deck builder — decks are 28 random distinct bodies + 2 random Relics.
- No AI opponent (removed earlier in favour of hot-seat).
- Cards have no flavour text or scripture references.
- 21 of 87 cards have art. Drop files into `Art/Cards/` and run
  `python3 import-art.py` — it reports what's still missing.

---

## Mana — the Mana Pool

Berries are gone. Cards are **converted** into a **Mana Pool**, one per turn,
usable the same turn, capped at 10 cards. Drag a card from hand onto the blue
pool panel; it flies there and dissolves.

The engine was the last thing still using berries — `bible-tcg-rules.md` and
`cards.json` already described this system in full, so this change made the code
match the canon rather than inventing anything.

**The Pool is a separate zone from the discard**, and that is the point of it. A
converted card is spent permanently and cannot be recovered, so River Otter
(`Sacrifice: Return a Human from your discard to your hand`) can no longer fish
it back. `PlayerBoard.manaPool` holds the cards and `maxMana` is derived from its
count — there is no separate counter to drift.

The probe pins both halves: a converted card is in the Pool *and* not in the
discard, plus a dedicated River Otter regression check.

Still unbuilt from `docs/superpowers/specs/2026-07-28-mana-pool-and-retargeting-design.md`:
draw-2 and the "Frontier card" targeting rework. The preparing phase and
Event-unlocked Relics are built — see below — but diverge from the spec's
written version; the rules doc and `cards.json` were updated to match what
actually shipped, not the other way round.

---

## The preparing phase and Event-unlocked Relics

Matches used to start cold — empty Basecamps, Player 1 always first. Now:

1. **Coin flip, first.**
2. **Both Basecamps seed themselves, off the untouched deck.** Two of each
   deck's cost-1 cards are picked **at random**, flipped face-down into the
   Basecamp, then turned face-up. Slot 0 (the Guardian) is whichever of the two
   randomly lands there. This step runs *before* any card is dealt — see the bug
   note below for why that order is load-bearing, not incidental.
3. **Hands are dealt.** The player going first gets **3** cards, the other
   **4**. Going first is a real edge with a Pool that ramps every turn, and the
   extra card is what offsets it — the written spec flagged this as unaddressed
   and this is the fix.
4. **The Pool starts empty.** 0 mana on turn 1. The written spec has 1 starting
   mana from a prep conversion step that was deliberately cut — see Notes below.

**Relics no longer come from the deck or hand.** Each player's 2 are set aside at
game start and placed **face-down** in the Relic slots — inert, invisible in
effect, on the board from turn 1. Clearing an Event flips one: the player is
shown both (still-hidden) Relics face-up and picks which unlocks, since decks are
random and this is the only time they'd otherwise know what they're holding.

**The one-line guard that makes this safe:** `PlayerBoard.hasRelic` — the single
chokepoint all ten Relic effects call through — now requires `!faceDown`.
Without it, seating two Relics on the board at game start would make every
Relic effect live before anyone unlocked anything. Probe checks this directly:
a face-down Relic must be inert, and flipping it must switch it on.

**The cascade case:** clearing two Events in one action (banked points reach
past the first Event into the one it just revealed) must unlock **two** Relics,
not one. Handled inside the same loop that already cascades Event clears; pinned
by a probe check that stacks a cascade and confirms both Relics unlock.

**The choice UI is new territory for this project** — the first player-choice
overlay ever built here. Mechanically it's an `async` engine method suspended on
a `withCheckedContinuation`, resumed when the view calls back with a pick.
That's the shape player-chosen *targeting* — the single largest remaining
TODO — would need too.

Card counts are conserved: `deck.count + basecamp.count + hand.count == 28` for
each side, checked directly.

### Notes and open items

- **A real ordering bug turned up during verification, not design.** The first
  version dealt hands *before* seeding the Basecamp. `buildDeck()` only
  guarantees the *deck* holds ≥2 cost-1 cards — it says nothing about where
  they land — so dealing first could draw one into a hand and leave the seed
  short. It surfaced as a genuine flake in the probe, roughly 1 run in 6–8, not
  as a deterministic failure — easy to miss with casual testing. Fixed by
  moving the seed step to run immediately after the coin flip, before any card
  leaves the deck. Repeated the probe **8 times in a row, 0 failures**, after
  the fix — a single clean pass isn't enough evidence for something
  probabilistic; a spread of reruns is.
- **The Guardian is now random**, not chosen — it's whichever of the two seeded
  cards lands in slot 0. Slot 0 takes Raid damage and Lion's/Nehemiah's auras,
  so this isn't inert, but it follows from seeding being random at all.
- **Six cards are now near-auto-includes.** Only 6 of 69 bodies cost 1
  (Sparrow, Tide Pool Crab, Ant, Lamb, Shepherd Boy, Field Hand), and every deck
  is now forced to hold at least 2 of them — `MatchViewModel.buildDeck` splits
  the pool and guarantees it, because an unconstrained 28-card draw comes up
  short about 1 game in 5. Fixable with more cost-1 card designs; not engine work.
- **Relics are unpriced.** They cost no mana and arrive on a fixed schedule, so
  Watchtower (was 2) and Shepherd's Staff (was 7) are equal. Fish Net's point
  doubling is flagged in the spec as the worst offender, landing free exactly
  when it matters most. A balance pass is owed and not part of this change.
- **The written spec's "start with 1 mana" was cut.** It comes from a "convert 1
  card during preparing" step the spec describes; that step was deliberately
  left out, so `bible-tcg-rules.md` and `cards.json` now document a 0-mana start
  instead of the spec's 1. If that conversion step gets built later, both files
  need the same correction again.

---

## Interaction — drag to act, tap to look

There is no action menu any more. A card is carried to where it should end up,
and every action has a printed destination on the mat:

| Action | Drag from | Drop on |
|---|---|---|
| Play | hand | your Camp (Relics → your Relic slots) |
| Convert to mana | hand | your Mana Pool |
| March | your Camp | your Frontier |
| Sacrifice | Camp / Frontier Creature | your Altar stone |
| Attack | your Frontier | an enemy Frontier card |
| Raid | your Frontier | the enemy Guardian |

Releasing without moving (under 12pt) is a **tap**, which opens the card
enlarged via `CardInspector` — board cards are ~60pt wide, so their ability text
is unreadable in play. It reuses `TCGCardView`, the ornate frame the Collection
screen draws, and shows live attack/health underneath when auras, damage or
Blessings have moved them off the printed values.

The hand fans in an arc (`MatLayout.handSlot`): cards tilt away from the middle,
outer ones ride lower, and picking one up straightens it while its neighbours
slide aside to leave a gap.

`Views/BoardDrag.swift` holds this as plain logic — `DragResolver` reads the
board and says what a drop *would* do, without mutating anything. Legality is
never re-implemented there: it defers to `canPlay` / `canConvert` / `canMarch` /
`canSacrifice` and the same guards inside `attack`, so the rules keep one home.
The same resolver drives the pickup highlight, so what glows and what actually
works cannot disagree.

**Two SwiftUI traps this hit, both worth remembering:**

- `DragGesture` must use a **named coordinate space** shared with the layout.
  With `.local` a drag reports points relative to the card being dragged, so no
  drop target ever matches and every drag silently does nothing.
- The gesture must be attached **before** `.position()`. That modifier expands to
  fill its parent, so a gesture applied after it gives the card a board-sized hit
  area and every card fights every other. `zIndex`, conversely, has to go
  *after* `.position()` — it only affects the ZStack's direct child.

---

## Orientation and the start menu

The app is **landscape-only from launch**, declared in `project.yml`
(`UISupportedInterfaceOrientations` for both iPhone and iPad). Nothing asks iOS
to rotate at runtime any more.

That replaced a real trap. The match view used to call `requestGeometryUpdate`
on appear and show a "turn your phone sideways" hint until it took effect — but
iOS can refuse that request, and when it does the game is simply unreachable. It
was refused *always* on iPad and intermittently on the iPhone simulator. Locking
the plist deletes the failure mode rather than working around it, so
`requestOrientation` and the hint are both gone.

`HomeView` was rebuilt for the wide, short canvas that leaves: **SHEPHERD TCG**
across the top, then **Co-op Play** (the existing hot-seat match — same rules,
just the name the menu uses for it) and **Collection** side by side, with the
card-count stats along the bottom. `HomeButton` became a squarer card since two
now sit next to each other. `CardCollectionView`'s grid went from a fixed two
columns to `.adaptive`, which would otherwise render two enormous cards across an
874pt-wide window.

The app's display name is now **Shepherd TCG**. The bundle identifier stays
`com.bibletcg.app` and the Xcode target stays `BibleTCG` — changing the
identifier would make it a different app to iOS, breaking the installed copy and
any future App Store identity, for no visible gain.

---

## Movement & animation — done

The board no longer snaps. Effects resolve as a visible sequence, and the layout
was retargeted to `playmat v4.jpg` in the same pass (animations need real
destinations, and V3/V4 is the first layout that prints one for every zone).

### 1. The engine pauses — `MatchViewModel`

`play`, `march`, `attack`, `sacrifice`, `convert`, `endTurn`, `confirmHandoff`,
`beginTurn` and `settle` are **`async`**. They stop at each moment worth seeing:

```swift
private func beat(_ ms: UInt64 = 280) async {
    withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) { bump() }
    guard !instant else { return }
    try? await Task.sleep(nanoseconds: ms * 1_000_000)
}
```

The board stays the single source of truth — there is no second copy of game
state to drift. `settle()`'s fixpoint loop became the death-cascade sequencer:
one wave per pass, each with its own beats, so "Locust stings X → X dies → Y
loses Elder's aura → Y dies" plays as separate steps.

Two flags support it:

- **`busy`** — published, set for the duration of an action. Every `can…` guard
  reads it, so input is locked mid-animation and taps can't interleave. Views
  call `Task { await vm.play(…) }`.
- **`instant`** — skips the sleeps. `Tests/EngineProbe.swift` sets it, so the
  77 checks still run in ~0.02s.

`init` can't await, so `setup()` calls `beginTurnState` + `settleInstantly()`
for turn 1. Those are the pause-free halves of `beginTurn` / `settle`.

### 2. Cues — the transient channel

Board state records that a card took 3 damage; it can't record that a red `−3`
should float off it. `VisualCue` (in `MatchModels.swift`) is a published,
self-expiring list tagged by card `UUID`, emitted from the chokepoints that
already existed — `deal()`, `destroy()`, `heal`, `grantShield`, `sacrificeValue`.

Deliberately narrower than promoting `note()` to a structured enum: it does the
animation job, and `note()` still writes the readable log untouched.

### 3. Positions — `MatLayout`

One table of slot rects in mat fractions, measured off the playmat art
(`playmat v4.jpg`, 4096 × 2240, aspect **1.829** — same layout and aspect as the
v3 mock it replaced, so only the Relic slots needed re-measuring, since V4 prints
them slightly staggered rather than level). `MatLayout.Frame` aspect-fits once and
converts fractions to points. Card size derives from the printed slot.

Measure against the **art**, not `shepherd playmat v1.pdf` — the wireframe is
aspect 1.62 and its geometry does not transfer.

Fixed along the way, all previously wrong on the board: the foe's Altar was
never drawn, both discards were summed into one number, only your element
counters showed, and two of the five printed Event slots went unused. The
column now reads foe 1·2 / shared 3 / your 2·1.

### 4. Views

`matchedGeometryEffect` on a namespace shared by every zone, keyed on the
`CardInstance.id` that `ForEach` already used. Deck, Discard and Altar became
real card stacks (`BoardStacks.swift`) — they were bare text counters, so
draw, death and Sacrifice animations had nowhere to fly. `MiniCard` animates its
own attack/health/shield. The END rock on the mat is the end-turn button.

Chrome lives in the letterbox margin; the match log rides the printed "Frontier"
divider, the one band that never holds a card, and steps aside for the action bar.

### Checking it by eye

Reaching combat in a real match takes seven turns of ramping the Pool. Instead:

```bash
xcrun simctl launch --terminate-running-process booted com.bibletcg.app --sandbox
```

`DebugSandbox` stacks both boards, gives 8 mana, and leaves an Event one
Sacrifice from clearing. `#if DEBUG` and opt-in — a normal launch is unaffected.

### Verified

Probe 94/94. In the simulator: convert, play, attack-and-kill, Sacrifice → Altar,
Event clear → Altar sweep → badge stamp → next Event revealed, and Elder's aura
applying to a Frontier Human. The aura *cascade* is covered by the probe
("aura retracts and kills the dependent card") rather than watched.

### Known gaps

- **No skip button**, by choice. If chains start to drag, it's one flag on `beat()`.
- On iPad, iPadOS 26's resizable windows mean a landscape-only declaration isn't
  the hard guarantee it is on iPhone — a tall window is still possible. Nothing
  breaks: `MatLayout` aspect-fits, so the board just letterboxes smaller.
- Opening hand appears rather than being dealt — `init` can't await.
- Draw animations rely on the card appearing in hand; the Deck stack is drawn
  from a count, since the deck holds `[TCGCard]` and not live instances.
