extends Node3D
## v1.0.22 TOWN CAT PROBE: instances each new Meshy town-cat GLB
## on a neutral stage next to a 0.5 m reference cube, prints the
## skeleton's bone global-rest positions (world space) so the
## runtime leg classifier in town_cat.gd can be calibrated, and
## takes side / front stills to verify each model is a single
## clean cat and to read its facing + scale.
## Run: xvfb-run -a godot --path . tests/TownCatProbe.tscn

const CATS: Array = [
	"town_tabby", "black_cat", "white_cat", "calico_cat",
	"gray_tabby", "siamese_cat", "tortoiseshell_cat", "russian_blue_cat",
]
const OUT := "/home/hatch/workspace/homeward/screenshots_v1022/cats"
var cam: Camera3D

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name)

func shoot(pos: Vector3, look: Vector3, name: String) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await wait_sec(0.25)
	await snap(name)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1100, 800))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.68, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.95, 0.95)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_energy = 1.2
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
	# 0.5 m reference cube at x = +0.85
	var ref := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.5, 0.5)
	ref.mesh = bm
	ref.position = Vector3(0.85, 0.25, 0)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.9, 0.3, 0.3)
	ref.material_override = rm
	add_child(ref)
	cam = Camera3D.new()
	cam.fov = 42.0
	add_child(cam)

	for cname in CATS:
		var ps: PackedScene = load("res://assets/models/" + cname + ".glb")
		if ps == null:
			print("CATPROBE| ", cname, " LOAD FAILED")
			continue
		var inst: Node = ps.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		var skel: Skeleton3D = null
		var stack: Array = [inst]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur is Skeleton3D:
				skel = cur as Skeleton3D
			for ch in cur.get_children():
				stack.append(ch)
		if skel != null:
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := Vector3(-1e9, -1e9, -1e9)
			for bi in range(skel.get_bone_count()):
				var wp: Vector3 = skel.to_global(skel.get_bone_global_rest(bi).origin)
				lo = Vector3(minf(lo.x, wp.x), minf(lo.y, wp.y), minf(lo.z, wp.z))
				hi = Vector3(maxf(hi.x, wp.x), maxf(hi.y, wp.y), maxf(hi.z, wp.z))
				print("CATPROBE| ", cname, " bone ", skel.get_bone_name(bi), " parent=", skel.get_bone_parent(bi), " world=", wp)
			print("CATPROBE| ", cname, " bone-extents size=", hi - lo, " min=", lo, " max=", hi)
		else:
			print("CATPROBE| ", cname, " NO SKELETON")
		await shoot(Vector3(1.6, 0.55, 0.0), Vector3(0, 0.3, 0), cname + "_side.png")
		await shoot(Vector3(0.0, 0.55, 1.6), Vector3(0, 0.3, 0), cname + "_front.png")
		await shoot(Vector3(1.15, 0.6, 1.15), Vector3(0, 0.28, 0), cname + "_34.png")
		inst.queue_free()
		await get_tree().process_frame
	print("DONE")
	get_tree().quit()
