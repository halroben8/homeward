extends Node
## v1.0.26 ITEM-1 CLOSE-UPS (diagnostic): frames the promenade
## slab and a Maple Street sidewalk stretch at close range —
## the proof geometry for "no grass on pavement, tufts still
## on the lawns". Cameras sit over roads / open lawn (never
## inside a house volume).
## Output: ~/workspace/homeward/screenshots_v1026_verify/.
## Run: xvfb-run -a godot --path . tests/ShotV1026Shots.tscn

var main: Node = null
var cam: Camera3D = null

const OUT := "/home/hatch/workspace/homeward/screenshots_v1026_verify"

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name + ".png")
	print("SNAP ", name)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(0.6)
	cam = main.get("cam")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.3)
	(main.get("story") as Node).call("skip_opening")
	await wait_sec(0.4)
	main.set("state", "play")
	main.set_process(false)
	await wait_sec(0.3)
	# The promenade at close range: from the lawn south of it,
	# looking north across the slab to the riverside strip.
	cam.global_position = Vector3(30, 1.7, -77.5)
	cam.look_at(Vector3(30, 0.1, -86.5), Vector3.UP)
	await wait_sec(0.4)
	await snap("06_promenade_close")
	# Along Maple Street from over the road: both sidewalks and
	# the front lawns either side.
	cam.global_position = Vector3(2, 2.1, -11)
	cam.look_at(Vector3(-32, 0.1, -11), Vector3.UP)
	await wait_sec(0.4)
	await snap("07_maple_corridor")
	print("V1026SHOTS DONE")
	get_tree().quit(0)
