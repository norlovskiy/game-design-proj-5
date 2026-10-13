extends SceneTree
## Check imported files, combo timing, looping music and screen transitions.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var orders := OrderSystem.new()
	orders.spawning = false
	root.add_child(orders)
	for level in range(1, 7):
		var combo := ComboMeter.new()
		combo.orders = orders
		root.add_child(combo)
		for index in level:
			combo.on_order_served()
		_check(not combo.reward_audio.playing, "level %d does not play audio before settlement" % level)
		combo.settle_pending_bonus()
		combo._process(0.08)
		_check(combo._label.scale.x > 1.0, "level %d enlarges its reward text at settlement" % level)
		if level == 1:
			_check(not combo.reward_audio.playing, "level one has no reward sound")
		else:
			_check(combo.reward_audio.playing and combo.reward_audio.stream.resource_path.ends_with("/%d.mp3" % level),
				"level %d plays its matching MP3 at settlement" % level)
			_check(combo.reward_audio.stream.get_length() > 0.0, "level %d MP3 decodes successfully" % level)
		var earned := orders.earnings
		combo.settle_pending_bonus()
		_check(orders.earnings == earned, "level %d cannot settle twice" % level)
		combo.queue_free()
		await process_frame
	orders.queue_free()
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.debug_brains = true
	root.add_child(game)
	_check(not game.music.playing, "main menu has no background playback")
	_check(game.music.stream.loop and game.music.stream.get_length() > 0.0, "background MP3 is valid and loops")
	game.show_instructions()
	_check(not game.music.playing, "instructions have no background playback")
	game.show_main_menu()
	game.start_game()
	_check(game.music.stream_paused, "NPC introduction pauses background playback")
	await _finish_intro(game)
	await create_timer(0.2).timeout
	_check(game.music.playing and not game.music.stream_paused, "background plays during the level")
	game.pause_game()
	await process_frame
	var position: float = game.music.get_playback_position()
	await create_timer(0.15, true).timeout
	_check(game.music.stream_paused and absf(game.music.get_playback_position() - position) < 0.03,
		"pause screen freezes background playback position")
	game.resume_game()
	_check(not game.music.stream_paused, "Resume continues background playback")
	game.shift.orders.spawned_count = game.customer_count
	game.shift.orders.earnings = 250.0
	game.shift.combo.on_order_served()
	game.shift.combo.on_order_served()
	game.finish_level()
	_check(game.state == "settling" and game.shift.combo.reward_audio.playing,
		"final combo plays its sound before opening the result screen")
	await create_timer(0.55, true).timeout
	_check(game.state == "passed" and game.music.stream_paused, "victory screen pauses background playback")
	_check(game.shift.combo.reward_audio.process_mode == Node.PROCESS_MODE_ALWAYS,
		"final reward sound can finish after the result screen pauses gameplay")
	game.next_level()
	_check(game.music.stream_paused and game.music.get_playback_position() < 0.1,
		"new level resets background to the beginning and waits for its introduction")
	await _finish_intro(game)
	game.shift.orders.spawned_count = game.customer_count
	game.shift.orders.earnings = 0.0
	game.finish_level()
	_check(game.state == "failed" and game.music.stream_paused, "failure screen pauses background playback")
	game.show_main_menu()
	_check(not game.music.playing, "returning to menu silences background playback")
	game.queue_free()
	await process_frame
	print("Audio: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _finish_intro(game: Node) -> void:
	while game.state == "intro" and not game._intro_returning:
		game._intro_text.visible_characters = game._intro_text.text.length()
		game.advance_intro()
	while game.state == "intro":
		await process_frame


func _check(ok: bool, description: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + description)
	if not ok:
		failures += 1
