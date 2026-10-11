class_name NPC
extends Node3D
## One employee and their state machine. Owns the numbers, which actions are
## legal right now, and how each action plays out. Never chooses: the Brain
## does. See docs/npc-state-and-actions.md and docs/brain-contract.md.

signal changed

## Overhead text per state, until real art replaces it (docs/telegraphs.md).
const BUBBLES := {
	"slack": "zzz",
	"refuse": "NO!",
	"switch": "-->",
	"chat": "blah",
	"fight": "#@!",
	"break": "[cup]",
	"crash": "@_@",
	"windup:slack": "*yawn*",
	"windup:switch": "?->",
	"windup:chat": "o/",
	"windup:fight": ">:(",
	"windup:break": "phew..",
	"praised": "<3",
	"scolded": ";;",
}
const MOOD_FACES := [">:(", ":(", ":|", ":)", ":D"]
const MOOD_COLORS := [
	Color(0.90, 0.20, 0.20), Color(0.95, 0.55, 0.20), Color(0.95, 0.85, 0.25),
	Color(0.60, 0.85, 0.30), Color(0.25, 0.85, 0.35),
]
## Actions that run on a timer and ignore decision requests until done.
const TIMED := ["chat", "fight", "break", "crash"]

var npc_name := ""
var personality: Personality

# --- State (0–100) -----------------------------------------------------------
var mood := Balance.MOOD_START
var energy := 100.0
var opinion_of_manager := Balance.OPINION_NEUTRAL
var opinions := {}  # coworker name -> opinion of them

## The standing role, or null.
var station: Station = null
## Current action: work, slack, switch, chat, fight, break or crash.
var action := "slack"
## Target of the current action: a station id or a coworker's name.
var action_target := ""
## Full action id of a wind-up in progress (e.g. "fight:Sam"), or "".
var windup := ""
var events: Array[Dictionary] = []
## The ticket or dish in this NPC's hands, or null.
var carrying: Order = null
## Counter job in progress: "", take_order, deliver_ticket, fetch_dish, serve.
var job := ""

# --- Wiring (set by main) ------------------------------------------------------
var kitchen: Kitchen
var orders: OrderSystem
var manager: Manager
var crew: Array = []  # every NPC, this one included
var brain: Brain
var fallback: Brain

# --- Bookkeeping ---------------------------------------------------------------
var manager_in_range := false
var hover_time := 0.0
var verb_cooldown := 0.0
var scold_burst := 0.0
var _scold_pending := 0.0  # multiplier of the drop applied when the burst ends
var _now := 0.0
var _windup_time := 0.0
var _windup_from := ""  # action to return to if the wind-up is cancelled
var _action_time := 0.0
var _refuse_time := 0.0
var _event_bubble := ""
var _event_bubble_time := 0.0
var _verb_history := {}  # verb -> Array of times
var _reassign_times: Array[float] = []
var _chat_pulled: Array[Dictionary] = []  # {time, name}
var _fight_cooldowns := {}  # coworker name -> seconds left
var _nearby := {}  # coworker names within one tile last frame
var _tick := 0.0
var _request_id := 0
var _pending := -1
var _pending_age := 0.0
var _pending_snapshot := {}
var _asked_fallback := false
var _order := ""  # ordered action awaiting accept/refuse: "work" or "break"
var _order_station: Station = null
var _break_need_seen := false
var _path := PackedVector3Array()
var _path_index := 0
var _goal_tile := Vector2i(-1, -1)
var _last_mood_tier := -1
var _job_station: Station = null
var _job_progress := 0.0

var model: CharacterModel
var _mood_label: Label3D
var _bubble_label: Label3D
var _prompt_label: Label3D

static var _next_request_id := 1


func setup(p_name: String, p_personality: Personality) -> void:
	npc_name = p_name
	personality = p_personality
	name = p_name


