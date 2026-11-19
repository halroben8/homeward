extends Node
## SHIPPED-CAT proof stills (2026-11-18) — NOT part of the suite.
##
## Purpose: trustworthy screenshots of the cat that actually ships
## in v1.0.14. The player cat is the REAL shipped player (scripts/
## cat.gd ghost-rig mirroring assets/models/zander.glb — md5
## identical to the downloaded Meshy original). Nothing about the
## model, textures or game code is changed; this harness only
## boots the real game, plays the real flow shortcut the game
## itself offers (skip_opening -> capture -> escape state ->
## _complete_escape -> town "play"), parks the townsfolk, and
## photographs the shipped cat in the real town at dusk:
##   01_follow.png     the game's OWN camera (no manual placement),
##                     ordinary follow framing on Oak Avenue
##   02_face_town.png  face readable in the street, front
##                     three-quarter (one-frame manual camera,
##                     the established snap_with_cam pattern)
##   03_walk_town.png  mid-stride, driven by the real touch_dir
##                     movement path, game's own camera
##                     (3 candidates snapped; best kept)
## Output: ~/workspace/homeward/screenshots_shipped_cat/
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerShippedCat.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_shipped_cat"
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size(), " state=", str(main.get("state")))

func snap_with_cam(name: String, pos: Vector3, target: Vector3, fov: float) -> void:
	# Freeze the game's camera driver for one frame (map-runner trick).
	main.set_process(false)
	await get_tree().process_frame
	var old_fov: float = cam.fov
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())
	cam.fov = old_fov
	main.set_process(true)

