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

var shift: Node3D
var level := 1
var customer_count := Balance.FIRST_LEVEL_CUSTOMERS
var next_count := Balance.FIRST_LEVEL_CUSTOMERS
var state := "menu"

var _hud: Control
var _status: Label
var _pause_button: Button
var _modal: ColorRect
var _content: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_modal.show()


func _discard_shift() -> void:
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
	_text("Three shifts. One kitchen. A team with a mind of its own.")
	_text("Meet each revenue target to advance.\nServe at least 85% of customers to attract more in the next level.")
	_text("WASD / Arrow Keys: Move\nE / Space: Talk to staff\n1-4: Assign / Praise / Scold / Break", 17)
	_text("Tip: You manage the team; your employees cook and serve.\nAssign the counter first, then cover the cooking stations.", 17)
	_content.add_child(_button("Start Game", start_game))


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
	shift.debug_brains = false
	shift.customer_limit = customer_count
	shift.revenue_target = Balance.LEVEL_TARGETS[level - 1]
	add_child(shift)
	state = "playing"
	_modal.hide()
	_hud.show()
	_pause_button.show()
	_refresh_hud()


func _process(_delta: float) -> void:
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
	get_tree().paused = false
	_modal.hide()
	_pause_button.show()


func finish_level() -> void:
	if state != "playing" or not shift.orders.all_customers_gone():
		return
	shift.combo.settle_pending_bonus()
	var orders: OrderSystem = shift.orders
	var passed := orders.earnings >= float(Balance.LEVEL_TARGETS[level - 1])
	next_count = Balance.next_customer_count(customer_count, orders.completed_count)
	state = "passed" if passed else "failed"
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if state == "paused":
			resume_game()
		elif state == "playing" and not shift.panel.visible:
			pause_game()
		else:
			return
		get_viewport().set_input_as_handled()
