extends Node
## ZANDER'S RUN v1.0.17 — screenshot runner for the three v1.0.17
## changes (not part of the suite):
##  1. title_panel.png — the title panel with the home address
##     REMOVED (no "collar tag says" line, no gold address) and the
##     layout rebalanced.
##  2. pound_pursuit.png — after the opening's pound escape, the
##     officer ACTIVELY pursuing in town (Fix 2): the runner prints
##     his displacement and his closing distance as proof.
##  3. house_escape.png — a regular townsperson's capture lands in
##     the HOUSE interior (Fix 1): living room, sofa + coffee table,
##     the owner in the room with the cat.
## Boots the real game and drives the real flows. PNGs land in
## ~/workspace/homeward/screenshots_v1017/.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1017/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("saved ", name, " ", img.get_size())

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	player = main.get("player")
	print("V1017: build_complete, house set=", (main.get("house_room_set") as Dictionary).size(), " shelter set=", (main.get("shelter_room_set") as Dictionary).size())

	# ---- 1: the title panel (address removed) ----
	main.call("dismiss_splash")
	await wait_sec(1.2)
	# proof: no label anywhere on the title panel carries the address
	var addr_found: bool = false
	var stack: Array = [main.get("title_panel")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var lab := n as Label
		if lab and (lab.text == str(main.get("home_address")) or lab.text.contains("collar tag says")):
			addr_found = true
	print("V1017: title panel address shown = ", addr_found, " (home_address internal = '", str(main.get("home_address")), "')")
	await snap("title_panel.png")

	# ---- 2: the opening pound escape -> the officer pursues ----
	main.call("start_game")
	await wait_sec(0.5)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.5)
	print("V1017: after skip, state=", str(main.get("state")), " captor is worker=", main.get("captor") == main.get("pound_worker"), " is_house=", bool(main.get("escape_room_is_house")), " ward=", (main.get("ward_cages") as Array).size())
	# out of the cage, the real PAW path
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	# distract him with the first prop, work the bolt, walk out
	var props: Array = main.get("distract_props")
	(player as Node3D).global_position = (props[0]["base"] as Vector3) + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(13.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	var worker: Node = main.get("pound_worker")
	print("V1017: pound escape done, state=", str(main.get("state")), " worker pursuing=", (main.get("pursuers") as Dictionary).has(worker), " worker active=", bool(worker.get("active")), " worker mode=", str(worker.get("mode")))
	var w0: Vector3 = (worker as Node3D).global_position
	# give him open ground to cross: the cat waits 11 m away, so the
	# shot catches him mid-pursuit, closing in — not a re-capture.
	(player as Node3D).global_position = w0 + Vector3(11.0, 0.3, 0.0)
	var d0: float = w0.distance_to((player as Node3D).global_position)
	await wait_sec(1.2) # real time: his physics brain drives him at the cat
	var w1: Vector3 = (worker as Node3D).global_position
	var d1: float = w1.distance_to((player as Node3D).global_position)
	print("V1017: officer displacement=", w0.distance_to(w1), " distance to cat ", d0, " -> ", d1)
	# burst at a few orbit angles — pick the frame where he reads as
	# a person running at the cat (he keeps closing throughout).
	var shot_i: int = 0
	for yaw in [0.0, -1.57, 1.57]:
		main.set("look_yaw", yaw)
		await wait_sec(0.45)
		await snap("pursuit_%d.png" % shot_i)
		shot_i += 1
	# drain his pursuit and park him, like the suite does
	worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(worker)
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_state", "patrol")
	worker.set("active", false)
	(worker as Node3D).visible = false

	# ---- 3: a regular capture -> the HOUSE interior ----
	var woman: Node = null
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110, 0.2, 80)
		if str(n.get("npc_type")) == "woman" and woman == null:
			woman = n
	main.set("captor", woman)
	main.call("_enter_escape")
	var names: Array = []
	for p in main.get("distract_props"):
		names.append(str(p["name"]))
	print("V1017: house entry, is_house=", bool(main.get("escape_room_is_house")), " ward=", (main.get("ward_cages") as Array).size(), " props=", names)
	# stage: cat in the open floor west of the coffee table (NOT
	# inside the sofa — that crushed the camera on the first pass);
	# burst two orbit angles and keep the better framing.
	(player as Node3D).global_position = o + Vector3(-3.2, 0.3, 0.6)
	main.set("look_pitch_deg", 10.0)
	var hi: int = 0
	for yaw2 in [3.14159, 0.0]:
		main.set("look_yaw", yaw2)
		await wait_sec(1.2)
		await snap("house_%d.png" % hi)
		hi += 1
	print("V1017: done")
	get_tree().quit()
