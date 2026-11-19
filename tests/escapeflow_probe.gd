extends Node
## HOMEWARD ESCAPEFLOW PROBE (diagnostic — not part of the game).
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/EscapeFlowProbe.tscn
## Reproduces Michael's v1.0.6 playtest report: "When I escaped I
## was high up in the air and super small. And it didn't return to
## normal." Boots the real Main scene, measures a NORMAL town chase
## framing as the baseline, then plays a full capture -> escape ->
## exit with the look controls dragged around the room the way a
## player hunting for the exit does (pitch wound up high), and
## prints every camera parameter + the cat's projected frame share
## at each stage: room / just after exit / mid-pursuit / after the
## pursuit drains. Whichever parameters fail to return to the town
## values are the leak.

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

func cat_drawn_height() -> float:
	var a := AABB()
	var first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		a = ga if first else a.merge(ga)
		first = false
	return a.size.y

func report(tag: String) -> void:
	var cp: Vector3 = (player as Node3D).global_position
	print("EFLOW ", tag,
		" state=", str(main.get("state")),
		" pitch=", snappedf(float(main.get("look_pitch_deg")), 0.1),
		" yaw=", snappedf(float(main.get("look_yaw")), 0.01),
		" fov=", snappedf(cam.fov, 0.1),
		" dist=", snappedf(float(main.get("current_cam_dist")), 0.01),
		" chase_cam=", str(main.get("chase_cam_active")),
		" cam_pos=", cam.global_position,
		" cam_h_above_cat=", snappedf(cam.global_position.y - cp.y, 0.01),
		" cam_dist_to_cat=", snappedf(cam.global_position.distance_to(cp), 0.01),
		" cat_share=", snappedf(cat_share(), 0.03),
		" cat_drawn_h=", snappedf(cat_drawn_height(), 0.02))

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
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

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	# v1.0.9 harness plumbing: Main now builds its world across frames
	# behind the splash — wait for build_complete before driving it,
	# exactly as the title flow does. No assertion is changed.
	var _bw109: int = 0
	while not bool(main.get("build_complete")) and _bw109 < 21600:
		await get_tree().process_frame
		_bw109 += 1
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

	# ---- BASELINE: an ordinary town chase at the shipped defaults.
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", 4.0)
	(woman as Node3D).global_position = Vector3(55, 0.2, 84)
	woman.set("mode", "chase")
	await wait_sec(1.2)
	report("BASELINE town chase (pitch 4)")
	woman.set("mode", "wander")
	park_npcs_far()
	await wait_sec(1.2)
	report("BASELINE plain town view")

	# ---- THE REPORTED FLOW: capture -> room -> escape -> pursuit.
	main.set("captor", woman)
	main.call("_enter_escape")
	print("EFLOW picked kinds=", str(main.call("current_escape_kinds")))
	# The player drags the look around the room hunting for the exit:
	# pitch wound UP (camera high, looking down) and yaw swung round.
	main.set("look_pitch_deg", 45.0)
	main.set("look_yaw", 2.2)
	await wait_sec(1.0)
	report("IN ROOM after look drags (pitch 45)")
	# Play the escape for real: distract, panel combo, walk out.
	distract_captor()
	var kind0: String = str(main.call("current_escape_kinds")[0])
	var exitp: Vector3 = main.call("_escape_exit_pos", kind0)
	(player as Node3D).global_position = exitp + Vector3(0, 0.3 - exitp.y, 0) + Vector3(0, 0, 0)
	(player as Node3D).global_position.y = 0.3
	# (winpush is a second working of the window — drive until open)
	var guard2: int = 0
	while not bool(main.get("exit_open")) and guard2 < 3:
		main.call("_on_escape_prompt_pressed")
		for inp in ["down", "up", "down", "up", "paw"]:
			main.call("escape_panel_input", inp)
		guard2 += 1
	print("EFLOW exit_open=", str(main.get("exit_open")), " kind=", str(main.get("exit_open_kind")))
	walk_out()
	print("EFLOW state after walk-out=", str(main.get("state")))
	await wait_sec(0.3)
	report("JUST AFTER EXIT (+0.3s, pursuit running)")
	await wait_sec(1.2)
	report("MID-PURSUIT (+1.5s)")
	main.call("_process", 60.1) # drain the pursuit the way 60 s does
	await wait_sec(1.2)
	report("AFTER PURSUIT DRAINED (+settle)")
	print("EFLOW DONE")
	get_tree().quit(0)
