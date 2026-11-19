extends Node
## HOMEWARD PURSUIT-CAM PROBE (diagnostic — not part of the game).
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/PursuitCamProbe.tscn
## Reproduces Michael's v1.0.7 + v1.0.12 real-play report: after
## escaping the house, the camera sits far too high/far and the cat
## is a tiny dot for the WHOLE pursuit, recovering only when the
## pursuit ends. The v1.4 EscapeFlowProbe staged the exit with the
## captor placed close and the cat stationary — it never opened the
## one gap real play always opens: the cat SPRINTS away (11.5) from
## a pursuer who runs at ~6.5, so she falls tens of metres behind
## while her mode stays "pursue" for the full timer. This probe
## plays the real path — real capture (grab hold), cutscene skip,
## room with the look dragged up high, distraction, panel combo,
## player walk-out — then sprints away through the real joystick +
## RUN hold, re-aiming away from her every 0.25 s, and reports
## camera distance / height / the cat's projected frame share plus
## the cat<->pursuer gap at every stage, including while she
## closes back in on the stopped cat.

var main: Node = null
var player: Node = null
var woman: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func cat_share() -> float:
	var a := AABB()
	var first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		a = ga if first else a.merge(ga)
		first = false
	var base: Vector3 = (player as Node3D).global_position
	var bot: Vector2 = cam.unproject_position(Vector3(base.x, a.position.y, base.z))
	var top: Vector2 = cam.unproject_position(Vector3(base.x, a.position.y + a.size.y, base.z))
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return absf(bot.y - top.y) / vp.y

func report(tag: String) -> void:
	var cp: Vector3 = (player as Node3D).global_position
	var gap: float = -1.0
	var wmode: String = "-"
	if woman:
		gap = (woman as Node3D).global_position.distance_to(cp)
		wmode = str(woman.get("mode"))
	var pleft: float = -1.0
	var purs: Dictionary = main.get("pursuers")
	if purs.has(woman):
		pleft = float(purs[woman])
	print("PCAM ", tag,
		" state=", str(main.get("state")),
		" pitch=", snappedf(float(main.get("look_pitch_deg")), 0.1),
		" fov=", snappedf(cam.fov, 0.1),
		" dist=", snappedf(float(main.get("current_cam_dist")), 0.01),
		" chase_cam=", str(main.get("chase_cam_active")),
		" cam_h_above_cat=", snappedf(cam.global_position.y - cp.y, 0.01),
		" cam_dist_to_cat=", snappedf(cam.global_position.distance_to(cp), 0.01),
		" cat_share=", snappedf(cat_share(), 0.03),
		" gap=", snappedf(gap, 0.1),
		" captor_mode=", wmode,
		" pursuit_left=", snappedf(pleft, 0.1))

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		if n == woman:
			continue
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func distract_captor() -> void:
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1

func walk_out() -> void:
	var kind: String = str(main.get("exit_open_kind"))
	var o: Vector3 = main.get("escape_origin")
	match kind:
		"latch", "winpush":
			(player as Node3D).global_position = o + Vector3(0, 0.3, -11.2)
		"petdoor", "carrier":
			(player as Node3D).global_position = o + Vector3(6, 0.3, -11.2)
		"bolt":
			(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)

func aim_away() -> void:
	# Full-push joystick directly away from the captor, through the
	# real input path (main._apply_joystick -> player.touch_dir).
	var cp: Vector3 = (player as Node3D).global_position
	var wp: Vector3 = (woman as Node3D).global_position
	var away := Vector3(cp.x - wp.x, 0, cp.z - wp.z)
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	var yaw: float = float(player.get("cam_yaw"))
	var b: Vector3 = Basis(Vector3.UP, -yaw) * away
	var dir2 := Vector2(b.x, b.z).normalized()
	main.set("joy_mouse", true)
	main.set("joy_origin", Vector2(200, 400))
	main.set("joy_current", Vector2(200, 400) + dir2 * 85.0)

func clear_joy() -> void:
	main.set("joy_mouse", false)
	main.set("joy_id", -999)

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var _bw: int = 0
	while not bool(main.get("build_complete")) and _bw < 21600:
		await get_tree().process_frame
		_bw += 1
	await wait_sec(1.2)
	player = main.get("player")
	cam = main.get("cam")
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman" and str(n.get("role")) == "grabber":
			woman = n
			break
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)

	# ---- BASELINE A: plain town view, no chase.
	(player as Node3D).global_position = Vector3(40, 0.2, 60)
	await wait_sec(1.0)
	report("BASELINE plain town")

	# ---- BASELINE B: ordinary town chase, chaser CLOSE behind.
	(woman as Node3D).global_position = Vector3(36, 0.2, 56)
	woman.set("mode", "chase")
	await wait_sec(1.2)
	report("BASELINE town chase (chaser close)")
	woman.set("mode", "wander")
	await wait_sec(0.5)

	# ---- REAL CAPTURE: she grabs and HOLDS the cat (the real
	# on_cat_taken path), cutscene, skip -> escape room.
	(player as Node3D).global_position = Vector3(40, 0.2, 60)
	(woman as Node3D).global_position = Vector3(39.2, 0.2, 59.2)
	woman.set("mode", "chase")
	var guard: int = 0
	while str(main.get("state")) != "cutscene" and guard < 40:
		await wait_sec(0.25)
		guard += 1
	print("PCAM capture state=", str(main.get("state")), " (guard=", guard, ")")
	await wait_sec(1.2)
	main.call("skip_cutscene")
	print("PCAM after skip state=", str(main.get("state")), " kinds=", str(main.call("current_escape_kinds")))
	# The player hunts around the room: pitch wound up high.
	main.set("look_pitch_deg", 45.0)
	main.set("look_yaw", 2.2)
	await wait_sec(1.0)
	report("IN ROOM after look drags (pitch 45)")
	# Play the escape for real: distract, panel combo, walk out.
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4) # at the back door
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	print("PCAM exit_open=", str(main.get("exit_open")), " kind=", str(main.get("exit_open_kind")))
	walk_out()
	print("PCAM state after walk-out=", str(main.get("state")))
	await wait_sec(0.3)
	report("JUST AFTER EXIT (+0.3s)")

	# ---- SPRINT AWAY through the real joystick + RUN hold.
	main.call("_on_run_hold", true)
	print("PCAM run_on=", str(main.get("run_on")))
	for step in range(24):
		aim_away()
		await wait_sec(0.25)
		if step % 4 == 3:
			report("SPRINT t=%.0fs" % (float(step + 1) * 0.25))
		if str(main.get("state")) != "play":
			print("PCAM sprint aborted, state=", str(main.get("state")))
			break
	# ---- STOP: she closes back in on the stationary cat.
	clear_joy()
	if bool(main.get("run_on")):
		main.call("_on_run_hold", false)
	for step2 in range(6):
		await wait_sec(1.0)
		report("WAIT t=%.0fs (she closes in)" % float(step2 + 1))
		if str(main.get("state")) != "play":
			print("PCAM wait aborted, state=", str(main.get("state")))
			break
		if woman and (woman as Node3D).global_position.distance_to((player as Node3D).global_position) < 2.5:
			print("PCAM she has arrived (gap < 2.5)")
			break
	# ---- Drain the pursuit and settle.
	main.call("_process", 65.0)
	await wait_sec(1.2)
	report("AFTER PURSUIT DRAINED (+settle)")
	print("PCAM DONE")
	get_tree().quit(0)
