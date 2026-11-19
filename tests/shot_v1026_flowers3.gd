extends Node
## v1.0.26 COMPLETION proof, supplement: the park-1 flowerbed
## at (-33, 29) from two extra angles (the south view is blocked
## by park bushes). Aimed from main.placed_flower_spots.
## Output: ~/workspace/homeward/screenshots_v1026_flowers2/.
## Run: xvfb-run -a godot --path . tests/ShotV1026Flowers3.tscn

var main: Node = null
var cam: Camera3D = null

const OUT := "/home/hatch/workspace/homeward/screenshots_v1026_flowers2"

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name + ".png")
	print("SNAP ", name)

func shot(name: String, pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await wait_sec(0.35)
	await snap(name)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await run()

func run() -> void:
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
	var worker: Node = main.get("pound_worker")
	if worker != null:
		worker.call("stop_pursuit")
		(main.get("pursuers") as Dictionary).erase(worker)
		worker.set("active", false)
		(worker as Node3D).visible = false
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_state", "patrol")
	(main.get("player") as Node3D).global_position = Vector3(0, 0.3, 0)
	await wait_sec(0.5)
	main.set_process(false)
	await wait_sec(0.3)

	var spots: Array = main.get("placed_flower_spots")
	var c := Vector3.ZERO
	var n := 0
	for s in spots:
		var p: Vector3 = s
		if Vector2(p.x + 33.0, p.z - 29.0).length() <= 2.6:
			c += p
			n += 1
	print("PARK1 BED spots=", n)
	if n > 0:
		c /= float(n)
		await shot("03b_park1_flowerbed_east", c + Vector3(3.1, 0.9, 0.7), c + Vector3(0, 0.2, 0))
		await shot("03c_park1_flowerbed_high", c + Vector3(2.0, 1.8, -2.4), c + Vector3(0, 0.1, 0))

	print("V1026FLOWERS3 DONE")
	get_tree().quit(0)
