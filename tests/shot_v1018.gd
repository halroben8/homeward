extends Node
## ZANDER'S RUN v1.0.18 — screenshot runner (not part of the suite):
## sprint_run_held.png — the cat at FULL SPRINT in town with the
## RUN hold engaged through the real two-finger touch path
## (joystick finger 0 + RUN finger 1, via Viewport.push_input):
## RUN button showing its green HELD fill, stamina bar draining.
## Boots the real game and drives the real flows. PNG lands in
## ~/workspace/homeward/screenshots_v1018/.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1018/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("saved ", name, " ", img.get_size())

func touch(idx: int, pressed: bool, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.pressed = pressed
	ev.position = pos
	get_viewport().push_input(ev, true)

func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = pos
	ev.relative = rel
	get_viewport().push_input(ev, true)

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
	await wait_sec(0.6)
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
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	var kind: String = str(main.get("exit_open_kind"))
	var o: Vector3 = main.get("escape_origin")
	match kind:
		"latch", "winpush":
			(player as Node3D).global_position = o + Vector3(0, 0.3, -11.2)
		"petdoor", "carrier":
			(player as Node3D).global_position = o + Vector3(6, 0.3, -11.2)
		"bolt":
			(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	print("SHOT state=", str(main.get("state")))
	var worker: Node = main.get("pound_worker")
	if worker != null:
		worker.call("stop_pursuit")
		(main.get("pursuers") as Dictionary).erase(worker)
		main.set("pound_engage_cd", 99999.0)
		main.set("pound_state", "patrol")
		worker.set("active", false)
		(worker as Node3D).visible = false
	var ii: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(ii) * 2.0, 0.2, 80)
		ii += 1
	(player as Node3D).global_position = Vector3(30, 0.2, 40)
	player.set("stamina", 100.0)
	player.set("winded", false)
	await wait_sec(0.5)
	# Two-finger sprint through the real touch path.
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var joy_pos := Vector2(vp.x * 0.15, vp.y * 0.55)
	var run_pos: Vector2 = (main.get("run_btn") as Button).get_global_rect().get_center()
	print("SHOT viewport=", vp, " joy=", joy_pos, " run=", run_pos)
	touch(0, true, joy_pos)
	await wait_sec(0.15)
	drag(0, joy_pos + Vector2(0, -100), Vector2(0, -100))
	await wait_sec(0.3)
	touch(1, true, run_pos)
	await wait_sec(1.1) # sprinting; stamina visibly draining
	var v: Vector3 = (player as CharacterBody3D).velocity
	print("SHOT sprinting=", str(player.get("is_sprinting")), " speed=", str(Vector2(v.x, v.z).length()), " stamina=", str(player.get("stamina")), " run_on=", str(main.get("run_on")))
	await snap("sprint_run_held.png")
	touch(1, false, run_pos)
	touch(0, false, joy_pos + Vector2(0, -100))
	await wait_sec(0.2)
	print("SHOT DONE")
	get_tree().quit(0)
