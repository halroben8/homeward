extends Node
## Worn-collar close-up runner (2026-11-18, collar realism pass).
## Boots the real game to the title (the cat stands at spawn wearing
## his collar), freezes main, and frames the collar two ways:
##   worn_front34.png — front three-quarter: strap, buckle, D-ring
##                      and the tag hanging at his chest in context
##   worn_tag.png     — tight on the tag: the "Zander" print
## Run under Xvfb, passing the output subfolder as the last arg:
##   xvfb-run -a godot --path . tests/ShotRunnerCollar.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerCollar.tscn -- after
## Output: ~/workspace/homeward/screenshots_collar_new/<arg>/
## Not part of the suite.

const BASE := "/home/hatch/workspace/homeward/screenshots_collar_new"
const EmojiFont := preload("res://tests/emoji_font.gd")

var OUT := BASE + "/before"
var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap_with_cam(name: String, pos: Vector3, target: Vector3) -> void:
	await get_tree().process_frame
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = BASE + "/" + args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	EmojiFont.apply()
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(1.0)
	player = main.get("player")
	cam = main.get("cam")
	main.call("dismiss_splash")
	await wait_sec(2.6) # title settles; the boot readout hides
	main.call("start_game") # title panel leaves; the story stages him at his door
	await wait_sec(0.4)
	player.set("idle_next_in", 999.0)
	player.set("velocity", Vector3.ZERO)
	# Freeze EVERYTHING before reading positions: the cat's own
	# physics keeps turning him toward any stale move direction
	# the staging left behind, which swung earlier takes around.
	player.set_physics_process(false)
	player.set_process(false)
	main.set_process(false) # the story ticks from main._process

	var neck: Vector3 = player.call("get_neck_global_pos")
	var tagp: Vector3 = player.call("get_tag_global_pos")
	# Frame off the tag's own facing — the model wrapper's basis
	# made local-space offsets land in surprising places.
	var fwd: Vector3 = player.call("get_tag_facing")
	fwd.y = 0.0
	fwd = fwd.normalized()
	# His own right side (local +X — where the buckle sits), from
	# the player basis: fwd x up flips with his world yaw.
	var side: Vector3 = (player as Node3D).global_transform.basis.x
	side.y = 0.0
	side = side.normalized()
	print("RUNNER neck=", neck, " tag=", tagp, " fwd=", fwd,
		" collar_visible=", str(player.call("is_collar_visible")))

	# A — front three-quarter off his right side: the strap around
	# the neck, the buckle on the near side, the tag at his chest.
	await snap_with_cam("worn_front34.png",
		neck + fwd * 0.30 + side * 0.26 + Vector3(0, 0.07, 0),
		neck + fwd * 0.02 + Vector3(0, -0.075, 0))
	# B — tight on the tag, straight down its facing.
	await snap_with_cam("worn_tag.png",
		tagp + (player.call("get_tag_facing") as Vector3) * 0.20 + Vector3(0, 0.025, 0),
		tagp)
	print("COLLAR SHOTS DONE -> ", OUT)
	get_tree().quit(0)
