extends Node3D
## v1.0.29 BUILDING VIEWS (diagnostic): instances each slimmed
## Meshy building GLB on a neutral stage, prints its Godot-space
## AABB, and snaps it from the four horizontal faces (gzp = the
## +Z face, gzm = -Z, gxp = +X, gxm = -X) so the model's front
## can be matched against the reference photo.
## Run: xvfb-run -a godot --path . tests/BuildingViews.tscn

const OUT := "/tmp/views"
const MODELS: Array = [
	"school", "elementary_school", "library", "police_station", "fire_station",
	"diner", "bakery", "corner_store", "bistro", "corner_cafe", "corner_cafe_2",
	"apartment_block", "house_modern", "house_red", "house_blue", "house_beige",
	"house_white_tall", "house_blue_bungalow", "house_cream_balcony",
]
var cam: Camera3D
var stage: Node3D

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name)

func model_aabb(root: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D and n != root:
			var mi := n as MeshInstance3D
			var t: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
			var ab: AABB = t * mi.get_aabb()
			if first:
				out = ab
				first = false
			else:
				out = out.merge(ab)
	return out

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(360, 360))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.92, 0.92, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.95, 0.95)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	add_child(fill)
	stage = Node3D.new()
	add_child(stage)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var only: Array = OS.get_cmdline_user_args()
	for mname in MODELS:
		if not only.is_empty() and not only.has(mname):
			continue
		var ps: PackedScene = load("res://assets/models/buildings/" + mname + ".glb")
		if ps == null:
			print("VIEWS ", mname, " LOAD FAILED")
			continue
		var inst: Node3D = ps.instantiate()
		stage.add_child(inst)
		await get_tree().process_frame
		var ab := model_aabb(inst)
		print("VIEWS ", mname, " aabb_pos=", ab.position, " aabb_size=", ab.size)
		var ctr: Vector3 = ab.get_center()
		var d: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z)) * 1.55
		var views: Dictionary = {
			"gzp": ctr + Vector3(0, ab.size.y * 0.12, d),
			"gzm": ctr + Vector3(0, ab.size.y * 0.12, -d),
			"gxp": ctr + Vector3(d, ab.size.y * 0.12, 0),
			"gxm": ctr + Vector3(-d, ab.size.y * 0.12, 0),
		}
		for vname in views:
			cam.global_position = views[vname]
			cam.look_at(ctr, Vector3.UP)
			await wait_sec(0.25)
			await snap(mname + "_" + vname + ".png")
		inst.queue_free()
		await get_tree().process_frame
	print("VIEWS DONE")
	get_tree().quit()
