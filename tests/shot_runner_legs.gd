extends Node
## LEGS FIX verification (2026-11-18) — NOT part of the suite.
## Boots the REAL game, takes the real flow to town (splash ->
## opening skip -> pound escape completion), parks every NPC /
## the worker / the van, then drives the REAL player cat with
## the game's own inputs (touch_dir / touch_sprint) on Maple
## Street and freezes him at chosen walk_phase values to capture
## gait SEQUENCES: 6 phases walk, 6 phases sprint (side view),
## plus the game's own follow camera at walk and at sprint.
## Output: ~/workspace/homeward/screenshots_legs_fix/
## Run: xvfb-run -a godot --path . tests/ShotRunnerLegs.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_legs_fix"
const SPOT := Vector3(48.0, 0.15, -11.0) # Maple Street (ex-MeshyIngame staging)
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null
var shot_cam: Camera3D = null

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
	print("SHOT: ", name, " ", img.get_size(), " catpos=", (player as Node3D).global_position)

func park(node: Node, off: Vector3) -> void:
	if node == null:
		return
	(node as Node3D).global_position = off
	(node as Node).set_physics_process(false)
	(node as Node).set_process(false)

func reset_cat() -> void:
	player.set_physics_process(true)
	(player as Node3D).global_position = SPOT + Vector3(0, 0.3, 0)
	(player as Node3D).velocity = Vector3.ZERO
	player.set("touch_dir", Vector2.ZERO)

func drive(sprint: bool) -> void:
	player.set("frozen", false)
	player.set("cam_yaw", 0.0)
	player.set("stamina", 100.0)
	player.set("winded", false)
	player.set("touch_sprint", sprint)
	player.set("touch_dir", Vector2(0, -1)) # -Z with cam_yaw 0

func cat_speed() -> float:
	var v: Vector3 = (player as Node3D).velocity
	return Vector2(v.x, v.z).length()

# Wait until walk_phase (mod TAU) is within `tol` of `target`
# while the cat is genuinely moving at gait speed. Watchdog:
# if he gets stuck against something, reset him to the spot.
func wait_phase(target: float, sprint: bool) -> bool:
	var tol := 0.11 if sprint else 0.08
	var stuck := 0
	var guard := 0
	while guard < 2400:
		await get_tree().physics_frame
		guard += 1
		if float(player.get("stun_t")) > 0.0:
			continue
		var sp := cat_speed()
		if sp < 0.5:
			stuck += 1
			if stuck > 90:
				print("WATCHDOG: cat stuck at ", (player as Node3D).global_position, " — resetting")
				reset_cat()
				drive(sprint)
				stuck = 0
			continue
		stuck = 0
		var want := 9.0 if sprint else 4.2
		if sp < want:
			continue
		if sprint and not bool(player.get("is_sprinting")):
			player.set("stamina", 100.0)
			continue
		var ph: float = fmod(float(player.get("walk_phase")), TAU)
		if absf(wrapf(ph - target, -PI, PI)) < tol:
			return true
	return false

func side_shot(name: String) -> void:
	# Freeze the exact pose, frame him side-on from his right.
	player.set_physics_process(false)
	var cp: Vector3 = (player as Node3D).global_position
	var basis_x: Vector3 = (player as Node3D).global_transform.basis.x
	shot_cam.global_position = cp + basis_x * 1.12 + Vector3(0, 0.34, 0)
	shot_cam.look_at(cp + Vector3(0, 0.20, 0), Vector3.UP)
	await snap(name)
	player.set_physics_process(true)

func gait_sequence(prefix: String, sprint: bool) -> void:
	var targets := [0.3, 1.35, 2.4, 3.45, 4.5, 5.55]
	reset_cat()
	drive(sprint)
	await wait_sec(0.6) # up to speed
	for k in range(targets.size()):
		if sprint:
			player.set("stamina", 100.0)
		var ok := await wait_phase(targets[k], sprint)
		print("PHASE ", prefix, k, " target=", targets[k], " ok=", ok, " phase=", snappedf(fmod(float(player.get("walk_phase")), TAU), 0.01))
		await side_shot("%s_p%d.png" % [prefix, k])
		drive(sprint) # resume (reset_cat/drive state reasserted)
	player.set("touch_dir", Vector2.ZERO)
	player.set("touch_sprint", false)

