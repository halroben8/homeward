extends Node
## HOMEWARD v1.2 — screenshot runner for the DISTRACTION system, the
## player-driven exit, the interruption, and the readability pass
## (closer camera + bigger cat + bigger NPC bars). Boots the real
## game, stages scenes in the escape room and in town, saves PNGs to
## ~/workspace/homeward/screenshots_distract/. Not part of the suite.

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
	print("saved ", name, " ", img.get_size())

func stage_cat(pos: Vector3, yaw: float, pitch: float) -> void:
	(player as Node3D).global_position = pos
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", yaw)
	main.set("look_pitch_deg", pitch)

func set_steps(kinds: Array) -> void:
	# Like the escape runner's force_steps, minus _reset_escape_props
	# (v1.2: that also resets the captor's room state — _enter_escape
	# already ran it; here we only swap the mechanism draw).
	var steps: Array = []
	for k in kinds:
		steps.append({"kind": k})
	main.set("escape_steps", steps)
	main.set("escape_step", 0)
	main.set("escape_prog", 0.0)
	main.call("_update_escape_label")

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
	set_steps(["latch", "winpush"])
	# --- 1: the captor in the room with the cat ----------------------
	stage_cat(o + Vector3(-0.5, 0.3, 3.2), 0.0, 12.0)
	await wait_sec(1.0)
	await snap("captor_in_room.png")
	# --- 2: paw the plant over (mid-topple) --------------------------
	stage_cat(o + Vector3(-5.55, 0.3, -5.8), 0.78, 14.0)
	await wait_sec(0.5)
	main.call("_on_interact") # the PAW path — topples the plant
	await wait_sec(0.18)
	await snap("prop_mid_topple.png")
	# --- 3: she hurries over and rights it ---------------------------
	var ok: bool = await wait_until_room_state("righting", 20.0)
	print("righting reached: ", ok)
	await wait_sec(0.6)
	await snap("person_righting_prop.png")
	# --- 4: the panel open during the distraction window ------------
	stage_cat(o + Vector3(0, 0.3, -8.2), 0.0, 10.0)
	await wait_sec(0.4)
	main.call("_on_escape_prompt_pressed")
	await wait_sec(0.4)
	await snap("panel_during_distraction.png")
	# finish both combos -> the window OPENS -> walk the cat out
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	print("exit_open: ", bool(main.get("exit_open")))
	(player as Node3D).global_position = o + Vector3(0, 0.3, -11.2)
	var t := 0.0
	while str(main.get("state")) != "play" and t < 5.0:
		await wait_sec(0.25)
		t += 0.25
	print("walked out, state: ", str(main.get("state")))
	# --- 5: the interruption (no distraction) ------------------------
	main.set("captor", woman)
	main.call("_enter_escape")
	set_steps(["petdoor"])
	stage_cat(o + Vector3(6, 0.3, -8.2), 0.0, 10.0)
	await wait_sec(0.8)
	main.call("_on_escape_prompt_pressed")
	var t2 := 0.0
	while float(main.get("notice_t")) < 0.8 and t2 < 4.0:
		await wait_sec(0.1)
		t2 += 0.1
	await snap("panel_watching_warning.png")
	var t3 := 0.0
	while (main.get("escape_panel") as Control).visible and t3 < 4.0:
		await wait_sec(0.1)
		t3 += 0.1
	print("panel interrupted: ", not (main.get("escape_panel") as Control).visible)
	await wait_sec(0.4)
	await snap("interrupt_moment.png")
	# --- 6: town readability — behind view with a notice bar ----------
	main.call("_complete_escape")
	(main.get("pursuers") as Dictionary).clear()
	woman.call("stop_pursuit")
	var grabber: Node = null
	for n in main.get("npcs"):
		if str(n.get("role")) == "grabber":
			grabber = n
			break
	(player as Node3D).global_position = Vector3(10, 0.2, 10)
	player.set("velocity", Vector3.ZERO)
	(grabber as Node3D).global_position = Vector3(10, 0.2, 4.2)
	grabber.set("notice", 0.55)
	grabber.set("mode", "wander")
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", 8.0)
	await wait_sec(0.35)
	await snap("view_behind_notice.png")
	# --- 7: town readability — chase view -----------------------------
	(player as Node3D).global_position = Vector3(20, 0.2, 20)
	(grabber as Node3D).global_position = Vector3(25.5, 0.2, 26.5)
	grabber.call("start_pursuit")
	main.set("look_yaw", 0.7)
	main.set("look_pitch_deg", 10.0)
	await wait_sec(0.45)
	await snap("view_chase.png")
	print("DONE")
	get_tree().quit(0)
