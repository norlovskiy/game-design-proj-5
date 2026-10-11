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

The smoke test plays through every verb and forces every NPC action on the
real scene, and exits non-zero on failure. `tests/screenshot.gd` renders
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
| `scripts/station.gd` | A station and its standing role |
| `scripts/manager.gd` | The manager: movement, verb lock, presence circle |
| `scripts/npc.gd` | NPC state machine: state, legality, wind-ups, actions, opinions, talk line, telegraphs |
| `scripts/character_model.gd` | Character model, animations, personality ring |
| `scripts/brain/` | `Brain` interface, `ObedientBrain`, `DebugBrain` (see [docs/brain-contract.md](docs/brain-contract.md)) |
| `scripts/ui/` | Interact panel, debug overlay |
| `data/personalities/` | One `.tres` per personality; add a file to add a personality |
| `assets/models/characters/` | Kenney Mini Characters (CC0), extracted from `assets/kenney_mini-characters.zip` |

## Built so far

- 3D isometric kitchen with the five stations, a break bench and the
  customer area, using placeholder boxes.
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

## Not built yet

- The order pipeline, customers, tickets and dishes, money, spills (and the
  talk line "This place is a mess."). Until orders exist, Work at a station
  is always "waiting".
- Days, levels, grades, screens (title, pause, day summary, level result),
  saving.
- Kitchen models: `assets/KayKit_Restaurant_Bits_1.0_FREE.zip` is an empty
  (0-byte) file. Re-add the real zip, extract the models under
  `assets/models/kitchen/`, and set their paths in `MODELS` in
  `scripts/kitchen.gd`.

## Credits

Characters: [Kenney](https://www.kenney.nl) Mini Characters, CC0.