func _ready() -> void:
	model = CharacterModel.new()
	add_child(model)
	model.setup(personality.model_path, personality.color)
	_mood_label = _make_label(64, 1.45)
	_bubble_label = _make_label(48, 1.8)
	_prompt_label = _make_label(40, 2.15)
	_prompt_label.text = "[E]"
	_prompt_label.visible = false
	_tick = randf() * Balance.DECISION_TICK
	brain.decided.connect(_on_decided.bind(false))
	fallback.decided.connect(_on_decided.bind(true))
	_update_overhead()


# --- Queries -------------------------------------------------------------------

func coworkers() -> Array:
	return crew.filter(func(n: NPC) -> bool: return n != self)


func find_coworker(coworker_name: String) -> NPC:
	for n: NPC in crew:
		if n.npc_name == coworker_name:
			return n
	return null


func distance_to(other: Node3D) -> float:
	return Kitchen.tile_distance(global_position, other.global_position)


func is_in_windup() -> bool:
	return windup != ""


func is_busy() -> bool:
	return action in TIMED or is_in_windup() or _order != ""


## True when standing at the assigned station.
func is_at_station() -> bool:
	return station != null and kitchen.world_to_tile(global_position) == station.work_tile and _path.is_empty()


## Work with nothing to do: not slacking, just standing ready.
func is_waiting() -> bool:
	return action == "work" and is_at_station() and not _has_work()


func _has_work() -> bool:
	if station == null:
		return false
	if station.is_cook():
		return station.current_ticket() != null
	if station.station_id == "counter":
		return carrying != null or job != "" or orders.has_counter_work()
	return false  # cleaning: spills are not built yet


## Doing the job right now (not waiting): what drains energy.
func is_working_now() -> bool:
	if action != "work" or station == null:
		return false
	if station.is_cook():
		return is_at_station() and station.current_ticket() != null
	return job != ""


func mood_tier() -> int:
	var tier := 0
	for bound: float in Balance.MOOD_TIER_BOUNDS:
		if mood >= bound:
			tier += 1
	return tier


func work_speed() -> float:
	var energy_factor := 0.5 + 0.5 * energy / 100.0
	var mood_factor := 0.75 + 0.5 * mood / 100.0
	var bonus := 1.0 + (Balance.SCOLD_SPEED_BONUS if scold_burst > 0.0 else 0.0)
	return Balance.BASE_WORK_SPEED * energy_factor * mood_factor * personality.work_speed * bonus


## Every action currently allowed, fully specified with its target.
func legal_actions() -> Array[String]:
	var legal: Array[String] = []
	if _order != "":
		legal.append(_order)
		if not personality.has_trait("never_refuses"):
			legal.append("refuse")
		return legal
	if station != null and energy > 0.0:
		legal.append("work")
	legal.append("slack")
	for id: String in Station.IDS:
		var s: Station = kitchen.stations[id]
		if s != station and s.is_free():
			legal.append("switch:" + id)
	for other: NPC in coworkers():
		if distance_to(other) > Balance.ADJACENT_RANGE:
			continue
		if _can_chat_with(other):
			legal.append("chat:" + other.npc_name)
		if _can_fight_with(other):
			legal.append("fight:" + other.npc_name)
	legal.append("break")
	return legal


func _can_chat_with(other: NPC) -> bool:
	return not (action == "fight" or other.action in ["fight", "crash"] or is_in_windup() or other.is_in_windup())


func _can_fight_with(other: NPC) -> bool:
	return _fight_cooldowns.get(other.npc_name, 0.0) <= 0.0 and other.action != "crash"


## The one sentence stating the most pressing need (docs/interactions.md).
func talk_line() -> String:
	if energy < Balance.TALK_ENERGY_LOW:
		return "I need a break."
	var low := _extreme_opinion(true)
	if low != "" and opinions[low] < Balance.TALK_COWORKER_MAD:
		return "I'm mad at %s." % low
	if personality.has_trait("hates_hovering") and hover_time > Balance.HOVER_TIME:
		return "Stop hovering."
	if _recent(_reassign_times, Balance.REASSIGN_WINDOW) >= Balance.REASSIGN_OFTEN:
		return "Stop moving me around."
	if opinion_of_manager < Balance.TALK_MANAGER_MAD:
		return "I'm mad at you."
	# 6: "This place is a mess." needs spills, which are not built yet.
	for entry in _chat_pulled:
		if _now - entry.time < Balance.CHAT_PULLED_WINDOW:
			return "%s won't stop talking." % entry.name
	if is_waiting():
		return "I've got nothing to do."
	var high := _extreme_opinion(false)
	if high != "" and opinions[high] > Balance.TALK_COWORKER_LIKE:
		return "I like working with %s." % high
	return "I'm fine."


