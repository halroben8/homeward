extends Node
## v1.0.32 screenshot proof (diagnostic — not part of the game).
## Boots the real Main scene and photographs the all-Meshy
## buildings finish:
##  1. far_bank_birch.png — from the Birch Lane fence gap (x=24)
##     looking north across the river: the far-bank shore row
##     must be Meshy house models, no box/slab houses, no
##     ShoreGableInfill prisms.
##  2. diorama_north.png — the escape-exterior street from the
##     rooms' side, looking north across the road at the three
##     diorama houses (Meshy models now).
##  3. diorama_east.png — the fourth diorama house on the east
##     side, front facing the rooms.
##  4. town_wide.png — a wide elevated town shot.
## Output: ~/workspace/homeward/screenshots_v1032/. Run:
##   xvfb-run -a godot --path . tests/ShotV1032.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_v1032"
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
	print("SHOT1032 saved ", name, " ", img.get_size())

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
	# Park the actors far away so nobody photobombs the scenery.
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1
	var player: Node3D = main.get("player")
	player.global_position = Vector3(-100, 0.2, 80)
	var van: Node3D = main.get("pound_van")
	if van != null:
		van.global_position = Vector3(-105, 0, 75)
	cam = Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	var o: Vector3 = main.get("escape_origin")
	# 1. Far bank from the Birch Lane fence gap.
	await snap("far_bank_birch.png", Vector3(24, 2.2, -80), Vector3(-6, 4.0, -124))
	# 2. Diorama street, north row, from the rooms' side.
	await snap("diorama_north.png", o + Vector3(2, 1.7, -13), o + Vector3(2, 3.2, -33.5))
	# 3. Diorama east house, front facing the rooms (-x).
	await snap("diorama_east.png", o + Vector3(19, 1.7, 4), o + Vector3(33.5, 3.0, 4))
	# 4. Wide town shot, elevated, looking north over the river.
	await snap("town_wide.png", Vector3(0, 30, 62), Vector3(0, 0, -70))
	print("SHOT1032 DONE")
	get_tree().quit()
