extends CharacterBody3D
## v1.0.22: the TOWN CATS — Michael's eight Meshy city cats
## (town tabby, black, white fluffy, calico, gray tabby, siamese,
## tortoiseshell, russian blue) wandering the town as ambient
## animals. The Meshy quadruped GLBs arrive RIGGED but with NO
## animation clips, so the trot is procedural: at spawn the leg
## bones are classified from their rest-pose positions (four
## chains off the skeleton's hub bone), diagonal pairs swing
## together like a real cat's trot, and the body bobs on its
## wrapper.
##
## v1.0.26: the cats are INTERACTIVE (Michael's ask, playing
## v1.0.25 — "I want the cat to meow back... maybe paw to play,
## you should get points if you play with another cat"). A meow
## near a cat is answered (meow_back, in the cat's own pitch);
## a paw starts a play session (start_play): the cat turns to
## Zander and rolls over on its wrapper, batting its legs, and
## a completed session scores +3 once per cat per run via
## main.on_town_cat_play. Their wander targets also hug the
## street corridors now (see _pick_next) — the old disc roam
## drifted into back gardens and Michael only ever saw one cat.
##
## Fit is measured, not assumed: bone extents in wrapper space
## set the scale (target bone span below) and ground the paws.

const TARGET_BONE_H := 0.46 # metres, paw-bottom to head-top over the bones
const WALK_SPEED := 1.15
const TURN_RATE := 3.2
const SWING_AMP := 0.5 # rad, upper-leg swing at a trot
const STRIDE_FREQ := 5.4 # phase rad/s per (m/s)
const ROADS_H: Array = [-55.0, -11.0, 15.0, 55.0] # horizontal road centrelines (z)
const ROADS_V: Array = [-70.0, -20.0, 24.0, 72.0] # vertical road centrelines (x) — the legacy grid every cat home sits on
const PLAY_DUR := 2.6 # seconds, one roll-over play session
const ROLL_MAX := PI * 0.92 # the roll-over arc (just shy of fully onto the back)

var model_scene: PackedScene = null
var player_ref: Node3D = null
var main_ref: Node = null # v1.0.25: for house-footprint checks
var home := Vector3.ZERO
var wander_radius := 10.0 # v1.0.26: tightened from 13 — street anchoring does the ranging now
var display_name: String = "the cat" # v1.0.26: set at spawn ("the black cat", ...)
var meow_pitch: float = 1.0 # v1.0.26: this cat's voice (recorded-meow pitch)
var meow_count: int = 0 # v1.0.26 suite handle: meow-backs fired
var played_this_run: bool = false # v1.0.26: the +3 is once per cat per run
var play_sessions: int = 0 # v1.0.26 suite handle: completed play sessions

var _play_t: float = 0.0 # v1.0.26: seconds left in the current play session
var _meow_pending: bool = false # v1.0.26: a meow-back is counting down its reply beat
var _meow_delay: float = 0.0
var _wrap_rest := Transform3D() # v1.0.26: the wrapper's fitted transform (the roll departs from and returns to it)

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
var _fwd_local := Vector3(0, 0, 1) # v1.0.25: the model's nose direction in root space (see _fit_and_classify)
var _best_to := 1e9 # v1.0.25: closest approach to the current target so far
var _away_t := 0.0 # v1.0.25: time spent not getting closer to the target
var _stuck_fires: int = 0 # v1.0.25: consecutive stuck-watchdog fires
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
	_wrap_rest = _wrap.transform # v1.0.26: the play roll departs from here
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
	# FACING: the head end of the long horizontal axis is the
	# facing. v1.0.25: prefer a bone NAMED for the head (head /
	# ear / skull / nose / eye) when the rig has names; otherwise
	# the highest bone in the skeleton is a head / ear bone in
	# every model in the batch (probe-verified).
	var use_z: bool = (hi.z - lo.z) >= (hi.x - lo.x)
	var top_bi: int = -1
	var top_y := -1e9
	for bi2 in range(_skel.get_bone_count()):
		var bname: String = _skel.get_bone_name(bi2).to_lower()
		if not ("head" in bname or "ear" in bname or "skull" in bname or "nose" in bname or "eye" in bname):
			continue
		if float(pos[bi2].y) > top_y:
			top_y = float(pos[bi2].y)
			top_bi = bi2
	if top_bi < 0:
		top_y = -1e9
		for bi3 in range(_skel.get_bone_count()):
			if float(pos[bi3].y) > top_y:
				top_y = float(pos[bi3].y)
				top_bi = bi3
	var axis_centre: float = ((lo.z + hi.z) * 0.5) if use_z else ((lo.x + hi.x) * 0.5)
	var top_coord: float = float(pos[top_bi].z) if use_z else float(pos[top_bi].x)
	var sgn: float = 1.0 if top_coord >= axis_centre else -1.0
	var fwd: Vector3 = Vector3(0, 0, sgn) if use_z else Vector3(sgn, 0, 0)
	_face_yaw_off = atan2(fwd.x, fwd.z)
	_fwd_local = fwd # v1.0.25: movement follows the nose (see _physics_process)
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
	_best_to = 1e9
	_away_t = 0.0
	if _walking:
		# v1.0.26: most walks run ALONG the cat's home street, in
		# the verge / front-lawn band where the player actually
		# goes; the rest stay in a tight disc around home. (The
		# old full-disc roam spent its time in back gardens.)
		# v1.0.25: never aim inside a house footprint (two cats'
		# homes sat inside houses — see main3d._spawn_town_cats —
		# and a target inside the same walls wedged them at home).
		for attempt in range(6):
			if _rng.randf() < 0.65:
				_target = _street_target()
			else:
				var a: float = _rng.randf() * TAU
				var r: float = wander_radius * sqrt(_rng.randf())
				_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
			_target.y = home.y
			if _on_pavement(_target):
				continue
			if main_ref != null and main_ref.has_method("point_in_house_footprint") and bool(main_ref.call("point_in_house_footprint", _target, 0.4)):
				continue
			break

