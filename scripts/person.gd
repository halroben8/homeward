extends CharacterBody3D
## HOMEWARD v0.7 — 3D NPC person, modelled on Michael's CITY NPCS sheet:
## Cat-Loving Young Woman (bun, cream sweater, jeans, cat-face bag, phone),
## Excited Kid (purple/orange hoodie, messy hair, smaller + fast),
## Friendly Dog Walker (green jacket, messenger bag, leash, small fluffy
## white dog), Cheerful Shopkeeper (flat cap, moustache, green apron with
## a cat face, paper cat bag). Turns to face its walking direction,
## swings arms/legs, turns toward the cat while curious / pursuing.

var npc_type: String = "pedestrian"
var display_name: String = "Pedestrian"
# --- v1.0.19 PRONOUNS: ONE set per character, defined once in
# _apply_type() and nowhere else. Every player-facing line that
# refers to a character pulls its pronouns from here (main3d's
# escape-room text, the opening's pound line) — the v1.0.17 build
# wrote the escape text as if every captor were the young woman,
# so the pound called the officer "she", and one screen mixed
# her/him for the same captor (Michael's v1.0.17 play report).
# gendered = true ONLY where the character's concept/model
# establishes a gender: the officer (the kind man of the opening
# story; cap + moustache on the splash), the Cat-Loving Young
# Woman, the shopkeeper (flat cap + moustache on the sheet and
# the model). The kid, the dog walker and the pedestrian
# neighbours have NO established gender — gendered stays false
# and text refers to them by display_name instead of a pronoun.
# Never guess one for them.
var pron_subj: String = "they" # he | she | they
var pron_obj: String = "them" # him | her | them
var pron_poss: String = "their" # his | her | their
var gendered: bool = false
var walk_speed: float = 2.4
var chase_speed: float = 6.2
var detect_radius: float = 11.0
var fill_rate: float = 0.45
var notice: float = 0.0
var mode: String = "wander" # wander | chase | pursue
var wander_target: Vector3 = Vector3.ZERO
var wander_wait: float = 0.0
var main_ref: Node = null
var player_ref: Node3D = null
var bark_timer: float = 0.0
# --- v0.6 CHASE capture (not meter-fill): full notice starts a chase;
# capture needs the NPC to catch up and HOLD grab range. ---
var grab_range: float = 1.2
var grab_needed: float = 1.5 # seconds in grab range required to capture
var grab_progress: float = 0.0 # seconds accumulated; decays slowly mid-chase
var notice_cooldown: float = 0.0 # seconds after a lost chase before noticing again
var far_timer: float = 0.0
var los_timer: float = 0.0
var has_los_now: bool = true
var active: bool = true
var wide_bounds: bool = false # POUND VAN: the patrol worker roams the DOUBLED map (x to 369); town NPCs keep the historic ±117 position clamp below
var wander_x_max: float = 366.0 # BISECT (v1.0.12): east edge for wander targets — main sets 112.0 in LEGACY_TOWN_ONLY mode so nobody wanders into the ungenerated east district
var net_root: Node3D = null # POUND VAN: the catch net (poundworker only), parented to the right arm
# --- v1.0.15 MESHY NPC SWAP (see the block at the end of this file) --
var meshy_root: Node3D = null # the imported model, child of `model`
var meshy_skel: Skeleton3D = null
var meshy_ap: AnimationPlayer = null
var meshy_rest: Dictionary = {} # bone index -> global rest Transform3D
var meshy_local_rest: Dictionary = {} # bone index -> parent-relative rest
var meshy_bone: Dictionary = {} # role -> bone index
var meshy_order: Array = [] # bone indices, parents before children
var meshy_arm_chain: Array = [] # bone index -> bool (arm subtree, fades on w_arms)
var meshy_w_body: float = 0.0 # ghost-mirror weight: body chain
var meshy_w_arms: float = 0.0 # ghost-mirror weight: arm chains
var meshy_overrides_on: bool = false
var meshy_clip: String = ""
var phone_mis: Array = [] # the woman's phone + screen meshes (kept visible through the swap — the mirrored pose holds them)
static var _meshy_loops_set: Dictionary = {} # Animation resources already set looping
# The little dog (dogwalker): his GLB has a skeleton but no clips,
# so his trot + tail wag get a small mirror of their own.
var dog_meshy_root: Node3D = null
var dog_skel: Skeleton3D = null
var dog_rest: Dictionary = {}
var dog_local_rest: Dictionary = {}
var dog_order: Array = []
var dog_bone: Dictionary = {} # fl/fr/rl/rr/tail -> bone index
# --- v0.6 interaction roles + grabber RUN tell + obstacle slowdown -----
# role (assigned by main at spawn): "grabber" | "friendly" | "ignore".
# Of the NPCs who notice the cat at all, ~1 in 4 is a grabber (2-3 of 14
# overall). Friendly NPCs come close and PET (+1) or offer a TREAT (+5);
# "ignore" NPCs never notice the cat. Grabbers give a clear RUN tell
# (crouch, arms wide, "!", "Here, kitty kitty!") before chasing.
var role: String = "friendly"
var interact_cooldown: float = 0.0
# --- v0.8 (item 5): friendly bend-down pet/treat ---------------------
# Friendly people NO LONGER build notice from proximity at all — the
# 👀 bar belongs to the grabber alone. A friendly person reacts only
# when the cat paws/meows at them: they bend down (bend_t/bend_a) and
# mid-bend the pending award fires (pet +1 / treat +5).
var bend_t: float = 0.0 # seconds of bend-down remaining
var bend_a: float = 0.0 # bend pose envelope 0..1 (animated in _animate)
# --- v1.3 CAPTURE SCOOP poses (driven by main's cutscene) ------------
# The old cutscene posed NOTHING here: main pitched the whole model
# from outside while this animator relaxed the arms to the sides, so
# the cat floated up untouched and rode at the person's back. Now
# main feeds three envelopes per frame (set_carry_pose) and _animate
# applies them LAST, over every other pose: KNEEL (the petting kneel,
# cutscene-driven), REACH (both hands aimed down at the cat's flanks,
# tracking him as he rises, sliding under his belly with lift_k),
# CRADLE (arms folded under him against the chest — and they STAY
# folded through the walk-away instead of walk-swinging).
var scoop_reach_a: float = 0.0
var scoop_cradle_a: float = 0.0
var scoop_kneel_a: float = 0.0
var scoop_lift_k: float = 0.0 # 0 = hands at his sides, 1 = hands under him
var award_t: float = -1.0 # countdown to the pet/treat moment (-1 = none pending)
var pending_award: String = "" # "pet" | "treat"
# --- v0.9 REAL PETTING (Michael, three times: "they just wave their
# arm / it just says something via text — I want them to bend down
# and PET you"). A friendly interaction is now a full acted sequence:
#   approach -> bend (kneel down to cat level) -> pet (the right arm
#   AIMS at the cat and strokes along his back, hand in contact,
#   hearts rising, cat leaning in and purring) or treat (hand offers
#   a visible treat, cat dips his head and eats it) -> rise.
# Points fire DURING the action, once the action has genuinely
# run (the pet award lands mid-stroke, the treat award as he
# finishes eating) — never on the trigger, never as a text-only
# event. (v1.0.13: the pet award no longer demands a sub-0.34 m
# hand measurement — the kneeling hand's real standoff is
# 0.33-0.41 m, so that gate silently ate ~3 of 4 pets. See the
# "pet" state in _run_interaction.)
var outfit_idx: int = 0 # 0 = the sheet design; >0 = outfit/hair variants for the extra neighbours
var mscale: float = 1.0 # body_h / 1.7, stored at build time
var interact_state: String = "" # "" | approach | bend | pet | treat | rise
var interact_t: float = 0.0 # seconds in the current sequence phase
var interact_kind: String = "" # "pet" | "treat"
var award_pending: bool = false # points will land mid-action (cooldown-gated)
var award_fired: bool = false
# v1.0.13 TREAT GUARANTEE: friendly encounters since the last
# treat, counted across ALL people (static) but only over
# award-eligible starts (cooldown ready — the encounters whose
# points can actually land). See _roll_interact_kind.
static var s_eligible_since_treat: int = 0
var pet_contact_frames: int = 0 # physics frames the hand was ON the cat this pet
var last_hand_dist: float = 999.0 # hand-to-cat distance, latest frame (tests + debug)
var hand_r_mi: MeshInstance3D = null # the right hand mesh (end of the petting arm)
var treat_mi: MeshInstance3D = null # the visible treat, shown in the hand during "treat"
var hearts: Array = [] # floating heart labels {node, t}
var heart_spawn_t: float = 0.0
var bubble_lock_t: float = 0.0 # spot bubble ("Oh, a cat!") can't be overwritten while > 0
var tell_t: float = 0.0 # seconds left in the RUN tell (mode == "tell")
var slowed_timer: float = 0.0 # set when the cat hops an obstacle mid-chase
var role_rng := RandomNumberGenerator.new()

func effective_chase_speed() -> float:
	return chase_speed * (0.45 if slowed_timer > 0.0 else 1.0)

var model: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var head_node: Node3D
var shin_l: Node3D = null # v1.4: knee pivots (two-segment legs)
var shin_r: Node3D = null
var mouths: Dictionary = {} # v1.4: expression mouth groups by name
var mouth_root: Node3D = null
var eye_base_scale := Vector3(0.08, 0.1, 0.042)
var cheek_base_scale := Vector3(0.078, 0.05, 0.028)
var skin_col: Color = SKIN # this person's own skin tone
var hair_col_v: Color = HAIR_BROWN # this person's own hair colour
# --- v0.6 JOY: faces change when they spot the cat -------------------
var expression: String = "neutral" # neutral | joy | sad
var joy_shown: bool = false
var expr_timer: float = 0.0
var joy_hop_t: float = 0.0
var brow_l: MeshInstance3D = null
var brow_r: MeshInstance3D = null
var brow_base_l: Vector3 = Vector3.ZERO
var brow_base_r: Vector3 = Vector3.ZERO
var mouth_mi: MeshInstance3D = null
var mouth_base_scale: Vector3 = Vector3(0.14, 0.055, 0.05)
var eye_l_mi: MeshInstance3D = null
var eye_r_mi: MeshInstance3D = null
var cheek_l_mi: MeshInstance3D = null
var cheek_r_mi: MeshInstance3D = null
var cheek_base_l: Vector3 = Vector3.ZERO
var cheek_base_r: Vector3 = Vector3.ZERO
var bubble_label: Label3D = null
var hold_pose: bool = false # woman/pedestrian: arms up holding a phone
var bubble_timer: float = 0.0
var dog_model: Node3D
var dog_legs: Array = []
var dog_tail: Node3D
var name_label: Label3D
var notice_label: Label3D
# --- v1.0.13 BAR CLEANUP: the notice / GRAB meter is real geometry
# now (bar_root: frame + track + fill quads), NOT block glyphs in the
# label text. The old text bar's unfilled cells were "░" shade
# glyphs, which render as a field of little dots trailing the fill —
# Michael, v1.0.12 play: "the progress bar for chasing looks like
# crap... underneath the progress bar it's weird like dots... like
# it's unfinished." The label carries only the words now; the meter
# under them is one clean solid fill. Same size, same spot over the
# head, same yellow, same thresholds and timing.
const BAR_W := 2.05 # meter width (m) — matches the old 10-block span
const BAR_H := 0.24
var bar_root: Node3D
var bar_fill: MeshInstance3D
var walk_phase: float = 0.0
var body_h: float = 1.7
# --- PERF (post-v1.0.1): distance-throttle state — see the gate at
# the top of _physics_process. _perf_accum banks the delta of skipped
# ticks so an executed tick advances the NPC by the FULL elapsed
# time: wander speed, timers and cooldowns all keep exact wall-clock
# rates at any stride. _perf_skip counts down the ticks still to
# skip before the next executed tick.
var _perf_accum: float = 0.0
var _perf_skip: int = 0

const SKIN := Color(0.96, 0.76, 0.6)
const HAIR_BROWN := Color(0.35, 0.22, 0.13)
const TEX_FABRIC: Texture2D = preload("res://assets/textures/fabric.png") # v0.8: knit detail so clothes aren't flat plastic
const TEX_FABRIC_N: Texture2D = preload("res://assets/textures/fabric_normal.png") # v1.0 step 2: the weave, in relief

func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	return _mat_cached("plain", c, rough)

func _mat_skin(c: Color) -> StandardMaterial3D:
	return _mat_cached("skin", c, 0.55)

func _mat_fabric(c: Color) -> StandardMaterial3D:
	return _mat_cached("fabric", c, 0.92)

