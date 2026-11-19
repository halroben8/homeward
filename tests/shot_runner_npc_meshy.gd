extends Node
## v1.0.15 MESHY NPC SWAP — verification screenshots.
## Boots the real game and photographs the Meshy NPCs where the
## player meets them:
##   pound_officer     — the officer (pound worker) inside the
##                       shelter ward, from the cat's side of the room.
##   lineup_front/side — officer, woman, kid, dog walker + dog,
##                       shopkeeper, and a code-built pedestrian
##                       (control) in a row on the south lawn.
##   walk_woman_0..2 / walk_kid_0..2 — the model's own Walking
##                       clip carrying them down a street.
##   pet_woman / pet_kid — REAL paw-reaction petting, mid-pet.
##   carry_side        — a REAL capture (on_cat_taken), cradle beat.
##   van_officer       — the officer standing by the pound van,
##                       net in hand (BoneAttachment check).
##   chase_net         — a REAL chase: net gripped two-handed,
##                       arms mirrored, legs on the Running clip.
## Output: ~/workspace/homeward/screenshots_npc_meshy/
## Not part of the suite.

const OUT := "/home/hatch/workspace/homeward/screenshots_npc_meshy"
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null
var cam: Camera3D = null
var story: Node = null

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

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1

func pick_type(t: String, outfit: int = 0) -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == t and int(n.get("outfit_idx")) == outfit:
			return n
	return null

func hold(n: Node, pos: Vector3, yaw: float) -> void:
	(n as Node3D).global_position = pos
	(n as Node3D).rotation = Vector3(0, yaw, 0)
	n.set("velocity", Vector3.ZERO)
	n.set("wander_target", pos)
	n.set("wander_wait", 999.0)
	var m = n.get("model")
	if m != null:
		(m as Node3D).visible = true
	var dm = n.get("dog_model")
	if dm != null:
		(dm as Node3D).visible = true
	var nl = n.get("name_label")
	if nl != null:
		(nl as Node3D).visible = true

