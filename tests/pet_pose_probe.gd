extends Node
## PET POSE PROBE — reproduces Michael's report: "when someone's
## petting the cat, the cat spins and goes through the floor."
## Stages the REAL pet interaction exactly like test_runner.gd does
## (paw near a friendly NPC with interact_kind forced to "pet"),
## samples the cat's pose EVERY physics tick, and snaps frames at
## fixed moments so before/after runs are directly comparable.
##   xvfb-run -a godot --path . tests/PetPoseProbe.tscn -- before
##   xvfb-run -a godot --path . tests/PetPoseProbe.tscn -- after
## Output: screenshots_petfix/<arg>/telemetry.csv + PNG frames.

const BASE := "/home/hatch/workspace/homeward/screenshots_petfix"
var OUT := BASE + "/before"
var main: Node = null
var player: Node = null
var body_node: Node3D = null
var body_mi: MeshInstance3D = null
var head_node: Node3D = null
var sampling := false
var rows: Array = []
var phase := "idle"
var start_msec := 0

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name)

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func npc_by_role(role: String) -> Node:
	for n in main.get("npcs"):
		if str(n.get("role")) == role:
			return n
	return null

func _physics_process(_delta: float) -> void:
	if not sampling or player == null:
		return
	var t: float = float(Time.get_ticks_msec() - start_msec) / 1000.0
	var aabb: AABB = body_mi.get_aabb()
	var world_aabb: AABB = body_mi.global_transform * aabb
	var head_off: float = head_node.position.distance_to(player.get("head_base_pos"))
	rows.append([t, phase, float(player.get("pet_a")), float(player.get("pet_t")),
		body_node.rotation.x, body_node.rotation.z,
		(player as Node3D).global_position.y, world_aabb.position.y, head_off,
		(player as Node3D).rotation.y])

func run_interaction(friendly: Node, kind: String, tag: String) -> Dictionary:
	# Stage exactly like the test suite: friendly 2 units east of the
	# cat, fresh interaction state, then a paw to trigger it.
	(friendly as Node3D).global_position = (player as Node3D).global_position + Vector3(2.0, 0, 0)
	friendly.set("notice", 0.0)
	friendly.set("joy_shown", false)
	friendly.set("interact_cooldown", 0.0)
	main.call("_paw_action")
	friendly.set("interact_kind", kind)
	phase = kind
	var snapped := {}
	var elapsed := 0.0
	var pet_seen_at := -1.0
	var end_at := -1.0
	while elapsed < 11.0:
		await wait_sec(0.1)
		elapsed += 0.1
		var st: String = str(friendly.get("interact_state"))
		if kind == "pet" and st == "pet" and pet_seen_at < 0.0:
			pet_seen_at = elapsed
		if kind == "treat" and st == "treat" and pet_seen_at < 0.0:
			pet_seen_at = elapsed
		# Timed frames: approach, contact, mid, late, recovery.
		if pet_seen_at >= 0.0:
			var pt: float = elapsed - pet_seen_at
			for mark in [[0.2, "contact"], [1.3, "mid"], [2.5, "late"]]:
				if pt >= float(mark[0]) and not snapped.has(mark[1]):
					snapped[mark[1]] = true
					await snap(tag + "_" + str(mark[1]) + ".png")
		if pet_seen_at >= 0.0 and st == "" and end_at < 0.0:
			end_at = elapsed
			await snap(tag + "_recovered.png")
			break
	return {"pet_seen_at": pet_seen_at, "end_at": end_at}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = BASE + "/" + args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	body_node = player.get("body_node")
	head_node = player.get("head_node")
	for c in body_node.get_children():
		if c is MeshInstance3D:
			body_mi = c
			break
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	(player as Node3D).global_position = Vector3(100, 0.2, 80)
	player.set("velocity", Vector3.ZERO)
	player.set("rotation", Vector3.ZERO)
	player.set("idle_next_in", 999.0) # no random idle actions mid-trace
	# Camera: three-quarter side view of the pair (person comes from +x).
	main.set("look_yaw", deg_to_rad(55.0))
	main.set("look_pitch_deg", 10.0)
	await wait_sec(1.0)
	await snap("staging.png")

	# Baseline: 1s of plain idle (self-calibrating floor reference).
	start_msec = Time.get_ticks_msec()
	phase = "idle"
	sampling = true
	await wait_sec(1.0)

	# --- the real PET interaction ---
	var friendly: Node = npc_by_role("friendly")
	var pet_res: Dictionary = await run_interaction(friendly, "pet", "pet")
	await wait_sec(0.8)
	(friendly as Node3D).global_position = (player as Node3D).global_position + Vector3(30, 0, 0)

	# --- the real TREAT interaction (same family — check it too) ---
	var friendly2: Node = null
	for n in main.get("npcs"):
		if str(n.get("role")) == "friendly" and n != friendly:
			friendly2 = n
			break
	var treat_res: Dictionary = await run_interaction(friendly2, "treat", "treat")
	await wait_sec(0.8)
	sampling = false

	# Write telemetry + summary.
	var f := FileAccess.open(OUT + "/telemetry.csv", FileAccess.WRITE)
	f.store_line("t,phase,pet_a,pet_t,body_rot_x,body_rot_z,root_y,body_min_y,head_off,root_rot_y")
	for r in rows:
		var cells: Array = []
		for v in r:
			cells.append(str(v))
		f.store_line(",".join(cells))
	f.close()
	var base_min := 999.0
	var pet_min := 999.0
	var pet_max_abs_z := 0.0
	var pet_first_z := 0.0
	var pet_last_z := 0.0
	var pet_z_travel := 0.0
	var prev_z := 0.0
	var have_prev := false
	var treat_max_head_off := 0.0
	var treat_max_abs_z := 0.0
	for r in rows:
		if str(r[1]) == "idle":
			base_min = minf(base_min, float(r[7]))
		if str(r[1]) == "pet":
			pet_min = minf(pet_min, float(r[7]))
			pet_max_abs_z = maxf(pet_max_abs_z, absf(float(r[5])))
			if pet_first_z == 0.0:
				pet_first_z = float(r[5])
			pet_last_z = float(r[5])
			if have_prev:
				pet_z_travel += absf(float(r[5]) - prev_z)
			prev_z = float(r[5])
			have_prev = true
		if str(r[1]) == "treat":
			treat_max_head_off = maxf(treat_max_head_off, float(r[8]))
			treat_max_abs_z = maxf(treat_max_abs_z, absf(float(r[5])))
	print("PROBE pet_seen_at=", pet_res["pet_seen_at"], " end_at=", pet_res["end_at"], " treat_seen_at=", treat_res["pet_seen_at"])
	print("PROBE baseline_body_min_y=", base_min)
	print("PROBE pet_body_min_y=", pet_min, " sink_vs_baseline=", base_min - pet_min)
	print("PROBE pet_body_rot_z: first=", pet_first_z, " last=", pet_last_z, " max_abs=", pet_max_abs_z, " total_travel_rad=", pet_z_travel)
	print("PROBE treat: max_head_off=", treat_max_head_off, " max_abs_body_rot_z=", treat_max_abs_z)
	print("PROBE DONE -> ", OUT)
	get_tree().quit(0)