func _box(parent: Node, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _sphere(parent: Node, pos: Vector3, scl: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 30
	sm.rings = 18
	mi.mesh = sm
	mi.position = pos
	mi.scale = scl
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _cyl(parent: Node, pos: Vector3, r_top: float, r_bot: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _ready() -> void:
	add_to_group("npc")
	_apply_type()
	_build_collision()
	_build_model()
	_pick_wander_target()

func _apply_type() -> void:
	match npc_type:
		"woman":
			display_name = "Cat-Loving Young Woman"
			pron_subj = "she"; pron_obj = "her"; pron_poss = "her"; gendered = true
			walk_speed = 2.5; chase_speed = 6.3; detect_radius = 7.5; fill_rate = 0.24
		"kid":
			display_name = "Excited Kid"
			# v1.0.19: no gender in the concept sheet or the model
			# (hoodie, grin, freckles) — gendered stays false, so
			# text uses the name, never a guessed pronoun.
			walk_speed = 3.4; chase_speed = 7.0; detect_radius = 7.0; fill_rate = 0.30; body_h = 1.15
		"dogwalker":
			display_name = "Friendly Dog Walker"
			# v1.0.19: no established gender (wavy hair, overshirt,
			# messenger bag) — gendered stays false, name-based text.
			walk_speed = 2.3; chase_speed = 6.6; detect_radius = 8.0; fill_rate = 0.26
		"shopkeeper":
			display_name = "Cheerful Shopkeeper"
			# v1.0.19: he/him — the flat cap + MOUSTACHE are part of
			# his sheet design and his model (see _build_model).
			pron_subj = "he"; pron_obj = "him"; pron_poss = "his"; gendered = true
			walk_speed = 2.1; chase_speed = 6.0; detect_radius = 6.5; fill_rate = 0.22
		"poundworker":
			# POUND VAN (Michael, 2026-11-17): the animal-control
			# worker from the white van. NOT a town NPC — main spawns
			# exactly one, keeps him out of the npcs array (so the
			# 25% avoid-share is untouched) and drives his patrol /
			# pull-over / return-to-van states itself; his chase,
			# grab and capture reuse this class's grabber machinery.
			display_name = "Pound Worker"
			# v1.0.19: he/him — the kind man of the opening story
			# (Michael's direction: the officer is a HE).
			pron_subj = "he"; pron_obj = "him"; pron_poss = "his"; gendered = true
			walk_speed = 2.4; chase_speed = 6.4; detect_radius = 12.0; fill_rate = 0.30
		_:
			display_name = "Pedestrian"
			# v1.0.19: the generic neighbours have no established
			# gender — gendered stays false, name-based text.
			walk_speed = 2.4; chase_speed = 6.1; detect_radius = 6.0; fill_rate = 0.18

# --- v1.0.19 pronoun accessors: player-facing text builds its
# references to a character from THESE and nothing else. --------
func p_subj() -> String:
	return pron_subj

func p_obj() -> String:
	return pron_obj

func p_poss() -> String:
	return pron_poss

func p_is_gendered() -> bool:
	return gendered

# Subject-position reference, sentence-ready: "He" / "She" for a
# gendered character, "The Excited Kid" for a neutral one.
func p_ref() -> String:
	return pron_subj.capitalize() if gendered else "The " + display_name

# The same reference mid-sentence: "he" / "she" / "the Excited Kid".
func p_ref_lower() -> String:
	return pron_subj if gendered else "the " + display_name

# Object-position reference: "him" / "her" / "the Excited Kid".
func p_ref_obj() -> String:
	return pron_obj if gendered else "the " + display_name

# Possessive reference: "his" / "her" / "the Excited Kid's".
func p_ref_poss() -> String:
	return pron_poss if gendered else "the " + display_name + "'s"

# "<X> is" as one fragment: "She's" / "He's" for a gendered
# character, "The Excited Kid is" for a neutral one — for the
# "<X> busy / watching / distracted / in the room" lines.
func p_is() -> String:
	return (pron_subj.capitalize() + "'s") if gendered else ("The " + display_name + " is")

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = body_h
	cs.shape = cap
	cs.position = Vector3(0, body_h * 0.5, 0)
	add_child(cs)

var last_hand_mi: MeshInstance3D = null # set by _limb: the hand/shoe blob at the limb's end


static var _mat_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}

# v1.4 NPC LOOK: materials are shared across all 48 neighbours via
# a static cache — the old code built a brand-new material for
# every body part of every person (~60 per person).
func _mat_cached(kind: String, c: Color, rough: float) -> StandardMaterial3D:
	var key: String = kind + "|" + str(c) + "|" + str(rough)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m: StandardMaterial3D
	if kind == "fabric":
		m = StandardMaterial3D.new()
		m.albedo_texture = TEX_FABRIC
		m.albedo_color = c
		m.roughness = 0.92
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.normal_enabled = true
		m.normal_texture = TEX_FABRIC_N
		m.normal_scale = 0.65
	else:
		m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
	_mat_cache[key] = m
	return m

# LOFT: sweep an elliptical ring along Y stations — the same
# shaped-mesh approach that fixed the cat. One continuous surface
# per body part (torso, head, hair, thigh, shin, arm) instead of
# stacked spheres/boxes/cylinders. Geometry is cached by its
# station signature, so every neighbour shares the same meshes;
# only the material (colour) differs per person.
func _loft(parent: Node, stations: Array, mat: Material, radial: int = 12) -> MeshInstance3D:
	var key: String = "loft|" + str(radial)
	for st in stations:
		key += "|" + str(st[0]) + "," + str(st[1]) + "," + str(st[2])
	var mesh: ArrayMesh = _mesh_cache.get(key)
	if mesh == null:
		mesh = _build_loft_mesh(stations, radial)
		_mesh_cache[key] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _build_loft_mesh(stations: Array, radial: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var center := Vector3.ZERO
	for st in stations:
		center += st[0]
	center /= float(stations.size())
	for si in range(stations.size()):
		var c: Vector3 = stations[si][0]
		for j in range(radial + 1):
			var a: float = TAU * float(j) / float(radial)
			verts.append(c + Vector3(cos(a) * float(stations[si][1]), 0, sin(a) * float(stations[si][2])))
			uvs.append(Vector2(float(j) / float(radial) * 2.0, c.y * 2.0))
	var bot_i: int = verts.size()
	verts.append(stations[0][0] + Vector3(0, -0.012, 0))
	uvs.append(Vector2(0.5, 0))
	var top_i: int = verts.size()
	verts.append(stations[stations.size() - 1][0] + Vector3(0, 0.012, 0))
	uvs.append(Vector2(0.5, 1))
	var idx := PackedInt32Array()
	for i in range(stations.size() - 1):
		for j in range(radial):
			var q0: int = i * (radial + 1) + j
			var q1: int = q0 + 1
			var q2: int = q0 + radial + 1
			var q3: int = q2 + 1
			idx.append_array([q0, q2, q1, q1, q2, q3])
	for j in range(radial):
		idx.append_array([bot_i, j + 1, j])
		var t0: int = (stations.size() - 1) * (radial + 1) + j
		idx.append_array([top_i, t0, t0 + 1])
	# Smooth normals, accumulated and signed outward; winding
	# corrected to Godot's front-face convention (same maths as
	# the cat sculpt's _finish_mesh).
	var tot: float = 0.0
	for k in range(0, idx.size(), 3):
		var pa: Vector3 = verts[idx[k]]
		var pb: Vector3 = verts[idx[k + 1]]
		var pc: Vector3 = verts[idx[k + 2]]
		tot += (pb - pa).cross(pc - pa).dot((pa + pb + pc) / 3.0 - center)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for k in range(0, idx.size(), 3):
		var fn: Vector3 = (verts[idx[k + 1]] - verts[idx[k]]).cross(verts[idx[k + 2]] - verts[idx[k]])
		normals[idx[k]] += fn
		normals[idx[k + 1]] += fn
		normals[idx[k + 2]] += fn
	var sgn: float = 1.0 if tot > 0.0 else -1.0
	for i in range(normals.size()):
		if normals[i].length() > 0.00001:
			normals[i] = normals[i].normalized() * sgn
		else:
			normals[i] = (verts[i] - center).normalized()
	if tot > 0.0:
		for k in range(0, idx.size(), 3):
			var tmp: int = idx[k + 1]
			idx[k + 1] = idx[k + 2]
			idx[k + 2] = tmp
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# Curved front panel (apron, tee front, pocket): an arc strip that
# follows the torso's curve instead of a flat box floating in front.
func _front_panel(parent: Node, r: float, y_top: float, y_bot: float, half_arc: float, mat: Material) -> MeshInstance3D:
	var key: String = "panel|" + str(r) + "|" + str(y_top) + "|" + str(y_bot) + "|" + str(half_arc)
	var mesh: ArrayMesh = _mesh_cache.get(key)
	if mesh == null:
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var normals := PackedVector3Array()
		var idx := PackedInt32Array()
		var rows: Array = [y_top, (y_top + y_bot) * 0.5, y_bot]
		var segs: int = 8
		for ri in range(rows.size()):
			for j in range(segs + 1):
				var a: float = -half_arc + 2.0 * half_arc * float(j) / float(segs)
				var rr: float = r + (0.006 if ri == 1 else 0.0)
				verts.append(Vector3(sin(a) * rr, rows[ri], cos(a) * rr))
				normals.append(Vector3(sin(a), 0, cos(a)))
				uvs.append(Vector2(float(j) / float(segs), float(ri) * 0.5))
		for i in range(rows.size() - 1):
			for j in range(segs):
				var q0: int = i * (segs + 1) + j
				var q1: int = q0 + 1
				var q2: int = q0 + segs + 1
				var q3: int = q2 + 1
				idx.append_array([q0, q1, q2, q1, q3, q2])
		mesh = ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mesh_cache[key] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi

# Two-segment leg: thigh pivot at the hip, SHIN pivot at the knee.
# This is what makes a real kneel possible — the old single-piece
# leg could only fold at the hip, so "kneeling" pitched the whole
# body. Now the descent lives in the knees, like Michael asked.
func _build_leg(parent: Node, x: float, s: float, thigh_col: Color, shin_col: Color, shoe_col: Color, cuff_col: Color, bare_shin: bool = false) -> Array:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.85 * s, 0)
	parent.add_child(pivot)
	_loft(pivot, [
		[Vector3(0, 0.012, 0), 0.108 * s, 0.118 * s],
		[Vector3(0, -0.22 * s, 0), 0.088 * s, 0.096 * s],
		[Vector3(0, -0.44 * s, 0), 0.066 * s, 0.070 * s]], _mat_fabric(thigh_col.lightened(0.3)), 10)
	var shin := Node3D.new()
	shin.position = Vector3(0, -0.44 * s, 0)
	pivot.add_child(shin)
	_loft(shin, [
		[Vector3(0, 0.012, 0), 0.064 * s, 0.068 * s],
		[Vector3(0, -0.18 * s, 0), 0.054 * s, 0.057 * s],
		[Vector3(0, -0.36 * s, 0), 0.046 * s, 0.048 * s]], _mat_skin(shin_col) if bare_shin else _mat_fabric(shin_col.lightened(0.3)), 10)
	if cuff_col.a > 0.0:
		var cuff := _cyl(shin, Vector3(0, -0.315 * s, 0), 0.062 * s, 0.066 * s, 0.1 * s, cuff_col)
		cuff.material_override = _mat_fabric(cuff_col.lightened(0.3))
	# A shoe that reads as a shoe: rounded toe + a sole.
	_sphere(shin, Vector3(0, -0.362 * s, 0.038 * s), Vector3(0.155 * s, 0.095 * s, 0.27 * s), shoe_col)
	var sole := _box(shin, Vector3(0, -0.398 * s, 0.042 * s), Vector3(0.165 * s, 0.028 * s, 0.29 * s), Color(0.92, 0.92, 0.9))
	sole.material_override = _mat(Color(0.92, 0.92, 0.9), 0.6)
	return [pivot, shin]

# Arm: one tapered loft (sleeve, or sleeve + bare forearm for the
# kid's short sleeves), an elbow ball, and a shaped hand with a
# thumb — the hand the cat feels when he's petted.
func _build_arm(parent: Node, x: float, s: float, sleeve_col: Color, short_sleeve: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 1.48 * s, 0)
	parent.add_child(pivot)
	if short_sleeve:
		_loft(pivot, [
			[Vector3(0, 0.012, 0), 0.084 * s, 0.088 * s],
			[Vector3(0, -0.16 * s, 0), 0.072 * s, 0.075 * s],
			[Vector3(0, -0.30 * s, 0), 0.062 * s, 0.064 * s]], _mat_fabric(sleeve_col.lightened(0.3)), 10)
		_loft(pivot, [
			[Vector3(0, -0.29 * s, 0), 0.060 * s, 0.062 * s],
			[Vector3(0, -0.50 * s, 0), 0.052 * s, 0.054 * s],
			[Vector3(0, -0.66 * s, 0), 0.046 * s, 0.048 * s]], _mat_skin(skin_col), 10)
	else:
		_loft(pivot, [
			[Vector3(0, 0.012, 0), 0.086 * s, 0.090 * s],
			[Vector3(0, -0.34 * s, 0), 0.066 * s, 0.069 * s],
			[Vector3(0, -0.66 * s, 0), 0.048 * s, 0.050 * s]], _mat_fabric(sleeve_col.lightened(0.3)), 10)
	var elb := _sphere(pivot, Vector3(0, -0.34 * s, 0), Vector3(0.125 * s, 0.125 * s, 0.125 * s), sleeve_col)
	elb.material_override = _mat_fabric(sleeve_col.lightened(0.3)) if not short_sleeve else _mat_skin(skin_col)
	var hand := _sphere(pivot, Vector3(0, -0.705 * s, 0.012), Vector3(0.105 * s, 0.135 * s, 0.115 * s), skin_col)
	hand.material_override = _mat_skin(skin_col)
	var thumb := _sphere(pivot, Vector3(signf(x) * -0.048 * s, -0.665 * s, 0.035), Vector3(0.042 * s, 0.06 * s, 0.042 * s), skin_col)
	thumb.material_override = _mat_skin(skin_col)
	last_hand_mi = hand
	return pivot


# v1.4 EXPRESSION MOUTHS: five small mouth groups (bead arcs and an
# open grin) built once per person; set_expression() just toggles
# which one is visible. Beads-on-an-arc read as a smile or a frown
# from across the street — the old single squashed sphere read as
# a blob at any distance.
func _build_mouths(s: float) -> void:
	mouth_root = Node3D.new()
	mouth_root.position = Vector3(0, -0.128 * s, 0.196 * s)
	head_node.add_child(mouth_root)
	var lip := Color(0.58, 0.27, 0.25)
	var smile := Node3D.new()
	var frown := Node3D.new()
	for i in range(5):
		var fx: float = -0.052 + float(i) * 0.026
		var arc: float = pow(absf(fx) / 0.052, 2.0) * 0.027
		var b1 := _sphere(smile, Vector3(fx, arc - 0.014, 0), Vector3(0.031, 0.021, 0.015), lip)
		b1.material_override = _mat(lip, 0.6)
		var b2 := _sphere(frown, Vector3(fx, 0.014 - arc, 0), Vector3(0.031, 0.021, 0.015), lip)
		b2.material_override = _mat(lip, 0.6)
	mouth_root.add_child(smile)
	mouth_root.add_child(frown)
	var small := Node3D.new()
	for i in range(3):
		var fx2: float = -0.03 + float(i) * 0.03
		var b3 := _sphere(small, Vector3(fx2, pow(absf(fx2) / 0.03, 2.0) * 0.012 - 0.006, 0), Vector3(0.028, 0.019, 0.014), lip)
		b3.material_override = _mat(lip, 0.6)
	mouth_root.add_child(small)
	var grin := Node3D.new()
	var oval := _sphere(grin, Vector3(0, -0.012, 0), Vector3(0.104, 0.122, 0.038), Color(0.33, 0.14, 0.14))
	oval.material_override = _mat(Color(0.33, 0.14, 0.14), 0.5)
	var teeth := _box(grin, Vector3(0, 0.03, 0.012), Vector3(0.074, 0.02, 0.012), Color(0.97, 0.96, 0.92))
	teeth.material_override = _mat(Color(0.97, 0.96, 0.92), 0.35)
	var tongue := _sphere(grin, Vector3(0, -0.042, 0.008), Vector3(0.056, 0.034, 0.02), Color(0.86, 0.46, 0.5))
	tongue.material_override = _mat(Color(0.86, 0.46, 0.5), 0.5)
	mouth_root.add_child(grin)
	var flat := Node3D.new()
	var fl := _cyl(flat, Vector3.ZERO, 0.0115, 0.0115, 0.076, lip.darkened(0.15))
	fl.rotation_degrees = Vector3(0, 0, 90)
	fl.material_override = _mat(lip.darkened(0.15), 0.6)
	mouth_root.add_child(flat)
	mouths = {"smile": smile, "frown": frown, "smile_small": small, "grin": grin, "flat": flat}
	_show_mouth("flat")

func _show_mouth(which: String) -> void:
	for k in mouths:
		(mouths[k] as Node3D).visible = k == which

func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var top_col := Color(0.85, 0.8, 0.7)
	var leg_col := Color(0.25, 0.35, 0.6)
	var hair_col := HAIR_BROWN
	var extra := ""
	match npc_type:
		"woman":
			top_col = Color(0.93, 0.87, 0.75) # cream sweater
			leg_col = Color(0.25, 0.38, 0.62) # jeans
			extra = "bun"
		"kid":
			top_col = Color(0.55, 0.3, 0.8) # purple/orange hoodie
			leg_col = Color(0.2, 0.3, 0.55)
			extra = "messy"
		"dogwalker":
			top_col = Color(0.4, 0.48, 0.32) # green jacket
			leg_col = Color(0.3, 0.35, 0.5)
		"shopkeeper":
			top_col = Color(0.95, 0.92, 0.85)
			leg_col = Color(0.4, 0.3, 0.2)
			extra = "apron_cap"
		"poundworker":
			top_col = Color(0.96, 0.96, 0.94) # white uniform shirt
			leg_col = Color(0.92, 0.92, 0.90) # white uniform trousers
			extra = "poundcap"
		_:
			top_col = Color(0.5, 0.6, 0.75)
			leg_col = Color(0.35, 0.35, 0.4)
	# v0.9 OUTFIT VARIETY: neighbours beyond the first of each type
	# (outfit_idx > 0) get different tops, trousers and hair, so a
	# busier street doesn't read as clones. The four sheet characters
	# keep outfit 0 exactly as designed.
	if outfit_idx > 0:
		var tops_v: Array = [Color(0.25, 0.6, 0.62), Color(0.9, 0.5, 0.35), Color(0.85, 0.7, 0.25), Color(0.6, 0.5, 0.8), Color(0.45, 0.65, 0.4)]
		var legs_v: Array = [Color(0.3, 0.3, 0.35), Color(0.55, 0.45, 0.3), Color(0.25, 0.4, 0.5), Color(0.6, 0.35, 0.4), Color(0.35, 0.45, 0.6)]
		var hairs_v: Array = [Color(0.12, 0.1, 0.08), Color(0.85, 0.7, 0.4), Color(0.6, 0.3, 0.15), Color(0.75, 0.72, 0.7), Color(0.4, 0.2, 0.35)]
		top_col = tops_v[outfit_idx % tops_v.size()]
		leg_col = legs_v[outfit_idx % legs_v.size()]
		hair_col = hairs_v[outfit_idx % hairs_v.size()]
	# v1.4: skin tones vary across the town too (the old build used
	# one SKIN constant for all 48 people).
	var skin_tones: Array = [Color(0.96, 0.76, 0.60), Color(0.89, 0.63, 0.46), Color(0.74, 0.50, 0.35), Color(0.56, 0.37, 0.25), Color(0.98, 0.83, 0.69)]
	var tone_off: int = {"woman": 0, "kid": 2, "dogwalker": 3, "shopkeeper": 1}.get(npc_type, 4)
	skin_col = skin_tones[(outfit_idx + tone_off) % skin_tones.size()]
	hair_col_v = hair_col
	var s: float = body_h / 1.7 # scale factor (kid smaller)
	mscale = s
	# ---- Legs: two-segment (thigh + shin), shaped lofts ----
	var thigh_col: Color = leg_col
	var shin_col: Color = leg_col
	var shoe_col := Color(0.92, 0.92, 0.92)
	var cuff_col := Color(0, 0, 0, 0)
	var bare_shin: bool = false
	if npc_type == "kid":
		thigh_col = Color(0.16, 0.24, 0.48) # navy patched shorts
		shin_col = skin_col # bare kid legs
		bare_shin = true
		shoe_col = Color(0.15, 0.65, 0.68) # teal sneakers
	elif npc_type == "woman":
		cuff_col = Color(0.55, 0.65, 0.82) # rolled jean cuffs
	elif npc_type == "shopkeeper":
		shoe_col = Color(0.35, 0.25, 0.18)
	elif npc_type == "poundworker":
		shoe_col = Color(0.25, 0.25, 0.28) # dark work shoes under the white uniform
	var leg_pair_l: Array = _build_leg(model, -0.14 * s, s, thigh_col, shin_col, shoe_col, cuff_col, bare_shin)
	var leg_pair_r: Array = _build_leg(model, 0.14 * s, s, thigh_col, shin_col, shoe_col, cuff_col, bare_shin)
	leg_l = leg_pair_l[0]
	shin_l = leg_pair_l[1]
	leg_r = leg_pair_r[0]
	shin_r = leg_pair_r[1]
	# ---- Pelvis + torso: ONE lofted garment shape each ----
	_loft(model, [
		[Vector3(0, 0.79 * s, 0), 0.265 * s, 0.195 * s],
		[Vector3(0, 0.90 * s, 0), 0.30 * s, 0.215 * s],
		[Vector3(0, 1.01 * s, 0), 0.28 * s, 0.20 * s]], _mat_fabric(leg_col.lightened(0.3)), 12)
	var belly: float = 1.16 if npc_type == "shopkeeper" else 1.0
	_loft(model, [
		[Vector3(0, 0.94 * s, 0), 0.285 * s, 0.205 * s * belly],
		[Vector3(0, 1.06 * s, 0), 0.315 * s, 0.22 * s * belly],
		[Vector3(0, 1.20 * s, 0), 0.295 * s, 0.205 * s * belly],
		[Vector3(0, 1.36 * s, 0), 0.335 * s, 0.225 * s * belly],
		[Vector3(0, 1.48 * s, 0), 0.35 * s, 0.215 * s * belly],
		[Vector3(0, 1.565 * s, 0), 0.185 * s, 0.145 * s]], _mat_fabric(top_col.lightened(0.3)), 12)
	var belt := _cyl(model, Vector3(0, 0.99 * s, 0), 0.295 * s, 0.295 * s, 0.075 * s, leg_col.darkened(0.35))
	belt.scale = Vector3(1, 1, 0.71)
	_box(model, Vector3(0, 0.99 * s, 0.215 * s), Vector3(0.12, 0.07, 0.03), Color(0.85, 0.7, 0.3)) # belt buckle
	var neck_mi := _cyl(model, Vector3(0, 1.60 * s, 0), 0.082 * s, 0.098 * s, 0.2 * s, skin_col)
	neck_mi.material_override = _mat_skin(skin_col)
	# Shoulders: soft balls where the arms join.
	for shx in [-0.335, 0.335]:
		var sh := _sphere(model, Vector3(shx * s, 1.47 * s, 0), Vector3(0.175 * s, 0.155 * s, 0.165 * s), top_col)
		sh.material_override = _mat_fabric(top_col.lightened(0.3))
	# ---- Torso dressing per type ----
	if npc_type == "kid":
		_front_panel(model, 0.222 * s, 1.27 * s, 0.99 * s, 0.52, _mat_fabric(Color(0.95, 0.55, 0.15))) # orange pocket panel
		_box(model, Vector3(0, 1.15 * s, 0.228 * s), Vector3(0.11, 0.11, 0.02), Color(0.98, 0.8, 0.25)) # star on pocket
		_sphere(model, Vector3(0, 1.52 * s, -0.17 * s), Vector3(0.3 * s, 0.24 * s, 0.18 * s), Color(0.45, 0.25, 0.72)) # hood behind head
	if npc_type == "dogwalker":
		# White tee showing at the front of the open overshirt
		_front_panel(model, 0.228 * s, 1.47 * s, 1.05 * s, 0.5, _mat_fabric(Color(0.96, 0.95, 0.92)))
		# Brown messenger bag + diagonal strap (sheet design)
		var strap := _box(model, Vector3(0.05 * s, 1.28 * s, 0.20 * s), Vector3(0.09, 0.62 * s, 0.04), Color(0.45, 0.3, 0.18))
		strap.rotation_degrees = Vector3(0, 0, 38)
		_box(model, Vector3(0.34 * s, 1.02 * s, 0.1 * s), Vector3(0.3, 0.34, 0.14), Color(0.55, 0.38, 0.22))
		_box(model, Vector3(0.34 * s, 1.16 * s, 0.12 * s), Vector3(0.32, 0.15, 0.15), Color(0.48, 0.32, 0.19)) # bag flap
	if extra == "apron_cap":
		# Apron: a curved panel on the torso, not a flat box.
		_front_panel(model, 0.238 * s, 1.44 * s, 0.80 * s, 0.85, _mat_fabric(Color(0.2, 0.45, 0.3)))
		_box(model, Vector3(0, 1.47 * s, 0.16 * s), Vector3(0.3 * s, 0.05, 0.03), Color(0.2, 0.45, 0.3)) # apron neck strap
		# Cat face ON the apron (sheet design): pale muzzle + ears + eyes
		_sphere(model, Vector3(0, 1.24 * s, 0.252 * s), Vector3(0.17, 0.15, 0.04), Color(0.95, 0.88, 0.7))
		for ex in [-0.09, 0.09]:
			_box(model, Vector3(ex * s, 1.38 * s, 0.245 * s), Vector3(0.07, 0.08, 0.03), Color(0.95, 0.88, 0.7))
			_sphere(model, Vector3(ex * s, 1.26 * s, 0.262 * s), Vector3(0.025, 0.035, 0.015), Color(0.15, 0.12, 0.1))
		# Paper shopping bag with a cat face, held in front (sheet design)
		_box(model, Vector3(0, 0.82 * s, 0.34 * s), Vector3(0.42, 0.44, 0.2), Color(0.85, 0.72, 0.52))
		_sphere(model, Vector3(0, 0.86 * s, 0.45 * s), Vector3(0.13, 0.11, 0.03), Color(0.5, 0.35, 0.2))
		for ex2 in [-0.07, 0.07]:
			_sphere(model, Vector3(ex2 * s, 0.89 * s, 0.47 * s), Vector3(0.02, 0.028, 0.012), Color(0.2, 0.15, 0.1))
	if npc_type == "poundworker":
		# Uniform dressing: a teal chest patch + a hi-vis band, so
		# he reads as ANIMAL CONTROL, not a pedestrian who happens
		# to be wearing white. Curved panels hug the torso loft.
		_front_panel(model, 0.238 * s, 1.40 * s, 1.29 * s, 0.30, _mat_fabric(Color(0.15, 0.55, 0.6)))
		_front_panel(model, 0.232 * s, 1.12 * s, 1.05 * s, 0.62, _mat(Color(0.80, 0.85, 0.90), 0.45))
	if npc_type == "woman":
		_sphere(model, Vector3(0, 1.44 * s, 0.2 * s), Vector3(0.045, 0.045, 0.03), Color(0.9, 0.72, 0.25)) # necklace pendant
		# Phone in front (sheet: she's looking at her phone)
		phone_mis.append(_box(model, Vector3(0, 1.18 * s, 0.3 * s), Vector3(0.16, 0.26, 0.04), Color(0.12, 0.13, 0.16)))
		phone_mis.append(_box(model, Vector3(0, 1.18 * s, 0.325 * s), Vector3(0.13, 0.22, 0.015), Color(0.55, 0.75, 0.9))) # phone screen glow
		# Cat-face crossbody bag (sheet design): strap + ears + face
		var strap2 := _box(model, Vector3(-0.08 * s, 1.3 * s, 0.2 * s), Vector3(0.07, 0.6 * s, 0.035), Color(0.6, 0.45, 0.3))
		strap2.rotation_degrees = Vector3(0, 0, -35)
		_box(model, Vector3(0.34 * s, 1.02 * s, 0.16 * s), Vector3(0.26, 0.26, 0.1), Color(0.88, 0.75, 0.57))
		for ex3 in [-0.08, 0.08]:
			_box(model, Vector3((0.34 + ex3) * s, 1.17 * s, 0.17 * s), Vector3(0.07, 0.08, 0.05), Color(0.88, 0.75, 0.57)) # bag ears
			_sphere(model, Vector3((0.34 + ex3 * 0.7) * s, 1.05 * s, 0.22 * s), Vector3(0.02, 0.028, 0.012), Color(0.2, 0.15, 0.1)) # bag eyes
		_sphere(model, Vector3(0.34 * s, 1.0 * s, 0.22 * s), Vector3(0.025, 0.018, 0.012), Color(0.95, 0.5, 0.55)) # bag nose
		for wx in [-1.0, 1.0]:
			for wi in range(2):
				var wh := _box(model, Vector3((0.34 + wx * 0.13) * s, (1.03 - float(wi) * 0.05) * s, 0.225 * s), Vector3(0.11, 0.012, 0.01), Color(0.35, 0.28, 0.2))
				wh.rotation_degrees = Vector3(0, 0, wx * (8.0 + float(wi) * 7.0))
	# ---- Arms: tapered lofts + shaped hands ----
	arm_l = _build_arm(model, -0.36 * s, s, top_col, npc_type == "kid")
	arm_r = _build_arm(model, 0.36 * s, s, top_col, npc_type == "kid")
	hand_r_mi = last_hand_mi
	arm_l.rotation.z = 0.1
	arm_r.rotation.z = -0.1
	_box(arm_l, Vector3(0, -0.52 * s, 0.05), Vector3(0.13, 0.07, 0.13), Color(0.25, 0.25, 0.3)) # wristwatch
	_sphere(arm_l, Vector3(0, -0.52 * s, 0.1), Vector3(0.045, 0.045, 0.02), Color(0.85, 0.9, 0.95)) # watch face
	# v0.9: the TREAT lives in the right hand — a little round biscuit
	# with choc chips, invisible until the treat moment.
	treat_mi = _sphere(arm_r, Vector3(0, -0.68 * s - 0.04, 0.1), Vector3(0.1, 0.035, 0.1), Color(0.78, 0.58, 0.32))
	_sphere(treat_mi, Vector3(0.3, -0.7, 0.2), Vector3(0.2, 0.3, 0.2), Color(0.3, 0.18, 0.1)) # choc chips (children: they hide with the treat)
	_sphere(treat_mi, Vector3(-0.4, -0.7, -0.1), Vector3(0.18, 0.3, 0.18), Color(0.3, 0.18, 0.1))
	treat_mi.visible = false
	if npc_type == "poundworker":
		_build_net(s) # POUND VAN: his catch net rides in his right hand
	# ---- Head: ONE lofted shape — jaw, cheeks and crown in a
	# single surface, no sphere-with-bits-glued-on. ----
	head_node = Node3D.new()
	head_node.position = Vector3(0, 1.72 * s, 0)
	model.add_child(head_node)
	_loft(head_node, [
		[Vector3(0, -0.265 * s, 0), 0.072 * s, 0.066 * s],
		[Vector3(0, -0.20 * s, 0), 0.152 * s, 0.140 * s],
		[Vector3(0, -0.12 * s, 0), 0.196 * s, 0.180 * s],
		[Vector3(0, -0.02 * s, 0), 0.226 * s, 0.202 * s],
		[Vector3(0, 0.07 * s, 0), 0.229 * s, 0.205 * s],
		[Vector3(0, 0.15 * s, 0), 0.212 * s, 0.190 * s],
		[Vector3(0, 0.22 * s, 0), 0.168 * s, 0.150 * s],
		[Vector3(0, 0.26 * s, 0), 0.095 * s, 0.085 * s]], _mat_skin(skin_col), 14)
	for esx in [-1.0, 1.0]: # ears
		var ear_mi := _sphere(head_node, Vector3(esx * 0.222 * s, -0.01, 0), Vector3(0.062 * s, 0.09 * s, 0.044 * s), skin_col)
		ear_mi.material_override = _mat_skin(skin_col)
	# Eyes: white sclera + iris + pupil + sparkle, as before — but
	# now seated on the shaped face, with ONE base scale the
	# expression system returns to (the old code's resets used a
	# different, asymmetric scale and the eyes drifted).
	for sx in [-0.082, 0.082]:
		var eye_mi := _sphere(head_node, Vector3(sx * s, 0.03, 0.208 * s), eye_base_scale, Color(0.97, 0.96, 0.94))
		eye_mi.material_override = _mat(Color(0.97, 0.96, 0.94), 0.3)
		var iris_mi := _sphere(eye_mi, Vector3(0, 0, 0.6), Vector3(0.58, 0.62, 0.5), Color(0.35, 0.22, 0.12))
		iris_mi.material_override = _mat(Color(0.35, 0.22, 0.12), 0.2)
		_sphere(iris_mi, Vector3(0, 0, 0.55), Vector3(0.55, 0.58, 0.4), Color(0.05, 0.04, 0.03)) # pupil
		_sphere(eye_mi, Vector3(0.3, 0.32, 0.7), Vector3(0.2, 0.2, 0.2), Color.WHITE) # sparkle
		if sx < 0.0:
			eye_l_mi = eye_mi
		else:
			eye_r_mi = eye_mi
		# Brows: soft bars in the person's own hair colour.
		var brow := _sphere(head_node, Vector3(sx * s, 0.138 * s, 0.196 * s), Vector3(0.108, 0.031, 0.026), hair_col_v)
		brow.material_override = _mat(hair_col_v, 0.9)
		if sx < 0.0:
			brow_l = brow
			brow_base_l = brow.position
		else:
			brow_r = brow
			brow_base_r = brow.position
	var nose_mi := _sphere(head_node, Vector3(0, -0.035, 0.206 * s), Vector3(0.05, 0.058, 0.036), skin_col)
	nose_mi.material_override = _mat_skin(skin_col.lerp(Color(0.92, 0.52, 0.42), 0.28))
	for sx in [-1.0, 1.0]:
		var cheek := _sphere(head_node, Vector3(sx * 0.155 * s, -0.075 * s, 0.176 * s), cheek_base_scale, Color(0.97, 0.60, 0.56))
		cheek.material_override = _mat(Color(0.97, 0.60, 0.56), 0.8)
		if sx < 0.0:
			cheek_l_mi = cheek
			cheek_base_l = cheek.position
		else:
			cheek_r_mi = cheek
			cheek_base_r = cheek.position
	_build_mouths(s)
	# ---- Hair: a shaped dome seated back on the head (its front
	# edge dips into the head, so the hairline is clean), plus the
	# style pieces per type / variant. ----
	var hair_mat: Material = _mat(hair_col_v, 0.95)
	var dome: Array = [
		[Vector3(0, 0.055 * s, -0.030 * s), 0.238 * s, 0.215 * s],
		[Vector3(0, 0.125 * s, -0.032 * s), 0.234 * s, 0.212 * s],
		[Vector3(0, 0.20 * s, -0.028 * s), 0.205 * s, 0.188 * s],
		[Vector3(0, 0.265 * s, -0.018 * s), 0.150 * s, 0.135 * s],
		[Vector3(0, 0.30 * s, -0.008 * s), 0.055 * s, 0.05 * s]]
	if outfit_idx > 0 and npc_type != "shopkeeper":
		match outfit_idx % 3:
			1: # baseball cap
				_loft(head_node, dome, _mat(top_col.darkened(0.15), 0.9), 14)
				var brim := _cyl(head_node, Vector3(0, 0.135 * s, 0.09 * s), 0.20 * s, 0.20 * s, 0.028, top_col.darkened(0.15))
				brim.scale = Vector3(1.1, 1, 1.45)
			2: # ponytail
				_loft(head_node, dome, hair_mat, 14)
				_sphere(head_node, Vector3(0, 0.26 * s, -0.17 * s), Vector3(0.15, 0.13, 0.15), hair_col_v)
				_loft(head_node, [
					[Vector3(0, 0.24 * s, -0.20 * s), 0.082 * s, 0.082 * s],
					[Vector3(0, 0.02 * s, -0.245 * s), 0.066 * s, 0.066 * s],
					[Vector3(0, -0.24 * s, -0.26 * s), 0.045 * s, 0.045 * s]], hair_mat, 10)
			_: # curly puffs over a low dome
				_loft(head_node, dome, hair_mat, 14)
				for ci in range(6):
					var ca: float = float(ci) * 1.05
					_sphere(head_node, Vector3(cos(ca) * 0.13 * s, 0.24 * s + 0.04 * sin(float(ci) * 2.3), sin(ca) * 0.13 * s - 0.02), Vector3(0.13, 0.12, 0.13), hair_col_v)
	elif extra == "apron_cap":
		# The shopkeeper's flat cap + brim.
		_loft(head_node, [
			[Vector3(0, 0.10 * s, -0.01), 0.248 * s, 0.228 * s],
			[Vector3(0, 0.155 * s, -0.01), 0.242 * s, 0.222 * s],
			[Vector3(0, 0.205 * s, -0.01), 0.195 * s, 0.180 * s]], _mat(Color(0.45, 0.32, 0.18), 0.9), 14)
		var brim2 := _cyl(head_node, Vector3(0, 0.135 * s, 0.085 * s), 0.205 * s, 0.205 * s, 0.028, Color(0.45, 0.32, 0.18))
		brim2.scale = Vector3(1.1, 1, 1.45)
		# Curved moustache halves under the nose
		for ex in [-0.08, 0.08]:
			var mo := _sphere(head_node, Vector3(ex * 0.55 * s, -0.052 * s, 0.20 * s), Vector3(0.115, 0.038, 0.03), Color(0.3, 0.2, 0.12))
			mo.rotation_degrees = Vector3(0, 0, ex * -160.0)
	elif extra == "poundcap":
		# The pound worker's white uniform cap + brim + teal badge.
		_loft(head_node, [
			[Vector3(0, 0.10 * s, -0.01), 0.248 * s, 0.228 * s],
			[Vector3(0, 0.155 * s, -0.01), 0.242 * s, 0.222 * s],
			[Vector3(0, 0.205 * s, -0.01), 0.195 * s, 0.180 * s]], _mat_fabric(Color(0.96, 0.96, 0.94)), 14)
		var pbrim := _cyl(head_node, Vector3(0, 0.135 * s, 0.085 * s), 0.205 * s, 0.205 * s, 0.028, Color(0.96, 0.96, 0.94))
		pbrim.scale = Vector3(1.1, 1, 1.45)
		pbrim.material_override = _mat_fabric(Color(0.96, 0.96, 0.94))
		var pbadge := _sphere(head_node, Vector3(0, 0.155 * s, 0.205 * s), Vector3(0.05, 0.05, 0.02), Color(0.15, 0.55, 0.6))
		pbadge.material_override = _mat(Color(0.15, 0.55, 0.6), 0.5)
	elif extra == "bun":
		_loft(head_node, dome, hair_mat, 14)
		_sphere(head_node, Vector3(0, 0.205 * s, 0.148 * s), Vector3(0.40, 0.125, 0.15), hair_col_v) # soft fringe
		_sphere(head_node, Vector3(-0.17 * s, 0.02, -0.02), Vector3(0.15, 0.28, 0.28), hair_col_v) # side volume
		_sphere(head_node, Vector3(0.17 * s, 0.02, -0.02), Vector3(0.15, 0.28, 0.28), hair_col_v)
		_sphere(head_node, Vector3(0, 0.335 * s, -0.09 * s), Vector3(0.21, 0.19, 0.21), hair_col_v) # the bun
	elif extra == "messy":
		_loft(head_node, dome, hair_mat, 14)
		for i in range(3):
			_sphere(head_node, Vector3((-0.16 + float(i) * 0.16) * s, 0.25 * s, -0.05), Vector3(0.13, 0.13, 0.13), hair_col_v) # tufts
		for fx in [-0.14, -0.1, 0.1, 0.14]:
			_sphere(head_node, Vector3(fx * s, -0.06 * s, 0.198 * s), Vector3(0.014, 0.014, 0.01), Color(0.72, 0.5, 0.35)) # freckles
	else:
		_loft(head_node, dome, hair_mat, 14)
		if npc_type == "dogwalker":
			for hx in [-0.13, 0.0, 0.13]:
				_sphere(head_node, Vector3(hx * s, 0.235 * s, -0.02), Vector3(0.17, 0.15, 0.3), hair_col_v) # wavy top
	if outfit_idx == 2 and npc_type == "woman":
		# a swishy skirt over the jeans: a flared loft, not a cone
		_loft(model, [
			[Vector3(0, 0.99 * s, 0), 0.275 * s, 0.205 * s],
			[Vector3(0, 0.86 * s, 0), 0.335 * s, 0.255 * s],
			[Vector3(0, 0.70 * s, 0), 0.405 * s, 0.305 * s],
			[Vector3(0, 0.58 * s, 0), 0.445 * s, 0.335 * s]], _mat_fabric(top_col.darkened(0.05).lightened(0.3)), 12)
	if outfit_idx == 1 and npc_type == "pedestrian":
		# backpack with a bedroll
		_box(model, Vector3(0, 1.25 * s, -0.3 * s), Vector3(0.44 * s, 0.56 * s, 0.2), Color(0.8, 0.35, 0.25))
		_cyl(model, Vector3(0, 1.6 * s, -0.3 * s), 0.09, 0.09, 0.46 * s, Color(0.35, 0.55, 0.7)).rotation_degrees = Vector3(0, 0, 90)
	if npc_type == "dogwalker":
		_build_dog()
		if dog_model:
			_box(dog_model, Vector3(0, 0.38, 0.55), Vector3(0.09, 0.04, 0.1), Color(0.95, 0.5, 0.55)) # dog tongue
			_sphere(dog_model, Vector3(0.1, 0.3, -0.3), Vector3(0.2, 0.18, 0.2), Color(0.97, 0.95, 0.9)) # extra fluff
			_sphere(dog_model, Vector3(-0.12, 0.52, 0.05), Vector3(0.2, 0.18, 0.2), Color(0.97, 0.95, 0.9))
	if npc_type == "woman" or npc_type == "pedestrian":
		hold_pose = true

	# Labels (billboarded, always face the camera)
	# NO NAME TITLES (Michael, 2026-11-17): the floating display-name
	# title over every person's head is gone — he asked for them
	# removed. name_label stays declared (null) because the distance
	# visibility toggles and some test harnesses reference it behind
	# null checks. What remains overhead is gameplay only: the notice
	# / GRAB bar below and the speech bubble.
	notice_label = Label3D.new()
	notice_label.text = ""
	notice_label.font_size = 44
	notice_label.pixel_size = 0.009
	notice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	notice_label.position = Vector3(0, body_h + 1.12, 0)
	notice_label.modulate = Color(1.0, 0.85, 0.3)
	notice_label.outline_size = 8
	add_child(notice_label)
	# The meter itself (see BAR CLEANUP note at the declarations):
	# three flat quads on one root — a near-black frame, a dark
	# track, and the yellow fill whose width _set_bar scales. The
	# root yaw-faces the camera in _set_bar, so the quads need no
	# billboard shader and the fill scale behaves plainly.
	bar_root = Node3D.new()
	bar_root.position = Vector3(0, body_h + 0.60, 0)
	bar_root.visible = false
	add_child(bar_root)
	var bar_frame := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(BAR_W + 0.08, BAR_H + 0.08)
	bar_frame.mesh = fq
	bar_frame.material_override = _bar_material(Color(0.03, 0.03, 0.05, 0.92))
	bar_root.add_child(bar_frame)
	var bar_track := MeshInstance3D.new()
	var tq := QuadMesh.new()
	tq.size = Vector2(BAR_W, BAR_H)
	bar_track.mesh = tq
	bar_track.position.z = 0.006
	bar_track.material_override = _bar_material(Color(0.23, 0.20, 0.16, 0.95))
	bar_root.add_child(bar_track)
	bar_fill = MeshInstance3D.new()
	var iq := QuadMesh.new()
	iq.size = Vector2(1.0, BAR_H - 0.06)
	bar_fill.mesh = iq
	bar_fill.position.z = 0.012
	bar_fill.material_override = _bar_material(Color(1.0, 0.85, 0.3))
	bar_root.add_child(bar_fill)
	# Speech bubble for the joyful "Oh, a cat!" moment (v0.6)
	bubble_label = Label3D.new()
	bubble_label.text = ""
	bubble_label.font_size = 48
	bubble_label.pixel_size = 0.0075 # v1.2: speech bubbles readable too
	bubble_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble_label.position = Vector3(0, body_h + 1.78, 0)
	bubble_label.modulate = Color(1.0, 0.98, 0.88)
	bubble_label.outline_size = 12
	bubble_label.outline_modulate = Color(0.35, 0.2, 0.1)
	bubble_label.visible = false
	add_child(bubble_label)
	_attach_meshy() # v1.0.15 MESHY NPC SWAP: hang the imported model on this ghost (no-op for types without one)


# POUND VAN: the animal-control catch net — modelled on
# Michael's reference photo of a REAL landing net (2026-11-18):
# a LONG silver pole gripped in the right hand, a rounded-
# RECTANGLE frame (wider than tall) mounted at the pole's end
# on a short yoke and TILTED ~26 degrees to the pole, and a
# DEEP bag of dark hexagonal/diamond mesh hanging BEHIND the
# frame — side walls of woven strands converging to a gathered
# bottom, so the bag has visible depth from any three-quarter
# view. Two earlier builds failed him: a translucent sphere
# ("a stick and a circle and a circle of white") and a round
# hoop with a spiral web that read face-on as a satellite
# dish. This one is rectangular, angled, deep and dark, like
# the photo. He holds it TWO-HANDED on the chase (see
# update_net_grip). Everything hangs off a root on arm_r, so
# the net swings as he walks and aims with the arm. Main hides
# it while he carries the cat / hosts the escape room
# (set_net_visible).
func _build_net(s: float) -> void:
	net_root = Node3D.new()
	arm_r.add_child(net_root)
	# Rubber grip where the right hand holds, then the long
	# aluminium shaft with its two dark telescoping bands.
	var grip := _cyl(net_root, Vector3(0, -0.74 * s, 0.01), 0.030 * s, 0.030 * s, 0.30 * s, Color(0.16, 0.15, 0.14))
	grip.material_override = _mat(Color(0.16, 0.15, 0.14), 0.95)
	var pole := _cyl(net_root, Vector3(0, -1.32 * s, 0.01), 0.019 * s, 0.019 * s, 0.92 * s, Color(0.66, 0.68, 0.72))
	pole.material_override = _mat(Color(0.66, 0.68, 0.72), 0.35)
	for band_y in [-1.04, -1.52]:
		var band := _cyl(net_root, Vector3(0, band_y * s, 0.01), 0.0235 * s, 0.0235 * s, 0.055 * s, Color(0.13, 0.13, 0.14))
		band.material_override = _mat(Color(0.13, 0.13, 0.14), 0.6)
	# Ferrule collar where the shaft meets the head yoke.
	var ferrule := _cyl(net_root, Vector3(0, -1.80 * s, 0.01), 0.030 * s, 0.030 * s, 0.09 * s, Color(0.25, 0.26, 0.29))
	ferrule.material_override = _mat(Color(0.25, 0.26, 0.29), 0.4)
	# The head: frame + bag on a tilted root at the pole's end.
	var head := Node3D.new()
	head.position = Vector3(0, -1.86 * s, 0.01)
	head.rotation.x = 0.45 # ~26 degrees: the frame angles off the pole, top edge leaning out like the photo
	net_root.add_child(head)
	# Yoke strut: from the pole end up to the frame's bottom edge.
	var yoke := _cyl(head, Vector3(0, 0, -0.075 * s), 0.020 * s, 0.020 * s, 0.21 * s, Color(0.20, 0.20, 0.22))
	yoke.rotation_degrees.x = 90.0
	yoke.material_override = _mat(Color(0.20, 0.20, 0.22), 0.45)
	# The frame itself: a rounded-rectangle tube, dark metal.
	var ring := _rounded_rect_points(0.32 * s, 0.215 * s, 0.095 * s, 9)
	var frame := MeshInstance3D.new()
	frame.mesh = _tube_mesh(ring, 0.0165 * s, 6)
	frame.material_override = _mat(Color(0.17, 0.17, 0.19), 0.45)
	head.add_child(frame)
	# The deep woven bag behind the frame.
	var bag := MeshInstance3D.new()
	bag.mesh = _net_bag_mesh(s, ring)
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(0.13, 0.13, 0.145) # dark charcoal mesh, like the photo — never a pale disc
	nm.roughness = 0.95
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bag.material_override = nm
	head.add_child(bag)
	# The gathered knot at the bag's bottom.
	_sphere(head, Vector3(0, 0.80 * s, -0.075 * s), Vector3(0.035 * s, 0.05 * s, 0.035 * s), Color(0.13, 0.13, 0.145))

# Points around a rounded rectangle in the XZ plane (x =
# half-width a, z = half-height b, corner radius r), CCW,
# per_corner points per corner arc. Consecutive points join
# into the straight edges on their own.
func _rounded_rect_points(a: float, b: float, r: float, per_corner: int) -> Array:
	var pts: Array = []
	var corners: Array = [
		[Vector2(a - r, b - r), 0.0],
		[Vector2(-(a - r), b - r), 90.0],
		[Vector2(-(a - r), -(b - r)), 180.0],
		[Vector2(a - r, -(b - r)), 270.0],
	]
	for ci in range(4):
		var c: Vector2 = corners[ci][0]
		var a0: float = float(corners[ci][1])
		for k in range(per_corner):
			var ang := deg_to_rad(a0 + 90.0 * float(k) / float(per_corner))
			pts.append(Vector3(c.x + r * cos(ang), 0, c.y + r * sin(ang)))
	return pts

# A tube of radius tr swept along a closed planar ring of
# points (ring plane = XZ, plane normal = +Y). One ArrayMesh.
func _tube_mesh(ring: Array, tr: float, radial: int) -> ArrayMesh:
	var n := ring.size()
	var verts: Array = []
	var normals: Array = []
	for i in range(n):
		var p: Vector3 = ring[i]
		var pn: Vector3 = ring[(i + 1) % n]
		var pp: Vector3 = ring[(i - 1 + n) % n]
		var tang := (pn - pp).normalized()
		var inplane := Vector3(0, 1, 0).cross(tang).normalized()
		for j in range(radial):
			var a0 := TAU * float(j) / float(radial)
			var a1 := TAU * float(j + 1) / float(radial)
			var d0 := inplane * cos(a0) + Vector3(0, 1, 0) * sin(a0)
			var d1 := inplane * cos(a1) + Vector3(0, 1, 0) * sin(a1)
			var q0: Vector3 = ring[i] + d0 * tr
			var q1: Vector3 = ring[i] + d1 * tr
			var r0: Vector3 = ring[(i + 1) % n] + d0 * tr
			var r1: Vector3 = ring[(i + 1) % n] + d1 * tr
			# NOTE: next-point ring verts reuse THIS point's frame —
			# close enough for a 16 mm tube and keeps it one strip.
			for v in [q0, r0, r1, q0, r1, q1]:
				verts.append(v)
			var nn := (d0 + d1).normalized()
			for k in range(6):
				normals.append(nn)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# One quad of net twine: a thin ribbon from a to b, width along wdir.
func _net_quad(verts: Array, normals: Array, a: Vector3, b: Vector3, wdir: Vector3, hw: float) -> void:
	var a1 := a - wdir * hw
	var a2 := a + wdir * hw
	var b1 := b - wdir * hw
	var b2 := b + wdir * hw
	var n := (b - a).cross(wdir)
	if n.length() < 0.000001:
		return
	n = n.normalized()
	for v in [a1, b1, b2, a1, b2, a2]:
		verts.append(v)
		normals.append(n)

# The DEEP net bag as a single ArrayMesh: the rim ring lies ON
# the frame (the same rounded-rect points) and the walls run
# BACK toward the handler (+Y in head space), shrinking level
# by level to a gathered bottom, with a growing downward sag
# so it hangs like a real net bag instead of a rigid cone.
# The weave is a DIAMOND lattice — every level connects to the
# next with both diagonals plus the ring strand — coarse dark
# twine that reads as hexagonal landing-net mesh at cover
# distance (~1700 tris, one draw call, no per-strand nodes).
func _net_bag_mesh(s: float, ring: Array) -> ArrayMesh:
	var depths: Array = [0.0, 0.15, 0.30, 0.44, 0.56, 0.66, 0.74, 0.79]
	var facs: Array = [1.0, 0.985, 0.94, 0.85, 0.69, 0.47, 0.20, 0.03]
	var sag: Array = [0.0, 0.010, 0.024, 0.038, 0.050, 0.060, 0.066, 0.068]
	var n := ring.size()
	var levels := depths.size()
	var pts: Array = []
	for l in range(levels):
		var ring_pts: Array = []
		for i in range(n):
			var rp: Vector3 = ring[i]
			ring_pts.append(Vector3(rp.x * float(facs[l]), float(depths[l]) * s, rp.z * float(facs[l]) - float(sag[l]) * s))
		pts.append(ring_pts)
	var verts: Array = []
	var normals: Array = []
	var hw := 0.0105 * s
	for l in range(levels):
		for i in range(n):
			var i2 := (i + 1) % n
			# Ring strand around this level (rim level is the frame itself).
			if l > 0:
				_net_quad(verts, normals, pts[l][i], pts[l][i2], Vector3(0, 1, 0), hw)
			if l < levels - 1:
				var tang2: Vector3 = (pts[l][i2] - pts[l][(i - 1 + n) % n]).normalized()
				# Meridian + both diagonals = the diamond weave.
				_net_quad(verts, normals, pts[l][i], pts[l + 1][i], tang2, hw)
				_net_quad(verts, normals, pts[l][i], pts[l + 1][i2], tang2, hw)
				_net_quad(verts, normals, pts[l][i2], pts[l + 1][i], tang2, hw)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# POUND VAN: TWO HANDS on the pole. The right hand grips at
# the butt (the net root rides arm_r); this slides the LEFT
# hand up the shaft to the pole point that sits one arm's
# reach from the left shoulder — a real two-handed landing-net
# carry. Called every frame while he chases with the net out,
# and by the splash harness for the cover pose.
func update_net_grip() -> void:
	if net_root == null or arm_l == null or arm_r == null or model == null:
		return
	var s := mscale
	var best := Vector3.ZERO
	var best_err := 1e9
	for t in [0.98, 1.08, 1.18, 1.28, 1.38, 1.50, 1.62]:
		var p: Vector3 = arm_r.transform * Vector3(0, -t * s, 0.01)
		var err := absf(p.distance_to(arm_l.position) - 0.70 * s)
		if err < best_err:
			best_err = err
			best = p
	if best_err < 0.14 * s:
		_aim_arm(arm_l, model.to_global(best))

func set_net_visible(v: bool) -> void:
	if net_root:
		net_root.visible = v

func _build_dog() -> void:
	# Leash: thin dark line from the walker's hand down to the dog's collar
	var leash := _cyl(model, Vector3(0.55, 0.95, 0.35), 0.016, 0.016, 1.05, Color(0.25, 0.2, 0.16))
	leash.rotation_degrees = Vector3(18, 0, 48)
	dog_model = Node3D.new()
	dog_model.position = Vector3(0.78, 0, 0.45)
	dog_model.scale = Vector3(1.15, 1.15, 1.15)
	add_child(dog_model)
	var w := Color(0.97, 0.95, 0.9)
	_sphere(dog_model, Vector3(0, 0.34, 0), Vector3(0.34, 0.3, 0.55), w)
	# Fluffy look (sheet: small white FLOOF) — overlapping puffs
	_sphere(dog_model, Vector3(0.14, 0.42, -0.1), Vector3(0.26, 0.24, 0.3), w)
	_sphere(dog_model, Vector3(-0.13, 0.4, 0.08), Vector3(0.24, 0.22, 0.28), w)
	_sphere(dog_model, Vector3(0, 0.26, -0.24), Vector3(0.26, 0.22, 0.24), w)
	_sphere(dog_model, Vector3(0, 0.48, 0.32), Vector3(0.3, 0.28, 0.3), w)
	_sphere(dog_model, Vector3(-0.14, 0.58, 0.26), Vector3(0.16, 0.14, 0.16), w) # head fluff
	_sphere(dog_model, Vector3(0.14, 0.58, 0.26), Vector3(0.16, 0.14, 0.16), w)
	_sphere(dog_model, Vector3(0, 0.4, 0.46), Vector3(0.16, 0.12, 0.14), Color(0.95, 0.88, 0.78))
	_box(dog_model, Vector3(0, 0.44, 0.52), Vector3(0.07, 0.05, 0.04), Color(0.15, 0.12, 0.12))
	for sx in [-0.1, 0.1]:
		_sphere(dog_model, Vector3(sx, 0.52, 0.4), Vector3(0.06, 0.07, 0.04), Color(0.1, 0.1, 0.1))
		var ear := _sphere(dog_model, Vector3(sx * 1.5, 0.52, 0.28), Vector3(0.09, 0.16, 0.06), Color(0.9, 0.82, 0.68))
		ear.rotation_degrees = Vector3(0, 0, sx * 60.0)
	_cyl(dog_model, Vector3(0, 0.32, 0.3), 0.13, 0.13, 0.07, Color(0.25, 0.6, 0.65)).rotation_degrees = Vector3(90, 0, 0) # teal collar
	for lx in [-0.11, 0.11]:
		for lz in [-0.18, 0.18]:
			var pivot := Node3D.new()
			pivot.position = Vector3(lx, 0.26, lz)
			dog_model.add_child(pivot)
			_cyl(pivot, Vector3(0, -0.12, 0), 0.04, 0.035, 0.26, w)
			dog_legs.append(pivot)
	dog_tail = Node3D.new()
	dog_tail.position = Vector3(0, 0.42, -0.28)
	dog_model.add_child(dog_tail)
	_cyl(dog_tail, Vector3(0, 0.09, -0.03), 0.03, 0.045, 0.22, w)
	dog_tail.rotation_degrees = Vector3(-35, 0, 0)

func _pick_wander_target() -> void:
	wander_target = Vector3(randf_range(-112.0, wander_x_max), 0, randf_range(-84.0, 84.0)) # MAP DOUBLING: wander range covers the east district too (wander_x_max = 366; BISECT: 112 in legacy mode)
	wander_wait = randf_range(0.0, 1.5)

func _physics_process(delta: float) -> void:
	if not active or main_ref == null or player_ref == null:
		velocity = Vector3.ZERO
		return
	# --- PERF (post-v1.0.1): DISTANCE THROTTLE -----------------------
	# Measured before this change: the 22 NPC brains + bodies were
	# ~93% of all physics CPU (11.0ms -> 0.84ms per frame with NPC
	# physics off), because every neighbour ran its full brain —
	# including the 41-house line-of-sight loop — on every one of the
	# 120 ticks a second, wherever it was on the map. Now: within 35m of
	# the cat the brain runs at FULL rate, exactly as before. Beyond
	# that, a wandering neighbour's brain runs at 1/3 rate (35-80m) or
	# 1/12 rate (80m+), with skipped deltas BANKED so the executed
	# tick advances by the full elapsed time — movement speed, timers
	# and cooldowns keep their exact wall-clock rates, only the
	# update granularity coarsens where nobody can see it. An ENGAGED
	# neighbour is NEVER throttled: chasing, pursuing, in the RUN
	# tell, mid pet/treat interaction, or with any notice built up
	# (a grabber's meter only builds within its ~11m sight radius,
	# i.e. always inside the full-rate zone anyway). Beyond ~85m the
	# model + name label are also hidden (a 1.7m person is ~2% of the
	# screen height out there); hysteresis (show < 75m) keeps the
	# boundary from flickering, and visibility is re-evaluated on
	# every executed tick, so a neighbour is back on screen within a
	# tenth of a second of coming into range.
	var engaged_now: bool = mode == "chase" or mode == "pursue" or mode == "tell" or interact_state != "" or notice > 0.0
	_perf_accum += delta
	if _perf_skip > 0 and not engaged_now:
		_perf_skip -= 1
		return
	var pdist: float = global_position.distance_to(player_ref.global_position)
	var stride: int = 1
	if not engaged_now:
		if pdist > 80.0:
			stride = 12
		elif pdist > 35.0:
			stride = 3
	_perf_skip = stride - 1
	delta = _perf_accum
	_perf_accum = 0.0
	if model:
		if pdist > 85.0 and model.visible:
			model.visible = false
			if dog_model: dog_model.visible = false
			if name_label: name_label.visible = false
		elif pdist < 75.0 and not model.visible:
			model.visible = true
			if dog_model: dog_model.visible = true
			if name_label: name_label.visible = true
	if bubble_timer > 0.0:
		bubble_timer -= delta
		if bubble_timer <= 0.0 and bubble_label:
			bubble_label.visible = false
	if bubble_lock_t > 0.0:
		bubble_lock_t -= delta
	if expr_timer > 0.0:
		expr_timer -= delta
		if expr_timer <= 0.0 and (expression == "sad" or expression == "worried"):
			set_expression("neutral")
	# v0.9: bend marker decays as before; points no longer ride a
	# timer — they fire inside the petting sequence, on contact.
	if bend_t > 0.0:
		bend_t -= delta
	_update_hearts(delta)
	if main_ref.get("state") != "play":
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= 24.0 * delta
		move_and_slide()
		_animate(delta, 0.0)
		_update_labels()
		return
	var to_player: Vector3 = player_ref.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var player_hidden: bool = bool(player_ref.get("is_hidden"))
	var player_sprinting: bool = bool(player_ref.get("is_sprinting"))
	# v0.9: a friendly interaction in progress owns this NPC until
	# the sequence finishes (approach/bend/pet/treat/rise).
	if interact_state != "":
		_run_interaction(delta, dist, to_player)
		return
	if notice_cooldown > 0.0:
		notice_cooldown -= delta
	if interact_cooldown > 0.0:
		interact_cooldown -= delta
	if slowed_timer > 0.0:
		slowed_timer -= delta
	if mode == "tell":
		# RUN TELL: frozen in a crouch, arms wide, calling the cat —
		# the player's clear warning to sprint NOW.
		tell_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= 24.0 * delta
		else:
			velocity.y = -0.5
		move_and_slide()
		_animate(delta, 0.0)
		_update_labels()
		if tell_t <= 0.0:
			mode = "chase"
			set_expression("determined") # v1.4: focused, never angry
			if main_ref and main_ref.has_method("on_chase_started"):
				main_ref.on_chase_started(self)
		return
	var in_pursuit: bool = mode == "pursue"
	var in_chase: bool = mode == "chase" or in_pursuit
	var sight_radius: float = detect_radius + (7.0 if in_pursuit else 0.0)
	has_los_now = _has_line_of_sight()
	var can_see: bool = dist < sight_radius and not player_hidden and has_los_now
	if npc_type == "dogwalker":
		bark_timer -= delta
		if dist < 9.0 and not player_hidden and bark_timer <= 0.0:
			bark_timer = 3.0
			if not in_chase and notice_cooldown <= 0.0 and role == "grabber": # v0.8: barks only feed the GRABBER's meter now
				notice = min(0.85, notice + 0.06)
			if main_ref.has_method("on_dog_bark"):
				main_ref.on_dog_bark(global_position)
	if in_chase:
		# CAPTURE = catch the cat and HOLD grab range for grab_needed
		# seconds. Getting close is not enough any more.
		notice = 1.0
		if not bool(player_ref.call("is_on_floor")):
			# The cat just hopped something (fence etc.): the pursuer
			# has to scramble at the obstacle and loses ground.
			slowed_timer = maxf(slowed_timer, 0.9)
		if dist <= grab_range and not player_hidden:
			grab_progress += delta
		else:
			grab_progress = maxf(0.0, grab_progress - 0.3 * delta)
		if grab_progress >= grab_needed:
			grab_progress = 0.0
			if main_ref.has_method("on_cat_taken"):
				main_ref.on_cat_taken(self)
			return
		if not in_pursuit:
			# The cat escapes the chase by getting far away (sustained)
			# or by breaking line of sight / hiding for 2 seconds.
			if dist > 6.5:
				far_timer += delta
			else:
				far_timer = 0.0
			if can_see:
				los_timer = 0.0
			else:
				los_timer += delta
			if far_timer >= 0.75 or los_timer >= 2.0:
				_end_chase()
	else:
		grab_progress = 0.0
		# v0.8 (item 5): the proximity notice meter is the GRABBER's
		# alone. Friendly and ignore NPCs gain NO notice from standing
		# near the cat, show NO bar, and never approach — friendly
		# people react only to a paw or a meow (react_to_attention).
		if can_see and notice_cooldown <= 0.0 and role == "grabber":
			var closeness: float = clampf(1.0 - dist / sight_radius, 0.0, 1.0)
			var rate: float = fill_rate * (0.35 + closeness * 0.95)
			if player_sprinting:
				rate *= 0.55 # a sprinting cat is harder to lock onto
			notice = minf(1.0, notice + rate * delta)
			if notice >= 0.5:
				_spot_cat() # face lights up JOY + "Oh, a cat!"
			if notice >= 1.0:
				_start_chase()
		else:
			notice = maxf(0.0, notice - 0.55 * delta) # fast decay when unseen
	# Movement
	var target_speed: float = walk_speed
	var dest: Vector3 = wander_target
	var chasing := false
	if mode == "pursue" or mode == "chase":
		# Corner-cutting: aim where the cat is HEADING, not where it is.
		dest = player_ref.global_position + (player_ref.get("velocity") as Vector3) * 0.22
		target_speed = effective_chase_speed()
		chasing = true
	elif notice > 0.15:
		dest = player_ref.global_position
		target_speed = walk_speed * 1.15
		chasing = true
	else:
		if global_position.distance_to(wander_target) < 1.6:
			wander_wait -= delta
			if wander_wait <= 0.0:
				_pick_wander_target()
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity.y -= 24.0 * delta
			move_and_slide()
			_animate(delta, 0.0)
			_update_labels()
			return
	var dir: Vector3 = dest - global_position
	dir.y = 0.0
	if dir.length() > 0.3:
		dir = dir.normalized()
		velocity.x = dir.x * target_speed
		velocity.z = dir.z * target_speed
		# Turn to face where we're walking (or toward the cat when close/curious)
		var face_dir: Vector3 = dir
		if chasing and dist < sight_radius:
			face_dir = to_player.normalized()
		var target_yaw: float = atan2(face_dir.x, face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, min(1.0, 8.0 * delta))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	global_position.x = clamp(global_position.x, -117.0, 369.0 if wide_bounds else 117.0)
	global_position.z = clamp(global_position.z, -89.0, 89.0)
	_animate(delta, Vector2(velocity.x, velocity.z).length())
	_update_labels()

func _animate(delta: float, speed2d: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	if speed2d > 0.3:
		walk_phase += delta * (4.0 + speed2d * 1.6)
		var swing: float = sin(walk_phase) * 0.55
		if leg_l: leg_l.rotation.x = swing
		if leg_r: leg_r.rotation.x = -swing
		# v1.4: the shin folds as its leg swings back — a real
		# knee bend in the walk cycle, not a swinging plank.
		if shin_l: shin_l.rotation.x = clampf(swing, 0.0, 1.0) * 0.55
		if shin_r: shin_r.rotation.x = clampf(-swing, 0.0, 1.0) * 0.55
		if arm_l: arm_l.rotation.x = -swing * 0.8
		if arm_r: arm_r.rotation.x = swing * 0.8
		if model: model.position.y = abs(sin(walk_phase)) * 0.04
	else:
		if leg_l: leg_l.rotation.x = lerp(leg_l.rotation.x, 0.0, min(1.0, 10.0 * delta))
		if leg_r: leg_r.rotation.x = lerp(leg_r.rotation.x, 0.0, min(1.0, 10.0 * delta))
		if shin_l: shin_l.rotation.x = lerp(shin_l.rotation.x, 0.0, min(1.0, 10.0 * delta))
		if shin_r: shin_r.rotation.x = lerp(shin_r.rotation.x, 0.0, min(1.0, 10.0 * delta))
		if arm_l: arm_l.rotation.x = lerp(arm_l.rotation.x, 0.0, min(1.0, 10.0 * delta))
		if arm_r: arm_r.rotation.x = lerp(arm_r.rotation.x, 0.0, min(1.0, 10.0 * delta))
		if model: model.position.y = sin(t * 2.0) * 0.012 # idle breathing bob
	# Phone pose: both hands up at the chest, holding the phone.
	if hold_pose and expression != "joy":
		if arm_l:
			arm_l.rotation.x = -0.92
			arm_l.rotation.z = 0.38
		if arm_r:
			arm_r.rotation.x = -0.92
			arm_r.rotation.z = -0.38
	# RUN TELL pose: crouched low, arms spread wide.
	if mode == "tell":
		if model:
			model.scale.y = lerpf(model.scale.y, 0.82, min(1.0, 10.0 * delta))
		if arm_l:
			arm_l.rotation.x = -0.7
			arm_l.rotation.z = 1.15
		if arm_r:
			arm_r.rotation.x = -0.7
			arm_r.rotation.z = -1.15
	elif model:
		# v1.4 ONE-KNEE KNEEL (Michael's direction, 2026-11-17:
		# "bend at the knee, not fold in half"). The descent is a
		# HIP DROP driven by the two-segment legs: left foot planted
		# forward (thigh near-horizontal, shin vertical), right
		# knee DOWN on the ground (thigh angled down-back, shin
		# folded flat behind it). The old Y-squash is gone entirely.
		# bend_a envelopes in/out with the interaction sequence, so
		# it never snaps.
		# v1.0.13 BEND FIX (Michael, v1.0.12 play: still "folding
		# in half a little bit"): two root causes. (1) The legs were
		# posed with a per-frame lerp that FOUGHT the idle branch's
		# lerp back to zero — the pair settled at 61% of target, so
		# the kneel never formed: full hip drop on half-bent legs
		# reads as a stooped lunge. The legs are now SET from
		# bend_a (this block runs after the walk/idle branch, so
		# the assignment wins; bend_a itself is smooth). (2) The
		# back stays UP: torso pitch 0.10 -> 0.03, head 0.28 ->
		# 0.24 — and the shoulder is held at its old world spot by
		# settling the model a touch deeper (0.407) and toward the
		# cat (0.104), so the petting hand lands exactly where it
		# did. The reach did not change; the back did.
		var kneeling: bool = interact_state == "bend" or interact_state == "pet" or interact_state == "treat"
		bend_a = move_toward(bend_a, 1.0 if kneeling else 0.0, delta * 3.4)
		model.scale.y = lerpf(model.scale.y, 1.0, min(1.0, 10.0 * delta))
		model.rotation.x = lerpf(model.rotation.x, 0.03 * bend_a, min(1.0, 10.0 * delta))
		# position.y is re-based by the walk/idle branch every frame,
		# so the kneel drop is applied additively from bend_a.
		model.position.y += -0.407 * mscale * bend_a
		model.position.z = 0.104 * mscale * bend_a
		if bend_a > 0.03:
			if leg_l:
				leg_l.rotation.x = -1.45 * bend_a
			if shin_l:
				shin_l.rotation.x = 1.40 * bend_a
			if leg_r:
				leg_r.rotation.x = 0.53 * bend_a
			if shin_r:
				shin_r.rotation.x = 0.99 * bend_a
			if head_node:
				head_node.rotation.x = lerpf(head_node.rotation.x, 0.24 * bend_a, min(1.0, 8.0 * delta))
			if interact_state == "bend" or interact_state == "rise":
				# both arms reaching down toward the cat while folding
				if arm_l:
					arm_l.rotation.x = lerpf(arm_l.rotation.x, -0.6, min(1.0, 8.0 * delta))
					arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.3, min(1.0, 8.0 * delta))
				if arm_r:
					arm_r.rotation.x = lerpf(arm_r.rotation.x, -0.6, min(1.0, 8.0 * delta))
					arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.3, min(1.0, 8.0 * delta))
	# JOY: a delighted hop when they first spot him, and arms reaching
	# out gently (to PET, never to grab-scary) through the chase.
	if joy_hop_t > 0.0:
		joy_hop_t -= delta
		if model:
			var hp: float = clampf(1.0 - joy_hop_t / 0.55, 0.0, 1.0)
			model.position.y += sin(hp * PI) * 0.13
	if (expression == "joy" or expression == "determined") and (mode == "chase" or mode == "pursue"):
		if arm_l:
			arm_l.rotation.x = lerp(arm_l.rotation.x, -1.05, min(1.0, 8.0 * delta))
			arm_l.rotation.z = lerp(arm_l.rotation.z, 0.5, min(1.0, 8.0 * delta))
		if arm_r:
			arm_r.rotation.x = lerp(arm_r.rotation.x, -1.05, min(1.0, 8.0 * delta))
			arm_r.rotation.z = lerp(arm_r.rotation.z, -0.5, min(1.0, 8.0 * delta))
	# POUND VAN: chasing with the net out, the left hand leaves
	# the reach pose and grips the pole — two hands on the net.
	if net_root != null and net_root.visible and (mode == "chase" or mode == "pursue"):
		update_net_grip()
	# v0.9 PETTING ARM AIM: while petting / offering a treat, the
	# right arm is aimed at the cat in model space every frame —
	# petting strokes travel along his back, the treat is held
	# right at his muzzle. This is what puts the hand ON the cat.
	if (interact_state == "pet" or interact_state == "treat") and bend_a > 0.25 and player_ref != null:
		var target_world: Vector3
		if interact_state == "pet":
			var back_p: Vector3 = player_ref.call("get_back_pos")
			var fwd_p: Vector3 = player_ref.call("get_forward_vec")
			target_world = back_p + fwd_p * sin(Time.get_ticks_msec() / 1000.0 * 5.2) * 0.06 + Vector3(0, 0.015, 0) # SCALE FIX: stroke travel 0.17 -> 0.06 for the 0.50-long back (was sized for the 1.64 back)
		else:
			target_world = player_ref.call("get_face_pos")
		_aim_arm(arm_r, target_world)
		if arm_l:
			arm_l.rotation.x = lerpf(arm_l.rotation.x, -0.85, min(1.0, 10.0 * delta))
			arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.25, min(1.0, 10.0 * delta))
	# v1.3 CAPTURE SCOOP: kneel / reach / cradle, applied LAST so it
	# wins over the walk swing, the chase JOY-reach and everything
	# else — during the cutscene THIS is what the arms are doing.
	if scoop_reach_a > 0.001 or scoop_cradle_a > 0.001 or scoop_kneel_a > 0.001:
		if model:
			# v1.0.13 BEND FIX (Michael, v1.0.12 play: the pickup
			# still "folds in half a little bit"): the old scoop
			# pitched the whole model toward 0.34 rad around her
			# feet and swung BOTH legs back with locked shins
			# (+1.9/+1.2) — a bow with her feet kicked up behind
			# her (and the same lerp fight as the petting kneel
			# froze even that at ~57-61%). She now takes the SAME
			# one-knee kneel as the petting pose, set from the
			# envelope so it fully forms: back up (pitch 0.05),
			# hips at full kneel depth (0.407), front leg planted,
			# back knee down with the shin folded flat, plus a
			# small forward settle (0.15) so her shoulders stay
			# over the cat while her hands come down at his sides.
			model.rotation.x = 0.05 * scoop_kneel_a
			model.position.y += -0.407 * mscale * scoop_kneel_a
			model.position.z = 0.15 * mscale * scoop_kneel_a
			if scoop_kneel_a > 0.03:
				if leg_l:
					leg_l.rotation.x = -1.45 * scoop_kneel_a
				if shin_l:
					shin_l.rotation.x = 1.40 * scoop_kneel_a
				if leg_r:
					leg_r.rotation.x = 0.53 * scoop_kneel_a
				if shin_r:
					shin_r.rotation.x = 0.99 * scoop_kneel_a
			if head_node:
				# Down at the cat while reaching; a soft look-down at
				# him in her arms once he's cradled.
				head_node.rotation.x = lerpf(head_node.rotation.x, 0.24 * scoop_kneel_a + 0.16 * scoop_cradle_a, min(1.0, 8.0 * delta))
		if scoop_reach_a > 0.01 and scoop_cradle_a < 0.6 and player_ref != null:
			# Both hands come down on either side of the cat's body
			# and TRACK him as he rises; with lift_k they slide from
			# his flanks in under his belly — the scoop itself.
			var cat_pos: Vector3 = player_ref.global_position
			var cat_right: Vector3 = player_ref.global_transform.basis.x
			cat_right.y = 0.0
			cat_right = cat_right.normalized() if cat_right.length() > 0.05 else Vector3.RIGHT
			var flank: float = lerpf(0.20, 0.12, scoop_lift_k)
			var hand_h: float = lerpf(0.17, 0.03, scoop_lift_k)
			_aim_arm(arm_l, cat_pos - cat_right * flank + Vector3(0, hand_h, 0))
			_aim_arm(arm_r, cat_pos + cat_right * flank + Vector3(0, hand_h, 0))
		if scoop_cradle_a > 0.001:
			# Arms folded under the cat, hands meeting beneath him.
			# The blend weight IS the envelope: at cradle 1 this is an
			# absolute set every call, so the walk cycle's arm swing
			# (set earlier in this function on the carry-away call)
			# can never leak through — she is HOLDING him. (Tuned
			# after the first proof frames: -0.98 reached too far
			# forward and a forearm crossed his chest; -0.84 / ±0.60
			# cups the hands under his belly instead.)
			if arm_l:
				arm_l.rotation.x = lerpf(arm_l.rotation.x, -0.84, scoop_cradle_a)
				arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.60, scoop_cradle_a)
			if arm_r:
				arm_r.rotation.x = lerpf(arm_r.rotation.x, -0.84, scoop_cradle_a)
				arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.60, scoop_cradle_a)
	# Dog trots + wags beside the dog walker
	if dog_model:
		if speed2d > 0.3:
			for i in range(dog_legs.size()):
				dog_legs[i].rotation.x = sin(walk_phase * 1.7 + (PI if i % 2 == 0 else 0.0)) * 0.5
			dog_model.position.y = abs(sin(walk_phase * 1.7)) * 0.03
		if dog_tail:
			dog_tail.rotation.y = sin(t * 6.0) * 0.4
	# v1.0.15 MESHY NPC SWAP: clips + ghost mirror, applied last so
	# the visible model wears the pose this function just struck.
	_update_meshy(delta, speed2d)

