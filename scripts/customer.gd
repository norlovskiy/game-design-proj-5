class_name Customer
extends Node3D
## A simple character that queues at the counter, waits and pays. No
## personality, no behaviour beyond waiting. Patience runs from arrival until
## the dish is served, and shows as a changing face. See
## docs/stations-and-orders.md.

const MODELS := [
	"character-female-a", "character-female-c", "character-female-f",
	"character-male-c", "character-male-e", "character-male-f",
]
## Patience share -> face, best first.
const FACES := [[0.66, ":)"], [0.33, ":|"], [0.12, ":("], [0.0, ">:("]]
const FACE_COLORS := [Color(0.3, 0.85, 0.35), Color(0.95, 0.85, 0.25), Color(0.95, 0.55, 0.2), Color(0.9, 0.2, 0.2)]

var patience := Balance.CUSTOMER_PATIENCE
var order: Order
## True once they have stopped waiting: served, or walked out.
var leaving := false

var model: CharacterModel
var _target := Vector3.ZERO
var _face: Label3D
var _bubble: Label3D


func _ready() -> void:
	model = CharacterModel.new()
	add_child(model)
	var file: String = MODELS[randi() % MODELS.size()]
	model.setup("res://assets/models/characters/%s.glb" % file, Color.WHITE, false)
	_face = _label(56, 1.45)
	_bubble = _label(48, 1.8)
	_target = global_position


func walk_to(point: Vector3) -> void:
	_target = point


func is_at_target() -> bool:
	return Kitchen.tile_distance(global_position, _target) < 0.05


func patience_share() -> float:
	return clampf(patience / Balance.CUSTOMER_PATIENCE, 0.0, 1.0)


## Served (happy) or walked out (angry): walk off and disappear.
func leave(exit_point: Vector3, happy: bool) -> void:
	leaving = true
	_bubble.text = "" if happy else ">:("
	_bubble.modulate = Color(0.9, 0.2, 0.2)
	_face.visible = happy
	walk_to(exit_point)


func _process(delta: float) -> void:
	if not leaving:
		patience = maxf(0.0, patience - delta)
	_update_face()
	var to := _target - global_position
	to.y = 0.0
	var step := Balance.CUSTOMER_WALK_SPEED * Balance.TILE_SIZE * delta
	if to.length() > step:
		global_position += to.normalized() * step
		model.face(to)
		model.play("walk")
	else:
		global_position = Vector3(_target.x, global_position.y, _target.z)
		if leaving:
			queue_free()
			return
		model.face(Vector3(0, 0, -1))  # toward the counter
		model.play("idle")


func _update_face() -> void:
	var share := patience_share()
	for i in FACES.size():
		if share >= FACES[i][0]:
			_face.text = FACES[i][1]
			_face.modulate = FACE_COLORS[i]
			return


func _label(font_size: int, height: float) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.outline_size = 12
	label.pixel_size = 0.006
	label.no_depth_test = true
	label.position.y = height
	add_child(label)
	return label
