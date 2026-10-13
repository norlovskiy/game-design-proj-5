extends SceneTree

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_lazy()
	_test_low_energy()
	_test_chatty()
	_test_irritable()
	_test_clean_freak()
	_test_overachiever()
	_test_refusal()

	print(
		"\n%s: %d utility brain failure(s)"
		% ["PASS" if failures == 0 else "FAIL", failures]
	)
	quit(1 if failures else 0)


func _test_lazy() -> void:
	var snapshot := _snapshot(
		"Lazy",
		["work", "slack", "break"]
	)

	_check(
		UtilityBrain.pick(snapshot) == "slack",
		"Lazy slacks when the manager is away"
	)

	snapshot["manager"]["in_range"] = true

	_check(
		UtilityBrain.pick(snapshot) == "work",
		"Lazy works when the manager is nearby"
	)


func _test_low_energy() -> void:
	var snapshot := _snapshot(
		"Irritable",
		["work", "slack", "break"],
		10.0
	)

	_check(
		UtilityBrain.pick(snapshot) == "break",
		"low energy favours taking a break"
	)


func _test_chatty() -> void:
	var coworker := {
		"name": "Sam",
		"personality": "Lazy",
		"distance_tiles": 1,
		"action": "work",
		"my_opinion_of_them": 50,
		"their_opinion_of_me": 50,
	}
	var snapshot := _snapshot(
		"Chatty",
		["work", "slack", "chat:Sam", "fight:Sam", "break"],
		100.0,
		60.0,
		50.0,
		false,
		"prep",
		[coworker]
	)

	_check(
		UtilityBrain.pick(snapshot) == "chat:Sam",
		"Chatty chats with a passing coworker"
	)

	snapshot["recent_events"] = [{
		"type": "chatted_with",
		"name": "Sam",
		"seconds_ago": 2,
	}]

	_check(
		UtilityBrain.pick(snapshot) == "work",
		"Chatty does not immediately repeat the same chat"
	)


func _test_irritable() -> void:
	var coworker := {
		"name": "Sam",
		"personality": "Lazy",
		"distance_tiles": 1,
		"action": "work",
		"my_opinion_of_them": 10,
		"their_opinion_of_me": 10,
	}
	var snapshot := _snapshot(
		"Irritable",
		["work", "slack", "fight:Sam", "break"],
		100.0,
		60.0,
		50.0,
		false,
		"grill",
		[coworker]
	)

	_check(
		UtilityBrain.pick(snapshot) == "fight:Sam",
		"Irritable fights when mutual opinion has deteriorated"
	)

	coworker["my_opinion_of_them"] = 50
	coworker["their_opinion_of_me"] = 50

	_check(
		UtilityBrain.pick(snapshot) == "work",
		"Irritable does not fight a neutral coworker"
	)


func _test_clean_freak() -> void:
	var snapshot := _snapshot(
		"Clean freak",
		["work", "slack", "switch:cleaning", "break"]
	)
	snapshot["recent_events"] = [{
		"type": "spill_nearby",
		"seconds_ago": 1,
	}]

	_check(
		UtilityBrain.pick(snapshot) == "switch:cleaning",
		"Clean freak switches to cleaning after noticing a spill"
	)


func _test_overachiever() -> void:
	var snapshot := _snapshot(
		"Overachiever",
		["work", "slack", "break"],
		5.0
	)

	_check(
		UtilityBrain.pick(snapshot) == "work",
		"Overachiever keeps working at dangerously low energy"
	)


func _test_refusal() -> void:
	var snapshot := _snapshot(
		"Irritable",
		["work", "refuse"]
	)
	snapshot["recent_events"] = [
		{"type": "reassigned", "seconds_ago": 3},
		{"type": "reassigned", "seconds_ago": 8},
		{"type": "reassigned", "seconds_ago": 14},
	]

	_check(
		UtilityBrain.pick(snapshot) == "refuse",
		"Irritable refuses after repeated reassignment"
	)


func _snapshot(
	personality: String,
	legal_actions: Array,
	energy := 100.0,
	mood := 60.0,
	manager_opinion := 50.0,
	manager_in_range := false,
	station := "grill",
	coworkers: Array = []
) -> Dictionary:
	return {
		"schema_version": 1,
		"request_id": 1,
		"npc": {
			"name": "Test NPC",
			"personality": personality,
			"personality_description": "",
			"mood": mood,
			"energy": energy,
			"opinion_of_manager": manager_opinion,
			"station": station,
			"action": "work",
		},
		"manager": {
			"in_range": manager_in_range,
			"distance_tiles": 2,
		},
		"coworkers": coworkers,
		"recent_events": [],
		"legal_actions": legal_actions,
	}


func _check(ok: bool, description: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + description)

	if not ok:
		failures += 1