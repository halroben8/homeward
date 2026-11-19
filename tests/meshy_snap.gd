extends Node3D
## MESHY SWAP SNAP (v1.0.14): instances the real player cat on a
## neutral stage and drives cat._animate by hand (physics off) to
## proof the Meshy ghost rig: idle stand, walk stride, sit.
## Run: xvfb-run -a godot --path . tests/MeshySnap.tscn

const CatScript: GDScript = preload("res://scripts/cat.gd")
const OUT := "/home/hatch/workspace/homeward/screenshots_meshy_swap"
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

	cat = CharacterBody3D.new()
	cat.set_script(CatScript)
	add_child(cat)
	cat.set_physics_process(false)
	print("MESHY| skel=", cat.get("meshy_skel") != null, " bones=", (cat.get("meshy_bone") as Dictionary).size(), " tail=", (cat.get("meshy_tail") as Array).size())
	print("MESHY| collar visible=", bool(cat.call("is_collar_visible")), " tag=", str(cat.call("get_tag_label").text) if cat.call("get_tag_label") != null else "none")

	cam = Camera3D.new()
	cam.fov = 42.0
	add_child(cam)

	# idle stand (let the idle pose settle)
	await drive(1.2, 0.0)
	await shoot(Vector3(0.55, 0.36, 0.95), Vector3(0, 0.24, 0.02), "01_idle_front34.png")
	await shoot(Vector3(1.05, 0.32, -0.05), Vector3(0, 0.24, -0.02), "02_idle_side.png")
	await shoot(Vector3(0.0, 0.34, 1.05), Vector3(0, 0.26, 0.05), "03_idle_front.png")
	# collar close-ups (strap on the new neck, tag readable)
	await shoot(Vector3(0.16, 0.44, 0.66), Vector3(0, 0.28, 0.16), "08_collar_front.png")
	await shoot(Vector3(0.66, 0.42, 0.22), Vector3(0, 0.27, 0.15), "09_collar_side.png")
	# walk stride — drive until the stride is near full swing so
	# the still actually proves the leg swing
	var guard := 0
	while absf(sin(float(cat.get("walk_phase")))) < 0.88 and guard < 40:
		await drive(0.08, 5.6)
		guard += 1
	await shoot(Vector3(1.05, 0.32, -0.05), Vector3(0, 0.24, -0.02), "04_walk_side.png")
	await shoot(Vector3(0.55, 0.36, 0.95), Vector3(0, 0.24, 0.02), "05_walk_front34.png")
	# sit (the idle-action machinery is gated on NOT frozen)
	cat.set("frozen", false)
	cat.set("idle_allowed", true)
	cat.call("debug_set_idle_action", "sit")
	await drive(2.2, 0.0)
	await shoot(Vector3(0.55, 0.36, 0.95), Vector3(0, 0.24, 0.02), "06_sit_front34.png")
	await shoot(Vector3(1.05, 0.32, -0.05), Vector3(0, 0.24, -0.02), "07_sit_side.png")
	print("DONE")
	get_tree().quit()
