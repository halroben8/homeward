extends Node
## ZANDER'S RUN v1.0.21 — screenshot runner #3 (not part of the
## suite): ONE frame — the Meshy Animal Control van close up on
## the road with its light bar lit and the officer at his door.
## The van is held parked via the depot state (huge dwell), the
## tree is paused for the snap so the lamp holds the lit phase
## the game's own _pound_update_lights set — the suite checks
## the on/off/alternation logic directly; this frame shows how
## the lit bar reads on the model.

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
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	await wait_sec(0.5)
	var worker: Node = main.get("pound_worker")
	worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(worker)
	main.set("pound_engage_cd", 99999.0)
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
	# Stage: van parked on the z=15 road, held by the depot dwell;
	# officer standing at his door; cat on the road ahead of it.
	var pvan: Node3D = main.get("pound_van")
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	pvan.rotation.y = 0.0
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "depot")
	main.set("pound_depot_t", 99999.0)
	worker.set("active", false)
	(worker as Node3D).visible = true
	var m = worker.get("model")
	if m:
		(m as Node3D).visible = true
	(worker as Node3D).global_position = pvan.position + Vector3(1.4, 0.15, 1.7)
	(player as Node3D).global_position = pvan.position + Vector3(5.2, 0.2, 2.6)
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", PI * 0.5)
	await wait_sec(1.6) # camera settle
	# Light the bar the game's way, then hold the frame: drive the
	# encounter state for one real update, then pause.
	main.set("pound_state", "chase")
	await wait_sec(0.12)
	get_tree().paused = true
	await snap("animal_control_van.png")
	get_tree().paused = false
	print("V1021C: lamp L/R at snap: ", (main.get("pound_light_lamp_l") as MeshInstance3D).visible, "/", (main.get("pound_light_lamp_r") as MeshInstance3D).visible, " van at ", pvan.position)
	print("V1021C: done")
	get_tree().quit()