# --- v0.9 interaction sequence ---------------------------------------
func _aim_arm(arm: Node3D, world_target: Vector3) -> void:
	# Point an arm (whose limb hangs along -Y) at a world target,
	# computed in model space so it stays correct while kneeling,
	# leaning and turning.
	if arm == null or model == null:
		return
	var d: Vector3 = model.to_local(world_target) - arm.position
	if d.length() < 0.05:
		return
	arm.basis = Basis(Quaternion(Vector3(0, -1, 0), d.normalized()))

func pet_hand_global() -> Vector3:
	if arm_r != null:
		return arm_r.to_global(Vector3(0, -0.68 * mscale, 0.03))
	return global_position + Vector3(0, 1, 0)

func set_carry_pose(reach: float, cradle: float, kneel: float, lift_k: float) -> void:
	# v1.3: main's capture cutscene feeds the scoop envelopes every
	# frame (already eased there); _animate applies them. All zeros
	# releases the pose completely.
	scoop_reach_a = clampf(reach, 0.0, 1.0)
	scoop_cradle_a = clampf(cradle, 0.0, 1.0)
	scoop_kneel_a = clampf(kneel, 0.0, 1.0)
	scoop_lift_k = clampf(lift_k, 0.0, 1.0)

func _spawn_heart() -> void:
	var hl := Label3D.new()
	hl.text = "❤"
	hl.font_size = 72
	hl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hl.modulate = Color(1.0, 0.45, 0.6, 0.95)
	hl.outline_size = 6
	hl.outline_modulate = Color(0.6, 0.15, 0.3)
	var off := Vector3(randf_range(-0.25, 0.25), 1.05, randf_range(-0.1, 0.3))
	if player_ref != null:
		var to_cat: Vector3 = player_ref.global_position - global_position
		to_cat.y = 0.0
		if to_cat.length() > 0.1:
			off += to_cat.normalized() * 0.45
	hl.position = off
	add_child(hl)
	hearts.append({"node": hl, "t": 0.0})

