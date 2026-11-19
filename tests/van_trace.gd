extends Node
## VAN TRACE — diagnostic for the v1.0.13 clip-fix suite interaction:
## replicates tests/test_runner.gd's pound-van staging VERBATIM in a
## fresh boot, then traces the catch window every 0.25s (worker mode,
## centre distance, grab_progress, both positions) to see why the
## catch does or doesn't complete. Prints VANTRACE| lines.
##   godot --headless --path . tests/VanTrace.tscn

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(0.6)
	player = main.get("player")
	main.call("start_game")
	await wait_sec(0.5)

	var pvan: Node3D = main.get("pound_van")
	var pworker: Node = main.get("pound_worker")
	print("VANTRACE| booted; state=", str(main.get("state")), " pound_state=", str(main.get("pound_state")))

	# --- suite staging, verbatim ---
	main.set("pound_state", "patrol")
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	(player as Node3D).global_position = Vector3(-100, 0.2, 80)
	for i in range(10):
		main.call("_update_pound", 0.5)
	print("VANTRACE| after manual patrol: van at ", pvan.position)
	(player as Node3D).global_position = pvan.position + Vector3(11.0, 0.2, 0.0)
	player.set("velocity", Vector3.ZERO)
	print("VANTRACE| cat placed at ", (player as Node3D).global_position)

	var guard_p: float = 0.0
	while str(main.get("pound_state")) != "exit" and guard_p < 12.0:
		await wait_sec(0.25)
		guard_p += 0.25
	print("VANTRACE| pound_state=", str(main.get("pound_state")), " after ", guard_p, "s; van at ", pvan.position)
	guard_p = 0.0
	while str(pworker.get("mode")) != "chase" and guard_p < 8.0:
		await wait_sec(0.25)
		guard_p += 0.25
	print("VANTRACE| worker mode=", str(pworker.get("mode")), " after ", guard_p, "s")

	# --- the catch window, traced ---
	var t: float = 0.0
	while t < 16.0:
		await wait_sec(0.25)
		t += 0.25
		var wp: Vector3 = (pworker as Node3D).global_position
		var cp: Vector3 = (player as Node3D).global_position
		print("VANTRACE| t=", t,
			" state=", str(main.get("state")),
			" mode=", str(pworker.get("mode")),
			" dist=", snappedf(wp.distance_to(cp), 0.01),
			" grab=", snappedf(float(pworker.get("grab_progress")), 0.01),
			" hidden=", str(player.get("is_hidden")),
			" worker=", wp, " cat=", cp,
			" catvel=", (player.get("velocity") as Vector3).length())
		if str(main.get("state")) != "play":
			break
	print("VANTRACE DONE")
	get_tree().quit(0)
