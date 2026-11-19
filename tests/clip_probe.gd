extends Node3D
## CLIP PROBE — v1.0.13 wall/object clipping fix verification.
## Drives the REAL player cat (scripts/cat.gd, driven via touch_dir
## exactly as the game drives it) at a house-sized wall, a door-post
## and a gap, and measures how far the cat's VISUAL body (real global
## AABBs of the built model) penetrates the obstacle.
##   torso = body + head + ears + legs (the tail is excluded: it is
##           thin, carried up/curved, and its trailing tip kissing a
##           wall is cosmetic — reported separately as model pen)
##   godot --headless --path . tests/ClipProbe.tscn
## Prints CLIP| lines the runner greps.

const WALL_FACE := -2.4 # front face of the wall box (8.2 x 3.7 x 7.2 @ z=-6)

var cat: Node = null
var post: StaticBody3D = null
var gap_l: StaticBody3D = null
var gap_r: StaticBody3D = null

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

func _torso_aabb() -> AABB:
	var out := _aabb_of(cat.get("body_node"))
	out = out.merge(_aabb_of(cat.get("head_node")))
	out = out.merge(_aabb_of(cat.get("ear_l")))
	out = out.merge(_aabb_of(cat.get("ear_r")))
	for lp in cat.get("leg_pivots"):
		out = out.merge(_aabb_of(lp))
	return out

func _static_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)
	return sb

func _reset_cat(pos: Vector3, yaw: float) -> void:
	cat.set("touch_dir", Vector2.ZERO)
	cat.set("velocity", Vector3.ZERO)
	(cat as Node3D).global_position = pos
	(cat as Node3D).rotation = Vector3(0, yaw, 0)

func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame

# Drive with a fixed touch_dir for N physics frames, tracking the max
# penetration of the torso / whole-model AABBs past the wall face.
func _drive_wall(dir: Vector2, frames: int) -> Vector2:
	var max_torso := 0.0
	var max_model := 0.0
	cat.set("touch_dir", dir)
	for i in range(frames):
		await get_tree().physics_frame
		var ta := _torso_aabb()
		if ta.position.x + ta.size.x > -4.1 and ta.position.x < 4.1:
			max_torso = maxf(max_torso, WALL_FACE - ta.position.z)
		var ma := _aabb_of(cat.get("model"))
		if ma.position.x + ma.size.x > -4.1 and ma.position.x < 4.1:
			max_model = maxf(max_model, WALL_FACE - ma.position.z)
	cat.set("touch_dir", Vector2.ZERO)
	return Vector2(max_torso, max_model)

func _ready() -> void:
	# Ground + a house wall (identical size/placement style to
	# main3d._build_house's solid walls box) + a door-frame post.
	_static_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	_static_box(Vector3(0, 2.0, -6.0), Vector3(8.2, 3.7, 7.2))
	post = _static_box(Vector3(6, 1.35, 0), Vector3(0.18, 2.7, 0.18))
	gap_l = _static_box(Vector3(9.0, 1.35, 0), Vector3(1.0, 2.7, 0.3))
	gap_r = _static_box(Vector3(11.0, 1.35, 0), Vector3(1.0, 2.7, 0.3))

	var CatScript: GDScript = load("res://scripts/cat.gd")
	cat = CatScript.new()
	add_child(cat)
	cat.set("frozen", false)
	await _settle(20)

	# --- Case 1: HEAD-ON into the wall face ---
	_reset_cat(Vector3(0, 0, 1.5), 0.0)
	await _settle(15)
	var r1 := await _drive_wall(Vector2(0, -1), 360)
	print("CLIP| head_on torso_pen_max=", snappedf(r1.x, 0.001), " model_pen_max=", snappedf(r1.y, 0.001),
		" centre_dist_to_face=", snappedf((cat as Node3D).global_position.z - WALL_FACE, 0.001))

	# --- Case 2: TURN AT THE WALL (spawned parallel, disc-distance
	# from the wall, then commanded straight at it: the body sweeps) ---
	_reset_cat(Vector3(0, 0, WALL_FACE + 0.19), PI / 2.0)
	await _settle(15)
	var r2 := await _drive_wall(Vector2(0, -1), 360)
	print("CLIP| turn_at_wall torso_pen_max=", snappedf(r2.x, 0.001), " model_pen_max=", snappedf(r2.y, 0.001))

	# --- Case 3: HUG THE WALL walking parallel, then turn into it ---
	_reset_cat(Vector3(-2.0, 0, WALL_FACE + 0.19), PI / 2.0)
	await _settle(15)
	var r3a := await _drive_wall(Vector2(1, 0), 100)
	var r3b := await _drive_wall(Vector2(0, -1), 240)
	print("CLIP| hug_and_turn torso_pen_max=", snappedf(maxf(r3a.x, r3b.x), 0.001), " model_pen_max=", snappedf(maxf(r3a.y, r3b.y), 0.001))

	# --- Case 4: POST head-on (door-frame post, 0.18 wide) ---
	_reset_cat(Vector3(6, 0, 3.0), 0.0)
	await _settle(15)
	var post_aabb := AABB(Vector3(6, 0, 0) - Vector3(0.09, 0, 0.09), Vector3(0.18, 2.7, 0.18))
	var max_post := 0.0
	cat.set("touch_dir", Vector2(0, -1))
	for i in range(360):
		await get_tree().physics_frame
		var ta2 := _torso_aabb()
		var ox: float = minf(ta2.position.x + ta2.size.x, post_aabb.position.x + post_aabb.size.x) - maxf(ta2.position.x, post_aabb.position.x)
		var oz: float = minf(ta2.position.z + ta2.size.z, post_aabb.position.z + post_aabb.size.z) - maxf(ta2.position.z, post_aabb.position.z)
		if ox > 0.05 and oz > 0.0:
			max_post = maxf(max_post, oz)
	cat.set("touch_dir", Vector2.ZERO)
	print("CLIP| post torso_overlap_max=", snappedf(max_post, 0.001))

	# --- Case 5/6: GAP FIT (footprint width must be unchanged) ---
	for gap in [0.5, 0.4]:
		gap_l.position.x = 10.0 - (gap / 2.0 + 0.5)
		gap_r.position.x = 10.0 + (gap / 2.0 + 0.5)
		_reset_cat(Vector3(10, 0, 3.0), 0.0)
		await _settle(15)
		cat.set("touch_dir", Vector2(0, -1))
		for i in range(480):
			await get_tree().physics_frame
		cat.set("touch_dir", Vector2.ZERO)
		var endz: float = (cat as Node3D).global_position.z
		print("CLIP| gap_", gap, " end_z=", snappedf(endz, 0.001), " through=", endz < -1.5)

	print("CLIP DONE")
	get_tree().quit(0)
