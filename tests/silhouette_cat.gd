extends Node3D
## HOMEWARD v12 SCULPT — silhouette capture of the player cat ONLY.
## Instantiates scripts/cat.gd standalone, freezes its animation,
## poses it at rest, paints every mesh flat black (unshaded) on a
## plain pale background, and shoots FRONT and SIDE. Run under Xvfb:
##   xvfb-run -a godot --path . tests/SilhouetteCat.tscn -- old
##   xvfb-run -a godot --path . tests/SilhouetteCat.tscn -- new
## Output: screenshots_cat_v12/silhouette/<arg>_front.png / _side.png

const BASE := "/home/hatch/workspace/homeward/screenshots_cat_v12/silhouette"
var tag := "old"
var cat: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(cam: Camera3D, name: String) -> void:
	cam.current = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(BASE + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func blacken(n: Node) -> void:
	if n is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.05, 0.05, 0.08)
		(n as MeshInstance3D).material_override = m
	for ch in n.get_children():
		blacken(ch)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	DirAccess.make_dir_recursive_absolute(BASE)
	DisplayServer.window_set_size(Vector2i(1100, 1000))
	# plain pale backdrop
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.94, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	# the cat, standalone
	var CatScript: GDScript = load("res://scripts/cat.gd")
	cat = CatScript.new()
	add_child(cat)
	# freeze IMMEDIATELY: there is no floor in this scene, so even a
	# few physics frames of gravity would drop the cat out of frame
	cat.set_physics_process(false)
	cat.set("velocity", Vector3.ZERO)
	cat.global_position = Vector3.ZERO
	await wait_sec(0.6)
	blacken(cat)
	var model: Node3D = cat.get("model")
	model.rotation = Vector3.ZERO
	var body: Node3D = cat.get("body_node")
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	var head: Node3D = cat.get("head_node")
	head.rotation = Vector3.ZERO
	head.position = cat.get("head_base_pos")
	for lp in cat.get("leg_pivots"):
		(lp as Node3D).rotation = Vector3.ZERO
	var ti := 0
	for tp in cat.get("tail_pivots"):
		(tp as Node3D).rotation = Vector3(-0.33 + float(ti) * 0.06, 0, 0)
		ti += 1
	(cat.get("ear_l") as Node3D).rotation = Vector3(0, 0, 0.12)
	(cat.get("ear_r") as Node3D).rotation = Vector3(0, 0, -0.12)
	# cameras
	var cam_f := Camera3D.new()
	cam_f.fov = 38.0
	add_child(cam_f)
	cam_f.global_position = Vector3(0, 0.74, 3.45)
	cam_f.look_at(Vector3(0, 0.62, 0.1), Vector3.UP)
	var cam_s := Camera3D.new()
	cam_s.fov = 38.0
	add_child(cam_s)
	cam_s.global_position = Vector3(3.45, 0.74, 0.05)
	cam_s.look_at(Vector3(0, 0.60, 0.0), Vector3.UP)
	await snap(cam_f, tag + "_front.png")
	await snap(cam_s, tag + "_side.png")
	print("SILHOUETTE DONE -> ", tag)
	get_tree().quit(0)
