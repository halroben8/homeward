extends Node
## HOMEWARD streets-cleanup before/after screenshots.
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerStreets.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerStreets.tscn -- after
## Identical staging for both runs (same hygiene as the population
## runner: neighbours held at spawn, notice pinned). One extra prop
## is staged identically in BOTH runs: a cream van built by the real
## _build_car on the Willow Park lawn, for the box-car close-up.
## In the AFTER run only, one real traffic car is also placed on
## Oak Avenue's eastbound lane to show traffic flowing on the
## cleared street (in the before build that lane is blocked by
## parked cars, which is the point of the shot).

const BASE := "/home/hatch/workspace/homeward/screenshots_streets"
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

func hold_npcs_at_spawn() -> void:
	for n in main.get("npcs"):
		n.set("notice_cooldown", 99999.0)
		n.set("wander_target", (n as Node3D).global_position)
		n.set("wander_wait", 999.0)
		n.set("velocity", Vector3.ZERO)

func stage(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	(player as Node3D).global_position = pos
	player.set("velocity", Vector3.ZERO)
	player.set("rotation", Vector3.ZERO)
	main.set("look_yaw", deg_to_rad(yaw_deg))
	main.set("look_pitch_deg", pitch_deg)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "before"
	if args.size() > 0:
		mode = args[0]
	OUT = BASE + "/" + mode
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1920, 864))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	hold_npcs_at_spawn()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	hold_npcs_at_spawn()
	player.set("idle_next_in", 999.0)

	# Close-up prop, identical in both runs: a cream van on the park
	# lawn (the current build's van vs the rebuilt van).
	main.call("_build_car", main.get_node("World"), Vector3(-38, 0, 30), Color(0.9, 0.88, 0.85), true, "van")

	if mode == "after":
		# One real traffic car flowing down the cleared Oak Avenue.
		var tc: Node3D = main.call("_build_car", main.get("traffic_group"), Vector3(26, 0, 16.8), Color(0.25, 0.45, 0.85), true, "sedan", true)
		(main.get("traffic_cars") as Array).append({"node": tc, "vel": Vector3(8, 0, 0)})

	# 1) OAK AVENUE — looking north across the road at the stretch
	# where three cars used to park on the asphalt (x 44/52/60).
	# (Viewpoint picked to keep the bus-stop board at x~30 and
	# 34 Oak's new driveway at x=48.6 out of the camera.)
	stage(Vector3(40, 0, 24.5), 0.0, 10.0)
	await wait_sec(1.1)
	await snap("oak_street.png")

	# 2) MAPLE STREET — looking north at the road where the red
	# sedan and cream van used to sit (x -8 and x 12).
	stage(Vector3(2, 0, -3.5), 0.0, 12.0)
	await wait_sec(1.1)
	await snap("maple_street.png")

	# 3) 27 MAPLE FRONT YARD / DRIVEWAY — before: plain lawn and
	# path; after: the red sedan parked in a driveway beside the path.
	stage(Vector3(-1.4, 0, -16.6), 0.0, 10.0)
	await wait_sec(1.1)
	await snap("driveway.png")

	# 4) VAN CLOSE-UP — the box-car test: three-quarter view of the
	# staged cream van on the park lawn.
	stage(Vector3(-33.8, 0, 33.8), 45.0, 12.0)
	await wait_sec(1.1)
	await snap("van_closeup.png")

	print("SHOTS DONE -> ", OUT)
	get_tree().quit(0)
