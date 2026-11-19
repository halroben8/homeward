extends Node3D
## FEASIBILITY PROOF (2026-11-18) — Blender -> glTF -> Godot pipeline.
## NOT part of the suite; wires nothing into the game. Loads a
## Blender-made skinned .glb (test_bean.glb, made by a Blender Python
## script), verifies the imported Skeleton3D, bends a bone in-engine,
## and snaps rest + bent stills.
## Output: ~/workspace/homeward/screenshots_feasibility/
## Run: xvfb-run -a godot --path . tests/feasibility_import/ImportProof.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_feasibility"
const GLB := "res://tests/feasibility_import/test_bean.glb"

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null

func _collect_meshes(n: Node, acc: Array) -> void:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_collect_meshes(c, acc)

func _snap(fname: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + fname)
	print("PROOF SHOT: ", fname, " ", img.get_size())

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.25, 0.27, 0.3)
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	cam.position = Vector3(2.6, 1.6, 3.4)
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	cam.current = true

	var packed: PackedScene = load(GLB)
	if packed == null:
		print("PROOF FAIL: glb load returned null")
		get_tree().quit(1)
		return
	var bean := packed.instantiate()
	add_child(bean)
	print("PROOF: instanced root '", bean.name, "'")

	var meshes: Array = []
	_collect_meshes(bean, meshes)
	for m in meshes:
		var mi := m as MeshInstance3D
		print("PROOF MESH: ", mi.name, " surfaces=", mi.mesh.get_surface_count(),
			" skin_attached=", (mi.skin != null))

	var skel := _find_skeleton(bean)
	if skel == null:
		print("PROOF FAIL: no Skeleton3D in import")
		get_tree().quit(1)
		return
	print("PROOF SKELETON: bones=", skel.get_bone_count())
	for i in range(skel.get_bone_count()):
		print("PROOF BONE ", i, ": ", skel.get_bone_name(i),
			" parent=", skel.get_bone_parent(i))

	await _snap("bean_rest.png")

	# Diagnostic: rotate the ROOT bone — the whole skinned bean must
	# swing rigidly if skinning is live. Read the pose back to confirm.
	var root_bone := skel.find_bone("Spine")
	if root_bone >= 0:
		skel.set_bone_pose_rotation(root_bone, Quaternion(Vector3.RIGHT, deg_to_rad(50.0)))
		print("PROOF ROOT POSE READBACK: ", skel.get_bone_pose_rotation(root_bone))
		await _snap("bean_root_bend.png")
		skel.set_bone_pose_rotation(root_bone, Quaternion.IDENTITY)
		await get_tree().process_frame

	var tip := skel.find_bone("SpineTip")
	if tip >= 0:
		# glTF bone-local axes are not documented per-export; try each
		# axis at a large angle and keep all three stills — the bend
		# axis shows a clear lean, the twist axis barely changes.
		var axes := {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}
		for key in axes:
			skel.set_bone_pose_rotation(tip, Quaternion(axes[key], deg_to_rad(50.0)))
			await _snap("bean_bend_" + key + ".png")
			skel.set_bone_pose_rotation(tip, Quaternion.IDENTITY)
			await get_tree().process_frame
		print("PROOF: posed SpineTip 50deg about each local axis in-engine")
	await _snap("bean_bent.png")
	print("PROOF DONE")
	get_tree().quit(0)
