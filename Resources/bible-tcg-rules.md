# Bible TCG — Rules & Vocabulary

Two players race to the **Promised Land** by overcoming 3 Events.

This document is the canonical vocabulary. Card text uses only the terms defined
here. `Services/CardLibrary.swift` is the live card set (87 cards); the tables at
the end of this file cover the **starter set** only.

Stat formula: **Human total (ATK+HP) = 2× cost.** **Creature total = 2× cost, minus 1** (equal at cost 1).
Creatures pay less total stats because Sacrifice gives them an escape valve Humans don't have.

---

## Card types

| Type | Attribute | Notes |
|---|---|---|
| **Human** | a **Discipline** — Wisdom, Courage, Strength | Has Attack / Health |
| **Creature** | an **Element** — Air, Sea, Land | Has Attack / Health. Only Creatures can be Sacrificed |
| **Event** | an element requirement | Not played from hand — see *Events* |
| **Relic** | — | Permanent. Max **2 per deck** |

"Creature" and "Human" are always capitalized and always mean the card type. A
Human standing in the Frontier is **not** a Creature and cannot be targeted by an
ability that says Creature.

## Zones

| Zone | Limit |
|---|---|
| **Deck** | — |
| **Hand** | 7 |
| **Basecamp** | 4 — slot 1 is the **Guardian** |
| **Frontier** | 5 |
| **Relic slots** | 2 |
| **Altar** | — holds Sacrificed Creatures |
| **Discard** | — |

Basecamp and Frontier are **separate zones**.

---

## Static keywords

Static keywords are always-on properties, not triggers.

- **Charge** — may March the same turn it's played, skipping the overnight wait.
- **Shield** — prevents the first instance of combat damage this card would take
  each turn. A printed Shield **refreshes at the start of its controller's turn**.
  A Shield granted by another card lasts only for the duration that card states.
- **Guard** — this card's ability is active **only while it is in your Basecamp**.
  It switches off the moment the card Marches, dies, or otherwise leaves.

## Triggers

A trigger fires at a moment.

- **Play:** — enters the Basecamp from hand.
- **March:** — moves from the Basecamp to the Frontier.
- **Raid:** — breaks through an empty enemy Frontier and hits their Basecamp.
- **Sacrifice:** — a Creature is given to the Altar.
- **Death:** — dies in combat or is destroyed, and goes to the discard.

**Blessing** is not a keyword. When a Creature's Sacrifice ability buffs a Human,
that's called a Blessing.

## Terms

- **attack** — your card initiates combat. **defend** — your card is the one
  being attacked. There is no such thing as "fighting", and there is no blocking.
- **damaged** — current Health is below max Health.
- **lowest Health** — how "weakest" is measured. Ties break by board order.
- **overnight** — a card has spent the night once it has been in play throughout
  your opponent's entire turn. Marching requires this, unless the card has Charge.
- **Heal N** / **Heal to full** — the only two healing forms.
- **Scope.** An effect that names no side refers to **your own** cards. Text says
  **enemy** when it means the opponent's. (Condition checks may still read
  "if you control …" — that's a condition, not a target.)

---

## Mana — berries

You start the game with **0 berries**.

Once per turn you may **eat** a card from your hand. It goes to the discard and
you gain **one berry**, permanently — and that berry's mana is available on the
same turn you ate it.

At the start of each of your turns your mana refills to your berry count. At
**10 berries** you can no longer eat.

Ramping costs you cards. Skipping a meal leaves you permanently a berry behind.

## Combat

When a card attacks from the Frontier, the attacker and the defender each deal
damage equal to their Attack to the other. A card whose Health reaches 0 goes to
the discard.

If the enemy Frontier is empty, an attacker **Raids** the enemy Basecamp
Guardian instead. A Raid takes **no retaliation**.

## The Guardian

Basecamp slots are numbered 1–4 in the order cards are placed. The card in slot 1
is the **Guardian** and takes all incoming Raid damage. When the Guardian dies or
leaves the Basecamp, every other card shifts up one slot and whichever card is
now in slot 1 becomes the new Guardian. This is automatic — not a card ability.

## Sacrifice and points

Sacrificing a Creature moves it to the **Altar** and gives you **+1 point** of
that Creature's Element.

Cards that change this are written as `+N <Element> points` — for example
`Sacrifice: +2 Sea points`.

When several modifiers apply, resolve in this order:

1. Set the base amount (the Creature's own printed value, e.g. Kraken's +3)
2. Apply flat modifiers (Moses: +1 extra point)
3. Apply multipliers (Fish Net: double)

So Kraken, with Moses in the Basecamp and Fish Net in play: (3 + 1) × 2 = **8 Sea points**.

## Events

Each player has their own **Event 1** and **Event 2**. **Event 3 is shared** —
both players race the same card.

Events unlock **one at a time**. Only Event 1 is face-up at the start; clearing it
reveals Event 2, and clearing Event 2 unlocks Event 3.

When either player unlocks Event 3, it is revealed to **both** players. A player
who has not yet cleared their own Events 1 and 2 can *see* Event 3 but cannot
clear it.

You overcome an Event when your point pool covers its requirement. Clearing an
Event subtracts **exactly** its requirement — any surplus stays banked for the
next one — and flushes your Altar to the discard.

Clears **cascade**: if clearing Event 1 leaves you with enough points for the
Event 2 it just revealed, that clears too, in the same action.

## Winning and losing

- **Win:** overcome all 3 of your Events and reach the Promised Land.
- **Lose:** your Basecamp is emptied by combat. You may never voluntarily empty
  it — the last card in your Basecamp cannot March or be Sacrificed.

