extends Node
## v1.0.24 verification shot: the escape panel MID-COMBO, with the
## combination entered through the REAL tap event sequence (raw
## touch press + its emulated-mouse echo, via main._input) — two
## steps lit from two taps, the v1.0.24 one-tap-one-step fix made
## visible.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1024/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(sname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + sname)
	print("V1024 saved ", sname)

func _tap(letter_pos: Vector2, idx: int) -> void:
	# One physical tap, exactly as the engine delivers it on the
	# phone: the raw touch press, then the emulated mouse press,
	# then both releases. Before v1.0.24 this filled TWO chips.
	var tp := InputEventScreenTouch.new()
	tp.index = idx
	tp.pressed = true
	tp.position = letter_pos
	main.call("_input", tp)
	var mp := InputEventMouseButton.new()
	mp.button_index = MOUSE_BUTTON_LEFT
	mp.pressed = true
	mp.position = letter_pos
	main.call("_input", mp)
	var tr := InputEventScreenTouch.new()
	tr.index = idx
	tr.pressed = false
	tr.position = letter_pos
	main.call("_input", tr)
	var mr := InputEventMouseButton.new()
	mr.button_index = MOUSE_BUTTON_LEFT
	mr.pressed = false
	mr.position = letter_pos
	main.call("_input", mr)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await wait_sec(0.5)
	player = main.get("player")
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	print("V1024 build complete")
	main.call("dismiss_splash")
	await wait_sec(0.4)
	main.call("start_game")
	await wait_sec(0.4)
	var bguard := 0
	while bguard < 900 and main.get("pound_worker") == null:
		await get_tree().physics_frame
		bguard += 1
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	# In the pound escape room now. Open the panel and pin a known
	# combo so the chips are readable: B B A B A.
	main.call("_open_escape_panel")
	main.set("escape_combo", ["B", "B", "A", "B", "A"])
	(main.get("escape_panel") as Control).call("set_combo_seq", ["B", "B", "A", "B", "A"])
	main.set("combo_index", 0)
	await wait_sec(0.3)
	var paw_pos: Vector2 = (main.get("paw_btn") as Button).get_global_rect().get_center()
	_tap(paw_pos, 3)
	_tap(paw_pos, 3)
	await wait_sec(0.4)
	print("V1024 combo_index after two B taps (want 2): ", int(main.get("combo_index")))
	await snap("escape_panel_midcombo.png")
	print("V1024 DONE")
	get_tree().quit()
