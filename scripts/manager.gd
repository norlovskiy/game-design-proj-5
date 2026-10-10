class_name Manager
extends CharacterBody3D
## The player's avatar. Walks the kitchen with WASD / arrow keys and interacts
## with one key. Never cooks, serves or cleans. Not blocked by NPCs and does
## not block them (NPCs have no collision bodies). See docs/interactions.md.

const MODEL_PATH := "res://assets/models/characters/character-male-a.glb"
const COLOR := Color(0.95, 0.95, 0.95)

## Screen-relative movement: "up" walks away from the camera.
var camera_yaw := deg_to_rad(Balance.CAMERA_YAW_DEG)
## Seconds left before the manager can move again after a verb.
var lock_time := 0.0

var model: CharacterModel


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.0
	shape.shape = capsule
	shape.position.y = 0.5
	add_child(shape)
	model = CharacterModel.new()
	add_child(model)
	model.setup(MODEL_PATH, COLOR)
	_add_presence_circle()


func lock(seconds: float) -> void:
	lock_time = maxf(lock_time, seconds)


func is_locked() -> bool:
	return lock_time > 0.0


func _physics_process(delta: float) -> void:
	lock_time = maxf(0.0, lock_time - delta)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_locked():
		input = Vector2.ZERO
	var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, camera_yaw)
	var speed := Balance.MANAGER_SPEED * Balance.TILE_SIZE
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = 0.0
	move_and_slide()
	if direction.length() > 0.01:
		model.face(direction)
		model.play("walk")
	else:
		model.play("idle")


## The faint circle of MANAGER_RADIUS tiles showing who is in range.
func _add_presence_circle() -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	var r := Balance.MANAGER_RADIUS * Balance.TILE_SIZE
	mesh.inner_radius = r - 0.04
	mesh.outer_radius = r + 0.04
	mesh.rings = 64
	ring.mesh = mesh
	ring.scale = Vector3(1, 0.1, 1)
	ring.position.y = 0.03
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
