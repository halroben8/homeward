extends Node
## v1.0.34 DIAGNOSTIC probe (not part of the game): run the REAL
## opening (no skip) and measure the officer's net grip through
## the van-exit / approach / standing-line beats — the beats the
## v1.0.33 NetGripProbe skipped over. Every line is prefixed
## OPENDUMP. Photos use the game's own cutscene camera (what the
## player actually sees).
## Output: ~/workspace/homeward/probe_net_opening/
## Run: xvfb-run -a godot --path . tests/OpeningNetProbe.tscn

const OUT := "/home/hatch/workspace/homeward/probe_net_opening"
var main: Node = null
var officer: Node3D = null
var story: Node = null
var snapped: Dictionary = {}

func snap(name: String) -> void:
	if snapped.has(name):
		return
	snapped[name] = true
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("OPENDUMP saved ", name)

func dump(tag: String) -> void:
	var s: float = float(officer.get("mscale"))
	var skel: Skeleton3D = officer.get("meshy_skel") as Skeleton3D
	var bones: Dictionary = officer.get("meshy_bone")
	var net: Node3D = officer.get("net_root") as Node3D
	if net == null or skel == null:
		print("OPENDUMP ", tag, " NO NET/SKEL")
		return
	var gt: Transform3D = net.global_transform
	var grip: Vector3 = gt * Vector3(0, -0.74 * s, 0.01)
	var ap: AnimationPlayer = officer.get("meshy_ap") as AnimationPlayer
	var apinfo := "none"
	if ap != null:
		apinfo = "anim=" + ap.current_animation + " speed=" + str(snappedf(ap.speed_scale, 0.01)) + " playing=" + str(ap.is_playing())
	print("OPENDUMP ", tag,
		" phase=", str(story.get("phase")),
		" line_step=", str(story.get("line_step")),
		" state=", str(main.get("state")),
		" active=", str(officer.get("active")),
		" mode=", str(officer.get("mode")),
		" netvis=", str(net.visible),
		" w_body=", str(snappedf(float(officer.get("meshy_w_body")), 0.01)),
		" w_arms=", str(snappedf(float(officer.get("meshy_w_arms")), 0.01)),
		" ", apinfo)
	for role in ["hand_l", "hand_r"]:
		if bones.has(role):
			var bi: int = int(bones[role])
			skel.force_update_all_bone_transforms()
			var hp: Vector3 = skel.global_transform * skel.get_bone_global_pose(bi).origin
			print("OPENDUMP   ", role, " dist_to_grip=", snappedf(hp.distance_to(grip), 0.003))

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	officer = main.get("pound_worker")
	story = main.get("story")
	main.call("dismiss_splash")
	main.call("start_game")
	# Sample the whole opening at ~4 Hz until the escape begins.
	# (Headless game-time runs ~3x slower than wall time here.)
	var t_end: int = Time.get_ticks_msec() + 420000
	var last_sample: int = 0
	var line_walk_snapped := false
	while Time.get_ticks_msec() < t_end:
		await get_tree().physics_frame
		var now: int = Time.get_ticks_msec()
		if now - last_sample < 250:
			continue
		last_sample = now
		var phase: String = str(story.get("phase"))
		var lstep: int = int(story.get("line_step"))
		dump("t+" + str(snappedf((now - (t_end - 420000)) / 1000.0, 0.1)) + "s")
		if phase == "line" and lstep == 0 and not line_walk_snapped:
			line_walk_snapped = true
			await snap("line_walk.png")
		if phase == "line" and lstep == 1:
			await snap("line_stand_a.png")
			await get_tree().create_timer(1.8).timeout
			dump("line_stand_late")
			await snap("line_stand_b.png")
		if str(main.get("state")) == "escape":
			dump("ESCAPE_REACHED")
			break
	print("OPENDUMP DONE")
	get_tree().quit()
