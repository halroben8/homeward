extends Node3D
# v1.0.35 verification probe (ad-hoc, not part of the suite): the
# unique pair — Danielle and her toddler Noah. Asserts exactly one
# of each spawns, Noah follows Danielle and settles beside her,
# Noah's rendered height is ~half Danielle's, Danielle is friendly
# + always_treat, the pair stays out of the npcs pool, and stages
# proof shots into screenshots_v1035/ (pair together; Zander with
# Danielle mid-interaction). Run under Xvfb, NOT headless:
#   xvfb-run -a godot --path . tests/PairProbe1035.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_v1035"

var main: Node
var cam: Camera3D
var failures: int = 0

func probe(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("PROBE PASS: ", name)
	else:
		failures += 1
		print("PROBE FAIL: ", name, " -- ", detail)

func count_type(node: Node, t: String) -> int:
	var c: int = 0
	if str(node.get("npc_type")) == t:
		c += 1
	for ch in node.get_children():
		c += count_type(ch, t)
	return c

func model_top(n: Node3D) -> float:
	var top: float = -1e9
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var ab: AABB = (cur as MeshInstance3D).global_transform * (cur as MeshInstance3D).get_aabb()
			top = max(top, ab.position.y + ab.size.y)
		for ch in cur.get_children():
			stack.push_back(ch)
	return top

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	var t := 0.0
	while not bool(main.get("build_complete")) and t < 180.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("PROBE: build_complete=", main.get("build_complete"), " after ", t, "s")
	probe("world build completed", bool(main.get("build_complete")))
	main.call("dismiss_splash")
	await get_tree().create_timer(0.4).timeout
	var tp: Object = main.get("title_panel")
	if tp: (tp as CanvasItem).visible = false
	var sp: Object = main.get("splash_panel")
	if sp: (sp as CanvasItem).visible = false
	main.call("start_game")
	await get_tree().create_timer(0.5).timeout

	var dan: Node3D = main.get("danielle_npc")
	var noah: Node3D = main.get("noah_npc")
	probe("danielle_npc exists", dan != null)
	probe("noah_npc exists", noah != null)
	if dan == null or noah == null:
		print("PROBE DONE failures=", failures)
		get_tree().quit(1)
		return
	probe("exactly one danielle in tree", count_type(main, "danielle") == 1, str(count_type(main, "danielle")))
	probe("exactly one noah in tree", count_type(main, "noah") == 1, str(count_type(main, "noah")))
	probe("danielle role friendly", str(dan.get("role")) == "friendly", str(dan.get("role")))
	probe("danielle always_treat", bool(dan.get("always_treat")) == true)
	probe("danielle display name", str(dan.get("display_name")) == "Danielle", str(dan.get("display_name")))
	probe("noah follow_target is danielle", noah.get("follow_target") == dan)
	probe("pair kept out of npcs pool", not (main.get("npcs") as Array).has(dan) and not (main.get("npcs") as Array).has(noah))
	print("PROBE: npcs pool size = ", (main.get("npcs") as Array).size())

	# Rendered heights: Noah ~half of Danielle.
	await get_tree().create_timer(1.0).timeout
	var d_top: float = model_top(dan)
	var n_top: float = model_top(noah)
	var d_base: float = dan.global_position.y
	var n_base: float = noah.global_position.y
	var d_h: float = d_top - d_base
	var n_h: float = n_top - n_base
	print("PROBE: heights danielle=", d_h, " noah=", n_h, " ratio=", (n_h / d_h) if d_h > 0.0 else -1.0)
	probe("danielle rendered height sane (1.3-2.1m)", d_h > 1.3 and d_h < 2.1, str(d_h))
	probe("noah ~half danielle height (ratio 0.35-0.65)", d_h > 0.0 and (n_h / d_h) > 0.35 and (n_h / d_h) < 0.65, str(n_h / d_h) if d_h > 0.0 else "n/a")

	# Free camera for staging.
	cam = Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	cam.current = true

	# Park the town + the cat out of frame for the pair shots.
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-100.0, 0, 80.0)
		n.set("notice", 0.0)
	var pw: Object = main.get("pound_worker")
	if pw: (pw as Node3D).global_position = Vector3(-100.0, 0, -80.0)
	var player: Node3D = main.get("player")
	player.global_position = Vector3(70.0, 0.2, 30.0)

	# Stage the pair on the z=-15 street, walking together.
	dan.global_position = Vector3(24.0, 0.2, -15.0)
	noah.global_position = Vector3(24.0, 0.2, -14.2)
	dan.set("wander_target", Vector3(36.0, 0.2, -15.0))
	dan.set("wander_wait", 0.0)
	await get_tree().create_timer(1.6).timeout
	var mid: Vector3 = (dan.global_position + noah.global_position) * 0.5
	await snap("pair_together", mid + Vector3(0.5, 1.5, 6.4), mid + Vector3(0, 0.75, 0))

	# Follow check over time: Danielle holds still, Noah settles.
	dan.set("wander_target", dan.global_position)
	dan.set("wander_wait", 30.0)
	var settle := 0.0
	while settle < 8.0:
		await get_tree().create_timer(0.25).timeout
		settle += 0.25
		if noah.global_position.distance_to(dan.global_position) < 1.1:
			break
	await get_tree().create_timer(0.8).timeout
	var gap: float = noah.global_position.distance_to(dan.global_position)
	print("PROBE: noah-danielle gap after settle = ", gap)
	probe("noah settles beside danielle (<1.6m)", gap < 1.6, str(gap))
	dan.rotation.y = 0.0
	noah.rotation.y = 0.0
	var pair_mid: Vector3 = (dan.global_position + noah.global_position) * 0.5
	await snap("pair_side_by_side", pair_mid + Vector3(0.2, 1.05, 4.6), pair_mid + Vector3(0, 0.8, 0))

	# Interaction: Zander comes to Danielle; she reacts (trot over,
	# kneel, pet + treat). Noah comes with her.
	player.global_position = dan.global_position + Vector3(2.4, 0, 0.6)
	await get_tree().create_timer(0.3).timeout
	var treats_before: int = int(main.get("treats_count"))
	dan.call("react_to_attention")
	var saw_state := ""
	for i in 14:
		await get_tree().create_timer(0.35).timeout
		saw_state = str(dan.get("interact_state"))
		if saw_state != "":
			break
	print("PROBE: danielle interact_state = ", saw_state)
	probe("danielle reacts to the cat (interaction started)", saw_state != "")
	await get_tree().create_timer(1.8).timeout
	var imid: Vector3 = (dan.global_position + player.global_position) * 0.5
	await snap("zander_with_danielle", imid + Vector3(1.4, 1.15, 4.4), imid + Vector3(0, 0.55, 0))
	# Let the interaction run to completion; a treat should land.
	for i in 20:
		await get_tree().create_timer(0.4).timeout
		if str(dan.get("interact_state")) == "":
			break
	print("PROBE: treats before=", treats_before, " after=", int(main.get("treats_count")), " state=", str(dan.get("interact_state")))
	probe("danielle gave zander a treat", int(main.get("treats_count")) > treats_before,
		"before=" + str(treats_before) + " after=" + str(int(main.get("treats_count"))))
	var gap2: float = noah.global_position.distance_to(dan.global_position)
	print("PROBE: noah-danielle gap after interaction = ", gap2)
	probe("noah stayed with danielle through interaction (<2.5m)", gap2 < 2.5, str(gap2))

	print("PROBE DONE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func snap(label: String, pos: Vector3, target: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + label + ".png")
	print("PROBE SHOT saved ", label)
