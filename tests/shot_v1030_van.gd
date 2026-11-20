extends Node
## v1.0.30 screenshot proof (diagnostic — not part of the game).
## Boots the real Main scene, waits for the build, stages the pound
## van side-on on its patrol road and photographs BOTH flanks:
## the code-added blue Label3D lettering must be GONE and the
## Meshy texture's baked ANIMAL CONTROL lettering + paw print
## must be what reads. Output: ~/workspace/homeward/
## screenshots_v1030/. Run:
##   xvfb-run -a godot --path . tests/ShotV1030Van.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_v1030"
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
	print("SHOT1030 saved ", name, " ", img.get_size())

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
	# Park the townsfolk and the cat far away so the frame is clean.
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1
	(main.get("player") as Node3D).global_position = Vector3(30, 0.2, 60)
	# Stage the van on its patrol lane and freeze the world.
	var van: Node3D = main.get("pound_van")
	van.position = Vector3(30, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	van.rotation.y = 0.0
	main.set("pound_state", "patrol")
	main.set_process(false)
	await get_tree().process_frame
	cam = Camera3D.new()
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	# North flank (the side Michael photographed) and south flank.
	await snap("van_flank_north.png", Vector3(33.5, 1.5, 11.4), Vector3(29.4, 1.05, 16.8))
	await snap("van_flank_south.png", Vector3(26.5, 1.5, 22.2), Vector3(30.6, 1.05, 16.8))
	print("SHOT1030 DONE")
	get_tree().quit()
