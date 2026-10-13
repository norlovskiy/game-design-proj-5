extends SceneTree
## Let all scheduled customers arrive and leave naturally, with no service.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 100.0
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for index in 3:
		game.level = index + 1
		game.customer_count = Balance.FIRST_LEVEL_CUSTOMERS + index * Balance.CUSTOMER_COUNT_INCREASE
		game._start_level()
		var orders: OrderSystem = game.shift.orders
		var last_arrival: float = Balance.FIRST_CUSTOMER_DELAY + (game.customer_count - 1) * Balance.CUSTOMER_INTERVAL * (1.0 - Balance.CUSTOMER_INTERVAL_JITTER)
		var deadline: float = last_arrival + game.customer_count * Balance.CUSTOMER_PATIENCE
		while game.state == "playing" and orders.elapsed < deadline:
			await create_timer(0.5, true).timeout
		var ok: bool = game.state == "failed" and orders.spawned_count == game.customer_count \
			and orders.completed_count == 0 and orders.elapsed >= last_arrival
		print("%s Level %d: %d customers, %.1fs, state=%s" % [
			"PASS" if ok else "FAIL", index + 1, orders.spawned_count, orders.elapsed, game.state])
		if not ok:
			failures += 1
	game.show_main_menu()
	game.queue_free()
	await process_frame
	print("Campaign pacing: %d failure(s)" % failures)
	quit(1 if failures else 0)
