extends Node
## Campaign shell. Only this menu/HUD processes while the SceneTree is paused;
## each kitchen shift explicitly uses PROCESS_MODE_PAUSABLE.

const SHIFT := preload("res://scenes/main.tscn")
const LEVEL_NAMES := ["Learn the Kitchen", "Find Your Rhythm", "The Dinner Rush"]
const LEVEL_HINTS := [
	"Assign a counter worker and cooks. Watch Sam, and give tired staff a break.",
	"Keep orders moving. Riley likes to chat, so watch for interruptions.",
	"Reach the higher target. Keep all cooking stations covered and give tired staff a break.",
]
const INTRO_NAMES := {1: ["Avery", "Sam", "Jo"], 2: ["Riley"], 3: ["Kit"]}
const INTRO_TEXT := {
	"Avery": "Avery is irritable. Avoid hovering and frequent reassignments. Watch for arguments with coworkers.",
	"Sam": "Sam is lazy. He works harder when you are nearby and may slack off when you leave. Keep an eye on him.",
	"Jo": "Jo is a clean freak. She prefers Cleaning, but finishes assigned jobs before switching back. Put her to work where needed.",
	"Riley": "Riley is chatty. She may pull coworkers into conversations and delay service. Step in when work gets interrupted.",
	"Kit": "Kit is an overachiever. She works fast and never refuses orders, but burns energy quickly. Give her a break before she crashes.",
}

var shift: Node3D
## Optional development mode; campaign gameplay keeps the configured AI.
@export var debug_brains := false
var level := 1
var customer_count := Balance.FIRST_LEVEL_CUSTOMERS
var next_count := Balance.FIRST_LEVEL_CUSTOMERS
var state := "menu"

var _hud: Control
var _status: Label
var _pause_button: Button
var _modal: ColorRect
var _content: VBoxContainer
var _instructions_back: Button
var _start_button: Button
var _pulse_time := 0.0
var _intro: Control
var _intro_title: Label
var _intro_text: Label
var _intro_continue: Button
var _intro_index := 0
var _intro_characters := 0.0
var _intro_returning := false
var _intro_camera_position := Vector3.ZERO
var _intro_camera_size := 0.0
var _intro_tween: Tween
var music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.name = "BackgroundMusic"
	var track := preload("res://assets/audio/background.mp3").duplicate() as AudioStreamMP3
	track.loop = true
	music.stream = track
	music.volume_db = -18.0
	add_child(music)
	_build_ui()
	show_main_menu()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	_status = Label.new()
	_status.position = Vector2(16, 92)
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_status)
	_pause_button = _button("Pause", pause_game)
	_pause_button.custom_minimum_size = Vector2(120, 44)
	_hud.add_child(_pause_button)
	_pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.offset_left = -136
	_pause_button.offset_right = -16
	_pause_button.offset_top = 16
	_pause_button.offset_bottom = 60
	_modal = ColorRect.new()
	_modal.color = Color(0.035, 0.05, 0.085, 0.96)
	layer.add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.105, 0.16)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(32)
	style.set_border_width_all(2)
	style.border_color = Color(0.28, 0.40, 0.55)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 18)
	card.add_child(_content)
	_instructions_back = _button("Back to Main Menu", show_main_menu)
	_modal.add_child(_instructions_back)
	_instructions_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_instructions_back.offset_left = -246
	_instructions_back.offset_right = -16
	_instructions_back.offset_top = 16
	_instructions_back.offset_bottom = 62
	_instructions_back.hide()
	_build_intro(layer)


func _build_intro(layer: CanvasLayer) -> void:
	_intro = Control.new()
	layer.add_child(_intro)
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	var card := PanelContainer.new()
	_intro.add_child(card)
	card.anchor_left = 0.15
	card.anchor_right = 0.85
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_top = -215
	card.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(18)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	_intro_title = Label.new()
	_intro_title.add_theme_font_size_override("font_size", 23)
	_intro_title.add_theme_color_override("font_color", Color(0.08, 0.13, 0.22))
	box.add_child(_intro_title)
	_intro_text = Label.new()
	_intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_intro_text.add_theme_font_size_override("font_size", 19)
	_intro_text.add_theme_color_override("font_color", Color(0.16, 0.20, 0.28))
	box.add_child(_intro_text)
	_intro_continue = _button("Continue", advance_intro)
	_intro_continue.size_flags_horizontal = Control.SIZE_SHRINK_END
	_intro_continue.custom_minimum_size.x = 180
	_style_menu_button(_intro_continue)
	box.add_child(_intro_continue)
	_intro.hide()


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _text(text: String, font_size := 19, color := Color(0.87, 0.91, 0.96)) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 530
	_content.add_child(label)


func _clear_modal() -> void:
	_start_button = null
	_instructions_back.hide()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_modal.show()


