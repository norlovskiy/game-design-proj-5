class_name Station
extends Node3D
## A place of work: counter, grill, fryer, prep or cleaning.
## Each station holds one NPC (its standing role). See
## docs/stations-and-orders.md.

const IDS: Array[String] = ["counter", "grill", "fryer", "prep", "cleaning"]
## Placeholder look per station: flat colour plus a short label.
const LOOKS := {
	"counter": {"label": "COUNTER", "color": Color(0.80, 0.62, 0.40)},
	"grill": {"label": "GRILL", "color": Color(0.30, 0.30, 0.33)},
	"fryer": {"label": "FRYER", "color": Color(0.88, 0.72, 0.25)},
	"prep": {"label": "PREP", "color": Color(0.55, 0.78, 0.50)},
	"cleaning": {"label": "CLEANING", "color": Color(0.45, 0.65, 0.90)},
}

var station_id := ""
## The tile the station's furniture sits on (solid).
var tile := Vector2i.ZERO
## The floor tile an NPC stands on to work here.
var work_tile := Vector2i.ZERO
## The NPC holding this standing role, or null.
var occupant: Node = null

var _taken_label: Label3D


func setup(id: String, at_tile: Vector2i, stand_tile: Vector2i) -> void:
	station_id = id
	tile = at_tile
	work_tile = stand_tile
	name = id.capitalize()


func display_name() -> String:
	return LOOKS[station_id].label.capitalize()


func color() -> Color:
	return LOOKS[station_id].color


func is_free() -> bool:
	return occupant == null


func set_occupant(npc: Node) -> void:
	occupant = npc
	if _taken_label:
		_taken_label.text = npc.npc_name if npc else ""


## Builds the label above the station. Called by the kitchen after the
## furniture (placeholder or model) is in place.
func build_labels(height: float) -> void:
	var label := Label3D.new()
	label.text = LOOKS[station_id].label
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.006
	label.position = Vector3(0, height + 0.45, 0)
	label.no_depth_test = true
	add_child(label)
	_taken_label = Label3D.new()
	_taken_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_taken_label.font_size = 28
	_taken_label.outline_size = 8
	_taken_label.pixel_size = 0.006
	_taken_label.modulate = Color(1, 1, 1, 0.8)
	_taken_label.position = Vector3(0, height + 0.22, 0)
	_taken_label.no_depth_test = true
	add_child(_taken_label)
