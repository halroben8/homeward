extends Node
## v1.0.33 DIAGNOSTIC probe (not part of the game): photograph +
## measure the animal control officer's net grip in stand / tell /
## walk / chase states, through the REAL start flow (start_game ->
## skip opening -> force town play with the worker on his own
## brain). Every measurement line is prefixed NETDUMP.
## Output: ~/workspace/homeward/probe_netgrip_before/
## Run: xvfb-run -a godot --path . tests/NetGripProbe.tscn

const OUT := "/home/hatch/workspace/homeward/probe_netgrip_after"
var main: Node = null
var cam: Camera3D = null
var officer: Node3D = null
var player: Node3D = null

func fwd_of(n: Node3D) -> Vector3:
	var f: Vector3 = n.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.05 else Vector3(0, 0, 1)

func right_of(n: Node3D) -> Vector3:
	var r: Vector3 = n.global_transform.basis.x
	r.y = 0.0
	return r.normalized() if r.length() > 0.05 else Vector3(1, 0, 0)

func snap(name: String, dist_fwd: float, dist_right: float, height: float, look_h: float) -> void:
	var o: Vector3 = officer.global_position
	cam.global_position = o + fwd_of(officer) * dist_fwd + right_of(officer) * dist_right + Vector3(0, height, 0)
	cam.look_at(o + Vector3(0, look_h, 0), Vector3.UP)
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("NETDUMP saved ", name)

var pin_pos := Vector3.ZERO
var pin_rot := 0.0
var pinning := false

