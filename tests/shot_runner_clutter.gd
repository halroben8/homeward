extends Node
## HOMEWARD street-clutter before/after screenshots.
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerClutter.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerClutter.tscn -- after
## Identical staging for both runs (neighbours held at spawn).
## Views: (1) the bench that stood centred on Cedar Street in the
## Elm-south front gardens, (2) the THREE-mailbox cluster in the
## Elm-north front gap by Cedar, (3) the Willow back fence crossing
## the Cedar Street corridor at z=73.

const BASE := "/home/hatch/workspace/homeward/screenshots_clutter"
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

	# 1) CEDAR STREET BENCH — camera on Cedar St north of the
	# Elm-south front gardens, looking south: before, a bench sits
	# centred on the Cedar centreline at (-20,-47); after, it rests
	# on the grass verge west of the road at (-27,-47).
	stage(Vector3(-23.5, 0, -40.0), 0.0, 10.0)
	await wait_sec(1.1)
	await snap("bench_on_cedar.png")

	# 2) TRIPLE MAILBOXES — the Elm-north front-gap cluster at
	# (-29.4,-59.6): three boxes in a row. After: the cluster's
	# mailboxes are gone (every house keeps exactly its own one).
	stage(Vector3(-29.4, 0, -54.0), 0.0, 8.0)
	await wait_sec(1.1)
	await snap("mailboxes_triple.png")

	# 3) WILLOW BACK FENCE — looking south down the Cedar corridor
	# at the fence run along z=73: before, it crosses the roadway;
	# after, it stops at the road's edge.
	stage(Vector3(-20.0, 0, 67.0), 180.0, 10.0)
	await wait_sec(1.1)
	await snap("fence_crossing.png")

	print("SHOTS DONE -> ", OUT)
	get_tree().quit(0)