func _update_hearts(delta: float) -> void:
	for h in hearts.duplicate():
		h["t"] = float(h["t"]) + delta
		var n: Label3D = h["node"]
		n.position.y += delta * 0.55
		n.position.x += sin(float(h["t"]) * 5.0) * delta * 0.12
		n.modulate.a = clampf(1.15 - float(h["t"]) / 1.3, 0.0, 1.0)
		if float(h["t"]) > 1.4:
			n.queue_free()
			hearts.erase(h)

func _run_interaction(delta: float, dist: float, to_player: Vector3) -> void:
	interact_t += delta
	velocity.x = 0.0
	velocity.z = 0.0
	if dist > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), min(1.0, 10.0 * delta))
	# The cat bolted mid-pet: stand back up, no hard feelings.
	if (interact_state == "bend" or interact_state == "pet" or interact_state == "treat") and dist > 3.2:
		interact_state = "rise"
		interact_t = 0.3
		if treat_mi:
			treat_mi.visible = false
		if bubble_lock_t <= 0.0:
			show_bubble("Come back…", 1.4)
	match interact_state:
		"approach":
			if dist > 0.82:
				var dir: Vector3 = to_player.normalized()
				velocity.x = dir.x * walk_speed * 1.35 # an eager trot over
				velocity.z = dir.z * walk_speed * 1.35
			if dist <= 0.88:
				interact_state = "bend"
				interact_t = 0.0
			elif interact_t > 4.5 or dist > 11.0:
				interact_state = "rise" # cat wandered off — give up gracefully
				interact_t = 0.3
		"bend":
			if interact_t >= 0.55:
				interact_t = 0.0
				if interact_kind == "treat":
					interact_state = "treat"
					if treat_mi:
						treat_mi.visible = true
					if player_ref.has_method("start_treat_reaction"):
						player_ref.start_treat_reaction()
				else:
					interact_state = "pet"
					pet_contact_frames = 0
					if player_ref.has_method("start_pet_reaction"):
						player_ref.start_pet_reaction(2.9)
		"pet":
			var hd: float = pet_hand_global().distance_to(player_ref.call("get_back_pos"))
			last_hand_dist = hd
			if hd < 0.34:
				pet_contact_frames += 1
			heart_spawn_t -= delta
			if heart_spawn_t <= 0.0 and interact_t > 0.25:
				heart_spawn_t = 0.75
				_spawn_heart()
			# v1.0.13 PET AWARD FIX (Michael, v1.0.7 + v1.0.12 play:
			# "I'm getting pet but the number of pets isn't going
			# up" — then one DID land: intermittent). The old gate
			# demanded >= 8 frames with the hand under 0.34 m from
			# the back point. Measured on the real player path
			# (tests/PetTreatProbe), the kneeling hand's actual
			# standoff is 0.33-0.41 m depending on the person's
			# size and the approach angle — kids sit at 0.35-0.40
			# and could NEVER score — so only ~1 in 4 completed
			# pettings ever paid out. The state machine is the
			# real guarantee: to be stroking at t >= 1.15 she has
			# trotted to <= 0.88 m, knelt for 0.55 s and the cat
			# has stayed within 3.2 m the whole time (leaving
			# aborts to "rise" above). So the +1 now lands on
			# petting completion, mid-stroke as before.
			# pet_contact_frames / last_hand_dist stay as pure
			# telemetry (the suite still reads them).
			if award_pending and not award_fired and interact_t >= 1.15:
				award_fired = true
				_fire_award("pet")
			if interact_t >= 2.6:
				interact_state = "rise"
				interact_t = 0.0
		"treat":
			last_hand_dist = pet_hand_global().distance_to(player_ref.call("get_face_pos"))
			heart_spawn_t -= delta
			if heart_spawn_t <= 0.0 and interact_t > 0.5:
				heart_spawn_t = 99.0
				_spawn_heart()
			if award_pending and not award_fired and interact_t >= 1.1:
				award_fired = true
				if treat_mi:
					treat_mi.visible = false # eaten!
				_fire_award("treat")
			if interact_t >= 1.55:
				interact_state = "rise"
				interact_t = 0.0
				if treat_mi:
					treat_mi.visible = false
		"rise":
			if interact_t >= 0.55:
				interact_state = ""
				interact_t = 0.0
				pending_award = ""
				set_expression("neutral")
				joy_shown = false
				_pick_wander_target()
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	global_position.x = clamp(global_position.x, -117.0, 369.0 if wide_bounds else 117.0)
	global_position.z = clamp(global_position.z, -89.0, 89.0)
	_animate(delta, Vector2(velocity.x, velocity.z).length())
	_update_labels()

