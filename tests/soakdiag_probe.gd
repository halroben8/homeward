extends Node
## v1.0.29 SOAK DIAGNOSTIC (temporary): heartbeat edition of the
## soak — prints every 120 frames so a stall is visible in the log,
## 10 s stages at WEST then EAST on the doubled town.

var main: Node = null
var player: Node = null
var frames := 0
var sampling := false
var deltas: Array = []

func _process(delta: float) -> void:
	frames += 1
	if frames % 120 == 0:
		print("DIAG heartbeat frames=", frames, " state=", str(main.get("state")) if main else "?")
	if sampling:
		deltas.append(delta * 1000.0)

func _sample(label: String, secs: float) -> void:
	deltas.clear()
	sampling = true
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(secs).timeout
	sampling = false
	var n: float = maxf(1.0, float(deltas.size()))
	var mean := 0.0
	for d in deltas:
		mean += d
	mean /= n
	var bands: Array = main.get("districts")
	var on_str := ""
	for b in bands:
		on_str += "1" if bool(b["on"]) else "0"
	print("DIAG ", label, " frames=", deltas.size(), " fps=", snappedf(n / maxf(0.01, float(Time.get_ticks_msec() - t0) / 1000.0), 0.1), " frame_ms_mean=", snappedf(mean, 0.01), " draws=", int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)), " static_mb=", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1), " bands_on=", on_str)

func _ready() -> void:
	Engine.max_fps = 30
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	print("=== DIAG soak doubled town ===")
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	print("DIAG build_complete houses=", (main.get("houses") as Array).size())
	player = main.get("player")
	main.set("state", "play")
	player.set("frozen", false)
	(player as Node3D).global_position = Vector3(-60, 0.6, 0)
	print("DIAG teleported WEST, settling")
	await get_tree().create_timer(2.0).timeout
	print("DIAG settled WEST, sampling")
	await _sample("WEST", 10.0)
	(player as Node3D).global_position = Vector3(320, 0.6, -20)
	print("DIAG teleported EAST, settling")
	await get_tree().create_timer(2.0).timeout
	print("DIAG settled EAST, sampling")
	await _sample("EAST", 10.0)
	print("=== DIAG DONE ===")
	get_tree().quit()
