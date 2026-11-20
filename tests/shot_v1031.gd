extends Node
## v1.0.31 screenshot proof (diagnostic — not part of the game).
## Boots the real Main scene and photographs the three changes:
##  1. van_creep.png — LIVE: the cat stands in the officer's sight
##     beside the patrol road; the van must have eased down to its
##     crawl (speed printed) while the notice meter is held at 0.3.
##  2. mailbox_number.png — close-up of a house's mailbox: the lot
##     number printed on its street face, at mailbox size.
##  3. house_front_no_board.png — the same house's whole front:
##     NO address board, NO brass plaque; the mailbox stands out
##     front with the number.
## Output: ~/workspace/homeward/screenshots_v1031/. Run:
##   xvfb-run -a godot --path . tests/ShotV1031.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_v1031"
var main: Node = null
var cam: Camera3D = null

func snap(name: String, pos: Vector3, target: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT1031 saved ", name, " ", img.get_size())

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	main.call("dismiss_splash")
	await get_tree().create_timer(1.0).timeout
	var tp: Object = main.get("title_panel")
	if tp != null:
		(tp as CanvasItem).visible = false
	var sp: Object = main.get("splash_panel")
	if sp != null:
		(sp as CanvasItem).visible = false
	# Park the townsfolk far away so no one interferes or photobombs.
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1
	cam = Camera3D.new()
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	var player: Node3D = main.get("player")
	var van: Node3D = main.get("pound_van")

	# ---- 1. THE CREEP, live ----
	main.set("state", "play")
	player.set("frozen", false)
	main.set("pound_engage_cd", 0.0)
	van.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	van.rotation.y = 0.0
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "patrol")
	main.set("pound_notice", 0.0)
	main.set("pound_creep", 0.0)
	var t: float = 0.0
	while t < 10.0:
		main.set("pound_notice", 0.3) # hold the meter: watching, not pulling over
		player.global_position = van.position + Vector3(6.0, 0.2, 2.5)
		player.set("velocity", Vector3.ZERO)
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if float(main.get("pound_van_speed")) <= 2.0 and float(main.get("pound_creep")) > 0.9:
			break
	print("SHOT1031 creep staged: speed=", main.get("pound_van_speed"), " creep=", main.get("pound_creep"), " state=", main.get("pound_state"))
	main.set_process(false) # freeze the world mid-creep for the photo
	await get_tree().process_frame
	await snap("van_creep.png", van.position + Vector3(9.5, 1.7, 6.2), van.position + Vector3(1.0, 0.9, 0.6))

	# ---- 2 + 3. A house front and its mailbox ----
	var houses: Array = main.get("houses")
	var hsel: Dictionary = houses[0]
	for h in houses:
		if str(h["address"]).begins_with("21 Maple"):
			hsel = h
			break
	var hpos: Vector3 = hsel["pos"]
	var facing: float = float(hsel.get("facing", 1.0))
	var world_node: Node = main.get_node("World")
	var grp: Node3D = null
	for ch in world_node.get_children():
		if ch is Node3D and not (ch is MultiMeshInstance3D) and (ch as Node3D).position.distance_to(hpos) < 0.6:
			grp = ch as Node3D
	var mb: Node3D = null
	if grp != null:
		for ch2 in grp.get_children():
			if ch2.name == "Mailbox":
				mb = ch2 as Node3D
	print("SHOT1031 house: ", hsel["address"], " mailbox=", mb)
	if mb != null:
		var mbg: Vector3 = mb.global_position
		await snap("mailbox_number.png", mbg + Vector3(0.85, 0.45, facing * 1.5), mbg + Vector3(0, 1.08, 0))
	await snap("house_front_no_board.png", hpos + Vector3(7.5, 3.0, facing * 14.5), hpos + Vector3(0, 2.0, 0))
	print("SHOT1031 DONE")
	get_tree().quit()
