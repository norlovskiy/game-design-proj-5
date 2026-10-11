extends SceneTree
## Renders the main scene and saves screenshots (needs a display, e.g. xvfb-run).
## Run: godot --path . -s res://tests/screenshot.gd -- <out_dir>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.level = 3
	root.add_child(main)
	await create_timer(0.5).timeout
	var k: Kitchen = main.kitchen
	var ids := ["counter", "grill", "fryer", "prep", "cleaning"]
	for i in main.npcs.size():
		main.npcs[i].order_assign(k.stations[ids[i]])
	await create_timer(6.0).timeout
	main.npcs[0].scold()
	(main.npcs[1].brain as DebugBrain).force("slack")
	main.npcs[1].request_decision()
	main.manager.global_position = main.npcs[2].global_position + Vector3(0.5, 0, 0.7)
	await create_timer(0.6).timeout
	main.interact()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/panel.png")
	main.panel.close()
	main.manager.global_position = main.kitchen.tile_to_world(Vector2i(6, 4))
	(main.npcs[3].brain as DebugBrain).force("break")
	main.npcs[3].request_decision()
	await create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/floor.png")
	await create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/break.png")
	main.overlay.visible = true
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/debug.png")
	quit()
