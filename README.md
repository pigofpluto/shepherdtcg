# Bible TCG

A trading card game based on Bible characters and stories. Two players race to the
**Promised Land** by overcoming 3 Events.

This folder contains **only the TCG** — art, card data, rules, and the working game
source — extracted from the older "Claude - Bible game" app (which also contained an
unrelated New Testament trivia game).

## Build & run

Requires Xcode and [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate          # regenerate after adding/removing source files
open BibleTCG.xcodeproj    # then ⌘R
```

Bundle id `com.bibletcg.app`, iOS 17+. Verified building and running on the iPhone 17 simulator.

## Folders

| Folder | Contents |
|---|---|
| `App/` | App entry point |
| `Models/` | `TCGCard.swift` (card model), `MatchModels.swift` (live match state) |
| `Services/` | `CardLibrary.swift` — **all 87 card definitions** |
| `ViewModels/` | `MatchViewModel.swift` — the match engine (turn loop, abilities, hot-seat) |
| `Views/` | `HomeView`, `TCGMatchView` (playmat board), `TCGCardView` (card face), `CardCollectionView` (gallery), `Theme`, `SeededRNG` |
| `Assets.xcassets/` | 26 imagesets — card art, 3 frames, playmat, card back |
| `Art/Cards/` | 21 oil-painting card portraits (source files for the importer) |
| `Art/Frames/` | Card-type overlays: `Human Overlay`, `animal card overlay`, `Event border V1`, backs, spare templates |
| `Art/Playmat/` | `playmat v4.jpg` — the landscape game board (4096×2240) |
| `Resources/` | `bible-tcg-rules.md` + `cards.json` (design spec), Firefly art prompts |
| `import-art.py` | Art → asset-catalog importer |

## The game

**Card types**
- **Humans** — have a *Discipline*: Wisdom (card advantage), Courage (combat), Strength (durability)
- **Creatures** — have an *Element*: Air, Sea, or Land
- **Events** — cleared by accumulating element points (e.g. "2 Sea, 1 Air")
- **Relics** — persistent effects; some buff Humans of a chosen Discipline

**Zones:** Basecamp (max 4, slot 1 = **Guardian**, takes Raid damage) → Frontier (max 5) → Altar (sacrificed creatures).

**Mana — the Mana Pool:** you start with an empty Pool. Once per turn you may **convert** a
card from hand into your Mana Pool, and its mana is usable that same turn. Mana refills to the
size of your Pool each turn, capped at 10 cards. Ramping costs you cards.

The Pool is a **separate zone from the discard** — a converted card is spent permanently and
can never be recovered, so discard recursion (River Otter) cannot reach it.

**Core loop:** play cards to the Basecamp; **March** to the Frontier (must wait overnight
unless it has *Charge*); attack; **Raid** the enemy Guardian when their Frontier is empty;
**Sacrifice** Creatures to the Altar to bank element points and overcome Events.

**Events** unlock one at a time. Only Event 1 is face-up at the start; clearing it reveals
Event 2. Event 3 is shared — whoever unlocks it reveals it to both players, though a player
who hasn't cleared their own Events 1 and 2 can see it without being able to clear it.

**Win:** overcome all 3 of your Events.
**Lose:** your Basecamp is emptied by combat. You can never voluntarily empty it — the last
Basecamp card cannot March or be Sacrificed.

Full keyword/trigger rules: `Resources/bible-tcg-rules.md` — that file is the **canonical
vocabulary**, and card text uses only terms defined there.

## Current state

- **87 cards** defined in `Services/CardLibrary.swift` (25 Creatures, 44 Humans, 8 Relics, 10 Events)
- **Every card with printed ability text resolves in the engine**
- **21 cards have real art**; the rest render a tinted placeholder
- **Playable hot-seat match** (2 players, one device, with a hand-hiding handoff screen)
- Played in **landscape** on the playmat
- `./Tests/run-probe.sh` runs 79 headless engine checks

See `PROJECT_STATUS.md` for the full picture and open TODOs.

## Art pipeline

Card art is matched **by filename → card id**. Generate art from
`Resources/firefly-prompts.md`, drop the file into `Art/Cards/`, then:

```bash
python3 import-art.py      # defaults to ./Art/Cards
xcodegen generate && open BibleTCG.xcodeproj
```

The importer has an alias table (`samson.png` → `h_samson`, `youngdavid.png` → `h_david`, …)
and prints which cards still need art. Card art appears with **no code change** — `TCGCardView`
loads `UIImage(named: card.id)` and falls back to a tinted procedural placeholder.

## Known gaps / next steps

- **No player-chosen targeting.** Abilities that say "target" or "chosen" auto-pick. Four
  abilities are simplified for the same reason — "look at the top card" resolves as a plain
  draw, "draw then discard" never discards, and Great Fish can't split its damage.
- **Balance is untested** after the switch to Mana Pool ramp and Creature-only targeting.
- No deck builder — decks are randomly generated from the card pool.
- No AI opponent (was removed in favor of hot-seat for testing).
- Cards lack flavor text and scripture references (these fields were dropped in a model rewrite).
- 6 old animals (fox, dog, hen, sheep, ox, goat) and 6 old items (sling, armour, staff, manna,
  oil, cruse) were retired and could be reinstated.
