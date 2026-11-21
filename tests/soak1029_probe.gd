extends Node
## v1.0.29 SOAK (diagnostic — not part of the game).
## Boots the DOUBLED town, then stages the player at four spots
## (west, centre, park, far east), sampling frame stats + memory
## for 60 s at each with all systems live (48 NPCs, cats, traffic,
## pound patrol). Teleports between stages exercise the district
## streaming toggles; band states are printed after each move.
## Run: xvfb-run -a godot --path . tests/Soak1029Probe.tscn

var main: Node = null
var player: Node = null
var sampling := false
var deltas: Array = []
var acc := {}

func _reset_acc() -> void:
	deltas.clear()
	acc = {"frames": 0, "draws": 0.0, "objs": 0.0}

func _process(delta: float) -> void:
	if not sampling:
		return
	acc["frames"] += 1
	deltas.append(delta * 1000.0)
	acc["draws"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	acc["objs"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))

func _report(label: String, wall_s: float) -> void:
	var n: float = maxf(1.0, float(acc["frames"]))
	var sorted := deltas.duplicate()
	sorted.sort()
	var m := sorted.size()
	var mean := 0.0
	var h50 := 0
	for d in sorted:
		mean += d
		if d > 50.0: h50 += 1
	mean /= maxf(1.0, float(m))
	var p95: float = sorted[int(0.95 * float(maxi(0, m - 1)))] if m > 0 else 0.0
	var mx: float = sorted[m - 1] if m > 0 else 0.0
	var bands: Array = main.get("districts")
	var on_str := ""
	for b in bands:
		on_str += "1" if bool(b["on"]) else "0"
	print("SOAK ", label,
		" | wall_s ", snappedf(wall_s, 0.1),
		" | fps ", snappedf(n / maxf(0.01, wall_s), 0.1),
		" | frame_ms mean ", snappedf(mean, 0.01),
		" p95 ", snappedf(p95, 0.01),
		" max ", snappedf(mx, 0.01),
		" | hitches>50ms ", h50,
		" | draw_calls ", int(float(acc["draws"]) / n),
		" | objects ", int(float(acc["objs"]) / n),
		" | static_mb ", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		" | peak_mb ", snappedf(OS.get_static_memory_peak_usage() / 1048576.0, 0.1),
		" | bands_on ", on_str)

func _sample(label: String, secs: float) -> void:
	_reset_acc()
	sampling = true
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(secs).timeout
	sampling = false
	_report(label, float(Time.get_ticks_msec() - t0) / 1000.0)

func _ready() -> void:
	Engine.max_fps = 30
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	print("=== SOAK1029 doubled town ===")
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	print("SOAK build_complete guard=", bw, " houses=", (main.get("houses") as Array).size(), " npcs=", (main.get("npcs") as Array).size(), " static_mb=", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))
	player = main.get("player")
	main.set("state", "play")
	player.set("frozen", false)
	var spots: Array = [
		["WEST", Vector3(-60, 0.6, 0)],
		["CENTRE", Vector3(126, 0.6, 0)],
		["PARK", Vector3(86, 0.6, 24)],
		["EAST", Vector3(320, 0.6, -20)],
		["WEST_AGAIN", Vector3(-60, 0.6, 0)],
	]
	for s in spots:
		(player as Node3D).global_position = s[1]
		await get_tree().create_timer(2.0).timeout # let districts settle
		await _sample(s[0], 60.0)
	print("=== SOAK1029 DONE ===")
	get_tree().quit()
