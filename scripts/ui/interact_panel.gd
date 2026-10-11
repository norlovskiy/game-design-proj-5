class_name InteractPanel
extends PanelContainer
## The panel opened by interacting with an NPC: talk line, energy and opinion
## sliders, coworker opinions, and the four verbs. The game does not pause
## while it is open. Mood is not shown here; it is the overhead emoji.
## See docs/interactions.md.

signal closed

var npc: NPC
var manager: Manager
var kitchen: Kitchen

var _portrait: ColorRect
var _name: Label
var _talk: Label
var _energy: ProgressBar
var _opinion: ProgressBar
var _coworkers: HBoxContainer
var _verbs: HBoxContainer
var _stations: HBoxContainer
var _verb_buttons := {}
var _station_buttons := {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.17, 0.94)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var portrait_box := VBoxContainer.new()
	head.add_child(portrait_box)
	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(56, 56)
	portrait_box.add_child(_portrait)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 12)
	portrait_box.add_child(_name)
	_talk = Label.new()
	_talk.add_theme_font_size_override("font_size", 22)
	_talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_talk)

	_energy = _slider_row(box, "Energy", Color(0.95, 0.80, 0.25))
	_opinion = _slider_row(box, "Opinion of you", Color(0.40, 0.70, 0.95))
	_coworkers = HBoxContainer.new()
	_coworkers.add_theme_constant_override("separation", 14)
	box.add_child(_coworkers)

	_verbs = HBoxContainer.new()
	_verbs.add_theme_constant_override("separation", 8)
	box.add_child(_verbs)
	var i := 1
	for verb in ["Assign", "Praise", "Scold", "Break"]:
		var b := _button("%d  %s" % [i, verb])
		b.pressed.connect(_on_verb.bind(verb))
		_verbs.add_child(b)
		_verb_buttons[verb] = b
		i += 1

	_stations = HBoxContainer.new()
	_stations.add_theme_constant_override("separation", 6)
	_stations.visible = false
	box.add_child(_stations)
	i = 1
	for id: String in Station.IDS:
		var b := _button("")
		b.pressed.connect(_on_station.bind(id))
		_stations.add_child(b)
		_station_buttons[id] = b
		i += 1
	var back := _button("Esc  Back")
	back.pressed.connect(_show_stations.bind(false))
	_stations.add_child(back)


func open(target: NPC) -> void:
	npc = target
	_show_stations(false)
	_portrait.color = npc.personality.color
	_name.text = npc.npc_name
	_rebuild_coworkers()
	visible = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	if npc and is_instance_valid(npc):
		npc.on_panel_closed()
	npc = null
	closed.emit()


func is_open_for(target: NPC) -> bool:
	return visible and npc == target


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(npc) or npc.distance_to(manager) > Balance.INTERACT_RANGE + 1.0 \
			or npc.action in ["fight", "crash"]:
		close()
		return
	_refresh()
	# Bottom centre of the screen.
	reset_size()
	var screen := get_viewport_rect().size
	position = Vector2((screen.x - size.x) / 2.0, screen.y - size.y - 16.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		if _stations.visible:
			_show_stations(false)
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	var n := key - KEY_1
	if n < 0 or n > 4:
		return
	if _stations.visible:
		_on_station(Station.IDS[n])
	elif n < 4:
		_on_verb(["Assign", "Praise", "Scold", "Break"][n])
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	_talk.text = "\"%s\"" % npc.talk_line()
	_energy.value = npc.energy
	_opinion.value = npc.opinion_of_manager
	for child in _coworkers.get_children():
		var other: NPC = child.get_meta("npc")
		(child.get_node("Bar") as ProgressBar).value = npc.opinions.get(other.npc_name, Balance.OPINION_NEUTRAL)
	var locked := manager.is_locked()
	var verb_ok := npc.can_take_verb() and not locked
	_verb_buttons.Assign.disabled = not npc.can_take_order() or locked
	for verb in ["Praise", "Scold", "Break"]:
		_verb_buttons[verb].disabled = not verb_ok
	_verb_buttons.Break.disabled = _verb_buttons.Break.disabled or npc.action == "break"
	var i := 1
	for id: String in Station.IDS:
		var s: Station = kitchen.stations[id]
		var b: Button = _station_buttons[id]
		var label := "%d  %s" % [i, s.display_name()]
		if s == npc.station:
			label += " (here)"
		elif not s.is_free():
			label += " (%s)" % s.occupant.npc_name  # taken: assigning swaps them off
		b.text = label
		b.disabled = s == npc.station
		i += 1


func _on_verb(verb: String) -> void:
	if _verb_buttons[verb].disabled:
		return
	match verb:
		"Assign":
			_show_stations(true)
		"Praise":
			npc.praise()
			manager.lock(Balance.VERB_LOCK)
		"Scold":
			npc.scold()
			manager.lock(Balance.VERB_LOCK)
		"Break":
			npc.order_break()
			manager.lock(Balance.VERB_LOCK)


func _on_station(id: String) -> void:
	if not _stations.visible or _station_buttons[id].disabled:
		return
	npc.order_assign(kitchen.stations[id])
	_show_stations(false)


func _show_stations(show: bool) -> void:
	_stations.visible = show
	_verbs.visible = not show


func _rebuild_coworkers() -> void:
	for child in _coworkers.get_children():
		child.queue_free()
	for other: NPC in npc.coworkers():
		var col := VBoxContainer.new()
		col.set_meta("npc", other)
		var face := ColorRect.new()
		face.color = other.personality.color
		face.custom_minimum_size = Vector2(28, 28)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(face)
		var label := Label.new()
		label.text = other.npc_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		col.add_child(label)
		var bar := _bar(Color(0.40, 0.70, 0.95))
		bar.name = "Bar"
		bar.custom_minimum_size = Vector2(60, 8)
		col.add_child(bar)
		_coworkers.add_child(col)


func _slider_row(parent: Container, text: String, fill: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)
	var bar := _bar(fill)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 14)
	row.add_child(bar)
	return bar


func _bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep arrow keys / space for movement
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b
