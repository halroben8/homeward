extends Node
## HOMEWARD v0.7 screenshot staging (run under Xvfb, NOT headless):
##   xvfb-run -a godot --path . tests/ShotRunner.tscn
## Captures the v0.7 proof shots into screenshots_v07/ at a wide,
## phone-like 1920x864 window (stretch/expand shows anchor behaviour).

const OUT := "/home/hatch/workspace/homeward/screenshots_v07"
const EmojiFont := preload("res://tests/emoji_font.gd")
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

func _ready() -> void:
	EmojiFont.apply() # render-only emoji fallback — before Main is instanced
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
	# 1) SPLASH at wide phone aspect: full-screen + centred (item 8)
	await snap("splash_wide.png")
	main.call("dismiss_splash")
	await wait_sec(0.4)
	await snap("title_wide.png")
	main.call("start_game")
	await wait_sec(0.5)
	# lively scoreboard for the gameplay shot (item 9)
	main.set("score", 12)
	main.set("pets_count", 2)
	main.set("treats_count", 1)
	main.call("_update_score_label")
	# 2) STREET SIGN face-on (item 3): Maple sign at (-58,0,-6), +Z face
	stage(Vector3(-58, 0, -0.5), 0.0, -5.0)
	await wait_sec(0.9)
	await snap("sign_front.png")
	# 3) same sign from BEHIND: text lives on the back face of the
	# board — nothing floats beside/behind it
	stage(Vector3(-58, 0, -11.5), 180.0, -5.0)
	await wait_sec(0.9)
	await snap("sign_back.png")
	# 4) and at an angle (the old billboard text hovered at angles)
	stage(Vector3(-53.5, 0, -1.5), 38.0, 0.0)
	await wait_sec(0.9)
	await snap("sign_angle.png")
	# 5) TREES close up (item 11): three fixed spots, mixed types
	stage(Vector3(-2, 0, -33.5), 0.0, 6.0)
	await wait_sec(0.9)
	await snap("tree_a.png")
	stage(Vector3(52, 0, -19.5), 0.0, 6.0)
	await wait_sec(0.9)
	await snap("tree_b.png")
	stage(Vector3(2, 0, 28.5), 180.0, 6.0)
	await wait_sec(0.9)
	await snap("tree_c.png")
	# 6) TRAFFIC on Oak Avenue (item 7): two cars mid-street
	var tg: Node = main.get("traffic_group")
	var c1: Node3D = main.call("_build_car", tg, Vector3(-16, 0, -9.2), Color(0.8, 0.25, 0.22), true, "sedan", true)
	var c2: Node3D = main.call("_build_car", tg, Vector3(30, 0, -12.8), Color(0.25, 0.45, 0.85), true, "hatchback", true)
	c2.rotation_degrees = Vector3(0, 180, 0)
	(main.get("traffic_cars") as Array).append({"node": c1, "vel": Vector3(8, 0, 0)})
	(main.get("traffic_cars") as Array).append({"node": c2, "vel": Vector3(-8, 0, 0)})
	stage(Vector3(4, 0, -1.0), 10.0, 12.0)
	await wait_sec(0.7)
	await snap("traffic.png")
	# 7) GAMEPLAY: bigger scoreboard, no minimap, no Sprint button
	stage(Vector3(4, 0, 6), -15.0, 16.0)
	await wait_sec(0.9)
	await snap("gameplay.png")
	# 8) CAT front (art pass evidence)
	stage(Vector3(4, 0, 6), 180.0, 14.0)
	await wait_sec(0.9)
	await snap("cat_front.png")
	# (v1.0.8: the old collar-zoom shot is gone — the collar check
	# itself was removed from the game.)
	print("SHOTS DONE")
	get_tree().quit(0)
