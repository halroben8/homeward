extends Node
## MESHY CAT in-game context stills (2026-11-18) — NOT part of
## the suite; wires nothing into the shipping game.
##
## Boots the REAL game world at dusk (same staging route as
## shot_runner_northstar), hides the shipping code-built cat,
## and instances the softened Meshy model (loaded from the
## meshy/ folder via GLTFDocument — no project asset changes)
## on Maple Street at the shipping cat's in-world size:
##   scale 0.96 -> back 0.333*0.96 = 0.32 m (matches), ear
##   tips 0.578*0.96 = 0.55 m (shipping: 0.51 m).
## Grounded from the imported mesh's real AABB so his feet sit
## exactly on the street (the GLB origin floats ~0.29 above
## his feet at scale 1).
##   01_follow.png       the game's own town follow framing
##                       (dist 2.0, pitch 4, anchor +1.15, FOV 70)
##   02_face_context.png closer three-quarter in the street
##   03_scale.png        beside a towns-person, side-on
## Output: ~/workspace/homeward/screenshots_meshy_ingame/
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerMeshyIngame.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_meshy_ingame"
const GLB_PATH := "/home/hatch/workspace/homeward/meshy/zander_softened.glb"
const CAT_SCALE := 0.96
const SPOT := Vector3(48.0, 0.15, -11.0) # Maple Street, ex-NorthStar staging
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var cam: Camera3D = null
var cat_root: Node3D = null
var cat_skel: Skeleton3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func set_cam(pos: Vector3, target: Vector3, fov: float = 55.0) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)

func snap_cam(name: String, pos: Vector3, target: Vector3, fov: float = 55.0) -> void:
	set_cam(pos, target, fov)
	await snap(name)

func park(node: Node) -> void:
	(node as Node3D).global_position = Vector3(-110, 0.2, 80)
	(node as Node).set_physics_process(false)
	(node as Node).set_process(false)

func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r: Skeleton3D = find_skeleton(c)
		if r:
			return r
	return null

# Yaw the model so its measured head direction faces `dir`
# (world, XZ). Measured from the live skeleton, so whatever
# internal rotation the GLB carries does not matter.
func face_toward(dir: Vector3) -> void:
	var hp: Vector3 = head_world()
	var sp: Vector3 = cat_skel.global_position
	var f: Vector3 = hp - sp
	f.y = 0
	var phi_f: float = atan2(f.x, f.z)
	var phi_d: float = atan2(dir.x, dir.z)
	cat_root.rotation.y += (phi_d - phi_f)
	print("FACE: measured=", f, " yaw now=", cat_root.rotation.y)

