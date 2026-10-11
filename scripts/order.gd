class_name Order
extends RefCounted
## One customer's order. It starts as a ticket marked for one cook station,
## becomes a dish once cooked, and is served to the customer. Tickets and
## dishes are visible objects that NPCs carry. See docs/stations-and-orders.md.

enum State { TICKET, DISH, SERVED, CANCELLED }

const TICKET_MODEL := "menu"
const TICKET_SCALE := 0.45
## Models stacked to make each station's dish.
const DISH_MODELS := {
	"grill": ["food_burger"],
	"fryer": ["plate_small", "food_ingredient_onion_rings"],
	"prep": ["food_dinner"],
}
const DISH_SCALE := 0.4

var station_id := ""
var customer: Customer
var state := State.TICKET
## The visible ticket or dish.
var item: Node3D


func _init(p_station_id: String, p_customer: Customer) -> void:
	station_id = p_station_id
	customer = p_customer
	item = _make_item([TICKET_MODEL], TICKET_SCALE)


func is_cancelled() -> bool:
	return state == State.CANCELLED


func become_dish() -> void:
	var parent := item.get_parent()
	var pos := item.position
	item.queue_free()
	item = _make_item(DISH_MODELS[station_id], DISH_SCALE)
	state = State.DISH
	if parent:
		place(parent, pos)


## The customer left: the ticket or dish is thrown away.
func cancel() -> void:
	state = State.CANCELLED
	if is_instance_valid(item):
		item.queue_free()


## Puts the ticket or dish on a station, in hands, or on a customer.
func place(parent: Node3D, pos: Vector3) -> void:
	if not is_instance_valid(item):
		return
	if item.get_parent():
		item.reparent(parent, false)
	else:
		parent.add_child(item)
	item.position = pos
	item.rotation = Vector3.ZERO


func _make_item(files: Array, item_scale: float) -> Node3D:
	var root := Node3D.new()
	for file: String in files:
		var path := Kitchen.KAYKIT % file
		var piece: Node3D
		if ResourceLoader.exists(path):
			piece = (load(path) as PackedScene).instantiate()
			piece.scale = Vector3.ONE * item_scale
		else:
			piece = _placeholder()
		root.add_child(piece)
	return root


func _placeholder() -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.05 if state == State.TICKET else 0.15, 0.15)
	mesh.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE if state == State.TICKET else Color(0.9, 0.6, 0.3)
	mesh.material_override = m
	return mesh
