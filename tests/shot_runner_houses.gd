extends Node
## HOUSE VARIETY screenshots (v1.0.14): rows of houses down four
## streets, staged identically for the before/after runs.
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerHouses.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerHouses.tscn -- after
## The world is frozen after the build (main._process off, actors'
## physics off) and the camera is placed by hand, so both runs frame
## exactly the same rows — only the houses themselves change.

const BASE := "/home/hatch/workspace/homeward/screenshots_houses"
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
	print("SHOT: ", name, " ", img.get_size(), " draw_calls=", int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))

func view(pos: Vector3, target: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await wait_sec(0.6)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "before"
	if args.size() > 0:
		mode = args[0]
	OUT = BASE + "/" + mode
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(1.2)
	player = main.get("player")
	cam = main.get("cam")
	print("HOUSES build done, state=", str(main.get("state")))
	main.call("dismiss_splash")
	main.call("start_game")
	await get_tree().process_frame
	await get_tree().process_frame
	# Freeze the world so the staged camera is the only thing moving.
	main.set_process(false)
	for layer_name in ["hud_layer", "touch_layer", "escape_ui_layer"]:
		var layer: CanvasLayer = main.get(layer_name)
		if layer:
			layer.visible = false
	var i: int = 0
	for n in main.get("npcs"):
		var nd := n as Node3D
		nd.global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		(n as Node).set_physics_process(false)
		i += 1
	var van: Node3D = main.get("pound_van")
	if van:
		van.global_position = Vector3(500, 0, 500)
	(player as Node).set_physics_process(false)
	(player as Node3D).global_position = Vector3(0, 0, 120)

	# 1) MAPLE STREET north row (fronts face +Z): 15 / 21 / 27 Maple.
	await view(Vector3(-26, 5.0, -10), Vector3(-18, 2.0, -30))
	await snap("maple_row.png")
	# 2) OAK AVENUE south row (fronts face -Z): 22 / 28 / 34 Oak.
	await view(Vector3(2, 5.0, 13), Vector3(-6, 2.0, 33))
	await snap("oak_row.png")
	# 3) WILLOW CRESCENT north row (fronts face +Z): 11 / 17 Willow.
	await view(Vector3(-26, 5.0, 68), Vector3(-16, 2.0, 44))
	await snap("willow_row.png")
	# 4) ELM DRIVE north row (fronts face +Z): 11 / 17 Elm.
	await view(Vector3(-30, 5.5, -42), Vector3(-18, 2.0, -66))
	await snap("elm_row.png")
	# 5) CLOSE-UP: 27 Maple's front, for shell/dressing detail.
	await view(Vector3(-13, 3.2, -17), Vector3(-6, 2.2, -30))
	await snap("maple_close.png")

	print("SHOTS DONE -> ", OUT)
	get_tree().quit(0)