func follow_shot(name: String, sprint: bool) -> void:
	# The game's OWN camera + HUD + input path: what Michael
	# actually sees. Drive through main's floating joystick and
	# the RUN button exactly like the suite does — setting
	# touch_dir directly gets overwritten by main's idle stick.
	for layer_name in ["hud_layer", "touch_layer"]:
		var layer: CanvasLayer = main.get(layer_name)
		if layer:
			layer.visible = true
	var gcam: Camera3D = main.get("cam")
	shot_cam.current = false
	gcam.current = true
	main.set_process(true)
	reset_cat()
	player.set("frozen", false)
	player.set("stamina", 100.0)
	player.set("winded", false)
	main.set("joy_mouse", true)
	main.set("joy_origin", Vector2(200, 400))
	main.set("joy_current", Vector2(200, 400) + Vector2(0, -100))
	if sprint:
		(main.get("run_btn") as Button).button_down.emit()
	# Wait until he is genuinely at gait speed AND the follow
	# camera has had time to swing behind him after the teleport
	# (it lerps; an early snap catches him at the frame edge).
	var want := 9.0 if sprint else 4.2
	var guard := 0
	var at_speed := 0
	while guard < 1800:
		await get_tree().physics_frame
		guard += 1
		if sprint:
			player.set("stamina", 100.0)
		if cat_speed() > want and float(player.get("stun_t")) <= 0.0:
			at_speed += 1
		else:
			at_speed = 0
		if at_speed >= 360: # 3 s continuously at speed
			break
	print("FOLLOW ", name, " speed=", snappedf(cat_speed(), 0.1), " sprinting=", bool(player.get("is_sprinting")))
	await snap(name)
	if sprint:
		(main.get("run_btn") as Button).button_up.emit()
	main.set("joy_mouse", false)
	main.set("joy_id", -999)
	main.set_process(false)
	for layer_name in ["hud_layer", "touch_layer"]:
		var layer: CanvasLayer = main.get(layer_name)
		if layer:
			layer.visible = false
	shot_cam.current = true

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
	print("BUILD complete, frames=", bw)
	await wait_sec(1.0)
	player = main.get("player")
	# Real flow to town: splash -> start -> opening skip -> escape
	# state -> the game's own escape completion.
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var story: Node = main.get("story")
	story.call("skip_opening")
	await wait_sec(0.4)
	print("STATE after skip: ", str(main.get("state")))
	main.call("_complete_escape")
	await wait_sec(0.3)
	print("STATE after escape: ", str(main.get("state")), " cat at ", (player as Node3D).global_position)
	# Neutralise the pursuit + every town actor.
	(main.get("pursuers") as Dictionary).clear()
	var i: int = 0
	for n in main.get("npcs"):
		park(n, Vector3(-110 + float(i) * 2.0, 0.2, 80))
		i += 1
	park(main.get("pound_worker"), Vector3(-115, 0.2, 85))
	var van: Node3D = main.get("pound_van")
	if van:
		van.global_position = Vector3(500, 0, 500)
	main.set_process(false)
	for layer_name in ["hud_layer", "touch_layer", "escape_ui_layer"]:
		var layer: CanvasLayer = main.get(layer_name)
		if layer:
			layer.visible = false
	shot_cam = Camera3D.new()
	shot_cam.fov = 50.0
	add_child(shot_cam)
	shot_cam.current = true

	var follow_only := "--follow-only" in OS.get_cmdline_user_args()
	if not follow_only:
		await gait_sequence("walk", false)
		await gait_sequence("run", true)

		# Bonus: a hop mid-walk — capture while airborne.
		reset_cat()
		drive(false)
		await wait_sec(0.7)
		player.call("try_hop")
		var hop_ok := false
		var hg := 0
		while hg < 240:
			await get_tree().physics_frame
			hg += 1
			if bool(player.get("hop_airborne")) and cat_speed() > 3.0:
				hop_ok = true
				break
		print("HOP airborne captured=", hop_ok)
		if hop_ok:
			await side_shot("hop.png")
		player.set("touch_dir", Vector2.ZERO)

	await follow_shot("follow_walk.png", false)
	await follow_shot("follow_run.png", true)

	print("LEGS SHOTS DONE")
	get_tree().quit(0)
