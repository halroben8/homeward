extends Node
## SHELTER WARD verification runner (2026-11-18, second pass).
## Boots the real game, plays the opening into the pound cage, and
## photographs the rebuilt ward:
##   01_cage_lookout  — from inside Zander's cage, looking out
##                      through the chain-link gate at the ward
##   02_kennel_row    — down the kennel row, the reference
##                      photo's angle (chain-link runs, cards)
##   03_cage_bank     — facing the stacked cat-cage bank on the
##                      west wall ("vertical stacked cages")
##   04_breakout      — Biscuit mid-breakout: gate open, cat
##                      RUNNING out of his run
## Then it drives the escape end to end (gate PAW -> mop-bucket
## distraction -> bolt-door combo -> walk out) to prove the flow
## in the new room. Prints SHELTER2 CHECK lines; exits 0 only if
## every check passed.
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerShelter2.tscn
## Output: ~/workspace/homeward/screenshots_shelter2/
## Not part of the suite.

const OUT := "/home/hatch/workspace/homeward/screenshots_shelter2"
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null
var story: Node = null
var cam: Camera3D = null
var failures: int = 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("SHELTER2 CHECK PASS: ", name)
	else:
		failures += 1
		print("SHELTER2 CHECK FAIL: ", name, " -- ", detail)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap_with_cam(name: String, pos: Vector3, target: Vector3) -> void:
	main.set_process(false)
	await get_tree().process_frame
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())
	main.set_process(true)

func wait_for_main(key: String, want: String, max_frames: int) -> bool:
	for i in range(max_frames):
		if str(main.get(key)) == want:
			return true
		await get_tree().process_frame
	print("RUNNER WAIT TIMEOUT: ", key, " != ", want)
	return false

func distract_captor() -> void:
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	EmojiFont.apply()
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(1.2)
	player = main.get("player")
	story = main.get("story")
	cam = main.get("cam")
	var o: Vector3 = main.get("escape_origin")
	main.call("dismiss_splash")
	main.call("start_game")

	# --- into the pound cage via the real opening flow ---
	for i in range(10):
		await get_tree().process_frame
	story.call("skip_opening")
	await wait_for_main("state", "escape", 3000)
	var guard: int = 0
	while not bool(story.get("cage_closed")) and guard < 600:
		await get_tree().process_frame
		guard += 1
	await wait_sec(1.3)
	check("cage closed at pound start", bool(story.get("cage_closed")))
	var ward: Array = main.get("ward_cages")
	check("ward cages registered", ward.size() >= 10, str(ward.size()))

	# --- screenshots of the ward ---
	var cc: Vector3 = story.get("cage_centre")
	await snap_with_cam("01_cage_lookout.png", cc + Vector3(0, 0.75, 0.75), cc + Vector3(0, 0.7, -7.0))
	await snap_with_cam("02_kennel_row.png", o + Vector3(10.5, 1.6, 3.2), o + Vector3(-9.0, 0.9, 8.8))
	await snap_with_cam("03_cage_bank.png", o + Vector3(-6.0, 1.6, 0.2), o + Vector3(-13.6, 1.35, 0.2))

	# --- out of his own cage (real gate PAW), then free Biscuit ---
	var gate_p: Vector3 = story.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	await wait_sec(0.6)
	check("gate opens on PAW", not bool(story.get("cage_closed")))
	var biscuit: Dictionary = ward[0]
	var score0: int = int(main.get("score"))
	(player as Node3D).global_position = (biscuit["gate_pos"] as Vector3) + Vector3(0, 0.3, -1.3)
	main.call("_on_interact")
	check("paw frees Biscuit", bool(biscuit["freed"]))
	check("freeing pays +5", int(main.get("score")) == score0 + 5, str(main.get("score")))
	# Step Zander aside so the camera sees the RUN, not the two
	# cats lined up on the same axis.
	(player as Node3D).global_position = (biscuit["gate_pos"] as Vector3) + Vector3(3.2, 0.3, -3.4)
	for i in range(7):
		main.call("_process_escape", 0.15)
	await snap_with_cam("04_breakout.png", o + Vector3(-4.2, 1.8, 0.2), o + Vector3(-10.2, 0.35, 5.2))
	var run_guard: int = 0
	while str(biscuit["animal_state"]) != "gone" and run_guard < 200:
		main.call("_process_escape", 0.25)
		run_guard += 1
	check("Biscuit runs out and is gone", str(biscuit["animal_state"]) == "gone", "guard=" + str(run_guard))

	# --- escape end to end in the new room ---
	distract_captor()
	check("mop-bucket distraction works", bool(main.call("captor_distracted")))
	(player as Node3D).global_position = o + Vector3(13.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
		main.call("_process_escape", 0.4)
	check("bolt-door combo opens the way out", bool(main.get("exit_open")))
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	check("walk-out reaches town play", str(main.get("state")) == "play", "state=" + str(main.get("state")))

	print("SHELTER2 RUNNER DONE failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