func _fire_award(kind: String) -> void:
	# v0.9: fires DURING the action — the pet award only after the
	# hand has stroked the cat, the treat award as he finishes
	# eating it from the person's hand.
	pending_award = ""
	set_expression("joy")
	if kind == "pet":
		show_bubble("❤️ *pet pet* +1", 2.2)
		if main_ref and main_ref.has_method("on_pet"):
			main_ref.on_pet(self)
	else:
		show_bubble("🍪 A treat for you! +5", 2.2)
		if main_ref and main_ref.has_method("on_treat"):
			main_ref.on_treat(self)

func end_chase_via_spot() -> void:
	# A pursuit-ender spot (cat gap, slip-through): the chase is over,
	# outright, and they stay cooled-down longer.
	if mode == "chase" or mode == "tell":
		_end_chase()
		notice_cooldown = 6.0
		show_bubble("Where did he go…?", 2.0)

func _bar_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _set_bar(show: bool, frac: float, lower: bool = false) -> void:
	# Drives the geometry meter built with the labels. `lower` drops
	# the bar one extra line when the label is carrying two lines
	# (🏃 CHASE! over ✋ GRAB) so the bar sits under the words, where
	# the old glyph bar's second line used to be.
	if bar_root == null:
		return
	bar_root.visible = show
	if not show:
		return
	var f: float = clampf(frac, 0.0, 1.0)
	bar_fill.scale = Vector3(maxf(BAR_W * f, 0.001), 1.0, 1.0)
	bar_fill.position.x = -BAR_W * 0.5 + BAR_W * f * 0.5
	bar_root.position.y = body_h + (0.16 if lower else 0.60)
	# Yaw-face the camera (the bar stays upright — no tilt).
	if is_inside_tree():
		var cam3d := get_viewport().get_camera_3d()
		if cam3d:
			var cp := cam3d.global_position
			var bp := bar_root.global_position
			bar_root.global_rotation = Vector3(0, atan2(cp.x - bp.x, cp.z - bp.z), 0)

