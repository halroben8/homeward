extends Node
## HOMEWARD POUND VAN screenshots.
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerPoundVan.tscn
## Three staged proofs of the real system (nothing mocked):
##   patrol_lettering — the van on its patrol lane, lettering
##     readable on the flank, shot from the kerb.
##   chase_net — a REAL engagement from the player's own camera:
##     the cat steps onto his road, the van pulls over, the worker
##     gets out with his net and chases — snapped mid-chase.
##   return_kerb — the chase lost (the cat bolts), the worker
##     walking back to the van parked at the kerb.
## Output: ~/workspace/homeward/screenshots_poundvan/

const OUT := "/home/hatch/workspace/homeward/screenshots_poundvan"
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
	main.set_process(false)
	await get_tree().process_frame
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())
	main.set_process(true)

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1

func stage_van(pos: Vector3, yaw: float = 0.0) -> void:
	var van: Node3D = main.get("pound_van")
	van.position = pos
	main.set("pound_van_yaw", yaw)
	van.rotation.y = yaw
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "patrol")
	main.set("pound_engage_cd", 0.0)

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
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	park_npcs_far()
	var van: Node3D = main.get("pound_van")
	var worker: Node = main.get("pound_worker")

	# ---------- 1: on patrol, lettering readable ----------
	main.set("player_collared", true) # staging only: he drives past for the camera
	stage_van(Vector3(30, 0, 16.8))
	(player as Node3D).global_position = Vector3(30, 0.2, 60) # well off his roads
	await wait_sec(0.1)
	# Freeze the world with the van side-on to a camera standing
	# at the road's north edge — the sight line crosses only
	# asphalt (from the south the house frontages block the view).
	main.set_process(false)
	await get_tree().process_frame
	cam.global_position = Vector3(33.5, 1.5, 11.6)
	cam.look_at(Vector3(29.2, 1.0, 16.8), Vector3.UP)
	await RenderingServer.frame_post_draw
	var img1: Image = get_viewport().get_texture().get_image()
	img1.save_png(OUT + "/patrol_lettering.png")
	print("SHOT: patrol_lettering.png ", img1.get_size())
	main.set_process(true)
	main.set("player_collared", false)

	# ---------- 2: the real chase, from the player's camera ----------
	stage_van(Vector3(-24, 0, 16.8))
	(player as Node3D).global_position = Vector3(-13, 0.2, 16.8) # on his road, 11m ahead of the van
	player.set("velocity", Vector3.ZERO)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face the oncoming van
	main.set("look_yaw", -PI * 0.5)
	var guard: float = 0.0
	while str(worker.get("mode")) != "chase" and guard < 12.0:
		await wait_sec(0.25)
		guard += 0.25
	print("chase staging: mode=", str(worker.get("mode")), " pound_state=", str(main.get("pound_state")), " guard=", guard)
	# Let him close some of the gap, then take the shot with the
	# game's own chase camera doing the framing. Snap while he is
	# still ~3m back so the whole of him — net hoop included —
	# fits the frame.
	guard = 0.0
	while guard < 9.0:
		await wait_sec(0.2)
		guard += 0.2
		var d: float = (worker as Node3D).global_position.distance_to((player as Node3D).global_position)
		if d < 3.4 or str(main.get("state")) != "play":
			break
	await snap("chase_net.png")
	print("chase snap: worker_cat_dist=", str((worker as Node3D).global_position.distance_to((player as Node3D).global_position)), " mode=", str(worker.get("mode")), " pound_state=", str(main.get("pound_state")))

	# ---------- 3: chase lost — he walks back to the kerb-parked van ----------
	if str(main.get("state")) == "play":
		# Lead him AWAY from the van first, in small hops the
		# chase can sustain (a single long teleport would break
		# the chase on distance at once), so the walk back is
		# long enough to photograph.
		for hop in range(4):
			var wp0: Vector3 = (worker as Node3D).global_position
			(player as Node3D).global_position = wp0 + Vector3(5.0, 0.0, 0.0)
			player.set("velocity", Vector3.ZERO)
			await wait_sec(0.45)
			if str(worker.get("mode")) != "chase":
				break
		# Bolt — far enough to break the chase on distance, but
		# within ~85m of him: person.gd's distance-hider hides a
		# model farther than that from the CAT, and the camera
		# still needs to see him walk back.
		(player as Node3D).global_position = Vector3(-40, 0.2, 60)
		# Freeze the world the moment his return begins — under
		# the slow screenshot renderer, real seconds pass between
		# observing a state and exposing a frame, and he would
		# otherwise finish the walk and be back inside the van.
		guard = 0.0
		while str(main.get("pound_state")) != "return" and guard < 8.0:
			await wait_sec(0.05)
			guard += 0.05
		main.set_process(false)
		print("return staging: pound_state=", str(main.get("pound_state")), " worker_van_dist=", str((worker as Node3D).global_position.distance_to(van.position)))
		var wp: Vector3 = (worker as Node3D).global_position
		var mid: Vector3 = (wp + van.position) * 0.5
		# Stand ON the road behind him, on his own line back to
		# the van: worker in the near foreground, the kerb-parked
		# van ahead of him, nothing but asphalt under the camera.
		# (A perpendicular camera ends up inside the house
		# frontages that line the street.)
		var wdir: Vector3 = wp - van.position
		wdir.y = 0.0
		wdir = wdir.normalized()
		await snap_with_cam("return_kerb.png", wp + wdir * 5.5 + Vector3(0, 2.2, 0), mid + Vector3(0, 0.7, 0))
	print("DONE")
	get_tree().quit(0)
