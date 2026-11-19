extends CharacterBody3D
## v1.0.22: the TOWN CATS — Michael's eight Meshy city cats
## (town tabby, black, white fluffy, calico, gray tabby, siamese,
## tortoiseshell, russian blue) wandering the town as ambient
## animals. The Meshy quadruped GLBs arrive RIGGED but with NO
## animation clips, so the trot is procedural: at spawn the leg
## bones are classified from their rest-pose positions (four
## chains off the skeleton's hub bone), diagonal pairs swing
## together like a real cat's trot, and the body bobs on its
## wrapper. Pure ambience — no interaction, no scoring; the
## player cat's systems never see them.
##
## Fit is measured, not assumed: bone extents in wrapper space
## set the scale (target bone span below) and ground the paws.

const TARGET_BONE_H := 0.46 # metres, paw-bottom to head-top over the bones
const WALK_SPEED := 1.15
const TURN_RATE := 3.2
const SWING_AMP := 0.5 # rad, upper-leg swing at a trot
const STRIDE_FREQ := 5.4 # phase rad/s per (m/s)

var model_scene: PackedScene = null
var player_ref: Node3D = null
var home := Vector3.ZERO
var wander_radius := 13.0

var _wrap: Node3D = null
var _inst: Node = null
var _skel: Skeleton3D = null
var _legs: Array = [] # {chain: Array[int], phase: float}
var _rest: Dictionary = {} # bone -> global rest (skeleton space)
var _local_rest: Dictionary = {} # bone -> parent-relative rest
var _target := Vector3.ZERO
var _walking := false
var _state_t := 1.0
var _phase := 0.0
var _stuck_t := 0.0
var _face_yaw_off := 0.0 # model forward vs root +Z, measured at spawn
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.16
	cap.height = 0.46
	cs.shape = cap
	cs.position = Vector3(0, 0.23, 0)
	add_child(cs)
	_wrap = Node3D.new()
	_wrap.name = "FitWrap"
	add_child(_wrap)
	if model_scene == null:
		return
	_inst = model_scene.instantiate()
	_wrap.add_child(_inst)
	var stack: Array = [_inst]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Skeleton3D:
			_skel = cur as Skeleton3D
		for ch in cur.get_children():
			stack.append(ch)
	if _skel == null:
		return
	_fit_and_classify()
	_pick_next(true)

func _fit_and_classify() -> void:
	# Bone positions in WRAPPER space (wrap still at identity).
	var inv: Transform3D = _wrap.global_transform.affine_inverse()
	var pos: Dictionary = {} # bone -> wrapper-space rest position
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	var children: Dictionary = {} # bone -> Array of child bones
	for bi in range(_skel.get_bone_count()):
		var gr: Transform3D = _skel.get_bone_global_rest(bi)
		_rest[bi] = gr
		var bp: int = _skel.get_bone_parent(bi)
		_local_rest[bi] = (_skel.get_bone_global_rest(bp).affine_inverse() * gr) if bp >= 0 else gr
		if bp >= 0:
			if not children.has(bp):
				children[bp] = []
			(children[bp] as Array).append(bi)
		var wp: Vector3 = inv * _skel.to_global(gr.origin)
		pos[bi] = wp
		lo = Vector3(minf(lo.x, wp.x), minf(lo.y, wp.y), minf(lo.z, wp.z))
		hi = Vector3(maxf(hi.x, wp.x), maxf(hi.y, wp.y), maxf(hi.z, wp.z))
	var h: float = maxf(hi.y - lo.y, 0.05)
	var s: float = TARGET_BONE_H / h
	_wrap.scale = Vector3.ONE * s
	_wrap.position = Vector3(-(lo.x + hi.x) * 0.5 * s, -lo.y * s, -(lo.z + hi.z) * 0.5 * s)
	# LEGS, topology-free (the batch has two rig shapes: a generic
	# joint rig whose legs hang off one hub bone, and a named rig
	# whose front legs hang off clavicles and rear legs off the
	# hips): a leg is the chain from a ground-level LEAF bone up to
	# the first branching ancestor. The tail fails the lateral test
	# (its chain never leaves the body's centre plane); ears and
	# jaw fail the ground test.
	var centre_x: float = (lo.x + hi.x) * 0.5
	var x_ext: float = maxf(hi.x - lo.x, 0.01)
	var cands: Array = []
	for bi in range(_skel.get_bone_count()):
		if children.has(bi):
			continue # not a leaf
		if float(pos[bi].y) > lo.y + 0.18 * h:
			continue # not at ground level
		var chain: Array = [bi]
		var cur: int = bi
		while true:
			var bp2: int = _skel.get_bone_parent(cur)
			if bp2 < 0 or (children.has(bp2) and (children[bp2] as Array).size() != 1):
				break
			chain.push_front(bp2)
			cur = bp2
		if chain.size() < 3:
			continue
		var max_lat := 0.0
		for cb in chain:
			max_lat = maxf(max_lat, absf(float(pos[int(cb)].x) - centre_x))
		cands.append({"chain": chain, "max_lat": max_lat})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["max_lat"]) > float(b["max_lat"]))
	for c0 in cands:
		if _legs.size() >= 4:
			break
		if float(c0["max_lat"]) <= 0.15 * x_ext:
			continue # the tail (or another centre-plane chain)
		_legs.append({"chain": c0["chain"], "phase": 0.0})
	if _legs.size() < 4:
		# Fallback: accept centre-plane chains too rather than
		# leave a cat legless (better a tail swings than nothing).
		for c1 in cands:
			if _legs.size() >= 4:
				break
			var dup := false
			for l0 in _legs:
				if (l0["chain"] as Array)[0] == (c1["chain"] as Array)[0]:
					dup = true
			if not dup:
				_legs.append({"chain": c1["chain"], "phase": 0.0})
	# FACING: the highest bone in the whole skeleton is a head /
	# ear bone in every model in the batch (probe-verified), so
	# the head end of the long horizontal axis is the facing.
	var use_z: bool = (hi.z - lo.z) >= (hi.x - lo.x)
	var top_bi: int = -1
	var top_y := -1e9
	for bi2 in range(_skel.get_bone_count()):
		if float(pos[bi2].y) > top_y:
			top_y = float(pos[bi2].y)
			top_bi = bi2
	var axis_centre: float = ((lo.z + hi.z) * 0.5) if use_z else ((lo.x + hi.x) * 0.5)
	var top_coord: float = float(pos[top_bi].z) if use_z else float(pos[top_bi].x)
	var sgn: float = 1.0 if top_coord >= axis_centre else -1.0
	var fwd: Vector3 = Vector3(0, 0, sgn) if use_z else Vector3(sgn, 0, 0)
	_face_yaw_off = atan2(fwd.x, fwd.z)
	var lateral: Vector3 = Vector3.UP.cross(fwd).normalized()
	# The same lateral in SKELETON space (where the pose overrides
	# live) — exact via the skeleton's spawn basis, so the swing
	# axis is right whatever the armature's own orientation.
	_skel_lateral = (_skel.global_transform.basis.inverse() * lateral).normalized()
	# Front / rear + side per leg, for the diagonal trot pairing.
	for leg in _legs:
		var chain2: Array = leg["chain"]
		var rp: Vector3 = pos[int(chain2[0])]
		var along: float = (rp.z - axis_centre) * sgn if use_z else (rp.x - axis_centre) * sgn
		var is_front: bool = along > 0.0
		var is_left: bool = (rp - Vector3(centre_x, rp.y, (lo.z + hi.z) * 0.5)).dot(lateral) > 0.0
		# Diagonal pairs move together: front-left with rear-right.
		leg["phase"] = 0.0 if (is_front == is_left) else PI

