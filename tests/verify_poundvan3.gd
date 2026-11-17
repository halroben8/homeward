extends Node
## HOMEWARD POUND VAN — verification pass 3: RETURN-ROUTING MATRIX.
## The suite's "he gets back in and the patrol resumes" check timed
## out at its 30s guard in two consecutive full-suite runs, while
## the standalone cycle harness measured a 2s return twice. The
## difference must be geometry: where the worker happens to be
## standing when the return begins. This probe does ONE real
## pullover (to get the authentic stop position, yaw and kerb
## side), then places the worker at 8 start spots around the
## parked van in "return" state and watches whether main's
## walk-home routing (nose waypoint, then door) gets him in.
## Run: godot --headless --path . tests/VerifyPoundVan3.tscn

var main: Node = null
var player: Node = null
var passed: int = 0
var failed: int = 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("VANVERIFY3 PASS: ", name)
	else:
		failed += 1
		print("VANVERIFY3 FAIL: ", name, " -- ", detail)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(320, 200))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	park_npcs_far()
	var van: Node3D = main.get("pound_van")
	var worker: Node = main.get("pound_worker")

	# --- one real pullover for authentic stop geometry ----------
	main.set("player_collared", false)
	van.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	van.rotation.y = 0.0
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "patrol")
	main.set("pound_engage_cd", 0.0)
	(player as Node3D).global_position = van.position + Vector3(11.0, 0.2, 0.0)
	player.set("velocity", Vector3.ZERO)
	var g: float = 0.0
	while str(main.get("pound_state")) != "exit" and g < 15.0:
		await wait_sec(0.25)
		g += 0.25
	check("setup: real pullover reached exit state", str(main.get("pound_state")) == "exit", str(main.get("pound_state")))
	var stop_pos: Vector3 = van.position
	var kerb: Vector3 = main.get("pound_kerb_dir")
	# main's own convention: _pound_forward() = (cos(yaw), 0, -sin(yaw))
	var vyaw: float = float(main.get("pound_van_yaw"))
	var fwd: Vector3 = Vector3(cos(vyaw), 0, -sin(vyaw))
	var door: Vector3 = main.call("_pound_door_pos")
	print("VANVERIFY3 NOTE: stop_pos=", stop_pos, " kerb_dir=", kerb, " door=", door, " van yaw=", van.rotation.y)
	# park the cat far away so the return never re-engages
	(player as Node3D).global_position = Vector3(-100, 0.2, 80)
	worker.set("active", false)

	# --- the matrix ----------------------------------------------
	var spots: Array = [
		["rear-road-side", stop_pos - fwd * 5.0 - kerb * 2.0],
		["rear-kerb-side", stop_pos - fwd * 5.0 + kerb * 2.0],
		["front-road-side", stop_pos + fwd * 6.0 - kerb * 2.0],
		["front-kerb-side", stop_pos + fwd * 6.0 + kerb * 2.0],
		["directly-behind", stop_pos - fwd * 7.0],
		["suite-drop-off (fwd*1 - kerb*3)", stop_pos + fwd * 1.0 - kerb * 3.0],
		["far-road-side", stop_pos - kerb * 6.0],
		["far-kerb-rear", stop_pos + kerb * 6.0 - fwd * 2.0],
	]
	for s in spots:
		var label: String = s[0]
		var spot: Vector3 = s[1]
		spot.y = 0.3
		(worker as Node3D).global_position = spot
		worker.set("active", false)
		main.set("pound_state", "return")
		main.set("pound_engage_cd", 0.0)
		var t: float = 0.0
		var arrived: bool = false
		var trace: String = ""
		while t < 15.0:
			# pin the van at its stop (an arrival flips state to
			# patrol and the van would drive off mid-matrix)
			van.position = stop_pos
			main.set("pound_van_speed", 0.0)
			await wait_sec(0.5)
			t += 0.5
			if int(t) % 5 == 0:
				trace += " t" + str(int(t)) + "=" + str(snappedf((worker as Node3D).global_position.distance_to(door), 0.1))
			if str(main.get("pound_state")) == "patrol":
				arrived = true
				break
		print("VANVERIFY3 TRACE: ", label, " from ", spot, " door-dist trace:", trace, " final state=", str(main.get("pound_state")), " worker pos=", (worker as Node3D).global_position, " t_arrive=", (str(t) + "s" if arrived else "never"))
		check("return routing: " + label, arrived, "not in after 15s; worker at " + str((worker as Node3D).global_position))

	print("VANVERIFY3 TESTS: %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)
