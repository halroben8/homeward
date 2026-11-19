extends Node
## v1.0.23 verification shots: (c) the restyled title panel,
## (a) 40 Oak Avenue's front/east side where the old slide used
## to lean (now clean), (b) the park with the Meshy playground
## and a kid playing, plus a lawn close-up for the black-spike
## fix and a playground close-up for grounding/scale.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1023/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(sname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + sname)
	print("V1023 saved ", sname)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await wait_sec(0.5)
	player = main.get("player")
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	print("V1023 build complete")
	# ---- (c) title panel ---------------------------------------
	main.call("dismiss_splash")
	await wait_sec(0.6)
	await snap("title_panel.png")
	# ---- into the town ------------------------------------------
	main.call("start_game")
	await wait_sec(0.4)
	var bguard := 0
	while bguard < 900 and main.get("pound_worker") == null:
		await get_tree().physics_frame
		bguard += 1
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	main.call("_complete_escape")
	await wait_sec(0.2)
	(main.get("pursuers") as Dictionary).clear()
	# Playground grounding, numerically.
	var pgm: Node3D = main.get("playground_model")
	var merged := AABB()
	var first := true
	var stack: Array = [pgm]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
		if cur is MeshInstance3D:
			var ab: AABB = (cur as MeshInstance3D).global_transform * (cur as MeshInstance3D).get_aabb()
			if first:
				merged = ab
				first = false
			else:
				merged = merged.merge(ab)
	print("V1023 playground AABB pos=", merged.position, " size=", merged.size)
	# ---- (a) 40 Oak, clean --------------------------------------
	(player as Node3D).global_position = Vector3(106.5, 0.2, 26.5)
	(player as Node3D).rotation.y = 2.23 + PI
	main.set("look_yaw", 2.23)
	main.set("look_pitch_deg", 8.0)
	for i in 8:
		await get_tree().physics_frame
		main.call("_update_camera", 0.016)
	await snap("house_clean.png")
	# ---- (b) the park, kids playing ------------------------------
	var dwellers: Array = []
	for n in main.get("npcs"):
		if bool(n.get("park_dweller")):
			dwellers.append(n)
	print("V1023 park dwellers: ", dwellers.size())
	var spots: Array = main.get("PARK_SPOTS")
	if dwellers.size() >= 2:
		# One kid walks between play spots; another stands at one.
		(dwellers[0] as Node3D).global_position = spots[3]
		dwellers[0].set("wander_target", spots[1])
		dwellers[0].set("wander_wait", 8.0)
		(dwellers[1] as Node3D).global_position = spots[0]
		dwellers[1].set("wander_target", spots[0])
		dwellers[1].set("wander_wait", 8.0)
	if dwellers.size() >= 3:
		(dwellers[2] as Node3D).global_position = spots[4]
		dwellers[2].set("wander_target", spots[4])
		dwellers[2].set("wander_wait", 8.0)
	(player as Node3D).global_position = Vector3(93, 0.2, 22.5)
	(player as Node3D).rotation.y = 2.39 + PI
	main.set("look_yaw", 2.39)
	main.set("look_pitch_deg", 6.0)
	for i in 30:
		await get_tree().physics_frame
		main.call("_update_camera", 0.016)
	await snap("park_play.png")
	# ---- playground close-up --------------------------------------
	(player as Node3D).global_position = Vector3(91.5, 0.2, 34.5)
	(player as Node3D).rotation.y = -0.88 + PI
	main.set("look_yaw", -0.88)
	main.set("look_pitch_deg", 6.0)
	for i in 8:
		await get_tree().physics_frame
		main.call("_update_camera", 0.016)
	await snap("playground_close.png")
	# ---- lawn close-up (black-spike check, same framing as diag4) --
	(player as Node3D).global_position = Vector3(30, 0.2, 47)
	(player as Node3D).rotation.y = 0.0
	main.set("look_yaw", PI)
	main.set("look_pitch_deg", 24.0)
	for i in 8:
		await get_tree().physics_frame
		main.call("_update_camera", 0.016)
	await snap("lawn_blades.png")
	print("V1023 DONE")
	get_tree().quit()
