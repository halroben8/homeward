extends Node
## TEMPORARY diagnostic probe (v1.0.18): drives the REAL input path
## with synthetic InputEventScreenTouch/Drag events via
## Input.parse_input_event — the same path Android touches take,
## including touch->mouse emulation — to find where the RUN hold
## breaks when a second finger is on the joystick.

var main: Node = null
var player: Node = null
var ev_count: int = 0

func _input(event: InputEvent) -> void:
	if ev_count < 60:
		ev_count += 1
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			print("PROBE EV touch idx=", t.index, " pressed=", t.pressed, " pos=", t.position)
		elif event is InputEventScreenDrag:
			var d := event as InputEventScreenDrag
			print("PROBE EV drag idx=", d.index, " pos=", d.position)
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			print("PROBE EV mousebtn idx=", mb.button_index, " pressed=", mb.pressed, " pos=", mb.position)
		elif event is InputEventMouseMotion:
			print("PROBE EV mousemotion pos=", (event as InputEventMouseMotion).position)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

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

func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func sample(tag: String) -> void:
	var spd: float = 0.0
	if player != null:
		var v: Vector3 = (player as CharacterBody3D).velocity
		spd = Vector2(v.x, v.z).length()
	print("PROBE ", tag, ": run_on=", str(main.get("run_on")),
		" touch_sprint=", str(player.get("touch_sprint")) if player else "?",
		" is_sprinting=", str(player.get("is_sprinting")) if player else "?",
		" speed=", str(snappedf(spd, 0.01)),
		" stamina=", str(snappedf(float(player.get("stamina")), 0.1)) if player else "?",
		" joy_id=", str(main.get("joy_id")))

func _ready() -> void:
	await run_probe()

func run_probe() -> void:
	print("PROBE emulate_mouse_from_touch=", str(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)))
	print("PROBE emulate_touch_from_mouse=", str(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)))
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
	# drive the pound escape like the suite does
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
	print("PROBE state after escape=", str(main.get("state")))
	# tidy: stop the worker pursuit, park everyone far away
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
	await wait_sec(0.3)
	var rb: Button = main.get("run_btn")
	var rect: Rect2 = rb.get_global_rect()
	var rc: Vector2 = rect.get_center()
	print("PROBE run_btn rect=", str(rect), " center=", str(rc), " viewport=", str(get_viewport().get_visible_rect().size), " window=", str(get_window().size))
	sample("baseline")

	# ---- TEST A: single finger on RUN (no joystick) ----
	touch(0, true, rc)
	await frames(3)
	await wait_sec(0.4)
	sample("A single-touch RUN held")
	touch(0, false, rc)
	await frames(3)
	await wait_sec(0.2)
	sample("A released")

	# ---- TEST B: joystick finger FIRST, RUN as second finger ----
	touch(0, true, Vector2(200, 400))
	await frames(3)
	drag(0, Vector2(200, 300), Vector2(0, -100))
	await frames(3)
	await wait_sec(0.3)
	sample("B joystick only")
	touch(1, true, rc)
	await frames(3)
	await wait_sec(0.6)
	sample("B joystick + RUN (finger2)")
	touch(1, false, rc)
	await frames(3)
	await wait_sec(0.3)
	sample("B RUN released, joystick still down")
	touch(0, false, Vector2(200, 300))
	await frames(3)

	# ---- TEST C: RUN finger FIRST, joystick as second finger ----
	player.set("stamina", 100.0)
	player.set("winded", false)
	touch(0, true, rc)
	await frames(3)
	await wait_sec(0.3)
	sample("C RUN first (finger1)")
	touch(1, true, Vector2(200, 400))
	await frames(3)
	drag(1, Vector2(200, 300), Vector2(0, -100))
	await frames(3)
	await wait_sec(0.6)
	sample("C RUN + joystick (finger2)")
	touch(1, false, Vector2(200, 300))
	touch(0, false, rc)
	await frames(3)
	await wait_sec(0.2)
	sample("C all released")
	print("PROBE DONE")
	get_tree().quit(0)
