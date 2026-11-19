extends Node
## TEMPORARY v1.0.9 post-splash crash audit (data integrity).
## Boots Main, waits for the streamed build, enters play for a few
## seconds (so NPCs/cat/physics have all moved), then walks EVERY
## node in the built world validating render + physics data:
##   - ArrayMesh surfaces: finite vertices/normals, sane counts,
##     indices in range and a multiple of 3.
##   - MultiMesh: instance transforms finite.
##   - CollisionShape3D: shape sizes finite and positive.
##   - Node3D: global transform finite.
## Prints MA: summary lines; problems listed with node paths.

var main: Node = null
var counts := {"mesh_instances": 0, "surfaces": 0, "verts": 0, "multimesh": 0, "mm_instances": 0, "shapes": 0, "node3d": 0}
var problem_count: int = 0

func _bad(kind: String, path: String, detail: String) -> void:
	problem_count += 1
	if problem_count <= 60:
		print("MA: PROBLEM ", kind, " @ ", path, " :: ", detail)

func _finite_v3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

func _audit_mesh(mi: MeshInstance3D, path: String) -> void:
	counts["mesh_instances"] += 1
	var mesh := mi.mesh
	if mesh == null:
		return
	if not (mesh is ArrayMesh):
		return
	var am := mesh as ArrayMesh
	for s in range(am.get_surface_count()):
		counts["surfaces"] += 1
		var arrays: Array = am.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		counts["verts"] += verts.size()
		if verts.size() == 0:
			_bad("mesh", path, "surface %d has ZERO vertices" % s)
			continue
		for v in verts:
			if not _finite_v3(v):
				_bad("mesh", path, "surface %d has non-finite vertex %s" % [s, str(v)])
				break
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.size() == verts.size():
			for n in normals:
				if not _finite_v3(n):
					_bad("mesh", path, "surface %d has non-finite normal %s" % [s, str(n)])
					break
				if n.length_squared() < 0.25:
					_bad("mesh", path, "surface %d has near-zero normal %s" % [s, str(n)])
					break
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.size() > 0:
			if idx.size() % 3 != 0:
				_bad("mesh", path, "surface %d index count %d not a multiple of 3" % [s, idx.size()])
			for i in idx:
				if i < 0 or i >= verts.size():
					_bad("mesh", path, "surface %d index %d out of range (verts=%d)" % [s, i, verts.size()])
					break
		var aabb: AABB = am.surface_get_aabb(s)
		if not _finite_v3(aabb.position) or not _finite_v3(aabb.size):
			_bad("mesh", path, "surface %d AABB non-finite %s" % [s, str(aabb)])

func _audit_multimesh(mmi: MultiMeshInstance3D, path: String) -> void:
	counts["multimesh"] += 1
	var mm := mmi.multimesh
	if mm == null:
		return
	counts["mm_instances"] += mm.instance_count
	for i in range(mm.instance_count):
		var t := mm.get_instance_transform(i)
		if not _finite_v3(t.origin) or not _finite_v3(t.basis.x) or not _finite_v3(t.basis.y) or not _finite_v3(t.basis.z):
			_bad("multimesh", path, "instance %d transform non-finite origin=%s" % [i, str(t.origin)])
			break

func _audit_shape(cs: CollisionShape3D, path: String) -> void:
	counts["shapes"] += 1
	var sh := cs.shape
	if sh == null:
		_bad("shape", path, "null shape")
		return
	if sh is BoxShape3D:
		var sz := (sh as BoxShape3D).size
		if not _finite_v3(sz) or sz.x <= 0.0 or sz.y <= 0.0 or sz.z <= 0.0:
			_bad("shape", path, "BoxShape size invalid %s" % str(sz))
	elif sh is SphereShape3D:
		var r := (sh as SphereShape3D).radius
		if not is_finite(r) or r <= 0.0:
			_bad("shape", path, "SphereShape radius invalid %f" % r)
	elif sh is CapsuleShape3D:
		var r2 := (sh as CapsuleShape3D).radius
		var h := (sh as CapsuleShape3D).height
		if not is_finite(r2) or not is_finite(h) or r2 <= 0.0 or h <= 0.0:
			_bad("shape", path, "CapsuleShape invalid r=%f h=%f" % [r2, h])
	elif sh is CylinderShape3D:
		var r3 := (sh as CylinderShape3D).radius
		var h3 := (sh as CylinderShape3D).height
		if not is_finite(r3) or not is_finite(h3) or r3 <= 0.0 or h3 <= 0.0:
			_bad("shape", path, "CylinderShape invalid r=%f h=%f" % [r3, h3])

func _walk(node: Node, path: String) -> void:
	var here := path + "/" + node.name
	if node is Node3D:
		counts["node3d"] += 1
		var gt := (node as Node3D).global_transform
		if not _finite_v3(gt.origin) or not _finite_v3(gt.basis.x) or not _finite_v3(gt.basis.y) or not _finite_v3(gt.basis.z):
			_bad("transform", here, "global transform non-finite origin=%s" % str(gt.origin))
	if node is MeshInstance3D:
		_audit_mesh(node as MeshInstance3D, here)
	if node is MultiMeshInstance3D:
		_audit_multimesh(node as MultiMeshInstance3D, here)
	if node is CollisionShape3D:
		_audit_shape(node as CollisionShape3D, here)
	for child in node.get_children():
		_walk(child, here)

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 600:
		await get_tree().process_frame
		guard += 1
	print("MA: build_complete=", bool(main.get("build_complete")), " guard_frames=", guard)
	# The phone path WITHOUT an early tap: dismiss after build, title,
	# then start play and let everything run a few seconds.
	main.call("dismiss_splash")
	await get_tree().create_timer(1.0).timeout
	print("MA: state after dismiss=", str(main.get("state")))
	main.call("start_game")
	await get_tree().create_timer(3.0).timeout
	print("MA: state after start=", str(main.get("state")), " player_pos=", str((main.get("player") as Node3D).global_position))
	_walk(main, "")
	print("MA: counts=", counts)
	print("MA: problem_count=", problem_count)
	print("MA: DONE")
	get_tree().quit()
