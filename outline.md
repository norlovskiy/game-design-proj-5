# Design Doc: Kitchen Management Prototype (working title TBD)

This page is the overview. Each system has its own spec in `docs/`:

| Page | Covers |
|------|--------|
| [NPC state and actions](docs/npc-state-and-actions.md) | Internal state, the seven actions, legality, personalities, how opinions move |
| [Brain contract](docs/brain-contract.md) | The interface between the NPC state machine and decision-making (Jev + fallback) |
| [Interactions](docs/interactions.md) | Manager movement, presence radius, the interact panel, praise / scold / break, screens |
| [Stations and orders](docs/stations-and-orders.md) | Kitchen, stations, the order pipeline, customers, spills |
| [Levels and economy](docs/levels-and-economy.md) | Levels, days, the money goal, grades, persistence, saving |
| [Telegraphs](docs/telegraphs.md) | What every state looks like: emoji, animation, placeholder art list |
| [Balance](docs/balance.md) | Every tunable constant, by name |
| [Glossary](docs/glossary.md) | The project's vocabulary |
| [Handoff](docs/handoff.md) | Who owns what, and assumptions still to confirm |

## Pitch
A 3D isometric management game (fixed top-down orthographic camera, low-poly
models) made in Godot 4, played in the browser. You manage a small restaurant kitchen. Core theme: **authority
without control**. The player never cooks, serves or cleans. Every task goes
through employees who have distinct personalities and don't always do what
they're told.

## Design goal
Managing people means working with who they are, not who you want them to be.
The player succeeds by learning each employee's quirks and arranging the shift
around them. NPC differences in behavior AND looks are what the player must
read and plan around.

## Core loop
- Each day runs in real time. Customers arrive and orders come in.
- The manager walks the kitchen and gives employees standing roles on
  stations: counter, grill, fryer, prep, cleaning.
- Employees decide for themselves, moment to moment, whether to work, slack,
  refuse, wander to another station, chat, fight or take a break.
- A level spans three days. Total earnings over the three days must reach the
  level goal. Falling short restarts the level.

## Player interactions
- The manager is an avatar. All interaction is by walking up to an employee
  and pressing the interact key.
- Verbs: **Assign**, **Praise**, **Scold**, **Break**.
- Manager position matters: employees react to the manager being in range.
- Rule: the player never performs tasks directly.

## NPCs
- Five personalities: Lazy, Irritable, Clean freak, Chatty, Overachiever.
  Personalities are data files, so more can be added.
- Internal state per NPC: mood, energy, opinion of the manager, opinion of
  each coworker.
- Seven actions: Work, Slack, Refuse, Switch station, Chat, Fight, Break.
- Every action the manager did not order is preceded by a visible wind-up the
  player can interrupt.

## Communication rule
Almost no text: show, don't tell. Mood is an always-visible emoji above each
head; events and wind-ups show larger emoji bubbles. The one exception is the
**talk line**: when the manager interacts with an employee, a single short
sentence says what they most want ("I need a break", "I'm mad at Avery"), so
the player never has to guess. Energy and opinions appear as sliders in the
same panel. There are no dialogue trees.

## NPC decision-making
- The state machine (Norman) owns state, legality and how actions play out.
- A **Brain** picks one action from the currently legal ones. The production
  brain calls Jev; a deterministic utility brain is the fallback on timeout
  or an invalid answer (both Baani).
- Failure should come from accumulated neglect, never from one bad roll.

## Levels
| Level | NPCs | Roster |
|-------|------|--------|
| 1 | 3 | Lazy, Irritable, Clean freak |
| 2 | 4 | the same three + Chatty |
| 3 | 5 | the same four + Overachiever |

Order volume increases with each level.

## Tech baseline
Godot 4.x, GDScript, web export (Compatibility renderer). 3D isometric view
with an orthographic camera; one tile is one world unit. WASD or arrow keys
to move (screen-relative), one interact key. See the [README](README.md) for
how to run the project.

## Out of scope
Hiring/firing, upgrades, menu expansion, recipes/ingredient steps,
customer personalities, story, level select, settings beyond volume.

## Later
- Perks for earning well past the goal, to reward playing on after the goal
  is met. For now the grade (F, C, B, A, S) is the only reward.
