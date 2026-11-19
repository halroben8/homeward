extends Node
## ZANDER'S RUN v1.0.21 — screenshot runner (not part of the suite):
## the three v1.0.21 changes, framed by the game itself.
##  1. garage_parked.png — the pound van parked INSIDE its new
##     garage bay at the depot (west end of the z=15 road), seen
##     from the road with the cat in the foreground.
##  2. officer_chase.png — the officer OUT of the van, mid-chase
##     near it, after the notice meter filled (his chase label up,
##     the chase camera framing cat + officer).
##  3. sprint_hop.png — the cat airborne mid-sprint-hop, driven
##     through the real three-finger touch path (joystick + RUN
##     held, third finger taps HOP).
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
	print("V1021: build_complete")
	# Enter play through the real flow (story skip -> pound escape).
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	# distract the officer, work the bolt, walk out
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
	# walk out through the opened door (the suite's walk_cat_out route)
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	await wait_sec(0.5)
	print("V1021: in play, state=", str(main.get("state")))
	# Park the pound: end the pursuit, van back on patrol, held off.
	var worker: Node = main.get("pound_worker")
	worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(worker)
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_state", "patrol")
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
	await wait_sec(0.5)

	var pvan: Node3D = main.get("pound_van")

	# ---- 1: the van parked inside the garage ----
	main.set("pound_state", "depot")
	main.set("pound_depot_t", 99999.0)
	pvan.position = Vector3(-112, 0, -1.9)
	main.set("pound_van_yaw", PI * 0.5)
	pvan.rotation.y = PI * 0.5
	main.set("pound_van_speed", 0.0)
	main.call("_pound_pin_worker")
	(player as Node3D).global_position = Vector3(-112, 0.2, 9.5)
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", 0.0)
	await wait_sec(1.6) # camera settle on the game's own framing
	await snap("garage_parked.png")
	print("V1021: garage shot — van at ", pvan.position, " depot node: ", main.get_node_or_null("World/PoundDepot") != null)

	# ---- 2: the officer out of the van, mid-chase near it ----
	main.set("pound_state", "patrol")
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	main.set("pound_engage_cd", 0.0)
	main.set("pound_notice", 0.0)
	worker.set("notice_cooldown", 0.0)
	(player as Node3D).global_position = pvan.position + Vector3(11.0, 0.2, 0.0)
	player.set("velocity", Vector3.ZERO)
	var guard: float = 0.0
	while str(worker.get("mode")) != "chase" and guard < 25.0:
		await wait_sec(0.25)
		guard += 0.25
	print("V1021: chase mode after ", guard, "s; worker at ", (worker as Node3D).global_position, " van at ", pvan.position)
	# Let him close on the (still) cat so the action is in frame.
	var guard2: float = 0.0
	while (worker as Node3D).global_position.distance_to((player as Node3D).global_position) > 3.5 and guard2 < 6.0:
		await wait_sec(0.1)
		guard2 += 0.1
	await wait_sec(0.2)
	await snap("officer_chase.png")
	print("V1021: chase shot — mode=", str(worker.get("mode")), " worker-cat dist=", (worker as Node3D).global_position.distance_to((player as Node3D).global_position))

	# ---- 3: the sprint hop, real touch path ----
	# Park the pound out of the way first.
	worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(worker)
	worker.set("active", false)
	(worker as Node3D).visible = false
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_state", "patrol")
	pvan.position = Vector3(-116, 0, 16.8)
	(player as Node3D).global_position = Vector3(30, 0.2, 40)
	player.set("stamina", 100.0)
	player.set("winded", false)
	await wait_sec(0.3)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var joy_pos := Vector2(vp.x * 0.15, vp.y * 0.55)
	var run_pos: Vector2 = (main.get("run_btn") as Button).get_global_rect().get_center()
	var hop_pos: Vector2 = (main.get("hop_btn") as Button).get_global_rect().get_center()
	var tj := InputEventScreenTouch.new()
	tj.index = 0
	tj.pressed = true
	tj.position = joy_pos
	get_viewport().push_input(tj, true)
	await wait_sec(0.15)
	var td := InputEventScreenDrag.new()
	td.index = 0
	td.position = joy_pos + Vector2(0, -100)
	td.relative = Vector2(0, -100)
	get_viewport().push_input(td, true)
	var tr := InputEventScreenTouch.new()
	tr.index = 1
	tr.pressed = true
	tr.position = run_pos
	get_viewport().push_input(tr, true)
	await wait_sec(0.6)
	print("V1021: sprinting=", bool(player.get("is_sprinting")), " speed=", Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length())
	var th := InputEventScreenTouch.new()
	th.index = 2
	th.pressed = true
	th.position = hop_pos
	get_viewport().push_input(th, true)
	await wait_sec(0.3) # rising, near the top of the arc
	print("V1021: at snap — on_floor=", (player as CharacterBody3D).is_on_floor(), " vy=", (player as CharacterBody3D).velocity.y, " y=", (player as Node3D).global_position.y)
	await snap("sprint_hop.png")
	print("V1021: done")
	get_tree().quit()