func _extreme_opinion(lowest: bool) -> String:
	var best := ""
	var best_value := 0.0
	for other: NPC in coworkers():
		var o: float = opinions.get(other.npc_name, Balance.OPINION_NEUTRAL)
		if best == "" or (o < best_value if lowest else o > best_value):
			best = other.npc_name
			best_value = o
	return best


# --- Snapshot and decisions -----------------------------------------------------

func snapshot() -> Dictionary:
	var co := []
	for other: NPC in coworkers():
		co.append({
			"name": other.npc_name,
			"personality": other.personality.display_name,
			"distance_tiles": roundi(distance_to(other)),
			"action": other.action,
			"my_opinion_of_them": roundi(opinions.get(other.npc_name, Balance.OPINION_NEUTRAL)),
			"their_opinion_of_me": roundi(other.opinions.get(npc_name, Balance.OPINION_NEUTRAL)),
		})
	var recent := []
	for e in events:
		var entry := {"type": e.type, "seconds_ago": roundi(_now - e.time)}
		if e.has("name"):
			entry.name = e.name
		recent.append(entry)
	return {
		"schema_version": Brain.SCHEMA_VERSION,
		"request_id": _request_id,
		"npc": {
			"name": npc_name,
			"personality": personality.display_name,
			"personality_description": personality.description,
			"mood": roundi(mood),
			"energy": roundi(energy),
			"opinion_of_manager": roundi(opinion_of_manager),
			"station": station.station_id if station else "",
			"action": action,
		},
		"manager": {
			"in_range": manager_in_range,
			"distance_tiles": roundi(distance_to(manager)),
		},
		"coworkers": co,
		"recent_events": recent,
		"legal_actions": legal_actions(),
	}


## Asks the brain for a decision. Ignored while a timed action, a wind-up or
## a crash is running, unless it is answering a manager's order.
func request_decision() -> void:
	if action == "crash":
		return
	if _order == "" and is_busy():
		return
	_request_id = _next_request_id
	_next_request_id += 1
	_pending = _request_id
	_pending_age = 0.0
	_asked_fallback = false
	_pending_snapshot = snapshot()
	brain.request_decision(_pending_snapshot)


func _on_decided(request_id: int, action_id: String, from_fallback: bool) -> void:
	if request_id != _pending:
		return  # stale: a newer request was sent
	if from_fallback != _asked_fallback:
		return  # the primary answered after we already moved on to the fallback
	if not action_id in legal_actions():
		if not from_fallback:
			_ask_fallback()
		else:
			_pending = -1
		return
	_pending = -1
	_apply(action_id)


func _ask_fallback() -> void:
	_asked_fallback = true
	_pending_age = 0.0
	fallback.request_decision(_pending_snapshot)


func _apply(action_id: String) -> void:
	if _order != "":
		_answer_order(action_id)
		return
	var parts := action_id.split(":")
	var verb := parts[0]
	var target := parts[1] if parts.size() > 1 else ""
	if verb == action and target == action_target:
		return
	if verb == "work":
		_begin("work")  # going back to the job needs no wind-up
	else:
		_start_windup(action_id)


func _start_windup(action_id: String) -> void:
	windup = action_id
	_windup_time = Balance.WINDUP_DURATION
	_windup_from = action
	_stop_walking()
	changed.emit()


func cancel_windup() -> void:
	windup = ""
	_windup_time = 0.0
	_begin(_windup_from if _windup_from != "" else "slack", action_target)


func _finish_windup() -> void:
	var action_id := windup
	windup = ""
	var parts := action_id.split(":")
	if not action_id in legal_actions():
		_begin(_windup_from, action_target)  # the moment passed
		return
	_begin(parts[0], parts[1] if parts.size() > 1 else "")


