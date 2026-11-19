extends Node
## v1.0.26 VERIFY (diagnostic, not part of the suite): drives the
## three v1.0.26 fixes in the real town.
##  ITEM 1: screenshots of the promenade + a Maple sidewalk —
##    concrete clean, tufts/blades still on the lawns beside.
##  ITEM 2: drives Zander north into the river at Birch Lane
##    and at both flanks (x = +/-140) — he must stop at the
##    shore wall (z > -92.4) every time; screenshots at the
##    water's edge and across the river.
##  ITEM 3: walks Zander to the black cat, meows (asserts the
##    meow-back fired), paws (asserts play state, screenshots
##    the roll mid-play, asserts exactly +3 on completion and
##    NO re-score on a second completed session).
## Output: ~/workspace/homeward/screenshots_v1026_verify/.
## Run: xvfb-run -a godot --path . tests/ShotV1026Verify.tscn

var main: Node = null
var player: Node = null
var cam: Camera3D = null
var failures: int = 0

const OUT := "/home/hatch/workspace/homeward/screenshots_v1026_verify"

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func report(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failures += 1
	print("V1026VERIFY ", label, ": ", "PASS" if ok else "FAIL", " -- ", detail)

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name + ".png")
	print("SNAP ", name)

func frame_cam(pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)

func steer_toward(wdir: Vector2) -> void:
	# Same camera-relative steering as the shore probe.
	var cy: float = float(player.get("cam_yaw"))
	var d3: Vector3 = Basis(Vector3.UP, -cy) * Vector3(wdir.x, 0, wdir.y)
	var d2 := Vector2(d3.x, d3.z)
	if d2.length() > 0.01:
		main.set("joy_mouse", true)
		main.set("joy_origin", Vector2(200, 400))
		main.set("joy_current", Vector2(200, 400) + d2.normalized() * 85.0)

func clear_joy() -> void:
	main.set("joy_mouse", false)
	main.set("joy_id", -999)

