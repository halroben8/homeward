extends Node
## ZANDER'S RUN v1.0.21 — screenshot runner #2 (not part of the
## suite): the Meshy vehicles + the A/B escape combo.
##  1. escape_combo.png — the escape panel mid-attempt, showing
##     the freshly rolled random A/B sequence (A = HOP, B = PAW).
##  2. street_meshy_cars.png — Meshy cars on the street: two on
##     the road lanes, one parked, the cat in frame.
##  3. animal_control_van.png — the Meshy Animal Control van
##     close up, light bar flashing (encounter state), the
##     officer at his door.
## Boots the real game and drives the real flows. PNGs land in
## ~/workspace/homeward/screenshots_v1021/.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1021/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("saved ", name, " ", img.get_size())

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	player = main.get("player")
	print("V1021B: build_complete")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var dg: int = 0
	while not bool(main.call("captor_distracted")) and dg < 40:
		main.call("_process_escape", 0.25)
		dg += 1
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	await wait_sec(0.6)
	# ---- 1: the escape panel with its random A/B combo ----
	await snap("escape_combo.png")
	print("V1021B: combo on the panel: ", main.get("escape_combo"))
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	await wait_sec(0.5)
	print("V1021B: in play, state=", str(main.get("state")))
	# Park the pound out of the way.
	var worker: Node = main.get("pound_worker")
	worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(worker)
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_state", "patrol")
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
	await wait_sec(0.5)
	var world: Node3D = main.get_node("World")

	# ---- 2: Meshy cars on the street ----
	var c1: Node3D = main.call("_build_car", world, Vector3(-40, 0, 13.2), Color.WHITE, true, "sedan", true)
	var c2: Node3D = main.call("_build_car", world, Vector3(-31, 0, 16.8), Color.WHITE, true, "van", true)
	c2.rotation_degrees = Vector3(0, 180, 0)
	var c3: Node3D = main.call("_build_car", world, Vector3(-47, 0, 8.6), Color.WHITE, false, "pickup", true)
	(player as Node3D).global_position = Vector3(-44.5, 0.2, 15.2)
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", PI * 0.5)
	await wait_sec(1.6)
	await snap("street_meshy_cars.png")
	print("V1021B: street shot — models: ", _pv(c1), " / ", _pv(c2), " / ", _pv(c3))
	c1.queue_free()
	c2.queue_free()
	c3.queue_free()

	# ---- 3: the Animal Control van, lights flashing ----
	var pvan: Node3D = main.get("pound_van")
	main.set("pound_state", "patrol")
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	pvan.rotation.y = 0.0
	main.set("pound_van_speed", 0.0)
	worker.set("active", false)
	(worker as Node3D).visible = true
	(worker as Node3D).global_position = pvan.position + Vector3(1.6, 0, 2.2)
	main.set("pound_state", "chase") # encounter live: the light bar flashes via _update_pound
	(player as Node3D).global_position = pvan.position + Vector3(7.5, 0.2, 3.4)
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", -PI * 0.5 + 0.5)
	await wait_sec(1.4)
	await snap("animal_control_van.png")
	print("V1021B: van shot — lamp L/R: ", (main.get("pound_light_lamp_l") as MeshInstance3D).visible, "/", (main.get("pound_light_lamp_r") as MeshInstance3D).visible)
	print("V1021B: done")
	get_tree().quit()

func _pv(n: Node) -> String:
	if n.scene_file_path != "":
		return n.scene_file_path
	for ch in n.get_children():
		var r: String = _pv(ch)
		if r != "":
			return r
	return ""
