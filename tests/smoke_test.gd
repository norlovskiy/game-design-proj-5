extends SceneTree
## Headless smoke test: drives the real main scene through every manager verb
## and every forced NPC action, and checks the state machine's results.
##
## Run: godot --headless --path . -s res://tests/smoke_test.gd

var main: Node
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 4.0
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.level = 3
	main.debug_brains = true
	root.add_child(main)
	main.orders.spawning = false  # customers are tested on their own below
	await _wait(0.2)

	var sam: NPC = _npc("Sam")
	var avery: NPC = _npc("Avery")
	var jo: NPC = _npc("Jo")
	var riley: NPC = _npc("Riley")
	var kit: NPC = _npc("Kit")
	var k: Kitchen = main.kitchen

	# Snapshot schema.
	var snap := sam.snapshot()
	_check(snap.schema_version == 1, "snapshot schema_version is 1")
	for key in ["request_id", "npc", "manager", "coworkers", "recent_events", "legal_actions"]:
		_check(snap.has(key), "snapshot has " + key)
	_check(not "work" in snap.legal_actions, "work is illegal without a station")
	_check("break" in snap.legal_actions and "slack" in snap.legal_actions, "break and slack always legal")

	# Interact opens the panel; manager is within range.
	_put_manager_next_to(sam)
	await _wait(0.1)
	main.interact()
	_check(main.panel.is_open_for(sam), "interact opens the panel on the nearest NPC")
	_check(sam.manager_in_range, "NPC knows the manager is in range")
	_check(sam.talk_line() != "", "talk line is shown")

	# Assign.
	sam.order_assign(k.stations.grill)
	await _wait(0.3)
	_check(sam.station == k.stations.grill and sam.action == "work", "Assign gives a standing role and Work")
	_check(sam.events.back().type == "assigned", "assigned event logged")
	await _wait(4.0)
	_check(sam.is_at_station(), "NPC walks to its station")

	# Praise keeps the per-NPC cooldown but does not lock manager movement.
	main.panel.open(sam)
	var mood_before := sam.mood
	var opinion_before := sam.opinion_of_manager
	main.panel._on_verb("Praise")
	_check(sam.mood > mood_before and sam.opinion_of_manager > opinion_before, "Praise raises mood and opinion")
	_check(not sam.can_take_verb(), "per-NPC verb cooldown after Praise")
	_check(not main.manager.is_locked(), "manager can move after Praise")

	# Scold: speed burst now, mood and opinion drop when it ends.
	var speed := sam.work_speed()
	sam.verb_cooldown = 0.0
	main.panel._refresh()
	main.panel._on_verb("Scold")
	_check(not main.manager.is_locked(), "manager can move after Scold")
	_check(sam.work_speed() > speed, "Scold speeds up work")
	mood_before = sam.mood
	sam.scold_burst = 0.01
	await _wait(0.1)
	_check(sam.mood < mood_before, "Scold drops mood when the burst ends")

	# Assigning to a taken station swaps the other NPC off it.
	avery.order_assign(k.stations.grill)
	await _wait(0.3)
	_check(avery.station == k.stations.grill and sam.station == null, "assign to a taken station swaps the other off")

	# Refuse: forced through the Debug brain; the previous role stands.
	(avery.brain as DebugBrain).force("refuse")
	avery.order_assign(k.stations.fryer)
	await _wait(0.3)
	_check(avery.station == k.stations.grill, "Refuse keeps the previous role")
	_check(avery.bubble_text() == NPC.BUBBLES.refuse, "Refuse is telegraphed")

	# Ordered break: no wind-up, NPC leaves, energy restores.
	jo.order_assign(k.stations.prep)
	await _wait(0.3)
	jo.energy = 10.0
	main.panel.open(jo)
	main.panel._on_verb("Break")
	_check(not main.manager.is_locked(), "manager can move after ordering Break")
	await _wait(0.3)
	_check(jo.action == "break" and not jo.is_in_windup(), "ordered Break has no wind-up")
	await _wait(6.0)
	_check(jo.energy > 10.0, "energy restores on break")

	# Unordered actions go through a wind-up; interacting cancels it.
	riley.order_assign(k.stations.fryer)
	await _wait(4.0)
	(riley.brain as DebugBrain).force("slack")
	riley.request_decision()
	await _wait(0.2)
	_check(riley.windup == "slack", "unordered Slack starts with a wind-up")
	_put_manager_next_to(riley)
	await _wait(0.1)
	main.interact()
	_check(not riley.is_in_windup() and riley.action == "work", "interact cancels the wind-up")
	_check(main.panel.is_open_for(riley), "and opens the panel")
	main.panel.close()

	# Wind-up runs to completion when not interrupted.
	(riley.brain as DebugBrain).force("switch:counter")
	riley.request_decision()
	await _wait(Balance.WINDUP_DURATION + 0.5)
	_check(riley.station == k.stations.counter, "Switch station takes the new station after the wind-up")
	await _wait(5.0)
	_check(riley.is_at_station() and riley.action == "work", "and works there once arrived")

	# Chat and Fight need a coworker within one tile.
	sam.global_position = riley.global_position + Vector3(0.8, 0, 0)
	sam._stop_walking()
	await _wait(0.1)
	_check(("chat:" + riley.npc_name) in sam.legal_actions(), "chat legal with an adjacent coworker")
	(sam.brain as DebugBrain).force("chat:Riley")
	sam.request_decision()
	await _wait(Balance.WINDUP_DURATION + 0.3)
	_check(sam.action == "chat" and riley.action == "chat", "Chat stops both NPCs")
	await _wait(Balance.CHAT_DURATION + 0.5)
	_check(sam.action != "chat", "Chat ends after CHAT_DURATION")

	sam.global_position = riley.global_position + Vector3(0.8, 0, 0)
	sam._stop_walking()
	await _wait(0.1)
	var opinion: float = sam.opinions.Riley
	(sam.brain as DebugBrain).force("fight:Riley")
	sam.request_decision()
	await _wait(Balance.WINDUP_DURATION + 0.3)
	_check(sam.action == "fight" and riley.action == "fight", "Fight stops both NPCs")
	_check(sam.opinions.Riley < opinion, "Fight lowers opinion")
	_check(not ("fight:Riley" in sam.legal_actions()), "fight pair cooldown")
	_put_manager_next_to(sam)
	await _wait(0.1)
	main.interact()
	_check(sam.action != "fight" and riley.action != "fight", "interacting ends a fight for both")
	_check(not main.panel.visible, "and opens no panel")

	# Overachiever: never refuses, crashes at zero energy, cannot be interrupted.
	(kit.brain as DebugBrain).force("refuse")
	kit.order_assign(k.stations.cleaning)
	await _wait(0.3)
	_check(kit.station == k.stations.cleaning, "Overachiever never refuses")
	await _wait(5.0)
	# Energy only drains while there is real work: give Kit a ticket to cook.
	kit.order_assign(k.stations.fryer)
	k.stations.fryer.add_ticket(Order.new("fryer", null))
	await _wait(5.0)
	kit.energy = 0.2
	await _wait(0.5)
	_check(kit.action == "crash", "Overachiever crashes at zero energy")
	_put_manager_next_to(kit)
	await _wait(0.1)
	main.interact()
	_check(not main.panel.visible and kit.action == "crash", "a crash cannot be interrupted")

	# Brain timeout falls back to the fallback brain.
	var silent := Brain.new()
	jo.brain = silent
	jo.add_child(silent)
	silent.decided.connect(jo._on_decided.bind(false))
	jo._end_timed()
	await _wait(Balance.BRAIN_TIMEOUT + 1.0)
	_check(jo.action == "work", "fallback brain answers when the brain times out")

	await _test_orders()

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)