func drive_north_into_river(label: String, start: Vector3) -> void:
	(player as Node3D).global_position = start
	player.set("velocity", Vector3.ZERO)
	await wait_sec(0.4)
	var min_z: float = start.z
	var last_pos: Vector3 = (player as Node3D).global_position
	var stall_t := 0.0
	var elapsed := 0.0
	var stopped := false
	while elapsed < 40.0:
		await wait_sec(0.25)
		elapsed += 0.25
		steer_toward(Vector2(0, -1))
		var p: Vector3 = (player as Node3D).global_position
		min_z = minf(min_z, p.z)
		if p.distance_to(last_pos) < 0.08:
			stall_t += 0.25
			if stall_t >= 2.5:
				stopped = true
				break
		else:
			stall_t = 0.0
		last_pos = p
	clear_joy()
	var fin: Vector3 = (player as Node3D).global_position
	report(label + ": stopped before the water", stopped and min_z > -92.4, "stopped=%s min_z=%.2f final=%s" % [stopped, min_z, fin])

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
	# Hold off the town's actors (the shore probe's pattern).
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

	# ---------- ITEM 1: pavement screenshots ----------
	main.set_process(false)
	await wait_sec(0.3)
	frame_cam(Vector3(14, 2.6, -71), Vector3(36, 0, -86))
	await wait_sec(0.35)
	await snap("01_promenade")
	frame_cam(Vector3(-42, 2.4, 3), Vector3(-22, 0, -9))
	await wait_sec(0.35)
	await snap("02_maple_sidewalk")
	main.set_process(true)
	await wait_sec(0.3)

	# ---------- ITEM 3: town cat interaction (black cat) ----------
	var cats: Array = main.get("town_cats")
	report("8 town cats spawned", cats.size() == 8, "count=" + str(cats.size()))
	var cat: Node3D = cats[1] as Node3D # black_cat, home verge of Birch Lane
	var score0: int = int(main.get("score"))
	var meows0: int = int(main.get("cat_meow_count"))
	(player as Node3D).global_position = (cat as Node3D).global_position + Vector3(1.2, 0.3, 0)
	player.set("velocity", Vector3.ZERO)
	await wait_sec(0.25)
	main.call("_on_meow")
	var waited := 0.0
	while int(cat.get("meow_count")) < 1 and waited < 2.5:
		await wait_sec(0.25)
		waited += 0.25
	report("cat meowed back", int(cat.get("meow_count")) >= 1, "meow_count=" + str(cat.get("meow_count")))
	report("meow-back sound played via main", int(main.get("cat_meow_count")) > meows0, "cat_meow_count=" + str(main.get("cat_meow_count")))
	# Paw: teleport alongside and paw in the same breath.
	(player as Node3D).global_position = (cat as Node3D).global_position + Vector3(1.0, 0.3, 0)
	player.set("velocity", Vector3.ZERO)
	main.call("_paw_action")
	report("paw started a play session", float(cat.get("_play_t")) > 0.0, "play_t=" + str(cat.get("_play_t")))
	await wait_sec(1.3) # mid-roll: on his back, legs batting
	main.set_process(false)
	await wait_sec(0.25)
	var cp: Vector3 = (cat as Node3D).global_position
	frame_cam(cp + Vector3(1.7, 0.85, 1.7), cp + Vector3(0, 0.2, 0))
	await wait_sec(0.3)
	await snap("03_cat_play_roll")
	main.set_process(true)
	waited = 0.0
	while int(cat.get("play_sessions")) < 1 and waited < 6.0:
		await wait_sec(0.25)
		waited += 0.25
	report("first session completed", int(cat.get("play_sessions")) >= 1, "sessions=" + str(cat.get("play_sessions")))
	report("score rose by exactly 3", int(main.get("score")) == score0 + 3, "score=%d want=%d" % [int(main.get("score")), score0 + 3])
	report("cat_play_count is 1", int(main.get("cat_play_count")) == 1, "count=" + str(main.get("cat_play_count")))
	# Second session: plays again, never re-scores.
	(player as Node3D).global_position = (cat as Node3D).global_position + Vector3(1.0, 0.3, 0)
	player.set("velocity", Vector3.ZERO)
	main.call("_paw_action")
	report("second paw started another session", float(cat.get("_play_t")) > 0.0, "play_t=" + str(cat.get("_play_t")))
	waited = 0.0
	while int(cat.get("play_sessions")) < 2 and waited < 6.0:
		await wait_sec(0.25)
		waited += 0.25
	report("second session completed", int(cat.get("play_sessions")) >= 2, "sessions=" + str(cat.get("play_sessions")))
	report("no re-score on the second session", int(main.get("score")) == score0 + 3 and int(main.get("cat_play_count")) == 1, "score=" + str(main.get("score")) + " plays=" + str(main.get("cat_play_count")))

	# ---------- ITEM 2: the river ----------
	await drive_north_into_river("river at Birch Lane", Vector3(24, 0.3, -88))
	# Screenshots from the stop point: Zander at the edge, then
	# the view across.
	main.set_process(false)
	await wait_sec(0.3)
	var zp: Vector3 = (player as Node3D).global_position
	frame_cam(zp + Vector3(0, 2.1, 6.8), zp + Vector3(0, 0.2, -26))
	await wait_sec(0.35)
	await snap("04_river_edge")
	frame_cam(Vector3(24, 3.2, -89), Vector3(24, 0.8, -126))
	await wait_sec(0.35)
	await snap("05_river_across")
	main.set_process(true)
	await wait_sec(0.3)
	await drive_north_into_river("river west flank (x=-140)", Vector3(-140, 0.3, -88))
	await drive_north_into_river("river east flank (x=140)", Vector3(140, 0.3, -88))

	print("V1026VERIFY DONE failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
