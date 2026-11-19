extends Node
## v1.0.27 PROOF runner: the opening, played the way Michael
## plays it — real taps through the real dispatcher (splash tap,
## START tap with its full touch+echo sequence), then the
## instinctive JOYSTICK GRAB ~3 s into the beats (the input that
## silently skipped the whole cutscene in every build up to
## v1.0.26), then hands off while the beats play out. All frames
## are the game's own follow camera — nothing is repositioned.
## user://boot_marker.txt is seeded "complete" first: the
## upgraded-install condition (v1.0.13–v1.0.26 data on the phone).
## Run: xvfb-run -a godot --path . tests/ShotV1027Opening.tscn
## Output: ~/workspace/homeward/screenshots_v1027/

const OUT := "/home/hatch/workspace/homeward/screenshots_v1027"

var main: Node = null
var player: Node = null
var story: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name + ".png")
	print("SNAP ", name, " state=", str(main.get("state")), " phase=", str(story.get("phase")))

func push_touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = pos
	t.pressed = pressed
	get_viewport().push_input(t)

func push_mouse(pos: Vector2, pressed: bool) -> void:
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.position = pos
	m.pressed = pressed
	get_viewport().push_input(m)

func phone_tap(pos: Vector2) -> void:
	push_touch(pos, true)
	push_mouse(pos, true)
	push_touch(pos, false)
	push_mouse(pos, false)

func find_start_button(n: Node) -> Button:
	if n is Button and (n as Button).text.contains("START"):
		return n as Button
	for c in n.get_children():
		var r := find_start_button(c)
		if r != null:
			return r
	return null

# Poll story/main keys until they match (real seconds cap).
func wait_for(what: String, key: String, want: String, cap_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(cap_s * 1000.0):
		var v: String = str(story.get(key)) if what == "story" else str(main.get(key))
		if v == want:
			return true
		await get_tree().process_frame
	print("PROOF WAIT TIMEOUT ", key, " != ", want)
	return false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# The upgraded-install seed: a previous version's completed
	# boot marker, exactly what Michael's phone carries.
	var f := FileAccess.open("user://boot_marker.txt", FileAccess.WRITE)
	if f:
		f.store_string("complete")
		f.close()
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(0.6)
	player = main.get("player")
	story = main.get("story")
	print("PROOF boot done state=", str(main.get("state")))
	phone_tap(Vector2(640, 200)) # dismiss the splash, like a player
	await wait_sec(0.5)
	var btn := find_start_button(main)
	phone_tap(btn.get_global_rect().get_center()) # START
	print("PROOF START tapped, state=", str(main.get("state")), " phase=", str(story.get("phase")))
	# This VM renders the town at a crawl (physics-step dilation
	# stretches game time ~7x); speed the clock so the beats
	# complete inside the run. Content is unaffected.
	Engine.time_scale = 3.0
	# Beat 1: leaving home.
	await wait_sec(1.4)
	await snap("01_leaving_home")
	# THE OLD KILLER: grab the joystick to steer, ~3 s in, hold it
	# a moment, let go. In v1.0.26 this jumped straight to the cage.
	await wait_sec(1.6)
	push_touch(Vector2(180, 520), true, 1)
	push_mouse(Vector2(180, 520), true)
	await wait_sec(1.2)
	push_touch(Vector2(180, 520), false, 1)
	push_mouse(Vector2(180, 520), false)
	print("PROOF after joystick grab: state=", str(main.get("state")),
		" phase=", str(story.get("phase")), " finished=", str(story.get("finished")),
		" skip_btn_visible=", str((story.get("skip_btn") as Button).visible))
	# Beat 2: the collar drop.
	var t0 := Time.get_ticks_msec()
	while not bool(story.get("collar_dropped")) and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	await wait_sec(0.8)
	await snap("02_collar_dropped")
	# Beat 3: the worker's line.
	await wait_for("story", "phase", "line", 120.0)
	t0 = Time.get_ticks_msec()
	while int(story.get("line_step")) != 1 and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	await wait_sec(0.7)
	await snap("03_worker_line")
	# Beat 4: the scoop.
	await wait_for("main", "state", "cutscene", 90.0)
	await wait_sec(1.6)
	await snap("04_scoop")
	# Beat 5: the cage.
	await wait_for("main", "state", "escape", 120.0)
	t0 = Time.get_ticks_msec()
	while not bool(story.get("cage_closed")) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	await wait_sec(1.6)
	await snap("05_pound_cage")
	print("PROOF DONE state=", str(main.get("state")), " cage_closed=", str(story.get("cage_closed")),
		" cat_in_cage=", str(story.call("cat_in_cage")))
	get_tree().quit(0)