## The order pipeline, on a fresh shift: customer -> counter -> ticket ->
## cook -> dish -> counter -> customer pays; walk-outs; a dropped role.
func _test_orders() -> void:
	main.queue_free()
	await _wait(0.1)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.level = 3
	main.debug_brains = true
	root.add_child(main)
	var orders: OrderSystem = main.orders
	orders.spawning = false
	var k: Kitchen = main.kitchen
	var sam: NPC = _npc("Sam")
	var kit: NPC = _npc("Kit")
	sam.order_assign(k.stations.counter)
	_npc("Avery").order_assign(k.stations.grill)
	_npc("Jo").order_assign(k.stations.fryer)
	_npc("Riley").order_assign(k.stations.prep)
	kit.order_assign(k.stations.cleaning)
	await _wait(5.0)
	_check(sam.is_waiting(), "counter NPC waits when there are no customers")

	var c := orders.spawn_customer()
	_check(await _until(func() -> bool: return sam.job == "take_order", 15.0), "counter NPC takes the front customer's order")
	_check(await _until(func() -> bool: return sam.carrying != null, 5.0), "taking the order gives a ticket to carry")
	var ticket: Order = sam.carrying
	var cook_station: Station = k.stations[ticket.station_id]
	var cook: NPC = cook_station.occupant
	_check(await _until(func() -> bool: return cook_station.current_ticket() == ticket, 15.0), "the ticket is carried to its cook station")
	_check(await _until(func() -> bool: return cook_station.has_dish(), 20.0), "the cook cooks the ticket into a dish")
	_check(cook.energy < 100.0, "cooking drains energy")
	_check(await _until(func() -> bool: return sam.carrying == ticket and ticket.state == Order.State.DISH, 15.0), "the counter NPC fetches the dish")
	_check(await _until(func() -> bool: return orders.earnings > 0.0, 15.0), "the customer is served and pays")
	_check(orders.earnings >= Balance.ORDER_BASE_PRICE, "payment is at least the base price")
	_check(c.leaving and not c in orders.waiting, "a served customer leaves")
	_check(sam.events.any(func(e: Dictionary) -> bool: return e.type == "order_completed"), "order_completed is logged")

	# A customer whose patience runs out walks out; their ticket is thrown away.
	var earned := orders.earnings
	var angry := orders.spawn_customer()
	await _until(func() -> bool: return sam.carrying != null and sam.carrying.customer == angry, 20.0)
	var lost: Order = sam.carrying
	angry.patience = 0.0
	await _wait(0.5)
	_check(angry.leaving and lost.is_cancelled(), "a customer out of patience walks out and the order is cancelled")
	_check(sam.carrying == null, "the carried ticket is dropped")
	_check(kit.events.any(func(e: Dictionary) -> bool: return e.type == "customer_walked_out"), "customer_walked_out is logged")
	_check(orders.earnings == earned, "a walk-out earns nothing")

	# Losing the counter role mid-delivery leaves the ticket on the counter.
	orders.spawn_customer()
	await _until(func() -> bool: return sam.carrying != null, 20.0)
	var left_behind: Order = sam.carrying
	sam.order_assign(k.stations.cleaning)  # Kit is swapped off cleaning
	await _wait(0.3)
	_check(sam.carrying == null and k.stations.counter.tickets.has(left_behind), "a ticket in hand is left on the counter when the role is lost")
	kit.order_assign(k.stations.counter)
	_check(await _until(func() -> bool: return k.stations[left_behind.station_id].tickets.has(left_behind) or left_behind.state == Order.State.DISH, 20.0), "the next counter NPC delivers it")


## Waits until a condition holds, up to `timeout` game seconds.
func _until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await _wait(0.1)
		waited += 0.1
	return condition.call()


func _npc(npc_name: String) -> NPC:
	for n: NPC in main.npcs:
		if n.npc_name == npc_name:
			return n
	return null


func _put_manager_next_to(npc: NPC) -> void:
	main.manager.global_position = npc.global_position + Vector3(-0.5, 0, -0.5)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout  # game seconds, sped up by time_scale


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1
