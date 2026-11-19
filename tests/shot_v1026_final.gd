extends Node
## v1.0.26 FINAL screenshot runner: (b) inhabitants actually
## walking in town with the player cat IN town (the v1.0.25
## runner parked the cat at the pound slot during dispersal,
## so models were hidden in its town frames), (c) a town cat
## roaming near its home, (d) the open escape doorway from
## inside the ward — re-verifying the black plug is gone in
## THIS build. Modelled on shot_v1025.gd.
## Run: xvfb-run -a godot --path . tests/ShotV1026Final.tscn
## Output: ~/workspace/homeward/screenshots_v1026/

var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/homeward/screenshots_v1026/" + name + ".png")
	print("SNAP ", name)

func snap_with_cam(name: String, pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await wait_sec(0.35)
	await snap(name)

func tap(btn: Button) -> void:
	var r: Rect2 = btn.get_global_rect()
	var c: Vector2 = r.get_center()
	var tp := InputEventScreenTouch.new()
	tp.index = 7
	tp.position = c
	tp.pressed = true
	main.call("_input", tp)
	var mp := InputEventMouseButton.new()
	mp.button_index = MOUSE_BUTTON_LEFT
	mp.pressed = true
	mp.position = c
	main.call("_input", mp)
	var tr := InputEventScreenTouch.new()
	tr.index = 7
	tr.position = c
	tr.pressed = false
	main.call("_input", tr)
	var mr := InputEventMouseButton.new()
	mr.button_index = MOUSE_BUTTON_LEFT
	mr.pressed = false
	mr.position = c
	main.call("_input", mr)

func _ready() -> void:
	await run()

func run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(0.6)
	print("V1026FINAL boot complete")
	player = main.get("player")
	cam = main.get("cam")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.3)
	(main.get("story") as Node).call("skip_opening")
	await wait_sec(0.4)
	main.set("state", "play")
	# (b) the cat waits IN TOWN (town centre) while the town
	# disperses and walks — models stay visible near the player.
	(player as Node3D).global_position = Vector3(6, 0.3, 26)
	Engine.time_scale = 3.0
	await wait_sec(20.0)
	Engine.time_scale = 1.0
	print("V1026FINAL dispersal done")
	var epb: Object = main.get("escape_prompt_btn")
	if epb is CanvasItem:
		(epb as CanvasItem).visible = false
	await wait_sec(1.5)
	main.set_process(false)
	await wait_sec(0.3)
	var npcs: Array = main.get("npcs")
	var best: Node3D = null
	var best_n := -1
	for n in npcs:
		var np: Vector3 = (n as Node3D).global_position
		if np.distance_to((player as Node3D).global_position) > 35.0:
			continue
		var cnt := 0
		for m in npcs:
			if m != n and (m as Node3D).global_position.distance_to(np) < 14.0:
				cnt += 1
		if cnt > best_n:
			best_n = cnt
			best = n
	if best != null:
		var bp: Vector3 = best.global_position
		await snap_with_cam("town_walkers", bp + Vector3(5.5, 2.6, 5.5), bp + Vector3(0, 1.0, 0))
	else:
		print("V1026FINAL no walker cluster found near the cat")
	# (c) a town cat roaming — stand the player near it first.
	var cats: Array = main.get("town_cats")
	if cats.size() > 0:
		# pick the cat nearest its own home area action: just
		# use the first cat that is not inside a house footprint
		# (position sanity is the suite's job; here we frame it).
		var cp: Vector3 = (cats[0] as Node3D).global_position
		(player as Node3D).global_position = cp + Vector3(3.0, 0.3, 3.0)
		await snap_with_cam("town_cat_roaming", cp + Vector3(2.4, 1.2, 2.4), cp + Vector3(0, 0.3, 0))
	main.set_process(true)
	# (d) the ward: a real officer capture, distract him, run
	# the bolt combo, then stand inside and look out the open
	# back door (the plug check for THIS build).
	var pworker: Node = main.get("pound_worker")
	(player as Node3D).global_position = Vector3(-40, 0.3, 16)
	(pworker as Node3D).global_position = Vector3(-41.5, 0.2, 16)
	main.call("on_cat_taken", pworker)
	await wait_sec(0.4)
	main.call("skip_cutscene")
	await wait_sec(0.6)
	print("V1026FINAL state=", str(main.get("state")), " kinds=", str(main.call("current_escape_kinds")))
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var dguard := 0
	while not bool(main.call("captor_distracted")) and dguard < 24:
		await wait_sec(0.25)
		dguard += 1
	print("V1026FINAL distracted=", bool(main.call("captor_distracted")))
	main.call("_open_escape_panel")
	await wait_sec(0.3)
	main.set("escape_combo", ["B", "B", "A", "B", "A"])
	(main.get("escape_panel") as Control).call("set_combo_seq", ["B", "B", "A", "B", "A"])
	main.set("combo_index", 0)
	var btn_a: Button = main.get("hop_btn")
	var btn_b: Button = main.get("paw_btn")
	for letter in ["B", "B", "A", "B", "A"]:
		tap(btn_b if letter == "B" else btn_a)
		await wait_sec(0.3)
	var guard := 0
	while not bool(main.get("exit_open")) and guard < 40:
		await wait_sec(0.25)
		guard += 1
	print("V1026FINAL exit_open=", bool(main.get("exit_open")), " kind=", str(main.get("exit_open_kind")))
	var o: Vector3 = main.get("escape_origin")
	main.set_process(false)
	await wait_sec(0.3)
	await snap_with_cam("doorway_inside_out", o + Vector3(8.6, 1.6, 3.4), o + Vector3(24, 0.9, 3.4))
	main.set_process(true)
	print("V1026FINAL DONE")
	get_tree().quit()