func _discard_shift() -> void:
	music.stop()
	if _intro_tween:
		_intro_tween.kill()
	_intro.hide()
	if is_instance_valid(shift):
		remove_child(shift)
		shift.queue_free()
	shift = null


func show_main_menu() -> void:
	_discard_shift()
	get_tree().paused = false
	state = "menu"
	level = 1
	customer_count = Balance.FIRST_LEVEL_CUSTOMERS
	next_count = customer_count
	_hud.hide()
	_clear_modal()
	_text("KITCHEN MANAGEMENT", 34, Color(1.0, 0.82, 0.40))
	_text("Can you turn a chaotic crew into a five-star kitchen?", 19)
	var instructions := _button("Instructions", show_instructions)
	_style_menu_button(instructions)
	_content.add_child(instructions)
	_start_button = _button("Start Game", start_game)
	_style_menu_button(_start_button)
	_content.add_child(_start_button)
	_pulse_time = 0.0


func _style_menu_button(button: Button) -> void:
	var colors := {
		"normal": Color("168bff"),
		"hover": Color("39a3ff"),
		"pressed": Color("0872db"),
	}
	for button_state: String in colors:
		var style := StyleBoxFlat.new()
		style.bg_color = colors[button_state]
		style.set_corner_radius_all(10)
		style.set_content_margin_all(12)
		button.add_theme_stylebox_override(button_state, style)
	for button_state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(button_state, Color.WHITE)


func show_instructions() -> void:
	if state != "menu":
		return
	state = "instructions"
	_clear_modal()
	_text("HOW TO PLAY", 32, Color(1.0, 0.82, 0.40))
	_text("You are the manager. Your employees cook and serve.\nMove with WASD / Arrow Keys. Press E / Space near an employee to talk. Press Esc to close their panel.", 18)
	_text("1 - Assign: Choose a station for an employee.\n2 - Praise: Improve mood and your relationship.\n3 - Scold: Boost speed briefly, at a cost to mood and trust.\n4 - Break: Send tired staff to rest. Staff may refuse orders.", 18)
	_text("Keep the counter staffed to take orders, carry tickets and serve dishes. Cover the grill, fryer and prep stations.\nWatch personality, energy and relationships: Sam slacks when unwatched, Riley chats, Avery dislikes hovering, and Kit can crash from exhaustion. Seated breaks restore energy.", 18)
	_text("Meet the revenue target shown at the top left. Tips reward faster service; consecutive serves build combo bonuses. Customers leave when their patience runs out.\nServe at least 85% to attract more customers next level. Results appear after everyone leaves. Use Pause at the top right to resume later or return to the main menu.", 18)
	_instructions_back.show()


func start_game() -> void:
	if state != "menu":
		return
	level = 1
	customer_count = Balance.FIRST_LEVEL_CUSTOMERS
	_start_level()


func _start_level() -> void:
	_discard_shift()
	get_tree().paused = false
	shift = SHIFT.instantiate()
	shift.process_mode = Node.PROCESS_MODE_PAUSABLE
	shift.level = level
	shift.debug_brains = debug_brains
	shift.customer_limit = customer_count
	shift.revenue_target = Balance.LEVEL_TARGETS[level - 1]
	add_child(shift)
	state = "playing"
	_modal.hide()
	_hud.show()
	_pause_button.show()
	_refresh_hud()
	music.stream_paused = true
	music.play(0.0)
	_begin_intro()


func _begin_intro() -> void:
	state = "intro"
	music.stream_paused = true
	get_tree().paused = true
	_pause_button.hide()
	_intro_index = 0
	_intro_returning = false
	_intro_camera_position = shift.camera.global_position
	_intro_camera_size = shift.camera.size
	_intro.show()
	_show_intro_npc()


func _show_intro_npc() -> void:
	var names: Array = INTRO_NAMES[level]
	var npc_name: String = names[_intro_index]
	for npc: NPC in shift.npcs:
		if npc.npc_name != npc_name:
			continue
		_intro_title.text = "%s — %s  (%d / %d)" % [npc_name, npc.personality.display_name, _intro_index + 1, names.size()]
		_intro_text.text = INTRO_TEXT[npc_name]
		_intro_text.visible_characters = 0
		_intro_characters = 0.0
		_intro_continue.disabled = false
		_intro_continue.text = "Continue"
		_focus_camera(npc.global_position + Vector3(0, 0.7, 0) + shift.camera.global_basis.z * Balance.CAMERA_DISTANCE, 6.0)
		break


func _focus_camera(position: Vector3, size: float) -> void:
	if _intro_tween:
		_intro_tween.kill()
	_intro_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_intro_tween.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(shift.camera, "global_position", position, 0.6)
	_intro_tween.tween_property(shift.camera, "size", size, 0.6)