func _pick_next(first: bool = false) -> void:
	_walking = not first and _rng.randf() < 0.75
	_state_t = _rng.randf_range(1.5, 5.0) if not _walking else 30.0
	if _walking:
		var a: float = _rng.randf() * TAU
		var r: float = wander_radius * sqrt(_rng.randf())
		_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
		_target.y = home.y

func _physics_process(delta: float) -> void:
	if _skel == null:
		return
	# Distance cull like the townsfolk: far cats neither render
	# nor think.
	if player_ref != null:
		var d: float = global_position.distance_to(player_ref.global_position)
		_wrap.visible = d < 95.0
		if d > 110.0:
			return
	_state_t -= delta
	var spd := 0.0
	if _walking:
		var to: Vector3 = _target - global_position
		to.y = 0.0
		if to.length() < 0.7 or _state_t <= 0.0:
			_walking = false
			_state_t = _rng.randf_range(2.0, 7.0)
		else:
			var want_yaw: float = atan2(to.x, to.z) - _face_yaw_off
			rotation.y = _turn_toward(rotation.y, want_yaw, TURN_RATE * delta)
			var dir := -global_transform.basis.z
			dir.y = 0.0
			dir = dir.normalized()
			velocity.x = dir.x * WALK_SPEED
			velocity.z = dir.z * WALK_SPEED
			spd = WALK_SPEED
			if get_real_velocity().length() < 0.25:
				_stuck_t += delta
				if _stuck_t > 1.4:
					_stuck_t = 0.0
					_walking = false
					_state_t = _rng.randf_range(0.5, 1.5)
			else:
				_stuck_t = 0.0
	if not _walking:
		velocity.x = 0.0
		velocity.z = 0.0
		if _state_t <= 0.0:
			_pick_next()
	velocity.y -= 25.0 * delta
	move_and_slide()
	# Trot: phase advances with travel; legs swing, body bobs.
	if spd > 0.1:
		_phase += delta * STRIDE_FREQ * spd
		_apply_trot()
	elif _skel != null:
		_skel.clear_bones_global_pose_override()
	if _inst != null:
		(_inst as Node3D).position.y = sin(_phase * 2.0) * 0.012 if spd > 0.1 else 0.0

func _turn_toward(cur: float, want: float, step: float) -> float:
	var d: float = wrapf(want - cur, -PI, PI)
	if absf(d) <= step:
		return want
	return cur + signf(d) * step

func _apply_trot() -> void:
	for leg in _legs:
		var chain: Array = leg["chain"]
		var swing: float = sin(_phase + float(leg["phase"])) * SWING_AMP
		var root_bi: int = int(chain[0])
		var rest_g: Transform3D = _rest[root_bi]
		var rot := Basis(_skel_lateral, swing)
		var about := Transform3D(rot, rest_g.origin - rot * rest_g.origin)
		var posed_parent: Transform3D = about * rest_g
		_skel.set_bone_global_pose_override(root_bi, posed_parent, 1.0, true)
		for i in range(1, chain.size()):
			var bi2: int = int(chain[i])
			var pg: Transform3D = posed_parent * (_local_rest[bi2] as Transform3D)
			_skel.set_bone_global_pose_override(bi2, pg, 1.0, true)
			posed_parent = pg

var _skel_lateral := Vector3(1, 0, 0) # set exactly in _fit_and_classify
