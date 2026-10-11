class_name CharacterModel
extends Node3D
## A character's look: the model (a Kenney mini-character), its animations,
## and a flat-colour ring under its feet (the placeholder personality look).

## Kenney minis are small next to one-unit tiles.
const MODEL_SCALE := 1.4
const LOOPING := ["idle", "walk", "sprint", "sit", "interact-right", "holding-both", "attack-melee-right"]

var _model: Node3D
var _anim: AnimationPlayer
var _current := ""


func setup(model_path: String, ring_color: Color, with_ring := true) -> void:
	if model_path != "" and ResourceLoader.exists(model_path):
		_model = (load(model_path) as PackedScene).instantiate()
	else:
		_model = _placeholder(ring_color)
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for anim_name in LOOPING:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	if with_ring:
		_add_ring(ring_color)
	play("idle")


## Plays an animation by name if the model has it. Safe to call every frame.
func play(anim_name: String, speed := 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed
	if _current != anim_name:
		_current = anim_name
		_anim.play(anim_name, 0.15)


## Turns to face a direction on the floor plane. Kenney models face +Z.
func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() < 0.001:
		return
	var target := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target, 0.35)


func face_point(point: Vector3) -> void:
	face(point - global_position)


func _add_ring(color: Color) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.26
	mesh.outer_radius = 0.36
	mesh.rings = 24
	ring.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.02
	add_child(ring)


func _placeholder(color: Color) -> Node3D:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 0.9
	mesh.mesh = capsule
	mesh.position.y = 0.45
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mesh.material_override = m
	var root := Node3D.new()
	root.add_child(mesh)
	return root
