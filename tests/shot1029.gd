extends Node
## v1.0.29 screenshot probe (diagnostic — not part of the game).
## Boots the real Main scene, waits for the build, then parks a
## free camera at street level in front of the new Meshy buildings
## and saves one PNG per spot to ~/workspace/homeward/
## screenshots_v1029/. Run:
##   xvfb-run -a godot --path . tests/Shot1029.tscn

var main: Node = null
var cam: Camera3D = null

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	main.call("dismiss_splash")
	await get_tree().create_timer(2.0).timeout
	# hide the title overlay so the town is unobstructed
	var tp: Object = main.get("title_panel")
	if tp != null:
		(tp as CanvasItem).visible = false
	var sp2: Object = main.get("splash_panel")
	if sp2 != null:
		(sp2 as CanvasItem).visible = false
	await get_tree().create_timer(0.5).timeout
	cam = Camera3D.new()
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	var shots: Array = [
		# name, camera pos, look target
		["maple_street_houses", Vector3(-38, 1.8, -12), Vector3(-54, 1.6, -30)],
		["bakery", Vector3(54.5, 1.8, 8.5), Vector3(62.5, 1.7, -4)],
		["school", Vector3(-6, 2.2, -13), Vector3(-6, 2.6, -30)],
		["police_station", Vector3(-42, 1.9, 17), Vector3(-42, 2.2, 33)],
		["library", Vector3(-2, 1.9, -49), Vector3(-2, 2.2, -66)],
		["apartment_block", Vector3(-6, 2.4, 17), Vector3(-6, 3.6, 2)],
		["oak_avenue_houses", Vector3(24, 1.8, 15), Vector3(-2, 1.6, 33)],
		["fire_station", Vector3(-112, 1.9, 17), Vector3(-112, 2.2, 33)],
	]
	var dir := DirAccess.open("/home/hatch/workspace/homeward")
	if dir != null and not dir.dir_exists("screenshots_v1029"):
		dir.make_dir("screenshots_v1029")
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in range(6):
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "/home/hatch/workspace/homeward/screenshots_v1029/" + str(s[0]) + ".png"
		img.save_png(path)
		print("SHOT1029 saved ", path)
	print("SHOT1029 DONE")
	get_tree().quit()
