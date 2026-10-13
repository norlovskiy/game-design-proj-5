class_name ComboMeter
extends Control
## Vertical combo meter on the right of the window. A served order fills it
## and starts a level; another serve before it empties raises the level.
## When it empties, the level's bonus is paid and the meter cools down.

const METER_SIZE := Vector2(64, 320)
const BAR_WIDTH := 28.0
const BAR_TOP := 42.0
const FRAME := 3.0
const CORNER := 10.0
const SETTLE_TIME := 0.45
const SETTLE_SCALE := 1.35
const LABEL_POS := Vector2(0, 2)
const REWARD_SOUNDS := {
	2: preload("res://assets/audio/2.mp3"),
	3: preload("res://assets/audio/3.mp3"),
	4: preload("res://assets/audio/4.mp3"),
	5: preload("res://assets/audio/5.mp3"),
	6: preload("res://assets/audio/6.mp3"),
}

var orders: OrderSystem

var _label: Label
var _level := 1
var _fill := 0.0
var _color := Balance.COMBO_COLOR_START
var _shake := Vector2.ZERO
## idle, running, settling, cooldown
var _state := "idle"
var _timer := 0.0
var reward_audio: AudioStreamPlayer


func _ready() -> void:
	reward_audio = AudioStreamPlayer.new()
	reward_audio.name = "ComboRewardSound"
	# Let a final combo sound finish even when the result screen pauses the shift.
	reward_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	reward_audio.volume_db = -3.0
	add_child(reward_audio)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = METER_SIZE
	size = METER_SIZE
	_label = Label.new()
	_label.position = LABEL_POS
	_label.size = Vector2(METER_SIZE.x, 34)
	_label.pivot_offset = Vector2(METER_SIZE.x * 0.5, 17)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	_label.visible = false
	add_child(_label)
	_place()
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	position = Vector2(vp.x - 18.0 - METER_SIZE.x, (vp.y - METER_SIZE.y) * 0.5)
	size = METER_SIZE


func on_order_served() -> void:
	if _state == "settling" or _state == "cooldown":
		return
	if _state == "idle":
		_level = 1
	else:
		_level = mini(_level + 1, Balance.COMBO_LEVELS)
	_fill = 1.0
	_state = "running"
	_color = Balance.combo_color(_level)
	_label.text = "+%d" % Balance.combo_reward(_level)
	_label.add_theme_color_override("font_color", _color)
	_label.visible = true
	_label.scale = Vector2.ONE
	_label.position = LABEL_POS
	queue_redraw()


func _process(delta: float) -> void:
	match _state:
		"running":
			_fill = maxf(0.0, _fill - delta / Balance.combo_drain_time(_level))
			if _fill <= 0.0:
				_shake = Vector2.ZERO
				_label.position = LABEL_POS
				_begin_settle()
			else:
				_shake = _shake_offset()
				_label.position = LABEL_POS + _shake
			queue_redraw()
		"settling":
			_shake = Vector2.ZERO
			_label.position = LABEL_POS
			_timer += delta
			var t := clampf(_timer / 0.22, 0.0, 1.0)
			t = 1.0 - pow(1.0 - t, 3.0)
			_label.scale = Vector2.ONE * lerpf(1.0, SETTLE_SCALE, t)
			if _timer >= SETTLE_TIME:
				_label.visible = false
				_label.scale = Vector2.ONE
				_state = "cooldown"
			queue_redraw()
		"cooldown":
			_timer += delta
			if _timer >= Balance.COMBO_COOLDOWN:
				_state = "idle"


func _shake_offset() -> Vector2:
	if _level < Balance.COMBO_SHAKE_FROM_LEVEL:
		return Vector2.ZERO
	var steps := _level - Balance.COMBO_SHAKE_FROM_LEVEL
	var amp := Balance.COMBO_SHAKE_BASE + float(steps) * Balance.COMBO_SHAKE_STEP
	var t := float(Time.get_ticks_msec()) * 0.001
	var offset := Vector2(
		sin(t * 52.0) * amp + sin(t * 31.0) * amp * 0.35,
		cos(t * 44.0) * amp * 0.55
	)
	return offset.limit_length(Balance.COMBO_SHAKE_MAX)


func _begin_settle() -> void:
	_state = "settling"
	_timer = 0.0
	_fill = 0.0
	_shake = Vector2.ZERO
	_label.position = LABEL_POS
	_label.scale = Vector2.ONE
	orders.add_bonus(float(Balance.combo_reward(_level)))
	if REWARD_SOUNDS.has(_level):
		reward_audio.stream = REWARD_SOUNDS[_level]
		reward_audio.play()


## Pay a still-running combo before the campaign compares final revenue.
func settle_pending_bonus() -> void:
	if _state == "running":
		_begin_settle()


func _draw() -> void:
	if _state != "running" or _fill <= 0.0:
		return
	var outer := Rect2((size.x - BAR_WIDTH) * 0.5, BAR_TOP, BAR_WIDTH, size.y - BAR_TOP - 12.0)
	outer.position += _shake
	var frame_pts := _rounded_points(outer, CORNER)
	draw_colored_polygon(frame_pts, Color(1, 1, 1, 0.08))
	var outline := frame_pts.duplicate()
	outline.append(frame_pts[0])
	draw_polyline(outline, Color.WHITE, FRAME, true)
	var inner := outer.grow(-FRAME)
	var filled_h := inner.size.y * _fill
	if filled_h <= 2.0:
		return
	var fill_rect := Rect2(inner.position.x, inner.position.y + inner.size.y - filled_h, inner.size.x, filled_h)
	var radius := minf(CORNER - FRAME, filled_h * 0.5)
	draw_colored_polygon(_rounded_points(fill_rect, radius), _color)


func _rounded_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	if r <= 0.5:
		pts.append(rect.position)
		pts.append(rect.position + Vector2(rect.size.x, 0))
		pts.append(rect.position + rect.size)
		pts.append(rect.position + Vector2(0, rect.size.y))
		return pts
	_add_arc(pts, rect.position + Vector2(rect.size.x - r, r), r, -PI * 0.5, 0.0)
	_add_arc(pts, rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, 0.0, PI * 0.5)
	_add_arc(pts, rect.position + Vector2(r, rect.size.y - r), r, PI * 0.5, PI)
	_add_arc(pts, rect.position + Vector2(r, r), r, PI, PI * 1.5)
	return pts


func _add_arc(pts: PackedVector2Array, center: Vector2, radius: float, from: float, to: float) -> void:
	var n := 6
	for i in n + 1:
		var a := lerpf(from, to, float(i) / float(n))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
