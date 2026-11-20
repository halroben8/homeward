extends Node
## v1.0.30 TAIL PROBE (diagnostic — not part of the game).
## Covers the final 8 checks of tests/test_runner.gd (idle purr,
## the two v1.0.27 tree/scatter audits, and the 5 opening checks)
## with the same assertions, on a fresh boot. The full suite on
## this shared box repeatedly hit wall-clock timeouts in its
## final section (358/366 printed, 0 FAIL, in the clean run);
## this probe runs the tail in isolation, the same remedy the
## v1.0.28 build used for the suite's opening section.
## Run: xvfb-run -a godot --path . tests/TailProbe1030.tscn

var main: Node = null
var player: Node = null
var passed: int = 0
var failed: int = 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: ", name)
	else:
		failed += 1
		print("FAIL: ", name, " -- ", detail)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var _bw: int = 0
	while not bool(main.get("build_complete")) and _bw < 21600:
		await get_tree().process_frame
		_bw += 1
	await wait_sec(0.6)
	player = main.get("player")
	main.call("dismiss_splash")
	await wait_sec(0.3)

	# ---------- opening checks (suite tail, verbatim assertions) ----------
	var story25: Node = main.get("story")
	main.call("start_game")
	check("v1.0.25 opening: START begins the opening cutscene", str(main.get("state")) == "opening", str(main.get("state")))
	var echo25 := InputEventMouseButton.new()
	echo25.button_index = MOUSE_BUTTON_LEFT
	echo25.pressed = true
	echo25.position = Vector2(640, 360)
	get_viewport().push_input(echo25)
	await wait_sec(0.3)
	check("v1.0.25 opening: the START tap's own echo does NOT skip the opening", str(main.get("state")) == "opening" and not bool(story25.get("finished")), str(main.get("state")) + " finished=" + str(story25.get("finished")))
	await wait_sec(1.5)
	var vp27: Vector2 = get_viewport().get_visible_rect().size
	var joy27 := InputEventScreenTouch.new()
	joy27.index = 3
	joy27.position = vp27 * Vector2(0.14, 0.72)
	joy27.pressed = true
	get_viewport().push_input(joy27)
	var joy27up := InputEventScreenTouch.new()
	joy27up.index = 3
	joy27up.position = vp27 * Vector2(0.14, 0.72)
	joy27up.pressed = false
	get_viewport().push_input(joy27up)
	var look27 := InputEventScreenTouch.new()
	look27.index = 4
	look27.position = vp27 * Vector2(0.68, 0.35)
	look27.pressed = true
	get_viewport().push_input(look27)
	var look27up := InputEventScreenTouch.new()
	look27up.index = 4
	look27up.position = vp27 * Vector2(0.68, 0.35)
	look27up.pressed = false
	get_viewport().push_input(look27up)
	var click27 := InputEventMouseButton.new()
	click27.button_index = MOUSE_BUTTON_LEFT
	click27.pressed = true
	click27.position = vp27 * Vector2(0.5, 0.5)
	get_viewport().push_input(click27)
	await wait_sec(0.3)
	check("v1.0.27 opening: control touches after the grace do NOT skip the opening", str(main.get("state")) == "opening" and not bool(story25.get("finished")), str(main.get("state")) + " finished=" + str(story25.get("finished")))
	var skip27: Object = story25.get("skip_btn")
	check("v1.0.27 opening: a SKIP button is offered during the beats", skip27 != null and (skip27 as Button).visible)
	if skip27 != null:
		(skip27 as Button).pressed.emit()
		await wait_sec(0.3)
		check("v1.0.27 opening: the SKIP button still skips to the pound", bool(story25.get("finished")) or str(main.get("state")) != "opening", str(main.get("state")) + " finished=" + str(story25.get("finished")))

	# ---------- idle purr (staged to free roam, as the suite's
	# late sections leave the game: state "play", cat in town) ----------
	main.set("state", "play")
	park_npcs_far()
	(player as Node3D).global_position = Vector3(110, 0.2, 84)
	player.set("velocity", Vector3.ZERO)
	await wait_sec(3.6)
	check("idle purr starts after ~3s still", bool(main.get("purr_active")))

	# ---------- v1.0.27 trees audit (verbatim logic) ----------
	var pads27: Array = main.get("driveway_pads")
	var cars27: Array = main.get("parked_car_spots")
	var trees27: Array = main.get("tree_registry")
	var tree_bad27: Array = []
	for te27 in trees27:
		var tn27 := te27["node"] as Node3D
		if tn27 == null or not is_instance_valid(tn27) or not tn27.visible:
			continue
		var tp27: Vector3 = tn27.global_position
		var tr27: float = float(te27["r"])
		for dp27 in pads27:
			var ddx27: float = maxf(absf(tp27.x - float(dp27["cx"])) - float(dp27["hx"]), 0.0)
			var ddz27: float = maxf(absf(tp27.z - float(dp27["cz"])) - float(dp27["hz"]), 0.0)
			if Vector2(ddx27, ddz27).length() < tr27 + 0.25:
				tree_bad27.append("pad@" + str(tp27))
		for cp27 in cars27:
			if Vector2(tp27.x - (cp27 as Vector3).x, tp27.z - (cp27 as Vector3).z).length() < tr27 + 2.5:
				tree_bad27.append("car@" + str(tp27))
		if bool(main.call("_paved_spot", tp27)):
			tree_bad27.append("paved@" + str(tp27))
	check("v1.0.27 trees: no canopy over a driveway or parked car, no trunk on pavement (violations=0)", tree_bad27.is_empty(), str(tree_bad27))
	var pad_open27: int = 0
	for dp27b in pads27:
		var pcx27: float = float(dp27b["cx"])
		var pcz27: float = float(dp27b["cz"])
		var phx27: float = float(dp27b["hx"]) - 0.3
		var phz27: float = float(dp27b["hz"]) - 0.3
		for off27 in [Vector2(0, 0), Vector2(phx27, phz27), Vector2(-phx27, phz27), Vector2(phx27, -phz27), Vector2(-phx27, -phz27), Vector2(phx27, 0), Vector2(-phx27, 0), Vector2(0, phz27), Vector2(0, -phz27)]:
			if not bool(main.call("_ground_spot_blocked", Vector3(pcx27 + off27.x, 0, pcz27 + off27.y))):
				pad_open27 += 1
	check("v1.0.27 ground scatter: every driveway pad is blocked ground (no tufts on driveways)", pad_open27 == 0 and pads27.size() >= 10, "open=" + str(pad_open27) + " pads=" + str(pads27.size()))

	print("TAILPROBE: %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)
