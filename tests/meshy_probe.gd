extends Node3D
## MESHY PROBE (temp, v1.0.14 cat swap): measures the legacy cat's
## model-space AABB and dumps the imported GLB's tree + skeleton.

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

func _dump(n: Node, depth: int) -> void:
	var t := ""
	if n is Node3D:
		var n3 := n as Node3D
		t = " pos=" + str(n3.position) + " rotdeg=" + str(Vector3(rad_to_deg(n3.rotation.x), rad_to_deg(n3.rotation.y), rad_to_deg(n3.rotation.z))) + " scale=" + str(n3.scale)
	print("TREE|", "  ".repeat(depth), n.get_class(), " '", n.name, "'", t)
	for ch in n.get_children():
		_dump(ch, depth + 1)

func _ready() -> void:
	# --- legacy cat measurements (model space = global / VISUAL_SCALE, cat at origin) ---
	var CatScript: GDScript = load("res://scripts/cat.gd")
	var cat: Node = CatScript.new()
	add_child(cat)
	cat.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var model: Node3D = cat.get("model")
	var la := _aabb_of(model)
	print("LEGACY| global AABB min=", la.position, " max=", la.end, " size=", la.size)
	print("LEGACY| model-space size=", la.size / 1.25, " min=", la.position / 1.25)
	# body-only and head-only for proportion anchors
	var body_a := _aabb_of(cat.get("body_node"))
	print("LEGACY| body global size=", body_a.size, " min=", body_a.position, " max=", body_a.end)
	cat.queue_free()
	await get_tree().process_frame
	# --- GLB dump ---
	var ps: PackedScene = load("res://assets/models/zander.glb")
	print("GLB| loaded: ", ps != null)
	var inst: Node = ps.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	_dump(inst, 0)
	var ga := _aabb_of(inst)
	print("GLB| global AABB min=", ga.position, " max=", ga.end, " size=", ga.size)
	var stack: Array = [inst]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Skeleton3D:
			var sk := cur as Skeleton3D
			print("SKEL| bones=", sk.get_bone_count())
			for i in range(sk.get_bone_count()):
				var gr: Transform3D = sk.get_bone_global_rest(i)
				print("BONE| ", i, " '", sk.get_bone_name(i), "' parent=", sk.get_bone_parent(i), " rest_origin=", gr.origin)
		for ch in cur.get_children():
			stack.append(ch)
	get_tree().quit()
