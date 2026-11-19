extends Node
## v1.0.25 extra proof shots: (g) a town cat CLOSE (frozen, cat
## height), (h) street-level walkers mid-stride, (i) a cat-gap
## fence break with NO floating label over it.
## Output: ~/workspace/homeward/screenshots_v1025/.

var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/homeward/screenshots_v1025/" + name + ".png")
	print("SNAP ", name)

func snap_with_cam(name: String, pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await wait_sec(0.35)
	await snap(name)

func _ready() -> void:
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
	(player as Node3D).global_position = Vector3(560, 0.3, 0)
	Engine.time_scale = 2.0
	await wait_sec(30.0)
	Engine.time_scale = 1.0
	main.set_process(false)
	await wait_sec(0.3)
	# (g) the town cat nearest the town centre, close and low.
	var cats: Array = main.get("town_cats")
	var best_cat: Node3D = null
	var best_d := 1e9
	for c in cats:
		var cp: Vector3 = (c as Node3D).global_position
		var d: float = Vector2(cp.x, cp.z).length()
		if d < best_d:
			best_d = d
			best_cat = c
	if best_cat != null:
		var cp2: Vector3 = best_cat.global_position
		await snap_with_cam("g_town_cat_close", cp2 + Vector3(1.5, 0.65, 1.5), cp2 + Vector3(0, 0.22, 0))
	# (h) walkers: the densest NPC cluster, street level.
	var npcs: Array = main.get("npcs")
	var best: Node3D = null
	var best_n := -1
	for n in npcs:
		var cnt := 0
		for m in npcs:
			if m != n and (m as Node3D).global_position.distance_to((n as Node3D).global_position) < 14.0:
				cnt += 1
		if cnt > best_n:
			best_n = cnt
			best = n
	var bp: Vector3 = best.global_position
	await snap_with_cam("h_street_walkers", bp + Vector3(4.2, 1.5, 4.2), bp + Vector3(0, 0.9, 0))
	# (i) a cat gap: plain fence break, no label.
	var gaps: Array = main.get("ender_points")
	if gaps.size() > 0:
		var gp: Vector3 = gaps[0]
		await snap_with_cam("i_cat_gap_nolabel", gp + Vector3(3.6, 1.5, 3.6), gp + Vector3(0, 0.8, 0))
	print("EXTRA SHOTS DONE cats=", cats.size(), " gaps=", gaps.size())
	get_tree().quit()
