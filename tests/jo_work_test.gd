extends SceneTree
## Check Jo's cleaning legality for unfinished cooking and counter errands.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.level = 1
	main.debug_brains = true
	main.use_jev = false
	root.add_child(main)
	main.orders.spawning = false
	var jo: NPC
	for npc: NPC in main.npcs:
		if npc.npc_name == "Jo":
			jo = npc
	var grill: Station = main.kitchen.stations.grill
	jo._take_station(grill)
	jo._begin("work")
	grill.add_ticket(Order.new("grill", null))
	grill.cook(0.5)
	_check(not "switch:cleaning" in jo.legal_actions(), "Jo cannot abandon unfinished cooking for Cleaning")
	_check(UtilityBrain.pick(jo.snapshot()) == "work", "Utility chooses to finish Jo's assigned cooking")
	grill.add_ticket(Order.new("grill", null))
	grill.cook(0.5)
	_check(not "switch:cleaning" in jo.legal_actions(), "remaining cooking tickets still protect assigned work")
	grill.cook(1.0)
	_check("switch:cleaning" in jo.legal_actions(), "Cleaning becomes available after cooking is finished")
	for dish: Order in grill.dishes:
		dish.cancel()
	grill.dishes.clear()
	jo._take_station(main.kitchen.stations.counter)
	jo._begin("work")
	var ticket := Order.new("prep", null)
	ticket.place(jo.model, Vector3.ZERO)
	jo.carrying = ticket
	jo.job = "deliver_ticket"
	_check(not "switch:cleaning" in jo.legal_actions(), "Jo cannot abandon a carried counter ticket for Cleaning")
	ticket.cancel()
	jo.carrying = null
	jo._clear_job()
	_check("switch:cleaning" in jo.legal_actions(), "Jo may prefer Cleaning again when counter work is finished")
	main.queue_free()
	await process_frame
	print("Jo work: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, description: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + description)
	if not ok:
		failures += 1
