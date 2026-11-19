extends Node
## HOMEWARD STORY PART 1 — screenshot runner for the OPENING
## CUTSCENE + POUND START (2026-11-18). Boots the real game and
## plays the opening through, snapping the key beats:
##   01_leaving_home    — the cat trots out of his own front door
##   02_collar_dropped  — mid-stroll: the collar on the ground
##                        behind him (follow camera, as the player
##                        sees it)
##   03_collar_tag_closeup — a staged close framing of the dropped
##                        tag: his name ("Zander") must READ
##   04_worker_line     — the van at the kerb, the worker out, his
##                        kind line in the speech bubble
##   05_scoop           — the ordinary capture scoop, mid-lift
##   06_pound_cage      — gameplay start: the cat in the little
##                        cage at the pound
##   07_gate_open       — PAW at the gate: it swings open
##   08_town_pursuit    — the pound escape walked out: town play,
##                        the worker pursuing
## The street beats play for real through 03; for 04 the runner
## fast-forwards the staging (cat to the kerb, van to just short
## of its stop) so the line and scoop play without minutes of
## approach driving — the flow itself is the game's own (and the
## suite drives it end-to-end unskipped). All waits count FRAMES,
## not seconds: under render load a "second" here is elastic.
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerOpening.tscn
## Output: ~/workspace/homeward/screenshots_opening/
## Not part of the suite.

const OUT := "/home/hatch/workspace/homeward/screenshots_opening"
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null
var story: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

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

# Poll a getter on story/main until it matches, counting frames.
func wait_for(what: String, key: String, want: String, max_frames: int) -> bool:
	for i in range(max_frames):
		var v: String = str(story.get(key)) if what == "story" else str(main.get(key))
		if v == want:
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
	EmojiFont.apply() # render-only emoji fallback — before Main is instanced
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
	print("RUNNER home=", str(main.get("home_address")), " story=", str(story != null))
	main.call("dismiss_splash")
	main.call("start_game")
	print("RUNNER state after START=", str(main.get("state")), " phase=", str(story.get("phase")))

	# 01 — leaving the house (early in the leave beat)
	await wait_sec(1.6)
	await snap("01_leaving_home.png")

	# 02 — the collar drop, from the follow camera
	var guard: int = 0
	while not bool(story.get("collar_dropped")) and guard < 1200:
		await get_tree().process_frame
		guard += 1
	print("RUNNER collar_dropped=", str(story.get("collar_dropped")), " after ", guard, " frames")
	await wait_frames(4)
	await snap("02_collar_dropped.png")

	# 03 — the dropped tag, framed close: the address must read.
	# Wait until he has strolled clear of it first (he drops it at
	# his feet and walks on, oblivious — the beat itself).
	var dc: Node3D = story.get("dropped_collar")
	if dc:
		guard = 0
		while (player as Node3D).global_position.distance_to(dc.global_position) < 2.5 and guard < 900:
			await get_tree().process_frame
			guard += 1
		# Frame the tag from its own print: the label's world
		# transform says where the print is and which way its top
		# points, so stand on the reader's side of it, above,
		# looking down. (Street-direction offsets framed it from
		# the wrong side on some homes.) Close in: the tag is a
		# real 2.5 cm pet tag now, not the old 30 cm proof disc.
		var lbl: Object = story.get("dropped_label")
		if lbl != null:
			var tp: Vector3 = (lbl as Node3D).global_position
			var text_up: Vector3 = (lbl as Node3D).global_transform.basis.y
			text_up.y = 0.0
			text_up = text_up.normalized()
			await snap_with_cam("03_collar_tag_closeup.png", tp - text_up * 0.03 + Vector3(0, 0.30, 0), tp)
		else:
			var tp2: Vector3 = dc.global_position + Vector3(0, 0.0, 0.1075).rotated(Vector3.UP, dc.rotation.y)
			await snap_with_cam("03_collar_tag_closeup.png", tp2 + Vector3(0, 0.22, 0.17), tp2)
	else:
		print("RUNNER: no dropped collar to frame!")

	# 04 — fast-forward the staging: the cat to his kerb spot, the
	# van to just short of its stop; the module drives the rest
	# (park, worker out, the walk up, the line) itself.
	var stroll_end: Vector3 = story.get("stroll_end")
	(player as Node3D).global_position = Vector3(stroll_end.x, 0.25, stroll_end.z)
	player.set("velocity", Vector3.ZERO)
	var van_stop: Vector3 = story.get("van_stop")
	var wdx2: float = float(story.get("walk_dir_x"))
	var van: Node3D = main.get("pound_van")
	van.global_position = Vector3(van_stop.x - wdx2 * 4.0, 0, van_stop.z)
	story.set("phase", "wait_van")
	story.set("phase_t", 0.0)
	await wait_for("story", "phase", "line", 1500)
	guard = 0
	while int(story.get("line_step")) != 1 and guard < 900:
		await get_tree().process_frame
		guard += 1
	# Frame the pair from off the road with headroom — the follow
	# camera sits too low to keep the speech bubble in frame.
	var wp: Vector3 = (main.get("pound_worker") as Node3D).global_position
	var mid: Vector3 = (wp + (player as Node3D).global_position) * 0.5
	var fcg2: float = float(story.get("facing"))
	await snap_with_cam("04_worker_line.png", mid + Vector3(-wdx2 * 3.4, 1.6, -fcg2 * 2.6), mid + Vector3(0, 1.0, 0))

	# 05 — the scoop, mid-lift
	await wait_for("main", "state", "cutscene", 1500)
	await wait_sec(1.9)
	await snap("05_scoop.png")

	# 06 — the pound: the cat in the little cage (gate on the cage
	# actually being shut — the module cages him on the first
	# escape tick, under the fade)
	await wait_for("main", "state", "escape", 1500)
	guard = 0
	while not bool(story.get("cage_closed")) and guard < 600:
		await get_tree().process_frame
		guard += 1
	await wait_sec(1.3) # the fade-in finishes
	print("RUNNER cage_closed=", str(story.get("cage_closed")), " cat_in_cage=", str(story.call("cat_in_cage")))
	await snap("06_pound_cage.png")

	# 07 — PAW the gate open (the real interact path)
	var gate_p: Vector3 = story.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	await wait_sec(0.6)
	print("RUNNER cage_closed after paw=", str(story.get("cage_closed")))
	await snap("07_gate_open.png")

	# 08 — the pound escape, walked out into the town pursuit
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)
	# Let the camera finish its flight back from the room (it
	# lerps across the map; an instant snap catches it inside
	# geometry), but snap before his pursuer can close in and
	# re-catch the stationary cat (~2.5 s of game time).
	await wait_sec(1.0)
	await snap("08_town_pursuit.png")
	print("RUNNER state after walk-out=", str(main.get("state")),
		" pursuers=", str((main.get("pursuers") as Dictionary).keys()),
		" collared=", str(main.get("player_collared")))
	print("OPENING SHOTS DONE")
	get_tree().quit(0)