func _update_labels() -> void:
	if notice_label:
		if mode == "tell":
			notice_label.text = "❗ RUN!"
			_set_bar(false, 0.0)
		elif mode == "chase" or mode == "pursue":
			var t: String = "🏃 CHASE!"
			if grab_progress > 0.03:
				t += "\n✋ GRAB"
				notice_label.text = t
				_set_bar(true, grab_progress / grab_needed, true)
			else:
				notice_label.text = t
				_set_bar(false, 0.0)
		elif notice > 0.03:
			notice_label.text = "👀"
			_set_bar(true, notice)
		else:
			notice_label.text = ""
			_set_bar(false, 0.0)

func _has_line_of_sight() -> bool:
	# Geometric LOS against the house blocks (main_ref.houses): a house
	# between the NPC and the cat breaks sight. Hiding (bushes/cars) is
	# handled separately via the cat's is_hidden flag.
	if main_ref == null or player_ref == null:
		return true
	var houses_arr = main_ref.get("houses")
	if houses_arr == null:
		return true
	var a := Vector2(global_position.x, global_position.z)
	var b := Vector2(player_ref.global_position.x, player_ref.global_position.z)
	# MAP DOUBLING perf: with 131 houses (was 41) the full loop got
	# 3x dearer per brain tick. Exact early-out: a house rect reaches
	# at most 5.88 from its centre, so a house farther than the
	# sight-line length + 5.9 from the NPC cannot touch the segment
	# and is skipped — the result is identical, only cheaper.
	var seg_len: float = a.distance_to(b)
	for h in houses_arr:
		var hp: Vector3 = h["pos"]
		if Vector2(hp.x, hp.z).distance_to(a) > seg_len + 5.9:
			continue
		var rect := Rect2(hp.x - 4.4, hp.z - 3.9, 8.8, 7.8)
		if rect.has_point(a) or rect.has_point(b):
			continue
		if _segment_hits_rect(a, b, rect):
			return false
	return true

