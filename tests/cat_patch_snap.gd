extends Node3D
## Cat chest-patch proof shots: instances the real player cat alone
## on a neutral stage (bright even light, no dusk grade) and snaps
## close-ups — front three-quarter, dead front, side, and a low
## front angle that reads the whole underside run.
## Run: xvfb-run -a godot --path . tests/CatPatchSnap.tscn -- <outdir>

const CatScript: GDScript = preload("res://scripts/cat.gd")
var OUT := "/home/hatch/workspace/homeward/screenshots_catpatch"
var cam: Camera3D

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func shoot(pos: Vector3, look: Vector3, name: String) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await wait_sec(0.35)
	await snap(name)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1400, 1050))

	# neutral stage: pale floor, even ambient + one key light
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.68, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.95, 0.95)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.57, 0.6)
	floor_mi.material_override = fm
	add_child(floor_mi)

	# the cat himself, frozen in his standing bind pose
	var cat := CharacterBody3D.new()
	cat.set_script(CatScript)
	add_child(cat)
	cat.set_physics_process(false)
	cat.set_process(false)

	cam = Camera3D.new()
	cam.fov = 42.0
	add_child(cam)

	await wait_sec(0.6)
	# cat faces +Z; body centre ~y 0.22, head ~y 0.32 z 0.27
	await shoot(Vector3(0.52, 0.34, 0.92), Vector3(0, 0.22, 0.0), "front34.png")
	await shoot(Vector3(0.0, 0.30, 1.02), Vector3(0, 0.23, 0.02), "front.png")
	await shoot(Vector3(1.02, 0.30, -0.02), Vector3(0, 0.22, -0.02), "side.png")
	await shoot(Vector3(0.30, 0.045, 0.88), Vector3(0, 0.20, -0.06), "belly_low.png")
	print("CATPATCH SHOTS DONE -> ", OUT)
	get_tree().quit(0)
