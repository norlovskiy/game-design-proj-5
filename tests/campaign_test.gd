extends SceneTree
## Exercise the actual campaign scene, including UI button callbacks and
## paused physics/timers. Run with --headless -s res://tests/campaign_test.gd.

var game: Node
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	_check(game.state == "menu" and game.shift == null, "launch opens the main menu")
	_click("Start Game")
	_check(game.level == 1 and game.state == "playing", "Start Game enters level one")
	_check(game.shift.orders.customer_limit == 30, "first shift has thirty customers")
	_check(game.shift.money_label.text.contains("Target: $250"), "HUD shows revenue and target")
	_check(game.shift.npcs.size() == 5, "first shift uses the five-person roster")
	_check(game.shift.npcs.any(func(npc: NPC) -> bool: return npc.npc_name == "Kit"), "Kit is restored to the roster")
	var orders: OrderSystem = game.shift.orders
	_test_prototype_cadence(orders)
	orders._spawn_timer = 0.0
	await process_frame
	await process_frame
	_check(orders.spawned_count == 1, "arrival timer creates a customer")
	var customer: Customer = orders.line[0]
	_click("Pause", game._hud)
	var elapsed_before := orders.elapsed
	var patience_before := customer.patience
	var customer_position := customer.global_position
	var manager_position: Vector3 = game.shift.manager.global_position
	Input.action_press("move_right")
	await create_timer(0.15, true).timeout
	Input.action_release("move_right")
	_check(paused and game.state == "paused", "Pause opens the pause screen")
	_check(orders.elapsed == elapsed_before and customer.patience == patience_before,
		"pause freezes shift time and patience")
	_check(customer.global_position == customer_position and game.shift.manager.global_position == manager_position,
		"pause freezes customer and manager movement")
	_click("Resume Game")
	await create_timer(0.1).timeout
	_check(not paused and orders.elapsed > elapsed_before, "Resume Game restarts simulation")


	# Full queues restart the original timer without consuming the budget.
	orders._spawn_timer = 0.0
	orders.spawning = false
	while orders.line.size() < Balance.MAX_QUEUE:
		orders.spawn_customer()
	var before := orders.spawned_count
	orders.spawning = true
	orders._process(0.0)
	_check(orders.spawned_count == before and orders._spawn_timer > 0.0, "full queue restarts the timer without consuming customers")
	var departing: Customer = orders.line[0]
	orders._walk_out(departing)
	orders._process(0.0)
	_check(orders.spawned_count == before, "opening queue space does not accelerate the original timer")
	orders._process(orders._spawn_timer)
	_check(orders.spawned_count == before + 1, "next customer arrives on the next timer tick")
	orders.spawning = false

	# Order counting is independent of tips/bonuses and cannot double-serve.
	var served: Customer = orders.line[0]
	var ticket := Order.new("grill", served)
	served.order = ticket
	orders.line.erase(served)
	orders.waiting.append(served)
	ticket.become_dish()
	_check(orders.serve(ticket) >= Balance.ORDER_BASE_PRICE, "serving a dish earns revenue")
	_check(orders.completed_count == 1, "one successful order counts once")
	_check(orders.serve(ticket) == 0.0 and orders.completed_count == 1, "duplicate serve is ignored")

	_check(Balance.next_customer_count(20, 17) == 22, "exactly 85 percent increases demand")
	_check(Balance.next_customer_count(20, 16) == 20, "below 85 percent keeps demand")
	_check(Balance.next_customer_count(30, 25) == 30, "twenty-five serves keep thirty customers")
	_check(Balance.next_customer_count(30, 26) == 32, "twenty-six serves increase demand to thirty-two")

	# Do not finish until the entire finite budget has arrived AND departed.
	orders.spawned_count = 29
	_check(not orders.all_customers_gone(), "unspawned budget prevents settlement")
	orders.spawned_count = 30
	_check(not orders.all_customers_gone(), "customers walking out still prevent settlement")
	_clear_customers(orders)
	orders.completed_count = 26
	orders.earnings = 250.0
	game.finish_level()
	_check(game.state == "passed" and paused, "equal-to-target revenue passes and freezes the shift")
	_check(game.next_count == 32, "passing with twenty-six serves plans thirty-two customers")
	_click("Next Level")
	_check(game.level == 2 and not paused and game.shift.orders.customer_limit == 32,
		"Next Level opens a fresh shift with increased demand")
	_check(game.shift.orders.earnings == 0.0 and game.shift.npcs.size() == 5,
		"level two resets revenue and uses its five-person roster")
	_check(game.shift.revenue_target == 350, "level two has a higher target")
	orders = game.shift.orders
	_test_prototype_cadence(orders)
	orders.spawned_count = 32
	orders.completed_count = 25
	orders.earnings = 350.0
	game.finish_level()
	_check(game.next_count == 32, "passing below 85 percent keeps the customer budget")
	_click("Next Level")
	_check(game.level == 3 and game.shift.customer_limit == 32 and game.shift.revenue_target == 550,
		"third level retains demand and increases the target")
	orders = game.shift.orders
	_test_prototype_cadence(orders)
	_check(game.shift.npcs.size() == 5, "third level keeps five employees")
	orders.spawned_count = 32
	orders.completed_count = 25
	orders.earnings = 537.0
	game.shift.combo.on_order_served()
	game.shift.combo.on_order_served() # Level-two combo pays 13 at settlement.
	game.finish_level()
	_check(game.state == "passed" and orders.earnings == 550.0, "pending combo bonus counts before final result")
	_check(_find_button("Next Level", game._content) == null, "third level has no nonexistent next level")
	_click("Return to Main Menu")
	_check(game.state == "menu" and not paused and game.shift == null, "results return to a clean main menu")
	_click("Start Game")
	_check(game.level == 1 and game.customer_count == 30, "new campaign resets to level one and thirty customers")
	orders = game.shift.orders
	orders.spawned_count = 30
	orders.earnings = 249.99
	game.finish_level()
	_check(game.state == "failed" and paused, "revenue below target shows failure")
	_check(_find_button("Next Level", game._content) == null, "failure cannot advance")
	_click("Return to Main Menu")
	_click("Start Game")
	_click("Pause", game._hud)
	_click("Return to Main Menu")
	_check(game.state == "menu" and not paused and game.shift == null, "pause menu can return to main menu")
	game.queue_free()
	await process_frame
	print("Campaign: %d failure(s)" % failures)
	quit(1 if failures else 0)


## Fixed RNG seed verifies that changing levels never changes the prototype cadence.
func _test_prototype_cadence(orders: OrderSystem) -> void:
	orders.rng.seed = 12345
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 12345
	var ok := true
	for index in 20:
		var expected := 9.0 * expected_rng.randf_range(0.7, 1.3)
		ok = ok and is_equal_approx(orders._next_interval(), expected)
	_check(ok, "level %d uses the original prototype's randomized nine-second cadence" % orders.level)


func _clear_customers(orders: OrderSystem) -> void:
	orders.line.clear()
	orders.waiting.clear()
	for child in orders.get_children():
		if child is Customer:
			orders.remove_child(child)
			child.queue_free()


func _find_button(text: String, node: Node) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text:
			return child
		var found := _find_button(text, child)
		if found:
			return found
	return null


func _click(text: String, node: Node = null) -> void:
	var button := _find_button(text, game._content if node == null else node)
	_check(button != null, "button exists: " + text)
	if button:
		button.pressed.emit()


func _check(ok: bool, description: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + description)
	if not ok:
		failures += 1
