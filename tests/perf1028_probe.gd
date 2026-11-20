extends Node
## v1.0.28 PERF PROFILER (diagnostic — not part of the game).
## Run: xvfb-run -a godot --path . tests/Perf1028Probe.tscn [capfps]
## Boots the real Main scene and measures, with wall-clock honesty:
##   BOOT     — launch -> build_complete (the preload/build cost)
##   OPENING  — real splash tap + real START tap, then the full
##              opening cutscene timed phase-by-phase in WALL time
##              (this is the "slow motion" test: compare trees)
##   SHELTER  — 5 s in the cage room after the opening
##   TOWN     — 6 s free-roam staged at the town centre
##   PARK     — 6 s staged at the park
##   CHASE    — up to 6 s of a real grabber chase
## Frame stats per phase: fps, frame ms mean/p50/p95/p99/max,
## hitch counts (>25 ms, >50 ms), draw calls, prims, objects,
## physics ms, process ms (Performance monitors).
## Optional CLI arg after "--": max_fps cap (default 30).

var main: Node = null
var player: Node = null
var story: Node = null

var sampling := false
var deltas: Array = []
var acc := {}

func _reset_acc() -> void:
	deltas.clear()
	acc = {"frames": 0, "draws": 0.0, "prims": 0.0, "objs": 0.0, "phys_ms": 0.0, "proc_ms": 0.0}

