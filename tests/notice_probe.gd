extends Node
## TEMPORARY probe (v1.0.21 debugging #2): why doesn't pound_notice
## build? Boots the game, enters play via the story skip + pound
## escape, stages the van + cat exactly like the suite's pound
## section, then calls _pound_update_notice SYNCHRONOUSLY 60 times
## and prints every gate input via printerr (unbuffered).

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	player = main.get("player")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var dg: int = 0
	while not bool(main.call("captor_distracted")) and dg < 40:
		main.call("_process_escape", 0.25)
		dg += 1
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	await wait_sec(0.5)
	printerr("PROBE2: state=", str(main.get("state")))
	var worker: Node = main.get("pound_worker")
	worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(worker)
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
	main.set("pound_engage_cd", 0.0)
	var pvan: Node3D = main.get("pound_van")
	main.set("pound_state", "patrol")
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	(player as Node3D).global_position = pvan.position + Vector3(11.0, 0.2, 0.0)
	player.set("velocity", Vector3.ZERO)
	main.call("_pound_pin_worker")
	var bad_modes: Array = []
	for n in main.get("npcs"):
		var m: String = str(n.get("mode"))
		if m == "chase" or m == "pursue" or m == "tell":
			bad_modes.append(str(n.get("npc_type")) + ":" + m)
	printerr("PROBE2 staging: gates=", bool(main.call("_pound_gates_open")),
		" collared=", bool(main.get("player_collared")),
		" engage_cd=", float(main.get("pound_engage_cd")),
		" pursuers=", (main.get("pursuers") as Dictionary).size(),
		" bad_modes=", bad_modes,
		" hidden=", bool(player.get("is_hidden")),
		" w_cd=", float(worker.get("notice_cooldown")),
		" w_pos=", (worker as Node3D).global_position,
		" cat_pos=", (player as Node3D).global_position,
		" van_pos=", pvan.position,
		" dist=", snappedf((player as Node3D).global_position.distance_to(pvan.position), 0.1),
		" LOS=", bool(worker.call("_has_line_of_sight")),
		" sight=", float(worker.get("detect_radius")),
		" fill=", float(worker.get("fill_rate")),
		" sprinting=", bool(player.get("is_sprinting")))
	for i in range(60):
		main.call("_pound_update_notice", 0.25)
		if i % 10 == 9:
			printerr("PROBE2 step ", i + 1, ": notice=", float(main.get("pound_notice")), " w_cd=", float(worker.get("notice_cooldown")), " pstate=", str(main.get("pound_state")))
	printerr("PROBE2: done, final notice=", float(main.get("pound_notice")), " pstate=", str(main.get("pound_state")))
	get_tree().quit()
