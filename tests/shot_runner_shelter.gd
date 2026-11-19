extends Node
## SHELTER REDESIGN verification runner (2026-11-18). Boots the
## real game, plays the opening into the pound cage, and:
##   01_cage_start      — the player's own view: Zander caged in
##                        the kennel row (follow camera, unstaged)
##   02_kennel_row_wide — a staged wide of the whole south-wall
##                        ward: both tiers, the sign, the staff bay
##   03_ward_from_north — straight-on from the room's north side
##   04_staff_bay       — the supply shelf + spare carrier bay
## Then it drives the escape END TO END through the real paths
## (gate PAW -> plant distraction -> bolt-door combo -> walk out)
## and finally re-enters via _enter_escape (the mid-game capture
## path) to confirm the room still receives a capture. Prints
## SHELTER CHECK lines; exits 0 only if every check passed.
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerShelter.tscn
## Output: ~/workspace/homeward/screenshots_shelter/
## Not part of the suite.

const OUT := "/home/hatch/workspace/homeward/screenshots_shelter"
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null
var story: Node = null
var cam: Camera3D = null
var failures: int = 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("SHELTER CHECK PASS: ", name)
	else:
		failures += 1
		print("SHELTER CHECK FAIL: ", name, " -- ", detail)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

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
	check("cat in cage", bool(story.call("cat_in_cage")),
		"cat at " + str((player as Node3D).global_position) + " cage " + str(story.get("cage_centre")))
	var cc: Vector3 = story.get("cage_centre")
	check("cage sits in the kennel row (z deep in the ward)", cc.z - o.z > 8.0, "cage z-off " + str(cc.z - o.z))
	check("pound entry title names the pound", str((main.get("room_title_label") as Label3D).text).to_lower().contains("pound"),
		str((main.get("room_title_label") as Label3D).text))
	var found_sign: bool = false
	var found_card: bool = false
	var stack: Array = [main.get_node("EscapeRoom")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label3D:
			if (n as Label3D).text == "ANIMAL SHELTER":
				found_sign = true
			if (n as Label3D).text == "BISCUIT":
				found_card = true
		for ch in n.get_children():
			stack.append(ch)
	check("ANIMAL SHELTER wall sign built", found_sign)
	check("kennel name cards built (BISCUIT)", found_card)

	# --- screenshots ---
	await snap("01_cage_start.png")
	await snap_with_cam("02_kennel_row_wide.png", o + Vector3(-8.5, 2.7, 1.2), o + Vector3(3.5, 0.8, 9.2))
	await snap_with_cam("03_ward_from_north.png", o + Vector3(0, 2.3, -6.8), o + Vector3(0, 1.0, 9.4))
	await snap_with_cam("04_staff_bay.png", o + Vector3(-6.6, 1.7, 4.6), o + Vector3(-4.6, 1.0, 9.4))

	# --- escape end to end: gate PAW ---
	var gate_p: Vector3 = story.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	await wait_sec(0.6)
	check("gate opens on PAW", not bool(story.get("cage_closed")))

	# --- distraction ---
	distract_captor()
	check("plant distraction works", bool(main.call("captor_distracted")))

	# --- bolt-door combo ---
	(player as Node3D).global_position = o + Vector3(13.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)

	# --- walk out ---
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	check("walk-out reaches town play", str(main.get("state")) == "play", "state=" + str(main.get("state")))
	var purs: Dictionary = main.get("pursuers")
	check("pound worker pursues for 30 s", purs.has(main.get("pound_worker")) and absf(float(purs[main.get("pound_worker")]) - 30.0) < 0.01,
		"pursuers=" + str(purs))

	# --- mid-game capture entry still lands in the room ---
	main.set("captor", main.get("pound_worker"))
	main.call("_enter_escape")
	var catp: Vector3 = (player as Node3D).global_position
	check("mid-game entry: state escape", str(main.get("state")) == "escape")
	check("mid-game entry: cat lands on the mat", catp.distance_to(o + Vector3(0, 0.3, 6)) < 1.2,
		"cat at " + str(catp))
	await snap_with_cam("05_midgame_entry.png", o + Vector3(-4.5, 2.2, -2.5), o + Vector3(1.5, 0.7, 7.5))

	print("SHELTER RUNNER DONE failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
