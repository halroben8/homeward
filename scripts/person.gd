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
var award_t: float = -1.0 # countdown to the pet/treat moment (-1 = none pending)
var pending_award: String = "" # "pet" | "treat"
# --- v0.9 REAL PETTING (Michael, three times: "they just wave their
# arm / it just says something via text — I want them to bend down
# and PET you"). A friendly interaction is now a full acted sequence:
#   approach -> bend (kneel down to cat level) -> pet (the right arm
#   AIMS at the cat and strokes along his back, hand in contact,
#   hearts rising, cat leaning in and purring) or treat (hand offers
#   a visible treat, cat dips his head and eats it) -> rise.
# Points fire DURING the action, only after contact is confirmed —
# never on the trigger, never as a text-only event.
var outfit_idx: int = 0 # 0 = the sheet design; >0 = outfit/hair variants for the extra neighbours
var mscale: float = 1.0 # body_h / 1.7, stored at build time
var interact_state: String = "" # "" | approach | bend | pet | treat | rise
var interact_t: float = 0.0 # seconds in the current sequence phase
var interact_kind: String = "" # "pet" | "treat"
var award_pending: bool = false # points will land mid-action (cooldown-gated)
var award_fired: bool = false
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
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _mat_skin(c: Color) -> StandardMaterial3D:
	# v1.0 step 2: skin is smoother than cloth and catches a soft
	# sheen — roughness 0.55 instead of the flat 0.85 everything
	# else used, which read as plastic.
	return _mat(c, 0.55)

