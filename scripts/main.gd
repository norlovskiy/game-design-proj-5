extends Node3D
## Builds one shift: the kitchen, the isometric camera, the manager, the
## level's roster of NPCs, customers and orders, and the UI, and routes the
## interact key.

## Employees join gradually as the campaign advances.
const ROSTERS := {
	1: ["irritable", "lazy", "clean_freak"],
	2: ["irritable", "lazy", "clean_freak", "chatty"],
	3: ["irritable", "lazy", "clean_freak", "chatty", "overachiever"],
}
const NAMES := {
	"lazy": "Sam", "irritable": "Avery", "clean_freak": "Jo",
	"chatty": "Riley", "overachiever": "Kit",
}
const MANAGER_START := Vector2i(6, 4)
## Where the roster stands at the start of a shift, in a row going +x: open
## floor away from every station.
const NPC_SPAWN := Vector2i(7, 6)

@export_range(1, 3) var level := 1
## Use the Debug brain (forcing actions from the overlay) instead of Utility.
@export var debug_brains := true
## Negative keeps the standalone prototype's unlimited customer stream.
@export var customer_limit := -1
@export var revenue_target := 0

var kitchen: Kitchen
var orders: OrderSystem
var manager: Manager
var camera: Camera3D
var npcs: Array = []
var panel: InteractPanel
var overlay: DebugOverlay
var money_label: Label
var combo: ComboMeter

var _prompted: NPC


func _ready() -> void:
	_build_environment()
	kitchen = Kitchen.new()
	kitchen.name = "Kitchen"
	add_child(kitchen)

	manager = Manager.new()
	manager.name = "Manager"
	add_child(manager)
	manager.global_position = kitchen.tile_to_world(MANAGER_START)

	orders = OrderSystem.new()
	orders.name = "Orders"
	orders.kitchen = kitchen
	orders.crew = npcs
	orders.level = level
	orders.customer_limit = customer_limit
	add_child(orders)

	_build_camera()
	_spawn_roster()
	_build_ui()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.17, 0.19, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.83, 0.95)
	env.ambient_light_energy = 0.35
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	add_child(sun)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = Balance.CAMERA_SIZE
	camera.rotation_degrees = Vector3(Balance.CAMERA_PITCH_DEG, Balance.CAMERA_YAW_DEG, 0)
	camera.far = 100.0
	add_child(camera)
	manager.camera_yaw = camera.rotation.y
	camera.global_position = _camera_target()


func _camera_target() -> Vector3:
	# Keep the whole kitchen framed, leaning toward wherever the manager is.
	var focus := kitchen.center().lerp(manager.global_position, 0.35)
	return focus + camera.global_basis.z * Balance.CAMERA_DISTANCE


func _spawn_roster() -> void:
	var ids: Array = ROSTERS[level]
	for i in ids.size():
		var personality: Personality = load("res://data/personalities/%s.tres" % ids[i])
		var npc := NPC.new()
		npc.setup(NAMES[ids[i]], personality)
		npc.kitchen = kitchen
		npc.orders = orders
		npc.manager = manager
		npc.crew = npcs
		npc.brain = DebugBrain.new() if debug_brains else UtilityBrain.new()
		npc.fallback = UtilityBrain.new()
		npc.add_child(npc.brain)
		npc.add_child(npc.fallback)
		npcs.append(npc)
		add_child(npc)
		npc.global_position = kitchen.tile_to_world(NPC_SPAWN + Vector2i(i, 0))
	for npc: NPC in npcs:
		for other: NPC in npcs:
			if other == npc:
				continue
			var key := "%s -> %s" % [npc.personality.display_name, other.personality.display_name]
			npc.opinions[other.npc_name] = Balance.OPINION_NEUTRAL + Balance.STARTING_OPINION_OFFSETS.get(key, 0.0)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = InteractPanel.new()
	panel.manager = manager
	panel.kitchen = kitchen
	layer.add_child(panel)
	overlay = DebugOverlay.new()
	overlay.npcs = npcs
	layer.add_child(overlay)
	var help := Label.new()
	help.text = "WASD / arrows: move    E / Space: interact    1-4: verbs    Esc: close    F3: debug"
	help.add_theme_font_size_override("font_size", 13)
	help.modulate = Color(1, 1, 1, 0.7)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(help)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 28)
	money_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	money_label.add_theme_constant_override("outline_size", 8)
	money_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	money_label.position = Vector2(16, 10)
	layer.add_child(money_label)
	_on_earnings_changed(orders.earnings)
	orders.earnings_changed.connect(_on_earnings_changed)
	combo = ComboMeter.new()
	combo.orders = orders
	layer.add_child(combo)
	orders.order_served.connect(combo.on_order_served)


func _on_earnings_changed(total: float) -> void:
	money_label.text = "$%d" % roundi(total)
	if revenue_target > 0:
		money_label.text = "Level %d  |  Revenue: $%.2f\nTarget: $%d" % [level, total, revenue_target]


func _process(delta: float) -> void:
	camera.global_position = camera.global_position.lerp(_camera_target(), clampf(Balance.CAMERA_FOLLOW * delta, 0, 1))
	for npc: NPC in npcs:
		npc.set_manager_in_range(npc.distance_to(manager) <= Balance.MANAGER_RADIUS)
	var target := nearest_interactable()
	if target != _prompted:
		if _prompted:
			_prompted.set_prompt_visible(false)
		_prompted = target
	if _prompted:
		_prompted.set_prompt_visible(not panel.is_open_for(_prompted))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()


## The interact key: open the panel on the nearest NPC, or close it.
func interact() -> void:
	var target := nearest_interactable()
	if target == null or panel.is_open_for(target):
		panel.close()
		return
	panel.close()
	if target.on_interact():
		panel.open(target)


func nearest_interactable() -> NPC:
	var best: NPC = null
	var best_d := Balance.INTERACT_RANGE
	for npc: NPC in npcs:
		var d := npc.distance_to(manager)
		if d <= best_d:
			best = npc
			best_d = d
	return best
