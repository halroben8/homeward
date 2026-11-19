extends Node
## HOMEWARD PERFORMANCE PROBE (diagnostic — not part of the game).
## Run under Xvfb (needs the real GL driver for rendering stats):
##   xvfb-run -a godot --path . tests/PerfProbe.tscn
## Boots the real Main scene, starts a game with the NPCs in their
## natural spawn spots and the cat at spawn (the standard behind
## view), then samples RenderingServer + Performance monitors over
## several phases. Between phases it toggles ONE subsystem at a time
## (NPC physics, sun shadows, ground-detail multimeshes) so the cost
## of each can be attributed by difference. Nothing in the game code
## is modified — toggles are runtime-only and restored afterwards.

var main: Node = null
var player: Node = null
var sampling := false
var acc := {}

func _reset_acc() -> void:
	acc = {"frames": 0, "draws": 0.0, "prims": 0.0, "objs": 0.0,
		"phys_ms": 0.0, "proc_ms": 0.0, "delta_ms": 0.0, "delta_max": 0.0}

func _process(delta: float) -> void:
	if not sampling:
		return
	acc["frames"] += 1
	acc["draws"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	acc["prims"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	acc["objs"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	acc["phys_ms"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	acc["proc_ms"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	acc["delta_ms"] += delta * 1000.0
	acc["delta_max"] = maxf(float(acc["delta_max"]), delta * 1000.0)

func _sample(label: String, secs: float) -> void:
	_reset_acc()
	sampling = true
	await get_tree().create_timer(secs).timeout
	sampling = false
	var n: float = maxf(1.0, float(acc["frames"]))
	var vis_models := 0
	for npc in main.get("npcs"):
		var m = npc.get("model")
		if m != null and (m as Node3D).visible:
			vis_models += 1
	print("STATE state=", main.get("state"), " player_pos=", (player as Node3D).global_position, " npc_models_visible=", vis_models, "/", main.get("npcs").size())
	print("PHASE ", label,
		" | frames ", int(n),
		" | fps ", snappedf(n / secs, 0.1),
		" | draw_calls ", int(acc["draws"] / n),
		" | prims ", int(acc["prims"] / n),
		" | objects ", int(acc["objs"] / n),
		" | phys_ms ", snappedf(float(acc["phys_ms"]) / n, 0.01),
		" | proc_ms ", snappedf(float(acc["proc_ms"]) / n, 0.01),
		" | frame_ms mean ", snappedf(float(acc["delta_ms"]) / n, 0.01),
		" max ", snappedf(float(acc["delta_max"]), 0.01))

func _count(n: Node, stats: Dictionary) -> void:
	stats["nodes"] += 1
	if n is MeshInstance3D:
		stats["mesh_instances"] += 1
		if (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			stats["shadow_casters"] += 1
	if n is MultiMeshInstance3D:
		stats["mmi"] += 1
		if (n as MultiMeshInstance3D).multimesh:
			stats["mm_instances"] += (n as MultiMeshInstance3D).multimesh.instance_count
	if n is StaticBody3D:
		stats["static_bodies"] += 1
	if n is CollisionShape3D:
		stats["col_shapes"] += 1
	if n is Label3D:
		stats["label3d"] += 1
	for ch in n.get_children():
		_count(ch, stats)

func _find_all(n: Node, type_name: String, out: Array) -> void:
	if n.is_class(type_name):
		out.append(n)
	for ch in n.get_children():
		_find_all(ch, type_name, out)

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	# v1.0.9 harness plumbing: Main now builds its world across frames
	# behind the splash — wait for build_complete before driving it,
	# exactly as the title flow does. No assertion is changed.
	var _bw109: int = 0
	while not bool(main.get("build_complete")) and _bw109 < 21600:
		await get_tree().process_frame
		_bw109 += 1
	await get_tree().create_timer(1.5).timeout
	main.call("dismiss_splash")
	await get_tree().create_timer(0.3).timeout
	main.call("start_game")
	await get_tree().create_timer(0.5).timeout
	player = main.get("player")
	# Measurement hygiene: pin every neighbour's notice cooldown so
	# no wanderer can spot the idle cat, start a chase and drag the
	# camera (or the cat, via a capture) out of the staged viewpoint
	# mid-measurement. Wander, animation and physics are untouched.
	for n in main.get("npcs"):
		n.set("notice_cooldown", 99999.0)

	# ---- static scene census -------------------------------------
	var stats := {"nodes": 0, "mesh_instances": 0, "shadow_casters": 0, "mmi": 0, "mm_instances": 0, "static_bodies": 0, "col_shapes": 0, "label3d": 0}
	_count(main, stats)
	print("=== PERF PROBE ===")
	print("CENSUS: ", stats)
	var cam: Camera3D = main.get("cam")
	print("CAMERA: far=", cam.far, " fov=", cam.fov)
	var suns: Array = []
	_find_all(main, "DirectionalLight3D", suns)
	for s in suns:
		var dl := s as DirectionalLight3D
		print("LIGHT: shadow=", dl.shadow_enabled, " max_dist=", dl.directional_shadow_max_distance, " mode=", dl.directional_shadow_mode)

	# ---- micro-benchmarks (script-side CPU) -----------------------
	var npcs: Array = main.get("npcs")
	var t0 := Time.get_ticks_usec()
	var reps := 200
	for r in range(reps):
		for n in npcs:
			n.call("_has_line_of_sight")
	print("MICRO: _has_line_of_sight x", npcs.size(), " x", reps, " = ", snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.01), "ms total -> per NPC per call ", snappedf(float(Time.get_ticks_usec() - t0) / (1000.0 * reps * npcs.size()), 0.002), "ms")
	t0 = Time.get_ticks_usec()
	for r in range(reps):
		for n in npcs:
			n.call("_update_labels")
	print("MICRO: _update_labels x", npcs.size(), " x", reps, " = ", snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.01), "ms total")
	t0 = Time.get_ticks_usec()
	for r in range(reps):
		for n in npcs:
			n.call("_animate", 1.0 / 120.0, 2.0)
	print("MICRO: _animate x", npcs.size(), " x", reps, " = ", snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.01), "ms total")

	# ---- phases ----------------------------------------------------
	await _sample("BASELINE", 5.0)

	for n in npcs:
		(n as Node).set_physics_process(false)
	await _sample("NPC_PHYSICS_OFF", 4.0)
	for n in npcs:
		(n as Node).set_physics_process(true)

	for s in suns:
		(s as DirectionalLight3D).shadow_enabled = false
	await _sample("SHADOWS_OFF", 4.0)
	for s in suns:
		(s as DirectionalLight3D).shadow_enabled = true

	var mmis: Array = []
	_find_all(main, "MultiMeshInstance3D", mmis)
	for m in mmis:
		(m as Node3D).visible = false
	await _sample("GROUND_DETAIL_OFF", 4.0)
	for m in mmis:
		(m as Node3D).visible = true

	await _sample("BASELINE_AGAIN", 4.0)
	print("=== END PERF PROBE ===")
	get_tree().quit()
