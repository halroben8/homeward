extends Node
## HOMEWARD POUND VAN — end-to-end verification harness.
## Added 2026-11-17 for the verification pass Michael approved after
## the van build step ended without a report. Drives the REAL game
## (nothing mocked) through: patrol + traffic coexistence, trigger
## geometry (absurd range / through-a-house), the full engage ->
## chase -> catch -> escape -> pursuit -> return cycle TWICE, a
## line-of-sight chase break, and the collar-flag gate. Prints
## VANVERIFY PASS/FAIL lines and a tally; exit code = failures.
## Run under Xvfb (it also takes two proof frames):
##   xvfb-run -a godot --path . tests/VerifyPoundVan.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_poundvan/verify"
var main: Node = null
var player: Node = null
var passed: int = 0
var failed: int = 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("VANVERIFY PASS: ", name)
	else:
		failed += 1
		print("VANVERIFY FAIL: ", name, " -- ", detail)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("VANVERIFY NOTE: snap skipped (headless): ", name)
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("VANVERIFY SHOT: ", name)

# Generic house staging: find a house where the van can sit on a
# real lane with the cat hidden directly behind the house body,
# still inside the 12m spot radius. Returns {van, cat, house}.
func find_house_staging() -> Dictionary:
	var lanes_h: Array = [-55.0, -11.0, 15.0, 55.0]
	var lanes_v: Array = [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0]
	for h in main.get("houses"):
		var hp: Vector3 = h["pos"]
		# van on the nearest horizontal lane, same x as the house
		var best_z: float = lanes_h[0]
		for rz in lanes_h:
			if absf(hp.z - rz) < absf(hp.z - best_z):
				best_z = rz
		var van_h: Vector3 = Vector3(hp.x, 0, best_z)
		var dir_h: Vector3 = Vector3(0, 0, signf(hp.z - best_z))
		var cat_h: Vector3 = hp + dir_h * 6.0 + Vector3(0, 0.2, 0)
		if van_h.distance_to(cat_h) <= 11.5 and absf(hp.z - best_z) > 3.0:
			return {"van": van_h, "cat": cat_h, "house": hp}
		# van on the nearest vertical lane, same z as the house
		var best_x: float = lanes_v[0]
		for rx in lanes_v:
			if absf(hp.x - rx) < absf(hp.x - best_x):
				best_x = rx
		var van_v: Vector3 = Vector3(best_x, 0, hp.z)
		var dir_v: Vector3 = Vector3(signf(hp.x - best_x), 0, 0)
		var cat_v: Vector3 = hp + dir_v * 6.0 + Vector3(0, 0.2, 0)
		if van_v.distance_to(cat_v) <= 11.5 and absf(hp.x - best_x) > 3.0:
			return {"van": van_v, "cat": cat_v, "house": hp}
	return {}

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1

func stage_van(pos: Vector3) -> void:
	var van: Node3D = main.get("pound_van")
	van.position = pos
	main.set("pound_van_yaw", 0.0)
	van.rotation.y = 0.0
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "patrol")
	main.set("pound_engage_cd", 0.0)

func count_vans() -> int:
	var c: int = 0
	var stack: Array = [main]
	while not stack.is_empty():
		var vn: Node = stack.pop_back()
		for ch in vn.get_children():
			stack.append(ch)
		if vn.name == "PoundVan":
			c += 1
	return c

func distract_captor() -> void:
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1

func drive_escape_panel() -> void:
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)

func walk_cat_out() -> void:
	var kind: String = str(main.get("exit_open_kind"))
	var o: Vector3 = main.get("escape_origin")
	match kind:
		"bolt":
			(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
		_:
			(player as Node3D).global_position = o + Vector3(0, 0.3, -11.2)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)