func _street_target() -> Vector3:
	# A point along the road nearest home, on home's side of it,
	# in the verge / front-lawn band just past the sidewalk (the
	# sidewalk edge is 4.8 m from a centreline; the band runs
	# 5.6–8.6 m), up to 15 m along the street either way.
	var best_h := 1e9
	var road_h := 0.0
	for rz in ROADS_H:
		var dh: float = absf(home.z - float(rz))
		if dh < best_h:
			best_h = dh
			road_h = float(rz)
	var best_v := 1e9
	var road_v := 0.0
	for rx in ROADS_V:
		var dv: float = absf(home.x - float(rx))
		if dv < best_v:
			best_v = dv
			road_v = float(rx)
	if best_h <= best_v:
		var side_h: float = 1.0 if home.z >= road_h else -1.0
		var along_h: float = clampf(home.x + _rng.randf_range(-15.0, 15.0), -112.0, 112.0)
		return Vector3(along_h, home.y, road_h + side_h * _rng.randf_range(5.6, 8.6))
	var side_v: float = 1.0 if home.x >= road_v else -1.0
	var along_v: float = clampf(home.z + _rng.randf_range(-15.0, 15.0), -84.0, 84.0)
	return Vector3(road_v + side_v * _rng.randf_range(5.6, 8.6), home.y, along_v)

func _on_pavement(p: Vector3) -> bool:
	# On (or inside the edge of) a road or its sidewalks: within
	# 5.2 m of any centreline (sidewalk edge is 4.8).
	for rz in ROADS_H:
		if absf(p.z - float(rz)) < 5.2:
			return true
	for rx in ROADS_V:
		if absf(p.x - float(rx)) < 5.2:
			return true
	return false

# v1.0.26: Zander meowed nearby — answer after a short beat, in
# this cat's own pitch (main owns the recorded-meow players).
func meow_back() -> void:
	if _meow_pending:
		return
	_meow_pending = true
	_meow_delay = _rng.randf_range(0.25, 0.55)

# v1.0.26: Zander pawed at this cat — PLAY. The cat turns to
# face him and rolls over (see _update_play); a completed
# session scores +3 via main, once per cat per run. Returns
# false when a session is already running (or there is no rig
# to roll).
func start_play() -> bool:
	if _play_t > 0.0 or _skel == null:
		return false
	_play_t = PLAY_DUR
	_walking = false
	_state_t = 3.0
	velocity.x = 0.0
	velocity.z = 0.0
	if player_ref != null:
		var to_p: Vector3 = player_ref.global_position - global_position
		to_p.y = 0.0
		if to_p.length() > 0.05:
			rotation.y = atan2(to_p.x, to_p.z) - _face_yaw_off
	return true

func _update_play(delta: float) -> void:
	# The roll lives on the WRAPPER (visual only — the physics
	# body never tips): rotate the fitted wrapper around the
	# cat's own nose axis through its body centre — roll onto
	# the back, wiggle there, roll back. Legs bat via the trot
	# overrides (see the animation step in _physics_process).
	_play_t -= delta
	var e: float = PLAY_DUR - _play_t
	var ang := 0.0
	if e < 1.0:
		ang = sin(clampf(e, 0.0, 1.0) * PI * 0.5) * ROLL_MAX
	elif e < 1.9:
		ang = ROLL_MAX + sin(e * 11.0) * 0.10
	else:
		ang = ROLL_MAX * cos(clampf((e - 1.9) / (PLAY_DUR - 1.9), 0.0, 1.0) * PI * 0.5)
	var r := Basis(_fwd_local, ang)
	_wrap.basis = r * _wrap_rest.basis
	var c := Vector3(0.0, 0.24, 0.0)
	_wrap.position = c + r * (_wrap_rest.origin - c)
	if _play_t <= 0.0:
		_play_t = 0.0
		_wrap.transform = _wrap_rest
		if _skel != null:
			_skel.clear_bones_global_pose_override()
		play_sessions += 1
		if not played_this_run:
			played_this_run = true
			if main_ref != null and main_ref.has_method("on_town_cat_play"):
				main_ref.call("on_town_cat_play", self)
		_state_t = _rng.randf_range(1.0, 3.0)

