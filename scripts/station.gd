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
## changes. The bar above the station reads this number, not the NPC.
var cook_progress := 0.0

const BAR_WIDTH := 1.35
const BAR_HEIGHT := 0.28
const BAR_INSET := 0.035
const BAR_BACK := Color(0.28, 0.28, 0.30)

var _taken_label: Label3D
var _progress_root: Node3D
var _progress_fill: MeshInstance3D
var _alert: Label3D
var _alert_age := 0.0


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


func _process(delta: float) -> void:
	_update_progress()
	_face_progress_bar()
	_update_alert(delta)


## A ticket is on this station and its NPC is actually cooking it. The bar
## hides when they stop; cook_progress stays on the station.
func _cook_in_progress() -> bool:
	if not is_cook() or occupant == null or not occupant.has_method("is_working_now"):
		return false
	return occupant.is_working_now()


func _update_progress() -> void:
	if _progress_root == null:
		return
	var cooking := _cook_in_progress()
	_progress_root.visible = cooking
	if not cooking:
		return
	var inner_w := BAR_WIDTH - BAR_INSET * 2.0
	var inner_h := BAR_HEIGHT - BAR_INSET * 2.0
	var filled := inner_w * clampf(cook_progress, 0.0, 1.0)
	var quad := _progress_fill.mesh as QuadMesh
	quad.size = Vector2(maxf(filled, 0.001), inner_h)
	# QuadMesh is centered, so shift it to keep the left edge fixed.
	_progress_fill.position.x = -inner_w * 0.5 + filled * 0.5
	_progress_fill.visible = filled > 0.001
	_face_progress_bar()


func _face_progress_bar() -> void:
	if _progress_root == null or not _progress_root.visible or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var xform := _progress_root.global_transform
	xform.basis = cam.global_transform.basis
	_progress_root.global_transform = xform


## A finished dish is waiting. The mark stays until an NPC picks it up
## (or the dish is thrown out because the customer left).
func _update_alert(delta: float) -> void:
	if _alert == null:
		return
	var ready := is_cook() and not dishes.is_empty()
	if not ready:
		_alert.visible = false
		_alert_age = 0.0
		return
	if not _alert.visible:
		_alert_age = 0.0
	_alert.visible = true
	_alert_age += delta
	var pop := 1.0
	if _alert_age < 0.16:
		pop = lerpf(0.25, 1.2, _alert_age / 0.16)
	elif _alert_age < 0.28:
		pop = lerpf(1.2, 1.0, (_alert_age - 0.16) / 0.12)
	var blink: float = 1.0 if fmod(_alert_age, 0.5) < 0.3 else 0.25
	_alert.modulate = Color(1.0, 0.86, 0.1, blink)
	_alert.scale = Vector3.ONE * pop


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
	_progress_root = Node3D.new()
	_progress_root.position = Vector3(0, height + 0.82, 0)
	_progress_root.visible = false
	add_child(_progress_root)
	var frame := _bar_quad(Vector2(BAR_WIDTH, BAR_HEIGHT), BAR_BACK, 0)
	_progress_root.add_child(frame)
	_progress_fill = _bar_quad(Vector2(0.001, BAR_HEIGHT - BAR_INSET * 2.0), Color(0.20, 0.82, 0.28), 1)
	_progress_fill.position = Vector3(-BAR_WIDTH * 0.5, 0, -0.01)
	_progress_fill.visible = false
	_progress_root.add_child(_progress_fill)
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.font_size = 72
	_alert.outline_size = 14
	_alert.pixel_size = 0.01
	_alert.modulate = Color(1.0, 0.86, 0.1)
	_alert.outline_modulate = Color(0.25, 0.16, 0.0)
	_alert.position = Vector3(0, height + 1.28, 0)
	_alert.no_depth_test = true
	_alert.visible = false
	add_child(_alert)


func _bar_quad(quad_size: Vector2, color: Color, priority: int) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = quad_size
	mesh_inst.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.render_priority = priority
	mesh_inst.material_override = mat
	return mesh_inst
