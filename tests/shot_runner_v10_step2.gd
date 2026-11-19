extends Node
## HOMEWARD v1.0 micro-step 2 (ART OVERHAUL) before/after screenshots.
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerV10Step2.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerV10Step2.tscn -- after
## Viewpoints are FIXED (same staging code for both runs) so each
## before/after pair is an honest comparison: cat front, cat side,
## a street, a house front, trees, and a resident mid-pet.

const BASE := "/home/hatch/workspace/homeward/screenshots_v10_step2"
var OUT := BASE + "/before"
var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func stage(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	(player as Node3D).global_position = pos
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", deg_to_rad(yaw_deg))
	main.set("look_pitch_deg", pitch_deg)

func npc_of(type: String, skip: Node = null) -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == type and n != skip:
			return n
	return null

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = BASE + "/" + args[0]
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
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	player.set("idle_next_in", 999.0)

	# 1) CAT FRONT — v0.9 staging.
	stage(Vector3(4, 0, 6), 180.0, 14.0)
	await wait_sec(0.9)
	await snap("cat_front.png")

	# 2) CAT SIDE — v0.9 staging.
	stage(Vector3(4, 0, 6), 90.0, 12.0)
	await wait_sec(0.9)
	await snap("cat_side.png")

	# 3) STREET — v0.9 street_ordered staging.
	stage(Vector3(-30, 0, 11), 0.0, 6.0)
	await wait_sec(1.0)
	await snap("street.png")

	# 4) HOUSE — cat on the path of 19 Oak Avenue, looking at its front.
	stage(Vector3(-6, 0, 10), 0.0, 16.0)
	await wait_sec(1.0)
	await snap("house.png")

	# 5) TREES — cat south of the leafy tree at (-14,0,-40), looking north.
	stage(Vector3(-14, 0, -33), 0.0, 8.0)
	await wait_sec(1.0)
	await snap("trees.png")

	# 6) PERSON — the v0.9 petting staging, snapped mid-stroke.
	var woman: Node = npc_of("woman")
	stage(Vector3(10, 0, 6), 205.0, 8.0)
	(woman as Node3D).global_position = Vector3(12.1, 0.2, 7.2)
	woman.set("interact_cooldown", 0.0)
	woman.set("joy_shown", false)
	await wait_sec(0.3)
	main.call("_paw_action")
	woman.set("interact_kind", "pet")
	await wait_sec(2.4)
	await snap("person_pet.png")

	print("SHOTS DONE -> ", OUT)
	get_tree().quit(0)