func _process(delta: float) -> void:
	if not sampling:
		return
	acc["frames"] += 1
	deltas.append(delta * 1000.0)
	acc["draws"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	acc["prims"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	acc["objs"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	acc["phys_ms"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	acc["proc_ms"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0

func _report(label: String, wall_s: float) -> void:
	var n: float = maxf(1.0, float(acc["frames"]))
	var sorted := deltas.duplicate()
	sorted.sort()
	var m := sorted.size()
	var mean := 0.0
	var h25 := 0
	var h50 := 0
	for d in sorted:
		mean += d
		if d > 25.0: h25 += 1
		if d > 50.0: h50 += 1
	mean /= maxf(1.0, float(m))
	var p50: float = sorted[int(0.50 * float(maxi(0, m - 1)))] if m > 0 else 0.0
	var p95: float = sorted[int(0.95 * float(maxi(0, m - 1)))] if m > 0 else 0.0
	var p99: float = sorted[int(0.99 * float(maxi(0, m - 1)))] if m > 0 else 0.0
	var mx: float = sorted[m - 1] if m > 0 else 0.0
	print("PHASE ", label,
		" | wall_s ", snappedf(wall_s, 0.01),
		" | frames ", int(n),
		" | fps ", snappedf(n / maxf(0.01, wall_s), 0.1),
		" | frame_ms mean ", snappedf(mean, 0.01),
		" p50 ", snappedf(p50, 0.01),
		" p95 ", snappedf(p95, 0.01),
		" p99 ", snappedf(p99, 0.01),
		" max ", snappedf(mx, 0.01),
		" | hitches>25ms ", h25, " >50ms ", h50,
		" | draw_calls ", int(float(acc["draws"]) / n),
		" | prims ", int(float(acc["prims"]) / n),
		" | objects ", int(float(acc["objs"]) / n),
		" | phys_ms ", snappedf(float(acc["phys_ms"]) / n, 0.01),
		" | proc_ms ", snappedf(float(acc["proc_ms"]) / n, 0.01))

func _sample(label: String, secs: float) -> void:
	_reset_acc()
	sampling = true
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(secs).timeout
	sampling = false
	_report(label, float(Time.get_ticks_msec() - t0) / 1000.0)

func push_touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = pos
	t.pressed = pressed
	get_viewport().push_input(t)

func push_mouse(pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.position = pos
	mb.pressed = pressed
	get_viewport().push_input(mb)

func phone_tap(pos: Vector2) -> void:
	push_touch(pos, true)
	push_mouse(pos, true)
	push_touch(pos, false)
	push_mouse(pos, false)

func find_start_button(n: Node) -> Button:
	if n is Button and (n as Button).text.contains("START"):
		return n as Button
	for c in n.get_children():
		var r := find_start_button(c)
		if r != null:
			return r
	return null

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cap := 30
	if args.size() > 0:
		cap = int(args[0])
	Engine.max_fps = cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	print("=== PERF1028 PROBE cap_fps=", cap, " physics_ticks=", Engine.physics_ticks_per_second, " max_steps=", Engine.max_physics_steps_per_frame, " ===")
	var boot_t0 := Time.get_ticks_msec()
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	print("BOOT | wall_s ", snappedf(float(Time.get_ticks_msec() - boot_t0) / 1000.0, 0.01), " | mem_mb ", int(OS.get_static_memory_usage()) / 1048576)
	await get_tree().create_timer(1.0).timeout
	player = main.get("player")
	story = main.get("story")

	# ---------- OPENING (real taps, wall-clock timed) ----------
	phone_tap(Vector2(640, 200)) # dismiss splash
	await get_tree().create_timer(0.5).timeout
	var btn := find_start_button(main)
	_reset_acc()
	sampling = true
	var open_t0 := Time.get_ticks_msec()
	phone_tap(btn.get_global_rect().get_center()) # START
	var last_phase := ""
	var phase_start := open_t0
	var guard := 0
	while str(main.get("state")) != "escape" and guard < 36000:
		await get_tree().process_frame
		guard += 1
		var ph: String = str(story.get("phase"))
		if ph != last_phase:
			var now := Time.get_ticks_msec()
			if last_phase != "":
				print("OPENING phase ", last_phase, " wall_s ", snappedf(float(now - phase_start) / 1000.0, 0.01))
			last_phase = ph
			phase_start = now
		if guard % 600 == 0:
			print("OPENING ... state=", str(main.get("state")), " phase=", ph, " wall_s ", snappedf(float(Time.get_ticks_msec() - open_t0) / 1000.0, 0.01))
	sampling = false
	var open_wall := float(Time.get_ticks_msec() - open_t0) / 1000.0
	print("OPENING last_phase ", last_phase, " wall_s ", snappedf(float(Time.get_ticks_msec() - phase_start) / 1000.0, 0.01))
	_report("OPENING", open_wall)
	print("OPENING total_wall_s ", snappedf(open_wall, 0.01), " state=", str(main.get("state")))

	# ---------- SHELTER (cage room) ----------
	await get_tree().create_timer(1.0).timeout
	await _sample("SHELTER", 5.0)

	# ---------- TOWN / PARK (staged free roam) ----------
	for n in main.get("npcs"):
		n.set("notice_cooldown", 99999.0)
	main.set("state", "play")
	player.set("frozen", false)
	(player as Node3D).global_position = Vector3(0, 0.6, 20)
	await get_tree().create_timer(1.0).timeout
	await _sample("TOWN", 6.0)
	(player as Node3D).global_position = Vector3(86, 0.6, 24)
	await get_tree().create_timer(1.0).timeout
	await _sample("PARK", 6.0)

	# ---------- CHASE ----------
	var grabber: Node = null
	for n in main.get("npcs"):
		if str(n.get("role")) == "grabber":
			grabber = n
			break
	if grabber != null:
		grabber.set("notice_cooldown", 0.0)
		var gp: Vector3 = (grabber as Node3D).global_position
		(player as Node3D).global_position = gp + Vector3(4.0, 0.2, 0.0)
		var ct0 := Time.get_ticks_msec()
		while str(grabber.get("mode")) != "chase" and Time.get_ticks_msec() - ct0 < 25000 and str(main.get("state")) == "play":
			await get_tree().process_frame
		print("CHASE engaged=", str(grabber.get("mode")), " after_s ", snappedf(float(Time.get_ticks_msec() - ct0) / 1000.0, 0.01))
		if str(grabber.get("mode")) == "chase":
			_reset_acc()
			sampling = true
			var ch_t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - ch_t0 < 6000 and str(grabber.get("mode")) == "chase" and str(main.get("state")) == "play":
				await get_tree().process_frame
			sampling = false
			_report("CHASE", float(Time.get_ticks_msec() - ch_t0) / 1000.0)
		else:
			print("CHASE not engaged (mode=", str(grabber.get("mode")), ")")
	else:
		print("CHASE no grabber found")
	print("=== END PERF1028 PROBE ===")
	get_tree().quit()
