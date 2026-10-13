# Interactions

Owner: Norman. Constants in `CAPS` are defined in [Balance](balance.md).

## The manager

- The manager is an avatar on the kitchen floor.
- Move with WASD or the arrow keys. One interact key.
- The manager never cooks, serves or cleans.
- The manager is not blocked by NPCs and does not block them.

### Presence

"Nearby" is a plain radius of `MANAGER_RADIUS` tiles, with no line of sight.
A faint circle is drawn around the manager so the player can see who is
inside it. NPCs are told when the manager enters or leaves their range.

## Interacting with an NPC

Walk next to an NPC and press interact. What happens depends on their state:

| NPC state | Result |
|-----------|--------|
| In a wind-up | The wind-up is cancelled, the NPC returns to what it was doing, and the panel opens |
| Fighting | The fight ends early for both. No panel |
| On an Overachiever crash break | Nothing; it cannot be interrupted |
| Anything else | The panel opens |

### The interact panel

The game does not pause while the panel is open.

```
+--------------------------------------+
| [portrait]  "I'm mad at Avery."      |   talk line
|                                      |
| Energy        [=======-----]         |
| Opinion of you[====--------]         |
|                                      |
| (face) (face) (face) (face)          |   coworkers
| [==--] [====] [=---] [===-]          |   opinion of each
|                                      |
| [Assign] [Praise] [Scold] [Break]    |   icon buttons
+--------------------------------------+
```

Mood is not in the panel; it is the always-on emoji above the NPC's head.

### The talk line

One short sentence stating the NPC's most pressing need. The state machine
picks it from a fixed list of templates by a fixed priority order; the first
one whose condition holds is shown. Jev does not generate text.

Proposed list, in priority order:

| # | Line | Condition |
|---|------|-----------|
| 1 | "I need a break." | Energy low |
| 2 | "I'm mad at {name}." | Lowest coworker opinion is below a threshold |
| 3 | "Stop hovering." | Irritable, and the manager has been in range a long time |
| 4 | "Stop moving me around." | Reassigned often recently |
| 5 | "I'm mad at you." | Opinion of the manager low |
| 6 | "This place is a mess." | A spill is nearby |
| 7 | "{name} won't stop talking." | Pulled into chats while busy recently |
| 8 | "I've got nothing to do." | Waiting at a station with no work |
| 9 | "I like working with {name}." | Highest coworker opinion is above a threshold |
| 10 | "I'm fine." | Default |

This is the game's one deliberate exception to "almost no text".

## The four verbs

| Verb | What the player does | Effect | Cost |
|------|----------------------|--------|------|
| Assign | Pick a station from an icon menu that opens on the spot | The NPC takes that standing role until told otherwise. The NPC may refuse. | Counts as a reassignment if the NPC already had a station |
| Praise | Press the button | Mood up, opinion of the manager up | Per-NPC cooldown; diminishing returns on repeats; no manager movement lock |
| Scold | Press the button | Work speed +`SCOLD_SPEED_BONUS` for `SCOLD_BURST_DURATION`, then mood −`SCOLD_MOOD_DROP` and opinion of the manager −`SCOLD_OPINION_DROP`. Doubled for Irritable. | Same as Praise |
| Break | Press the button | The NPC leaves the station for `BREAK_DURATION` and energy restores. The NPC may refuse. | Same as Praise, plus the station is unstaffed |

A standing role means "you're on the grill until I say otherwise". The player
manages staffing, not individual tickets.

Assignment happens from where the manager stands: the player does not walk to
the station. Stations taken by another NPC are shown as taken; assigning to
one swaps the other NPC off it, leaving them without a station.

## Screens

| Screen | Contents |
|--------|----------|
| Title | Start, continue from the highest unlocked level, volume |
| Pause | Resume, restart level, quit to title, volume. Pauses the game. |
| Day summary | The day's earnings and progress toward the level goal. Shown after days one and two. |
| Level result | Total earnings, the goal, the grade. Continue or retry. |

Levels are played in order. There is no level select and no setting other
than volume.

## Debug

- An overlay showing every NPC's real numbers, current action and legal
  actions.
- The Debug brain panel, which forces any legal action on any NPC
  (see [Brain contract](brain-contract.md)).
