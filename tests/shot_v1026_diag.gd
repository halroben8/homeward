extends Node
## v1.0.26 DIAGNOSTIC runner (BEFORE-fix evidence for Michael's
## v1.0.25 play reports):
##  (1) BLACK SPIKES: a player-height shot over lawn + promenade,
##      plus three controlled blade patches side by side on one
##      lawn — CTRL (the game's current _blade_mesh as-is), FLIP
##      (same mesh, triangle winding reversed), UPN (same mesh,
##      all normals straight up) — same material, same palette,
##      same sun. Whichever patch renders green names the bug.
##  (2) RIVER: drive the REAL cat north at x=24 (a street gap in
##      the fence) and record how far he gets.
##  (3) GABLE: straight-on shots of two far-bank houses' south
##      gable ends.
## Run: xvfb-run -a godot --path . tests/ShotV1026Diag.tscn
## Output: ~/workspace/homeward/screenshots_v1026_diag/.

var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/homeward/screenshots_v1026_diag/" + name + ".png")
	print("V26DIAG SNAP ", name)

func snap_with_cam(name: String, pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await wait_sec(0.35)
	await snap(name)

func steer_toward(wdir: Vector2) -> void:
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

func variant_mesh(flip: bool, up_normals: bool) -> ArrayMesh:
	var src: ArrayMesh = main.call("_blade_mesh")
	var arrs: Array = src.surface_get_arrays(0)
	if flip:
		var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX]
		var ni := PackedInt32Array()
		ni.resize(idx.size())
		for t in range(0, idx.size(), 3):
			ni[t] = idx[t]
			ni[t + 1] = idx[t + 2]
			ni[t + 2] = idx[t + 1]
		arrs[Mesh.ARRAY_INDEX] = ni
	if up_normals:
		var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
		var nn := PackedVector3Array()
		nn.resize(ns.size())
		for i in range(ns.size()):
			nn[i] = Vector3.UP
		arrs[Mesh.ARRAY_NORMAL] = nn
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return m

