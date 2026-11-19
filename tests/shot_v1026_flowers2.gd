extends Node
## v1.0.26 COMPLETION proof (diagnostic, not part of the suite):
## the hand-scattered flower sites converted from bare coloured
## spheres to stem+daisy flowers (_place_flowers). Cameras are
## aimed from the RECORDED placements (main.placed_flower_spots):
## for each site, the centroid of its spots inside a target
## region, shot from a fixed offset — no guessed coordinates.
## Sites: park 1 scatter, park 1 flowerbed, promenade beds,
## park 2 ring bed, park 2 scatter, a mid-town flowerbed, plus
## two wide town shots scanned for stray balls.
## Output: ~/workspace/homeward/screenshots_v1026_flowers2/.
## Run: xvfb-run -a godot --path . tests/ShotV1026Flowers2.tscn

var main: Node = null
var player: Node = null
var cam: Camera3D = null

const OUT := "/home/hatch/workspace/homeward/screenshots_v1026_flowers2"

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name + ".png")
	print("SNAP ", name)

func frame_cam(pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)

func shot(name: String, pos: Vector3, look: Vector3) -> void:
	frame_cam(pos, look)
	await wait_sec(0.35)
	await snap(name)

func spots_near(spots: Array, centre: Vector3, r: float) -> Array:
	var out: Array = []
	for s in spots:
		var p: Vector3 = s
		if Vector2(p.x - centre.x, p.z - centre.z).length() <= r:
			out.append(p)
	return out

func centroid_of(spots: Array) -> Vector3:
	var c := Vector3.ZERO
	for s in spots:
		c += s
	if spots.size() > 0:
		c /= float(spots.size())
	return c

func aim(name: String, spots: Array, centre: Vector3, r: float, cam_off: Vector3, look_up: float) -> void:
	var near: Array = spots_near(spots, centre, r)
	print("AIM ", name, " spots=", near.size(), " near ", centre)
	if near.is_empty():
		print("AIM ", name, " NO SPOTS — shot skipped")
		return
	var c := centroid_of(near)
	await shot(name, c + cam_off, c + Vector3(0, look_up, 0))

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
	player = main.get("player")
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
	var npcs: Array = main.get("npcs")
	for i in range(npcs.size()):
		(npcs[i] as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
	(player as Node3D).global_position = Vector3(0, 0.3, 0)
	await wait_sec(0.5)
	main.set_process(false)
	await wait_sec(0.3)

	var spots: Array = main.get("placed_flower_spots")
	print("PLACED FLOWER SPOTS total=", spots.size())
	# Park 1 scatter: region spots EXCLUDING the flowerbed cluster
	# at (-33, 29) — aim wide over the lawn, then one close-up.
	var park1: Array = spots_near(spots, Vector3(-39, 0, 25.5), 17.0)
	var park1_scatter: Array = []
	for p in park1:
		if Vector2(p.x + 33.0, p.z - 29.0).length() > 3.0:
			park1_scatter.append(p)
	print("PARK1 scatter spots=", park1_scatter.size())
	if not park1_scatter.is_empty():
		var pc := centroid_of(park1_scatter)
		await shot("01_park1_scatter", pc + Vector3(5.5, 2.1, 6.5), pc + Vector3(0, 0.1, 0))
		var one: Vector3 = park1_scatter[0]
		await shot("02_park1_scatter_close", one + Vector3(1.3, 0.5, 1.3), one + Vector3(0, 0.22, 0))
	# Park 1 flowerbed at (-33, 29).
	await aim("03_park1_flowerbed", spots, Vector3(-33, 0, 29), 2.6, Vector3(0, 0.8, 2.8), 0.25)
	# Promenade flowerbeds (the 06_promenade_close ball strip bed).
	await aim("04_promenade_bed_36", spots, Vector3(36, 0, -88.5), 3.2, Vector3(0, 0.95, 3.6), 0.22)
	await aim("05_promenade_bed_-80", spots, Vector3(-80, 0, -88.5), 3.2, Vector3(0, 0.95, 3.6), 0.22)
	# Park 2 ring bed at (-83, 73) + park 2 scatter lawn.
	await aim("06_park2_ring", spots, Vector3(-83, 0, 73), 2.0, Vector3(2.6, 0.85, 2.6), 0.3)
	await aim("07_park2_scatter", spots, Vector3(-87.5, 0, 74), 13.0, Vector3(5.0, 2.0, 6.0), 0.1)
	# Mid-town flowerbed (Oak back gardens, -27, -1).
	await aim("08_town_flowerbed", spots, Vector3(-27, 0, -1), 2.6, Vector3(0, 0.85, 2.9), 0.25)
	# Wide town shots — stray-ball scan.
	await shot("09_town_wide", Vector3(30, 16, 38), Vector3(-10, 0, -20))
	await shot("10_town_wide_north", Vector3(-30, 13, -55), Vector3(20, 0, -95))

	print("V1026FLOWERS2 DONE")
	get_tree().quit(0)
