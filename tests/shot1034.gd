extends Node
## v1.0.34 screenshot + district-staging probe (diagnostic — not
## part of the game). Boots the real Main scene on the DOUBLED
## town, stages the player WEST -> EAST -> WEST so the district
## streaming switches and restores, printing bands_on at each
## stage, and saves PNGs to ~/workspace/homeward/
## screenshots_v1034/:
##   wide_west_all_on.png   elevated wide from the west, all west
##                          bands on (start of run)
##   east_street.png        playing-height street in the east
##                          district (player staged east)
##   wide_east_west_off.png elevated wide from the east with the
##                          two west bands OFF (same staging)
##   wide_east_restored.png same east framing after returning
##                          west: west bands restored, east bands
##                          now off instead
## Run: xvfb-run -a godot --path . tests/Shot1034.tscn

var main: Node = null
var cam: Camera3D = null

func _bands_str() -> String:
	var bands: Array = main.get("districts")
	var s := ""
	for b in bands:
		s += "1" if bool(b["on"]) else "0"
	return s

func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "/home/hatch/workspace/homeward/screenshots_v1034/" + name
	img.save_png(path)
	print("SHOT1034 saved ", path)

func _stage(pos: Vector3, label: String) -> void:
	(main.get("player") as Node3D).global_position = pos
	await get_tree().create_timer(1.6).timeout # districts throttle is 0.25 s
	print("SHOT1034 stage ", label, " bands_on=", _bands_str(), " static_mb=", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var dir := DirAccess.open("/home/hatch/workspace/homeward")
	if dir != null and not dir.dir_exists("screenshots_v1034"):
		dir.make_dir("screenshots_v1034")
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	print("SHOT1034 build_complete houses=", (main.get("houses") as Array).size(), " districts_built=", bool(main.get("districts_built")))
	main.call("dismiss_splash")
	await get_tree().create_timer(1.0).timeout
	var tp: Object = main.get("title_panel")
	if tp != null:
		(tp as CanvasItem).visible = false
	var sp2: Object = main.get("splash_panel")
	if sp2 != null:
		(sp2 as CanvasItem).visible = false
	main.set("state", "play")
	(main.get("player") as Object).set("frozen", false)
	cam = Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	# --- stage WEST: everything nearby on ---
	await _stage(Vector3(-60, 0.6, 0), "WEST")
	cam.position = Vector3(-95, 58, 128)
	cam.look_at(Vector3(150, 0, -12), Vector3.UP)
	await _snap("wide_west_all_on.png")
	# --- stage EAST: west bands switch off ---
	await _stage(Vector3(320, 0.6, -20), "EAST")
	cam.position = Vector3(238, 1.8, 14)
	cam.look_at(Vector3(300, 1.7, 30), Vector3.UP)
	await _snap("east_street.png")
	cam.position = Vector3(368, 58, 128)
	cam.look_at(Vector3(110, 0, -12), Vector3.UP)
	await _snap("wide_east_west_off.png")
	# --- stage WEST again: west bands restore, east bands off ---
	await _stage(Vector3(-60, 0.6, 0), "WEST-AGAIN")
	cam.position = Vector3(368, 58, 128)
	cam.look_at(Vector3(110, 0, -12), Vector3.UP)
	await _snap("wide_east_restored.png")
	print("SHOT1034 DONE")
	get_tree().quit()
