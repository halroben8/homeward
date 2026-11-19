extends Node
## ZANDER'S RUN v1.0.22 — cast + intake card screenshot runner
## (not part of the suite):
##  1. cast_and_cats.png — three of the NEW Meshy townsfolk (baker,
##     construction worker, street musician) with three of the new
##     Meshy town cats, staged on the grass by Maple Street.
##  2. intake_card.png — the intake card on Zander's cage in the
##     ward, up close and readable (it names Maple Street, rolled
##     from a Maple Street position through the real lookup).
##  3. intake_card_wide.png — the cage front with the card on it,
##     Zander inside, from across the ward.
## Boots the real game (same escape-to-town sequence as the suite);
## stills use the free camera with main's process paused, the
## established shelter-shot pattern.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1022/"

var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap_with_cam(sname: String, pos: Vector3, target: Vector3) -> void:
	# Pause BOTH of main's loops: the follow camera is driven from
	# the physics step in this build, and a pose set while it runs
	# gets overwritten before the frame is drawn.
	main.set_process(false)
	main.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().physics_frame
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + sname)
	print("SHOT: ", sname, " ", img.get_size())
	main.set_physics_process(true)
	main.set_process(true)

func first_npc_of_type(t: String) -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == t:
			return n
	return null

func cat_by_model(m: String) -> Node:
	for c in main.get("town_cats"):
		var stack: Array = [c]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur.scene_file_path.ends_with(m + ".glb"):
				return c
			for ch2 in cur.get_children():
				stack.append(ch2)
	return null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await wait_sec(0.5)
	player = main.get("player")
	cam = main.get("cam")
	# Wait for the staged boot build to finish BEFORE the splash
	# calls — start_game during the build is a no-op and the runner
	# would sit on the title screen forever (the v1.0.21 runner's
	# proven order).
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	main.call("dismiss_splash")
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
	var pworker: Node = main.get("pound_worker")
	pworker.set("active", false)
	pworker.set("visible", false)

	# ---- 1. the new cast + town cats --------------------------------
	# Two-step staging: teleport next to the player and let a few
	# LIVE frames pass (the townsfolk/cats distance-cull their
	# models — the cull must see them near before it latches them
	# visible), THEN freeze and re-teleport to the exact marks.
	var anchor := Vector3(26.0, 0.2, 27.5) # open grass south of Oak Avenue
	var baker: Node3D = first_npc_of_type("baker")
	var builder: Node3D = first_npc_of_type("construction")
	var musician: Node3D = first_npc_of_type("musician")
	var folk: Array = [
		[baker, anchor + Vector3(-1.9, 0, 0.4), 0.25],
		[builder, anchor + Vector3(0.1, 0, 1.3), -0.15],
		[musician, anchor + Vector3(2.0, 0, 0.2), 0.4],
	]
	var cat_spots: Array = [
		["town_tabby", anchor + Vector3(-1.0, 0, -1.7)],
		["calico_cat", anchor + Vector3(0.9, 0, -1.4)],
		["siamese_cat", anchor + Vector3(0.0, 0, -2.9)],
	]
	player.global_position = anchor + Vector3(5.0, 0.2, -6.0)
	for f in folk:
		if f[0] != null:
			(f[0] as Node3D).global_position = anchor + Vector3(0, 0, -4.0)
	for cs in cat_spots:
		var c0: Node3D = cat_by_model(cs[0])
		if c0 != null:
			c0.global_position = anchor + Vector3(0, 0, -4.0)
	await wait_sec(0.4) # live settle: culling latches everyone visible
	for f in folk:
		var n: Node3D = f[0]
		if n == null:
			continue
		n.set_physics_process(false)
		n.global_position = f[1]
		n.rotation.y = float(f[2])
	for cs in cat_spots:
		var c: Node3D = cat_by_model(cs[0])
		if c == null:
			print("CAST SHOT: cat not found: ", cs[0])
			continue
		c.set_physics_process(false)
		c.global_position = cs[1]
		# Face the camera (south of the group): the cat's facing is
		# its root yaw plus the measured model-forward offset.
		var off: float = float(c.get("_face_yaw_off"))
		c.rotation.y = atan2(0.0, 1.0) - off
	await snap_with_cam("cast_and_cats.png", anchor + Vector3(1.4, 1.5, 6.9), anchor + Vector3(0, 0.8, 0.2))
	print("CAST SHOT done")

	# ---- 2/3. the intake card ---------------------------------------
	var street: String = str(main.call("street_name_at", Vector3(0, 0, -11)))
	main.set("pickup_street", street)
	main.call("_refresh_intake_card")
	var o: Vector3 = main.get("escape_origin")
	var card_pos: Vector3 = o + Vector3(0.86, 0.74, 8.55 - 1.16)
	player.global_position = o + Vector3(0.1, 0.3, 8.55) # Zander in his cage behind the card
	await wait_sec(0.3)
	await snap_with_cam("intake_card.png", card_pos + Vector3(0.1, 0.06, -1.25), card_pos)
	await snap_with_cam("intake_card_wide.png", o + Vector3(4.6, 1.9, 1.8), o + Vector3(0.2, 0.7, 8.4))
	print("CARD SHOT done — street on card: ", street)

	# ---- 4. traffic nose-first (free camera, deterministic) ---------
	# Spawn traffic until a car is driving a horizontal road, then
	# frame it from the roadside ahead of its travel: nose toward
	# the camera side it is driving to. (The suite measures the
	# nose-vs-travel alignment live; this is the visual companion.)
	var tcar: Node3D = null
	var tvel := Vector3.ZERO
	for tries in 40:
		var node: Node3D = main.call("spawn_traffic_car")
		if node == null:
			break
		for tc in main.get("traffic_cars"):
			if tc["node"] == node:
				tvel = tc["vel"]
		if absf(tvel.z) < 0.1 and absf(tvel.x) > 1.0:
			tcar = node
			break
	if tcar != null:
		var dir: Vector3 = tvel.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var cp: Vector3 = tcar.global_position
		await snap_with_cam("traffic_nose_first.png", cp + dir * 7.5 + side * 4.5 + Vector3(0, 1.7, 0), cp + dir * 1.5 + Vector3(0, 0.5, 0))
		print("TRAFFIC SHOT done — car at ", cp, " vel ", tvel, " nose ", main.call("_car_nose_dir", tcar))
	else:
		print("TRAFFIC SHOT: no horizontal-road car found")
	get_tree().quit()