func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var dir := b - a
	var tmin: float = 0.0
	var tmax: float = 1.0
	for axis in range(2):
		var av: float = a[axis]
		var dv: float = dir[axis]
		var lo: float = r.position[axis]
		var hi: float = r.position[axis] + r.size[axis]
		if absf(dv) < 0.00001:
			if av < lo or av > hi:
				return false
		else:
			var t1: float = (lo - av) / dv
			var t2: float = (hi - av) / dv
			if t1 > t2:
				var tmp: float = t1; t1 = t2; t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return false
	return true

func set_expression(e: String) -> void:
	# v1.4 EXPRESSIONS: every call sets EVERY face parameter, so a
	# face can never stick after an interaction ends. Mouths are
	# pre-built groups (smile / grin / frown / flat / small smile);
	# brows, eyes and cheeks pose around them. Readable at the
	# game's real camera distance, not just in close-up:
	#   joy        big open grin, brows up, happy eye-squint
	#   happy      warm smile (greetings, the escape-room host)
	#   excited    RUN tell — grin, brows high, eyes wide
	#   determined chase/pursuit — focused brows, small smile,
	#              never angry
	#   sad        chase lost — frown, inner brows up, head droop
	#   worried    host noticing / a toppled prop — frown, inner
	#              brows up hard, eyes wide
	#   neutral    flat mouth, level brows (passers-by)
	expression = e
	if brow_l == null or mouth_root == null:
		return
	var brow_dy: float = 0.0
	var brow_rot_l: float = 0.0
	var brow_rot_r: float = 0.0
	var brow_in: float = 0.0 # brows pinch toward the centre by this much
	var eye_sy: float = 1.0
	var cheek_dy: float = 0.0
	var cheek_sc: float = 1.0
	var mouth: String = "flat"
	var head_rx: float = 0.0
	match e:
		"joy":
			mouth = "grin"
			brow_dy = 0.034
			brow_rot_l = 0.28
			brow_rot_r = -0.28
			eye_sy = 0.6
			cheek_dy = 0.02
			cheek_sc = 1.3
			joy_hop_t = 0.55 # a little hop of delight
		"happy":
			mouth = "smile"
			brow_dy = 0.02
			brow_rot_l = 0.15
			brow_rot_r = -0.15
			eye_sy = 0.82
			cheek_dy = 0.012
			cheek_sc = 1.15
		"excited":
			mouth = "grin"
			brow_dy = 0.05
			brow_rot_l = 0.2
			brow_rot_r = -0.2
			eye_sy = 1.18
			cheek_dy = 0.016
			cheek_sc = 1.2
			head_rx = -0.05
		"determined":
			mouth = "smile_small"
			brow_dy = -0.006
			brow_rot_l = -0.30
			brow_rot_r = 0.30
			eye_sy = 0.88
		"sad":
			mouth = "frown"
			brow_dy = 0.018
			brow_rot_l = 0.42
			brow_rot_r = -0.42
			brow_in = 0.010
			eye_sy = 0.78
			head_rx = 0.16 # head droops a little
		"worried":
			mouth = "frown"
			brow_dy = 0.026
			brow_rot_l = 0.5
			brow_rot_r = -0.5
			brow_in = 0.014
			eye_sy = 1.08
			head_rx = 0.07
		_:
			pass # neutral: the defaults above
	_show_mouth(mouth)
	brow_l.position = brow_base_l + Vector3(brow_in, brow_dy, 0)
	brow_r.position = brow_base_r + Vector3(-brow_in, brow_dy, 0)
	brow_l.rotation.z = brow_rot_l
	brow_r.rotation.z = brow_rot_r
	if eye_l_mi:
		eye_l_mi.scale = eye_base_scale * Vector3(1, eye_sy, 1)
	if eye_r_mi:
		eye_r_mi.scale = eye_base_scale * Vector3(1, eye_sy, 1)
	if cheek_l_mi:
		cheek_l_mi.position = cheek_base_l + Vector3(0, cheek_dy, 0)
		cheek_l_mi.scale = cheek_base_scale * cheek_sc
	if cheek_r_mi:
		cheek_r_mi.position = cheek_base_r + Vector3(0, cheek_dy, 0)
		cheek_r_mi.scale = cheek_base_scale * cheek_sc
	if head_node:
		head_node.rotation.x = head_rx

func show_bubble(text: String, dur: float = 2.6) -> void:
	if bubble_label:
		bubble_label.text = "💬 " + text
		bubble_label.visible = true
		bubble_timer = dur

func _spot_cat() -> void:
	if joy_shown:
		return
	joy_shown = true
	set_expression("joy")
	match npc_type:
		"kid": show_bubble("A kitty!!")
		"shopkeeper": show_bubble("Well hello, little cat!")
		_: show_bubble("Oh, a cat!")
	bubble_lock_t = 1.2 # let the greeting be seen before anything overwrites it

func _fire_pending_award() -> void:
	# v0.9: kept as a thin compat wrapper — awards now fire from the
	# interaction sequence (_fire_award) on confirmed contact.
	if pending_award != "":
		_fire_award(pending_award)

func _start_chase() -> void:
	if role != "grabber":
		notice = 0.85 # friendly / uninterested NPCs never chase
		return
	# RUN TELL first: crouch, arms spread wide, "!", and the call —
	# only after the tell does the actual chase begin.
	mode = "tell"
	tell_t = 0.9
	grab_progress = 0.0
	far_timer = 0.0
	los_timer = 0.0
	_spot_cat()
	set_expression("excited") # v1.4: the RUN tell gets the bright excited face
	if npc_type == "poundworker":
		# POUND VAN: his line is a rescue, not a grab — he says it
		# every time he gets out of the van (Michael, 2026-11-17).
		show_bubble("There you are! Let's get you home!", 2.2)
	else:
		show_bubble("Here, kitty kitty!", 1.8)
	if main_ref and main_ref.has_method("on_grabber_tell"):
		main_ref.on_grabber_tell(self)

func _end_chase() -> void:
	mode = "wander"
	notice = 0.25
	grab_progress = 0.0
	notice_cooldown = 3.0
	far_timer = 0.0
	los_timer = 0.0
	_pick_wander_target()
	set_expression("sad") # aww — not angry, just disappointed
	expr_timer = 3.0
	joy_shown = false
	if main_ref and main_ref.has_method("on_chase_ended"):
		main_ref.on_chase_ended(self)

func _roll_interact_kind(eligible: bool) -> String:
	# v1.0.13 TREAT RATE (Michael, every play session ever: "No
	# one's giving treats" — Treats stuck at 0). The treat award
	# itself was never broken (probe: every completed treat
	# sequence paid its +5); treats were just rare and luck-only:
	# a flat 25% roll, stacked on few completed encounters (and,
	# until today, a pet gate that ate most of the rest). Now:
	# the same 25% roll, PLUS a guarantee over award-eligible
	# encounters — if the last three eligible friendly encounters
	# were all pets, this one IS a treat. Long-run rate ≈ 1 in 3
	# encounters, and no player can meet four friendly people in
	# a row without one of them offering the biscuit.
	if eligible and s_eligible_since_treat >= 3:
		s_eligible_since_treat = 0
		return "treat"
	if randf() < 0.25:
		if eligible:
			s_eligible_since_treat = 0
		return "treat"
	if eligible:
		s_eligible_since_treat += 1
	return "pet"

func react_to_attention() -> String:
	# v0.7 (items 13+15): the cat just PAWED or MEOWED at this
	# person — INSTANT attention, the notice meter is bypassed.
	if player_ref:
		var d: Vector3 = player_ref.global_position - global_position
		d.y = 0.0
		if d.length() > 0.05:
			rotation.y = atan2(d.x, d.z)
	if role == "grabber":
		# Pawing the WRONG person: provoked — the full RUN tell and
		# chase, exactly like being spotted up close.
		notice = 1.0
		_start_chase()
		return "tell"
	elif role == "friendly":
		# v0.9: they react BECAUSE he pawed/meowed — joy + "Oh, a
		# cat!", then the full acted sequence: walk over, KNEEL down,
		# and stroke him with a hand that's really on his back (+1),
		# or offer a treat from the hand that he eats (+5). Points
		# land mid-action, once the action has genuinely run
		# (25s cooldown keeps one person from being farmed). No
		# notice meter, ever.
		_spot_cat()
		if interact_state == "":
			award_pending = interact_cooldown <= 0.0
			award_fired = false
			interact_kind = _roll_interact_kind(award_pending)
			if award_pending:
				interact_cooldown = 25.0
				pending_award = interact_kind
			interact_state = "approach"
			interact_t = 0.0
			bend_t = 2.4
			heart_spawn_t = 0.0
		return "notice"
	show_bubble("Hmm?", 1.2) # uninterested folks just shrug it off
	return "shrug"

func start_pursuit() -> void:
	mode = "pursue"
	notice = 0.0
	grab_progress = 0.0
	far_timer = 0.0
	los_timer = 0.0
	set_expression("determined") # v1.4: the post-escape pursuit face

func stop_pursuit() -> void:
	mode = "wander"
	notice = 0.0
	grab_progress = 0.0
	notice_cooldown = 2.0
	_pick_wander_target()
	set_expression("neutral")
	joy_shown = false


# =====================================================================
# v1.0.15 MESHY NPC SWAP (Michael, 2026-11-18: "get them into the
# game as soon as possible") — the same GHOST RIG pattern as the
# cat (cat.gd _attach_meshy / _mirror_meshy): this class's logic,
# pivots and pose contracts stay authoritative and keep posing
# the (now invisible) code-built body; the imported Meshy model
# is what renders. Two pose sources, cross-faded per frame by
# _update_meshy:
#   * the GLB's own Mixamo clips (Walking / Running) drive pure
#     locomotion — the model's own gait, better than the code
#     swing;
#   * the ghost mirror (global-pose overrides composed from the
#     skeleton's rest pose, parent-first, with the ghost pivots'
#     rotations folded in — the cat's maths) drives everything
#     the clips cannot do: idle standing (the GLBs have no idle
#     clip), the petting kneel + aimed stroking arm, treats, the
#     capture scoop / cradle, the RUN tell, the phone pose, the
#     dog walker's leash hand, and the chase reach (arms only —
#     the legs keep the Running clip through a chase).
# The officer's net moves onto his skeleton hand via a
# BoneAttachment3D, so set_net_visible / update_net_grip keep
# working untouched. Left/right are matched by POSITION, as with
# the cat: the ghost's "l" pivots sit at model -X, which is the
# skeleton's Right chain. Types without a model (pedestrian)
# skip all of this — zero behaviour change. To light up a future
# model, add its type -> GLB line in _meshy_scene_for_type.

func _meshy_scene_for_type() -> PackedScene:
	match npc_type:
		"poundworker":
			return preload("res://assets/models/officer.glb")
		"woman":
			return preload("res://assets/models/young_woman.glb")
		"kid":
			return preload("res://assets/models/excited_kid.glb")
		"dogwalker":
			return preload("res://assets/models/dog_walker.glb")
		"shopkeeper":
			return preload("res://assets/models/shopkeeper.glb")
	return null