func run_catch_cycle(tag: String) -> void:
	# One full loop: engage -> chase -> catch -> room -> escape ->
	# pursuit -> he returns -> patrol resumes. Timed and logged.
	var van: Node3D = main.get("pound_van")
	var worker: Node = main.get("pound_worker")
	main.set("player_collared", false)
	stage_van(Vector3(-60, 0, 16.8))
	await wait_sec(0.3)
	(player as Node3D).global_position = van.position + Vector3(11.0, 0.2, 0.0)
	player.set("velocity", Vector3.ZERO)
	var g: float = 0.0
	while str(main.get("pound_state")) != "exit" and g < 15.0:
		await wait_sec(0.25)
		g += 0.25
	check(tag + ": engage -> pullover, worker out", str(main.get("pound_state")) == "exit", str(main.get("pound_state")) + " after " + str(g) + "s")
	g = 0.0
	while str(worker.get("mode")) != "chase" and g < 10.0:
		await wait_sec(0.25)
		g += 0.25
	check(tag + ": worker chases", str(worker.get("mode")) == "chase", str(worker.get("mode")))
	check(tag + ": chase camera engaged", bool(main.get("chase_cam_active")))
	var msg: String = str((main.get("message_label") as Label).text) if main.get("message_label") != null else ""
	print("VANVERIFY NOTE: ", tag, " message_label during chase = ", msg)
	if tag == "cycle2":
		await snap("cycle2_chase.png")
	g = 0.0
	while str(main.get("state")) == "play" and g < 20.0:
		await wait_sec(0.25)
		g += 0.25
	check(tag + ": catch -> cutscene, he is the captor", str(main.get("state")) == "cutscene" and main.get("captor") == worker, str(main.get("state")) + " after " + str(g) + "s")
	check(tag + ": van waits while he is captor (pound_state away)", str(main.get("pound_state")) == "away", str(main.get("pound_state")))
	main.call("skip_cutscene")
	check(tag + ": pound room is the back-door bolt room", str(main.get("state")) == "escape" and main.call("current_escape_kinds") == ["bolt"], str(main.get("state")) + " kinds=" + str(main.call("current_escape_kinds")))
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	walk_cat_out()
	check(tag + ": escape completes, he is the pursuer", str(main.get("state")) == "play" and (main.get("pursuers") as Dictionary).has(worker), str(main.get("state")))
	main.call("_process", 60.1) # drain the pursuit clock
	check(tag + ": pursuit over -> he heads back (pound_state return)", str(main.get("pound_state")) == "return", str(main.get("pound_state")))
	(player as Node3D).global_position = Vector3(-100, 0.2, 80)
	# Timed return with a distance trace — this is the link that
	# timed out at the suite's 30s guard in one loaded run.
	var door: Vector3 = Vector3.ZERO
	g = 0.0
	var arrived: float = -1.0
	while g < 90.0:
		await wait_sec(1.0)
		g += 1.0
		door = (worker as Node3D).global_position # trace anchor
		var wpos: Vector3 = (worker as Node3D).global_position
		var vpos: Vector3 = van.position
		if int(g) % 5 == 0 or str(main.get("pound_state")) == "patrol":
			print("VANVERIFY TRACE: ", tag, " return t=", g, "s state=", str(main.get("pound_state")), " worker->van dist=", snappedf(wpos.distance_to(vpos), 0.1))
		if str(main.get("pound_state")) == "patrol":
			arrived = g
			break
	check(tag + ": he gets back in, patrol resumes (timed)", arrived > 0.0, "not patrol after 90s; state=" + str(main.get("pound_state")))
	print("VANVERIFY NOTE: ", tag, " return-to-patrol took ", arrived, "s")
	check(tag + ": worker back inside (invisible, at the van)", not worker.visible and (worker as Node3D).global_position.distance_to(van.position) < 1.5, "vis=" + str(worker.visible))
	check(tag + ": still exactly ONE van", count_vans() == 1, str(count_vans()))

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	park_npcs_far()
	var van: Node3D = main.get("pound_van")
	var worker: Node = main.get("pound_worker")
	check("boot: van and worker exist", van != null and worker != null)
	check("boot: exactly ONE van", count_vans() == 1, str(count_vans()))

	# ---------- A: patrol + ordinary traffic coexistence ----------
	main.set("player_collared", true) # observation only: no engagement while we watch the roads
	stage_van(Vector3(-100, 0, 16.8))
	(player as Node3D).global_position = Vector3(200, 0.2, 84)
	# Traffic spawns on a 3.5-6.5s timer — wait for it to exist.
	var traffic: Array = []
	var twait: float = 0.0
	while traffic.size() < 3 and twait < 25.0:
		await wait_sec(0.5)
		twait += 0.5
		traffic.clear()
		for ch in (main.get("traffic_group") as Node).get_children():
			if ch != van:
				traffic.append(ch)
	check("patrol: ordinary traffic exists alongside the van", traffic.size() >= 3, str(traffic.size()) + " after " + str(twait) + "s")
	var tpos0: Dictionary = {}
	for c in traffic:
		tpos0[c] = (c as Node3D).global_position
	var vpos0: Vector3 = van.position
	var on_road_samples: int = 0
	var samples: int = 0
	var t: float = 0.0
	while t < 12.0:
		await wait_sec(1.0)
		t += 1.0
		var vp: Vector3 = van.position
		var near_h: bool = false
		for rz in [-55.0, -11.0, 15.0, 55.0]:
			if absf(vp.z - rz) < 2.6:
				near_h = true
		var near_v: bool = false
		for rx in [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0]:
			if absf(vp.x - rx) < 2.6:
				near_v = true
		samples += 1
		if near_h or near_v:
			on_road_samples += 1
	check("patrol: van travelled > 40m in 12s", van.position.distance_to(vpos0) > 40.0, str(van.position.distance_to(vpos0)))
	check("patrol: van on a road lane at every sample", on_road_samples == samples, str(on_road_samples) + "/" + str(samples))
	var moved_traffic: int = 0
	for c in traffic:
		if (c as Node3D).global_position.distance_to(tpos0[c]) > 2.0:
			moved_traffic += 1
	check("patrol: ordinary traffic still drives (majority moved)", moved_traffic >= traffic.size() / 2, str(moved_traffic) + "/" + str(traffic.size()))
	await snap("patrol_overview.png")
	main.set("player_collared", false)

	# ---------- B: trigger geometry ----------
	# B1: absurd range — cat 25m off his road on a parallel street.
	stage_van(Vector3(-60, 0, 16.8))
	(player as Node3D).global_position = Vector3(-60, 0.2, 56.8)
	await wait_sec(3.0)
	check("trigger: NO engage from 40m away (parallel road)", str(main.get("pound_state")) == "patrol", str(main.get("pound_state")))
	# B2: through a house — cat inside the 12m radius but with a
	# house body between him and the van. The van is re-pinned each
	# step so only the gate is exercised.
	var staging: Dictionary = find_house_staging()
	var found_house: bool = not staging.is_empty()
	var hpos: Vector3 = staging.get("house", Vector3.ZERO)
	var hvan: Vector3 = staging.get("van", Vector3.ZERO)
	var hcat: Vector3 = staging.get("cat", Vector3.ZERO)
	check("trigger: found a house staging spot (van on a lane, cat behind the house, inside 12m)", found_house, "")
	if found_house:
		(player as Node3D).global_position = hcat
		player.set("velocity", Vector3.ZERO)
		main.set("pound_engage_cd", 0.0)
		var pinned: float = 0.0
		var engaged: bool = false
		while pinned < 3.0:
			van.position = hvan
			main.set("pound_van_speed", 0.0)
			await wait_sec(0.25)
			pinned += 0.25
			if str(main.get("pound_state")) != "patrol":
				engaged = true
				break
		print("VANVERIFY NOTE: through-house staging: house at ", hpos, " van at ", hvan, " cat at ", hcat, " van-cat dist=", snappedf(hvan.distance_to(hcat), 1))
		check("trigger: does NOT engage through a house (radial-only gate would fail this)", not engaged, "pound_state=" + str(main.get("pound_state")))
		# leave any accidental chase behind: park the cat far away
		# and let him finish his walk back before the cycles begin
		(player as Node3D).global_position = Vector3(-100, 0.2, 80)
		var settle: float = 0.0
		while str(main.get("pound_state")) != "patrol" and settle < 60.0:
			await wait_sec(0.5)
			settle += 0.5
		print("VANVERIFY NOTE: post-B2 settle: pound_state=", str(main.get("pound_state")), " after ", settle, "s")

	# ---------- C: speed balance ----------
	check("balance: worker chase speed 6.4 in the locked 6.0-7.0 band", absf(float(worker.get("chase_speed")) - 6.4) < 0.01, str(worker.get("chase_speed")))
	check("balance: cat sprint clears chase speed by >= 2.0", float(player.get("speed_sprint")) - float(worker.get("chase_speed")) >= 2.0, str(player.get("speed_sprint")))

	# ---------- D: two full catch cycles ----------
	await run_catch_cycle("cycle1")
	await run_catch_cycle("cycle2")

	# ---------- E: line-of-sight chase break ----------
	main.set("player_collared", false)
	var g2: float = 0.0
	if found_house:
		# Engage him with the cat in front of the same house the
		# B2 probe used, so the cat can slip straight behind it.
		# The van is staged back along its lane so it drives up
		# to the cat the way it would in play.
		var approach: Vector3 = hvan - (hcat - hvan).normalized() * 0.0 # van spot is the lane point beside the house
		stage_van(hvan)
		await wait_sec(0.3)
		# cat stands between the van and the house, in plain sight
		var front: Vector3 = hpos - (hcat - hpos).normalized() * 6.0 + Vector3(0, 0.2, 0)
		(player as Node3D).global_position = front
		player.set("velocity", Vector3.ZERO)
		print("VANVERIFY NOTE: LOS engage staging: van at ", hvan, " cat front at ", front, " dist=", snappedf(hvan.distance_to(front), 1))
		while str(worker.get("mode")) != "chase" and g2 < 12.0:
			await wait_sec(0.25)
			g2 += 0.25
	check("los: chase started for the LOS test", str(worker.get("mode")) == "chase", str(worker.get("mode")))
	if str(worker.get("mode")) == "chase" and found_house:
		# Cat slips behind the house: still inside his 12m sight
		# radius, but the house body blocks the sight line. The
		# chase should die on the 2-second no-LOS rule (person.gd
		# los_timer >= 2.0), not on distance and not by capture.
		var catpos: Vector3 = hcat
		(player as Node3D).global_position = catpos
		player.set("velocity", Vector3.ZERO)
		var wpos0: Vector3 = (worker as Node3D).global_position
		print("VANVERIFY NOTE: LOS staging: worker at ", wpos0, " cat at ", catpos, " dist=", snappedf(wpos0.distance_to(catpos), 1))
		g2 = 0.0
		var broke: bool = false
		var dist_at_break: float = -1.0
		while g2 < 20.0:
			await wait_sec(0.25)
			g2 += 0.25
			# keep the cat pinned behind the house (he is the
			# quarry, not a moving target, for this probe)
			(player as Node3D).global_position = catpos
			player.set("velocity", Vector3.ZERO)
			if str(main.get("pound_state")) == "return":
				broke = true
				dist_at_break = (worker as Node3D).global_position.distance_to(catpos)
				break
			if str(main.get("state")) != "play":
				break # he rounded the house and caught him — not an LOS break
		print("VANVERIFY NOTE: LOS break: pound_state=", str(main.get("pound_state")), " worker mode=", str(worker.get("mode")), " dist at break=", dist_at_break, " after ", g2, "s")
		check("los: chase breaks on line-of-sight loss behind a house", broke and dist_at_break > 0.0 and dist_at_break < 12.5, "state=" + str(main.get("pound_state")) + " mode=" + str(worker.get("mode")) + " dist=" + str(dist_at_break))
		(player as Node3D).global_position = Vector3(-100, 0.2, 80)
		g2 = 0.0
		while str(main.get("pound_state")) != "patrol" and g2 < 60.0:
			await wait_sec(0.5)
			g2 += 0.5
		check("los: after the break he returns and patrol resumes", str(main.get("pound_state")) == "patrol", str(main.get("pound_state")) + " after " + str(g2) + "s")

	print("VANVERIFY TESTS: %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)
