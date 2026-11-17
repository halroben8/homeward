extends Node
## HOMEWARD POUND VAN — verification pass 2: the two probes that
## needed the town's real lot geometry.
##   B2  through-a-house ENGAGEMENT: the van's spot gate is a flat
##       12m radius with no LOS test — but town lots are audited
##       >= 14 units from road centrelines, so this probe computes
##       the CLOSEST any behind-a-house cat can ever get to a van
##       on a lane, stages exactly that, and watches the gate.
##   LOS chase break on foot: engage him in front of that house,
##       slip the cat behind it (inside his 12m sight radius, house
##       body on the sight line) and watch the 2s no-LOS rule fire.
## Run: godot --headless --path . tests/VerifyPoundVan2.tscn

var main: Node = null
var player: Node = null
var passed: int = 0
var failed: int = 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("VANVERIFY2 PASS: ", name)
	else:
		failed += 1
		print("VANVERIFY2 FAIL: ", name, " -- ", detail)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("notice_cooldown", 99999.0)
		i += 1

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(320, 200))
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

	# ---- census: closest behind-a-house staging in the whole town
	var lanes_h: Array = [-55.0, -11.0, 15.0, 55.0]
	var lanes_v: Array = [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0]
	var best: Dictionary = {}
	var best_dist: float = 1e9
	var min_centre_dist: float = 1e9
	for h in main.get("houses"):
		var hp: Vector3 = h["pos"]
		for rz in lanes_h:
			var dz: float = absf(hp.z - rz)
			min_centre_dist = minf(min_centre_dist, dz)
			var dir: Vector3 = Vector3(0, 0, signf(hp.z - rz))
			var cat: Vector3 = hp + dir * 4.5 + Vector3(0, 0.2, 0)
			var vp: Vector3 = Vector3(hp.x, 0, rz + dir.z * 1.8) # the driving lane, not the centreline
			var d: float = vp.distance_to(cat)
			if d < best_dist:
				best_dist = d
				best = {"van": vp, "cat": cat, "house": hp, "front": hp - dir * 5.0 + Vector3(0, 0.2, 0)}
		for rx in lanes_v:
			var dx: float = absf(hp.x - rx)
			min_centre_dist = minf(min_centre_dist, dx)
			var dir2: Vector3 = Vector3(signf(hp.x - rx), 0, 0)
			var cat2: Vector3 = hp + dir2 * 4.5 + Vector3(0, 0.2, 0)
			var vp2: Vector3 = Vector3(rx + dir2.x * 1.8, 0, hp.z)
			var d2: float = vp2.distance_to(cat2)
			if d2 < best_dist:
				best_dist = d2
				best = {"van": vp2, "cat": cat2, "house": hp, "front": hp - dir2 * 5.0 + Vector3(0, 0.2, 0)}
	print("VANVERIFY2 NOTE: census over ", (main.get("houses") as Array).size(), " houses: min lot-centre distance to a road centreline = ", snappedf(min_centre_dist, 0.1), "m; closest possible behind-a-house cat to a lane-driving van = ", snappedf(best_dist, 0.1), "m (spot radius is 12.0)")
	check("geometry: every behind-a-house spot is OUTSIDE the 12m spot radius", best_dist > 12.0, str(best_dist))

	# ---- B2: stage that closest case and watch the gate ----------
	var hvan: Vector3 = best["van"]
	var hcat: Vector3 = best["cat"]
	main.set("player_collared", false)
	main.set("pound_state", "patrol")
	main.set("pound_engage_cd", 0.0)
	(player as Node3D).global_position = hcat
	player.set("velocity", Vector3.ZERO)
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
	check("trigger: no engagement with the cat behind a house at the town's closest staging", not engaged, "pound_state=" + str(main.get("pound_state")))

	# ---- LOS: engage in front of the house, slip behind it --------
	var front: Vector3 = best["front"]
	van.position = hvan
	main.set("pound_van_yaw", 0.0)
	van.rotation.y = 0.0
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "patrol")
	main.set("pound_engage_cd", 0.0)
	(player as Node3D).global_position = front
	player.set("velocity", Vector3.ZERO)
	print("VANVERIFY2 NOTE: LOS engage staging: van at ", hvan, " cat front at ", front, " dist=", snappedf(hvan.distance_to(front), 1))
	var g: float = 0.0
	while str(worker.get("mode")) != "chase" and g < 12.0:
		await wait_sec(0.25)
		g += 0.25
	check("los: chase started in front of the house", str(worker.get("mode")) == "chase", str(worker.get("mode")) + " after " + str(g) + "s")
	if str(worker.get("mode")) == "chase":
		(player as Node3D).global_position = hcat
		player.set("velocity", Vector3.ZERO)
		var wpos0: Vector3 = (worker as Node3D).global_position
		print("VANVERIFY2 NOTE: LOS slip: worker at ", wpos0, " cat behind house at ", hcat, " dist=", snappedf(wpos0.distance_to(hcat), 1), " (sight radius 12)")
		g = 0.0
		var broke: bool = false
		var dist_at_break: float = -1.0
		while g < 20.0:
			await wait_sec(0.25)
			g += 0.25
			(player as Node3D).global_position = hcat
			player.set("velocity", Vector3.ZERO)
			if str(main.get("pound_state")) == "return":
				broke = true
				dist_at_break = (worker as Node3D).global_position.distance_to(hcat)
				break
			if str(main.get("state")) != "play":
				break
		print("VANVERIFY2 NOTE: LOS outcome: pound_state=", str(main.get("pound_state")), " mode=", str(worker.get("mode")), " dist at break=", dist_at_break, " after ", g, "s")
		check("los: chase breaks with the house on the sight line (not by capture)", broke and str(main.get("state")) == "play", "state=" + str(main.get("pound_state")) + "/" + str(main.get("state")))
		(player as Node3D).global_position = Vector3(-100, 0.2, 80)
		g = 0.0
		while str(main.get("pound_state")) != "patrol" and g < 60.0:
			await wait_sec(0.5)
			g += 0.5
		check("los: after the break he returns and patrol resumes", str(main.get("pound_state")) == "patrol", str(main.get("pound_state")) + " after " + str(g) + "s")

	print("VANVERIFY2 TESTS: %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)