# --- Playing actions out ---------------------------------------------------------

func _begin(verb: String, target := "") -> void:
	action = verb
	action_target = target
	_stop_walking()
	match verb:
		"work":
			if station:
				_walk_to(station.work_tile)
		"slack":
			pass
		"switch":
			var s: Station = kitchen.stations[target]
			_take_station(s)
			_walk_to(s.work_tile)
		"chat":
			var i_was_idle := _windup_from in ["slack", "break"] or station == null
			_action_time = Balance.CHAT_DURATION
			mood = clampf(mood + Balance.CHAT_MOOD_GAIN, 0, 100)
			log_event("chatted_with", target)
			find_coworker(target)._pulled_into_chat(self, i_was_idle)
		"fight":
			_start_fight(find_coworker(target))
		"break":
			_action_time = Balance.BREAK_DURATION
			_walk_to(_pick_break_tile())
		"crash":
			_action_time = Balance.BREAK_DURATION * Balance.CRASH_BREAK_MULTIPLIER
			model.play("die")
	changed.emit()


func _pulled_into_chat(by: NPC, by_was_idle: bool) -> void:
	var was_busy := action == "work" and is_at_station()
	var was_idle := action in ["slack", "break"] or station == null
	if was_busy:
		_change_opinion(by.npc_name, -Balance.OPINION_CHAT_BUSY_DROP)
		_chat_pulled.append({"time": _now, "name": by.npc_name})
	elif was_idle and by_was_idle:
		_change_opinion(by.npc_name, Balance.OPINION_CHAT_IDLE_GAIN)
		by._change_opinion(npc_name, Balance.OPINION_CHAT_IDLE_GAIN)
	windup = ""
	action = "chat"
	action_target = by.npc_name
	_action_time = Balance.CHAT_DURATION
	_stop_walking()
	mood = clampf(mood + Balance.CHAT_MOOD_GAIN, 0, 100)
	log_event("chatted_with", by.npc_name)
	changed.emit()


func _start_fight(other: NPC) -> void:
	for pair: Array in [[self, other], [other, self]]:
		var a: NPC = pair[0]
		var b: NPC = pair[1]
		if a.is_in_windup():
			a.windup = ""
		a.action = "fight"
		a.action_target = b.npc_name
		a._action_time = Balance.FIGHT_DURATION
		a._stop_walking()
		a._change_opinion(b.npc_name, -Balance.FIGHT_OPINION_DROP)
		a._fight_cooldowns[b.npc_name] = Balance.FIGHT_PAIR_COOLDOWN
		a.changed.emit()
	for n: NPC in crew:
		if n == self or n == other:
			continue
		if n.distance_to(self) <= Balance.FIGHT_NEARBY_RANGE:
			n.mood = clampf(n.mood - Balance.FIGHT_NEARBY_MOOD_LOSS, 0, 100)
			n.log_event("fight_nearby")


## Ends a fight early for both fighters (the manager stepped in).
func end_fight() -> void:
	var other := find_coworker(action_target)
	_end_timed()
	if other and other.action == "fight":
		other._end_timed()


## A timed action is over: stand by and let the brain pick what is next.
func _end_timed() -> void:
	_action_time = 0.0
	action = "slack"
	action_target = ""
	_stop_walking()
	changed.emit()
	request_decision()


func _take_station(s: Station) -> void:
	if station == s:
		return
	if station:
		_leave_role()
		station.set_occupant(null)
	if s.occupant and s.occupant != self:
		var bumped: NPC = s.occupant
		bumped._leave_role()
		bumped.station = null
		if bumped.action == "work":
			bumped.action = "slack"
		bumped.changed.emit()
	station = s
	s.set_occupant(self)


func _pick_break_tile() -> Vector2i:
	var best := kitchen.break_tiles[0]
	var best_count := INF
	for t in kitchen.break_tiles:
		var count := 0
		for n: NPC in crew:
			if n != self and n.action == "break" and n._goal_tile == t:
				count += 1
		if count < best_count:
			best = t
			best_count = count
	return best


