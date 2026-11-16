extends Node
## HOMEWARD v1.1 ESCAPE PANEL screenshots.
## Run under Xvfb:  xvfb-run -a godot --path . tests/ShotRunnerEscape.tscn
## Drives the REAL flow for every mechanism: walk to it (prompt),
## open the panel, do the combo, watch the escape animation.
## Output: ~/workspace/homeward/screenshots_escape/

const OUT := "/home/hatch/workspace/homeward/screenshots_escape"
const COMBO: Array = ["down", "up", "down", "up", "paw"]
var main: Node = null
var player: Node = null
var woman: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String, crop_centre: bool = false) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())
	if crop_centre:
		var w: int = img.get_width()
		var h: int = img.get_height()
		var region := Rect2i(int(w * 0.28), int(h * 0.18), int(w * 0.44), int(h * 0.6))
		img.get_region(region).save_png(OUT + "/" + name.replace(".png", "_crop.png"))
		print("SHOT: ", name.replace(".png", "_crop.png"))

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func force_steps(kinds: Array) -> void:
	var steps: Array = []
	for k in kinds:
		steps.append({"kind": k})
	main.set("escape_steps", steps)
	main.set("escape_step", 0)
	main.set("escape_prog", 0.0)
	main.call("_reset_escape_props")
	main.call("_update_escape_label")

func stage_cat(pos: Vector3, yaw_rad: float, pitch: float = 10.0) -> void:
	(player as Node3D).global_position = pos
	player.set("velocity", Vector3.ZERO)
	player.set("rotation", Vector3.ZERO)
	main.set("look_yaw", yaw_rad)
	main.set("look_pitch_deg", pitch)

func do_combo() -> void:
	for inp in COMBO:
		main.call("escape_panel_input", inp)

func wait_until_play(max_s: float) -> void:
	var t: float = 0.0
	while str(main.get("state")) == "escape" and t < max_s:
		await wait_sec(0.25)
		t += 0.25

func clear_pursuit() -> void:
	(main.get("pursuers") as Dictionary).clear()
	if woman:
		woman.call("stop_pursuit")
	park_npcs_far()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1920, 864))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	player.set("idle_next_in", 999.0)
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman":
			woman = n
			break
	main.set("captor", woman)

	# ================= WINDOW (latch, then push) =================
	main.call("_enter_escape")
	force_steps(["latch", "winpush"])
	stage_cat(Vector3(200, 0.3, -7.9), 0.0)
	await wait_sec(1.2)
	await snap("prompt_window.png")
	main.call("_on_escape_prompt_pressed")
	await wait_sec(0.5)
	await snap("panel_latch_start.png")
	main.call("escape_panel_input", "down")
	main.call("escape_panel_input", "up")
	await wait_sec(0.4)
	await snap("panel_latch_mid.png")
	main.call("escape_panel_input", "down")
	main.call("escape_panel_input", "up")
	main.call("escape_panel_input", "paw")
	await wait_sec(0.4)
	main.call("_on_escape_prompt_pressed")
	await wait_sec(0.5)
	await snap("panel_winpush_start.png")
	do_combo()
	await wait_sec(1.12)
	await snap("escape_anim_window_mid.png", true)
	await wait_until_play(4.0)
	main.set("look_yaw", PI)
	await wait_sec(1.0)
	await snap("outside_after_escape.png")
	clear_pursuit()

	# ================= PET DOOR =================
	main.call("_enter_escape")
	force_steps(["petdoor"])
	stage_cat(Vector3(206, 0.3, -8.1), 0.0)
	await wait_sec(1.2)
	await snap("prompt_petdoor.png")
	main.call("_on_escape_prompt_pressed")
	await wait_sec(0.5)
	await snap("panel_petdoor_start.png")
	do_combo()
	await wait_sec(1.08)
	await snap("escape_anim_petdoor_mid.png", true)
	await wait_until_play(4.0)
	clear_pursuit()

	# ================= BOLT (back door) =================
	main.call("_enter_escape")
	force_steps(["bolt"])
	stage_cat(Vector3(212.4, 0.3, 3.4), -PI / 2.0, 8.0)
	await wait_sec(1.0)
	main.call("_on_escape_prompt_pressed")
	await wait_sec(0.5)
	await snap("panel_bolt_start.png")
	do_combo()
	await wait_sec(1.25)
	await snap("escape_anim_bolt_mid.png", true)
	await wait_until_play(4.0)
	clear_pursuit()

	# ================= CARRIER =================
	main.call("_enter_escape")
	force_steps(["carrier"])
	stage_cat(Vector3(194, 0.3, 7.5), 0.0)
	await wait_sec(1.0)
	main.call("_on_escape_prompt_pressed")
	await wait_sec(0.5)
	await snap("panel_carrier_start.png")
	do_combo()
	await wait_sec(0.85)
	await snap("escape_anim_carrier_mid.png", true)
	await wait_until_play(4.0)

	print("SHOTS DONE -> ", OUT)
	get_tree().quit(0)
