extends Node
## SCALE FIX before/after screenshots — IDENTICAL staging for both
## runs, only the cat's proportions differ:
##   xvfb-run -a godot --path . tests/ShotRunnerScaleFix.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerScaleFix.tscn -- after
## Output: screenshots_scalefix/<arg>/{beside_person,beside_door,beside_car,behind}.png
## Scenes: cat standing beside a woman (1.7m), beside a house door
## (2.7m), beside a sedan, and the standard behind gameplay view.
## All staged through the game's OWN camera (look yaw/pitch + the
## project's camera distance), so the frames are what Michael sees.

const BASE := "/home/hatch/workspace/homeward/screenshots_scalefix"
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
	(player as Node3D).rotation = Vector3.ZERO
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
	player.set("frozen", true)

	# 1) BESIDE A PERSON — woman (body_h 1.7) standing at the cat's
	# left, both in profile-ish three-quarter view.
	var woman: Node = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman":
			woman = n
			break
	stage(Vector3(4, 0, 6), 205.0, 8.0)
	if woman != null:
		var wp := Vector3(4.95, 0, 6.35)
		(woman as Node3D).global_position = wp
		(woman as Node3D).rotation = Vector3(0, deg_to_rad(-70.0), 0)
		woman.set("velocity", Vector3.ZERO)
		woman.set_physics_process(false)
		# she was parked >85m away, so the perf gate hid her model;
		# with her physics off the gate can't un-hide her — do it here
		(woman.get("model") as Node3D).visible = true
		if woman.get("name_label"):
			(woman.get("name_label") as Node3D).visible = false
	await wait_sec(1.0)
	await snap("beside_person.png")

	# 2) BESIDE A HOUSE DOOR — first house in the registry; the cat
	# stands on the path in front of its 2.7m door.
	var houses: Array = main.get("houses")
	var h0: Dictionary = houses[0]
	var door: Vector3 = h0["door"]
	var facing: float = float(h0.get("facing", 1.0))
	var cat_door_pos := door + Vector3(0, 0, 3.1 * facing)
	stage(cat_door_pos, 0.0 if facing > 0.0 else 180.0, 6.0)
	(player as Node3D).rotation.y = PI if facing > 0.0 else 0.0 # face the door
	await wait_sec(1.0)
	await snap("beside_door.png")

	# 3) BESIDE A CAR — the red sedan parked at (-8, 0, -11),
	# built along X (3.9 long, ~1.5 high). Cat stands just past
	# its front bumper; camera looks along the car's flank so cat
	# and car profile share the frame (a flank view from behind
	# puts the car between camera and cat — pull-in eats it).
	stage(Vector3(-3.4, 0, -8.55), 90.0, 8.0)
	(player as Node3D).rotation.y = deg_to_rad(90.0)
	await wait_sec(1.0)
	await snap("beside_car.png")

	# 4) BEHIND — the standard gameplay view (same staging as the
	# v12 cat runner: spawn lawn, yaw 180, pitch 14).
	stage(Vector3(4, 0, 6), 180.0, 14.0)
	await wait_sec(1.0)
	await snap("behind.png")

	print("SHOTS DONE -> ", OUT)
	get_tree().quit(0)