func _physics_process(delta: float) -> void:
	# v1.0.26: the meow-back reply beat ticks first — it must
	# fire even for a cat whose rig failed (none should).
	if _meow_pending:
		_meow_delay -= delta
		if _meow_delay <= 0.0:
			_meow_pending = false
			meow_count += 1
			if main_ref != null and main_ref.has_method("play_cat_meow"):
				main_ref.call("play_cat_meow", meow_pitch)
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
	# v1.0.25 LEASH: a cat that somehow ends up far from home
	# (shoved, spawned wrong, a bad walk) walks HOME, not onward.
	# In v1.0.24 the town cats drifted clean out of the town and
	# were never seen again — Michael: "where are the NPC cats?"
	if global_position.distance_to(home) > wander_radius + 9.0:
		_walking = true
		_target = home
		_state_t = 30.0
		_best_to = 1e9
		_away_t = 0.0
	# v1.0.26: a play session owns the cat while it runs — no
	# wandering, no walking away mid-roll.
	if _play_t > 0.0:
		_update_play(delta)
	var spd := 0.0
	if _walking and _play_t <= 0.0:
		var to: Vector3 = _target - global_position
		to.y = 0.0
		if to.length() < 0.7 or _state_t <= 0.0:
			_walking = false
			_state_t = _rng.randf_range(2.0, 7.0)
		else:
			# v1.0.25 WALK-AWAY WATCHDOG: if the gap to the target
			# has not closed at all in 3 s, something is steering
			# wrong — stop, idle, re-pick, rather than march in a
			# wrong direction for the whole 30 s walk state.
			if to.length() < _best_to - 0.2:
				_best_to = to.length()
				_away_t = 0.0
			else:
				_away_t += delta
				if _away_t > 3.0:
					_away_t = 0.0
					_best_to = 1e9
					_walking = false
					_state_t = _rng.randf_range(0.5, 1.5)
			var want_yaw: float = atan2(to.x, to.z) - _face_yaw_off
			rotation.y = _turn_toward(rotation.y, want_yaw, TURN_RATE * delta)
			# v1.0.25 THE MISSING-CATS BUG: movement used to follow
			# the ROOT's -Z while rotation aimed the MODEL at the
			# target. For any rig whose nose is not on wrapper +Z
			# (offset PI or +/-PI/2), the cat walked away from —
			# or sideways to — every target, 30 s at a time, until
			# it had wandered out of the town entirely. Movement
			# now follows the model's own nose (_fwd_local).
			var dir: Vector3 = global_transform.basis * _fwd_local
			dir.y = 0.0
			dir = dir.normalized()
			velocity.x = dir.x * WALK_SPEED
			velocity.z = dir.z * WALK_SPEED
			spd = WALK_SPEED
			if get_real_velocity().length() < 0.25:
				_stuck_t += delta
				if _stuck_t > 1.4:
					_stuck_t = 0.0
					_stuck_fires += 1
					if _stuck_fires >= 4 and main_ref != null and main_ref.has_method("escape_point_from_houses"):
						# v1.0.25 last resort, same as the
						# townsfolk: overlap-wedged bodies step
						# bodily out to the escape point.
						var out_c: Vector3 = main_ref.call("escape_point_from_houses", global_position)
						out_c = main_ref.call("push_out_of_houses", out_c, 0.5)
						global_position = Vector3(out_c.x, global_position.y, out_c.z)
						_stuck_fires = 0
						_pick_next()
					elif _stuck_fires >= 2 and main_ref != null and main_ref.has_method("escape_point_from_houses"):
						# v1.0.25: same porch-pocket escape the
						# townsfolk got — walk OUT, don't just
						# re-pick and press the same faces again.
						_target = main_ref.call("escape_point_from_houses", global_position)
						_state_t = 20.0
						_best_to = 1e9
						_away_t = 0.0
					else:
						_walking = false
						_state_t = _rng.randf_range(0.5, 1.5)
			else:
				_stuck_t = 0.0
				_stuck_fires = 0
	if not _walking:
		velocity.x = 0.0
		velocity.z = 0.0
		if _state_t <= 0.0:
			_pick_next()
	velocity.y -= 25.0 * delta
	move_and_slide()
	# v1.0.25: the town bounds, same clamp the townsfolk get — a
	# town cat never leaves the town.
	global_position.x = clamp(global_position.x, -117.0, 117.0)
	global_position.z = clamp(global_position.z, -89.0, 89.0)
	# Trot: phase advances with travel; legs swing, body bobs.
	# v1.0.26: mid-play the same leg overrides become paw-batting
	# in the air while the wrapper holds the roll.
	if _play_t > 0.0:
		_phase += delta * 9.0
		_apply_trot()
	elif spd > 0.1:
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
