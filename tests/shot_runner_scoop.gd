extends Node
## HOMEWARD capture-scoop screenshots (before/after pair).
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerScoop.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerScoop.tscn -- after
## Stages a REAL capture on an open lawn and fires the real
## on_cat_taken: the cat faces +X, an adult grabber stands 1.05 m in
## front of him facing him. Beats are snapped by polling the real
## cutscene clock, from two camera setups: a side profile (the scoop
## reads best) and the player's typical behind-the-cat view.
## Output: ~/workspace/homeward/screenshots_scoop/<arg>/

const BASE := "/home/hatch/workspace/homeward/screenshots_scoop"
var OUT := BASE + "/before"
var main: Node = null
var player: Node = null
var woman: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String, crop: bool = true) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())
	if crop:
		var w: int = img.get_width()
		var h: int = img.get_height()
		var region := Rect2i(int(w * 0.30), int(h * 0.10), int(w * 0.42), int(h * 0.72))
		img.get_region(region).save_png(OUT + "/" + name.replace(".png", "_crop.png"))
		print("SHOT: ", name.replace(".png", "_crop.png"))

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func pick_captor() -> Node:
	# An adult grabber (the Cat-Loving Young Woman if she seeks).
	var best: Node = null
	var best_h: float = 0.0
	for n in main.get("npcs"):
		if str(n.get("role")) == "grabber":
			var bh: float = float(n.get("body_h"))
			if str(n.get("npc_type")) == "woman":
				return n
			if bh > best_h:
				best_h = bh
				best = n
	return best

func stage_pair() -> void:
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	player.set("velocity", Vector3.ZERO)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X
	player.set("frozen", false)
	(woman as Node3D).global_position = Vector3(61.05, 0.2, 84)
	(woman as Node3D).rotation = Vector3(0, -PI * 0.5, 0) # face -X, at the cat
	woman.set("velocity", Vector3.ZERO)
	woman.set("mode", "wander")
	woman.set("notice", 0.0)
	woman.set("notice_cooldown", 0.0)
	woman.set("grab_progress", 0.0)

func wait_beat(target: float) -> void:
	var guard: float = 0.0
	while str(main.get("state")) == "cutscene" and float(main.get("cutscene_t")) < target and guard < 9.0:
		await wait_sec(0.03)
		guard += 0.03

func run_capture(beats: Array, tag: String) -> void:
	stage_pair()
	await wait_sec(0.35)
	main.call("on_cat_taken", woman)
	print("capture fired, state: ", str(main.get("state")))
	for b in beats:
		await wait_beat(float(b[0]))
		await snap(tag + "_" + str(b[1]) + ".png")
	# let the cutscene finish into the escape room, then reset to play
	var guard: float = 0.0
	while str(main.get("state")) == "cutscene" and guard < 8.0:
		await wait_sec(0.25)
		guard += 0.25
	print("after cutscene, state: ", str(main.get("state")))
	if str(main.get("state")) == "escape":
		main.call("_complete_escape")
		(main.get("pursuers") as Dictionary).clear()
		woman.call("stop_pursuit")
		await wait_sec(0.3)
	park_npcs_far()
	print("reset, state: ", str(main.get("state")))

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = BASE + "/" + args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
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
	await wait_sec(0.4)
	woman = pick_captor()
	print("captor: ", str(woman.get("npc_type")), " / ", str(woman.get("display_name")))
	# --- pass 1: side profile (camera south of the pair, looking north)
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", 6.0)
	await run_capture([[0.55, "bend"], [1.15, "arms"], [1.6, "midlift"], [2.2, "cradle"], [2.8, "settled"]], "side")
	# --- pass 2: the player's typical view (camera behind the cat)
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", 12.0)
	await run_capture([[0.55, "bend"], [1.6, "midlift"], [2.8, "cradle"], [3.8, "carry"]], "view")
	print("DONE")
	get_tree().quit(0)
