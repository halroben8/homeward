extends Node
## ZANDER'S RUN v1.0.20 — screenshot runner (not part of the suite):
## the INDOOR escape-room camera (Michael's v1.0.17 play screenshot:
## the camera jammed right up behind Zander indoors — cat filling
## half the screen, a bare wall corner and a strip of carpet, the
## room / captor / props / door out of view).
## Three shots, all framed by the game itself: this runner sets
## look_yaw (the player's own look control) but NEVER touches
## look_pitch_deg, so the shipped indoor pitch profile is what is
## measured. Per shot it prints the camera's distance to the cat,
## the cat's share of frame height, the camera height and FOV, and
## whether the captor's head projects inside the frame.
##  1. ward_room.png    — shelter ward, OFFICER captor, cat mid-ward.
##  2. house_corner.png — house, YOUNG WOMAN captor, cat backed into
##     the south-west corner with the camera pushed into the corner
##     (the exact geometry of Michael's screenshot).
##  3. house_room.png   — house, young woman captor, cat mid-room.
## Boots the real game and drives the real flows. PNGs land in
## ~/workspace/homeward/screenshots_v1020/.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1020/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("saved ", name, " ", img.get_size())

func measure(tag: String, captor_node: Node) -> void:
	var cam3d: Camera3D = main.get("cam")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var cat_a := AABB()
	var first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		cat_a = ga if first else cat_a.merge(ga)
		first = false
	var base: Vector3 = (player as Node3D).global_position
	var bot: Vector2 = cam3d.unproject_position(Vector3(base.x, cat_a.position.y, base.z))
	var top: Vector2 = cam3d.unproject_position(Vector3(base.x, cat_a.position.y + cat_a.size.y, base.z))
	var share: float = absf(bot.y - top.y) / vp.y
	var dist: float = cam3d.global_position.distance_to(base)
	var captor_in := false
	var captor_frac := Vector2(-1, -1)
	if captor_node != null:
		var hp: Vector3 = (captor_node as Node3D).global_position + Vector3(0, 1.55, 0)
		if not cam3d.is_position_behind(hp):
			captor_frac = cam3d.unproject_position(hp) / vp
			captor_in = captor_frac.x >= 0.0 and captor_frac.x <= 1.0 and captor_frac.y >= 0.0 and captor_frac.y <= 1.0
	print("MEASURE ", tag, ": cam_dist=", snappedf(dist, 0.01), " cat_share=", snappedf(share, 0.001), " cam_y=", snappedf(cam3d.global_position.y, 0.01), " fov=", cam3d.fov, " pitch_stored=", main.get("look_pitch_deg"), " cur_dist=", main.get("current_cam_dist"), " captor_head_in_frame=", captor_in, " at=", captor_frac)

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
	print("V1020: build_complete")
	var o: Vector3 = main.get("escape_origin")

	# ---- 1: the opening pound escape — the officer in the ward ----
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.5)
	print("V1020: after skip, state=", str(main.get("state")), " captor is worker=", main.get("captor") == main.get("pound_worker"))
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	await wait_sec(0.5)
	var officer: Node = main.get("pound_worker")
	(player as Node3D).global_position = o + Vector3(2.0, 0.3, -2.0)
	main.set("look_yaw", -PI * 0.75)
	await wait_sec(1.4) # camera settle on the game's own framing
	(officer as Node3D).global_position = o + Vector3(5.5, 0.25, 1.5)
	await wait_sec(0.35)
	measure("ward_room", officer)
	await snap("ward_room.png")

	# ---- 2+3: a regular capture — the young woman, the house ----
	# (park the officer first: both rooms share the escape_origin
	# slot, so the previous captor would otherwise stand in shot)
	officer.set("active", false)
	(officer as Node3D).visible = false
	(officer as Node3D).global_position = Vector3(-110, 0.2, 80)
	var woman: Node = null
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110, 0.2, 80)
		if str(n.get("npc_type")) == "woman" and woman == null:
			woman = n
	main.call("clear_message_band")
	main.set("captor", woman)
	main.call("_enter_escape")
	await wait_sec(0.5)
	# 2: the corner case from Michael's screenshot
	(player as Node3D).global_position = o + Vector3(-12.4, 0.3, 8.4)
	main.set("look_yaw", -PI * 0.25)
	await wait_sec(1.4)
	(woman as Node3D).global_position = o + Vector3(-6.0, 0.25, 2.0)
	await wait_sec(0.35)
	measure("house_corner", woman)
	await snap("house_corner.png")
	# 3: mid-room
	(player as Node3D).global_position = o + Vector3(2.0, 0.3, -2.0)
	main.set("look_yaw", -PI * 0.75)
	await wait_sec(1.4)
	(woman as Node3D).global_position = o + Vector3(5.5, 0.25, 1.5)
	await wait_sec(0.35)
	measure("house_room", woman)
	await snap("house_room.png")
	print("V1020: done")
	get_tree().quit()
