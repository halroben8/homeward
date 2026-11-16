extends Node
## HOMEWARD cat rebuild (splash-match) before/after screenshots.
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerCatV11.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerCatV11.tscn -- after
## FIXED staging, identical for both runs: front face view, side
## view, and the normal in-game behind view.

const BASE := "/home/hatch/workspace/homeward/screenshots_cat_v11"
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
	player.set("rotation", Vector3.ZERO)
	main.set("look_yaw", deg_to_rad(yaw_deg))
	main.set("look_pitch_deg", pitch_deg)

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
	await wait_sec(1.2)
	player = main.get("player")
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	player.set("idle_next_in", 999.0)

	# 1) FRONT — camera in front of the cat (yaw 0 = camera on the
	# side the cat faces), low pitch so the face fills the frame.
	stage(Vector3(4, 0, 6), 0.0, 7.0)
	await wait_sec(1.1)
	await snap("cat_front.png")

	# 2) SIDE — profile view.
	stage(Vector3(4, 0, 6), 90.0, 10.0)
	await wait_sec(1.1)
	await snap("cat_side.png")

	# 3) BEHIND — the normal in-game view while playing.
	stage(Vector3(4, 0, 6), 180.0, 14.0)
	await wait_sec(1.1)
	await snap("cat_behind.png")

	print("SHOTS DONE -> ", OUT)
	get_tree().quit(0)
