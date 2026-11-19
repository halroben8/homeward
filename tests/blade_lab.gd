extends Node3D
## v1.0.26 BLADE LAB: a minimal scene under the game's EXACT dusk
## rig (same sky, ambient, sun, tonemap, grass material) with
## three blade patches side by side — CTRL (the game's current
## _blade_mesh verbatim), FLIP (same mesh, winding reversed),
## UPN (same mesh, normals straight up) — plus _grass_tuft-style
## cones for reference. Discriminates the black-spike root cause
## without booting the whole town.
## Run: xvfb-run -a godot --path . tests/BladeLab.tscn
## Output: ~/workspace/homeward/screenshots_v1026_diag/lab_*.png

func blade_arrays() -> Array:
	# _blade_mesh() from main3d.gd, verbatim.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rb := 0.038
	var rt := 0.004
	var bh := 0.26
	var vi: int = 0
	for s in range(4):
		var a0 := float(s) * PI * 0.5 + PI * 0.25
		var a1 := float(s + 1) * PI * 0.5 + PI * 0.25
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		verts.append_array([d0 * rb, d1 * rb, d1 * rt + Vector3(0, bh, 0), d0 * rt + Vector3(0, bh, 0)])
		var n := (d0 + d1).normalized()
		var nn := Vector3(n.x, (rb - rt) / bh, n.z).normalized()
		for k in range(4):
			normals.append(nn)
			uvs.append(Vector2(0, 0))
		indices.append_array([vi, vi + 1, vi + 2, vi, vi + 2, vi + 3])
		vi += 4
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

func make_mesh(flip: bool, up_normals: bool) -> ArrayMesh:
	var arrs: Array = blade_arrays()
	if flip:
		var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX]
		var ni := PackedInt32Array()
		ni.resize(idx.size())
		for t in range(0, idx.size(), 3):
			ni[t] = idx[t]
			ni[t + 1] = idx[t + 2]
			ni[t + 2] = idx[t + 1]
		arrs[Mesh.ARRAY_INDEX] = ni
	if up_normals:
		var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
		var nn := PackedVector3Array()
		nn.resize(ns.size())
		for i in range(ns.size()):
			nn[i] = Vector3.UP
		arrs[Mesh.ARRAY_NORMAL] = nn
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return m

func make_mesh_steep() -> ArrayMesh:
	# STEEP: the cone normals leaned 62% toward straight up
	# (resulting |y| ~ 0.87 — still outward-leaning cone normals).
	var arrs: Array = blade_arrays()
	var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
	var nn := PackedVector3Array()
	nn.resize(ns.size())
	for i in range(ns.size()):
		nn[i] = (ns[i] * 0.38 + Vector3.UP * 0.62).normalized()
	arrs[Mesh.ARRAY_NORMAL] = nn
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return m

func make_patch(mesh: Mesh, mat: Material, centre: Vector3, seed_i: int) -> void:
	var prng := RandomNumberGenerator.new()
	prng.seed = 5000 + seed_i
	var palette: Array = [Color(0.34, 0.56, 0.22), Color(0.3, 0.5, 0.19), Color(0.39, 0.61, 0.25), Color(0.32, 0.53, 0.2)]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var n := 400
	mm.instance_count = n
	for j in range(n):
		var px: float = centre.x + prng.randf_range(-1.9, 1.9)
		var pz: float = centre.z + prng.randf_range(-1.3, 1.3)
		var basis := Basis(Vector3.UP, prng.randf_range(0.0, TAU)).scaled(Vector3.ONE * prng.randf_range(0.6, 1.1))
		mm.set_instance_transform(j, Transform3D(basis, Vector3(px, 0.02, pz)))
		mm.set_instance_color(j, palette[prng.randi_range(0, palette.size() - 1)])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func snap(cam: Camera3D, name: String) -> void:
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/homeward/screenshots_v1026_diag/" + name + ".png")
	print("BLADELAB SNAP ", name)

