extends Node
## v1.0.25 screenshot runner (v2): (a) inhabitants mid-walk on
## a street after a real dispersal, (b) house fronts clear of
## frozen standers, (c) a closed gable, (d) a town cat roaming,
## (e) the ward's open back door from INSIDE — street scene in
## the frame, not black — and (f) just after crossing out.
## NOTE: models cull beyond ~85-95 m from the player cat, so
## after the dispersal the cat is brought INTO town before the
## town shots, or nobody renders.
## Output: ~/workspace/homeward/screenshots_v1025/.

var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/homeward/screenshots_v1025/" + name + ".png")
	print("SNAP ", name)

func snap_with_cam(name: String, pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await wait_sec(0.35)
	await snap(name)

func tap(btn: Button) -> void:
	# The v1.0.24 pattern: a raw touch press + release, then the
	# emulated-mouse echo of the press. One tap = one combo step.
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
	print("SHOTV2 boot complete")
	player = main.get("player")
	cam = main.get("cam")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.3)
	(main.get("story") as Node).call("skip_opening")
	await wait_sec(0.4)
	# DISPERSAL: the cat waits at the pound slot (the field
	# condition — most of the town distance-throttled) while the
	# town lives for ~90 game-seconds.
	main.set("state", "play")
	(player as Node3D).global_position = Vector3(560, 0.3, 0)
	Engine.time_scale = 3.0
	await wait_sec(15.0)
	Engine.time_scale = 1.0
	print("SHOTV2 dispersal done")
	# Bring the cat into town so models un-cull, and clear the
	# leftover escape prompt from the forced state change.
	(player as Node3D).global_position = Vector3(6, 0.3, 26)
	var epb: Object = main.get("escape_prompt_btn")
	if epb is CanvasItem:
		(epb as CanvasItem).visible = false
	await wait_sec(2.5)
	main.set_process(false)
	await wait_sec(0.3)
	# (a) the busiest cluster of inhabitants near the cat.
	var npcs: Array = main.get("npcs")
	var best: Node3D = null
	var best_n := -1
	for n in npcs:
		var np: Vector3 = (n as Node3D).global_position
		if np.distance_to((player as Node3D).global_position) > 30.0:
			continue
		var cnt := 0
		for m in npcs:
			if m != n and (m as Node3D).global_position.distance_to(np) < 14.0:
				cnt += 1
		if cnt > best_n:
			best_n = cnt
			best = n
	var bp: Vector3 = best.global_position
	await snap_with_cam("a_street_walkers", bp + Vector3(5.5, 2.6, 5.5), bp + Vector3(0, 1.0, 0))
	# (b) Oak Avenue house fronts.
	await snap_with_cam("b_house_fronts_clear", Vector3(28, 2.2, 15.5), Vector3(28, 1.0, -2))
	# (c) a gable-roofed house's end wall.
	var houses: Array = main.get("houses")
	for h in houses:
		if (h as Dictionary).has("gable"):
			var hp: Vector3 = h["pos"]
			await snap_with_cam("c_gable_closed", hp + Vector3(10.5, 4.8, 0.5), hp + Vector3(0, 4.2, 0))
			break
	# (d) a town cat, out roaming — stand the player near it
	# first (process still stopped; move BOTH player and cam).
	var cats: Array = main.get("town_cats")
	if cats.size() > 0:
		var cp: Vector3 = (cats[0] as Node3D).global_position
		(player as Node3D).global_position = cp + Vector3(3.0, 0.3, 3.0)
		await snap_with_cam("d_town_cat_roaming", cp + Vector3(2.4, 1.2, 2.4), cp + Vector3(0, 0.3, 0))
	main.set_process(true)
	# (e) the ward: a real officer capture, DISTRACT him (the
	# suite's way — an undistracted watcher closes the panel
	# and resets the combo), then the bolt combo, then stand
	# inside and look out the open back door.
	var pworker: Node = main.get("pound_worker")
	(player as Node3D).global_position = Vector3(-40, 0.3, 16)
	(pworker as Node3D).global_position = Vector3(-41.5, 0.2, 16)
	main.call("on_cat_taken", pworker)
	await wait_sec(0.4)
	main.call("skip_cutscene")
	await wait_sec(0.6)
	print("SHOT state=", str(main.get("state")), " kinds=", str(main.call("current_escape_kinds")))
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var dguard := 0
	while not bool(main.call("captor_distracted")) and dguard < 24:
		await wait_sec(0.25)
		dguard += 1
	print("SHOT distracted=", bool(main.call("captor_distracted")))
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
	print("SHOT exit_open=", bool(main.get("exit_open")), " kind=", str(main.get("exit_open_kind")), " combo_index=", int(main.get("combo_index")))
	var o: Vector3 = main.get("escape_origin")
	main.set_process(false)
	await wait_sec(0.3)
	await snap_with_cam("e_doorway_inside_out", o + Vector3(8.6, 1.6, 3.4), o + Vector3(24, 0.9, 3.4))
	main.set_process(true)
	# (f) walk out: the crossing completes and the cat lands on
	# the depot street in town, the pursuit beginning.
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	guard = 0
	while str(main.get("state")) == "escape" and guard < 40:
		await wait_sec(0.25)
		guard += 1
	await wait_sec(0.8)
	main.set_process(false)
	await wait_sec(0.3)
	var lp: Vector3 = (player as Node3D).global_position
	await snap_with_cam("f_just_outside", lp + Vector3(4.5, 2.4, 4.5), lp + Vector3(0, 0.4, 0))
	main.set_process(true)
	print("SHOTS DONE state=", str(main.get("state")), " cat=", str(lp))
	get_tree().quit()
