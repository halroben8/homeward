extends Node
## HOMEWARD map-doubling proof screenshots.
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerMap.tscn
##   overview_east   raised camera over the new east district
##   overview_whole  the whole doubled town, high from the south
##   street_new      street level in the new district (Harbour
##                   Market / Maple Street) — the game's own camera
##   street_infill   street level at a filled old-town gap (Oak
##                   Avenue infill row) — the game's own camera
## Output: ~/workspace/homeward/screenshots_map/

const OUT := "/home/hatch/workspace/homeward/screenshots_map"
var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func snap_with_cam(name: String, pos: Vector3, target: Vector3) -> void:
	# Freeze the game's own camera driver, or it re-poses the
	# camera from its damped target before the frame draws.
	main.set_process(false)
	await get_tree().process_frame
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())
	main.set_process(true)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	cam = main.get("cam")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	# 1) overview of the new east district
	await snap_with_cam("overview_east.png", Vector3(246, 165, 150), Vector3(246, 0, -5))
	# 2) the whole doubled town
	await snap_with_cam("overview_whole.png", Vector3(126, 330, 275), Vector3(126, 0, -10))
	# 3) street level in the new district: on Maple Street by the
	# Harbour Market, game's own camera behind the cat
	(player as Node3D).global_position = Vector3(200, 0.2, -13.5)
	await wait_sec(1.6)
	await snap("street_new.png")
	# 4) street level at a filled old-town gap: Oak Avenue, with
	# the new infill houses (21 Oak at x38, 30 Oak at x10 south)
	(player as Node3D).global_position = Vector3(46, 0.2, 9.5)
	await wait_sec(1.6)
	await snap("street_infill.png")
	print("DONE")
	get_tree().quit(0)
