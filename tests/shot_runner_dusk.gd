extends Node
## HOMEWARD dusk-lighting screenshots (before/after pair).
## Run under Xvfb, passing the output subfolder as the last CLI arg:
##   xvfb-run -a godot --path . tests/ShotRunnerDusk.tscn -- before
##   xvfb-run -a godot --path . tests/ShotRunnerDusk.tscn -- after
## Four staged scenes:
##   a_street_cat     ordinary street view on Maple Street, game's
##                    own camera behind the cat; a lamp post stands
##                    ahead-right so lamp heads are in frame
##   b_person_close   cat face-to-face with a friendly woman at
##                    1.2 m, her JOY expression set — face readability
##   c_sign_lookup    max look-up at the Oak Avenue sign, cat 3 m
##                    away — sign readability (proven staging from
##                    the camera-framing runner)
##   d_overview       raised view over the east district (frozen
##                    camera, same framing as the map runner)
## Output: ~/workspace/homeward/screenshots_dusk/<arg>/

const BASE := "/home/hatch/workspace/homeward/screenshots_dusk"
var OUT := BASE + "/before"
var main: Node = null
var player: Node = null
var woman: Node = null
var cam: Camera3D = null
var default_pitch: float = 18.0

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func frac(p: Vector3) -> String:
	if cam.is_position_behind(p):
		return "BEHIND"
	var s: Vector2 = cam.unproject_position(p)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return "(%.2f, %.2f)" % [s.x / vp.x, s.y / vp.y]

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func pick_friendly_woman() -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman" and str(n.get("role")) == "friendly":
			return n
	return null

func print_env() -> void:
	var wes: Array = []
	_find_all(main, "WorldEnvironment", wes)
	if wes.size() > 0:
		var env: Environment = (wes[0] as WorldEnvironment).environment
		var psm := env.sky.sky_material as ProceduralSkyMaterial
		print("ENV sky_top=", psm.sky_top_color, " sky_horizon=", psm.sky_horizon_color,
			" ground_horizon=", psm.ground_horizon_color,
			" ambient_src=", env.ambient_light_source, " ambient_energy=", env.ambient_light_energy,
			" tonemap=", env.tonemap_mode, " bright=", env.adjustment_brightness,
			" contrast=", env.adjustment_contrast, " sat=", env.adjustment_saturation,
			" fog_col=", env.fog_light_color, " fog_energy=", env.fog_light_energy,
			" fog_density=", env.fog_density, " fog_sky_affect=", env.fog_sky_affect)
	var suns: Array = []
	_find_all(main, "DirectionalLight3D", suns)
	for s in suns:
		var dl := s as DirectionalLight3D
		print("LIGHT rot=", dl.rotation_degrees, " col=", dl.light_color,
			" energy=", dl.light_energy, " shadow=", dl.shadow_enabled)

func _find_all(n: Node, type_name: String, out: Array) -> void:
	if n.is_class(type_name):
		out.append(n)
	for ch in n.get_children():
		_find_all(ch, type_name, out)

func scene_street() -> void:
	# Cat on Maple Street (road centreline z=-11) facing +X; the
	# lamp at (50, 0, -16.6) stands ahead-right on the verge.
	(player as Node3D).global_position = Vector3(44, 0.2, -11)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", default_pitch)
	await wait_sec(1.2)
	print("DUSKSHOT a lamp_head=", frac(Vector3(50, 4.5, -16.6)))
	await snap("a_street_cat.png")

func scene_person() -> void:
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", default_pitch)
	(woman as Node3D).global_position = Vector3(61.2, 0.2, 84) # 1.2 m gap
	(woman as Node3D).rotation = Vector3(0, -PI * 0.5, 0) # face the cat
	woman.set("mode", "wander")
	woman.call("set_expression", "joy")
	await wait_sec(0.2)
	woman.set_physics_process(false) # hold the pose + face for the shot
	# Re-apply BOTH position and rotation after freezing: her
	# wander AI turns her during the settle waits (an earlier cut
	# of this runner re-set only the position and shot her back).
	(woman as Node3D).global_position = Vector3(61.2, 0.2, 84)
	(woman as Node3D).rotation = Vector3(0, -PI * 0.5, 0)
	woman.call("set_expression", "joy")
	await wait_sec(1.1) # camera settle
	var wp: Vector3 = (woman as Node3D).global_position
	print("DUSKSHOT b face=", frac(wp + Vector3(0, 1.52, 0)),
		" expr=", str(woman.get("expression")))
	await snap("b_person_close.png")
	woman.set_physics_process(true)

func scene_sign() -> void:
	# Oak Avenue sign at (58, 0, 20), cat 3 m south, max look-up
	# through the real look-drag input path (proven staging).
	(woman as Node3D).global_position = Vector3(-110, 0.2, 80)
	(player as Node3D).global_position = Vector3(58, 0.2, 23)
	(player as Node3D).rotation = Vector3(0, PI, 0) # face the sign (-Z)
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", default_pitch)
	await wait_sec(0.6)
	main.call("apply_look_drag", Vector2(0, -100000)) # -> max look-up
	await wait_sec(1.1)
	print("DUSKSHOT c sign_centre=", frac(Vector3(58, 3.75, 20)),
		" sign_top=", frac(Vector3(58, 4.28, 20)),
		" sign_bottom=", frac(Vector3(58, 3.22, 20)))
	await snap("c_sign_lookup.png")

func scene_room() -> void:
	# Bonus sanity check (not one of the four required frames):
	# the escape-room interior must stay warm and lit by its own
	# lights, not dragged into dusk. Staging follows the
	# escape-flow runner: grabber woman as captor, _enter_escape.
	var grabber: Node = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman" and str(n.get("role")) == "grabber":
			grabber = n
			break
	var o: Vector3 = main.get("escape_origin")
	print("DUSKSHOT room grabber=", grabber, " origin=", o)
	main.set("captor", grabber)
	print("DUSKSHOT room captor_now=", main.get("captor"))
	main.call("_enter_escape")
	(grabber as Node3D).global_position = o + Vector3(11.6, 0.25, -4.5)
	main.set("captor_room_wait", 30.0)
	(player as Node3D).global_position = o + Vector3(-4.6, 0.3, 6.2)
	(player as Node3D).rotation = Vector3(0, -2.32, 0)
	main.set("look_yaw", 0.82)
	main.set("look_pitch_deg", 10.0)
	await wait_sec(3.0)
	await snap("e_escape_room.png")

func scene_overview() -> void:
	main.set_process(false)
	await get_tree().process_frame
	cam.global_position = Vector3(246, 165, 150)
	cam.look_at(Vector3(246, 0, -5), Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/d_overview.png")
	print("SHOT: d_overview.png ", img.get_size())
	main.set_process(true)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = BASE + "/" + args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	cam = main.get("cam")
	default_pitch = float(main.get("look_pitch_deg"))
	print("DUSKSHOT default_pitch=", default_pitch, " fov=", cam.fov)
	print_env()
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	woman = pick_friendly_woman()
	await scene_street()
	await scene_person()
	await scene_sign()
	await scene_overview()
	await scene_room()
	print("DONE")
	get_tree().quit(0)
