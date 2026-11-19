extends Node
## v1.0.26 TOWN CAT VERIFY (diagnostic, not part of the suite):
## boots the real town, lets the 8 Meshy town cats live for ~60
## game-seconds with the player parked at the town centre (inside
## every cat's think radius), logs each cat's home distance +
## displacement, then frames four of them with the game camera.
## Output: ~/workspace/homeward/screenshots_v1026/.

var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/homeward/screenshots_v1026/" + name + ".png")
	print("SNAP ", name)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/home/hatch/workspace/homeward/screenshots_v1026")
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
	(player as Node3D).global_position = Vector3(0, 0.3, 0)
	Engine.time_scale = 3.0
	await wait_sec(20.0)
	Engine.time_scale = 1.0
	var cats: Array = main.get("town_cats")
	print("CATS count=", cats.size())
	var homes: Dictionary = {}
	for c in cats:
		var cn: Node3D = c as Node3D
		homes[cn] = cn.global_position
	await wait_sec(10.0)
	# Second sample 10 s later: displacement proves live wandering.
	for i in range(cats.size()):
		var cn: Node3D = cats[i] as Node3D
		var p0: Vector3 = homes[cn]
		var p1: Vector3 = cn.global_position
		print("CAT ", i, " home=", str(cn.get("home")), " pos=", str(p1), " moved10s=", snappedf(p0.distance_to(p1), 0.01), " dist_home=", snappedf(p1.distance_to(cn.get("home")), 0.01))
	main.set_process(false)
	await wait_sec(0.3)
	for i in range(mini(4, cats.size())):
		var cn: Node3D = cats[i] as Node3D
		var cp: Vector3 = cn.global_position
		cam.global_position = cp + Vector3(2.3, 1.15, 2.3)
		cam.look_at(cp + Vector3(0, 0.25, 0), Vector3.UP)
		await wait_sec(0.35)
		await snap("cat_" + str(i))
	print("CAT SHOTS DONE")
	get_tree().quit()