func _mat_fabric(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = TEX_FABRIC
	m.albedo_color = c
	m.roughness = 0.92
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.normal_enabled = true
	m.normal_texture = TEX_FABRIC_N
	m.normal_scale = 0.65
	return m

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
			walk_speed = 2.5; chase_speed = 6.3; detect_radius = 7.5; fill_rate = 0.24
		"kid":
			display_name = "Excited Kid"
			walk_speed = 3.4; chase_speed = 7.0; detect_radius = 7.0; fill_rate = 0.30; body_h = 1.15
		"dogwalker":
			display_name = "Friendly Dog Walker"
			walk_speed = 2.3; chase_speed = 6.6; detect_radius = 8.0; fill_rate = 0.26
		"shopkeeper":
			display_name = "Cheerful Shopkeeper"
			walk_speed = 2.1; chase_speed = 6.0; detect_radius = 6.5; fill_rate = 0.22
		_:
			display_name = "Pedestrian"
			walk_speed = 2.4; chase_speed = 6.1; detect_radius = 6.0; fill_rate = 0.18

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = body_h
	cs.shape = cap
	cs.position = Vector3(0, body_h * 0.5, 0)
	add_child(cs)

var last_hand_mi: MeshInstance3D = null # set by _limb: the hand/shoe blob at the limb's end

func _limb(parent: Node, pos: Vector3, len_: float, r: float, c: Color, shoe: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var limb := _cyl(pivot, Vector3(0, -len_ * 0.5, 0), r, r * 0.85, len_, c)
	limb.material_override = _mat_fabric(c.lightened(0.32)) # v0.8: fabric grain on arms/legs
	_box(pivot, Vector3(0, -len_, 0.04), Vector3(r * 2.1, 0.08, 0.26), shoe)
	# v0.9: a rounded HAND (arms) / shoe toe (legs) at the very end —
	# the petting hand the cat actually feels.
	last_hand_mi = _sphere(pivot, Vector3(0, -len_ - 0.02, 0.03), Vector3(r * 2.1, r * 1.7, r * 2.1), shoe)
	if shoe == SKIN:
		last_hand_mi.material_override = _mat_skin(SKIN) # a hand, not a shoe
	return pivot

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
	var s: float = body_h / 1.7 # scale factor (kid smaller)
	mscale = s
	# Legs
	leg_l = _limb(model, Vector3(-0.14 * s, 0.85 * s, 0), 0.8 * s, 0.09 * s, leg_col, Color(0.9, 0.9, 0.9))
	leg_r = _limb(model, Vector3(0.14 * s, 0.85 * s, 0), 0.8 * s, 0.09 * s, leg_col, Color(0.9, 0.9, 0.9))
	# Torso
	var torso := _sphere(model, Vector3(0, 1.2 * s, 0), Vector3(0.62 * s, 0.75 * s, 0.4 * s), top_col)
	torso.material_override = _mat_fabric(top_col.lightened(0.3)) # v0.8: knit sweater/jacket grain
	# v0.9 BODY STRUCTURE: hips + shoulder bar + neck, so the body
	# reads as a person with joints, not a capsule with sticks.
	var hips := _sphere(model, Vector3(0, 0.9 * s, 0), Vector3(0.52 * s, 0.34 * s, 0.38 * s), leg_col)
	hips.material_override = _mat_fabric(leg_col.lightened(0.3))
	var shoulders := _sphere(model, Vector3(0, 1.47 * s, 0), Vector3(0.74 * s, 0.3 * s, 0.4 * s), top_col)
	shoulders.material_override = _mat_fabric(top_col.lightened(0.3))
	var neck_mi := _cyl(model, Vector3(0, 1.6 * s, 0), 0.085 * s, 0.1 * s, 0.2 * s, SKIN) # neck
	neck_mi.material_override = _mat_skin(SKIN)
	_box(model, Vector3(0, 0.98 * s, 0), Vector3(0.56 * s, 0.09 * s, 0.42 * s), leg_col.darkened(0.35)) # belt
	_box(model, Vector3(0, 0.98 * s, 0.22 * s), Vector3(0.12, 0.07, 0.03), Color(0.85, 0.7, 0.3)) # belt buckle
	if npc_type == "kid":
		_box(model, Vector3(0, 1.12 * s, 0.17 * s), Vector3(0.4 * s, 0.28 * s, 0.06), Color(0.95, 0.55, 0.15)) # orange pocket
		_sphere(model, Vector3(0, 1.52 * s, -0.16 * s), Vector3(0.3 * s, 0.24 * s, 0.18 * s), Color(0.45, 0.25, 0.72)) # hood behind head
		_box(model, Vector3(0, 1.14 * s, 0.21 * s), Vector3(0.12, 0.12, 0.03), Color(0.98, 0.8, 0.25)) # star on pocket
	if npc_type == "dogwalker":
		# Brown messenger bag + diagonal strap (sheet design)
		var strap := _box(model, Vector3(0.05 * s, 1.28 * s, 0.19 * s), Vector3(0.09, 0.62 * s, 0.04), Color(0.45, 0.3, 0.18))
		strap.rotation_degrees = Vector3(0, 0, 38)
		_box(model, Vector3(0.34 * s, 1.02 * s, 0.1 * s), Vector3(0.3, 0.34, 0.14), Color(0.55, 0.38, 0.22))
	if extra == "apron_cap":
		_box(model, Vector3(0, 1.15 * s, 0.19 * s), Vector3(0.44 * s, 0.6 * s, 0.05), Color(0.2, 0.45, 0.3)) # green apron
		# Cat face ON the apron (sheet design): pale muzzle + ears + eyes
		_sphere(model, Vector3(0, 1.22 * s, 0.23 * s), Vector3(0.17, 0.15, 0.04), Color(0.95, 0.88, 0.7))
		for ex in [-0.09, 0.09]:
			_box(model, Vector3(ex * s, 1.36 * s, 0.22 * s), Vector3(0.07, 0.08, 0.03), Color(0.95, 0.88, 0.7))
			_sphere(model, Vector3(ex * s, 1.24 * s, 0.26 * s), Vector3(0.025, 0.035, 0.015), Color(0.15, 0.12, 0.1))
		# Paper shopping bag with a cat face, held in front (sheet design)
		_box(model, Vector3(0, 0.82 * s, 0.34 * s), Vector3(0.42, 0.44, 0.2), Color(0.85, 0.72, 0.52))
		_sphere(model, Vector3(0, 0.86 * s, 0.45 * s), Vector3(0.13, 0.11, 0.03), Color(0.5, 0.35, 0.2))
		for ex2 in [-0.07, 0.07]:
			_sphere(model, Vector3(ex2 * s, 0.89 * s, 0.47 * s), Vector3(0.02, 0.028, 0.012), Color(0.2, 0.15, 0.1))
	# v1.0 step 2: shoulder balls + elbow balls, so arms join the
	# body and bend at a joint instead of hanging as plain sticks.
	for shx in [-0.36, 0.36]:
		var sh := _sphere(model, Vector3(shx * s, 1.48 * s, 0), Vector3(0.17 * s, 0.17 * s, 0.17 * s), top_col)
		sh.material_override = _mat_fabric(top_col.lightened(0.3))
	# Arms
	arm_l = _limb(model, Vector3(-0.36 * s, 1.48 * s, 0), 0.68 * s, 0.07 * s, top_col, SKIN)
	arm_r = _limb(model, Vector3(0.36 * s, 1.48 * s, 0), 0.68 * s, 0.07 * s, top_col, SKIN)
	for arm_p in [arm_l, arm_r]:
		var elb := _sphere(arm_p, Vector3(0, -0.34 * s, 0), Vector3(0.085 * s, 0.085 * s, 0.085 * s), top_col)
		elb.material_override = _mat_fabric(top_col.lightened(0.3))
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
	# Head
	head_node = Node3D.new()
	head_node.position = Vector3(0, 1.72 * s, 0)
	model.add_child(head_node)
	var head_mi := _sphere(head_node, Vector3.ZERO, Vector3(0.50 * s, 0.53 * s, 0.47 * s), SKIN)
	head_mi.material_override = _mat_skin(SKIN)
	for esx in [-1.0, 1.0]: # v0.9: ears
		var ear_mi := _sphere(head_node, Vector3(esx * 0.245 * s, -0.01, 0), Vector3(0.07 * s, 0.095 * s, 0.05 * s), SKIN)
		ear_mi.material_override = _mat_skin(SKIN)
	for sx in [-0.08, 0.08]:
		# v1.0 step 2: REAL eyes — a white sclera ball with a brown
		# iris and a black pupil riding on it as children, so the
		# expression system (which scales eye_l_mi/eye_r_mi) squints
		# the whole eye at once. v0.9's single dark blob read as a
		# hole in the face at any distance.
		var eye_mi := _sphere(head_node, Vector3(sx * s, 0.03, 0.225 * s), Vector3(0.078, 0.098, 0.04), Color(0.97, 0.96, 0.94))
		eye_mi.material_override = _mat(Color(0.97, 0.96, 0.94), 0.3)
		var iris_mi := _sphere(eye_mi, Vector3(0, 0, 0.6), Vector3(0.6, 0.64, 0.5), Color(0.35, 0.22, 0.12))
		iris_mi.material_override = _mat(Color(0.35, 0.22, 0.12), 0.2)
		_sphere(iris_mi, Vector3(0, 0, 0.55), Vector3(0.55, 0.58, 0.4), Color(0.05, 0.04, 0.03)) # pupil
		_sphere(eye_mi, Vector3(0.3, 0.32, 0.7), Vector3(0.2, 0.2, 0.2), Color.WHITE) # sparkle
		if sx < 0.0:
			eye_l_mi = eye_mi
		else:
			eye_r_mi = eye_mi
		var brow := _box(head_node, Vector3(sx * s, 0.135 * s, 0.2 * s), Vector3(0.095, 0.026, 0.02), HAIR_BROWN) # eyebrows (joy/sad move these)
		if sx < 0.0:
			brow_l = brow
			brow_base_l = brow.position
		else:
			brow_r = brow
			brow_base_r = brow.position
	var nose_mi := _sphere(head_node, Vector3(0, -0.04, 0.225 * s), Vector3(0.045, 0.05, 0.03), Color(0.93, 0.68, 0.55)) # nose
	nose_mi.material_override = _mat_skin(Color(0.93, 0.68, 0.55))
	for sx in [-1.0, 1.0]:
		var cheek := _sphere(head_node, Vector3(sx * 0.16 * s, -0.08 * s, 0.185 * s), Vector3(0.07, 0.045, 0.03), Color(0.97, 0.62, 0.58)) # rosy cheeks
		if sx < 0.0:
			cheek_l_mi = cheek
			cheek_base_l = cheek.position
		else:
			cheek_r_mi = cheek
			cheek_base_r = cheek.position
	mouth_mi = _sphere(head_node, Vector3(0, -0.13 * s, 0.19 * s), mouth_base_scale, Color(0.7, 0.35, 0.3)) # smile-ish mouth
	if extra == "bun":
		_sphere(head_node, Vector3(0, 0.16 * s, -0.05), Vector3(0.52 * s, 0.36 * s, 0.49 * s), hair_col) # hair cap
		_sphere(head_node, Vector3(0, 0.34 * s, -0.08), Vector3(0.24, 0.22, 0.24), hair_col) # bun
		_sphere(model, Vector3(0, 1.44 * s, 0.2 * s), Vector3(0.045, 0.045, 0.03), Color(0.9, 0.72, 0.25)) # necklace pendant
		# Phone in front (sheet: she's looking at her phone)
		_box(model, Vector3(0, 1.18 * s, 0.3 * s), Vector3(0.16, 0.26, 0.04), Color(0.12, 0.13, 0.16))
		# Cat-face crossbody bag (sheet design): strap + ears + face
		var strap2 := _box(model, Vector3(-0.08 * s, 1.3 * s, 0.2 * s), Vector3(0.07, 0.6 * s, 0.035), Color(0.6, 0.45, 0.3))
		strap2.rotation_degrees = Vector3(0, 0, -35)
		_box(model, Vector3(0.34 * s, 1.02 * s, 0.16 * s), Vector3(0.26, 0.26, 0.1), Color(0.88, 0.75, 0.57))
		for ex3 in [-0.08, 0.08]:
			_box(model, Vector3((0.34 + ex3) * s, 1.17 * s, 0.17 * s), Vector3(0.07, 0.08, 0.05), Color(0.88, 0.75, 0.57)) # bag ears
			_sphere(model, Vector3((0.34 + ex3 * 0.7) * s, 1.05 * s, 0.22 * s), Vector3(0.02, 0.028, 0.012), Color(0.2, 0.15, 0.1)) # bag eyes
		_sphere(model, Vector3(0.34 * s, 1.0 * s, 0.22 * s), Vector3(0.025, 0.018, 0.012), Color(0.95, 0.5, 0.55)) # bag nose
	elif extra == "messy":
		for i in range(7):
			var spike := _cyl(head_node, Vector3(-0.19 + float(i) * 0.065, 0.27 * s, 0), 0.01, 0.05, 0.22, hair_col)
			spike.rotation_degrees = Vector3(randf_range(-18, 18), 0, randf_range(-18, 18))
	elif extra == "apron_cap":
		_cyl(head_node, Vector3(0, 0.2 * s, 0), 0.24 * s, 0.25 * s, 0.1, Color(0.45, 0.32, 0.18)) # flat cap
		_box(head_node, Vector3(0, 0.16 * s, 0.22 * s), Vector3(0.3, 0.04, 0.16), Color(0.45, 0.32, 0.18))
	else:
		_sphere(head_node, Vector3(0, 0.17 * s, -0.03), Vector3(0.52 * s, 0.32 * s, 0.49 * s), hair_col)
	# v0.9 HAIR / OUTFIT VARIANTS for the extra neighbours
	if outfit_idx > 0 and npc_type != "shopkeeper":
		match outfit_idx % 3:
			1: # baseball cap
				_cyl(head_node, Vector3(0, 0.21 * s, 0), 0.26 * s, 0.27 * s, 0.1 * s, top_col.darkened(0.15))
				_box(head_node, Vector3(0, 0.17 * s, 0.3 * s), Vector3(0.34 * s, 0.035, 0.22 * s), top_col.darkened(0.15))
			2: # ponytail + long back hair
				_sphere(head_node, Vector3(0, 0.05, -0.24 * s), Vector3(0.3 * s, 0.42 * s, 0.18 * s), hair_col)
				_sphere(head_node, Vector3(0, 0.3 * s, -0.16 * s), Vector3(0.16, 0.14, 0.16), hair_col)
				_cyl(head_node, Vector3(0, -0.05, -0.3 * s), 0.07, 0.05, 0.5 * s, hair_col)
			_: # curly puffs
				for ci in range(6):
					var ca: float = float(ci) * 1.05
					_sphere(head_node, Vector3(cos(ca) * 0.13 * s, 0.24 * s + 0.04 * sin(float(ci) * 2.3), sin(ca) * 0.13 * s - 0.02), Vector3(0.13, 0.12, 0.13), hair_col)
	if outfit_idx == 2 and npc_type == "woman":
		# a swishy skirt over the jeans
		var skirt := _cyl(model, Vector3(0, 0.78 * s, 0), 0.3 * s, 0.5 * s, 0.42 * s, top_col.darkened(0.05))
		skirt.material_override = _mat_fabric(top_col.darkened(0.05).lightened(0.3))
	if outfit_idx == 1 and npc_type == "pedestrian":
		# backpack with a bedroll
		_box(model, Vector3(0, 1.25 * s, -0.3 * s), Vector3(0.44 * s, 0.56 * s, 0.2), Color(0.8, 0.35, 0.25))
		_cyl(model, Vector3(0, 1.6 * s, -0.3 * s), 0.09, 0.09, 0.46 * s, Color(0.35, 0.55, 0.7)).rotation_degrees = Vector3(0, 0, 90)
	if npc_type == "dogwalker":
		_build_dog()
	if npc_type == "woman" or npc_type == "pedestrian":
		hold_pose = true

	# ---- v0.6 sheet-matched extras ----
	if npc_type == "woman":
		_sphere(head_node, Vector3(0, 0.235 * s, 0.13 * s), Vector3(0.42, 0.15, 0.2), hair_col) # soft fringe band
		# fuller hair: side volume + bigger bun; sweater hem; jeans cuffs
		_sphere(head_node, Vector3(-0.17 * s, 0.02, -0.02), Vector3(0.16, 0.3, 0.3), hair_col)
		_sphere(head_node, Vector3(0.17 * s, 0.02, -0.02), Vector3(0.16, 0.3, 0.3), hair_col)
		_sphere(head_node, Vector3(0, 0.37 * s, -0.08), Vector3(0.23, 0.21, 0.23), hair_col)
		_box(model, Vector3(0, 0.92 * s, 0), Vector3(0.52 * s, 0.13, 0.4 * s), Color(0.88, 0.81, 0.68))
		for cx in [-0.14, 0.14]:
			_cyl(model, Vector3(cx * s, 0.12 * s, 0), 0.105 * s, 0.105 * s, 0.13, Color(0.55, 0.65, 0.82)) # rolled jean cuffs
		# cat-face bag: whiskers to go with the existing ears/eyes/nose
		for wx in [-1.0, 1.0]:
			for wi in range(2):
				var wh := _box(model, Vector3((0.34 + wx * 0.13) * s, (1.03 - float(wi) * 0.05) * s, 0.225 * s), Vector3(0.11, 0.012, 0.01), Color(0.35, 0.28, 0.2))
				wh.rotation_degrees = Vector3(0, 0, wx * (8.0 + float(wi) * 7.0))
		_box(model, Vector3(0, 1.18 * s, 0.325 * s), Vector3(0.13, 0.22, 0.015), Color(0.55, 0.75, 0.9)) # phone screen glow
	elif npc_type == "kid":
		# navy patched shorts over skin legs + teal sneakers
		for cx in [-0.13, 0.13]:
			_box(model, Vector3(cx * s, 0.72 * s, 0), Vector3(0.23 * s, 0.3 * s, 0.25 * s), Color(0.16, 0.24, 0.48))
			_cyl(model, Vector3(cx * s, 0.42 * s, 0), 0.075 * s, 0.07 * s, 0.34 * s, SKIN)
			_box(model, Vector3(cx * s, 0.05 * s, 0.05), Vector3(0.19, 0.09, 0.3), Color(0.15, 0.65, 0.68)) # teal sneaker
			_box(model, Vector3(cx * s, 0.005 * s, 0.05), Vector3(0.2, 0.03, 0.31), Color(0.95, 0.95, 0.95)) # white sole
		_box(model, Vector3(-0.13 * s, 0.7 * s, 0.14 * s), Vector3(0.09, 0.09, 0.02), Color(0.95, 0.55, 0.15)) # orange patch
		_box(model, Vector3(0.14 * s, 0.76 * s, 0.14 * s), Vector3(0.08, 0.08, 0.02), Color(0.3, 0.75, 0.5)) # green patch
		_box(model, Vector3(0.24 * s, 1.2 * s, 0.16 * s), Vector3(0.13 * s, 0.4 * s, 0.05), Color(0.2, 0.65, 0.7)) # teal side panel
		_box(model, Vector3(0, -0.13 * s + 1.72 * s, 0.235 * s), Vector3(0.16, 0.045, 0.03), Color(0.55, 0.25, 0.2)) # big grin
		for fx in [-0.14, -0.1, 0.1, 0.14]:
			_sphere(head_node, Vector3(fx * s, -0.06 * s, 0.2 * s), Vector3(0.014, 0.014, 0.01), Color(0.72, 0.5, 0.35)) # freckles
		for i in range(3):
			var tuft := _sphere(head_node, Vector3((-0.16 + float(i) * 0.16) * s, 0.24 * s, -0.05), Vector3(0.13, 0.13, 0.13), hair_col)
			tuft.position.y += 0.02
	elif npc_type == "dogwalker":
		# white tee under an open olive overshirt
		_box(model, Vector3(0, 1.27 * s, 0.185 * s), Vector3(0.3 * s, 0.44 * s, 0.05), Color(0.96, 0.95, 0.92))
		for px in [-0.21, 0.21]:
			_box(model, Vector3(px * s, 1.26 * s, 0.17 * s), Vector3(0.15 * s, 0.5 * s, 0.06), Color(0.38, 0.45, 0.3))
		# wavy hair: bumpy top
		for hx in [-0.13, 0.0, 0.13]:
			_sphere(head_node, Vector3(hx * s, 0.22 * s, -0.02), Vector3(0.17, 0.15, 0.3), hair_col)
		_box(model, Vector3(0.34 * s, 1.16 * s, 0.12 * s), Vector3(0.32, 0.15, 0.15), Color(0.48, 0.32, 0.19)) # bag flap
		if dog_model:
			_box(dog_model, Vector3(0, 0.38, 0.55), Vector3(0.09, 0.04, 0.1), Color(0.95, 0.5, 0.55)) # dog tongue
			_sphere(dog_model, Vector3(0.1, 0.3, -0.3), Vector3(0.2, 0.18, 0.2), Color(0.97, 0.95, 0.9)) # extra fluff
			_sphere(dog_model, Vector3(-0.12, 0.52, 0.05), Vector3(0.2, 0.18, 0.2), Color(0.97, 0.95, 0.9))
	elif npc_type == "shopkeeper":
		# rounder belly under the apron, longer apron, bigger cat emblem
		_sphere(model, Vector3(0, 1.02 * s, 0.06), Vector3(0.56 * s, 0.5 * s, 0.38 * s), top_col)
		_box(model, Vector3(0, 0.8 * s, 0.2 * s), Vector3(0.42 * s, 0.34 * s, 0.05), Color(0.2, 0.45, 0.3))
		_sphere(model, Vector3(0, 1.3 * s, 0.245 * s), Vector3(0.15, 0.14, 0.035), Color(0.96, 0.9, 0.75)) # emblem face
		for ex in [-0.08, 0.08]:
			_box(model, Vector3(ex * s, 1.44 * s, 0.24 * s), Vector3(0.07, 0.08, 0.03), Color(0.96, 0.9, 0.75)) # emblem ears
			_sphere(model, Vector3(ex * 0.7 * s, 1.32 * s, 0.28 * s), Vector3(0.022, 0.03, 0.012), Color(0.15, 0.12, 0.1)) # emblem eyes
			var mo := _box(head_node, Vector3(ex * 0.55 * s, -0.045 * s, 0.245 * s), Vector3(0.12, 0.04, 0.035), Color(0.3, 0.2, 0.12))
			mo.rotation_degrees = Vector3(0, 0, ex * -18.0) # curved moustache halves
	# Labels (billboarded, always face the camera)
	name_label = Label3D.new()
	name_label.text = display_name
	name_label.font_size = 36
	# v1.2 READABILITY (Michael's v1.0.4 playtest): at the cat's real
	# scale the overhead labels were too small to read on his phone.
	# pixel_size is set EXPLICITLY now: name 0.27m tall, the notice /
	# GRAB bar (the gameplay-critical one) 0.40m with a ~2.2m bar.
	name_label.pixel_size = 0.0075
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = Vector3(0, body_h + 0.55, 0)
	name_label.modulate = Color(1, 1, 1, 0.95)
	name_label.outline_size = 8
	add_child(name_label)
	notice_label = Label3D.new()
	notice_label.text = ""
	notice_label.font_size = 44
	notice_label.pixel_size = 0.009
	notice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	notice_label.position = Vector3(0, body_h + 1.12, 0)
	notice_label.modulate = Color(1.0, 0.85, 0.3)
	notice_label.outline_size = 8
	add_child(notice_label)
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
	wander_target = Vector3(randf_range(-112.0, 112.0), 0, randf_range(-84.0, 84.0))
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
		if expr_timer <= 0.0 and expression == "sad":
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
	global_position.x = clamp(global_position.x, -117.0, 117.0)
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
		if arm_l: arm_l.rotation.x = -swing * 0.8
		if arm_r: arm_r.rotation.x = swing * 0.8
		if model: model.position.y = abs(sin(walk_phase)) * 0.04
	else:
		if leg_l: leg_l.rotation.x = lerp(leg_l.rotation.x, 0.0, min(1.0, 10.0 * delta))
		if leg_r: leg_r.rotation.x = lerp(leg_r.rotation.x, 0.0, min(1.0, 10.0 * delta))
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
		# v0.9 KNEEL-DOWN (replaces the v0.8 bend): the whole body
		# drops to cat level — knees fold under, torso leans in, head
		# tips down to the cat. bend_a envelopes in/out with the
		# interaction sequence, so it never snaps.
		var kneeling: bool = interact_state == "bend" or interact_state == "pet" or interact_state == "treat"
		bend_a = move_toward(bend_a, 1.0 if kneeling else 0.0, delta * 3.4)
		model.scale.y = lerpf(model.scale.y, 1.0 - 0.15 * bend_a, min(1.0, 10.0 * delta))
		model.rotation.x = lerpf(model.rotation.x, 0.34 * bend_a, min(1.0, 10.0 * delta))
		# position.y is re-based by the walk/idle branch every frame,
		# so the kneel drop is applied additively from bend_a.
		model.position.y += -0.3 * mscale * bend_a
		if bend_a > 0.03:
			if leg_l:
				leg_l.rotation.x = lerpf(leg_l.rotation.x, 1.9 * bend_a, min(1.0, 14.0 * delta))
			if leg_r:
				leg_r.rotation.x = lerpf(leg_r.rotation.x, 1.2 * bend_a, min(1.0, 14.0 * delta))
			if head_node:
				head_node.rotation.x = lerpf(head_node.rotation.x, 0.3 * bend_a, min(1.0, 8.0 * delta))
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
	if expression == "joy" and (mode == "chase" or mode == "pursue"):
		if arm_l:
			arm_l.rotation.x = lerp(arm_l.rotation.x, -1.05, min(1.0, 8.0 * delta))
			arm_l.rotation.z = lerp(arm_l.rotation.z, 0.5, min(1.0, 8.0 * delta))
		if arm_r:
			arm_r.rotation.x = lerp(arm_r.rotation.x, -1.05, min(1.0, 8.0 * delta))
			arm_r.rotation.z = lerp(arm_r.rotation.z, -0.5, min(1.0, 8.0 * delta))
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
	# Dog trots + wags beside the dog walker
	if dog_model:
		if speed2d > 0.3:
			for i in range(dog_legs.size()):
				dog_legs[i].rotation.x = sin(walk_phase * 1.7 + (PI if i % 2 == 0 else 0.0)) * 0.5
			dog_model.position.y = abs(sin(walk_phase * 1.7)) * 0.03
		if dog_tail:
			dog_tail.rotation.y = sin(t * 6.0) * 0.4

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
			if award_pending and not award_fired and interact_t >= 1.15 and pet_contact_frames >= 8:
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
	global_position.x = clamp(global_position.x, -117.0, 117.0)
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

func _update_labels() -> void:
	if notice_label:
		if mode == "tell":
			notice_label.text = "❗ RUN!"
		elif mode == "chase" or mode == "pursue":
			var t: String = "🏃 CHASE!"
			if grab_progress > 0.03:
				var blocks: int = int(round(grab_progress / grab_needed * 10.0))
				var bar: String = ""
				for i in range(10):
					bar += "█" if i < blocks else "░"
				t += "\n✋ GRAB " + bar
			notice_label.text = t
		elif notice > 0.03:
			var blocks2: int = int(round(notice * 10.0))
			var bar2: String = ""
			for i in range(10):
				bar2 += "█" if i < blocks2 else "░"
			notice_label.text = "👀 " + bar2
		else:
			notice_label.text = ""

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
	for h in houses_arr:
		var hp: Vector3 = h["pos"]
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
	expression = e
	if brow_l == null or mouth_mi == null:
		return
	match e:
		"joy":
			brow_l.position = brow_base_l + Vector3(0, 0.04, 0)
			brow_r.position = brow_base_r + Vector3(0, 0.04, 0)
			brow_l.rotation.z = 0.3
			brow_r.rotation.z = -0.3
			mouth_mi.scale = mouth_base_scale * Vector3(1.6, 1.7, 1.0) # BIG delighted smile
			if eye_l_mi: eye_l_mi.scale = Vector3(0.078, 0.066, 0.032) # happy squint
			if eye_r_mi: eye_r_mi.scale = Vector3(0.063, 0.056, 0.03)
			if cheek_l_mi: cheek_l_mi.position = cheek_base_l + Vector3(0, 0.02, 0)
			if cheek_r_mi: cheek_r_mi.position = cheek_base_r + Vector3(0, 0.02, 0)
			if head_node: head_node.rotation.x = 0.0
			joy_hop_t = 0.55 # a little hop of delight
		"sad":
			brow_l.position = brow_base_l + Vector3(0, -0.015, 0)
			brow_r.position = brow_base_r + Vector3(0, -0.015, 0)
			brow_l.rotation.z = -0.38 # inner ends down: gentle disappointment
			brow_r.rotation.z = 0.38
			mouth_mi.scale = mouth_base_scale * Vector3(0.65, 0.6, 1.0)
			if eye_l_mi: eye_l_mi.scale = Vector3(0.068, 0.088, 0.032)
			if eye_r_mi: eye_r_mi.scale = Vector3(0.068, 0.088, 0.032)
			if cheek_l_mi: cheek_l_mi.position = cheek_base_l
			if cheek_r_mi: cheek_r_mi.position = cheek_base_r
			if head_node: head_node.rotation.x = 0.16 # head droops a little
		_:
			brow_l.position = brow_base_l
			brow_r.position = brow_base_r
			brow_l.rotation.z = 0.0
			brow_r.rotation.z = 0.0
			mouth_mi.scale = mouth_base_scale
			if cheek_l_mi: cheek_l_mi.position = cheek_base_l
			if cheek_r_mi: cheek_r_mi.position = cheek_base_r
			if eye_l_mi: eye_l_mi.scale = Vector3(0.068, 0.088, 0.032)
			if eye_r_mi: eye_r_mi.scale = Vector3(0.068, 0.088, 0.032)
			if head_node: head_node.rotation.x = 0.0

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
	set_expression("joy")
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
		# land mid-action on confirmed contact (25s cooldown keeps
		# one person from being farmed). No notice meter, ever.
		_spot_cat()
		if interact_state == "":
			interact_kind = "pet" if randf() < 0.75 else "treat"
			award_pending = interact_cooldown <= 0.0
			award_fired = false
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
	set_expression("joy")

func stop_pursuit() -> void:
	mode = "wander"
	notice = 0.0
	grab_progress = 0.0
	notice_cooldown = 2.0
	_pick_wander_target()
	set_expression("neutral")
	joy_shown = false
