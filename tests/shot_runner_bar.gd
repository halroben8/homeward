extends Node
## Notice / GRAB bar close-ups (2026-11-18, bar cleanup pass).
## Boots the real game, freezes it, and stages ONE grabber in front
## of a fixed camera two ways:
##   notice.png — mode "wander", notice = 0.50 (the 👀 build-up bar)
##   grab.png   — mode "chase", grab_progress at 50% (the ✋ GRAB bar)
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerBar.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerBar.tscn -- after
## Output: ~/workspace/homeward/screenshots_bar/<arg>/
## Not part of the suite.

const BASE := "/home/hatch/workspace/homeward/screenshots_bar"
const EmojiFont := preload("res://tests/emoji_font.gd")

var OUT := BASE + "/before"
var main: Node = null
var player: Node = null
var woman: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func pick_woman() -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman" and str(n.get("role")) == "grabber":
			return n
	return null

func park_npcs_far(except: Node) -> void:
	var i: int = 0
	for n in main.get("npcs"):
		if n == except:
			continue
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		(n as Node).set_physics_process(false)
		i += 1

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
	main.call("start_game") # the story stages the cat at his door
	await wait_sec(0.4)
	main.set_process(false) # freeze the world driver (story, camera)

	woman = pick_woman()
	park_npcs_far(woman)

	# Stage: an open lawn spot. Woman faces the camera (+Z), the cat
	# sits in the foreground with his back to us, as in real play.
	(woman as Node3D).global_position = Vector3(61.5, 0.2, 90.2)
	(woman as Node3D).rotation = Vector3(0, PI, 0)
	(player as Node3D).global_position = Vector3(63.4, 0.2, 90.8)
	(player as Node3D).rotation = Vector3(0, 0, 0) # face -Z, toward her
	player.set("idle_next_in", 999.0)
	player.set("velocity", Vector3.ZERO)
	player.set_physics_process(false)
	player.set_process(false)
	(woman as Node).set_physics_process(false)
	(woman as Node).set_process(false)

	# Fixed camera: front, a touch to the side, at label height.
	cam.global_position = Vector3(62.2, 2.2, 94.6)
	cam.look_at(Vector3(61.5, 2.0, 90.2), Vector3.UP)

	# --- 1: notice bar at 50% -------------------------------------
	woman.set("mode", "wander")
	woman.set("grab_progress", 0.0)
	woman.set("notice", 0.5)
	woman.call("_update_labels")
	await wait_sec(0.3)
	print("BARSHOT notice label_text='", (woman.get("notice_label") as Label3D).text, "'")
	await snap("notice.png")

	# --- 2: GRAB bar at 50% (mid-chase) ---------------------------
	woman.set("mode", "chase")
	woman.set("grab_progress", 0.75) # grab_needed 1.5 -> 50%
	woman.call("_update_labels")
	await wait_sec(0.3)
	print("BARSHOT grab label_text='", (woman.get("notice_label") as Label3D).text, "'")
	await snap("grab.png")

	print("DONE")
	get_tree().quit(0)