func wait_for_main(key: String, want: String, max_frames: int) -> bool:
	for i in range(max_frames):
		if str(main.get(key)) == want:
			return true
		await get_tree().process_frame
	print("RUNNER WAIT TIMEOUT: ", key, " != ", want)
	return false

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
	cam = main.get("cam")
	story = main.get("story")
	for layer_name in ["hud_layer", "touch_layer"]:
		var layer: CanvasLayer = main.get(layer_name)
		if layer:
			layer.visible = false
	main.call("dismiss_splash")
	main.call("start_game")
	for i in range(10):
		await get_tree().process_frame

	# ============ PART B: the officer in the pound ============
	story.call("skip_opening")
	await wait_for_main("state", "escape", 3000)
	var guard: int = 0
	while not bool(story.get("cage_closed")) and guard < 600:
		await get_tree().process_frame
		guard += 1
	await wait_sec(1.0)
	var worker: Node = main.get("pound_worker")
	var o: Vector3 = main.get("escape_origin")
	# Freeze him mid-room for a clean read (the room AI would
	# wander him out of frame); the cat watches from the mat.
	(worker as Node).set_physics_process(false)
	hold(worker, o + Vector3(1.5, 0.3, 1.2), -0.74)
	worker.call("_animate", 0.016, 0.0)
	(player as Node3D).global_position = o + Vector3(-1.5, 0.3, 3.2)
	await snap_with_cam("pound_officer.png", o + Vector3(-1.6, 1.5, 4.6), o + Vector3(1.2, 0.9, 1.2))
	(worker as Node).set_physics_process(true)
	# Out the real way and end the escape cleanly.
	main.call("_complete_escape")
	(main.get("pursuers") as Dictionary).clear()
	worker.call("stop_pursuit")
	await wait_sec(0.3)

	# ============ PART A: town ============
	park_npcs_far()
	var woman: Node = pick_type("woman", 0)
	var kid: Node = pick_type("kid", 0)
	var walker: Node = pick_type("dogwalker", 0)
	var shop: Node = pick_type("shopkeeper", 0)
	var ped: Node = pick_type("pedestrian", 0)
	(player as Node3D).global_position = Vector3(52, 0.2, 89)
	player.set("velocity", Vector3.ZERO)
	# ---------- lineup ----------
	var lineup: Array = [worker, woman, kid, walker, shop, ped]
	for i in range(lineup.size()):
		if lineup[i] != null:
			hold(lineup[i], Vector3(54.6 + float(i) * 1.9, 0.2, 84), 0.0)
			(lineup[i] as Node).set_physics_process(false)
			lineup[i].call("_animate", 0.016, 0.0)
	await wait_sec(0.3)
	await snap_with_cam("lineup_front.png", Vector3(59.5, 1.45, 90.8), Vector3(59.5, 0.92, 84))
	# Profile pair: officer + dog walker (with dog), close range.
	park_npcs_far()
	hold(worker, Vector3(57.6, 0.2, 84), PI * 0.5)
	hold(walker, Vector3(60.6, 0.2, 84), PI * 0.5)
	(worker as Node).set_physics_process(false)
	(walker as Node).set_physics_process(false)
	worker.call("_animate", 0.016, 0.0)
	walker.call("_animate", 0.016, 0.0)
	await wait_sec(0.2)
	await snap_with_cam("lineup_side.png", Vector3(59.1, 1.3, 87.6), Vector3(59.1, 0.9, 84))
	for i in range(lineup.size()):
		if lineup[i] != null:
			(lineup[i] as Node).set_physics_process(true)
	park_npcs_far()
	hold(worker, Vector3(-100, 0.2, 80), 0.0)
	(worker as Node).set_physics_process(false)
	# ---------- walking clips: woman, then kid, down a street --
	for pair in [[woman, "woman"], [kid, "kid"]]:
		var who: Node = pair[0]
		var tag: String = str(pair[1])
		who.set("role", "ignore")
		hold(who, Vector3(56, 0.2, 30), PI)
		(who as Node).set_physics_process(true)
		who.set("wander_target", Vector3(56, 0.2, 14))
		who.set("wander_wait", 0.0)
		(player as Node3D).global_position = Vector3(50, 0.2, 22)
		for s in range(3):
			await wait_sec(0.55)
			var wp: Vector3 = (who as Node3D).global_position
			await snap_with_cam("walk_" + tag + "_" + str(s) + ".png", wp + Vector3(2.6, 1.15, 1.4), wp + Vector3(0, 0.85, 0))
		hold(who, Vector3(-104, 0.2, 80), 0.0)
	# ---------- petting: woman, then kid (real reactions) -----
	for pair in [[woman, "woman"], [kid, "kid"]]:
		var who2: Node = pair[0]
		var tag2: String = str(pair[1])
		(who2 as Node).set_physics_process(true)
		who2.set("role", "friendly")
		hold(who2, Vector3(61.1, 0.2, 84), -PI * 0.5)
		(player as Node3D).global_position = Vector3(60.2, 0.2, 84)
		(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
		player.set("velocity", Vector3.ZERO)
		who2.set("interact_cooldown", 0.0)
		who2.set("notice_cooldown", 0.0)
		who2.call("react_to_attention")
		who2.set("interact_kind", "pet")
		var g2: float = 0.0
		while g2 < 9.0:
			await wait_sec(0.15)
			g2 += 0.15
			if str(who2.get("interact_state")) == "pet" and float(who2.get("bend_a")) > 0.85:
				break
		print("pet staging ", tag2, ": state=", str(who2.get("interact_state")), " bend_a=", str(who2.get("bend_a")))
		await snap_with_cam("pet_" + tag2 + ".png", Vector3(59.1, 0.72, 85.7), Vector3(60.7, 0.5, 84))
		await snap_with_cam("pet_" + tag2 + "_side.png", Vector3(60.6, 0.78, 87.3), Vector3(60.6, 0.48, 84))
		park_npcs_far()
	# ---------- capture carry: the woman, cradle beat ---------
	(woman as Node).set_physics_process(true)
	hold(woman, Vector3(61.05, 0.2, 84), -PI * 0.5)
	woman.set("mode", "wander")
	woman.set("notice", 0.0)
	woman.set("grab_progress", 0.0)
	woman.call("set_expression", "neutral")
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	player.set("frozen", false)
	await wait_sec(0.35)
	main.call("on_cat_taken", woman)
	var g3: float = 0.0
	while str(main.get("state")) == "cutscene" and float(main.get("cutscene_t")) < 2.8 and g3 < 9.0:
		await wait_sec(0.03)
		g3 += 0.03
	await snap_with_cam("carry_side.png", Vector3(63.6, 1.25, 87.2), Vector3(60.6, 0.95, 84))
	g3 = 0.0
	while str(main.get("state")) == "cutscene" and g3 < 8.0:
		await wait_sec(0.25)
		g3 += 0.25
	if str(main.get("state")) == "escape":
		main.call("_complete_escape")
		(main.get("pursuers") as Dictionary).clear()
		woman.call("stop_pursuit")
		await wait_sec(0.3)
	# ---------- officer by the van + a real chase -------------
	park_npcs_far()
	(worker as Node).set_physics_process(true)
	var van: Node3D = main.get("pound_van")
	var van_pos: Vector3 = van.global_position
	var side: Vector3 = (van.global_transform.basis * Vector3(0.6, 0, 2.1))
	hold(worker, van_pos + side + Vector3(0, 0.2, 0), PI)
	worker.call("set_net_visible", true)
	(player as Node3D).global_position = van_pos + Vector3(6, 0.2, 6)
	await wait_sec(0.4)
	var wp2: Vector3 = (worker as Node3D).global_position
	await snap_with_cam("van_officer.png", wp2 + Vector3(2.4, 1.5, 2.6), wp2 + Vector3(0, 1.0, 0))
	# Chase: enter through the game's own door — main's van
	# state machine set to "chase" + the worker's _start_chase,
	# exactly what the pull-over exit does — but staged on open
	# ground (the van kerb is too cramped to read a run). The
	# tell burns ~0.85s standing; snaps land after he's moving.
	hold(worker, Vector3(56, 0.2, 26), PI)
	(player as Node3D).global_position = Vector3(56, 0.2, 19.5)
	player.set("velocity", Vector3.ZERO)
	main.set("pound_state", "chase")
	worker.set("active", true)
	worker.set("notice", 1.0)
	worker.call("_start_chase")
	await wait_sec(1.15)
	var wp3: Vector3 = (worker as Node3D).global_position
	await snap_with_cam("chase_net.png", wp3 + Vector3(2.6, 1.3, 0.4), wp3 + Vector3(0, 0.95, 0))
	await wait_sec(0.3)
	var wp4: Vector3 = (worker as Node3D).global_position
	await snap_with_cam("chase_net2.png", wp4 + Vector3(2.6, 1.3, 0.4), wp4 + Vector3(0, 0.95, 0))
	worker.call("stop_pursuit")
	main.set("pound_state", "patrol")
	print("NPC MESHY SHOTS DONE")
	get_tree().quit(0)