func visible_cat_aabb() -> AABB:
	var a := AABB()
	var first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).is_visible_in_tree():
			continue
		var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		a = ga if first else a.merge(ga)
		first = false
	return a

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1
	for key in ["pound_worker", "captor"]:
		var extra: Node = main.get(key)
		if extra != null and extra is Node3D:
			(extra as Node3D).global_position = Vector3(-130, 0.2, 80)
	var van: Node = main.get("pound_van")
	if van != null and van is Node3D:
		(van as Node3D).global_position = Vector3(500, 0, 500)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	EmojiFont.apply()
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(1.2)
	player = main.get("player")
	cam = main.get("cam")
	print("STAGED boot done; player model uses res://assets/models/zander.glb via cat.gd")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	# Real flow: skip the opening street beats (the game's own
	# skip), ride the capture, then complete the escape through
	# the game's own funnel so we land in genuine town "play".
	var story: Node = main.get("story")
	if story and story.has_method("skip_opening"):
		story.call("skip_opening")
	var guard: float = 0.0
	var landed: bool = false
	while guard < 30.0:
		await wait_sec(0.25)
		guard += 0.25
		var st: String = str(main.get("state"))
		if st == "escape":
			# Open the cage gate through the game's own paw path
			# first (this is what hides the cage prompt and clears
			# cage_closed in the real flow), then complete the
			# escape through the game's own funnel.
			if story and story.has_method("handle_escape_paw"):
				print("GATE paw spent=", story.call("handle_escape_paw"))
			await wait_sec(0.3)
			main.call("_complete_escape")
			landed = true
			break
		if st == "play":
			landed = true
			break
	print("FLOW landed=", landed, " state=", str(main.get("state")), " after ", guard, "s")
	# Cancel the post-escape pursuit so nobody photobombs/harasses.
	var purs: Dictionary = main.get("pursuers")
	purs.clear()
	var captor: Node = main.get("captor")
	if captor and captor.has_method("stop_pursuit"):
		captor.call("stop_pursuit")
	park_npcs_far()
	# The pound van engages a COLLARLESS cat on sight in play —
	# left alone it pulls over beside him and fills the frame.
	# Stage the game's own collared state (the van's settled
	# leave-him-alone condition, as after a collar restore) so
	# the stills show the cat, not the van's pull-over beat.
	main.set("player_collared", true)
	# Stage him on the z=15 road early, then wait out the whole
	# message queue + the new-game controls hint (~11 s) so the
	# stills carry no leftover escape-room text.
	(player as Node3D).global_position = Vector3(46, 0.2, 15)
	(player as Node3D).rotation = Vector3(0, -PI * 0.5, 0)
	player.set("velocity", Vector3.ZERO)
	await wait_sec(11.0)

	# ---------- 01 FOLLOW: the game's own camera ----------
	# On the z=15 road (a real ROAD_CENTRELINES street), facing
	# -X down the road, camera behind him at the shipped framing.
	(player as Node3D).global_position = Vector3(46, 0.2, 15)
	(player as Node3D).rotation = Vector3(0, -PI * 0.5, 0) # face -X
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", PI * 0.5) # behind the cat (rotation + PI)
	main.set("look_pitch_deg", 4.0) # shipped CAM_TOWN_PITCH
	await wait_sec(1.3)
	var a := visible_cat_aabb()
	var base: Vector3 = (player as Node3D).global_position
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sb: Vector2 = cam.unproject_position(Vector3(base.x, a.position.y, base.z))
	var st2: Vector2 = cam.unproject_position(Vector3(base.x, a.position.y + a.size.y, base.z))
	print("FOLLOW cat_height_share=", snappedf(absf(sb.y - st2.y) / vp.y, 0.03),
		" aabb=", a, " cam_pos=", cam.global_position, " fov=", cam.fov)
	await snap("01_follow.png")

	# ---------- 02 FACE: in the street, facing the camera ----------
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X (toward follow cam)
	player.set("velocity", Vector3.ZERO)
	await wait_sec(0.5)
	# Head position from the model's own skeleton (bone "head"),
	# not the merged AABB (the tail corrupts the AABB centre).
	var head := Vector3.ZERO
	var skels: Array = (player as Node3D).find_children("*", "Skeleton3D", true, false)
	if skels.size() > 0:
		var skel: Skeleton3D = skels[0]
		var hi: int = skel.find_bone("head")
		if hi >= 0:
			head = skel.global_transform * skel.get_bone_global_pose(hi).origin
	if head == Vector3.ZERO:
		a = visible_cat_aabb()
		head = Vector3(a.position.x + a.size.x * 0.5, a.position.y + a.size.y * 0.80, a.position.z + a.size.z * 0.5)
	print("FACE head_target=", head)
	var fwd := Vector3(1, 0, 0) # facing +X after the rotation above
	var side := Vector3(fwd.z, 0, -fwd.x)
	await snap_with_cam("02_face_town.png", head + fwd * 0.92 + side * 0.34 + Vector3(0, 0.10, 0), head + Vector3(0, 0.02, 0), 50.0)

	# ---------- 03 WALK: real movement, game's own camera ----------
	# Driven through main's REAL joystick path (joy_mouse +
	# joy_origin/joy_current): _apply_joystick turns that into
	# touch_dir every frame, exactly as a player's thumb does.
	# (Setting touch_dir directly is overwritten within a frame.)
	(player as Node3D).global_position = Vector3(54, 0.2, 15)
	(player as Node3D).rotation = Vector3(0, -PI * 0.5, 0)
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", PI * 0.5) # camera behind-right: three-quarter rear
	main.set("look_pitch_deg", 4.0)
	await wait_sec(0.9)
	var walk_start: Vector3 = (player as Node3D).global_position
	main.set("joy_origin", Vector2(150, 570))
	main.set("joy_current", Vector2(150, 570 - 72)) # push up, mag ~0.85
	main.set("joy_mouse", true)
	await wait_sec(0.8)
	# Close side-on candidates while he walks (the follow camera
	# keeps him at ~21% of frame height — too small to read a
	# stride). Camera re-placed beside his live position each
	# time via the one-frame snap_with_cam pattern; his legs are
	# posed by the real animation at that instant.
	for k in range(4):
		var pp: Vector3 = (player as Node3D).global_position
		await snap_with_cam("cand_walk_%d.png" % (k + 1), pp + Vector3(0.25, 0.45, 1.55), pp + Vector3(0, 0.30, 0), 55.0)
		await wait_sec(0.16)
	main.set("joy_mouse", false)
	print("WALK start=", walk_start, " end pos=", (player as Node3D).global_position,
		" travelled=", walk_start.distance_to((player as Node3D).global_position))
	print("DONE")
	get_tree().quit(0)
