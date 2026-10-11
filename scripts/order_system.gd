class_name OrderSystem
extends Node3D
## Customers and money. Customers arrive, queue at the counter, order, wait
## for their dish and pay, or walk out when their patience runs out. The
## work in between (taking orders, carrying tickets and dishes, cooking) is
## done by NPCs; see the Work section of scripts/npc.gd.
## See docs/stations-and-orders.md.

signal earnings_changed(total: float)

## Customers waiting to order stand in a line along the counter row, front
## first; customers who have ordered wait for their dish to the left.
const LINE_DIRECTION := Vector2i(1, 0)
const PICKUP_DIRECTION := Vector2i(-1, 0)
const SPAWN_TILE := Vector2i(16, 8)
const EXIT_TILE := Vector2i(-3, 9)

var kitchen: Kitchen
var crew: Array = []
var level := 1
## When false, no new customers arrive (tests and debugging).
var spawning := true

var earnings := 0.0
var line: Array[Customer] = []  # waiting to order, front first
var waiting: Array[Customer] = []  # ordered, waiting for their dish
var rng := RandomNumberGenerator.new()

var _spawn_timer := Balance.FIRST_CUSTOMER_DELAY


func _process(delta: float) -> void:
	if spawning:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _next_interval()
			if line.size() < Balance.MAX_QUEUE:
				spawn_customer()
	for c in line + waiting:
		if c.patience <= 0.0:
			_walk_out(c)


# --- Customers ----------------------------------------------------------------

func spawn_customer() -> Customer:
	var c := Customer.new()
	add_child(c)
	c.global_position = kitchen.tile_to_world(SPAWN_TILE)
	line.append(c)
	_arrange()
	return c


## The customer at the front of the line, once they have reached the counter.
func front_customer() -> Customer:
	if line.is_empty() or not line[0].is_at_target():
		return null
	return line[0]


## The counter NPC takes the front customer's order. Returns the new ticket.
func take_order(station_id := "") -> Order:
	var c := front_customer()
	if c == null:
		return null
	if station_id == "":
		station_id = Station.COOK_IDS[rng.randi() % Station.COOK_IDS.size()]
	line.pop_front()
	c.order = Order.new(station_id, c)
	waiting.append(c)
	_arrange()
	return c.order


## The counter NPC hands over a dish. Returns what the customer paid.
func serve(order: Order) -> float:
	if order == null or order.is_cancelled() or not is_instance_valid(order.customer):
		return 0.0
	var c := order.customer
	var paid := Balance.ORDER_BASE_PRICE + Balance.ORDER_MAX_TIP * c.patience_share()
	earnings += paid
	order.state = Order.State.SERVED
	order.place(c.model, Vector3(0, 0.6, 0.3))
	waiting.erase(c)
	c.leave(kitchen.tile_to_world(EXIT_TILE), true)
	_arrange()
	_coin(paid)
	_log_all("order_completed")
	earnings_changed.emit(earnings)
	return paid


func _walk_out(c: Customer) -> void:
	line.erase(c)
	waiting.erase(c)
	if c.order:
		c.order.cancel()
	c.leave(kitchen.tile_to_world(EXIT_TILE), false)
	_arrange()
	_log_all("customer_walked_out")


# --- Queries for the counter NPC ----------------------------------------------

## A cooked dish whose customer is still waiting, or null.
func ready_dish() -> Order:
	for id in Station.COOK_IDS:
		var s: Station = kitchen.stations[id]
		if s.has_dish():
			return s.dishes[0]
	return null


func has_counter_work() -> bool:
	var counter: Station = kitchen.stations.counter
	return front_customer() != null or ready_dish() != null \
		or counter.current_ticket() != null or counter.has_dish()


# --- Helpers -----------------------------------------------------------------------

func _arrange() -> void:
	var front: Vector2i = kitchen.stations.counter.tile + Vector2i(0, 1)
	for i in line.size():
		line[i].walk_to(kitchen.tile_to_world(front + LINE_DIRECTION * i))
	for i in waiting.size():
		waiting[i].walk_to(kitchen.tile_to_world(front + Vector2i(0, 1) + PICKUP_DIRECTION * (i + 1)))


func _next_interval() -> float:
	var base: float = Balance.CUSTOMER_INTERVAL[clampi(level, 1, Balance.CUSTOMER_INTERVAL.size()) - 1]
	var jitter := Balance.CUSTOMER_INTERVAL_JITTER
	return base * rng.randf_range(1.0 - jitter, 1.0 + jitter)


func _log_all(event_type: String) -> void:
	for npc: NPC in crew:
		npc.log_event(event_type)


## "Order paid: coin over the counter" (docs/telegraphs.md).
func _coin(amount: float) -> void:
	var label := Label3D.new()
	label.text = "+$%d" % roundi(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.outline_size = 12
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.85, 0.2)
	label.no_depth_test = true
	add_child(label)
	label.global_position = kitchen.stations.counter.global_position + Vector3(0, 1.0, 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 0.8, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)
