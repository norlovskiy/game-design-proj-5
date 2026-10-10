# Handoff

Three people. Each section says what that person owns and what they need
from the others.

## Norman: setup, movement, NPC states, menus, interactions

Builds everything except the choosing, so that every interaction in the game
can happen.

- Godot 4.x project, GDScript, web export.
- Manager movement, presence radius, interact key.
- The kitchen, stations, the order pipeline, customers, spills.
- The NPC state machine: state values, legality, wind-ups, how each action
  plays out, every rule that changes mood, energy and opinions.
- Personalities as Resource files.
- The interact panel, talk line, four verbs, and all screens.
- The Brain interface, the Obedient brain, the Debug brain and debug overlay.
- Placeholder art for every state in [Telegraphs](telegraphs.md).
- A balance file with every constant from [Balance](balance.md) in one place.

Done when: with the Debug brain, every action in
[NPC state and actions](npc-state-and-actions.md) can be forced on every
personality and plays out as specified, and a level can be played start to
finish with the Obedient brain.

Specs: [NPC state and actions](npc-state-and-actions.md),
[Interactions](interactions.md), [Stations and orders](stations-and-orders.md),
[Levels and economy](levels-and-economy.md).

## Baani: Jev and decision-making

Builds the brains that make NPCs behave like their personalities.

- The Utility brain: deterministic weighted scoring over legal actions. It is
  the fallback, and must make a complete game on its own.
- The Jev brain: turns a snapshot into a Jev request and the answer back into
  an action id.
- The proxy that holds the Jev key. The key never ships in the web build.
- The wording of personalities and state for Jev.

Can start before the game exists, working from the snapshot schema.

Spec: [Brain contract](brain-contract.md). The section "What the brain is
expected to weigh" lists the behaviours that are the brain's responsibility.

Needs from Norman: any change to the snapshot schema is agreed together and
bumps `schema_version`.

## Naxin: balance, polish, game feel

Makes it fair, readable and good to play.

- Every value in [Balance](balance.md), especially those marked TBD.
- Level goals, customer arrival rates, grade feel.
- Final art, animation, emoji and sound, replacing the placeholders listed in
  [Telegraphs](telegraphs.md).
- The check that failure comes from accumulated neglect, never from one bad
  roll.

Needs from Norman: the balance file and the debug overlay. Needs from Baani:
the utility weights exposed as tunable values.

## Assumptions made while writing

These details were filled in to make the specs complete and were not
explicitly decided. Confirm or change them.

1. The counter NPC does three things: takes the order, carries the ticket to
   the cook station, and carries the dish back to the customer.
2. One patience timer runs from a customer's arrival until they are served.
3. Each station holds one NPC. Assigning to a taken station swaps the other
   NPC off it.
4. Stations are cleared at the start of each day, so the player assigns
   everyone again each morning.
5. On a level restart, opinions return to their values at the start of that
   level.
6. Interacting with an NPC in a wind-up cancels it and opens the panel.
   Interacting with a fighter ends the fight and opens no panel.
7. Refuse has no wind-up, and is only legal in answer to an Assign or Break
   order.
8. Chat and an unasked Break have wind-ups, like every other unordered action.
9. Bad moods spread to coworkers working nearby (from the original outline;
   the rate is TBD).
10. The ten talk lines and their priority order in
    [Interactions](interactions.md) are a proposal.
11. Mood is not shown in the interact panel, only overhead.
12. The pause screen pauses the game; the interact panel does not.

## Still open

- Working title.
- Names for the five employees.
- Perks for earning well past the goal.
