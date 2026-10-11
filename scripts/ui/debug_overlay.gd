class_name DebugOverlay
extends PanelContainer
## Every NPC's real numbers, current action and legal actions (toggle with
## F3). Clicking a legal action forces it through the NPC's Debug brain; it
## still goes through the state machine, wind-up included.

var npcs: Array = []

var _list: VBoxContainer
var _rows := {}  # NPC -> {label, actions, signature}


func _ready() -> void:
	visible = false
	position = Vector2(8, 8)
	modulate = Color(1, 1, 1, 0.92)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	for npc: NPC in npcs:
		if not _rows.has(npc):
			_add_row(npc)
		var row: Dictionary = _rows[npc]
		row.label.text = _describe(npc)
		var legal := npc.legal_actions()
		var signature := ",".join(legal)
		if signature != row.signature:
			row.signature = signature
			_rebuild_actions(npc, row.actions, legal)


func _describe(npc: NPC) -> String:
	var lines := PackedStringArray()
	lines.append("%s  (%s)" % [npc.npc_name, npc.personality.display_name])
	lines.append("mood %d  energy %d  opinion of manager %d" % [npc.mood, npc.energy, npc.opinion_of_manager])
	var ops := PackedStringArray()
	for k in npc.opinions:
		ops.append("%s %d" % [k, npc.opinions[k]])
	lines.append("opinions: " + ", ".join(ops))
	var doing := npc.action + (":" + npc.action_target if npc.action_target != "" else "")
	if npc.is_in_windup():
		doing = "WIND-UP -> " + npc.windup
	lines.append("station %s  action %s  in range %s" % [
		npc.station.station_id if npc.station else "-", doing, npc.manager_in_range])
	if npc.scold_burst > 0.0:
		lines.append("scold burst %.0fs" % npc.scold_burst)
	return "\n".join(lines)


func _add_row(npc: NPC) -> void:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	var actions := HFlowContainer.new()
	box.add_child(actions)
	box.add_child(HSeparator.new())
	_list.add_child(box)
	_rows[npc] = {"label": label, "actions": actions, "signature": ""}


func _rebuild_actions(npc: NPC, container: Container, legal: Array[String]) -> void:
	for child in container.get_children():
		child.queue_free()
	for action_id in legal:
		var b := Button.new()
		b.text = action_id
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_force.bind(npc, action_id))
		container.add_child(b)
	if not "refuse" in legal:
		# Refuse is only legal at the moment of an order: queue it for the next one.
		var r := Button.new()
		r.text = "refuse next order"
		r.focus_mode = Control.FOCUS_NONE
		r.add_theme_font_size_override("font_size", 11)
		r.pressed.connect(func() -> void: (npc.brain as DebugBrain).force("refuse"))
		container.add_child(r)


func _force(npc: NPC, action_id: String) -> void:
	if npc.brain is DebugBrain:
		(npc.brain as DebugBrain).force(action_id)
		npc.request_decision()