func _ready() -> void:
	# --- environment: _build_environment() values, verbatim ---
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.15, 0.25, 0.52)
	psm.sky_horizon_color = Color(1.0, 0.55, 0.27)
	psm.ground_bottom_color = Color(0.13, 0.12, 0.16)
	psm.ground_horizon_color = Color(0.72, 0.42, 0.26)
	psm.sun_angle_max = 25.0
	psm.sky_energy_multiplier = 1.0
	psm.ground_energy_multiplier = 0.7
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.90, 0.58, 0.38)
	env.fog_light_energy = 0.75
	env.fog_density = 0.0020
	env.fog_sky_affect = 0.35
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44, -35, 0)
	sun.light_color = Color(1.0, 0.60, 0.32)
	sun.light_energy = 1.30
	sun.shadow_enabled = true
	sun.shadow_blur = 0.4
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	# --- ground: the town grass material ---
	var gtex: Texture2D = load("res://assets/textures/grass.png")
	var gnrm: Texture2D = load("res://assets/textures/grass_normal.png")
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = gtex
	gmat.albedo_color = Color(0.72, 0.84, 0.64)
	gmat.roughness = 0.94
	gmat.uv1_scale = Vector3(12, 8, 1)
	gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	gmat.normal_enabled = true
	gmat.normal_texture = gnrm
	gmat.normal_scale = 1.1
	var ground := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(60, 0.5, 40)
	ground.mesh = gb
	ground.position = Vector3(0, -0.25, 0)
	ground.material_override = gmat
	add_child(ground)
	# --- a pale "sidewalk" slab strip in front of the patches ---
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.82, 0.80, 0.82)
	smat.roughness = 0.95
	var slab := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(16, 0.06, 2.6)
	slab.mesh = sb
	slab.position = Vector3(0, 0.03, 3.4)
	slab.material_override = smat
	add_child(slab)
	# --- the three blade patches + tuft reference cones ---
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color.WHITE
	bmat.roughness = 1.0
	bmat.vertex_color_use_as_albedo = true
	make_patch(make_mesh(false, false), bmat, Vector3(-4.2, 0, 0), 1) # CTRL (left)
	make_patch(make_mesh_steep(), bmat, Vector3(0, 0, 0), 2) # STEEP (centre)
	make_patch(make_mesh(false, true), bmat, Vector3(4.2, 0, 0), 3) # UPN (right)
	var tuft_cols: Array = [Color(0.3, 0.58, 0.28), Color(0.4, 0.66, 0.32), Color(0.34, 0.62, 0.3)]
	for ti in range(7):
		for bi in range(3):
			var cm := CylinderMesh.new()
			cm.top_radius = 0.004
			cm.bottom_radius = 0.045
			cm.height = 0.44
			cm.radial_segments = 18
			var tmi := MeshInstance3D.new()
			tmi.mesh = cm
			var tm := StandardMaterial3D.new()
			tm.albedo_color = tuft_cols[(bi + ti) % 3]
			tm.roughness = 0.9
			tmi.material_override = tm
			tmi.position = Vector3(-9.5 + float(ti) * 0.55 + (float(bi) - 1.0) * 0.09, 0.32, (float((bi + ti) % 3) - 1.0) * 0.08)
			tmi.rotation_degrees = Vector3((float(bi) - 1.0) * 9.0, 0, (float((bi * 2 + ti) % 3) - 1.0) * 9.0)
			add_child(tmi)
	# --- cameras: player height, three compass views ---
	var cam_a := Camera3D.new()
	add_child(cam_a)
	cam_a.global_position = Vector3(0, 1.25, 7.2)
	cam_a.look_at(Vector3(0, 0.15, 0), Vector3.UP)
	await snap(cam_a, "lab_from_south")
	var cam_b := Camera3D.new()
	add_child(cam_b)
	cam_b.global_position = Vector3(0, 1.25, -7.2)
	cam_b.look_at(Vector3(0, 0.15, 0), Vector3.UP)
	await snap(cam_b, "lab_from_north")
	var cam_c := Camera3D.new()
	add_child(cam_c)
	cam_c.global_position = Vector3(7.2, 1.25, 0)
	cam_c.look_at(Vector3(0, 0.15, 0), Vector3.UP)
	await snap(cam_c, "lab_from_east")
	# close-up on the STEEP patch, low, like the cat's own view
	var cam_d := Camera3D.new()
	add_child(cam_d)
	cam_d.global_position = Vector3(0, 0.5, 2.2)
	cam_d.look_at(Vector3(0, 0.12, 0), Vector3.UP)
	await snap(cam_d, "lab_steep_closeup")
	# and the same close-up from the anti-sun (north) side
	var cam_e := Camera3D.new()
	add_child(cam_e)
	cam_e.global_position = Vector3(0, 0.5, -2.2)
	cam_e.look_at(Vector3(0, 0.12, 0), Vector3.UP)
	await snap(cam_e, "lab_steep_closeup_north")
	print("BLADELAB DONE")
	get_tree().quit()