# --- Manager verbs -----------------------------------------------------------------

## What happens when the manager presses interact next to this NPC.
## Returns true if the interact panel should open.
func on_interact() -> bool:
	if action == "crash":
		return false
	if action == "fight":
		end_fight()
		return false
	if is_in_windup():
		cancel_windup()
	_break_need_seen = talk_line() == "I need a break."
	return true


## The panel closed. Seeing "I need a break" and not granting one costs opinion.
func on_panel_closed() -> void:
	if _break_need_seen and action != "break" and _order != "break":
		opinion_of_manager = clampf(opinion_of_manager - Balance.OPINION_BREAK_DENIED_DROP, 0, 100)
	_break_need_seen = false


## Praise, Scold and Break: per-NPC cooldown (docs/interactions.md).
func can_take_verb() -> bool:
	return verb_cooldown <= 0.0 and can_take_order()


func can_take_order() -> bool:
	return _order == "" and action != "crash"


## Assign has no cooldown; its cost is counting as a reassignment.
func order_assign(s: Station) -> void:
	if s == station or not can_take_order():
		return
	log_event("reassigned" if station else "assigned")
	_order = "work"
	_order_station = s
	_give_order()


func praise() -> void:
	if not can_take_verb():
		return
	var mult := _repeat_factor("praise") * personality.praise_multiplier
	mood = clampf(mood + Balance.PRAISE_MOOD_GAIN * mult, 0, 100)
	opinion_of_manager = clampf(opinion_of_manager + Balance.PRAISE_OPINION_GAIN * mult, 0, 100)
	_after_verb("praised")


func scold() -> void:
	if not can_take_verb():
		return
	_scold_pending += _repeat_factor("scold") * personality.scold_multiplier
	scold_burst = Balance.SCOLD_BURST_DURATION
	_after_verb("scolded")


func order_break() -> void:
	if not can_take_verb() or action == "break":
		return
	log_event("sent_on_break")
	verb_cooldown = Balance.VERB_COOLDOWN
	_order = "break"
	_give_order()


func _give_order() -> void:
	if is_in_windup():
		windup = ""
	if personality.has_trait("never_refuses"):
		_answer_order(_order)
	else:
		request_decision()
	changed.emit()


func _answer_order(action_id: String) -> void:
	var ordered := _order
	_order = ""
	if action_id == "refuse":
		_refuse_time = Balance.REFUSE_SHOW_TIME
		_order_station = null
		changed.emit()
		return
	if ordered == "work":
		if station:
			_reassign_times.append(_now)
			opinion_of_manager = clampf(opinion_of_manager - Balance.OPINION_REASSIGN_DROP, 0, 100)
		_take_station(_order_station)
		_order_station = null
		if action in TIMED:
			_action_time = 0.0
		_begin("work")
	elif ordered == "break":
		if energy < Balance.TALK_ENERGY_LOW:
			opinion_of_manager = clampf(opinion_of_manager + Balance.OPINION_BREAK_GRANTED_GAIN, 0, 100)
		_begin("break")


func _after_verb(event_type: String) -> void:
	verb_cooldown = Balance.VERB_COOLDOWN
	_flash(event_type)
	log_event(event_type)
	changed.emit()


func _repeat_factor(verb: String) -> float:
	var times: Array = _verb_history.get(verb, [])
	times = times.filter(func(t: float) -> bool: return _now - t < Balance.VERB_REPEAT_WINDOW)
	var factor := pow(Balance.VERB_REPEAT_FALLOFF, times.size())
	times.append(_now)
	_verb_history[verb] = times
	return factor


# --- Events and opinions -------------------------------------------------------------

func log_event(event_type: String, other_name := "") -> void:
	var e := {"type": event_type, "time": _now}
	if other_name != "":
		e.name = other_name
	events.append(e)
	while events.size() > Balance.EVENT_LOG_SIZE:
		events.pop_front()


