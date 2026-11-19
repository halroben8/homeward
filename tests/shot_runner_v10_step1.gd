extends Node
## HOMEWARD v1.0 micro-step 1 (town fill) screenshots — run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerV10Step1.tscn
## Viewpoints are the areas Michael's v0.9 playtest showed as bare
## grass: the north riverside band, the NE corner, the west Oak band,
## the south strip behind Willow, and the east market block.

const OUT := "/home/hatch/workspace/homeward/screenshots_v10_step1"
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

	# 0) OVERHEAD of the whole town (fill proof).
	main.set_process(false)
	var cam: Camera3D = main.get("cam")
	cam.global_position = Vector3(0, 165, 55)
	cam.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	await wait_sec(0.6)
	await snap("map_overview.png")
	main.set_process(true)
	await wait_sec(0.4)

	# 1) North band: promenade + café, looking north to the river.
	stage(Vector3(-30, 0, -70), 0.0, 8.0)
	await wait_sec(1.0)
	await snap("promenade_cafe.png")

	# 2) NE corner: Riverside Court apartments + parking, looking north.
	stage(Vector3(96, 0, -57), 0.0, 8.0)
	await wait_sec(1.0)
	await snap("riverside_court_ne.png")

	# 3) West Oak band: West End Foods + park entrance, looking south.
	stage(Vector3(-100, 0, 12), 180.0, 8.0)
	await wait_sec(1.0)
	await snap("west_end_shops.png")

	# 4) South band: Willow Hall + sheds, looking south from Willow Cres.
	stage(Vector3(24, 0, 62), 180.0, 8.0)
	await wait_sec(1.0)
	await snap("south_band_hall.png")

	# 5) SE block: Willow Green fountain park, from its south edge
	# looking north across the fountain to the Willow houses.
	stage(Vector3(100, 0, 88), 0.0, 8.0)
	await wait_sec(1.0)
	await snap("willow_green_se.png")

	# 6) East market row stalls, looking south down the row.
	stage(Vector3(97, 0, -31), 180.0, 8.0)
	await wait_sec(1.0)
	await snap("market_row_east.png")

	# 7) Riverside corner: bakery + parking, looking south.
	stage(Vector3(62, 0, -15), 180.0, 8.0)
	await wait_sec(1.0)
	await snap("bakery_riverside.png")

	print("SHOTS DONE")
	get_tree().quit(0)
