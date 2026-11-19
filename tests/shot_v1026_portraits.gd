extends Node
## v1.0.26 PORTRAIT SPOT-CHECK (diagnostic, not part of the suite):
## boots the real town, parks the townsfolk far away (no captures),
## lets the town cats roam ~45 game-seconds, then FREEZES subjects
## and frames tight portraits: Zander, the officer, the cat-loving
## young woman, and two town cats where they roam. Used to verify
## (a) town cats visibly present in town and (b) ETC2/ASTC texture
## compression did not soften faces or fur.
## Output: ~/workspace/homeward/screenshots_v1026b/.

var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/homeward/screenshots_v1026b/" + name + ".png")
	print("SNAP ", name)

func frame_subject(target: Vector3, dist: float, height: float, name: String) -> void:
	cam.global_position = target + Vector3(dist, height, dist)
	cam.look_at(target + Vector3(0, 0.1, 0), Vector3.UP)
	await wait_sec(0.4)
	await snap(name)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/home/hatch/workspace/homeward/screenshots_v1026b")
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
	print("GPU_WARM_COUNT=", str(main.get("gpu_warm_count")), " WARMUP_COUNT=", str(main.get("warmup_count")))
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.3)
	(main.get("story") as Node).call("skip_opening")
	await wait_sec(0.4)
	main.set("state", "play")
	# Park the townsfolk far off so nothing interrupts the shoot
	# (spread along a line so they don't stack inside each other).
	var park_i := 0
	for n in main.get("npcs"):
		var nn := n as Node3D
		nn.global_position = Vector3(-110 + float(park_i % 12) * 2.2, 0.2, 80 - float(park_i / 12) * 3.0)
		nn.set("notice_cooldown", 99999.0)
		park_i += 1
	(player as Node3D).global_position = Vector3(0, 0.3, 0)
	Engine.time_scale = 3.0
	await wait_sec(15.0)
	Engine.time_scale = 1.0
	main.set_process(false)
	await wait_sec(0.3)
	# Zander portrait (he stands where the player left him).
	var zp: Vector3 = (player as Node3D).global_position
	await frame_subject(zp + Vector3(0, 0.3, 0), 1.5, 0.75, "zander")
	# Officer portrait at the pound depot.
	var officer: Node = main.get("pound_worker")
	if officer != null:
		var op: Vector3 = (officer as Node3D).global_position
		await frame_subject(op + Vector3(0, 1.35, 0), 1.7, 0.55, "officer")
	# A townsperson face: first NPC of type woman (parked cluster —
	# frame the first one; faces read at this range).
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman":
			var wp: Vector3 = (n as Node3D).global_position
			await frame_subject(wp + Vector3(0, 1.4, 0), 1.7, 0.5, "woman")
			break
	# Two town cats, frozen where they roam.
	var cats: Array = main.get("town_cats")
	for i in range(mini(2, cats.size())):
		var cn := cats[i] as Node3D
		cn.set_physics_process(false)
		await frame_subject(cn.global_position + Vector3(0, 0.22, 0), 1.35, 0.6, "towncat_" + str(i))
	print("PORTRAITS DONE")
	get_tree().quit()
