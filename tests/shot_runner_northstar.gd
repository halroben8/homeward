extends Node
## NORTH STAR CAT comparison stills (2026-11-18) — NOT part of
## the suite; wires nothing into the game.
##
## Boots the REAL game world at dusk (same staging route as
## shot_runner_splash), then instances a SECOND cat with
## cat.gd's `north_star` variant flag set BEFORE it enters the
## tree. The player cat is the shipping model. Both are posed
## identically on Maple Street and shot with the same cameras:
##   pair.png          both cats side by side, front 3/4
##   face_current.png  shipping cat, face close-up (head-relative cam)
##   face_ns.png       North Star variant, same face framing
##   profile_current.png / profile_ns.png  side profile, gameplay distance
##   run_current.png   / run_ns.png        gallop pose, dkc3 hero framing
## Output: ~/workspace/homeward/screenshots_northstar/
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerNorthStar.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_northstar"
const CatScript: GDScript = preload("res://scripts/cat.gd")
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null # shipping model
var variant: Node = null # north_star = true
var cam: Camera3D = null

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

# Gallop pose, the dkc5/dkc7 staging values (real mid-gallop
# legs, no mirrored pairs), applied to either cat instance.
func pose_gallop(cat: Node, y: float) -> void:
	var m: Node3D = cat.get("model")
	var legs: Array = cat.get("leg_pivots")
	var tails: Array = cat.get("tail_pivots")
	m.rotation.x = 0.10
	m.scale = Vector3(1.0, 1.03, 1.16)
	legs[0].rotation.x = -1.30 # FL reaching
	legs[1].rotation.x = 0.50 # FR tucked under
	legs[2].rotation.x = 1.30 # BL extended behind
	legs[3].rotation.x = -0.55 # BR driving through
	for t in tails:
		(t as Node3D).rotation.x = 0.70
	(cat as Node3D).global_position.y = y

func pose_neutral(cat: Node) -> void:
	var m: Node3D = cat.get("model")
	m.rotation = Vector3.ZERO
	m.scale = Vector3.ONE
	for l in cat.get("leg_pivots"):
		(l as Node3D).rotation = Vector3.ZERO
	# Tail carried UP like the reference (the build pose is
	# -19 deg per segment; a touch more curl reads as the
	# illustration's upright, white-tipped tail).
	var curl := [-0.52, -0.46, -0.38]
	var tails: Array = cat.get("tail_pivots")
	for i in range(tails.size()):
		(tails[i] as Node3D).rotation = Vector3(curl[i], 0, 0)

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
	player = main.get("player")
	cam = main.get("cam")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_frames(10)
	main.set_process(false)
	for layer_name in ["hud_layer", "touch_layer", "escape_ui_layer"]:
		var layer: CanvasLayer = main.get(layer_name)
		if layer:
			layer.visible = false
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		(n as Node).set_physics_process(false)
		i += 1
	var worker: Node = main.get("pound_worker")
	if worker:
		park(worker)
		(worker as Node3D).visible = false
	var van: Node3D = main.get("pound_van")
	if van:
		van.global_position = Vector3(500, 0, 500)
	park(player)
	# The variant: flag set BEFORE add_child (model builds in
	# _ready). Removed from the "player" group so nothing in
	# the frozen world can mistake it for the real cat.
	var v := CharacterBody3D.new()
	v.set_script(CatScript)
	v.set("north_star", true)
	main.add_child(v)
	v.remove_from_group("player")
	variant = v
	park(variant)
	print("NORTHSTAR staged: player north_star=", str(player.get("north_star")),
		" variant north_star=", str(variant.get("north_star")))
	await wait_frames(3)

	# ---- (0) PAIR: side by side on the Maple road, front 3/4 ----
	pose_neutral(player)
	pose_neutral(variant)
	(player as Node3D).global_position = Vector3(47.55, 0.15, -11.0)
	(player as Node3D).rotation = Vector3(0, 0.45, 0)
	(variant as Node3D).global_position = Vector3(48.55, 0.15, -11.0)
	(variant as Node3D).rotation = Vector3(0, 0.45, 0)
	await wait_frames(2)
	await snap_cam("pair.png", Vector3(48.05, 0.62, -8.15), Vector3(48.05, 0.42, -11.0), 50.0)

	# ---- (a) FACE close-ups: same head-relative framing ----
	for which in ["current", "ns"]:
		var cat: Node = player if which == "current" else variant
		var other: Node = variant if which == "current" else player
		park(other)
		pose_neutral(cat)
		(cat as Node3D).global_position = Vector3(48.0, 0.15, -11.0)
		(cat as Node3D).rotation = Vector3(0, 0.45, 0)
		await wait_frames(2)
		var head_pos: Vector3 = (cat.get("head_node") as Node3D).global_position
		var dir := Vector3(0.52, 0.16, 1.0).normalized()
		await snap_cam("face_" + which + ".png", head_pos + dir * 0.52, head_pos + Vector3(0, -0.005, 0), 50.0)

	# ---- (b) PROFILE at gameplay distance: identical world camera ----
	for which in ["current", "ns"]:
		var cat: Node = player if which == "current" else variant
		var other: Node = variant if which == "current" else player
		park(other)
		pose_neutral(cat)
		(cat as Node3D).global_position = Vector3(48.0, 0.15, -11.0)
		(cat as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X
		await wait_frames(2)
		await snap_cam("profile_" + which + ".png", Vector3(48.0, 0.48, -8.55), Vector3(48.0, 0.34, -11.0), 55.0)

	# ---- (c) RUN pose: the proven dkc3 hero framing, both cats ----
	for which in ["current", "ns"]:
		var cat: Node = player if which == "current" else variant
		var other: Node = variant if which == "current" else player
		park(other)
		(cat as Node3D).global_position = Vector3(48.46, 0.71, -10.60)
		(cat as Node3D).rotation = Vector3(0, 1.12, 0)
		pose_gallop(cat, 0.71)
		((cat as Node).get("model") as Node3D).rotation.z = 0.04
		await wait_frames(2)
		await snap_cam("run_" + which + ".png", Vector3(49.13, 0.88, -9.65), Vector3(48.46, 1.04, -10.57), 46.0)

	print("NORTHSTAR SHOTS DONE")
	get_tree().quit(0)
