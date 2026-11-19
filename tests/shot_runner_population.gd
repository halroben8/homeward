extends Node
## HOMEWARD population step before/after screenshots.
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerPopulation.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerPopulation.tscn -- after
## FIXED staging, identical for both runs: the cat is placed at four
## town viewpoints (market row, riverside promenade/cafe, playground,
## Willow Green) and the shot is taken ~1s after staging. Staging
## holds every neighbour at its spawn point (wander target set to
## its own position + a long wait, velocity zeroed) so the before
## and after runs differ ONLY by who was spawned — free wander made
## the tight 1.45m-orbit framing a lottery. NPC notice cooldowns
## are pinned (same hygiene as PerfProbe) so no chase or capture
## can drag the cat out of frame mid-shot.

const BASE := "/home/hatch/workspace/homeward/screenshots_population"
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
	hold_npcs_at_spawn()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	hold_npcs_at_spawn()
	player.set("idle_next_in", 999.0)

	# 1) MARKET ROW — front-style view (yaw 0): camera on the side the
	# cat faces, stalls at z=-21 in the background behind him. Cat is
	# offset west so the market shopkeeper (97,-17) isn't directly
	# behind his head.
	stage(Vector3(94, 0, -11), 0.0, 20.0)
	await wait_sec(1.1)
	await snap("market_row.png")

	# 2) RIVERSIDE PROMENADE / CAFE — same front-style view toward the
	# cafe at (-30,-86) and the promenade path at z=-85. Lower pitch
	# and a longer gap than the market view: at pitch 20 a standing
	# person 4m behind the cat was cropped to her ankles by the top
	# of the frame; pitch 8 from 7m back keeps her fully in frame.
	stage(Vector3(-40, 0, -76), 0.0, 8.0)
	await wait_sec(1.1)
	await snap("promenade_cafe.png")

	# 3) PLAYGROUND — behind view (yaw 180) looking +Z into the
	# playground block (z 22..37).
	stage(Vector3(97, 0, 15), 180.0, 16.0)
	await wait_sec(1.1)
	await snap("playground.png")

	# 4) WILLOW GREEN — side view from the park's west path end
	# (91,76) looking along the cross path toward the fountain at
	# (100,76). NOTE: (100,65) is inside the 24 Willow Crescent
	# house footprint — the park proper starts south of z=71.
	stage(Vector3(91, 0, 76), -90.0, 14.0)
	await wait_sec(1.1)
	await snap("willow_green.png")

	print("SHOTS DONE -> ", OUT)
	get_tree().quit(0)