func set_manager_in_range(in_range: bool) -> void:
	if in_range == manager_in_range:
		return
	manager_in_range = in_range
	if not in_range:
		hover_time = 0.0
	log_event("manager_entered_range" if in_range else "manager_left_range")
	request_decision()


func _change_opinion(other_name: String, amount: float) -> void:
	opinions[other_name] = clampf(opinions.get(other_name, Balance.OPINION_NEUTRAL) + amount, 0, 100)


func _recent(times: Array[float], window: float) -> int:
	var count := 0
	for t in times:
		if _now - t < window:
			count += 1
	return count


# --- Frame update ------------------------------------------------------------------

func _process(delta: float) -> void:
	_now += delta
	verb_cooldown = maxf(0.0, verb_cooldown - delta)
	for k in _fight_cooldowns.keys():
		_fight_cooldowns[k] = maxf(0.0, _fight_cooldowns[k] - delta)
	_update_scold(delta)
	_update_brain_timeout(delta)
	_update_state(delta)
	_update_action(delta)
	_check_passers_by()
	_tick -= delta
	if _tick <= 0.0:
		_tick = Balance.DECISION_TICK
		request_decision()
	_update_overhead()


func _update_scold(delta: float) -> void:
	if scold_burst <= 0.0:
		return
	scold_burst -= delta
	if scold_burst <= 0.0:
		mood = clampf(mood - Balance.SCOLD_MOOD_DROP * _scold_pending, 0, 100)
		opinion_of_manager = clampf(opinion_of_manager - Balance.SCOLD_OPINION_DROP * _scold_pending, 0, 100)
		_scold_pending = 0.0


func _update_brain_timeout(delta: float) -> void:
	if _pending < 0:
		return
	_pending_age += delta
	if _pending_age > Balance.BRAIN_TIMEOUT:
		if not _asked_fallback:
			_ask_fallback()
		else:
			_pending = -1


func _update_state(delta: float) -> void:
	if manager_in_range:
		hover_time += delta
		if personality.has_trait("hates_hovering") and hover_time > Balance.HOVER_TIME:
			opinion_of_manager = clampf(opinion_of_manager - Balance.OPINION_HOVER_DROP * delta, 0, 100)
	# Drift toward neutral.
	opinion_of_manager = move_toward(opinion_of_manager, Balance.OPINION_NEUTRAL, Balance.OPINION_DRIFT * delta)
	for k in opinions.keys():
		opinions[k] = move_toward(opinions[k], Balance.OPINION_NEUTRAL, Balance.OPINION_DRIFT * delta)
	mood = move_toward(mood, Balance.MOOD_START, Balance.MOOD_DRIFT * delta)
	if energy < Balance.TALK_ENERGY_LOW:
		mood = maxf(0.0, mood - Balance.MOOD_LOSS_LOW_ENERGY * delta)
	# Bad moods spread to coworkers working nearby; slackers annoy workers.
	if action == "work" and is_at_station():
		for other: NPC in coworkers():
			var d := distance_to(other)
			if other.mood < Balance.MOOD_SPREAD_BELOW and d <= Balance.MOOD_SPREAD_RANGE:
				mood = maxf(0.0, mood - Balance.MOOD_SPREAD_RATE * delta)
			if other.action == "slack" and d <= Balance.ADJACENT_RANGE:
				_change_opinion(other.npc_name, -Balance.OPINION_SLACKER_DROP * delta)