func snap_pinned(name: String, dist_fwd: float, dist_right: float, height: float, look_h: float) -> void:
	# Like snap(), but the officer + cat are re-pinned on every
	# physics frame throughout the settle, so a running chase
	# pose holds still for the camera.
	pinning = true
	for i in range(10):
		await get_tree().process_frame
		var o: Vector3 = officer.global_position
		cam.global_position = o + fwd_of(officer) * dist_fwd + right_of(officer) * dist_right + Vector3(0, height, 0)
		cam.look_at(o + Vector3(0, look_h, 0), Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("NETDUMP saved ", name)
	pinning = false

func dump(tag: String) -> void:
	var s: float = float(officer.get("mscale"))
	var skel: Skeleton3D = officer.get("meshy_skel") as Skeleton3D
	var bones: Dictionary = officer.get("meshy_bone")
	var net: Node3D = officer.get("net_root") as Node3D
	var gt: Transform3D = net.global_transform
	var grip: Vector3 = gt * Vector3(0, -0.74 * s, 0.01)
	var shaft_a: Vector3 = gt * Vector3(0, -0.59 * s, 0.01)
	var head_p: Vector3 = gt * Vector3(0, -1.86 * s, 0.01)
	var axis: Vector3 = (head_p - shaft_a).normalized()
	print("NETDUMP ", tag, " mode=", str(officer.get("mode")), " speed=", snappedf((officer.velocity as Vector3).length(), 0.01))
	print("NETDUMP   grip=", grip, " head=", head_p, " axis=", axis)
	var inv: Transform3D = officer.global_transform.affine_inverse()
	for role in ["hand_l", "hand_r", "fore_l", "fore_r", "arm_l", "arm_r"]:
		if bones.has(role):
			var bi: int = int(bones[role])
			var hp: Vector3 = skel.global_transform * skel.get_bone_global_pose(bi).origin
			var dline: float = (hp - shaft_a).cross(axis).length()
			var dgrip: float = hp.distance_to(grip)
			print("NETDUMP   ", role, " local=", inv * hp, " dist_to_pole=", snappedf(dline, 0.001), " dist_to_grip=", snappedf(dgrip, 0.001))

func dump_rest() -> void:
	var skel: Skeleton3D = officer.get("meshy_skel") as Skeleton3D
	var bones: Dictionary = officer.get("meshy_bone")
	var rest: Dictionary = officer.get("meshy_rest")
	var inv: Transform3D = officer.global_transform.affine_inverse()
	print("NETDUMP REST (officer-local, standing at rest)")
	for role in ["hips", "spine2", "sh_l", "arm_l", "fore_l", "hand_l", "sh_r", "arm_r", "fore_r", "hand_r", "head"]:
		if bones.has(role):
			var bi: int = int(bones[role])
			var wp: Vector3 = skel.global_transform * (rest[bi] as Transform3D).origin
			print("NETDUMP   rest ", role, " local=", inv * wp)
	for side in ["l", "r"]:
		var a: Vector3 = (rest[int(bones["arm_" + side])] as Transform3D).origin
		var f: Vector3 = (rest[int(bones["fore_" + side])] as Transform3D).origin
		var h: Vector3 = (rest[int(bones["hand_" + side])] as Transform3D).origin
		print("NETDUMP   seg ", side, " L1(upper)=", snappedf(a.distance_to(f), 0.001), " L2(fore)=", snappedf(f.distance_to(h), 0.001), " reach=", snappedf(a.distance_to(f) + f.distance_to(h), 0.001))

func _physics_process(_delta: float) -> void:
	if pinning and officer != null and player != null:
		officer.global_position = pin_pos
		officer.rotation.y = pin_rot
		player.global_position = pin_pos + fwd_of(officer) * 5.0 + Vector3(0, 0.05, 0)

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
	# The real flow: START -> opening cutscene -> skip to the pound.
	main.call("dismiss_splash")
	main.call("start_game")
	await get_tree().create_timer(0.5).timeout
	var story: Node = main.get("story")
	story.call("skip_opening")
	await get_tree().create_timer(0.5).timeout
	# Force free town play with the worker on his own brain and
	# main's van machine hands-off ("away"), engagements held off.
	officer = main.get("pound_worker")
	(main.get("pursuers") as Dictionary).clear()
	officer.call("stop_pursuit")
	main.set("state", "play")
	main.set("pound_state", "away")
	main.set("pound_engage_cd", 99999.0)
	player = main.get("player")
	player.set("frozen", false)
	var tp: Object = main.get("title_panel")
	if tp != null:
		(tp as CanvasItem).visible = false
	var sp: Object = main.get("splash_panel")
	if sp != null:
		(sp as CanvasItem).visible = false
	var ep: Object = main.get("escape_prompt_btn")
	if ep != null:
		(ep as CanvasItem).visible = false
	officer.visible = true
	officer.set("active", true)
	officer.call("set_net_visible", true)
	officer.set("grab_needed", 999.0)
	officer.set("detect_radius", 0.0)
	officer.set("notice_cooldown", 9999.0)
	# Park everyone else far away.
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1
	# Officer on Maple Street, facing +Z (south); cat 10 m ahead.
	officer.global_position = Vector3(10, 0.15, 14)
	officer.rotation.y = 0.0
	officer.set("wander_target", officer.global_position)
	officer.set("wander_wait", 999.0)
	player.global_position = Vector3(10, 0.2, 24)
	cam = Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	await get_tree().create_timer(0.9).timeout
	dump_rest()
	# ---- STAND ----
	await snap("stand_close.png", 2.6, 1.6, 1.45, 1.0)
	dump("STAND")
	await snap("stand_normal.png", 4.6, 2.2, 1.7, 1.0)
	# ---- WALK (along Maple, +X) ----
	officer.set("wander_wait", 0.0)
	officer.set("wander_target", Vector3(38, 0, 14))
	var wguard: int = 0
	while (officer.velocity as Vector3).length() < 0.8 and wguard < 60 * 6:
		await get_tree().physics_frame
		wguard += 1
	await get_tree().create_timer(0.35).timeout
	await snap("walk_close_a.png", 2.8, 1.7, 1.45, 1.0)
	dump("WALK_A")
	await get_tree().create_timer(0.45).timeout
	await snap("walk_close_b.png", 2.8, -1.7, 1.45, 1.0)
	dump("WALK_B")
	# ---- TELL + CHASE ----
	officer.set("wander_target", officer.global_position)
	officer.set("detect_radius", 12.0)
	officer.set("notice_cooldown", 0.0)
	officer.set("notice", 1.0)
	player.global_position = officer.global_position + fwd_of(officer) * 5.0 + Vector3(0, 0.05, 0)
	officer.call("_start_chase")
	await get_tree().create_timer(0.45).timeout
	await snap("tell_close.png", 2.6, 1.6, 1.45, 1.0)
	dump("TELL")
	# Chase: keep the cat 5 m ahead of him so he keeps running.
	var t_end: int = Time.get_ticks_msec() + 3400
	var snapped_a := false
	while Time.get_ticks_msec() < t_end:
		await get_tree().physics_frame
		player.global_position = officer.global_position + fwd_of(officer) * 5.0 + Vector3(0, 0.05, 0)
		if not snapped_a and Time.get_ticks_msec() > t_end - 1900:
			snapped_a = true
			await snap("chase_close_a.png", 2.8, 1.6, 1.45, 1.0)
			dump("CHASE_A")
	await snap("chase_close_b.png", 2.8, -1.6, 1.45, 1.0)
	dump("CHASE_B")
	await snap("chase_side.png", 0.3, 3.0, 1.45, 1.0)
	await snap("chase_normal.png", 4.6, 2.2, 1.7, 1.0)
	# ---- PINNED CHASE: same chase pose, stable framing ----
	pin_pos = officer.global_position
	pin_rot = officer.rotation.y
	await snap_pinned("chase_pin_front.png", 2.9, 1.5, 1.45, 1.0)
	dump("CHASE_PIN")
	await snap_pinned("chase_pin_side.png", 0.2, 3.0, 1.45, 1.0)
	await snap_pinned("chase_pin_back.png", -2.9, -1.5, 1.45, 1.0)
	print("NETDUMP DONE")
	get_tree().quit()