func make_patch(parent: Node, mesh: Mesh, mat: Material, centre: Vector3, seed_i: int) -> void:
	var prng := RandomNumberGenerator.new()
	prng.seed = 5000 + seed_i
	var palette: Array = [Color(0.34, 0.56, 0.22), Color(0.3, 0.5, 0.19), Color(0.39, 0.61, 0.25), Color(0.32, 0.53, 0.2)]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var n := 260
	mm.instance_count = n
	for j in range(n):
		var px: float = centre.x + prng.randf_range(-1.7, 1.7)
		var pz: float = centre.z + prng.randf_range(-1.1, 1.1)
		var basis := Basis(Vector3.UP, prng.randf_range(0.0, TAU)).scaled(Vector3.ONE * prng.randf_range(1.1, 1.7))
		mm.set_instance_transform(j, Transform3D(basis, Vector3(px, 0.02, pz)))
		mm.set_instance_color(j, palette[prng.randi_range(0, palette.size() - 1)])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)

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
	await wait_sec(0.5)
	player = main.get("player")
	cam = main.get("cam")
	print("V26DIAG boot complete")
	# ---- reach free play through the game's own flow (shore-probe path)
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_open_escape_panel")
	await wait_sec(0.3)
	main.set("escape_combo", ["B", "B", "A", "B", "A"])
	(main.get("escape_panel") as Control).call("set_combo_seq", ["B", "B", "A", "B", "A"])
	main.set("combo_index", 0)
	for letter in ["B", "B", "A", "B", "A"]:
		main.call("escape_panel_input", letter)
		await wait_sec(0.15)
	var eguard: int = 0
	while not bool(main.get("exit_open")) and eguard < 40:
		await wait_sec(0.25)
		eguard += 1
	print("V26DIAG exit_open=", bool(main.get("exit_open")))
	(player as Node3D).global_position = Vector3(560, 0.3, 0) + Vector3(15.2, 0.3, 3.4)
	for i in range(40):
		if str(main.get("state")) != "escape":
			break
		await wait_sec(0.25)
	await wait_sec(0.5)
	print("V26DIAG state=", str(main.get("state")))
	# ---- hold off the town's actors
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
	# ---- (1) blade variant patches on the lawn band at z=-81.5
	var world_node: Node = main.get_node("World")
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color.WHITE
	bmat.roughness = 1.0
	bmat.vertex_color_use_as_albedo = true
	make_patch(world_node, variant_mesh(false, false), bmat, Vector3(22.0, 0, -81.5), 1) # CTRL
	make_patch(world_node, variant_mesh(true, false), bmat, Vector3(27.0, 0, -81.5), 2) # FLIP
	make_patch(world_node, variant_mesh(false, true), bmat, Vector3(32.0, 0, -81.5), 3) # UPN
	(player as Node3D).global_position = Vector3(60, 0.3, -60)
	main.set_process(false)
	await wait_sec(0.4)
	await snap_with_cam("diag_blade_variants", Vector3(27, 1.3, -74.6), Vector3(27, 0.15, -81.5))
	# ---- (1b) the promenade repro: lawn foreground, path, river
	(player as Node3D).global_position = Vector3(14, 0.02, -82)
	await snap_with_cam("diag_promenade_before", Vector3(8.5, 1.25, -78.0), Vector3(20, 0.2, -87.5))
	# ---- (4) flowers: the densest real cluster the scatter made
	var fspots: Array = main.get("flower_spots")
	if fspots != null and fspots.size() > 0:
		var best_f: Vector3 = fspots[0]
		var best_fn := -1
		for s in fspots:
			var cnt := 0
			for t in fspots:
				if (s as Vector3).distance_to(t as Vector3) < 5.0:
					cnt += 1
			if cnt > best_fn:
				best_fn = cnt
				best_f = s
		print("V26DIAG flower cluster at ", best_f, " neighbours=", best_fn)
		await snap_with_cam("diag_flowers_close", best_f + Vector3(0.9, 0.55, 0.9), best_f + Vector3(0, 0.2, 0))
		await snap_with_cam("diag_flowers_player", best_f + Vector3(2.6, 1.25, 2.6), best_f + Vector3(0, 0.15, 0))
	else:
		print("V26DIAG no flower_spots (pre-fix build)")
	# ---- (3) far-bank gables (process still off)
	await snap_with_cam("diag_gable_east_before", Vector3(20, 2.4, -107.5), Vector3(20, 4.2, -124))
	await snap_with_cam("diag_gable_west_before", Vector3(-20, 2.4, -107.5), Vector3(-20, 4.2, -124))
	main.set_process(true)
	await wait_sec(0.3)
	# ---- (2) river drive: north at x=24 through the fence gap
	(player as Node3D).global_position = Vector3(24, 0.3, -78)
	player.set("velocity", Vector3.ZERO)
	await wait_sec(0.4)
	steer_toward(Vector2(0, -1))
	var last_pos: Vector3 = (player as Node3D).global_position
	var stall_t: float = 0.0
	var elapsed: float = 0.0
	var min_z: float = 999.0
	var min_y: float = 99.0
	while elapsed < 40.0:
		await wait_sec(0.25)
		elapsed += 0.25
		steer_toward(Vector2(0, -1))
		var p: Vector3 = (player as Node3D).global_position
		min_z = minf(min_z, p.z)
		min_y = minf(min_y, p.y)
		if p.distance_to(last_pos) < 0.08:
			stall_t += 0.25
			if stall_t >= 3.0:
				break
		else:
			stall_t = 0.0
		last_pos = p
	clear_joy()
	var fin: Vector3 = (player as Node3D).global_position
	print("V26DIAG RIVERDRIVE final=", fin, " min_z=", min_z, " min_y=", min_y, " elapsed=", elapsed)
	main.set_process(false)
	await wait_sec(0.3)
	await snap_with_cam("diag_river_before", fin + Vector3(0, 2.0, 7.5), fin + Vector3(0, 0.3, 0))
	print("V26DIAG DONE")
	get_tree().quit()
