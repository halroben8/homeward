extends Node3D
## v1.0.22 NOSE PROBE (diagnostic, not part of the suite): renders
## every vehicle GLB UNROTATED from the side (camera on +Z, so
## screen-right = +X), with a RED block beyond the +X end and a
## GREEN block beyond the -X end. Reading the PNG tells us which
## way each model's nose actually points in Godot space.

const CARS := {
	"car_sedan": "res://assets/models/car_sedan.glb",
	"car_compact": "res://assets/models/car_compact.glb",
	"car_sports": "res://assets/models/car_sports.glb",
	"truck_pickup": "res://assets/models/truck_pickup.glb",
	"car_police": "res://assets/models/car_police.glb",
	"van_delivery": "res://assets/models/van_delivery.glb",
	"van_animal_control": "res://assets/models/van_animal_control.glb",
	"suv": "res://assets/models/suv.glb",
}
const OUT := "/tmp/noseprobe/"

func _dump(n: Node, depth: int) -> void:
	var t := ""
	if n is Node3D:
		var n3 := n as Node3D
		t = " pos=" + str(n3.position) + " rotdeg=" + str(Vector3(rad_to_deg(n3.rotation.x), rad_to_deg(n3.rotation.y), rad_to_deg(n3.rotation.z))) + " scale=" + str(n3.scale)
	print("TREE|", "  ".repeat(depth), n.get_class(), " '", n.name, "'", t)
	for ch in n.get_children():
		_dump(ch, depth + 1)

func _aabb_of(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				var a: AABB = mi.global_transform * mi.get_aabb()
				if first:
					out = a
					first = false
				else:
					out = out.merge(a)
		for ch in cur.get_children():
			stack.append(ch)
	return out

func _marker(pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 1.8, 0.5)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.5
	mi.material_override = m
	mi.position = pos
	return mi

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(900, 420))
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.15, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.95, 1.0)
	env.ambient_light_energy = 1.0
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.8
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.position = Vector3(0, 1.25, 10.5)
	add_child(cam)
	cam.look_at(Vector3(0, 0.7, 0), Vector3.UP)
	cam.current = true
	add_child(_marker(Vector3(3.4, 0.9, 0), Color(1, 0.1, 0.1))) # RED = +X end
	add_child(_marker(Vector3(-3.4, 0.9, 0), Color(0.1, 1, 0.2))) # GREEN = -X end
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(9, 0.05, 3)
	ground.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.3, 0.3, 0.34)
	ground.material_override = gmat
	ground.position = Vector3(0, -0.03, 0)
	add_child(ground)
	await get_tree().process_frame
	for cname in CARS:
		print("==== ", cname, " ====")
		var inst: Node3D = (load(CARS[cname]) as PackedScene).instantiate()
		add_child(inst)
		_dump(inst, 0)
		await get_tree().process_frame
		await get_tree().process_frame
		var a := _aabb_of(inst)
		print("AABB| ", cname, " min=", a.position, " max=", a.end, " size=", a.size)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(OUT + cname + ".png")
		print("saved ", cname)
		inst.queue_free()
		await get_tree().process_frame
	get_tree().quit()
