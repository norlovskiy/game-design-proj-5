class_name Personality
extends Resource
## One personality. Adding a personality means adding a .tres file in
## data/personalities/, not code. See docs/npc-state-and-actions.md.

## Shown to the brain as text.
@export var display_name := ""
@export_multiline var description := ""

@export_group("Modifiers")
@export var energy_drain := 1.0
@export var spill_chance := 1.0
@export var work_speed := 1.0
@export var praise_multiplier := 1.0
@export var scold_multiplier := 1.0

@export_group("Traits")
## Absolute rules enforced by the state machine, e.g. "never_refuses",
## "crash_at_zero_energy", "hates_hovering".
@export var traits: PackedStringArray = []

@export_group("Look")
## Placeholder look: one flat colour per personality (docs/telegraphs.md).
@export var color := Color.WHITE
## Character model; a Kenney mini-character by default.
@export_file("*.glb", "*.gltf", "*.tscn") var model_path := ""


func has_trait(trait_name: String) -> bool:
	return trait_name in traits
