extends Node
## HOMEWARD CAMERA FRAMING PROBE (diagnostic — not part of the game).
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/CamProbe.tscn
## Boots the real Main scene and, with the REAL game camera, projects
## the framing-critical points into viewport fractions (x: 0=left,
## 1=right; y: 0=TOP, 1=BOTTOM; a point is visible iff 0<=x,y<=1 and
## not behind the camera):
##   - an adult woman at conversational gaps from the cat: feet, face,
##     head top, name label, NOTICE BAR label
##   - the Maple Street sign board (centre/top/bottom) at several
##     cat distances
##   - the cat's own screen-height share in the ordinary street view
## ...each at the default pitch and at max look-up pitch, so the
## framing failure (and any fix) is measured, not guessed.

var main: Node = null
var player: Node = null
var woman: Node = null
var cam: Camera3D = null
var pitch_default: float = 18.0 # read from the game at boot
var pitch_min: float = -10.0 # read from the game at boot

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func proj(p: Vector3) -> String:
	if cam.is_position_behind(p):
		return "BEHIND"
	var s: Vector2 = cam.unproject_position(p)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return "(%.2f, %.2f)" % [s.x / vp.x, s.y / vp.y]

func in_frame(p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var s: Vector2 = cam.unproject_position(p)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return s.x >= 0.0 and s.x <= vp.x and s.y >= 0.0 and s.y <= vp.y

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func pick_woman() -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman" and str(n.get("role")) == "grabber":
			return n
	return null

func settle(pitch: float) -> void:
	main.set("look_pitch_deg", pitch)
	await wait_sec(1.0) # camera damp k=7 settles in well under this

func measure_person() -> void:
	# Cat faces +X on an open lawn; woman faces him at each gap.
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	main.set("look_yaw", -PI * 0.5)
	var head_top: float = 1.85
	var model: Node3D = woman.get("model")
	if model:
		var a := AABB()
		var first := true
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			a = ga if first else a.merge(ga)
			first = false
		head_top = a.position.y + a.size.y - (woman as Node3D).global_position.y
	print("CAMMEAS person model head_top_local=", snappedf(head_top, 0.01),
		" notice_label_local=", (woman.get("notice_label") as Node3D).position,
		" name_label_local=", (woman.get("name_label") as Node3D).position)
	for pitch in [pitch_default, pitch_min]:
		for gap in [0.8, 1.2, 2.0, 3.0, 5.0]:
			(woman as Node3D).global_position = Vector3(60 + gap, 0.2, 84)
			(woman as Node3D).rotation = Vector3(0, -PI * 0.5, 0)
			await settle(pitch)
			var wp: Vector3 = (woman as Node3D).global_position
			var feet := wp + Vector3(0, 0.05, 0)
			var face := wp + Vector3(0, 1.52, 0)
			var top := wp + Vector3(0, head_top, 0)
			var notice_p: Vector3 = (woman.get("notice_label") as Node3D).global_position
			var name_p: Vector3 = (woman.get("name_label") as Node3D).global_position
			print("CAMMEAS pitch=", pitch, " gap=", gap,
				" cam_pos=", cam.global_position, " cam_fov=", cam.fov,
				" | feet ", proj(feet), " in=", in_frame(feet),
				" | face ", proj(face), " in=", in_frame(face),
				" | headtop ", proj(top), " in=", in_frame(top),
				" | name ", proj(name_p), " in=", in_frame(name_p),
				" | NOTICE ", proj(notice_p), " in=", in_frame(notice_p))

func measure_sign() -> void:
	# Maple Street sign at (-58, 0, -6); board centre y=3.75, board
	# spans 3.22..4.28. Cat stands south of it, facing it (-Z).
	(woman as Node3D).global_position = Vector3(-110, 0.2, 80)
	main.set("look_yaw", 0.0)
	(player as Node3D).rotation = Vector3(0, PI, 0)
	var centre := Vector3(-58, 3.75, -6)
	var top := Vector3(-58, 4.28, -6)
	var bottom := Vector3(-58, 3.22, -6)
	for pitch in [pitch_default, pitch_min]:
		for d in [2.0, 3.0, 4.0, 6.0]:
			(player as Node3D).global_position = Vector3(-58, 0.2, -6 + d)
			await settle(pitch)
			print("CAMMEAS SIGN pitch=", pitch, " catdist=", d,
				" cam_pos=", cam.global_position,
				" | centre ", proj(centre), " in=", in_frame(centre),
				" | top ", proj(top), " in=", in_frame(top),
				" | bottom ", proj(bottom), " in=", in_frame(bottom))

func measure_cat_share() -> void:
	# Ordinary street view: default pitch, nobody staged, cat on lawn.
	(woman as Node3D).global_position = Vector3(-110, 0.2, 80)
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	main.set("look_yaw", -PI * 0.5)
	await settle(pitch_default)
	# Cat drawn AABB (wrapper included) via its mesh instances.
	var a := AABB()
	var first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		a = ga if first else a.merge(ga)
		first = false
	var base: Vector3 = (player as Node3D).global_position
	var bot := Vector3(base.x, a.position.y, base.z)
	var top := Vector3(base.x, a.position.y + a.size.y, base.z)
	var sb: Vector2 = cam.unproject_position(bot)
	var st: Vector2 = cam.unproject_position(top)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	print("CAMMEAS CAT drawn_height=", snappedf(a.size.y, 0.03),
		" screen_share=", snappedf(absf(sb.y - st.y) / vp.y, 0.03),
		" top_frac=", snappedf(st.y / vp.y, 0.02), " bot_frac=", snappedf(sb.y / vp.y, 0.02),
		" cam_pos=", cam.global_position)

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	cam = main.get("cam")
	pitch_default = float(main.get("look_pitch_deg"))
	var mn = main.get("LOOK_PITCH_MIN")
	if mn != null:
		pitch_min = float(mn)
	print("CAMPROBE shipped default_pitch=", pitch_default, " pitch_min=", pitch_min)
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	woman = pick_woman()
	woman.set_physics_process(false) # hold her exactly where staged
	print("CAMPROBE woman=", str(woman.get("display_name")), " body_h=", woman.get("body_h"),
		" town_dist=", main.get("CAM_TOWN_DIST") if false else "(const, see code)")
	await measure_person()
	await measure_sign()
	await measure_cat_share()
	print("CAMPROBE DONE")
	get_tree().quit(0)
