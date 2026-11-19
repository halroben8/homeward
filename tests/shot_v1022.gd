extends Node
## ZANDER'S RUN v1.0.22 — screenshot runner (not part of the suite):
##  1. traffic_nose_first.png — a real spawned traffic car driving
##     past the cat on the z=15 road, nose first.
##  2. pound_van_patrol.png — the pound van patrolling east on its
##     z=16.8 lane toward the cat's view, nose first.
##  3. pound_van_lights.png — the encounter staged on patrol with the
##     notice meter part-built: exactly one blue lamp lit (strict
##     alternation), siren playing.
## Boots the real game (same escape-to-town sequence as the suite).

const OUT := "/home/hatch/workspace/homeward/screenshots_v1022/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(sname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + sname)
	print("saved ", sname)

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await wait_sec(0.5)
	player = main.get("player")
	# Boot into town play, the suite's proven route: splash -> opening
	# cutscene -> skip to the pound escape -> complete the escape
	# (the one funnel that flips the state to "play").
	# Wait for the staged boot build to finish BEFORE the splash
	# calls — start_game during the build is a no-op and the runner
	# would sit on the title screen forever (the v1.0.21 runner's
	# proven order).
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	# The pound van + worker are built a little after boot (the suite
	# reaches this point minutes in); wait until they exist.
	var bguard := 0
	while bguard < 900 and main.get("pound_worker") == null:
		await get_tree().physics_frame
		bguard += 1
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	main.call("_complete_escape")
	await wait_sec(0.2)
	var pvan: Node3D = main.get("pound_van")
	var pworker: Node = main.get("pound_worker")
	# End the escape pursuit: the worker goes back to riding in the
	# van (invisible, brain off) and the van is on patrol.
	(main.get("pursuers") as Dictionary).clear()
	pworker.set("active", false)
	pworker.set("visible", false)

	# ---- 1. traffic nose-first --------------------------------------
	# spawn_traffic_car picks a random road; keep spawning until one
	# lands on the z=15 horizontal road (the rest drive on as extra
	# traffic), then frame it passing the cat.
	var car_root: Node3D = null
	var car_vel := Vector3.ZERO
	for tries in 40:
		var node: Node3D = main.call("spawn_traffic_car")
		if node == null:
			break
		var v := Vector3.ZERO
		for tc in main.get("traffic_cars"):
			if tc["node"] == node:
				v = tc["vel"]
		if absf(node.global_position.z - 15.0) < 3.0 and absf(v.z) < 0.1:
			car_root = node
			car_vel = v
			break
	if car_root != null:
		var dirx := signf(car_vel.x)
		# Cat on the north sidewalk ahead of the car, facing the road
		# (rotation.y 0 = facing -Z, toward the z=15 lane); camera
		# behind the cat (look_yaw = cat yaw + PI) so the car crosses
		# the frame nose-first.
		player.global_position = Vector3(car_root.global_position.x + dirx * 16.0, 0.2, 19.5)
		(player as Node3D).rotation.y = 0.0
		main.set("look_yaw", PI)
		main.set("look_pitch_deg", 10.0)
		var cguard := 0
		while cguard < 900 and absf(car_root.global_position.x - player.global_position.x) > 5.0:
			await get_tree().physics_frame
			cguard += 1
		for i in 6:
			await get_tree().physics_frame
		main.call("_update_camera", 0.016)
		await snap("traffic_nose_first.png")
		print("V1022: traffic shot — car at ", car_root.global_position, " vel ", car_vel, " nose ", main.call("_car_nose_dir", car_root))

	# ---- 2. pound van patrolling nose-first --------------------------
	# Stage the van mid-patrol on its eastbound lane (the suite proves
	# the real depot cycle separately); worker riding inside.
	main.set("pound_state", "patrol")
	main.set("pound_route_idx", 1)  # target: the east end of the z=16.8 lane
	main.set("pound_notice", 0.0)
	pworker.set("active", false)
	pworker.set("visible", false)
	pvan.global_position = Vector3(-70.0, 0.0, 16.8)
	pvan.rotation.y = 0.0
	player.global_position = Vector3(-52.0, 0.2, 19.5)
	(player as Node3D).rotation.y = PI / 2.0  # face west, the way the van comes from
	main.set("look_yaw", PI / 2.0 + PI)
	main.set("look_pitch_deg", 10.0)
	var guard := 0
	while guard < 1500 and pvan.global_position.x < -60.5:
		await get_tree().physics_frame
		guard += 1
	for i in 10:
		await get_tree().physics_frame
	main.call("_update_camera", 0.016)
	await snap("pound_van_patrol.png")
	print("V1022: van patrol shot — van at ", pvan.global_position, " nose ", main.call("_car_nose_dir", pvan))

	# ---- 3. encounter lights: meter building on patrol ----------------
	# Van on the road just west of the cat, meter part-built: by the
	# v1.0.22 rule the lamps alternate and the siren plays already.
	pvan.global_position = Vector3(-58.0, 0.0, 16.8)
	pvan.rotation.y = 0.0
	main.set("pound_state", "patrol")
	main.set("pound_route_idx", 1)
	main.set("pound_notice", 0.55)
	player.global_position = Vector3(-52.0, 0.2, 19.5)
	(player as Node3D).rotation.y = 0.0  # face the road
	main.set("look_yaw", PI)
	main.set("look_pitch_deg", 10.0)
	for i in 20:
		await get_tree().physics_frame
	main.call("_pound_update_lights", 0.3)
	for i in 5:
		await get_tree().physics_frame
	main.call("_update_camera", 0.016)
	var ll := main.get("pound_light_lamp_l") as Node3D
	var lr := main.get("pound_light_lamp_r") as Node3D
	var siren := main.get("sfx_siren") as AudioStreamPlayer
	await snap("pound_van_lights.png")
	print("V1022: lights shot — van at ", pvan.global_position, " lamp L/R: ", ll.visible, "/", lr.visible, " siren playing: ", siren.playing)
	get_tree().quit()
