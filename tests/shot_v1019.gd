extends Node
## ZANDER'S RUN v1.0.19 — screenshot runner (not part of the suite):
## the pronoun fix, proven on screen:
##  1. pound_escape.png — the pound escape with the OFFICER as
##     captor: the entry message and the distract line both use
##     he/him ("and so is he!", "distract him!").
##  2. house_escape.png — the house escape with the YOUNG WOMAN as
##     captor: every line on screen uses she/her consistently
##     ("and so is she!", "distract her!") — the v1.0.17 screenshot
##     Michael sent mixed her/him on this one screen.
## Boots the real game and drives the real flows. PNGs land in
## ~/workspace/homeward/screenshots_v1019/.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1019/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name)
	print("saved ", name, " ", img.get_size())

func band_text() -> String:
	var lab = main.get("message_label")
	return str(lab.text) if lab else ""

func wait_band_contains(needle: String, timeout_s: float) -> bool:
	var t: float = 0.0
	while t < timeout_s:
		if band_text().contains(needle):
			return true
		await wait_sec(0.3)
		t += 0.3
	return band_text().contains(needle)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	player = main.get("player")
	print("V1019: build_complete")

	# ---- 1: the opening pound escape — the officer, he/him ----
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.5)
	print("V1019: after skip, state=", str(main.get("state")), " captor is worker=", main.get("captor") == main.get("pound_worker"))
	# out of the cage, the real PAW path — the held entry beats are
	# released into the message band as the gate opens.
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	# stage the cat in the open room and let the band reach beat 1
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(-3.2, 0.3, 0.6)
	main.set("look_yaw", 3.14159)
	main.set("look_pitch_deg", 10.0)
	var got_pound: bool = await wait_band_contains("POUND", 20.0)
	var dl = main.get("distract_label")
	print("V1019: pound band='", band_text(), "' distract='", str(dl.text) if dl else "?", "' beat_found=", got_pound)
	await wait_sec(0.6)
	await snap("pound_escape.png")

	# ---- 2: a regular capture — the young woman, she/her ----
	# (park the officer first: both rooms share the escape_origin
	# slot, so the previous captor would otherwise stand in shot)
	var worker19: Node = main.get("pound_worker")
	worker19.set("active", false)
	(worker19 as Node3D).visible = false
	(worker19 as Node3D).global_position = Vector3(-110, 0.2, 80)
	var woman: Node = null
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110, 0.2, 80)
		if str(n.get("npc_type")) == "woman" and woman == null:
			woman = n
	main.call("clear_message_band")
	main.set("captor", woman)
	main.call("_enter_escape")
	(player as Node3D).global_position = o + Vector3(-3.2, 0.3, 0.6)
	main.set("look_yaw", 3.14159)
	main.set("look_pitch_deg", 10.0)
	var got_house: bool = await wait_band_contains("so is she", 10.0)
	await wait_sec(0.6) # let the distract HUD refresh on real frames
	print("V1019: house band='", band_text(), "' distract='", str(dl.text) if dl else "?", "' beat_found=", got_house)
	await snap("house_escape.png")
	print("V1019: done")
	get_tree().quit()
