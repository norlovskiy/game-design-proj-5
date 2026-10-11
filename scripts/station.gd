class_name Station
extends Node3D
## A place of work: counter, grill, fryer, prep or cleaning.
## Each station holds one NPC (its standing role). See
## docs/stations-and-orders.md.

const IDS: Array[String] = ["counter", "grill", "fryer", "prep", "cleaning"]
## Stations that cook tickets into dishes.
const COOK_IDS: Array[String] = ["grill", "fryer", "prep"]
## Height of the work surface, where tickets and dishes are put down.
const TOP_HEIGHT := 0.52
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
## Where the counter NPC stands to drop off a ticket or pick up a dish.
var handoff_tile := Vector2i.ZERO
## The NPC holding this standing role, or null.
var occupant: Node = null

## Cook stations: tickets waiting to be cooked, first in front, and dishes
## ready to be picked up. The counter uses the same lists for tickets and
## dishes left behind by a counter NPC who lost the role.
var tickets: Array[Order] = []
var dishes: Array[Order] = []
## Progress on the front ticket, 0 to 1. Stays with the station if the cook
## changes.
var cook_progress := 0.0

var _taken_label: Label3D
var _progress_label: Label3D


func setup(id: String, at_tile: Vector2i, stand_tile: Vector2i) -> void:
	station_id = id
	tile = at_tile
	work_tile = stand_tile
	name = id.capitalize()


func display_name() -> String:
	return LOOKS[station_id].label.capitalize()


func color() -> Color:
	return LOOKS[station_id].color


func is_cook() -> bool:
	return station_id in COOK_IDS


func current_ticket() -> Order:
	_purge()
	return tickets[0] if not tickets.is_empty() else null


func add_ticket(order: Order) -> void:
	tickets.append(order)
	_layout()


func take_ticket() -> Order:
	_purge()
	if tickets.is_empty():
		return null
	var order: Order = tickets.pop_front()
	_layout()
	return order


## Cooks the front ticket by `amount` (1 = a whole ticket). Returns true when
## it became a dish.
func cook(amount: float) -> bool:
	if current_ticket() == null:
		return false
	cook_progress += amount
	if cook_progress < 1.0:
		_update_progress()
		return false
	cook_progress = 0.0
	var order: Order = tickets.pop_front()
	order.become_dish()
	dishes.append(order)
	_layout()
	return true


func has_dish() -> bool:
	_purge()
	return not dishes.is_empty()


func add_dish(order: Order) -> void:
	dishes.append(order)
	_layout()


func take_dish() -> Order:
	_purge()
	if dishes.is_empty():
		return null
	var order: Order = dishes.pop_front()
	_layout()
	return order


## Drops tickets and dishes whose customer has left.
func _purge() -> void:
	var before := tickets.size() + dishes.size()
	tickets.assign(tickets.filter(func(o: Order) -> bool: return not o.is_cancelled()))
	dishes.assign(dishes.filter(func(o: Order) -> bool: return not o.is_cancelled()))
	if tickets.size() + dishes.size() != before:
		if tickets.is_empty():
			cook_progress = 0.0
		_layout()


## Tickets line up on the left of the work surface, dishes on the right.
func _layout() -> void:
	for i in tickets.size():
		tickets[i].place(self, Vector3(-0.3 + 0.12 * i, TOP_HEIGHT, 0.25))
	for i in dishes.size():
		dishes[i].place(self, Vector3(0.25 - 0.18 * i, TOP_HEIGHT, 0.0))
	_update_progress()


func _update_progress() -> void:
	if _progress_label == null:
		return
	var cooking := is_cook() and not tickets.is_empty()
	_progress_label.visible = cooking
	if cooking:
		var filled := roundi(cook_progress * 8.0)
		_progress_label.text = "[" + "#".repeat(filled) + "-".repeat(8 - filled) + "]"


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
	_progress_label = Label3D.new()
	_progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_progress_label.font_size = 32
	_progress_label.outline_size = 8
	_progress_label.pixel_size = 0.006
	_progress_label.modulate = Color(1.0, 0.85, 0.3)
	_progress_label.position = Vector3(0, height + 0.7, 0)
	_progress_label.no_depth_test = true
	_progress_label.visible = false
	add_child(_progress_label)
