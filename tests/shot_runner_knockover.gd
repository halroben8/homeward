extends Node
## HOMEWARD v1.5 — screenshot runner for KNOCK OVER ALMOST
## EVERYTHING: the escape room's distraction props grew from 3 to
## 17. Boots the real game, stages the tidy room, a mid-chaos room
## (several new props down, the captor righting one), and a close
## shot of new topples in the kitchen corner. Saves PNGs to
## ~/workspace/homeward/screenshots_knockover/. Not part of the suite.

const OUT := "/home/hatch/workspace/homeward/screenshots_knockover/"

var main: Node = null
var player: Node = null
var woman: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("saved ", name, " ", img.get_size())

func stage_cat(pos: Vector3, yaw: float, pitch: float) -> void:
	(player as Node3D).global_position = pos
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", yaw)
	main.set("look_pitch_deg", pitch)

func prop_by_id(id: String) -> Dictionary:
	for p in main.get("distract_props"):
		if str(p["id"]) == id:
			return p
	return {}

func topple(id: String) -> void:
	var p: Dictionary = prop_by_id(id)
	if not p.is_empty():
		main.call("topple_prop", p)

func wait_until_room_state(want: String, timeout_s: float) -> bool:
	var t := 0.0
	while t < timeout_s:
		if str(main.get("captor_room_state")) == want:
			return true
		await wait_sec(0.2)
		t += 0.2
	return false

func _ready() -> void:
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
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		if str(n.get("npc_type")) == "woman" and woman == null:
			woman = n
		i += 1
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	var o: Vector3 = main.get("escape_origin")
	main.set("captor", woman)
	main.call("_enter_escape")
	print("props in room: ", (main.get("distract_props") as Array).size())
	# --- 1: the tidy room, before ---------------------------------
	# (cat staged on the open west floor: between the coffee table
	# and the sofa the room camera pulls in tight against the cat)
	stage_cat(o + Vector3(-4.5, 0.3, -1.5), 0.0, 10.0)
	await wait_sec(1.2)
	await snap("room_before.png")
	# --- 2: mid-chaos — the bookcase cluster goes over: plant,
	# book stack and watering can down around her (mug too, for
	# queue depth); she is righting the plant while the rest wait --
	topple("plant")
	topple("bookstack")
	topple("wateringcan")
	topple("mug")
	var ok: bool = await wait_until_room_state("righting", 25.0)
	print("righting reached: ", ok, " queue: ", (main.get("distract_queue") as Array).size())
	await wait_sec(0.7)
	await snap("room_chaos.png")
	# --- 3: close shot — kitchen corner topples (floor lamp,
	# wastebasket, stool all down) ----------------------------------
	main.call("_enter_escape")
	topple("floorlamp")
	topple("wastebasket")
	topple("stool")
	stage_cat(o + Vector3(9.0, 0.3, -5.0), 2.6, 16.0)
	await wait_sec(0.9)
	await snap("close_new_topples.png")
	print("DONE")
	get_tree().quit(0)
