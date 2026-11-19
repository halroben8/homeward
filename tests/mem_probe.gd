extends Node
## TEMPORARY memory probe (rendered): boots Main, waits for the
## build, sits on the title, then starts play briefly, printing
## engine memory monitors at each stage.

var main: Node = null

func report(tag: String) -> void:
	var static_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var peak_mb: float = OS.get_static_memory_peak_usage() / 1048576.0
	print("MEM: ", tag, " static_mb=", snappedf(static_mb, 0.1), " peak_mb=", snappedf(peak_mb, 0.1), " state=", str(main.get("state")))

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	report("build_complete")
	main.call("dismiss_splash")
	await get_tree().create_timer(3.0).timeout
	report("title")
	main.call("start_game")
	await get_tree().create_timer(6.0).timeout
	report("play")
	print("MEM: DONE")
	get_tree().quit()
