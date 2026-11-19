extends Node
## POUND FIX player-view runner (2026-11-18).
## Michael played v1.0.14 and reported the pound "looks just like
## the regular house — still the bookshelf, the window". The
## earlier shelter runners photographed the room with a FREE
## camera at flattering angles; this runner never touches the
## camera. It boots the real game, plays the opening into the
## pound cage, then stages the CAT at the waypoints a player
## actually occupies — waking in the cage, at the gate, crossing
## the room, facing the kennel row, facing the cage bank, at the
## back door — sets the follow camera's yaw the way a player's
## drag would (directly behind the cat's facing), lets the game's
## own camera settle, and photographs the viewport.
## Usage:  godot --path . tests/ShotRunnerPoundFix.tscn -- before
##         godot --path . tests/ShotRunnerPoundFix.tscn -- after
## Output: ~/workspace/homeward/screenshots_pound_fix/<mode>_NN.png
## Not part of the suite.

const OUT := "/home/hatch/workspace/homeward/screenshots_pound_fix"
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null
var story: Node = null
var mode: String = "before"

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + mode + "_" + name)
	print("SHOT: ", mode, "_", name, " ", img.get_size(), " cam=", (main.get("cam") as Camera3D).global_position, " yaw=", main.get("look_yaw"), " pitch=", main.get("look_pitch_deg"))

func stage(pos: Vector3, facing_yaw: float, cam_yaw: float) -> void:
	(player as Node3D).global_position = pos
	(player as Node3D).rotation.y = facing_yaw
	main.set("look_yaw", cam_yaw)
	await wait_sec(1.5) # let the game's own camera damp + pull-in settle

func wait_for_main(key: String, want: String, max_frames: int) -> bool:
	for i in range(max_frames):
		if str(main.get(key)) == want:
			return true
		await get_tree().process_frame
	print("RUNNER WAIT TIMEOUT: ", key, " != ", want)
	return false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
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
	await wait_sec(1.2)
	player = main.get("player")
	story = main.get("story")
	var o: Vector3 = main.get("escape_origin")
	main.call("dismiss_splash")
	main.call("start_game")
	for i in range(10):
		await get_tree().process_frame
	story.call("skip_opening")
	await wait_for_main("state", "escape", 3000)
	var guard: int = 0
	while not bool(story.get("cage_closed")) and guard < 600:
		await get_tree().process_frame
		guard += 1
	await wait_sec(1.5)

	# 01 — waking in the cage: exactly as the game leaves it.
	await snap("01_wake.png")

	# 02 — at the cage gate, facing it, camera behind the cat.
	var gate_p: Vector3 = story.call("cage_gate_pos")
	await stage(gate_p + Vector3(0, 0.3, 0.55), PI, 0.0)
	await snap("02_gate.png")

	# Out of the cage the real way (PAW), then the crossing views.
	main.call("_on_interact")
	await wait_sec(0.9)
	print("gate opened: ", not bool(story.get("cage_closed")))

	# 03 — mid-room on the mat, facing north (window / pet door wall).
	await stage(o + Vector3(0, 0.3, 2.0), PI, 0.0)
	await snap("03_crossing_north.png")

	# 04 — same spot, turned around: the kennel row behind him.
	await stage(o + Vector3(0, 0.3, 2.0), 0.0, PI)
	await snap("04_row_south.png")

	# 05 — mid-room west half, facing the west wall (cage bank).
	await stage(o + Vector3(-6.5, 0.3, 0.5), -PI / 2.0, PI / 2.0)
	await snap("05_bank_west.png")

	# 06 — at the back door, facing it (the bolt-door exit).
	await stage(o + Vector3(12.3, 0.3, 3.4), PI / 2.0, -PI / 2.0)
	await snap("06_backdoor.png")

	print("POUNDFIX RUNNER DONE mode=", mode)
	get_tree().quit(0)