func _update_action(delta: float) -> void:
	model.position.y = 0.0  # raised again below while seated on a break chair
	if carrying and carrying.is_cancelled():
		_drop_cancelled()
	if _refuse_time > 0.0:
		_refuse_time -= delta
		model.play("emote-no")
		return
	if is_in_windup():
		_windup_time -= delta
		_face_windup_target()
		model.play("idle")
		if _windup_time <= 0.0:
			_finish_windup()
		return
	if is_working_now():
		energy = maxf(0.0, energy - Balance.ENERGY_DRAIN_WORK * personality.energy_drain * work_speed() * delta)
		if energy <= 0.0:
			_on_energy_zero()
			return
	if _walk(delta):
		return
	match action:
		"work", "switch":
			if action == "switch" and is_at_station():
				action = "work"
				changed.emit()
			if action == "work" and station:
				_update_work(delta)
			else:
				model.play("idle")
		"slack":
			model.play("idle", 0.6)
		"chat", "fight":
			var other := find_coworker(action_target)
			if other:
				model.face_point(other.global_position)
			model.play("idle" if action == "chat" else "attack-melee-right", 1.0 if action == "chat" else 0.6)
			_count_down(delta)
		"break":
			if kitchen.break_tables.has(_goal_tile):
				model.face_point(kitchen.tile_to_world(kitchen.break_tables[_goal_tile]))
				model.position.y = Kitchen.BREAK_SEAT_HEIGHT
			model.play("sit")
			energy = minf(100.0, energy + Balance.ENERGY_RESTORE_BREAK * delta)
			_count_down(delta)
		"crash":
			energy = minf(100.0, energy + Balance.ENERGY_RESTORE_BREAK * delta / Balance.CRASH_BREAK_MULTIPLIER)
			_count_down(delta)


func _count_down(delta: float) -> void:
	_action_time -= delta
	if _action_time <= 0.0:
		_end_timed()


func _on_energy_zero() -> void:
	if personality.has_trait("crash_at_zero_energy"):
		windup = ""
		_begin("crash")
	else:
		action = "slack"
		changed.emit()
		request_decision()


func _face_windup_target() -> void:
	var parts := windup.split(":")
	if parts.size() < 2:
		return
	if parts[0] == "switch":
		model.face_point(kitchen.stations[parts[1]].global_position)
	else:
		var other := find_coworker(parts[1])
		if other:
			model.face_point(other.global_position)


func _check_passers_by() -> void:
	var now_near := {}
	var someone_new := false
	for other: NPC in coworkers():
		if distance_to(other) <= Balance.ADJACENT_RANGE:
			now_near[other.npc_name] = true
			if not _nearby.has(other.npc_name):
				someone_new = true
	_nearby = now_near
	if someone_new:
		request_decision()


# --- Work ------------------------------------------------------------------------------
# Work is what a station's role does: cooks cook tickets into dishes; the
# counter takes orders, carries each ticket to its cook station, and carries
# each dish back to the customer (docs/stations-and-orders.md).

func _update_work(delta: float) -> void:
	if station.station_id == "counter":
		_update_counter(delta)
		return
	if not _go_to(station.work_tile):
		return
	model.face_point(station.global_position)
	if station.is_cook() and station.current_ticket() != null:
		model.play("interact-right", work_speed())
		var cook_time: float = Balance.COOK_TIME[station.station_id]
		station.cook(work_speed() * delta / cook_time)
	else:
		model.play("idle")  # waiting


func _update_counter(delta: float) -> void:
	var counter := station
	if job == "":
		_pick_counter_job()
	match job:
		"":
			if _go_to(counter.work_tile):
				model.face_point(counter.global_position)
				model.play("idle")  # waiting
		"take_order":
			if not _go_to(counter.work_tile):
				return
			if orders.front_customer() == null:
				_clear_job()
				return
			model.face_point(counter.global_position)
			model.play("interact-right", work_speed())
			_job_progress += work_speed() * delta / Balance.ORDER_TAKE_TIME
			if _job_progress >= 1.0:
				_hold(orders.take_order())
				_start_carrying_job()
		"deliver_ticket":
			if not _go_to(_job_station.handoff_tile):
				return
			_job_station.add_ticket(carrying)
			carrying = null
			_clear_job()
		"fetch_dish":
			if not _go_to(_job_station.handoff_tile):
				return
			_hold(_job_station.take_dish())
			if carrying:
				_start_carrying_job()
			else:
				_clear_job()
		"serve":
			if not _go_to(counter.work_tile):
				return
			model.face_point(counter.global_position)
			orders.serve(carrying)
			carrying = null
			_clear_job()


