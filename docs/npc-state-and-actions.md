# NPC state and actions

Owner: Norman. Constants in `CAPS` are defined in [Balance](balance.md).

The NPC state machine owns three things: the numbers, which actions are legal
right now, and how each action plays out. It never chooses. Choosing is the
[Brain](brain-contract.md)'s job.

## Internal state

All values are 0–100.

| Value | Shown to the player as | Across days | Across levels |
|-------|------------------------|-------------|---------------|
| Mood | Always-on emoji above the head, five tiers | Partially resets toward neutral | Resets |
| Energy | Slider in the interact panel | Resets to full | Resets |
| Opinion of the manager | Slider in the interact panel | Persists | Persists |
| Opinion of each coworker | Small slider under that coworker's face in the panel | Persists | Persists |

Each NPC also keeps its current station, current action, and a log of its
last `EVENT_LOG_SIZE` events (see [Brain contract](brain-contract.md)).

## Who changes the numbers

Every change to mood, energy and opinions is a fixed rule in the state
machine, read from the balance file and the NPC's personality. The brain only
reads state and picks actions. This keeps the game tunable without touching
Jev.

## Actions

| Action | What it is | Legal when |
|--------|------------|------------|
| Work | Do the job of the assigned station. If there is nothing to do (no tickets, no spills), the NPC waits at the station; waiting is not slacking. | Has a station and energy above 0 |
| Slack | Stop working and idle (phone, leaning) at or near the station | Always |
| Refuse | Reject an order the manager just gave; the previous role stands | Only at the moment of an Assign or a Break order; never for a personality with the `never_refuses` trait |
| Switch station | Walk to a different station and take it up, unasked | Another station is free |
| Chat | Stop and talk with a coworker; both stop working for `CHAT_DURATION` | A coworker is within one tile and neither is fighting or mid wind-up |
| Fight | Argue with a coworker; both stop working for `FIGHT_DURATION` | A coworker is adjacent and the pair is not on fight cooldown |
| Break | Leave the station for `BREAK_DURATION`; energy restores | Always. Ordered by the manager or taken unasked |

Legal actions are handed to the brain fully specified: one entry per target,
such as "switch to fryer" or "fight Avery".

Cleaning is Work at the cleaning role. A spill is not an action; see
[Stations and orders](stations-and-orders.md).

### Wind-ups

Every action the manager did not order starts with a wind-up state lasting
`WINDUP_DURATION`, with its own emoji and animation
(see [Telegraphs](telegraphs.md)). The wind-up is part of the state machine,
so no brain can skip it. If the manager interacts with the NPC during the
wind-up, the action is cancelled and the NPC returns to what it was doing.

### Energy and work speed

- Work speed = `BASE_WORK_SPEED` × an energy factor × a mood factor × the
  personality's modifier.
- Working drains energy; a break restores it.
- At zero energy, Work is not legal. The NPC can only slack or take a break.

### Fight

- Hard requirements: the two are adjacent, and the pair's fight cooldown
  (`FIGHT_PAIR_COOLDOWN`) has run out. There is no opinion threshold.
- Weight: every adjacent pair has a small baseline chance. It grows as their
  opinion of each other falls, and when either is Irritable. The baseline is
  low enough that two NPCs who like each other fight very rarely. The weights
  themselves belong to the brain (Jev, and the utility fallback).
- Effect: both stop working for `FIGHT_DURATION`. Each one's opinion of the
  other drops. NPCs nearby lose a little mood.
- The manager ends a fight early by interacting with either fighter.

### Break

- Ordered: the manager chooses Break in the panel. The NPC may refuse.
- Unasked: the NPC may take one itself, with a wind-up.
- Overachiever crash: at zero energy an Overachiever is forced into a break
  of double length that cannot be interrupted.

## How opinions move

### Opinion of a coworker

| Direction | Cause |
|-----------|-------|
| Down | Being pulled into a chat while busy |
| Down | Cleaning up that coworker's spill |
| Down | Working next to that coworker while they slack |
| Down | Fighting with them |
| Up | A chat when both are idle or on break |
| Up | A shift worked side by side without incident |
| Up | Time apart after a fight: slow drift back toward neutral |

The player's lever is who is stationed next to whom.

### Opinion of the manager

| Direction | Cause |
|-----------|-------|
| Up | Praise |
| Up | A break granted when energy is low |
| Up | Being left on one station |
| Down | Scold |
| Down | Frequent reassignment |
| Down | The manager seeing "I need a break" and not granting one |
| Down | Hovering (Irritable only) |

It also drifts slowly toward neutral.

### Starting values

Opinions start near `OPINION_NEUTRAL` with small authored offsets per pair
(for example, Clean freak starts a little low on Lazy), so each level has a
relationship to discover from the first minute. An NPC who joins at a later
level starts at neutral with everyone.

### Mood

Mood moves with praise and scold (see [Interactions](interactions.md)),
fights nearby, chats, and low energy. Bad moods spread: an NPC working near a
coworker in a low mood slowly loses mood. Amounts are in
[Balance](balance.md).

## Personalities

A personality is a Godot Resource file. Adding a personality means adding a
file, not code. Each one holds:

- a name and a one-line description (sent to the brain as text),
- numeric modifiers (energy drain, spill chance, work speed, effect
  multipliers for praise and scold),
- trait flags that change legality or forced behaviour,
- the look that telegraphs it (see [Telegraphs](telegraphs.md)).

| Personality | Behaviour | Traits and modifiers |
|-------------|-----------|----------------------|
| Lazy | Works when the manager is in range; slacks when the manager leaves. Spills things. | Raised spill chance |
| Irritable | Works worse when the manager hovers; slows down or snaps if reassigned too often. Picks fights more readily. | Scold effects doubled; opinion of the manager falls while hovered over |
| Clean freak | Drops everything to clean a spill, whether or not the manager is there. | Switch to the cleaning role is strongly favoured when a spill exists |
| Chatty | Pulls passing coworkers into conversation. | Chat strongly favoured when a coworker passes within one tile |
| Overachiever | Never refuses, burns energy fast, then crashes. | `never_refuses`; raised energy drain; forced double-length break at zero energy |

Behaviour that is a matter of preference (Lazy slacking, Chatty chatting) is
expressed through the brain's weights, not through legality. Behaviour that
is absolute (Overachiever never refusing, the crash) is a trait flag enforced
by the state machine.

Personalities should interact: Lazy spills, so Clean freak abandons their
station; Chatty distracts others; bad moods spread; low opinions lead to
fights.
