extends Node
# v1.0.35 verification probe B (ad-hoc): reach real town play via
# the sanctioned flow (skip opening -> cage -> bolt panel -> walk
# out, the suite's own helpers), then (1) confirm Danielle's
# always-treat lands (treats_count rises) and (2) take properly
# framed proof shots with the GAME camera into screenshots_v1035/.
#   xvfb-run -a godot --path . tests/PairProbe1035B.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_v1035"

var main: Node
var player: Node
var failures: int = 0

func probe(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("PROBE PASS: ", name)
	else:
		failures += 1
		print("PROBE FAIL: ", name, " -- ", detail)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("PROBE SHOT: ", name, " ", img.get_size())

func stage(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	(player as Node3D).global_position = pos
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", deg_to_rad(yaw_deg))
	main.set("look_pitch_deg", pitch_deg)

# --- the suite's own escape helpers (tests/test_runner.gd) ---
func drive_escape_panel() -> void:
	main.call("_on_escape_prompt_pressed")
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))

func distract_captor() -> void:
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1

func walk_cat_out() -> void:
	var kind: String = str(main.get("exit_open_kind"))
	var o: Vector3 = main.get("escape_origin")
	match kind:
		"latch", "winpush":
			(player as Node3D).global_position = o + Vector3(0, 0.3, -11.2)
		"petdoor", "carrier":
			(player as Node3D).global_position = o + Vector3(6, 0.3, -11.2)
		"bolt":
			(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 576))
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	var t := 0.0
	while not bool(main.get("build_complete")) and t < 180.0:
		await wait_sec(0.25)
		t += 0.25
	print("PROBE: build_complete=", main.get("build_complete"))
	player = main.get("player")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var story: Node = main.get("story")
	story.call("skip_opening")
	probe("skip lands in pound escape", str(main.get("state")) == "escape", str(main.get("state")))
	var gate_p: Vector3 = story.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	probe("cage gate opened", not bool(story.get("cage_closed")))
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	walk_cat_out()
	await wait_sec(0.6)
	probe("escape leads to town play", str(main.get("state")) == "play", str(main.get("state")))
	# Tidy the pursuit (suite's own cleanup).
	var worker: Node = main.get("pound_worker")
	worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(worker)
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_state", "patrol")
	worker.set("active", false)
	(worker as Node3D).visible = false

	var dan: Node3D = main.get("danielle_npc")
	var noah: Node3D = main.get("noah_npc")
	probe("pair present in town play", dan != null and noah != null)

	# Park the town far away; keep the pair.
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-100.0, 0, 80.0)
		n.set("notice", 0.0)

	# --- Shot 1: the pair walking together on the z=-15 street ---
	dan.global_position = Vector3(24.0, 0.2, -15.0)
	noah.global_position = Vector3(24.0, 0.2, -14.2)
	dan.set("wander_target", Vector3(36.0, 0.2, -15.0))
	dan.set("wander_wait", 0.0)
	stage(Vector3(30.0, 0.2, -9.0), 0.0, -4.0)
	await wait_sec(1.6)
	# Re-frame on wherever the pair actually is now.
	var mid: Vector3 = (dan.global_position + noah.global_position) * 0.5
	stage(mid + Vector3(0.0, 0.0, 5.2), 0.0, -4.0)
	await wait_sec(0.9)
	await snap("pair_together.png")

	# --- Shot 2: side by side at rest (heights read clearly) ---
	dan.set("wander_target", dan.global_position)
	dan.set("wander_wait", 30.0)
	var settle := 0.0
	while settle < 8.0:
		await wait_sec(0.25)
		settle += 0.25
		if noah.global_position.distance_to(dan.global_position) < 1.1:
			break
	await wait_sec(0.8)
	var pmid: Vector3 = (dan.global_position + noah.global_position) * 0.5
	stage(pmid + Vector3(0.0, 0.0, 3.4), 0.0, -3.0)
	await wait_sec(0.9)
	await snap("pair_side_by_side.png")

	# --- Treat verification + Shot 3: Zander with Danielle ---
	stage(dan.global_position + Vector3(0.0, 0.0, 2.3), 0.0, -3.0)
	await wait_sec(0.4)
	var treats_before: int = int(main.get("treats_count"))
	dan.call("react_to_attention")
	var seen_states: Array = []
	var snapped_kneel := false
	var elapsed := 0.0
	while elapsed < 150.0:
		await wait_sec(0.4)
		elapsed += 0.4
		var st: String = str(dan.get("interact_state"))
		if st != "" and not seen_states.has(st):
			seen_states.append(st)
			print("PROBE: interact_state -> ", st, " at ", elapsed, "s")
		if not snapped_kneel and st != "" and st != "approach":
			await snap("zander_with_danielle.png")
			snapped_kneel = true
		if int(main.get("treats_count")) > treats_before:
			break
		if st == "" and elapsed > 6.0 and seen_states.size() > 0:
			break # interaction ended without a treat — a failure
	print("PROBE: states seen = ", seen_states)
	print("PROBE: treats ", treats_before, " -> ", int(main.get("treats_count")))
	probe("danielle gave zander a treat", int(main.get("treats_count")) > treats_before,
		"states=" + str(seen_states))
	if not snapped_kneel:
		await snap("zander_with_danielle.png")
	var gap: float = noah.global_position.distance_to(dan.global_position)
	print("PROBE: noah-danielle gap after interaction = ", gap)
	probe("noah stayed with danielle through interaction (<2.5m)", gap < 2.5, str(gap))

	print("PROBE DONE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
