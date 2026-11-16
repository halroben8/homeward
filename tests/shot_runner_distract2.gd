extends Node
## HOMEWARD v1.2 — restaged proof shots (the first runner's room and
## chase framings hid their subjects). Same scenes, better camera
## spots. Overwrites captor_in_room.png, person_righting_prop.png,
## interrupt_moment.png, view_behind_notice.png, view_chase.png in
## ~/workspace/homeward/screenshots_distract/.

const OUT := "/home/hatch/workspace/homeward/screenshots_distract/"

var main: Node = null
var player: Node = null
var woman: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("saved ", name)

func stage_cat(pos: Vector3, yaw: float, pitch: float) -> void:
	(player as Node3D).global_position = pos
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", yaw)
	main.set("look_pitch_deg", pitch)

func set_steps(kinds: Array) -> void:
	var steps: Array = []
	for k in kinds:
		steps.append({"kind": k})
	main.set("escape_steps", steps)
	main.set("escape_step", 0)
	main.set("escape_prog", 0.0)
	main.call("_update_escape_label")

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
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
	set_steps(["latch", "winpush"])
	# --- 1: captor in the room — cat north of her, looking back south
	stage_cat(o + Vector3(-4.5, 0.3, -2.5), 2.91, 8.0)
	await wait_sec(1.0)
	await snap("captor_in_room.png")
	# --- 2: righting, seen side-on ------------------------------------
	stage_cat(o + Vector3(-5.55, 0.3, -5.8), 0.78, 14.0)
	await wait_sec(0.4)
	main.call("_on_interact") # paw the plant over
	var t := 0.0
	while str(main.get("captor_room_state")) != "righting" and t < 20.0:
		await wait_sec(0.2)
		t += 0.2
	stage_cat(o + Vector3(-3.4, 0.3, -4.2), 0.91, 10.0)
	await wait_sec(0.5)
	await snap("person_righting_prop.png")
	# --- 3: interruption, with her in frame ---------------------------
	main.call("_enter_escape")
	set_steps(["petdoor"])
	(woman as Node3D).global_position = o + Vector3(9.5, 0.25, -3.0)
	main.set("captor_room_state", "idle")
	main.set("captor_room_wait", 30.0) # she stays put until the panel opens
	stage_cat(o + Vector3(6, 0.3, -8.2), 0.0, 10.0)
	await wait_sec(0.6)
	main.call("_on_escape_prompt_pressed")
	var t3 := 0.0
	while (main.get("escape_panel") as Control).visible and t3 < 4.0:
		await wait_sec(0.1)
		t3 += 0.1
	print("panel interrupted: ", not (main.get("escape_panel") as Control).visible)
	await wait_sec(0.5)
	await snap("interrupt_moment.png")
	# --- 4: town behind view with a half-filled notice bar ------------
	main.call("_complete_escape")
	(main.get("pursuers") as Dictionary).clear()
	woman.call("stop_pursuit")
	await wait_sec(1.0) # let the arrival fade finish
	var grabber: Node = null
	for n in main.get("npcs"):
		if str(n.get("role")) == "grabber":
			grabber = n
			break
	(player as Node3D).global_position = Vector3(10, 0.2, 10)
	(player as Node3D).rotation.y = PI # facing away (north) — a true behind view
	player.set("velocity", Vector3.ZERO)
	(grabber as Node3D).global_position = Vector3(10, 0.2, 4.2)
	grabber.set("notice", 0.55)
	grabber.set("mode", "wander")
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", 8.0)
	await wait_sec(0.3)
	await snap("view_behind_notice.png")
	# --- 5: chase — the cat flees toward camera, pursuer behind him ---
	(player as Node3D).global_position = Vector3(20, 0.2, 20)
	(player as Node3D).rotation.y = 0.0 # facing the camera (fleeing toward us)
	(grabber as Node3D).global_position = Vector3(19, 0.2, 12.5)
	grabber.call("start_pursuit")
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", 10.0)
	await wait_sec(0.5)
	await snap("view_chase.png")
	print("DONE")
	get_tree().quit(0)