func head_world() -> Vector3:
	var hi: int = cat_skel.find_bone("head")
	return cat_skel.global_transform * cat_skel.get_bone_global_pose(hi).origin

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	EmojiFont.apply()
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(1.2)
	var player: Node = main.get("player")
	cam = main.get("cam")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_frames(10)
	main.set_process(false)
	for layer_name in ["hud_layer", "touch_layer", "escape_ui_layer"]:
		var layer: CanvasLayer = main.get(layer_name)
		if layer:
			layer.visible = false
	# Hide the shipping cat's visuals; park the body far away.
	(player.get("model") as Node3D).visible = false
	park(player)
	# Park everyone; the one nearest the spot is kept for the
	# scale shot (deterministic pick — npc list order varies).
	var keeper: Node = null
	var best_d: float = 1e9
	var npcs_arr: Array = main.get("npcs")
	print("NPCS count=", npcs_arr.size())
	var i: int = 0
	for n in npcs_arr:
		var nd: float = (n as Node3D).global_position.distance_to(SPOT)
		if nd < best_d:
			best_d = nd
			keeper = n
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		(n as Node).set_physics_process(false)
		(n as Node).set_process(false)
		i += 1
	print("KEEPER: ", keeper, " was ", best_d, "m from spot")
	var worker: Node = main.get("pound_worker")
	if worker:
		park(worker)
		(worker as Node3D).visible = false
	var van: Node3D = main.get("pound_van")
	if van:
		van.global_position = Vector3(500, 0, 500)

	# ---- Instance the softened Meshy model from the GLB file ----
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: int = doc.append_from_file(GLB_PATH, state)
	print("GLB append err=", err)
	if err != OK:
		print("MESHY INGAME FAILED: cannot load GLB")
		get_tree().quit(1)
		return
	cat_root = doc.generate_scene(state) as Node3D
	main.add_child(cat_root)
	cat_root.scale = Vector3.ONE * CAT_SCALE
	cat_root.global_position = SPOT
	cat_skel = find_skeleton(cat_root)
	print("SKEL: ", cat_skel, " bones=", cat_skel.get_bone_count() if cat_skel else -1)
	await wait_frames(3)
	# Ground him: shift so the imported mesh AABB bottom = SPOT.y.
	var mi: MeshInstance3D = null
	var stack: Array = [cat_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			mi = n as MeshInstance3D
			break
		for c in n.get_children():
			stack.push_back(c)
	var aabb: AABB = mi.global_transform * mi.get_aabb()
	print("AABB min=", aabb.position, " size=", aabb.size)
	cat_root.global_position.y -= (aabb.position.y - SPOT.y)
	await wait_frames(2)
	aabb = mi.global_transform * mi.get_aabb()
	print("GROUNDED AABB min=", aabb.position, " size=", aabb.size)

	# ---- (a) FOLLOW: the game's own town framing ----------------
	# look_target = cat + (0,1.15,0); cam = target + behind*(cos4*2.0)
	# + (0, sin4*2.0, 0), behind=+Z at yaw 0; FOV 70 (main3d CAM_TOWN_*).
	face_toward(Vector3(0, 0, -1)) # facing away from camera, down the street
	await wait_frames(2)
	var lt: Vector3 = SPOT + Vector3(0, 1.15, 0)
	var cam_pos: Vector3 = lt + Vector3(0, 0, 1) * (cos(deg_to_rad(4.0)) * 2.0) + Vector3(0, sin(deg_to_rad(4.0)) * 2.0, 0)
	await snap_cam("01_follow.png", cam_pos, lt, 70.0)

	# ---- (b) FACE in context: three-quarter close-up -------------
	face_toward(Vector3(0.45, 0, 0.89)) # turned toward camera-right
	await wait_frames(2)
	var hp: Vector3 = head_world()
	print("HEAD world=", hp)
	await snap_cam("02_face_context.png", hp + Vector3(0.42, 0.14, 0.62), hp + Vector3(0, -0.01, 0), 50.0)

	# ---- (c) SCALE: beside a towns-person -------------------------
	face_toward(Vector3(0, 0, -1))
	if keeper:
		(keeper as Node3D).global_position = SPOT + Vector3(0.95, 0.0, 0.1)
		(keeper as Node3D).rotation = Vector3(0, -0.5, 0)
		print("KEEPER placed at ", (keeper as Node3D).global_position, " visible=", (keeper as Node3D).visible)
	await wait_frames(2)
	if keeper:
		print("KEEPER at snap time: ", (keeper as Node3D).global_position)
		# Force the whole visual subtree visible and report where
		# its meshes actually are — some NPC states hide the model
		# child while the body node still reports visible.
		var stack: Array = [keeper]
		while not stack.is_empty():
			var nd: Node = stack.pop_back()
			if nd is Node3D:
				(nd as Node3D).visible = true
			if nd is MeshInstance3D:
				print("KEEPER MESH: ", nd.name, " at ", (nd as Node3D).global_position)
			for c in nd.get_children():
				stack.push_back(c)
		await wait_frames(2)
	await snap_cam("03_scale.png", SPOT + Vector3(0.35, 0.8, 3.9), SPOT + Vector3(0.4, 0.72, 0), 55.0)

	print("MESHY INGAME SHOTS DONE")
	get_tree().quit(0)
