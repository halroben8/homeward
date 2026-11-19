extends Node3D
## HELD/CRADLE snap (legs fix, 2026-11-18): instances the real
## player cat on the MeshySnap-style neutral stage, calls the
## real start_held(), drives _animate by hand until the cradle
## settles, and shoots it — plus prints the front upper-leg
## bone's deviation from rest (the shipped build's snapshot
## differencing ate ~92% of the fold: ~0.13 rad of the 1.5).
## Run: xvfb-run -a godot --path . tests/HeldSnap.tscn

const CatScript: GDScript = preload("res://scripts/cat.gd")
const OUT := "/home/hatch/workspace/homeward/screenshots_legs_fix"
var cam: Camera3D
var cat: Node

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
	await wait_sec(0.3)
	await snap(name)

func drive(sec: float, speed: float) -> void:
	var steps := int(sec * 60.0)
	for i in range(steps):
		cat.call("_animate", 1.0 / 60.0, speed)
		await get_tree().process_frame

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1200, 900))
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
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.57, 0.6)
	floor_mi.material_override = fm
	add_child(floor_mi)

	cat = CharacterBody3D.new()
	cat.set_script(CatScript)
	add_child(cat)
	cat.set_physics_process(false)
	cam = Camera3D.new()
	cam.fov = 42.0
	add_child(cam)

	await drive(1.0, 0.0) # settle idle
	cat.call("start_held")
	await drive(1.6, 0.0) # startle + cradle settle (held_a -> 1)
	print("HELD held_a=", snappedf(float(cat.get("held_a")), 0.01))
	var skel: Skeleton3D = cat.get("meshy_skel")
	var rest: Dictionary = cat.get("meshy_rest")
	var bones: Dictionary = cat.get("meshy_bone")
	for role in ["fl", "fl_lo", "bl"]:
		var bi: int = int(bones[role])
		var cur: Basis = skel.get_bone_global_pose(bi).basis.orthonormalized()
		var rst: Basis = (rest[bi] as Transform3D).basis.orthonormalized()
		var rel: Basis = rst.inverse() * cur
		var tr: float = rel.x.x + rel.y.y + rel.z.z
		var ang: float = acos(clampf((tr - 1.0) * 0.5, -1.0, 1.0))
		print("HELD bone ", role, " deviation from rest (rad)=", snappedf(ang, 0.01))
	# Lift him to chest height for the portrait, as the game does.
	(cat as Node3D).position.y = 0.55
	await drive(0.2, 0.0)
	await shoot(Vector3(1.05, 0.85, -0.05), Vector3(0, 0.72, -0.02), "held_side.png")
	await shoot(Vector3(0.55, 0.88, 0.95), Vector3(0, 0.72, 0.02), "held_front34.png")
	print("DONE")
	get_tree().quit()