func advance_intro() -> void:
	if state != "intro" or _intro_returning:
		return
	if _intro_text.visible_characters < _intro_text.text.length():
		_intro_text.visible_characters = _intro_text.text.length()
		_intro_characters = float(_intro_text.text.length())
		return
	_intro_index += 1
	if _intro_index < INTRO_NAMES[level].size():
		_show_intro_npc()
		return
	_intro_returning = true
	_intro_continue.disabled = true
	_focus_camera(_intro_camera_position, _intro_camera_size)
	_intro_tween.chain().tween_callback(_finish_intro)


func _finish_intro() -> void:
	if state != "intro" or not is_instance_valid(shift):
		return
	_intro.hide()
	state = "playing"
	get_tree().paused = false
	music.stream_paused = false
	_pause_button.show()


func _process(_delta: float) -> void:
	if state == "intro":
		if not _intro_returning:
			_intro_characters += _delta * 40.0
			_intro_text.visible_characters = mini(int(_intro_characters), _intro_text.text.length())
		return
	if state == "settling":
		if shift.combo._state != "settling":
			_show_level_result()
		return
	if state == "menu" and is_instance_valid(_start_button):
		_pulse_time += _delta
		_start_button.pivot_offset = _start_button.size * 0.5
		_start_button.scale = Vector2.ONE * (1.0 + 0.03 * sin(_pulse_time * TAU / 2.0))
		return
	if state != "playing" or not is_instance_valid(shift):
		return
	_refresh_hud()
	if shift.orders.all_customers_gone():
		finish_level()


func _refresh_hud() -> void:
	var orders: OrderSystem = shift.orders
	var seconds := int(orders.elapsed)
	_status.text = "Served: %d / %d  |  Arrived: %d / %d  |  Time: %d:%02d\n%s\n%s" % [
		orders.completed_count, customer_count, orders.spawned_count, customer_count,
		seconds / 60, seconds % 60, LEVEL_NAMES[level - 1], LEVEL_HINTS[level - 1]]


func pause_game() -> void:
	if state != "playing":
		return
	state = "paused"
	music.stream_paused = true
	get_tree().paused = true
	_pause_button.hide()
	_clear_modal()
	_text("GAME PAUSED", 34)
	_text("Take a breather. The kitchen will wait for you.\nCustomers, staff and the shift clock are paused.")
	_content.add_child(_button("Resume Game", resume_game))
	_content.add_child(_button("Return to Main Menu", show_main_menu))


func resume_game() -> void:
	if state != "paused":
		return
	state = "playing"
	music.stream_paused = false
	get_tree().paused = false
	_modal.hide()
	_pause_button.show()


func finish_level() -> void:
	if state != "playing" or not shift.orders.all_customers_gone():
		return
	shift.combo.settle_pending_bonus()
	if shift.combo._state == "settling":
		state = "settling"
		_pause_button.hide()
		return
	_show_level_result()


func _show_level_result() -> void:
	var orders: OrderSystem = shift.orders
	var passed := orders.earnings >= float(Balance.LEVEL_TARGETS[level - 1])
	next_count = Balance.next_customer_count(customer_count, orders.completed_count)
	state = "passed" if passed else "failed"
	music.stream_paused = true
	shift.panel.close()
	shift.overlay.hide()
	get_tree().paused = true
	_pause_button.hide()
	_clear_modal()
	_text("LEVEL %d COMPLETE!" % level if passed else "LEVEL %d FAILED" % level,
		34, Color(0.45, 0.95, 0.65) if passed else Color(1.0, 0.55, 0.45))
	_text("Revenue: $%.2f  /  Target: $%d\nOrders completed: %d / %d (%.1f%%)" % [
		orders.earnings, Balance.LEVEL_TARGETS[level - 1], orders.completed_count,
		customer_count, 100.0 * float(orders.completed_count) / float(customer_count)])
	if passed:
		if level < Balance.LEVEL_TARGETS.size():
			_text("You met the revenue target. Great work, manager!")
			_text("At least 85%% served! Next level: %d customers." % next_count
				if next_count > customer_count else "Next level: %d customers. Reach 85%% served to grow demand." % next_count)
			_content.add_child(_button("Next Level", next_level))
		else:
			_text("ALL THREE LEVELS COMPLETE!\nYou kept the kitchen running through the dinner rush.")
	else:
		_text("The shift is over, but the revenue target was not met.\nTry again: keep the counter staffed, cover cooking stations,\nand take care of your team's energy and morale.")
	_content.add_child(_button("Return to Main Menu", show_main_menu))


func next_level() -> void:
	if state != "passed" or level >= Balance.LEVEL_TARGETS.size():
		return
	level += 1
	customer_count = next_count
	_start_level()


func _unhandled_input(event: InputEvent) -> void:
	if state == "intro" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			advance_intro()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			show_main_menu()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if state == "paused":
			resume_game()
		elif state == "instructions":
			show_main_menu()
		elif state == "playing" and not shift.panel.visible:
			pause_game()
		else:
			return
		get_viewport().set_input_as_handled()