## Serving waiting customers comes first, then delivering tickets, then
## taking new orders.
func _pick_counter_job() -> void:
	var counter := station
	if carrying:
		_start_carrying_job()
	elif counter.has_dish():
		_hold(counter.take_dish())
		_start_carrying_job()
	elif orders.ready_dish():
		job = "fetch_dish"
		_job_station = kitchen.stations[orders.ready_dish().station_id]
	elif counter.current_ticket():
		_hold(counter.take_ticket())
		_start_carrying_job()
	elif orders.front_customer():
		job = "take_order"
		_job_progress = 0.0


func _start_carrying_job() -> void:
	if carrying == null:
		_clear_job()
		return
	job = "serve" if carrying.state == Order.State.DISH else "deliver_ticket"
	_job_station = kitchen.stations[carrying.station_id]


## The customer walked out: the ticket or dish in hands is thrown away and
## the errand stops.
func _drop_cancelled() -> void:
	carrying = null
	_clear_job()
	if action == "work":
		_stop_walking()


func _clear_job() -> void:
	job = ""
	_job_station = null
	_job_progress = 0.0


func _hold(order: Order) -> void:
	carrying = order
	if order:
		order.place(model, Vector3(0, 0.62, 0.32))


## Losing a role: whatever is in hands is left on the counter for the next
## counter NPC.
func _leave_role() -> void:
	if carrying:
		var counter: Station = kitchen.stations.counter
		if carrying.state == Order.State.DISH:
			counter.add_dish(carrying)
		else:
			counter.add_ticket(carrying)
		carrying = null
	_clear_job()


## Walks toward a tile. Returns true once standing on it.
func _go_to(t: Vector2i) -> bool:
	if kitchen.world_to_tile(global_position) == t and _path.is_empty():
		return true
	if _goal_tile != t or _path.is_empty():
		_walk_to(t)
	model.play("idle")
	return false


# --- Walking -------------------------------------------------------------------------

func _walk_to(t: Vector2i) -> void:
	_goal_tile = t
	_path = kitchen.find_path(global_position, t)
	_path_index = 0


func _stop_walking() -> void:
	_path = PackedVector3Array()
	_path_index = 0
	_goal_tile = Vector2i(-1, -1)


## Moves along the current path. Returns true while still walking.
func _walk(delta: float) -> bool:
	if _path_index >= _path.size():
		if not _path.is_empty():
			_path = PackedVector3Array()
		return false
	var target := _path[_path_index]
	var to := target - global_position
	to.y = 0
	var step := Balance.NPC_WALK_SPEED * Balance.TILE_SIZE * delta
	if to.length() <= step:
		global_position = Vector3(target.x, global_position.y, target.z)
		_path_index += 1
	else:
		global_position += to.normalized() * step
	model.face(to)
	model.play("walk")
	return true


# --- Telegraphs --------------------------------------------------------------------------

func set_prompt_visible(v: bool) -> void:
	_prompt_label.visible = v


func _flash(event_type: String) -> void:
	_event_bubble = BUBBLES.get(event_type, "")
	_event_bubble_time = 1.5


func bubble_text() -> String:
	if _refuse_time > 0.0:
		return BUBBLES.refuse
	if _event_bubble_time > 0.0:
		return _event_bubble
	if is_in_windup():
		return BUBBLES.get("windup:" + windup.split(":")[0], "")
	return BUBBLES.get(action, "")


func _update_overhead() -> void:
	var tier := mood_tier()
	_mood_label.text = MOOD_FACES[tier]
	_mood_label.modulate = MOOD_COLORS[tier]
	if tier != _last_mood_tier:
		if _last_mood_tier != -1:
			var tween := create_tween()
			_mood_label.scale = Vector3.ONE * 1.6
			tween.tween_property(_mood_label, "scale", Vector3.ONE, 0.3)
		_last_mood_tier = tier
	_event_bubble_time = maxf(0.0, _event_bubble_time - get_process_delta_time())
	_bubble_label.text = bubble_text()
	_bubble_label.modulate = Color(1, 0.5, 0.2) if is_in_windup() else Color.WHITE


func _make_label(font_size: int, height: float) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.outline_size = 12
	label.pixel_size = 0.006
	label.no_depth_test = true
	label.position.y = height
	add_child(label)
	return label
