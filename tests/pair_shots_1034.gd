extends Node3D
# v1.0.34 proof-shot probe (ad-hoc, not part of the suite): the
# unique pair — Danielle and Noah — photographed in town at eye
# level, with the Excited Kid staged beside them for the height
# comparison, plus Danielle's treat moment with Zander. Uses the
# established shot-probe pattern: boot Main, dismiss the splash,
# hide the title, free camera, NO start_game (no cutscene).
# Run under Xvfb, NOT headless:
#   xvfb-run -a godot --path . tests/PairShots1034.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_v1034_pair"

var main: Node
var cam: Camera3D

func mesh_height(n: Node) -> float:
	# Same measure as the suite: union of VISIBLE mesh AABBs.
	var box: AABB
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D and (cur as MeshInstance3D).is_visible_in_tree():
			var ga: AABB = (cur as MeshInstance3D).global_transform * (cur as MeshInstance3D).get_aabb()
			if first:
				box = ga
				first = false
			else:
				box = box.merge(ga)
		for ch in cur.get_children():
			stack.append(ch)
	if first:
		return 0.0
	return box.size.y

func snap(label: String, pos: Vector3, target: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + label + ".png")
	print("PAIRSHOT saved ", label)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	print("PAIRSHOT build_complete=", main.get("build_complete"))
	main.call("dismiss_splash")
	await get_tree().create_timer(0.6).timeout
	var tp: Object = main.get("title_panel")
	if tp: (tp as CanvasItem).visible = false
	var sp: Object = main.get("splash_panel")
	if sp: (sp as CanvasItem).visible = false

	cam = Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	cam.current = true

	var dan: Node3D = main.get("danielle_npc")
	var noah: Node3D = main.get("noah_npc")
	var player: Node3D = main.get("player")
	print("PAIRSHOT dan=", dan != null, " noah=", noah != null)
	if dan == null or noah == null:
		get_tree().quit(1)
		return

	# Find the Excited Kid, park everyone else far away.
	var kid: Node3D = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "kid" and kid == null:
			kid = n
		else:
			(n as Node3D).global_position = Vector3(-100.0, 0, 80.0)
			n.set("notice", 0.0)
	var pw: Object = main.get("pound_worker")
	if pw: (pw as Node3D).global_position = Vector3(-100.0, 0, -80.0)
	player.global_position = Vector3(70.0, 0.2, 30.0)

	# Stage the three in a row on the z=-15 street, frozen.
	dan.set("active", false)
	noah.set("active", false)
	if kid: kid.set("active", false)
	dan.global_position = Vector3(24.0, 0.2, -15.0)
	noah.global_position = Vector3(25.0, 0.2, -15.0)
	if kid: kid.global_position = Vector3(23.0, 0.2, -15.0)
	dan.rotation.y = 0.0
	noah.rotation.y = 0.0
	if kid: kid.rotation.y = 0.0
	await get_tree().create_timer(1.2).timeout
	print("PAIRSHOT heights: danielle=%.3f noah=%.3f kid=%.3f" % [mesh_height(dan), mesh_height(noah), mesh_height(kid) if kid else -1.0])
	await snap("pair_lineup_south", Vector3(24.0, 1.15, -10.9), Vector3(24.0, 0.85, -15.0))
	await snap("pair_lineup_north", Vector3(24.0, 1.15, -19.1), Vector3(24.0, 0.85, -15.0))

	# Treat moment: Zander at Danielle's side, she reacts.
	if kid: kid.global_position = Vector3(-60.0, 0, -60.0)
	dan.set("active", true)
	noah.set("active", true)
	dan.set("interact_cooldown", 0.0)
	dan.set("interact_state", "")
	player.global_position = dan.global_position + Vector3(1.5, 0, 0.4)
	var treats_before: int = int(main.get("treats_count"))
	dan.call("react_to_attention")
	var saw := ""
	for i in 30:
		await get_tree().create_timer(0.25).timeout
		saw = str(dan.get("interact_state"))
		if saw == "treat" or saw == "pet":
			break
	print("PAIRSHOT interact_state=", saw)
	# Let the act get underway (kneel), then photograph it.
	await get_tree().create_timer(1.1).timeout
	var mid: Vector3 = (dan.global_position + player.global_position) * 0.5
	await snap("danielle_treat_moment", mid + Vector3(1.5, 0.95, 3.1), mid + Vector3(0, 0.5, 0))
	for i in 24:
		await get_tree().create_timer(0.4).timeout
		if str(dan.get("interact_state")) == "":
			break
	print("PAIRSHOT treats before=", treats_before, " after=", int(main.get("treats_count")), " noah_gap=%.2f" % noah.global_position.distance_to(dan.global_position))
	print("PAIRSHOT DONE")
	get_tree().quit(0)
