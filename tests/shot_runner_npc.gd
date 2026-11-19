extends Node
## HOMEWARD NPC-look screenshots (before/after pair).
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerNpc.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerNpc.tscn -- after
## Identical staging for both runs:
##   lineup_front / lineup_side — one of each person type (+ one
##     outfit variant) in a row on the south lawn.
##   expr_joy / expr_sad / expr_excited / expr_worried — face
##     close-ups of the Cat-Loving Young Woman, driven through the
##     real set_expression().
##   pet_player / pet_side — a REAL petting sequence (paw reaction),
##     snapped mid-pet: the kneel must read from the player's angle
##     and in profile.
##   carry_side — a REAL capture (on_cat_taken), snapped in the
##     cradle beat.
##   street_view — the game's own camera on a street corner with
##     neighbours staged on the sidewalk.
## Output: ~/workspace/homeward/screenshots_npc_look/<arg>/

const BASE := "/home/hatch/workspace/homeward/screenshots_npc_look"
var OUT := BASE + "/before"
var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func snap_with_cam(name: String, pos: Vector3, target: Vector3) -> void:
	# Freeze the game's camera driver for one frame (map-runner trick).
	main.set_process(false)
	await get_tree().process_frame
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())
	main.set_process(true)

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1

func pick_type(t: String, outfit: int = 0) -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == t and int(n.get("outfit_idx")) == outfit:
			return n
	return null

func hold(n: Node, pos: Vector3, yaw: float) -> void:
	(n as Node3D).global_position = pos
	(n as Node3D).rotation = Vector3(0, yaw, 0)
	n.set("velocity", Vector3.ZERO)
	n.set("wander_target", pos)
	n.set("wander_wait", 999.0)
	# The perf pass hides models >85m from the cat; a frozen NPC
	# never re-shows itself, so force visibility after staging.
	var m = n.get("model")
	if m != null:
		(m as Node3D).visible = true
	var dm = n.get("dog_model")
	if dm != null:
		(dm as Node3D).visible = true
	var nl = n.get("name_label")
	if nl != null:
		(nl as Node3D).visible = true

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = BASE + "/" + args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
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
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	park_npcs_far()

	var woman: Node = pick_type("woman", 0)
	var kid: Node = pick_type("kid", 0)
	var walker: Node = pick_type("dogwalker", 0)
	var shop: Node = pick_type("shopkeeper", 0)
	var ped: Node = pick_type("pedestrian", 0)
	var variant: Node = pick_type("woman", 2)
	var lineup: Array = [woman, kid, walker, shop, ped]
	if variant != null:
		lineup.append(variant)
	# Cat nearby (off-frame) so the distance-hiding keeps them shown.
	(player as Node3D).global_position = Vector3(52, 0.2, 89)
	player.set("velocity", Vector3.ZERO)
	# ---------- lineup, front then side ----------
	for i in range(lineup.size()):
		hold(lineup[i], Vector3(56.4 + float(i) * 1.8, 0.2, 84), 0.0)
		(lineup[i] as Node).set_physics_process(false)
	await wait_sec(0.3)
	await snap_with_cam("lineup_front.png", Vector3(60.5, 1.45, 90.8), Vector3(60.5, 0.92, 84))
	for i in range(lineup.size()):
		(lineup[i] as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	await wait_sec(0.2)
	await snap_with_cam("lineup_side.png", Vector3(67.2, 1.45, 84), Vector3(60.5, 0.92, 84))
	# ---------- expression close-ups (the woman, solo) ----------
	park_npcs_far()
	hold(woman, Vector3(48, 0.2, 84), 0.0)
	for e in ["joy", "sad", "excited", "worried"]:
		woman.call("set_expression", e)
		await wait_sec(0.25)
		await snap_with_cam("expr_" + e + ".png", Vector3(48, 1.62, 85.7), Vector3(48, 1.60, 84))
	woman.call("set_expression", "neutral")
	# ---------- petting: a real paw reaction, mid-pet ----------
	(woman as Node).set_physics_process(true)
	hold(woman, Vector3(61.1, 0.2, 84), -PI * 0.5)
	(player as Node3D).global_position = Vector3(60.2, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X, at her
	player.set("velocity", Vector3.ZERO)
	woman.set("interact_cooldown", 0.0)
	woman.set("notice_cooldown", 0.0)
	woman.call("react_to_attention")
	woman.set("interact_kind", "pet")
	var guard: float = 0.0
	while guard < 9.0:
		await wait_sec(0.15)
		guard += 0.15
		if str(woman.get("interact_state")) == "pet" and float(woman.get("bend_a")) > 0.85:
			break
	print("pet staging: state=", str(woman.get("interact_state")), " bend_a=", str(woman.get("bend_a")),
		" model_rot_x=", str((woman.get("model") as Node3D).rotation.x),
		" model_y=", str((woman.get("model") as Node3D).position.y))
	await snap_with_cam("pet_player.png", Vector3(59.1, 0.72, 85.7), Vector3(60.7, 0.5, 84))
	await snap_with_cam("pet_side.png", Vector3(60.6, 0.78, 87.3), Vector3(60.6, 0.48, 84))
	# ---------- capture carry: a real capture, cradle beat ----------
	park_npcs_far()
	(woman as Node).set_physics_process(true)
	hold(woman, Vector3(61.05, 0.2, 84), -PI * 0.5)
	woman.set("mode", "wander")
	woman.set("notice", 0.0)
	woman.set("grab_progress", 0.0)
	woman.call("set_expression", "neutral")
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	player.set("frozen", false)
	await wait_sec(0.35)
	main.call("on_cat_taken", woman)
	guard = 0.0
	while str(main.get("state")) == "cutscene" and float(main.get("cutscene_t")) < 2.8 and guard < 9.0:
		await wait_sec(0.03)
		guard += 0.03
	await snap_with_cam("carry_side.png", Vector3(63.6, 1.25, 87.2), Vector3(60.6, 0.95, 84))
	guard = 0.0
	while str(main.get("state")) == "cutscene" and guard < 8.0:
		await wait_sec(0.25)
		guard += 0.25
	if str(main.get("state")) == "escape":
		main.call("_complete_escape")
		(main.get("pursuers") as Dictionary).clear()
		woman.call("stop_pursuit")
		await wait_sec(0.3)
	# ---------- street view: the game's own camera ----------
	park_npcs_far()
	hold(ped, Vector3(56.3, 0.2, 20.6), PI * 0.75)
	hold(shop, Vector3(61.2, 0.2, 19.2), -PI * 0.6)
	(player as Node3D).global_position = Vector3(58, 0.2, 24)
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", 4.0)
	await wait_sec(0.8)
	await snap("street_view.png")
	print("DONE")
	get_tree().quit(0)
