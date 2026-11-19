extends Node
## TEMPORARY v1.0.9 post-splash crash driver (rendered, real-time).
## Boots Main, taps the splash EARLY (queued-tap path), waits for the
## build, lands on title, starts play, wanders with the joystick,
## provokes a chase with a meow, gets caught, enters the escape room,
## then returns to play and wanders again. Prints CD: milestones.

var main: Node = null
var player: Node = null
var t_start: int = 0

func log_step(s: String) -> void:
	print("CD: ", s, " t=", (Time.get_ticks_msec() - t_start) / 1000.0, "s state=", str(main.get("state")) if main else "?")

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func set_joy(vec: Vector2) -> void:
	main.set("joy_mouse", true)
	main.set("joy_origin", Vector2(200, 400))
	main.set("joy_current", Vector2(200, 400) + vec)

func clear_joy() -> void:
	main.set("joy_mouse", false)
	main.set("joy_id", -999)

func _ready() -> void:
	t_start = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(640, 360))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(0.3)
	log_step("splash up, build running")
	# EARLY TAP: dismiss while the town is still streaming in.
	main.call("dismiss_splash")
	log_step("early tap done (should queue)")
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	log_step("build complete")
	await wait_sec(1.5)
	# The queued tap should have auto-dismissed to title; if still on
	# splash, dismiss now (the normal path).
	if str(main.get("state")) == "splash":
		main.call("dismiss_splash")
		log_step("dismissed splash after build")
	await wait_sec(2.0)
	log_step("on title")
	main.call("start_game")
	await wait_sec(0.5)
	log_step("play started")
	player = main.get("player")
	# Wander: a couple of joystick directions, a few seconds of play.
	var dirs: Array = [Vector2(0, -120), Vector2(110, 0)]
	for d in dirs:
		set_joy(d)
		await wait_sec(4.0)
		log_step("wander step done pos=" + str((player as Node3D).global_position))
	clear_joy()
	# Provoke a chase: stand next to a grabber and meow.
	var grabber: Node = null
	for n in main.get("npcs"):
		if str(n.get("role")) == "grabber":
			grabber = n
			break
	if grabber == null and (main.get("npcs") as Array).size() > 0:
		grabber = (main.get("npcs") as Array)[0]
	(player as Node3D).global_position = (grabber as Node3D).global_position + Vector3(2.0, 0.2, 0)
	await wait_sec(0.5)
	main.call("_on_meow")
	log_step("meow next to npc " + str(grabber.get("npc_type")))
	await wait_sec(6.0)
	log_step("after meow (chase should be live or done)")
	# Get caught: hand the cat to the npc through the real capture path.
	main.call("on_cat_taken", grabber)
	await wait_sec(3.0)
	log_step("capture handed over")
	var guard2: int = 0
	while str(main.get("state")) != "escape" and guard2 < 60 * 30:
		await get_tree().process_frame
		guard2 += 1
	log_step("escape state reached (or timeout)")
	await wait_sec(5.0)
	log_step("sat in escape room")
	# Keep the process alive a little longer in whatever state, then quit.
	await wait_sec(5.0)
	log_step("END - survived")
	get_tree().quit()
