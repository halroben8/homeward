extends Node
## HOMEWARD v0.8 screenshot staging (run under Xvfb, NOT headless):
##   xvfb-run -a godot --path . tests/ShotRunnerV08.tscn
## Proof shots for items 1-6 into screenshots_v08/.

const OUT := "/home/hatch/workspace/homeward/screenshots_v08"
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

func _ready() -> void:
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

	# 1) SHARPNESS PAIR (item 3): same stretch of Oak Avenue.
	# A: standing still. B: mid-sprint through the same area.
	# C: standing again where the sprint ended (matched viewpoint).
	stage(Vector3(30, 0, 26), 0.0, 10.0)
	await wait_sec(1.0)
	await snap("sharpness_still.png")
	player.set("stamina", 100.0)
	player.set("winded", false)
	set_joy(Vector2(0, -100)) # full push = sprint north
	await wait_sec(0.85)
	await snap("sharpness_sprint.png")
	var sprint_end: Vector3 = (player as Node3D).global_position
	clear_joy()
	await wait_sec(0.4)
	stage(sprint_end + Vector3(0, 0, 6.0), 0.0, 10.0) # stand where the sprint view ended
	await wait_sec(1.0)
	await snap("sharpness_still_after.png")

	# 2) RENUMBERED STREET (item 2): from Oak Avenue looking NORTH
	# at the odd-numbered row — 13 Oak Avenue, then 19 Oak Avenue
	# (Apartment 3B) to its east: numbers climb in order, in frame.
	stage(Vector3(-30, 0, 11), 0.0, 6.0)
	await wait_sec(1.0)
	await snap("street_ordered.png")

	# 3) STREET CLEAR (item 1): looking south down Cedar Street
	# (x=-20) — v0.7's "22 Oak Avenue" at x=-16 stood in the middle
	# of this view; the corridor is open now.
	stage(Vector3(-20, 0, -2), 180.0, 4.0)
	await wait_sec(1.0)
	await snap("street_clear.png")

	# 4) PAW mid-swipe + reset (item 4): front three-quarter view.
	stage(Vector3(4, 0, 6), 150.0, 12.0)
	await wait_sec(0.9)
	player.call("do_paw_swipe")
	await wait_sec(0.15)
	await snap("paw_mid.png")
	await wait_sec(0.75)
	await snap("paw_reset.png")

	# 5) FRIENDLY BEND-DOWN PET (item 5): paw the woman -> she bends
	# down and pets the cat (points bubble mid-bend).
	var woman: Node = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman":
			woman = n
			break
	stage(Vector3(10, 0, 6), 205.0, 8.0)
	(woman as Node3D).global_position = Vector3(11.6, 0.2, 7.0)
	woman.set("wander_target", Vector3(11.6, 0, 7.0)) # hold her in frame
	woman.set("wander_wait", 999.0)
	woman.set("interact_cooldown", 0.0)
	woman.set("joy_shown", false)
	await wait_sec(0.3)
	main.call("_paw_action")
	await wait_sec(0.95)
	await snap("pet_bend.png")

	# 6) ART PASS cat close-ups (item 6): front + side.
	stage(Vector3(4, 0, 6), 180.0, 14.0)
	await wait_sec(0.9)
	await snap("cat_closeup_front.png")
	stage(Vector3(4, 0, 6), 90.0, 12.0)
	await wait_sec(0.9)
	await snap("cat_closeup_side.png")

	print("SHOTS DONE")
	get_tree().quit(0)