func _attach_meshy() -> void:
	var ps := _meshy_scene_for_type()
	if ps == null or model == null:
		return
	var inst: Node = ps.instantiate()
	meshy_root = Node3D.new()
	meshy_root.name = "MeshyRoot"
	model.add_child(meshy_root)
	meshy_root.add_child(inst)
	meshy_root.scale = Vector3.ONE * mscale
	var stack: Array = [inst]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Skeleton3D:
			meshy_skel = cur as Skeleton3D
		elif cur is AnimationPlayer:
			meshy_ap = cur as AnimationPlayer
		elif cur is MeshInstance3D and (cur as MeshInstance3D).name.to_lower().contains("icosphere"):
			(cur as MeshInstance3D).visible = false # stock-scene placeholder guard (the cat's lesson)
		for ch in cur.get_children():
			stack.append(ch)
	if meshy_skel == null:
		meshy_root.visible = false
		meshy_root = null
		return
	if meshy_ap != null:
		for an in meshy_ap.get_animation_list():
			if an == "Walking" or an == "Running":
				var a := meshy_ap.get_animation(an)
				if not _meshy_loops_set.has(a):
					a.loop_mode = Animation.LOOP_LINEAR
					_meshy_loops_set[a] = true
	var want := {
		"hips": "mixamorig_Hips", "spine": "mixamorig_Spine", "spine1": "mixamorig_Spine1", "spine2": "mixamorig_Spine2",
		"neck": "mixamorig_Neck", "head": "mixamorig_Head",
		"sh_l": "mixamorig_LeftShoulder", "arm_l": "mixamorig_LeftArm", "fore_l": "mixamorig_LeftForeArm", "hand_l": "mixamorig_LeftHand",
		"sh_r": "mixamorig_RightShoulder", "arm_r": "mixamorig_RightArm", "fore_r": "mixamorig_RightForeArm", "hand_r": "mixamorig_RightHand",
		"uleg_l": "mixamorig_LeftUpLeg", "leg_l": "mixamorig_LeftLeg", "foot_l": "mixamorig_LeftFoot",
		"uleg_r": "mixamorig_RightUpLeg", "leg_r": "mixamorig_RightLeg", "foot_r": "mixamorig_RightFoot",
	}
	for role in want.keys():
		var bi: int = meshy_skel.find_bone(str(want[role]))
		if bi >= 0:
			meshy_bone[role] = bi
	var count: int = meshy_skel.get_bone_count()
	var depths: Array = []
	depths.resize(count)
	for bi in range(count):
		var gr: Transform3D = meshy_skel.get_bone_global_rest(bi)
		meshy_rest[bi] = gr
		var bp: int = meshy_skel.get_bone_parent(bi)
		if bp >= 0:
			meshy_local_rest[bi] = meshy_skel.get_bone_global_rest(bp).affine_inverse() * gr
		else:
			meshy_local_rest[bi] = gr
		var d: int = 0
		var p: int = bp
		while p >= 0:
			d += 1
			p = meshy_skel.get_bone_parent(p)
		depths[bi] = d
	meshy_order = []
	for bi in range(count):
		meshy_order.append(bi)
	meshy_order.sort_custom(func(a: int, b: int) -> bool: return depths[a] < depths[b])
	meshy_arm_chain.resize(count)
	var arm_roots: Array = [int(meshy_bone.get("arm_l", -1)), int(meshy_bone.get("arm_r", -1)), int(meshy_bone.get("sh_l", -1)), int(meshy_bone.get("sh_r", -1))]
	for bi in range(count):
		var p2: int = bi
		meshy_arm_chain[bi] = false
		while p2 >= 0:
			if arm_roots.has(p2):
				meshy_arm_chain[bi] = true
				break
			p2 = meshy_skel.get_bone_parent(p2)
	# The officer's net: re-hang it on the skeleton's left hand
	# (ghost arm_r's side, position-matched) so it follows the
	# VISIBLE hand through clips and mirror alike.
	if net_root != null and meshy_bone.has("hand_l"):
		var hand_bi: int = int(meshy_bone["hand_l"])
		var att := BoneAttachment3D.new()
		att.bone_name = meshy_skel.get_bone_name(hand_bi)
		meshy_skel.add_child(att)
		var old_parent: Node = net_root.get_parent()
		if old_parent != null:
			old_parent.remove_child(net_root)
		att.add_child(net_root)
		# Offset chosen so that, at rest, the net sits exactly
		# where the ghost arm put it: ghost arm_r rests at design
		# (0.36, 1.48, 0) with identity basis (design units —
		# meshy_root's scale converts). The net's geometry was
		# authored in model units, so counter-scale it back.
		var g_rest := Transform3D(Basis.IDENTITY, Vector3(0.36, 1.48, 0))
		att.transform = (meshy_rest[hand_bi] as Transform3D).affine_inverse() * g_rest
		net_root.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE / mscale), Vector3.ZERO)
	# Hide the code-built body (the ghost nodes/pivots stay live).
	_hide_ghost_meshes(model)
	_attach_dog_meshy()

func _meshy_keep_visible(mi: MeshInstance3D) -> bool:
	if treat_mi != null and (mi == treat_mi or treat_mi.is_ancestor_of(mi)):
		return true # the biscuit (and its chips) ride the ghost hand as before
	return phone_mis.has(mi)

func _hide_ghost_meshes(root: Node) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur == meshy_root:
			continue
		if cur is MeshInstance3D and not _meshy_keep_visible(cur as MeshInstance3D):
			(cur as MeshInstance3D).visible = false
		for ch in cur.get_children():
			stack.append(ch)

func _attach_dog_meshy() -> void:
	if npc_type != "dogwalker" or dog_model == null:
		return
	var ps: PackedScene = preload("res://assets/models/little_dog.glb")
	if ps == null:
		return
	# The code dog's meshes retire. (His leash cylinder on `model`
	# was already hidden by the generic pass above — the model's
	# OWN leash, skinned into his mesh, takes over: it leaves his
	# collar curving up and back toward the walker's hand side.)
	var stack: Array = [dog_model]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			(cur as MeshInstance3D).visible = false
		for ch in cur.get_children():
			stack.append(ch)
	var inst: Node = ps.instantiate()
	dog_meshy_root = Node3D.new()
	dog_meshy_root.name = "DogMeshyRoot"
	dog_model.add_child(dog_meshy_root)
	dog_meshy_root.add_child(inst)
	# The GLB dog stands with his feet at y -0.46 in his own
	# units; lift him so they land on dog_model's ground, sized
	# to match the code dog he replaces.
	var sd := 1.02
	dog_meshy_root.scale = Vector3.ONE * sd
	dog_meshy_root.position.y = 0.46 * sd
	var stack2: Array = [inst]
	while not stack2.is_empty():
		var cur2: Node = stack2.pop_back()
		if cur2 is Skeleton3D:
			dog_skel = cur2 as Skeleton3D
		for ch in cur2.get_children():
			stack2.append(ch)
	if dog_skel == null:
		dog_meshy_root.visible = false
		dog_meshy_root = null
		return
	var dwant := {"fl": "joint_27", "fr": "joint_32", "rl": "joint_17", "rr": "joint_22", "tail": "joint_07"}
	for role in dwant.keys():
		var bi: int = dog_skel.find_bone(str(dwant[role]))
		if bi >= 0:
			dog_bone[role] = bi
	var dcount: int = dog_skel.get_bone_count()
	var ddepths: Array = []
	ddepths.resize(dcount)
	for bi in range(dcount):
		var gr: Transform3D = dog_skel.get_bone_global_rest(bi)
		dog_rest[bi] = gr
		var bp: int = dog_skel.get_bone_parent(bi)
		if bp >= 0:
			dog_local_rest[bi] = dog_skel.get_bone_global_rest(bp).affine_inverse() * gr
		else:
			dog_local_rest[bi] = gr
		var d: int = 0
		var p: int = bp
		while p >= 0:
			d += 1
			p = dog_skel.get_bone_parent(p)
		ddepths[bi] = d
	dog_order = []
	for bi in range(dcount):
		dog_order.append(bi)
	dog_order.sort_custom(func(a: int, b: int) -> bool: return ddepths[a] < ddepths[b])

func _update_meshy(delta: float, speed2d: float) -> void:
	_update_dog_meshy(speed2d)
	if meshy_skel == null or meshy_root == null:
		return
	if model != null and not model.visible:
		return # distance-hidden: nothing to pose; state resumes on show
	# The phone only reads while she's actually holding it up:
	# put away during pets, treats, scoops, tells and chases —
	# her hands are busy then, and a phone floating at her chest
	# while her arms reach would give the game away.
	if not phone_mis.is_empty():
		var phone_ok: bool = interact_state == "" and scoop_reach_a <= 0.001 and scoop_cradle_a <= 0.001 and scoop_kneel_a <= 0.001 and mode != "chase" and mode != "pursue" and mode != "tell"
		for mi in phone_mis:
			(mi as MeshInstance3D).visible = phone_ok
	# --- the model's own clips drive pure locomotion ---
	if meshy_ap != null:
		var want_clip := ""
		if speed2d > 4.2:
			want_clip = "Running"
		elif speed2d > 0.3:
			want_clip = "Walking"
		if want_clip != "" and meshy_ap.has_animation(want_clip) and meshy_clip != want_clip:
			meshy_ap.play(want_clip, 0.18)
			meshy_clip = want_clip
		if want_clip == "":
			meshy_ap.speed_scale = 0.0 # frozen under the idle mirror
		elif meshy_clip == "Walking":
			meshy_ap.speed_scale = clampf(speed2d / (1.5 * mscale), 0.75, 2.2)
		elif meshy_clip == "Running":
			meshy_ap.speed_scale = clampf(speed2d / (4.2 * mscale), 0.75, 1.9)
	# --- regime weights: the ghost mirror takes the body for
	# idle + every interaction; it takes the ARMS additionally
	# for the phone pose and the chase reach (legs keep the
	# Running clip through a chase). ---
	var overlay: bool = interact_state != "" or scoop_reach_a > 0.001 or scoop_cradle_a > 0.001 or scoop_kneel_a > 0.001 or mode == "tell"
	var body_t := 0.0
	var arm_t := 0.0
	if overlay:
		body_t = 1.0
		arm_t = 1.0
	else:
		if speed2d <= 0.3:
			body_t = 1.0 # no idle clip exists: the mirrored rest IS the idle
			arm_t = 1.0
		if hold_pose or mode == "chase" or mode == "pursue":
			arm_t = 1.0
	meshy_w_body = move_toward(meshy_w_body, body_t, delta * 5.5)
	meshy_w_arms = move_toward(meshy_w_arms, arm_t, delta * 5.5)
	# Petting lean-in: the skeleton's arms are shorter than the
	# ghost's, so the whole model settles a touch toward the cat
	# as the kneel forms (the ghost's own settle is in
	# model.position.z, inherited — this is the extra the shorter
	# arms need; the spine pitch in _meshy_compose adds the rest).
	meshy_root.position.z = 0.07 * bend_a
	if meshy_w_body <= 0.001 and meshy_w_arms <= 0.001:
		if meshy_overrides_on:
			for bi in range(meshy_skel.get_bone_count()):
				meshy_skel.set_bone_global_pose_override(bi, Transform3D(), 0.0, false)
			meshy_overrides_on = false
		return
	_meshy_compose()
	meshy_overrides_on = true

func _meshy_drv(drv: Dictionary, role: String, b: Basis) -> void:
	var bi: int = int(meshy_bone.get(role, -1))
	if bi >= 0:
		drv[bi] = b

func _meshy_arm(drv: Dictionary, side: String, ghost_arm: Node3D, aimed: bool) -> void:
	if ghost_arm == null:
		return
	var arm_role := "arm_" + side
	var fore_role := "fore_" + side
	if aimed:
		# Rotate the skeleton arm's rest direction onto the
		# ghost's aim direction: the visible hand lands on the
		# cat, not wherever the A-pose rest would have put it.
		# The forearm inherits the rotation through the composed
		# chain (straight arm, like the ghost's one-piece arm).
		var arm_bi: int = int(meshy_bone.get(arm_role, -1))
		var fore_bi: int = int(meshy_bone.get(fore_role, -1))
		if arm_bi >= 0 and fore_bi >= 0:
			var want_dir: Vector3 = (ghost_arm.transform.basis * Vector3(0, -1, 0)).normalized()
			var rest_dir: Vector3 = ((meshy_rest[fore_bi] as Transform3D).origin - (meshy_rest[arm_bi] as Transform3D).origin).normalized()
			if rest_dir.length() > 0.01 and want_dir.length() > 0.01:
				_meshy_drv(drv, arm_role, Basis(Quaternion(rest_dir, want_dir)))
				return
	# Mirrored basis + a state-based elbow bend (the ghost arm
	# is one piece; the skeleton's elbow needs the hint).
	_meshy_drv(drv, arm_role, ghost_arm.transform.basis)
	var bend := -0.12
	if scoop_cradle_a > 0.01:
		bend = -0.55 * scoop_cradle_a
	elif hold_pose:
		bend = -0.5
	elif interact_state == "pet" or interact_state == "treat":
		bend = -0.2
	_meshy_drv(drv, fore_role, Basis.from_euler(Vector3(bend, 0, 0)))

func _meshy_compose() -> void:
	var drv: Dictionary = {}
	# Legs (position-matched: ghost -X pivots drive the Right chain)
	if leg_l != null:
		_meshy_drv(drv, "uleg_r", leg_l.transform.basis)
	if shin_l != null:
		_meshy_drv(drv, "leg_r", shin_l.transform.basis)
		_meshy_drv(drv, "foot_r", Basis.from_euler(Vector3(-shin_l.rotation.x * 0.35, 0, 0)))
	if leg_r != null:
		_meshy_drv(drv, "uleg_l", leg_r.transform.basis)
	if shin_r != null:
		_meshy_drv(drv, "leg_l", shin_r.transform.basis)
		_meshy_drv(drv, "foot_l", Basis.from_euler(Vector3(-shin_r.rotation.x * 0.35, 0, 0)))
	# Head + a share of the nod in the neck (carries the
	# expression tilts and the kneel's look-down).
	if head_node != null:
		_meshy_drv(drv, "head", head_node.transform.basis)
		_meshy_drv(drv, "neck", Basis.from_euler(head_node.rotation * 0.35))
	# Petting lean (see _update_meshy): pitch the chest toward
	# the cat as the kneel forms.
	if bend_a > 0.02 and (interact_state == "pet" or interact_state == "treat"):
		_meshy_drv(drv, "spine2", Basis.from_euler(Vector3(0.20 * bend_a, 0, 0)))
		_meshy_drv(drv, "spine1", Basis.from_euler(Vector3(0.10 * bend_a, 0, 0)))
	# Arms. The petting / treat arm and the scoop's reaching
	# arms are AIMED by the ghost (_aim_arm points the pivot's
	# -Y at the cat): those go by direction. Everything else
	# mirrors the ghost pivot's basis.
	var aim_r: bool = ((interact_state == "pet" or interact_state == "treat") and bend_a > 0.25) or (scoop_reach_a > 0.01 and scoop_cradle_a < 0.6)
	var aim_l: bool = scoop_reach_a > 0.01 and scoop_cradle_a < 0.6
	_meshy_arm(drv, "l", arm_r, aim_r) # ghost arm_r (+X) -> skeleton Left chain
	_meshy_arm(drv, "r", arm_l, aim_l) # ghost arm_l (-X) -> skeleton Right chain
	# Compose parent-first from rest, fold the drivers in, and
	# apply with the per-chain weights.
	var desired: Array = []
	desired.resize(meshy_skel.get_bone_count())
	for bi in meshy_order:
		var bp: int = meshy_skel.get_bone_parent(bi)
		var g: Transform3D
		if bp >= 0 and desired[bp] != null:
			g = (desired[bp] as Transform3D) * (meshy_local_rest[bi] as Transform3D)
		else:
			g = meshy_local_rest[bi] as Transform3D
		if drv.has(bi):
			g = Transform3D((drv[bi] as Basis) * g.basis, g.origin)
		desired[bi] = g
		var w: float = meshy_w_arms if bool(meshy_arm_chain[bi]) else meshy_w_body
		meshy_skel.set_bone_global_pose_override(bi, g, w, true)

func _update_dog_meshy(speed2d: float) -> void:
	if dog_skel == null or dog_meshy_root == null:
		return
	if dog_model != null and not dog_model.visible:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	var drv: Dictionary = {}
	var swing := 0.0
	if speed2d > 0.3:
		swing = 0.5
	# Trot: diagonal pairs (front-left with rear-right), swung
	# from the same walk_phase the code dog used.
	var ph: float = walk_phase * 1.7
	if dog_bone.has("fl"):
		drv[int(dog_bone["fl"])] = Basis.from_euler(Vector3(sin(ph) * swing, 0, 0))
	if dog_bone.has("rr"):
		drv[int(dog_bone["rr"])] = Basis.from_euler(Vector3(sin(ph) * swing, 0, 0))
	if dog_bone.has("fr"):
		drv[int(dog_bone["fr"])] = Basis.from_euler(Vector3(sin(ph + PI) * swing, 0, 0))
	if dog_bone.has("rl"):
		drv[int(dog_bone["rl"])] = Basis.from_euler(Vector3(sin(ph + PI) * swing, 0, 0))
	if dog_bone.has("tail"):
		drv[int(dog_bone["tail"])] = Basis.from_euler(Vector3(0, sin(t * 6.0) * 0.4, 0))
	var desired: Array = []
	desired.resize(dog_skel.get_bone_count())
	for bi in dog_order:
		var bp: int = dog_skel.get_bone_parent(bi)
		var g: Transform3D
		if bp >= 0 and desired[bp] != null:
			g = (desired[bp] as Transform3D) * (dog_local_rest[bi] as Transform3D)
		else:
			g = dog_local_rest[bi] as Transform3D
		if drv.has(bi):
			g = Transform3D((drv[bi] as Basis) * g.basis, g.origin)
		desired[bi] = g
		dog_skel.set_bone_global_pose_override(bi, g, 1.0, true)