Other rules: a card must have spent the night in its zone before it can March
(unless it has Charge). If the Frontier is at its 5-card max, you may discard a
card or Sacrifice a Creature to make room.

---

# Starter Card Set

## Creatures (20)

| Name | Cost | Element | ATK/HP | Ability |
|---|---|---|---|---|
| Sparrow | 1 | Air | 1/1 | Sacrifice: Draw a card. |
| Tide Pool Crab | 1 | Sea | 0/2 | Vanilla. |
| Raven | 2 | Air | 2/1 | Play: Look at the top card of your deck. Sacrifice: A Wisdom Human you control draws a card. |
| Minnow Shoal | 2 | Sea | 1/2 | Sacrifice: +2 Sea points. |
| Locust | 2 | Air | 2/1 | Sacrifice: Deal 1 damage to target enemy Frontier Creature. |
| Wild Boar | 3 | Land | 3/2 | Charge. |
| Golden Jackal | 3 | Land | 3/2 | Death: Deal 1 damage to the Creature that killed it. Sacrifice: Give a Courage Human +1 attack. |
| Owl | 3 | Air | 2/3 | Guard: The first Human that Marches to the Frontier each turn gains Shield until end of turn. |
| River Otter | 3 | Sea | 3/2 | Sacrifice: Return a Human from your discard to your hand. |
| Stone Ram | 3 | Land | 2/3 | Charge. |
| Lion | 4 | Land | 4/3 | Guard: The Guardian gets +2/+0. |
| Eagle | 4 | Air | 3/4 | March: This Creature may attack the Guardian even if the enemy Frontier is occupied. |
| Great Fish | 4 | Sea | 3/4 | Sacrifice: Deal 4 damage split among any number of enemy Frontier Creatures. |
| Behemoth Calf | 4 | Land | 4/3 | Vanilla. |
| Serpent | 5 | Land | 5/4 | Sacrifice: Destroy an enemy Frontier Creature with 3 or less Health. |
| Whale | 5 | Sea | 4/5 | Guard: Sea Creatures cost 1 less to play. |
| Griffin Vulture | 5 | Air | 5/4 | Death: Draw a card. |
| Kraken | 6 | Sea | 6/5 | Sacrifice: +3 Sea points. |
| Great Bear | 6 | Land | 5/6 | Sacrifice: Give a Strength Human +2/+3. |
| Leviathan | 7 | Land | 9/6 | Vanilla. |

## Humans (20)

| Name | Cost | Discipline | ATK/HP | Ability |
|---|---|---|---|---|
| Shepherd Boy | 1 | Courage | 1/1 | Play: Look at the top card of your deck. |
| Field Hand | 1 | Strength | 0/2 | Vanilla. |
| Watchman | 2 | Wisdom | 1/3 | Vanilla. |
| Young Scribe | 2 | Wisdom | 2/2 | Play: Draw a card, then discard a card. |
| Herald | 2 | Courage | 2/2 | March: Draw a card if this is the first Human you've Marched this turn. |
| Farmer | 2 | Strength | 1/3 | Guard: Whenever you Sacrifice a Creature, this gains +1/+0. |
| Elder | 3 | Wisdom | 2/4 | Guard: Humans in the Frontier get +0/+1. |
| Soldier | 3 | Courage | 4/2 | Charge. |
| Fisherman | 3 | Courage | 3/3 | March: If you control a Sea Creature, this gains +1/+1 until end of turn. |
| Physician | 3 | Wisdom | 2/4 | Death: Heal 2 on each other Human in the Frontier. |
| Priest | 4 | Wisdom | 3/5 | Guard: Whenever you Sacrifice a Creature, this Human heals to full. |
| Judge | 4 | Wisdom | 4/4 | Raid: Draw a card. |
| Centurion | 4 | Strength | 5/3 | Charge. |
| Craftsman | 4 | Strength | 3/5 | Vanilla. |
| King's Guard | 5 | Courage | 5/5 | Shield. |
| Prophet | 5 | Wisdom | 4/6 | Guard: Whenever you overcome an Event, draw a card. |
| Warrior Chief | 5 | Strength | 6/4 | March: This Human deals double damage the first time it attacks this turn. |
| High Priest | 6 | Wisdom | 5/7 | Guard: When a Creature's Sacrifice targets this Human, it also gains Shield until your next turn. |
| Champion | 6 | Strength | 7/5 | Raid: Also deal this Human's Attack to the enemy Basecamp card with the lowest Health. |
| Anointed King | 7 | Courage | 7/7 | Vanilla. |

## Relics (5 — decks include up to 2)

| Name | Cost | Ability |
|---|---|---|
| Watchtower | 2 | Whenever an enemy Raids your Basecamp, draw a card. |
| Ark of the Covenant | 5 | The first card you play each turn costs 1 less. |
| Altar of Fire | 6 | Whenever you Sacrifice a Creature, deal 1 damage to a random enemy Frontier Creature. |
| Fish Net | 6 | Sacrifices give double points. |
| Shepherd's Staff | 7 | Cards in the Frontier get +0/+2. |

## Events (10)

| Name | Requirement |
|---|---|
| The Great Flood | 3 Sea |
| Plague of Locusts | 2 Air, 1 Land |
| The Red Sea | 2 Sea, 1 Air |
| Walls of Jericho | 3 Land |
| The Fiery Furnace | 2 Land, 1 Sea |
| The Lion's Den | 3 Land, 1 Air |
| The Great Storm | 2 Sea, 2 Air |
| Tower of Babylon | 2 Air, 2 Land |
| The Whale's Belly | 3 Sea, 1 Land |
| The Tribulation | 2 Air, 2 Land, 2 Sea |

*The Tribulation is the heaviest and is used as the shared Event 3.*
