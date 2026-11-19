extends Node
## HOMEWARD camera-framing screenshots (before/after pair).
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerCamera.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerCamera.tscn -- after
## Four staged scenes from the player's REAL viewpoint (the game's own
## default pitch is captured at boot and used for a/c/d; b uses the
## real look-drag path pushed to max look-up):
##   a_person_notice  cat face-to-face with a grabber, notice bar at 55%
##   c_street_view    ordinary street view — the cat's screen share
##   d_chase          pursuer 5 m behind the cat, chase cam engaged
##   b_sign_lookup    max look-up at the Maple Street sign, cat 3 m away
## Each scene also prints CAMSHOT projection fractions (y: 0=top,
## 1=bottom of frame) for the points that must be inside the frame.
## Output: ~/workspace/homeward/screenshots_camera/<arg>/

const BASE := "/home/hatch/workspace/homeward/screenshots_camera"
var OUT := BASE + "/before"
var main: Node = null
var player: Node = null
var woman: Node = null
var cam: Camera3D = null
var default_pitch: float = 18.0

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func frac(p: Vector3) -> String:
	if cam.is_position_behind(p):
		return "BEHIND"
	var s: Vector2 = cam.unproject_position(p)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return "(%.2f, %.2f)" % [s.x / vp.x, s.y / vp.y]

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func pick_woman() -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman" and str(n.get("role")) == "grabber":
			return n
	return null

func cat_aabb() -> AABB:
	var a := AABB()
	var first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		a = ga if first else a.merge(ga)
		first = false
	return a

func scene_person() -> void:
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", default_pitch)
	(woman as Node3D).global_position = Vector3(61.2, 0.2, 84) # 1.2 m gap
	(woman as Node3D).rotation = Vector3(0, -PI * 0.5, 0) # face the cat
	woman.set("mode", "wander")
	woman.set("notice", 0.55) # bar mid-build; her label updater renders it
	await wait_sec(0.2)
	woman.set_physics_process(false) # hold the pose + label for the shot
	(woman as Node3D).global_position = Vector3(61.2, 0.2, 84)
	await wait_sec(1.1) # camera settle
	var wp: Vector3 = (woman as Node3D).global_position
	print("CAMSHOT a notice=", frac((woman.get("notice_label") as Node3D).global_position),
		" name=", frac((woman.get("name_label") as Node3D).global_position),
		" face=", frac(wp + Vector3(0, 1.52, 0)),
		" label_text='", (woman.get("notice_label") as Label3D).text, "'")
	await snap("a_person_notice.png")

func scene_street() -> void:
	(woman as Node3D).global_position = Vector3(-110, 0.2, 80)
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", default_pitch)
	await wait_sec(1.1)
	var a := cat_aabb()
	var base: Vector3 = (player as Node3D).global_position
	var sb: Vector2 = cam.unproject_position(Vector3(base.x, a.position.y, base.z))
	var st: Vector2 = cam.unproject_position(Vector3(base.x, a.position.y + a.size.y, base.z))
	var vp: Vector2 = get_viewport().get_visible_rect().size
	print("CAMSHOT c cat_share=", snappedf(absf(sb.y - st.y) / vp.y, 0.03),
		" cat_top=", frac(Vector3(base.x, a.position.y + a.size.y, base.z)),
		" cat_bot=", frac(Vector3(base.x, a.position.y, base.z)))
	await snap("c_street_view.png")

func scene_chase() -> void:
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # running +X
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", default_pitch)
	(woman as Node3D).global_position = Vector3(55, 0.2, 85.3) # 5 m behind, offset sideways so she doesn't eclipse the cat (real chases cut corners — never perfectly in line)
	(woman as Node3D).rotation = Vector3(0, PI * 0.5, 0) # facing the cat
	woman.set("mode", "chase") # engages the real chase camera in main
	(woman.get("notice_label") as Label3D).text = "🏃 CHASE!"
	await wait_sec(1.2)
	var wp: Vector3 = (woman as Node3D).global_position
	var a := cat_aabb()
	print("CAMSHOT d chase_cam=", str(main.get("chase_cam_active")),
		" pursuer_notice=", frac((woman.get("notice_label") as Node3D).global_position),
		" pursuer_face=", frac(wp + Vector3(0, 1.52, 0)),
		" cat_top=", frac(Vector3(60, a.position.y + a.size.y, 84)),
		" cat_bot=", frac(Vector3(60, a.position.y, 84)))
	await snap("d_chase.png")
	woman.set("mode", "wander")
	(woman.get("notice_label") as Label3D).text = ""

func scene_sign() -> void:
	# Oak Avenue sign at (58, 0, 20): open corner, pole dead ahead —
	# picked from four candidate signs for the cleanest sight line.
	(woman as Node3D).global_position = Vector3(-110, 0.2, 80)
	(player as Node3D).global_position = Vector3(58, 0.2, 23) # 3 m south of the sign
	(player as Node3D).rotation = Vector3(0, PI, 0) # face the sign (-Z)
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", default_pitch)
	await wait_sec(0.6)
	main.call("apply_look_drag", Vector2(0, -100000)) # real input path -> max look-up
	await wait_sec(1.1)
	print("CAMSHOT b pitch_now=", main.get("look_pitch_deg"),
		" sign_centre=", frac(Vector3(58, 3.75, 20)),
		" sign_top=", frac(Vector3(58, 4.28, 20)),
		" sign_bottom=", frac(Vector3(58, 3.22, 20)))
	await snap("b_sign_lookup.png")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = BASE + "/" + args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	# v1.0.9 harness plumbing: Main now builds its world across frames
	# behind the splash — wait for build_complete before driving it,
	# exactly as the title flow does. No assertion is changed.
	var _bw109: int = 0
	while not bool(main.get("build_complete")) and _bw109 < 21600:
		await get_tree().process_frame
		_bw109 += 1
	await wait_sec(1.2)
	player = main.get("player")
	cam = main.get("cam")
	default_pitch = float(main.get("look_pitch_deg"))
	print("CAMSHOT default_pitch=", default_pitch, " fov=", cam.fov)
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	woman = pick_woman()
	await scene_person()
	await scene_street()
	await scene_chase()
	await scene_sign()
	print("DONE")
	get_tree().quit(0)
