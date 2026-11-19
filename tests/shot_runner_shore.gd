extends Node
## SHORELINE ACCESS probe (v1.0.14): drives the REAL cat from
## town streets out to the island shore at N/E/S/W and confirms
## the ONLY stop left is the shore collision at the waterline.
## Run headless:
##   godot --headless --path . tests/ShotRunnerShore.tscn
## Reaches free play through the game's own flow (splash ->
## opening skip -> cage paw -> bolt-door escape -> walk out),
## parks the NPCs and holds the pound van off, then for each
## compass point: teleport to a street inside the OLD border,
## hold the joystick toward the sea, and wait for the walk to
## stall against the shore wall. PASS per direction requires:
##   - he crossed the old town-border line (x +/-119.8 / z +/-92)
##   - his centre stops 1.0..4.6 m short of the waterline
##     (measured against main.island_waterline_pts)
##   - 3 more seconds of pushing moves him < 0.4 m (no swimming)
##   - he never fell (min y > -1.3) and ends standing on the
##     beach/apron (final y in [-0.8, 0.15])

var main: Node = null
var player: Node = null
var failures: int = 0

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func set_joy(vec: Vector2) -> void:
	main.set("joy_mouse", true)
	main.set("joy_origin", Vector2(200, 400))
	main.set("joy_current", Vector2(200, 400) + vec)

func clear_joy() -> void:
	main.set("joy_mouse", false)
	main.set("joy_id", -999)

func report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("SHOREPROBE ", label, ": ", "PASS" if ok else "FAIL", " -- ", detail)

func dist_to_waterline(p: Vector2, pts: Array) -> float:
	var best: float = 1e9
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var ab: Vector2 = b - a
		var t: float = 0.0
		if ab.length_squared() > 0.0:
			t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

func steer_toward(wdir: Vector2) -> void:
	# Movement is camera-yaw-relative (main publishes cam_yaw to
	# the cat every frame), so a fixed joystick vector curves as
	# the follow camera swings behind the cat. Recompute the
	# joystick vector from the CURRENT cam_yaw so the cat's world
	# direction stays the one we asked for.
	var cy: float = float(player.get("cam_yaw"))
	var d3: Vector3 = Basis(Vector3.UP, -cy) * Vector3(wdir.x, 0, wdir.y)
	var d2 := Vector2(d3.x, d3.z)
	if d2.length() > 0.01:
		main.set("joy_mouse", true)
		main.set("joy_origin", Vector2(200, 400))
		main.set("joy_current", Vector2(200, 400) + d2.normalized() * 85.0)

func drive_to_shore(label: String, start: Vector3, wdir: Vector2, cross_axis: String, cross_sign: float, wl_pts: Array) -> void:
	(player as Node3D).global_position = start
	player.set("velocity", Vector3.ZERO)
	await wait_sec(0.4)
	steer_toward(wdir)
	var last_pos: Vector3 = (player as Node3D).global_position
	var stall_t: float = 0.0
	var elapsed: float = 0.0
	var min_y: float = 99.0
	var stopped: bool = false
	while elapsed < 120.0:
		await wait_sec(0.25)
		elapsed += 0.25
		steer_toward(wdir)
		var p: Vector3 = (player as Node3D).global_position
		min_y = minf(min_y, p.y)
		if p.distance_to(last_pos) < 0.08:
			stall_t += 0.25
			if stall_t >= 3.0:
				stopped = true
				break
		else:
			stall_t = 0.0
		last_pos = p
	var stop_pos: Vector3 = (player as Node3D).global_position
	# Keep pushing: he must NOT advance into the water.
	for i in range(12):
		await wait_sec(0.25)
		steer_toward(wdir)
	var drift: float = (player as Node3D).global_position.distance_to(stop_pos)
	clear_joy()
	await wait_sec(0.3)
	var fin: Vector3 = (player as Node3D).global_position
	var wl_d: float = dist_to_waterline(Vector2(fin.x, fin.z), wl_pts)
	var crossed: float = (fin.x if cross_axis == "x" else fin.z) * cross_sign
	report(label + " crossed old border", crossed > (121.0 if cross_axis == "x" else 93.5), "final=%s crossed=%.1f" % [fin, crossed])
	report(label + " stopped at shore wall", stopped and wl_d >= 1.0 and wl_d <= 4.6, "stopped=%s waterline_dist=%.2f final=%s" % [stopped, wl_d, fin])
	report(label + " cannot enter water", drift < 0.4, "drift=%.2f" % drift)
	report(label + " never fell / stands on shore", min_y > -1.3 and fin.y >= -0.8 and fin.y <= 0.15, "min_y=%.2f final_y=%.2f" % [min_y, fin.y])

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var _bw: int = 0
	while not bool(main.get("build_complete")) and _bw < 21600:
		await get_tree().process_frame
		_bw += 1
	await wait_sec(0.5)
	player = main.get("player")
	# ---- reach free play through the game's own flow -------------
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	# Distract the captor (the intended path), then the bolt door.
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	(player as Node3D).global_position = Vector3(560, 0.3, 0) + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	await wait_sec(0.5)
	report("reached free play", str(main.get("state")) == "play", "state=%s" % str(main.get("state")))
	# ---- hold off the town's actors -------------------------------
	var worker: Node = main.get("pound_worker")
	if worker != null:
		worker.call("stop_pursuit")
		(main.get("pursuers") as Dictionary).erase(worker)
		worker.set("active", false)
		(worker as Node3D).visible = false
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_state", "patrol")
	var npcs: Array = main.get("npcs")
	for i in range(npcs.size()):
		(npcs[i] as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
	# ---- the four drives -------------------------------------------
	var wl_pts: Array = main.get("island_waterline_pts")
	print("SHOREPROBE: waterline points=", wl_pts.size())
	await drive_to_shore("EAST", Vector3(100, 0.2, 15), Vector2(1, 0), "x", 1.0, wl_pts)
	await drive_to_shore("WEST", Vector3(-100, 0.2, 15), Vector2(-1, 0), "x", -1.0, wl_pts)
	await drive_to_shore("NORTH", Vector3(24, 0.2, -55), Vector2(0, -1), "z", -1.0, wl_pts)
	await drive_to_shore("SOUTH", Vector3(24, 0.2, 55), Vector2(0, 1), "z", 1.0, wl_pts)
	print("SHOREPROBE DONE failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
