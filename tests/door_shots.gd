extends Node
## v1.0.34 staged screenshots (not part of the game): the new
## bolt (3D + panel close-ups), the open-door countdown HUD, the
## captor at the closing door, and the officer on foot in town
## holding his net. Output: ~/workspace/homeward/screenshots_v1032/
## Run: xvfb-run -a godot --path . tests/DoorShots.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_v1032"
var main: Node = null
var player: Node3D = null
var cam: Camera3D = null

func snap(name: String) -> void:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("DOORSHOT saved ", name)

func use_cam(pos: Vector3, look: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.far = 600.0
		add_child(cam)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.current = true

func step_escape(n: int, dt: float) -> void:
	for i in range(n):
		main.call("_process_escape", dt)
		if i % 4 == 0:
			await get_tree().process_frame

func open_the_door() -> void:
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	player = main.get("player")
	main.call("dismiss_splash")
	main.call("start_game")
	await get_tree().create_timer(0.5).timeout
	(main.get("story") as Node).call("skip_opening")
	await get_tree().create_timer(0.5).timeout
	# House escape room with the young woman as captor (the
	# shopkeeper case in Michael's report is the same machinery).
	var woman: Node = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman":
			woman = n
	main.set("captor", woman)
	main.call("_enter_escape")
	await get_tree().create_timer(0.4).timeout
	var o: Vector3 = main.get("escape_origin")
	# Distract her (the intended path), then stand at the door.
	var props: Array = main.get("distract_props")
	(player as Node3D).global_position = (props[0]["base"] as Vector3) + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var g2: int = 0
	while not bool(main.call("captor_distracted")) and g2 < 40:
		main.call("_process_escape", 0.25)
		g2 += 1
	# 1) The remodelled bolt in 3D, engaged, door closed.
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	use_cam(o + Vector3(12.45, 1.8, 1.55), o + Vector3(13.35, 1.82, 3.0))
	await snap("bolt_3d_closeup.png")
	# 2) The panel close-up of the new bolt.
	cam.current = false
	main.call("_on_escape_prompt_pressed")
	await snap("bolt_panel_closeup.png")
	# 3) Finish the combo: the door opens, countdown running.
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))
	(player as Node3D).global_position = o + Vector3(6, 0.3, 3.4)
	player.rotation.y = PI * 0.5 # face the back door
	main.set("look_yaw", player.rotation.y + PI)
	use_cam(o + Vector3(7.6, 2.9, 8.8), o + Vector3(13.2, 1.1, 3.2))
	await snap("door_window_hud.png")
	# 4) Run the window out: the captor comes to shut the door.
	main.set("door_window_t", 0.4)
	var g3: int = 0
	var stand: Vector3 = o + Vector3(12.3, 0, 3.13)
	while g3 < 300:
		main.call("_process_escape", 0.1)
		if g3 % 4 == 0:
			await get_tree().process_frame
		g3 += 1
		if str(main.get("captor_room_state")) == "to_door" and (woman as Node3D).global_position.distance_to(stand) < 3.2:
			break # close in on the door, mid-stride
		if not bool(main.get("exit_open")):
			break
	use_cam(o + Vector3(10.4, 2.2, 6.6), o + Vector3(12.9, 1.2, 3.3))
	await snap("captor_at_closing_door.png")
	# 5) Town: the officer on foot, net in hand (net-probe staging).
	main.set("state", "play")
	main.set("pound_state", "away")
	main.set("pound_engage_cd", 99999.0)
	(main.get("pursuers") as Dictionary).clear()
	var officer: Node3D = main.get("pound_worker")
	officer.call("stop_pursuit")
	officer.visible = true
	officer.set("active", true)
	officer.call("set_net_visible", true)
	officer.set("grab_needed", 999.0)
	officer.set("detect_radius", 0.0)
	officer.set("notice_cooldown", 9999.0)
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1
	officer.global_position = Vector3(10, 0.15, 14)
	officer.rotation.y = 0.0
	officer.set("wander_target", officer.global_position)
	officer.set("wander_wait", 999.0)
	(player as Node3D).global_position = Vector3(10, 0.2, 24)
	player.set("frozen", false)
	var tp: Object = main.get("title_panel")
	if tp != null:
		(tp as CanvasItem).visible = false
	var ep: Object = main.get("escape_prompt_btn")
	if ep != null:
		(ep as CanvasItem).visible = false
	await get_tree().create_timer(1.2).timeout
	use_cam(officer.global_position + Vector3(2.6, 1.6, 2.6), officer.global_position + Vector3(0, 1.35, 0))
	await snap("officer_net_onfoot.png")
	print("DOORSHOT DONE")
	get_tree().quit()
