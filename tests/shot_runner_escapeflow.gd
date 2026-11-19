extends Node
## HOMEWARD v1.4 — screenshot runner for the ESCAPE FLOW fixes.
## Boots the real game and stages, through the REAL flow:
##   (c) the cat carrier in the room as transport dressing only —
##       the cat free beside it, the escape hint pointing at the
##       BACK DOOR, no prompt/puzzle anywhere near the carrier;
##   (b) the back door: the PAW prompt at the door, then the PAW
##       itself opening the escape panel with the bolt picture;
##   (a) a full capture -> door escape -> walk-out with the look
##       controls wound up in the room (pitch 45, the reported
##       bug): the pursuit a moment later, at the restored town
##       framing — cat normal size, camera back down at town
##       height.
## Saves PNGs to ~/workspace/homeward/screenshots_escapeflow/.
## Not part of the suite.

const OUT := "/home/hatch/workspace/homeward/screenshots_escapeflow/"

var main: Node = null
var player: Node = null
var woman: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("saved ", name, " ", img.get_size())

func hide_hints() -> void:
	# The 7 s tutorial hint from start_game overlaps the escape
	# label in staged shots — hide it (HUD overlay only).
	var hl = main.get("hint_label")
	if hl:
		(hl as Control).visible = false
	main.set("hint_timer", -1.0)

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
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4) # beyond the back-door threshold
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)

func door_combo() -> void:
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1920, 864))
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
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman" and str(n.get("role")) == "grabber":
			woman = n
			break
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var o: Vector3 = main.get("escape_origin")

	# ---------- session 1: the room — carrier (c), door panel (b)
	main.set("captor", woman)
	main.call("_enter_escape")
	print("runner kinds=", str(main.call("current_escape_kinds")))
	# (c) the carrier: the cat stands FREE on the rug in front of
	# it, looking at it; the escape hint at the top of the screen
	# points at the back door, and no prompt appears at the
	# carrier — it is furniture, not a puzzle. (She is parked at
	# the far anchor so her greeting bubble leaves the frame.)
	hide_hints()
	(woman as Node3D).global_position = o + Vector3(11.6, 0.25, -4.5)
	main.set("captor_room_wait", 30.0)
	(player as Node3D).global_position = o + Vector3(-4.6, 0.3, 6.2)
	(player as Node3D).rotation = Vector3(0, -2.32, 0) # facing the carrier
	main.set("look_yaw", 0.82) # behind the cat, carrier beyond him
	main.set("look_pitch_deg", 10.0)
	await wait_sec(3.0) # her greeting bubble (2.6 s) expires too
	await snap("c_carrier_transport_only.png")
	# (b) at the back door: prompt first, then the PAW opens the
	# panel with the bolt picture.
	distract_captor()
	hide_hints()
	(player as Node3D).global_position = o + Vector3(13.4, 0.3, 3.4)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", 6.0)
	await wait_sec(0.8)
	await snap("b_door_prompt.png")
	main.call("_on_interact") # the PAW itself
	await wait_sec(0.4)
	await snap("b_door_panel_open.png")
	# finish this escape the intended way and drain the pursuit
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	walk_out()
	main.call("_process", 60.1)
	await wait_sec(0.3)

	# ---------- session 2: full capture -> escape -> pursuit (a)
	park_npcs_far()
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	player.set("frozen", false)
	(woman as Node3D).global_position = Vector3(61.05, 0.2, 84)
	(woman as Node3D).rotation = Vector3(0, -PI * 0.5, 0)
	woman.set("mode", "wander")
	await wait_sec(0.2)
	main.call("on_cat_taken", woman)
	await wait_sec(0.3)
	main.call("skip_cutscene")
	print("runner session2 state=", str(main.get("state")), " kinds=", str(main.call("current_escape_kinds")))
	# the reported bug's setup: look controls wound up in the room
	main.set("look_pitch_deg", 45.0)
	main.set("look_yaw", 2.2)
	distract_captor()
	(player as Node3D).global_position = o + Vector3(13.4, 0.3, 3.4)
	door_combo()
	print("runner exit_open=", str(main.get("exit_open")), " kind=", str(main.get("exit_open_kind")))
	walk_out()
	print("runner state after walk-out=", str(main.get("state")))
	# Snap early in the pursuit: she is a few metres behind him,
	# the chase cam framing BOTH at the restored town values.
	hide_hints()
	await wait_sec(0.45)
	print("runner pursuit cam: pitch=", str(main.get("look_pitch_deg")),
		" fov=", str((main.get("cam") as Camera3D).fov),
		" dist=", str(main.get("current_cam_dist")),
		" cam_pos=", str((main.get("cam") as Camera3D).global_position))
	await snap("a_pursuit_after_exit.png")
	print("ESCAPEFLOW SHOTS DONE")
	get_tree().quit(0)
