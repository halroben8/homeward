extends Node
## HOMEWARD v0.9 screenshot staging (run under Xvfb, NOT headless):
##   xvfb-run -a godot --path . tests/ShotRunnerV09.tscn
## Comparison shots reuse v0.8's EXACT staging (cat close-ups,
## street_ordered, street_clear, sharpness pair) so v0.8-vs-v0.9
## composites are honest. New: petting sequence, treat sequence,
## filled districts (Elm south row, Willow/playground, garden),
## and a manual-camera overhead of the whole town.

const OUT := "/home/hatch/workspace/homeward/screenshots_v09"
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

func set_joy(vec: Vector2) -> void:
	main.set("joy_mouse", true)
	main.set("joy_origin", Vector2(200, 400))
	main.set("joy_current", Vector2(200, 400) + vec)

func clear_joy() -> void:
	main.set("joy_mouse", false)
	main.set("joy_id", -999)

func npc_of(type: String, skip: Node = null) -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == type and n != skip:
			return n
	return null

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

	# 0) OVERHEAD (item 1 proof): manual camera, main processing off.
	main.set_process(false)
	var cam: Camera3D = main.get("cam")
	cam.global_position = Vector3(0, 165, 55)
	cam.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	await wait_sec(0.6)
	await snap("map_overview.png")
	main.set_process(true)
	await wait_sec(0.4)

	# 1) SHARPNESS PAIR — same staging as v0.8.
	stage(Vector3(30, 0, 26), 0.0, 10.0)
	await wait_sec(1.0)
	await snap("sharpness_still.png")
	player.set("stamina", 100.0)
	player.set("winded", false)
	set_joy(Vector2(0, -100))
	await wait_sec(0.85)
	await snap("sharpness_sprint.png")
	clear_joy()
	await wait_sec(0.4)

	# 2) RENUMBERED STREET — same staging as v0.8.
	stage(Vector3(-30, 0, 11), 0.0, 6.0)
	await wait_sec(1.0)
	await snap("street_ordered.png")

	# 3) STREET CLEAR — same staging as v0.8.
	stage(Vector3(-20, 0, -2), 180.0, 4.0)
	await wait_sec(1.0)
	await snap("street_clear.png")

	# 4) CAT CLOSE-UPS — same staging as v0.8 (art comparison).
	stage(Vector3(4, 0, 6), 180.0, 14.0)
	await wait_sec(0.9)
	await snap("cat_closeup_front.png")
	stage(Vector3(4, 0, 6), 90.0, 12.0)
	await wait_sec(0.9)
	await snap("cat_closeup_side.png")

	# 5) PETTING SEQUENCE (item 3): paw the woman — she walks over,
	# kneels, and strokes the cat. Three frames of the act.
	var woman: Node = npc_of("woman")
	stage(Vector3(10, 0, 6), 205.0, 8.0)
	(woman as Node3D).global_position = Vector3(12.1, 0.2, 7.2)
	woman.set("interact_cooldown", 0.0)
	woman.set("joy_shown", false)
	await wait_sec(0.3)
	main.call("_paw_action")
	woman.set("interact_kind", "pet")
	await wait_sec(1.05)
	await snap("pet_kneel.png")
	await wait_sec(1.35)
	await snap("pet_stroking.png")
	await wait_sec(1.1)
	await snap("pet_hearts.png")

	# 6) TREAT SEQUENCE: the shopkeeper offers a visible treat.
	var shop: Node = npc_of("shopkeeper")
	(woman as Node3D).global_position = Vector3(40, 0.2, 40)
	stage(Vector3(10, 0, 6), 205.0, 8.0)
	(shop as Node3D).global_position = Vector3(12.1, 0.2, 7.2)
	shop.set("interact_cooldown", 0.0)
	shop.set("joy_shown", false)
	await wait_sec(0.3)
	main.call("_paw_action")
	shop.set("interact_kind", "treat")
	await wait_sec(2.0)
	await snap("treat_offer.png")
	await wait_sec(2.5)

	# 7) FILLED DISTRICTS (item 1).
	stage(Vector3(20, 0, -50), 180.0, 8.0) # from Elm Dr looking south at the NEW Elm south row fronts
	await wait_sec(1.0)
	await snap("fill_elm_south.png")
	stage(Vector3(97, 0, 52), 0.0, 10.0) # Willow Cres looking north: new Willow N row + playground behind
	await wait_sec(1.0)
	await snap("fill_willow_playground.png")
	stage(Vector3(-100, 0, 70), 180.0, 10.0) # looking south over the community garden
	await wait_sec(1.0)
	await snap("fill_garden.png")
	stage(Vector3(-84, 0, 14), 180.0, 8.0) # Michael's v0.8 screenshot area: the Willow west border, filled
	await wait_sec(1.0)
	await snap("fill_west.png")

	print("SHOTS DONE")
	get_tree().quit(0)
