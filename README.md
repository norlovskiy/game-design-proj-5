# Kitchen Management Prototype

Authority without control: you manage a restaurant kitchen, but every task
goes through employees who don't always do what they're told. The design is
in [outline.md](outline.md) and [docs/](docs/).

Godot 4.3+, GDScript, 3D isometric view, web export.

## Running

Open the folder in Godot 4.3 or later and press Play (`scenes/main.tscn`).

| Key | Does |
|-----|------|
| WASD / arrow keys | Move the manager (screen-relative) |
| E / Space | Interact with the nearest NPC; again to close |
| 1–4 | Assign / Praise / Scold / Break in the interact panel |
| 1–5 | Pick a station in the Assign menu |
| Esc | Back out of the Assign menu, or close the panel |
| F3 | Debug overlay: real numbers, legal actions, force any action |

On `Main` in `scenes/main.tscn`, `level` (1–3) picks the roster, and
`debug_brains` swaps the Debug brain for the Obedient brain.

### Tests

```
godot --headless --path . --import            # first time only
godot --headless --path . -s res://tests/smoke_test.gd
```

The smoke test plays through every verb, forces every NPC action, and runs
orders from customer to payment (plus walk-outs) on the real scene, and exits
non-zero on failure. `tests/screenshot.gd` renders
screenshots, which needs a display (e.g. `xvfb-run`).

### Web export

`export_presets.cfg` has a Web preset writing to `build/web/` (git-ignored).
Install the export templates from the editor first.

## Layout

| Path | What |
|------|------|
| `scripts/balance.gd` | Every tunable constant (mirrors [docs/balance.md](docs/balance.md)) |
| `scripts/main.gd` | Builds a shift: kitchen, camera, manager, roster, UI; routes the interact key |
| `scripts/kitchen.gd` | The kitchen grid (`LAYOUT`), walls, stations, pathfinding, model slots (`MODELS`) |
| `scripts/station.gd` | A station, its standing role, and its tickets and dishes |
| `scripts/order_system.gd` | Customer arrivals, the queue, serving, payment, walk-outs |
| `scripts/order.gd` | One order: a ticket that becomes a dish |
| `scripts/customer.gd` | A customer: queueing, patience face, leaving |
| `scripts/manager.gd` | The manager: movement, verb lock, presence circle |
| `scripts/npc.gd` | NPC state machine: state, legality, wind-ups, actions, opinions, talk line, telegraphs |
| `scripts/character_model.gd` | Character model, animations, personality ring |
| `scripts/brain/` | `Brain` interface, `ObedientBrain`, `DebugBrain` (see [docs/brain-contract.md](docs/brain-contract.md)) |
| `scripts/ui/` | Interact panel, debug overlay |
| `data/personalities/` | One `.tres` per personality; add a file to add a personality |
| `assets/models/characters/` | Kenney Mini Characters (CC0), extracted from `assets/kenney_mini-characters.zip` |
| `assets/models/kitchen/` | The KayKit Restaurant Bits models in use (CC0), extracted from `assets/KayKit_Restaurant_Bits_1.0_FREE.zip` |

## Built so far

- 3D isometric kitchen built from KayKit models: stove (grill), single stove
  with pan (fryer), table with cutting board (prep), sink (cleaning), counter,
  break tables and chairs, fridge and crates, and the customer area.
- The manager's movement, the `MANAGER_RADIUS` presence circle, enter/leave
  range events, and the interact key with an `[E]` prompt.
- The interact panel with the talk line (all ten lines, in priority order),
  energy and opinion sliders, coworker opinions, and Assign / Praise / Scold /
  Break with `VERB_LOCK`, per-NPC cooldown and diminishing returns.
- The NPC state machine: the seven actions with legality, wind-ups that
  interacting cancels, refuse, timed chat / fight / break, the Overachiever
  crash, opinion and mood rules, and snapshot schema v1.
- The Brain interface with timeout, fallback and dropping stale answers; the
  Obedient and Debug brains; the debug overlay.

- The order pipeline: customers arrive and queue, the counter NPC takes
  orders and carries tickets to the cook stations, cooks cook them into
  dishes, the counter NPC serves them, and customers pay base price plus a
  tip that shrinks with patience, or walk out. Earnings show top left.

## Not built yet

- Spills, and the talk line "This place is a mess."
- Days, levels, grades, screens (title, pause, day summary, level result),
  saving.

## Credits

Characters: [Kenney](https://www.kenney.nl) Mini Characters, CC0.
Kitchen: [KayKit](https://www.kaylousberg.com) Restaurant Bits by Kay Lousberg, CC0.
