extends CharacterBody3D
## HOMEWARD v0.7 — 3D player cat, modelled on Michael's reference sheet
## (assets/reference/protagonist_reference_5249.jpg): domestic shorthair
## ORANGE TABBY — rich orange fur, darker tabby stripes across back,
## sides, legs and tail; WHITE muzzle, chest patch, paws and tail tip;
## BIG green eyes, pink nose, friendly open smile; black collar with a
## round SILVER tag with a paw print. Soft/furry look via high-roughness
## materials + overlapping fluff spheres (cheeks, chest, tail).
## The cat SMOOTHLY TURNS to face its exact movement direction and plays
## a real walk cycle. Movement is CAMERA-YAW-relative (cam_yaw is set by
## main3d.gd from the v0.4 look controls (unchanged in v0.5)). Idle: breathing, tail sway,
## ear twitches. Sprint: faster cycle. Hop: jump.

# v1.2 READABILITY (Michael's v1.0.4 playtest): the real-scale cat read
# too small on his phone, so the MODEL (only the model — a wrapper node
# around it) is drawn 1.25x. Collision capsule, speeds, hop and every
# gameplay measurement stay exactly as the scale step set them; the
# body-space getters below scale their offsets by the same factor so
# petting hands, treats and the collar zoom still land on the cat you
# SEE.
const VISUAL_SCALE := 1.25

# The cat's name (Michael named him, 2026-11-18): ZANDER. It is what
# his collar tag says — the tag carries his NAME, not the home
# address (the address lives on the title screen).
const CAT_NAME := "Zander"

# --- v1.0.14 MESHY ZANDER -------------------------------------------------
# Michael's call (2026-11-18): the in-code sculpt is replaced on
# screen by the Meshy model generated from his cover art
# (assets/models/zander.glb). The swap is a GHOST RIG: the sculpt
# still builds exactly as before — every pose system, body-space
# getter and suite contract reads it — but its meshes are hidden,
# and the imported model's skeleton is posed every frame by
# MIRRORING the sculpt rig's pivot state (legs / head / spine /
# tail / ears) onto the matching bones (see _attach_meshy /
# _mirror_meshy at the end of this file). Movement, collision,
# camera and gameplay are untouched; only the drawn cat changes.
# The imported skeleton uses the same axis convention as the
# sculpt (nose +Z, up +Y — verified by tests/meshy_probe.gd), so
# pivot rotations carry across with no axis conversion.
const MESHY_SCENE: PackedScene = preload("res://assets/models/zander.glb")
const MESHY_SCALE := 0.88 # measured (tests/meshy_probe.gd): scales the GLB's nose->rump (0.711) and back height onto the sculpt's (0.627 / 0.322 in model units)
const MESHY_GROUND_Y := 0.256 # the GLB's feet rest at y=-0.291 in its own space; x0.88 -> -0.256, so this lifts them onto model-space y=0

# NORTH STAR VARIANT (look proposal for Michael, 2026-11-18):
# he adopted a Grok illustration as the game's art North Star
# and wants the cat pushed toward it — rounder/chubbier body,
# a BIG head, very large round eyes with worried brow ridges,
# fluffy cheek ruffs, a rich fur-textured orange coat, shorter
# legs, bigger paws. `north_star` restyles the SAME rig at
# build time (proportions, eye size, brows, ruffs, coat
# texture, nose). It defaults OFF, and with it off every build
# path below produces exactly the shipping model — the variant
# exists so Michael can judge comparison stills before any
# shipping change. Harnesses set it on the instance BEFORE the
# node enters the tree (the model builds in _ready).
var north_star: bool = false
# Coat textures actually used by the builders — swapped to the
# North Star coat at the top of _build_model when the flag is
# on; with the flag off they ARE the shipping textures.
var _tex_body: Texture2D = TEX_BODY
var _tex_fur: Texture2D = TEX_FUR
# Eye-stack scale.y bases captured at build time. _apply_idle_pose
# squashes the eyes from these (it used to hardcode the shipping
# sizes, which would have snapped variant eyes back every frame).
var eye_base_y: float = 0.0595
var iris_base_y: float = 0.037
var pupil_base_y: float = 0.018

var speed_walk: float = 5.6
var speed_sprint: float = 11.5 # v0.7: sprint must FEEL fast — nearly 2x walk, well clear of the fastest chaser (7.0)
var gravity: float = 24.0
var jump_vel: float = 8.5
var frozen: bool = true
var is_hidden: bool = false
var is_sprinting: bool = false
var touch_dir: Vector2 = Vector2.ZERO
var touch_sprint: bool = false # v1.0.14: the RUN button's HELD state (set by main3d._on_run_hold) — true only while the button is held down
var cam_yaw: float = 0.0
var main_ref: Node = null

var model: Node3D
var body_node: Node3D
var head_node: Node3D
var ear_l: Node3D
var ear_r: Node3D
var tail_pivots: Array = []
var leg_pivots: Array = [] # FL, FR, BL, BR
var hide_label: Label3D
var walk_phase: float = 0.0
var idle_time: float = 0.0
var hop_airborne: bool = false
# --- v0.6 idle life + purr -------------------------------------------------
var purring: bool = false # set by main when the idle purr is running
var idle_allowed: bool = false # set by main: town gameplay only
var idle_action: String = "" # "" | sit | groom | look | tailflick | pawtap
var idle_action_t: float = 0.0
var idle_action_dur: float = 0.0
var idle_next_in: float = 1.0
var last_idle_action: String = ""
var sit_a: float = 0.0
var groom_a: float = 0.0
var look_a: float = 0.0
var tail_a: float = 0.0
var tap_a: float = 0.0
var sleepy_a: float = 0.0
var eye_l_mi: MeshInstance3D = null # the SCLERA (white ball) since the normal-eye rebuild
var eye_r_mi: MeshInstance3D = null
var iris_l_mi: MeshInstance3D = null
var iris_r_mi: MeshInstance3D = null
var pupil_l_mi: MeshInstance3D = null
var pupil_r_mi: MeshInstance3D = null
var lid_base_y: float = 0.065 # set at build from the lid's resting height; _apply_idle_pose droops from here
var lid_l_mi: MeshInstance3D = null
var lid_r_mi: MeshInstance3D = null
var head_base_pos: Vector3 = Vector3(0, 0.315, 0.27)
var idle_rng := RandomNumberGenerator.new()
var anim_speed: float = 0.0
# --- v0.6 stamina + chase adrenaline --------------------------------------
# Sprinting drains the stamina pool; it refills while not sprinting.
# In a chase, main grants a one-off +25 ADRENALINE pool (shown as the
# RED segment at the end of the HUD bar) that only exists while chased.
# When both pools are empty there is no sprint — escape is turns, hops
# and hiding until the bar recovers.
var stamina: float = 100.0
var stamina_max: float = 100.0
var adrenaline: float = 0.0
var adrenaline_max: float = 25.0
var chase_mode: bool = false # set by main every frame
var want_sprint: bool = false
var winded: bool = false # v0.7: pool fully empty -> sprint locks out until stamina recovers to 30 (the drop back to walk is unmistakable)
var stun_t: float = 0.0 # v0.7 traffic bump: brief comic stun, never hurt
var paw_t: float = 0.0 # v0.7 paw swipe animation timer
var paw_applied: Vector3 = Vector3.ZERO # v0.8: the offset the swipe applied LAST frame — removed before anything else writes the leg, so the swipe is always base+offset and can never accumulate or stick
# --- v0.9 BEING-PETTED reactions -------------------------------------
# A friendly NPC's hand is actually ON the cat (see person.gd): the
# cat leans into it, tail goes UP and waves happily, eyes squint with
# contentment. A treat makes him dip his head down to eat from the
# person's hand. Driven by start_pet_reaction / start_treat_reaction.
var pet_t: float = 0.0 # seconds of petting reaction remaining
var pet_a: float = 0.0 # petting pose envelope 0..1
var treat_t: float = 0.0 # seconds of treat-eating head dip remaining
const TREAT_DUR := 1.15
# --- v1.3 HELD / CARRIED pose (the capture scoop) ---------------------
# Until now a captured cat hung in his standing pose for the whole
# ride — a rigid plank floating at chest height. Now main calls
# start_held() the moment the scoop's lift begins: a brief STARTLE
# (ears flatten, a little tense crouch), then he SETTLES into the
# cradle — front paws folded under his chest, back legs dangling
# loose, tail curled round, chin up looking at the person, the whole
# body pitched into the cradle by main's held path + model pitch
# below. held_a envelopes in/out like pet_a, and every offset is
# additive on the re-based idle bases, same pattern as pet/treat.
var held_a: float = 0.0 # carried pose envelope 0..1
var held_target: float = 0.0
var startle_t: float = 0.0 # seconds of startle remaining
const STARTLE_DUR := 0.38
var collar_tag: MeshInstance3D = null # v0.7: the real 3D tag, for the collar-check camera zoom
var tag_label: Label3D = null # his name ("Zander"), printed ON the tag's face (child of collar_tag)
var collar_parts: Array = [] # STORY PART 1: every collar mesh (band, ring link, tag, paw print) — the opening cutscene drops the WHOLE collar at once (see set_collar_visible)
# v1.0.14 Meshy ghost rig (see the MESHY note at the top):
var meshy_root: Node3D = null # the imported model instance wrapper, child of `model`
var meshy_skel: Skeleton3D = null
var meshy_rest: Dictionary = {} # bone index -> global rest Transform3D (skeleton space)
var meshy_local_rest: Dictionary = {} # bone index -> parent-relative rest Transform3D
var meshy_bone: Dictionary = {} # role -> bone index (fl/fr/bl/br/head/spine/ear_l/ear_r)
var meshy_tail: Array = [] # tail bone indices, base -> tip
var meshy_leg_snap: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO] # leg pivot rotations as the idle branch left them, before _apply_idle_pose's += terms (see _mirror_meshy)
var meshy_leg_snap_fresh := false
# LEGS FIX (2026-11-18): the snapshot above was the shipped bug —
# _apply_idle_pose runs on EVERY _animate call, so the snapshot
# always contained the walk branch's just-assigned swing and the
# mirror's (raw - snapshot) cancelled the gait to ~0.00-0.03 rad
# at the bones (measured, tests/leg_probe.gd) while the sculpt
# swung the full 0.62. The mirror now picks its source by REGIME,
# flagged here by _animate itself:
var meshy_move_raw := false # true on frames where the movement branch ASSIGNED the leg pose (walk / sprint / stun): raw pivot values ARE the intended pose, no differencing
var meshy_held_snap: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO] # leg rotations the HELD block assigned this frame (an absolute pose — differencing it against the idle snapshot ate the cradle fold the same way)
var meshy_held_fresh := false
# Gait synthesis constants for the mirror (the sculpt keeps its
# settled trot; these shape what the MODEL's legs do with it —
# lower-leg fold so the legs BEND, and a true gallop at sprint).
const GAIT_WALK_GAIN := 1.12 # mirror-side gain on the sculpt's 0.62 rad trot swing
const GAIT_GALLOP_AMP := 0.82 # upper-leg swing amplitude (rad) in the gallop
const GAIT_FOLD_FRONT := 0.55 # lower-leg fold (rad) at full protraction, walk
const GAIT_FOLD_REAR := 0.50
const GAIT_FOLD_LEAD := 0.35 # fold peaks slightly ahead of mid-protraction
const GAIT_GALLOP_PITCH := 0.13 # spine pitch flex (rad) in the gallop
const GAIT_GALLOP_BOB := 0.030 # extra body bob (model units) in the gallop

func set_chase_mode(on: bool) -> void:
	if on and not chase_mode:
		adrenaline = adrenaline_max # adrenaline surge when a chase starts
	if not on:
		adrenaline = 0.0
	chase_mode = on

func sprint_pool() -> float:
	return stamina + (adrenaline if chase_mode else 0.0)

# Palette sampled from the reference sheet: rich warm orange fur,
# deeper burnt-orange stripes, creamy whites, leaf-green eyes.
const ORANGE := Color(0.88, 0.47, 0.11)
const ORANGE_LIGHT := Color(0.95, 0.60, 0.20)
const ORANGE_DARK := Color(0.66, 0.30, 0.04)
const CREAM := Color(1.0, 0.97, 0.9)
const WHITE := Color(0.99, 0.98, 0.96)
const EYE_GREEN := Color(0.17, 0.26, 0.06) # deep leaf green sampled from the splash cat's iris (the old 0.15/0.60/0.21 rendered lime — Michael, 2026-11-16: "I don't like the lime green eyes")
const NOSE_PINK := Color(0.96, 0.45, 0.5)
const SILVER := Color(0.84, 0.86, 0.9)

func _mat(c: Color, rough: float = 0.95, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough # ~1.0 = soft matte fur, not shiny plastic
	m.metallic = metallic
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
	sm.radial_segments = 40
	sm.rings = 26
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
	cm.radial_segments = 14
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


const TEX_BODY: Texture2D = preload("res://assets/textures/tabby_body.png")
const TEX_FUR: Texture2D = preload("res://assets/textures/tabby_plain.png")
const TEX_HEAD: Texture2D = preload("res://assets/textures/tabby_head.png")
const TEX_CREAM: Texture2D = preload("res://assets/textures/cream_fur.png")
# v1.0 step 2 (ART OVERHAUL): strand-level NORMAL MAPS for the fur +
# a hair-stroke alpha sheet for the fuzz shell. v0.8/v0.9 fur was a
# flat albedo tint — light slid off it like plastic. The normal map
# makes every strand catch the sun, and RIM light gives the soft
# backlit halo real fur has.
const TEX_BODY_N: Texture2D = preload("res://assets/textures/tabby_body_normal.png")
const TEX_FUR_N: Texture2D = preload("res://assets/textures/tabby_plain_normal.png")
const TEX_HEAD_N: Texture2D = preload("res://assets/textures/tabby_head_normal.png")
const TEX_CREAM_N: Texture2D = preload("res://assets/textures/cream_fur_normal.png")
const TEX_FUR_ALPHA: Texture2D = preload("res://assets/textures/fur_alpha.png")
# NORTH STAR VARIANT coat (2026-11-18): a richer, furrier tabby
# texture (deep saturated orange, soft broken stripes, strand
# grain) generated for the look proposal — used ONLY when the
# north_star flag is on; the shipping cat keeps TEX_BODY/TEX_FUR.
const TEX_NS: Texture2D = preload("res://assets/textures/tabby_northstar.png")

func _normal_for(tex: Texture2D) -> Texture2D:
	if tex == TEX_BODY:
		return TEX_BODY_N
	if tex == TEX_HEAD:
		return TEX_HEAD_N
	if tex == TEX_CREAM:
		return TEX_CREAM_N
	return TEX_FUR_N

func _mat_tex(tex: Texture2D, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	# SPLASH-MATCH colour grade (cat rebuild): the warm sun + sky
	# ambient + the old 0.38 rim washed the coat out to pale YELLOW
	# on the phone. Cutting a little green and more blue out of
	# every fur material keeps the rendered coat the deep, saturated
	# orange of the splash-screen cat, and the rim is turned well
	# down so it stops bleaching the silhouette.
	m.albedo_color = tint * Color(1.0, 0.90, 0.78)
	m.roughness = 0.96
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC # v0.8: crisp fur in motion
	m.normal_enabled = true
	m.normal_texture = _normal_for(tex)
	m.normal_scale = 0.65
	m.rim_enabled = true # soft fur halo against the light
	m.rim = 0.10
	m.rim_tint = 0.4
	return m

func _fur_shell(parent: Node, pos: Vector3, scl: Vector3, tint: Color) -> MeshInstance3D:
	# UNUSED since the step-2 screenshot review (see the note in
	# _build_model): the alpha-shell fuzz read as scratches on the
	# phone-sized cat. Kept only so the experiment is documented.
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 32
	sm.rings = 20
	mi.mesh = sm
	mi.position = pos
	mi.scale = scl * 1.06
	var m := StandardMaterial3D.new()
	m.albedo_texture = TEX_FUR_ALPHA
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.42
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	parent.add_child(mi)
	return mi

func _sphere_tex(parent: Node, pos: Vector3, scl: Vector3, tex: Texture2D, tint: Color = Color.WHITE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 40; sm.rings = 26 # v0.8: smoother silhouette at close camera range
	mi.mesh = sm; mi.position = pos; mi.scale = scl
	mi.material_override = _mat_tex(tex, tint)
	parent.add_child(mi)
	return mi

func _cyl_tex(parent: Node, pos: Vector3, r_top: float, r_bot: float, h: float, tex: Texture2D, tint: Color = Color.WHITE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top; cm.bottom_radius = r_bot; cm.height = h; cm.radial_segments = 18
	mi.mesh = cm; mi.position = pos
	mi.material_override = _mat_tex(tex, tint)
	parent.add_child(mi)
	return mi

# A tabby stripe BAND that actually hugs the body's elliptical cross-section
# (a squashed torus ring), instead of a flat box plank.
func _band(parent: Node, pos: Vector3, rx: float, ry: float, tube: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5 - tube
	tm.outer_radius = 0.5 + tube
	tm.rings = 28; tm.ring_segments = 10
	mi.mesh = tm
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.scale = Vector3(rx * 2.0, 1.0, ry * 2.0)
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

# A flat STRAP ring for the collar: a rectangular cross-section
# (width along Z, thin radially) swept around an ellipse in the
# X-Y plane. Four crisp faces — outer wall, inner wall, two rims —
# each with its own flat normals, so the strap's EDGES read the
# way a real collar band's do (the round-cord _band torus never
# could). Centred on the local origin; position it on the neck.
func _strap_mesh(rx: float, ry: float, width: float, thick: float, segs: int = 40) -> ArrayMesh:
	var hw := width * 0.5
	var ro := Vector2(rx + thick * 0.5, ry + thick * 0.5)
	var ri := Vector2(rx - thick * 0.5, ry - thick * 0.5)
	# Per station: corner points 0 outer/+z, 1 outer/-z,
	# 2 inner/+z, 3 inner/-z, plus the radial outward normal.
	var stations: Array = []
	for i in range(segs + 1):
		var th := TAU * float(i) / float(segs)
		var co := cos(th)
		var si := sin(th)
		var n := Vector2(co / rx, si / ry).normalized()
		stations.append([
			Vector3(ro.x * co, ro.y * si, hw), Vector3(ro.x * co, ro.y * si, -hw),
			Vector3(ri.x * co, ri.y * si, hw), Vector3(ri.x * co, ri.y * si, -hw),
			Vector3(n.x, n.y, 0)])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	# Surfaces as (corner A, corner B, normal kind): the quad strip
	# between the two corner tracks, wound so the supplied normal
	# is the visible side; the strap material is cull-disabled, so
	# a winding slip can never make a face vanish.
	var surfaces := [
		[0, 1, 0], # outer wall — radial normal
		[2, 0, 1], # front rim (+Z)
		[3, 2, 2], # inner wall — inward normal
		[1, 3, 3], # back rim (-Z)
	]
	for s in surfaces:
		var ca: int = s[0]
		var cb: int = s[1]
		var kind: int = s[2]
		var base := verts.size()
		for i in range(segs + 1):
			var st: Array = stations[i]
			var nrm: Vector3 = st[4]
			if kind == 1:
				nrm = Vector3(0, 0, 1)
			elif kind == 2:
				nrm = -st[4]
			elif kind == 3:
				nrm = Vector3(0, 0, -1)
			verts.append(st[ca])
			normals.append(nrm)
			verts.append(st[cb])
			normals.append(nrm)
		for i in range(segs):
			var a0 := base + i * 2
			idx.append_array([a0, a0 + 1, a0 + 2, a0 + 1, a0 + 3, a0 + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# A collar BUCKLE: a little rectangular frame with a centre bar,
# built from thin boxes in the Y-Z plane — the tangent plane at
# the strap's +X side, where `centre` sits. Returns the pieces.
func _buckle(parent: Node, centre: Vector3, mat: Material) -> Array:
	var out: Array = []
	var dims := [
		[Vector3(0, 0.0084, 0), Vector3(0.005, 0.0032, 0.017)], # top bar (runs along Z)
		[Vector3(0, -0.0084, 0), Vector3(0.005, 0.0032, 0.017)], # bottom bar
		[Vector3(0, 0, 0.0069), Vector3(0.005, 0.0136, 0.0032)], # front bar (runs along Y)
		[Vector3(0, 0, -0.0069), Vector3(0.005, 0.0136, 0.0032)], # back bar
		[Vector3(0, 0, 0), Vector3(0.004, 0.0168, 0.0024)], # centre bar
	]
	for d in dims:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = d[1]
		b.mesh = bm
		b.position = centre + (d[0] as Vector3)
		b.material_override = mat
		parent.add_child(b)
		out.append(b)
	return out

func _ready() -> void:
	add_to_group("player")
	idle_rng.randomize()
	_build_collision()
	_build_model()

func _build_collision() -> void:
	var cap := CapsuleShape3D.new()
	# SCALE FIX collision: the capsule is UPRIGHT now. A lying
	# capsule sized to the new cat (top ~0.28) slipped UNDER the
	# fences' bottom rail (rail bottom 0.40) between the posts —
	# the whole fence/cat-gap system silently stopped working.
	# Upright capsule r0.17 h0.55 centred at y=0.275: bottom sits
	# exactly on the ground (no float), top 0.55 still meets the
	# rail, footprint 0.34 across (gaps are 4-6m — no fit change).
	cap.radius = 0.17
	cap.height = 0.55
	# v1.0.13 WALL-CLIP FIX (Michael's screenshot: the cat's rear
	# half sunk into a brick wall beside a door): ONE upright
	# capsule guards only a 0.34 DISC, but the DRAWN cat is long —
	# ScaleProbe measures the built model at nose z=+0.47, rump
	# z=-0.30 (0.77 nose-to-rump, tail trailing to -0.54) against
	# the disc's +/-0.17. Walking nose-first into a wall, the head
	# sank 0.31 in; turning beside a wall swept the body 0.29 in;
	# a door post was swallowed whole (tests/clip_probe.gd, before:
	# head_on 0.314 / turn 0.293 / post overlap 0.18). The fix is a
	# CHAIN of the same upright capsules along the body's long
	# axis (z -0.19 / 0 / +0.155 / +0.31): identical height profile
	# (ground contact and fence rails untouched), identical 0.34
	# width (gap fit untouched — clip probe gaps 0.5/0.4 still
	# pass), but the guarded footprint now spans z -0.36..+0.48,
	# covering rump and nose. The chain rotates with the cat, so
	# turns beside walls push the cat out instead of sweeping the
	# body through. Only the thin trailing tail tip (to -0.54,
	# carried raised/curved in every gait) can still kiss a wall.
	for zoff in [0.155, 0.31, -0.19, 0.0]: # centre capsule added LAST: ScaleProbe reads the last CollisionShape3D child as the primary
		var cs := CollisionShape3D.new()
		cs.shape = cap
		cs.position = Vector3(0, 0.275, zoff)
		add_child(cs)

# ============================================================
# v1.2 SCULPT — the cat is built from SHAPED MESHES now, not from
# stacked primitive chunks. Michael's verdict on the chunk cat:
# "forget the color, the shape is everything" — ~20 spheres/cones/
# tori could only ever read as stacked, segmented pieces next to
# the splash cat's one smooth sculpted shape. So:
#   BODY  — one lofted mesh: elliptical cross-sections swept along
#           the spine, so back curve, belly sag, chest swell, neck
#           waist and haunch bulge are ONE continuous surface. The
#           white chest bib is a second material surface of the
#           same mesh, not an overlapping ball. Tabby stripes come
#           from the fur texture (v runs along the body, so the
#           painted bands wrap across the back like real tabby
#           markings) — the old torus "segment" rings are GONE.
#   HEAD  — one parametric mesh deformed from a sphere by the
#           splash cat's proportions: wide low cheeks, muzzle
#           pushed out of the face itself (and painted cream by
#           surface, not a glued-on ball), flatter face, tapered
#           jaw. Eyes sit FLUSH on the surface, facing forward —
#           the old eye stack protruded ~0.09 and bulged sideways.
#   EARS  — shaped flat triangles with rounded tips and a cupped
#           front, built from the splash outline, not cones.
#   LEGS / TAIL — tapered lofts; stripes from texture, no bands.
# Parts stay separate pivoted pieces (head / body / legs / tail /
# ears) so every animation and behaviour contract is unchanged.
# ============================================================

# Finish a grid-built mesh: smooth normals accumulated from faces
# and signed outward, winding auto-corrected to Godot's front-face
# convention (clockwise from outside — see the note inside), up to
# two material surfaces. All these shapes are star-convex about
# `center`, which makes the orientation test reliable.
func _finish_mesh(verts: PackedVector3Array, uvs: PackedVector2Array, idx_a: PackedInt32Array, idx_b: PackedInt32Array, mat_a: Material, mat_b: Material, center: Vector3) -> ArrayMesh:
	var all_idx := PackedInt32Array()
	all_idx.append_array(idx_a)
	all_idx.append_array(idx_b)
	var tot := 0.0
	for k in range(0, all_idx.size(), 3):
		var pa := verts[all_idx[k]]
		var pb := verts[all_idx[k + 1]]
		var pc := verts[all_idx[k + 2]]
		tot += (pb - pa).cross(pc - pa).dot((pa + pb + pc) / 3.0 - center)
	# Godot front faces wind CLOCKWISE seen from outside — i.e.
	# the winding's own right-hand-rule normal points INWARD,
	# toward `center`. (An earlier version of this helper oriented
	# faces geometric-outward; every closed mesh still showed via
	# its far shell, but OPEN meshes — the eye/nose domes — were
	# culled to invisibility.) So: flip only when the winding
	# normals point outward (tot > 0). The shading normals are
	# accumulated separately and always signed OUTWARD.
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for k in range(0, all_idx.size(), 3):
		var a := all_idx[k]
		var b := all_idx[k + 1]
		var c := all_idx[k + 2]
		var fn := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		normals[a] += fn
		normals[b] += fn
		normals[c] += fn
	var sgn := 1.0 if tot > 0.0 else -1.0
	for i in range(normals.size()):
		if normals[i].length() > 0.00001:
			normals[i] = normals[i].normalized() * sgn
		else:
			normals[i] = (verts[i] - center).normalized()
	if tot > 0.0:
		for k in range(0, all_idx.size(), 3):
			var tmp := all_idx[k + 1]
			all_idx[k + 1] = all_idx[k + 2]
			all_idx[k + 2] = tmp
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = all_idx.slice(0, idx_a.size())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mat_a != null:
		mesh.surface_set_material(0, mat_a)
	if idx_b.size() > 0:
		var arrays2 := []
		arrays2.resize(Mesh.ARRAY_MAX)
		arrays2[Mesh.ARRAY_VERTEX] = verts
		arrays2[Mesh.ARRAY_NORMAL] = normals
		arrays2[Mesh.ARRAY_TEX_UV] = uvs
		arrays2[Mesh.ARRAY_INDEX] = all_idx.slice(idx_a.size())
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays2)
		if mat_b != null:
			mesh.surface_set_material(1, mat_b)
	return mesh

# Simple single-surface mesh with caller-supplied normals (patches,
# ear inners — flat decals that hug another surface).
func _mesh_from(verts: PackedVector3Array, uvs: PackedVector2Array, normals: PackedVector3Array, idx: PackedInt32Array, mat: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mat != null:
		mesh.surface_set_material(0, mat)
	return mesh

# LOFT: sweep an elliptical ring along a list of stations.
# Each station: {c: Vector3 centre, r1/r2: radii along a1/a2, v: texture v}.
# Ring point = c + a1*cos(t)*r1 + a2*sin(t)*r2, seam at -a2 (hidden side).
# cream_fn(t01, sin_mid, z_mid) -> bool routes a quad to surface 2.
func _loft_mesh(stations: Array, a1: Vector3, a2: Vector3, radial: int, mat_a: Material, mat_b: Material, cream_fn: Callable) -> ArrayMesh:
	var rows := stations.size()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var center := Vector3.ZERO
	for s in stations:
		center += (s["c"] as Vector3)
	center /= float(rows)
	for i in range(rows):
		var s: Dictionary = stations[i]
		var c: Vector3 = s["c"]
		for j in range(radial + 1):
			var ang := -PI * 0.5 + TAU * float(j) / float(radial)
			verts.append(c + a1 * (cos(ang) * float(s["r1"])) + a2 * (sin(ang) * float(s["r2"])))
			uvs.append(Vector2(float(j) / float(radial), float(s["v"])))
	var idx_a := PackedInt32Array()
	var idx_b := PackedInt32Array()
	for i in range(rows - 1):
		for j in range(radial):
			var q0 := i * (radial + 1) + j
			var q1 := q0 + 1
			var q2 := q0 + radial + 1
			var q3 := q2 + 1
			var t01 := (float(i) + 0.5) / float(rows - 1)
			var sinm := sin(-PI * 0.5 + TAU * (float(j) + 0.5) / float(radial))
			var zm := ((stations[i]["c"] as Vector3) + (stations[i + 1]["c"] as Vector3)).z * 0.5
			if mat_b != null and cream_fn.is_valid() and bool(cream_fn.call(t01, sinm, zm)):
				idx_b.append_array([q0, q2, q1, q1, q2, q3])
			else:
				idx_a.append_array([q0, q2, q1, q1, q2, q3])
	return _finish_mesh(verts, uvs, idx_a, idx_b, mat_a, mat_b, center)

func _station(c: Vector3, r1: float, r2: float, v: float) -> Dictionary:
	return {"c": c, "r1": r1, "r2": r2, "v": v}

# Body profile, front (chest, +Z) to back (rump, -Z). One sweep:
# throat -> neck waist (the collar sits in it) -> chest swell ->
# shoulders -> mid with a slight belly sag -> haunch -> round rump.
func _body_stations() -> Array:
	# SCALE FIX (post-v1.0.3): the v12 sculpt traced a SITTING
	# portrait at giant size — torso 1.64 long, back at 0.93,
	# i.e. a small pony next to the 1.7m people. These stations
	# are a real standing domestic cat, cute-plump division:
	# torso 0.50 long, 0.24 wide, back top ~0.32, belly ~0.11.
	var raw := [
		[0.25, 0.215, 0.012, 0.012], [0.215, 0.212, 0.082, 0.088],
		[0.165, 0.210, 0.104, 0.100], [0.105, 0.212, 0.116, 0.102],
		[0.03, 0.218, 0.120, 0.098], [-0.05, 0.220, 0.120, 0.096],
		[-0.12, 0.222, 0.121, 0.100], [-0.18, 0.224, 0.114, 0.098],
		[-0.225, 0.226, 0.082, 0.084], [-0.25, 0.228, 0.012, 0.012],
	]
	var out := []
	for r in raw:
		var z: float = r[0]
		var cy: float = r[1]
		var rr1: float = r[2]
		var rr2: float = r[3]
		if north_star:
			# NORTH STAR: chubbier through the chest, barrel and
			# haunches; the throat ring (z >= 0.20) grows less so
			# the collar still sits on the neck. Centres drop a
			# touch so the extra depth reads as a low, round body.
			var wmul := 1.10 if z >= 0.20 else 1.24
			rr1 = r[2] * wmul
			rr2 = r[3] * 1.13
			cy = r[1] - 0.006
		out.append(_station(Vector3(0, cy, z), rr1, rr2, (0.25 - z) / 0.50 * 1.02))
	return out

func _leg_stations() -> Array:
	# pivot space: hip at y=0, paw lands ~y=-0.20 (SCALE FIX:
	# legs were 0.44 AABB on a 0.93 back — stubby; now the leg
	# is ~0.20 long under a 0.32 back, near real-cat ratio).
	# v spans 0..0.38 of the tabby sheet -> SOFT painted stripes.
	var st := [
		_station(Vector3(0, 0.038, 0), 0.007, 0.007, 0.00),
		_station(Vector3(0, 0.016, 0), 0.034, 0.032, 0.02),
		_station(Vector3(0, -0.032, 0), 0.034, 0.032, 0.10),
		_station(Vector3(0, -0.081, 0), 0.031, 0.029, 0.19),
		_station(Vector3(0, -0.124, 0), 0.029, 0.027, 0.27),
		_station(Vector3(0, -0.157, 0), 0.028, 0.027, 0.34),
		_station(Vector3(0, -0.170, 0), 0.030, 0.028, 0.38),
	]
	if north_star:
		# NORTH STAR: shorter (y x0.85) and thicker (r x1.18)
		# legs. _make_leg drops the pivot by the same share so
		# the paw still lands exactly on the ground.
		for s in st:
			var c: Vector3 = s["c"]
			s["c"] = Vector3(c.x, c.y * 0.85, c.z)
			s["r1"] = float(s["r1"]) * 1.18
			s["r2"] = float(s["r2"]) * 1.18
	return st

func _paw_stations() -> Array:
	# a low paw sweeping forward from the ankle (+Z = forward)
	var st := [
		_station(Vector3(0, -0.166, -0.031), 0.005, 0.004, 0.5),
		_station(Vector3(0, -0.166, -0.020), 0.027, 0.017, 0.5),
		_station(Vector3(0, -0.167, 0.007), 0.030, 0.018, 0.5),
		_station(Vector3(0, -0.166, 0.036), 0.028, 0.017, 0.5),
		_station(Vector3(0, -0.164, 0.056), 0.021, 0.014, 0.5),
		_station(Vector3(0, -0.163, 0.065), 0.005, 0.004, 0.5),
	]
	if north_star:
		# NORTH STAR: bigger paws — longer sweep (z x1.12),
		# much rounder (r x1.30), riding at the shortened
		# leg's ankle height (y x0.85).
		for s in st:
			var c: Vector3 = s["c"]
			s["c"] = Vector3(c.x, c.y * 0.85, c.z * 1.12)
			s["r1"] = float(s["r1"]) * 1.30
			s["r2"] = float(s["r2"]) * 1.30
	return st

func _tail_stations() -> Array:
	# one tail segment, base -> rounded tip, drifting back slightly
	var st := [
		_station(Vector3(0, -0.010, 0.001), 0.010, 0.010, 0.00),
		_station(Vector3(0, 0.007, 0.0), 0.022, 0.022, 0.06),
		_station(Vector3(0, 0.034, -0.002), 0.027, 0.027, 0.20),
		_station(Vector3(0, 0.065, -0.005), 0.028, 0.028, 0.34),
		_station(Vector3(0, 0.088, -0.007), 0.024, 0.024, 0.46),
		_station(Vector3(0, 0.107, -0.010), 0.014, 0.014, 0.55),
		_station(Vector3(0, 0.116, -0.011), 0.003, 0.003, 0.60),
	]
	if north_star:
		# NORTH STAR: a fluffier tail (r x1.18); the white tip
		# (v > 0.55 in the loft's cream fn) is unchanged.
		for s in st:
			s["r1"] = float(s["r1"]) * 1.18
			s["r2"] = float(s["r2"]) * 1.18
	return st

# HEAD: a sphere deformed by the splash cat's proportions. d is a
# unit direction from the head centre; the result is the surface
# point. Feature placement (eyes/nose/patches) uses the same
# function, so details sit exactly ON the sculpted surface.
func _head_radii() -> Vector3:
	# NORTH STAR: the head grows ~26% in every axis — the
	# reference cat's head is BIG against its body, the single
	# biggest proportion lever in the illustration.
	return Vector3(0.124, 0.106, 0.103) if north_star else Vector3(0.098, 0.086, 0.084)

func _head_point(d: Vector3) -> Vector3:
	# SCALE FIX: head radii were (0.40, 0.355, 0.345) -> a 0.91m
	# head, WIDER than the torso and 1.8x a person's head. Now
	# (0.098, 0.086, 0.084): ~0.21m wide with cheeks — a cute-big
	# head (~40% of torso length) inside real-cat plausibility
	# (a real head is ~0.125m, ~27% of torso length).
	var hr := _head_radii()
	var p := Vector3(d.x * hr.x, d.y * hr.y, d.z * hr.z)
	# wide, low, fluffy cheeks (the splash head is nearly body-width)
	# NORTH STAR: cheek factor 0.17 -> 0.27 for the round,
	# ruff-framed face in the reference.
	var cheek_k := 0.27 if north_star else 0.17
	var cheek := exp(-pow((d.y + 0.28) / 0.42, 2.0)) * absf(d.x)
	p.x *= 1.0 + cheek_k * cheek
	# muzzle pushed out of the face itself, low and front
	# NORTH STAR: a touch more muzzle (0.020 -> 0.027).
	var muz_k := 0.027 if north_star else 0.020
	var muz := exp(-pow((d.y + 0.38) / 0.34, 2.0)) * maxf(0.0, d.z)
	p.z += muz_k * muz
	if north_star:
		# NORTH STAR RUFF FLARE: the cheek ruff lives in the
		# sculpt itself — the lower-cheek silhouette widens
		# with a gentle vertical scallop, so the jaw line
		# feathers like fur. (Separate cone tufts were tried
		# first and read as hard red spikes in the stills;
		# a silhouette treatment is the honest cheap route.)
		var ruff := exp(-pow((d.y + 0.40) / 0.32, 2.0)) * pow(absf(d.x), 2.0)
		p.x *= 1.0 + 0.10 * ruff * (0.75 + 0.25 * sin(d.y * 26.0))
	# flatter face, slightly flattened crown, fuller back of head
	if d.z > 0.0:
		p.z *= 0.96
	if d.y > 0.55:
		p.y *= 0.945
	if d.z < 0.0:
		p.z *= 1.03
	# jaw tapers under the cheeks
	if d.y < -0.55:
		var k := clampf((-d.y - 0.55) / 0.45, 0.0, 1.0)
		p.x *= 1.0 - 0.13 * k
		p.z *= 1.0 - 0.08 * k
	return p

func _head_normal(d: Vector3) -> Vector3:
	var p := _head_point(d)
	# Shipping denominators are the shipping radii squared,
	# rounded (0.0096 / 0.0074 / 0.0071) — kept verbatim so the
	# flag-off head is untouched; the variant divides by its
	# own radii squared.
	var n := Vector3(p.x / 0.0096, p.y / 0.0074, p.z / 0.0071)
	if north_star:
		var hr := _head_radii()
		n = Vector3(p.x / (hr.x * hr.x), p.y / (hr.y * hr.y), p.z / (hr.z * hr.z))
	return n.normalized() if n.length() > 0.001 else Vector3(0, 0, 1)

func _head_mesh() -> ArrayMesh:
	var rows := 26
	var cols := 36
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(rows + 1):
		var phi := PI * float(i) / float(rows)
		for j in range(cols + 1):
			var th := TAU * float(j) / float(cols)
			var d := Vector3(sin(phi) * sin(th + PI), cos(phi), sin(phi) * cos(th + PI))
			verts.append(_head_point(d))
			uvs.append(Vector2(float(j) / float(cols), float(i) / float(rows)))
	var idx_a := PackedInt32Array()
	var idx_b := PackedInt32Array()
	for i in range(rows):
		for j in range(cols):
			var q0 := i * (cols + 1) + j
			var q1 := q0 + 1
			var q2 := q0 + cols + 1
			var q3 := q2 + 1
			var pm := PI * (float(i) + 0.5) / float(rows)
			var tm := TAU * (float(j) + 0.5) / float(cols)
			var dm := Vector3(sin(pm) * sin(tm + PI), cos(pm), sin(pm) * cos(tm + PI))
			# cream surface: the muzzle (front + low) and the chin
			if (dm.z > 0.40 and dm.y < 0.12) or (dm.y < -0.58 and dm.z > 0.05):
				idx_b.append_array([q0, q2, q1, q1, q2, q3])
			else:
				idx_a.append_array([q0, q2, q1, q1, q2, q3])
	return _finish_mesh(verts, uvs, idx_a, idx_b, _mat_tex(_tex_fur), _mat_tex(TEX_CREAM), Vector3.ZERO)

# A shallow dome (unit: rim radius 0.5 in XY, pole at z=+0.5) —
# eyes, nose, eyelids. Scaled per use.
func _dome_mesh(phi_max: float = 1.25, rings: int = 6, segs: int = 20) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(rings + 1):
		var phi := phi_max * float(i) / float(rings)
		for j in range(segs + 1):
			var th := TAU * float(j) / float(segs)
			verts.append(0.5 * Vector3(sin(phi) * sin(th), sin(phi) * cos(th), cos(phi)))
			uvs.append(Vector2(float(j) / float(segs), float(i) / float(rings)))
	var idx := PackedInt32Array()
	for i in range(rings):
		for j in range(segs):
			var q0 := i * (segs + 1) + j
			var q1 := q0 + 1
			var q2 := q0 + segs + 1
			var q3 := q2 + 1
			idx.append_array([q0, q2, q1, q1, q2, q3])
	return _finish_mesh(verts, uvs, idx, PackedInt32Array(), null, null, Vector3(0, 0, 0.1))

# A marking that hugs the head: a small curved patch floated just
# off the sculpted surface (forehead "M", cheek strokes).
func _patch_on_head(d_center: Vector3, w: float, h: float, ang_deg: float, mat: Material) -> void:
	var d0 := d_center.normalized()
	var t1 := Vector3.UP.cross(d0)
	t1 = t1.normalized() if t1.length() > 0.1 else Vector3.RIGHT
	var t2 := d0.cross(t1).normalized()
	var ang := deg_to_rad(ang_deg)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var gx := 4
	var gy := 3
	for iy in range(gy + 1):
		for ix in range(gx + 1):
			var a := -1.0 + 2.0 * float(ix) / float(gx)
			var b := -1.0 + 2.0 * float(iy) / float(gy)
			var ra := a * cos(ang) - b * sin(ang)
			var rb := a * sin(ang) + b * cos(ang)
			var d := (d0 + t1 * (ra * w) + t2 * (rb * h)).normalized()
			verts.append(_head_point(d) + _head_normal(d) * 0.004)
			normals.append(_head_normal(d))
			uvs.append(Vector2(a * 0.5 + 0.5, b * 0.5 + 0.5))
	var idx := PackedInt32Array()
	for iy in range(gy):
		for ix in range(gx):
			var q0 := iy * (gx + 1) + ix
			var q1 := q0 + 1
			var q2 := q0 + gx + 1
			var q3 := q2 + 1
			idx.append_array([q0, q1, q2, q1, q3, q2])
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_from(verts, uvs, normals, idx, mat)
	head_node.add_child(mi)

func _make_leg(x: float, z: float) -> Node3D:
	var pivot := Node3D.new()
	# NORTH STAR: the pivot drops 0.205 -> 0.175 to match the
	# shortened leg stations (y x0.85), so the paw still lands
	# at the same ground plane and every animation rotation
	# about the pivot is unchanged.
	pivot.position = Vector3(x, 0.175 if north_star else 0.205, z)
	model.add_child(pivot)
	# one tapered loft — stripes are the texture's soft painted
	# bands now, not dark cylinder hoops around a tube
	var leg_mi := MeshInstance3D.new()
	leg_mi.mesh = _loft_mesh(_leg_stations(), Vector3.RIGHT, Vector3.BACK, 18, _mat_tex(_tex_body), null, Callable())
	pivot.add_child(leg_mi)
	var paw_mi := MeshInstance3D.new()
	paw_mi.mesh = _loft_mesh(_paw_stations(), Vector3.RIGHT, Vector3.UP, 18, _mat_tex(TEX_CREAM), null, Callable())
	pivot.add_child(paw_mi)
	# NORTH STAR: toe/bean accents ride the shortened leg (y
	# x0.85) and the longer paw sweep (z x1.12); shipping
	# placements are exact when the flag is off.
	var ls := 0.85 if north_star else 1.0
	var zs := 1.12 if north_star else 1.0
	for tx in [-0.019, 0.0, 0.019]:
		_box(pivot, Vector3(tx, -0.161 * ls, 0.059 * zs), Vector3(0.005, 0.017, 0.007), ORANGE_DARK)
	for tx2 in [-0.017, 0.0, 0.017]: # pink toe beans under each toe
		_sphere(pivot, Vector3(tx2, -0.193 * ls, 0.032 * zs), Vector3(0.010, 0.006, 0.009), Color(0.94, 0.55, 0.58))
	return pivot

func _build_model() -> void:
	# v1.2: the whole sculpt sits under a VisualRoot scaled by
	# VISUAL_SCALE (see the note at the top). Everything inside the
	# model — pivots, animation offsets, the hop squash on model.scale.y
	# — is untouched; only the rendered size grows.
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.scale = Vector3.ONE * VISUAL_SCALE
	add_child(visual_root)
	model = Node3D.new()
	model.name = "CatModel"
	visual_root.add_child(model)
	body_node = Node3D.new()
	model.add_child(body_node)
	# NORTH STAR: swap the coat to the richer fur texture for
	# every builder below (body, head, legs, tail, ears, lids).
	if north_star:
		_tex_body = TEX_NS
		_tex_fur = TEX_NS
	# --- BODY: one lofted sculpt (see the SCULPT note above) ---
	# Cream surface = a chest bib ONLY: throat wrap + upper chest.
	var body_cream := func(t01: float, sinm: float, zm: float) -> bool:
		# CHEST PATCH (Michael, 2026-11-18, second pass — the first
		# pass still wrapped the whole chest depth and showed as a
		# broad white region down the underside): the bib lives on
		# the throat and the UPPER chest and ends ahead of the
		# front legs. Throat cone: wraps except the neck top.
		# Chest row: bottom + lower sides only (sinm < 0.18), so
		# the white no longer climbs the chest walls. One row
		# further back only the very bottom centre dips in
		# (sinm < -0.78) — a soft point to the patch, not a band.
		# Everything behind/below that line is orange tabby.
		if zm >= 0.205:
			return sinm < 0.55
		if zm >= 0.155:
			return sinm < 0.18
		if zm >= 0.125:
			return sinm < -0.78
		return false
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = _loft_mesh(_body_stations(), Vector3.RIGHT, Vector3.UP, 36, _mat_tex(_tex_body), _mat_tex(TEX_CREAM), body_cream)
	body_node.add_child(body_mi)
	# --- Legs (short, pivots at hips/shoulders) ---
	leg_pivots.append(_make_leg(-0.082, 0.145))
	leg_pivots.append(_make_leg(0.082, 0.145))
	leg_pivots.append(_make_leg(-0.086, -0.155))
	leg_pivots.append(_make_leg(0.086, -0.155))
	# --- HEAD: one sculpted parametric mesh ---
	head_node = Node3D.new()
	# NORTH STAR: the bigger head sits a touch higher and
	# further forward on the chubbier neck; head_base_pos
	# follows so idle/treat head motion orbits the new home.
	head_node.position = Vector3(0, 0.345, 0.290) if north_star else Vector3(0, 0.315, 0.27)
	head_base_pos = head_node.position
	model.add_child(head_node)
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = _head_mesh()
	head_node.add_child(head_mi)
	# forehead "M": four short dark strokes fanning from centre,
	# as curved patches ON the surface (were floating boxes)
	var dark_mat := _mat(ORANGE_DARK)
	dark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(4):
		var fx := -0.17 + float(i) * 0.113
		_patch_on_head(Vector3(fx, 0.62, 0.74), 0.030, 0.082, (float(i) - 1.5) * 13.0, dark_mat)
	# cheek tabby strokes: three short marks fanning on each cheek
	for sxc in [-1.0, 1.0]:
		for ci in range(3):
			_patch_on_head(Vector3(sxc * (0.56 + float(ci) * 0.05), -0.04 - float(ci) * 0.13, 0.74), 0.072, 0.015, sxc * (-14.0 + float(ci) * 11.0), dark_mat)
	# NOSE: a shallow glossy dome sitting on the muzzle surface
	var nose_d := Vector3(0, -0.10, 1.0).normalized()
	var nose_p := _head_point(nose_d)
	var nose_mi := MeshInstance3D.new()
	nose_mi.mesh = _dome_mesh(1.15)
	# NORTH STAR: a bigger, pinker nose (the reference nose is
	# a clear pink, not brick).
	nose_mi.scale = Vector3(0.031, 0.020, 0.013) * (1.30 if north_star else 1.0)
	nose_mi.position = nose_p + Vector3(0, 0, 0.001)
	nose_mi.material_override = _mat(Color(0.96, 0.47, 0.54) if north_star else Color(0.93, 0.38, 0.44), 0.32) # moist — slight gloss
	head_node.add_child(nose_mi)
	# whisker roots: three tiny dark dots each side of the muzzle
	for sxw in [-1.0, 1.0]:
		for wi2 in range(3):
			var rd := Vector3(sxw * (0.20 + float(wi2) * 0.085), -0.30 - float(wi2 % 2) * 0.05, 1.0).normalized()
			_sphere(head_node, _head_point(rd) + _head_normal(rd) * 0.001, Vector3(0.004, 0.004, 0.003), Color(0.45, 0.25, 0.12))
	# open smiling mouth + tongue, tucked under the muzzle
	# NORTH STAR: the mouth rides the bigger head's surface
	# (z x1.23, a touch lower and larger) so it stays visible
	# instead of sinking into the grown muzzle.
	var mzs := 1.23 if north_star else 1.0
	var mss := 1.20 if north_star else 1.0
	_sphere(head_node, Vector3(0, -0.045 * mss, 0.084 * mzs), Vector3(0.031, 0.017, 0.011) * mss, Color(0.42, 0.14, 0.12))
	_sphere(head_node, Vector3(0, -0.052 * mss, 0.086 * mzs), Vector3(0.017, 0.009, 0.008) * mss, Color(0.96, 0.52, 0.54))
	# whiskers: 3 thin lines each side, fanned FORWARD off the
	# muzzle with a gentle downward droop — the old near-
	# horizontal set stuck straight out sideways and read as
	# stiff wires on the cover close-ups (Michael, 2026-11-18).
	# NORTH STAR: whisker roots ride the wider, deeper head.
	var wx := 0.118 if north_star else 0.093
	var wz := 0.114 if north_star else 0.093
	var wl := 0.088 if north_star else 0.078
	for sx in [-1.0, 1.0]:
		for wi in range(3):
			var whisker := _cyl(head_node, Vector3(sx * wx, -0.020 - float(wi) * 0.012, wz), 0.0016, 0.0016, wl, Color(0.93, 0.91, 0.87))
			whisker.rotation_degrees = Vector3(-12.0 - float(wi) * 5.0, sx * 26.0, sx * (64.0 - float(wi) * 7.0))
	# BIG ROUND green eyes, set FORWARD and FLUSH on the face:
	# a flat stack of shallow domes on the surface point — dark
	# outline, glossy iris, round pupil, clear cornea, sparkles.
	# NOTE: _apply_idle_pose squashes the whole stack from the
	# base scale.y values captured at the end of this loop
	# (shipping: sclera 0.0595 / iris 0.037 / pupil 0.018)
	# (SCALE FIX: was 0.24 when the head was 0.91m wide).
	# NORTH STAR: the whole stack grows x1.38 (depth x1.30) and
	# sits a touch wider/higher — the reference's eyes are HUGE
	# and round, the face's whole expression.
	var es := 1.38 if north_star else 1.0
	var ez := 1.30 if north_star else 1.0
	for sx in [-0.40, 0.40]:
		var ed := Vector3(sx * (1.10 if north_star else 1.0), 0.34 if north_star else 0.30, 1.0).normalized()
		var ep := _head_point(ed)
		var base := ep + Vector3(0, 0, 0.001)
		var outline := MeshInstance3D.new()
		outline.mesh = _dome_mesh(1.30)
		outline.scale = Vector3(0.062, 0.066, 0.014) * Vector3(es, es, ez)
		outline.position = base
		outline.material_override = _mat(Color(0.08, 0.06, 0.05), 0.55)
		head_node.add_child(outline)
		# NORMAL EYE (Michael, 2026-11-18): white of the eye
		# FIRST — a sclera dome the iris sits on. The solid
		# green orb read "soulless"; he asked for regular eyes:
		# whites, green irises, dark pupils, a highlight.
		var sclera := MeshInstance3D.new()
		sclera.mesh = _dome_mesh(1.25)
		sclera.scale = Vector3(0.0545, 0.0595, 0.015) * Vector3(es, es, ez)
		sclera.position = base + Vector3(0, 0, 0.001)
		sclera.material_override = _mat(Color(0.97, 0.96, 0.93), 0.35)
		head_node.add_child(sclera)
		var iris := MeshInstance3D.new()
		iris.mesh = _dome_mesh(1.20)
		iris.scale = Vector3(0.031, 0.037, 0.0165) * Vector3(es, es, ez)
		iris.position = base + Vector3(0, 0, 0.0035 * es)
		var iris_mat := StandardMaterial3D.new()
		# NORTH STAR: a richer, more saturated green (still not
		# the lime Michael rejected — a deep leaf green).
		iris_mat.albedo_color = Color(0.18, 0.33, 0.06) if north_star else EYE_GREEN
		iris_mat.roughness = 0.12
		iris_mat.metallic = 0.05
		# COVER FIX (Michael, 2026-11-18): at dusk the deep-green
		# albedo alone rendered as a BLACK VOID in close-up — the
		# green never reached the camera. A dim green emission in
		# the same colour family lifts the iris so it READS green
		# at cover range without going back to the lime he hated.
		iris_mat.emission_enabled = true
		iris_mat.emission = Color(0.05, 0.16, 0.015) if north_star else Color(0.05, 0.14, 0.015)
		iris.material_override = iris_mat
		head_node.add_child(iris)
		var pupil := MeshInstance3D.new()
		pupil.mesh = _dome_mesh(1.10)
		pupil.scale = Vector3(0.012, 0.018, 0.012) * Vector3(es, es, ez) # NORMAL EYE: pupil clearly smaller than the iris, a touch taller than wide
		pupil.position = base + Vector3(0, -0.0005, 0.0095 * es)
		pupil.material_override = _mat(Color(0.04, 0.04, 0.04), 0.4)
		head_node.add_child(pupil)
		var cornea := MeshInstance3D.new()
		cornea.mesh = _dome_mesh(1.25)
		cornea.scale = Vector3(0.0575, 0.0625, 0.021) * Vector3(es, es, ez)
		cornea.position = base + Vector3(0, 0, 0.003)
		var cornea_mat := StandardMaterial3D.new()
		cornea_mat.albedo_color = Color(1, 1, 1, 0.07) # COVER FIX: thinner film — the old 0.10 + metallic sheen helped mute the iris to black
		cornea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cornea_mat.roughness = 0.03
		cornea_mat.metallic = 0.0
		cornea.material_override = cornea_mat
		head_node.add_child(cornea)
		var lid := MeshInstance3D.new()
		lid.mesh = _dome_mesh(1.05)
		# NORTH STAR: the lid grows in WIDTH with the eye but
		# keeps the shipping THINNESS — scaled up in y it read
		# as a red disc floating over the eye in the first
		# North Star stills.
		lid.scale = Vector3(0.056, 0.013, 0.021) * Vector3(es, 1.0 if north_star else es, ez)
		# COVER FIX (Michael, 2026-11-18): the lid used to float
		# at a fixed y=0.065, ~0.04 above the eye centre — at
		# cover range it detached completely and read as a RED
		# OVAL hovering over each eye (proven by hiding
		# lid_l_mi/lid_r_mi in a staged frame: both ovals
		# vanished). It now hugs the eye stack, overlapping the
		# outline dome's top edge like a real eyelid.
		lid.position = Vector3(ep.x, ep.y + 0.031 * es, ep.z - 0.003)
		lid.rotation_degrees = Vector3(-28, 0, 0)
		lid.material_override = _mat_tex(_tex_fur)
		head_node.add_child(lid)
		lid_base_y = lid.position.y
		# Capture the built eye bases for _apply_idle_pose's
		# squash — identical to the old hardcoded constants when
		# the flag is off, the grown sizes when it is on.
		eye_base_y = sclera.scale.y
		iris_base_y = iris.scale.y
		pupil_base_y = pupil.scale.y
		if sx < 0.0:
			eye_l_mi = sclera
			iris_l_mi = iris
			pupil_l_mi = pupil
			lid_l_mi = lid
		else:
			eye_r_mi = sclera
			iris_r_mi = iris
			pupil_r_mi = pupil
			lid_r_mi = lid
		# NORTH STAR: sparkles grow only a little (ss) — at the
		# full eye scale they read as white balls stuck on the
		# iris in the first stills.
		var ss := 1.12 if north_star else 1.0
		_sphere(head_node, base + Vector3(0.011 * ss, 0.018 * ss, 0.012 * ss), Vector3(0.014, 0.014, 0.005) * ss, WHITE)
		_sphere(head_node, base + Vector3(-0.010 * ss, -0.012 * ss, 0.011 * ss), Vector3(0.007, 0.007, 0.004) * ss, WHITE)
	if north_star:
		# NORTH STAR EXPRESSION (variant only): the reference
		# cat's face is WORRIED-cute — brow ridges slanting
		# down toward the nose. Brows are surface patches in a
		# mid-dark orange (fur shadow, not a drawn line). The
		# cheek ruff is sculpted into the head silhouette
		# itself (see the ruff flare in _head_point).
		var brow_mat := _mat(Color(0.55, 0.23, 0.02))
		brow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for sxb in [-1.0, 1.0]:
			_patch_on_head(Vector3(sxb * 0.37, 0.64, 0.82), 0.125, 0.026, sxb * 28.0, brow_mat)
	ear_l = _make_ear(-0.066 if north_star else -0.052)
	ear_r = _make_ear(0.066 if north_star else 0.052)
	# --- The collar: a real CAT collar (Michael, 2026-11-18) ---
	# The old build was a round-cord torus ring and a 6 cm disc —
	# it read as a rubber ring with a dinner plate. A collar is a
	# FLAT STRAP with hardware: strap, buckle, D-ring, and a tag
	# sized like a real pet tag (2.5 cm) hanging at the chest.
	# STORY PART 1: every piece is registered in collar_parts so
	# the opening cutscene can take the whole collar off in one
	# call (and the homecoming can put it back).
	var collar_metal := _mat(Color(0.78, 0.80, 0.84), 0.35, 0.5) # satin silver — stays silver at dusk (full-metal mirrored the dark sky and went black)
	var strap_mat := _mat(Color(0.055, 0.055, 0.07), 0.88) # black fabric strap
	strap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# NORTH STAR: the strap grows x1.16 around the chubbier
	# throat so it still sits ON the neck, not inside it.
	var cs := 1.16 if north_star else 1.0
	var strap := MeshInstance3D.new()
	strap.mesh = _strap_mesh(0.0835 * cs, 0.0865 * cs, 0.013, 0.0038)
	strap.position = Vector3(0, 0.248 + (0.004 if north_star else 0.0), 0.215)
	strap.material_override = strap_mat
	model.add_child(strap)
	collar_parts.append(strap)
	# The buckle: a little rectangular frame with its centre bar,
	# standing proud of the strap on his right side.
	for piece in _buckle(model, Vector3(0.0864 * cs, 0.248, 0.215), collar_metal):
		collar_parts.append(piece)
	# The D-ring at the throat: its top tucks into the strap's
	# lower edge, and the tag hangs from it.
	var dring := MeshInstance3D.new()
	var dtm := TorusMesh.new()
	dtm.inner_radius = 0.0059
	dtm.outer_radius = 0.0091
	dtm.rings = 16
	dtm.ring_segments = 8
	dring.mesh = dtm
	dring.position = Vector3(0, 0.143, 0.2285) if north_star else Vector3(0, 0.155, 0.2245)
	dring.rotation_degrees = Vector3(90, 0, 0)
	dring.material_override = collar_metal
	model.add_child(dring)
	collar_parts.append(dring)
	# The tag: 2.5 cm across, hanging from the ring in the hollow
	# under his throat, face forward, tipped back a touch the way
	# a worn tag rests.
	# NORTH STAR: the tag drops a touch lower/further forward
	# so it clears the grown chest instead of clipping into it.
	var tag := _cyl(model, Vector3(0, 0.134, 0.236) if north_star else Vector3(0, 0.1385, 0.2285), 0.0125, 0.0125, 0.0024, SILVER)
	collar_tag = tag
	collar_parts.append(tag)
	tag.rotation_degrees = Vector3(82, 0, 0)
	tag.material_override = collar_metal
	# --- His name, printed ON the tag's face ---
	# A Label3D riding as a CHILD of the tag mesh — no billboard, so
	# it moves and tilts with the tag exactly, like print on metal.
	# Tag-local frame: the tag cylinder's axis is +Y and its front
	# cap faces +Y, so the label lies flat against that cap: a -90
	# rotation about X turns the label's facing (+Z) onto +Y and its
	# text-up onto the model's up. It floats 0.0026 along +Y — the
	# cap is at 0.0012 — so the print rests just off the face.
	# Dark print on the pale metal, like an engraved tag.
	tag_label = Label3D.new()
	tag_label.font_size = 64
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_label.modulate = Color(0.10, 0.10, 0.13)
	tag_label.outline_size = 8
	tag_label.outline_modulate = Color(0.95, 0.96, 0.98, 0.85)
	tag_label.position = Vector3(0, 0.0026, 0)
	tag_label.rotation_degrees = Vector3(-90, 0, 0)
	tag.add_child(tag_label)
	# --- Tail: 3 chained lofted segments, tapering, white tip ---
	var parent_node: Node3D = model
	var base_pos := Vector3(0, 0.26, -0.225)
	for i in range(3):
		var pivot := Node3D.new()
		pivot.position = base_pos if i == 0 else Vector3(0, 0.095, -0.007)
		parent_node.add_child(pivot)
		var seg_mi := MeshInstance3D.new()
		if i == 2:
			seg_mi.mesh = _loft_mesh(_tail_stations(), Vector3.RIGHT, Vector3.BACK, 20, _mat_tex(_tex_body), _mat_tex(TEX_CREAM),
				func(t01: float, sinm: float, zm: float) -> bool: return t01 > 0.55)
		else:
			seg_mi.mesh = _loft_mesh(_tail_stations(), Vector3.RIGHT, Vector3.BACK, 20, _mat_tex(_tex_body), null, Callable())
		pivot.add_child(seg_mi)
		pivot.rotation_degrees = Vector3(-19, 0, 0)
		tail_pivots.append(pivot)
		parent_node = pivot
	hide_label = Label3D.new()
	hide_label.text = "🌿 hidden"
	hide_label.font_size = 30
	hide_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hide_label.position = Vector3(0, 0.68, 0)
	hide_label.modulate = Color(0.6, 1.0, 0.6)
	hide_label.visible = false
	add_child(hide_label)
	# v1.0.14: hang the Meshy model on this rig and hide the sculpt
	_attach_meshy()

# A SHAPED ear: a broad flat triangle with a rounded tip, traced
# from the splash cat — not a cone. Three things make it read as
# an ear from every angle: a SKIRT below the pivot line so the
# base sinks into the head (no floating gap), an outward lean,
# and a ~20 degree yaw so the SIDE view sees a triangular wedge
# instead of a paper-thin edge.
func _ear_outline() -> Array:
	# SCALE FIX: the splash-traced outline at 0.30x — ear height
	# 0.49 -> 0.147, so ear tips land ~0.51 instead of 1.52.
	# EAR TRIM (Michael, 2026-11-18): "not quite that big" — the
	# traced outline at 0.82x (18% off height and width, tips now
	# ~0.483). Same shape, forward set and skirt; just less ear.
	var raw := [
		Vector2(-0.0384, -0.027), Vector2(-0.0414, 0.006), Vector2(-0.0432, 0.036),
		Vector2(-0.036, 0.0705), Vector2(-0.0192, 0.099), Vector2(0.000, 0.120),
		Vector2(0.0192, 0.099), Vector2(0.0348, 0.0675), Vector2(0.0411, 0.0345),
		Vector2(0.0384, 0.006), Vector2(0.0366, -0.027),
	]
	# NORTH STAR: ears trim a further ~12% — against the bigger
	# head the shipping ears towered in the first stills.
	var ek := 0.82 * (0.88 if north_star else 1.0)
	var out := []
	for p in raw:
		out.append(Vector2(p.x * ek, p.y * ek))
	return out

func _ear_xform(p: Vector2, z: float, side: float) -> Vector3:
	var tilt := -side * deg_to_rad(7.0)
	var x := p.x * cos(tilt) - p.y * sin(tilt)
	var y := p.x * sin(tilt) + p.y * cos(tilt)
	x += side * 0.014
	var b := side * deg_to_rad(28.0)
	return Vector3(x * cos(b) + z * sin(b), y, -x * sin(b) + z * cos(b))

func _ear_mesh(side: float) -> ArrayMesh:
	var outline := _ear_outline()
	var n := outline.size()
	var cf := _ear_xform(Vector2(0, 0.045), 0.013, side)
	var cb := _ear_xform(Vector2(0, 0.045), -0.004, side)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	# vertex layout: 0 = front centre, 1..n = front loop,
	# n+1 = back centre, n+2..2n+1 = back loop
	verts.append(cf)
	uvs.append(Vector2(0.5, 0.4))
	for p in outline:
		var v := _ear_xform(p, 0.007, side)
		verts.append(v)
		uvs.append(Vector2(v.x * 5.3 + 0.5, v.y * 5.3))
	verts.append(cb)
	uvs.append(Vector2(0.5, 0.4))
	for p in outline:
		var v2 := _ear_xform(p, -0.007, side)
		verts.append(v2)
		uvs.append(Vector2(v2.x * 5.3 + 0.5, v2.y * 5.3))
	var idx := PackedInt32Array()
	for i in range(n):
		var f0 := 1 + i
		var f1 := 1 + (i + 1) % n
		var b0 := n + 2 + i
		var b1 := n + 2 + (i + 1) % n
		idx.append_array([0, f0, f1]) # front fan
		idx.append_array([n + 1, b1, b0]) # back fan
		idx.append_array([f0, f1, b1, f0, b1, b0]) # rim
	return _finish_mesh(verts, uvs, idx, PackedInt32Array(), _mat_tex(_tex_fur), null, Vector3(cf.x, cf.y, 0))

func _ear_inner_mesh(side: float) -> ArrayMesh:
	var outline := _ear_outline()
	var b := side * deg_to_rad(28.0)
	var nrm := Vector3(sin(b), 0, cos(b))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	verts.append(_ear_xform(Vector2(0, 0.044), 0.013, side))
	normals.append(nrm)
	uvs.append(Vector2(0.5, 0.4))
	for p in outline:
		var sp := Vector2(p.x * 0.58, p.y * 0.60 + 0.015)
		var v := _ear_xform(sp, 0.009, side)
		verts.append(v)
		normals.append(nrm)
		uvs.append(Vector2(v.x + 0.5, v.y))
	var idx := PackedInt32Array()
	for i in range(outline.size()):
		idx.append_array([0, 1 + i, 1 + (i + 1) % outline.size()])
	return _mesh_from(verts, uvs, normals, idx, _mat(Color(0.90, 0.42, 0.42), 0.9))

func _make_ear(x: float) -> Node3D:
	var pivot := Node3D.new()
	# NORTH STAR: ear pivots ride the bigger head (up, out,
	# a touch back); shipping placement exact when off.
	pivot.position = Vector3(x, 0.418 if north_star else 0.385, 0.270 if north_star else 0.255)
	model.add_child(pivot)
	var side := 1.0 if x > 0.0 else -1.0
	var outer := MeshInstance3D.new()
	outer.mesh = _ear_mesh(side)
	pivot.add_child(outer)
	var inner := MeshInstance3D.new()
	inner.mesh = _ear_inner_mesh(side)
	pivot.add_child(inner)
	return pivot

func _physics_process(delta: float) -> void:
	# Gravity always applies so Hop is a real jump arc
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.5
	if frozen:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_animate(delta, 0.0)
		return
	if stun_t > 0.0:
		# Traffic bump (v0.7): knocked sideways, briefly stunned.
		# Points only — the cat is never hurt.
		stun_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)
		move_and_slide()
		global_position.x = clamp(global_position.x, -194.0, 590.0) # SHORELINE ACCESS (v1.0.14): backstop only — the IslandShore wall stops him ~2 m short of the water, well inside these bounds; east stays 590 for the escape room
		global_position.z = clamp(global_position.z, -164.0, 164.0)
		_animate(delta, Vector2(velocity.x, velocity.z).length())
		return
	var dir2 := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir2.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir2.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir2.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir2.y += 1.0
	var touch_mag: float = 1.0
	var from_touch := false
	if dir2 == Vector2.ZERO and touch_dir != Vector2.ZERO:
		dir2 = touch_dir
		from_touch = true
		touch_mag = clampf(dir2.length(), 0.0, 1.0)
		if touch_mag < 0.12:
			dir2 = Vector2.ZERO # joystick deadzone
	dir2 = dir2.normalized()
	# v1.0.14 RUN HOLD (Michael's direction, superseding v0.7's
	# push-to-sprint and v1.0.13's press-to-toggle, which he reversed
	# after playing it): the joystick NEVER sprints on its own any
	# more — a full push "rocketed off". Sprint comes only from the
	# RUN button while it is HELD (touch_sprint, set by
	# main3d._on_run_hold) or the PC Shift key (also hold). The
	# stamina/winded gate below is unchanged: an empty pool still
	# drops the cat to walk until recovery, even while RUN stays
	# held, and sprint then resumes.
	want_sprint = Input.is_physical_key_pressed(KEY_SHIFT) or touch_sprint
	# Stamina gate (v0.7): sprint only while the pool lasts. When the
	# pool (stamina + chase adrenaline) hits EMPTY the cat is WINDED:
	# speed drops straight back to walk and sprint stays locked out
	# until stamina alone recovers to 30 — no mushy in-between.
	if winded and stamina >= 30.0:
		winded = false
	is_sprinting = want_sprint and dir2 != Vector2.ZERO and not winded and sprint_pool() > 0.5
	if want_sprint and dir2 != Vector2.ZERO and sprint_pool() <= 0.5:
		winded = true
	if is_sprinting:
		var drain: float = 13.0 * delta # ~7-8s of full sprint (+adrenaline in a chase)
		if chase_mode and adrenaline > 0.0:
			var from_ad: float = minf(adrenaline, drain * 0.5)
			adrenaline -= from_ad
			drain -= from_ad
		stamina = maxf(0.0, stamina - drain)
	else:
		stamina = minf(stamina_max, stamina + (9.0 if dir2 == Vector2.ZERO else 5.0) * delta)
	var spd: float = speed_sprint if is_sprinting else speed_walk
	if from_touch and not is_sprinting:
		spd = speed_walk * (0.55 + 0.45 * touch_mag) # small drag = gentle walk
	# Camera-yaw-relative (v0.4): the input vector is rotated by the
	# camera's orbit yaw, so up always walks away from wherever the
	# camera currently is. At yaw 0 this is exactly the v0.3 mapping.
	var dir3: Vector3 = Basis(Vector3.UP, cam_yaw) * Vector3(dir2.x, 0, dir2.y)
	velocity.x = dir3.x * spd
	velocity.z = dir3.z * spd
	# --- TURN: smoothly rotate the whole cat to face the movement direction ---
	if dir3.length() > 0.05:
		var target_yaw: float = atan2(dir3.x, dir3.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, min(1.0, 14.0 * delta))
	move_and_slide()
	global_position.x = clamp(global_position.x, -194.0, 590.0) # SHORELINE ACCESS (v1.0.14): backstop only — the IslandShore wall stops him ~2 m short of the water, well inside these bounds; east stays 590 for the escape room
	global_position.z = clamp(global_position.z, -164.0, 164.0)
	var speed2d: float = Vector2(velocity.x, velocity.z).length()
	_animate(delta, speed2d)
	if main_ref != null and main_ref.has_method("update_player_hiding"):
		main_ref.update_player_hiding(self)

func _animate(delta: float, speed2d: float) -> void:
	anim_speed = speed2d
	# LEGS FIX: regime flags for the Meshy mirror (see _mirror_meshy).
	# The movement branch below ASSIGNS the leg pose outright when
	# speed2d > 0.4 (the same condition it branches on); the held
	# flag is (re)armed by the held block further down.
	meshy_move_raw = speed2d > 0.4
	meshy_held_fresh = false
	var t: float = Time.get_ticks_msec() / 1000.0
	# PAW UNDO (v0.8, item 4): strip LAST frame's swipe offset before
	# any pose system writes the leg. Nothing else ever writes
	# rotation.z, and rotation.x is rebuilt by the walk/idle branches
	# below, so after this line the leg is at its true no-swipe base
	# for the current state — in EVERY state (walk, sprint, idle,
	# sit, groom, frozen/collar), because _animate runs in all of them.
	if paw_applied != Vector3.ZERO and leg_pivots.size() == 4:
		leg_pivots[1].rotation -= paw_applied
		paw_applied = Vector3.ZERO
	if speed2d > 0.4:
		idle_time = 0.0
		if idle_action != "":
			last_idle_action = idle_action
			idle_action = "" # movement interrupts any idle action at once
		var freq: float = 6.0 + speed2d * 1.5
		walk_phase += delta * freq
		var swing: float = sin(walk_phase) * 0.62
		# Diagonal pairs move together (a real cat trot)
		if leg_pivots.size() == 4:
			leg_pivots[0].rotation.x = swing
			leg_pivots[3].rotation.x = swing
			leg_pivots[1].rotation.x = -swing
			leg_pivots[2].rotation.x = -swing
		body_node.position.y = abs(sin(walk_phase)) * 0.018
		body_node.rotation.z = sin(walk_phase) * 0.03
		head_node.rotation.x = 0.05
		# Tail streams behind, swaying with the stride
		for i in range(tail_pivots.size()):
			tail_pivots[i].rotation.y = sin(walk_phase * 0.7 - float(i) * 0.7) * 0.3
			tail_pivots[i].rotation.x = -0.36 + sin(walk_phase - float(i)) * 0.07
	else:
		idle_time += delta
		# Legs settle, gentle breathing, slow tail sway, ear twitches, head looks
		for lp in leg_pivots:
			lp.rotation.x = lerp(lp.rotation.x, 0.0, min(1.0, 10.0 * delta))
		body_node.position.y = 0.0
		# PET-SPIN FIX: re-base the body ROLL every idle tick, exactly
		# like position.y above. The walk branch assigns rotation.z
		# outright, but this branch never did — so the petting pose's
		# per-tick `rotation.z += 0.07 * pet_a` (below) had nothing to
		# reset it and ACCUMULATED at 120 ticks/s: the "lean" became
		# ~24 rad (~4 full barrel rolls) over one 2.9s pet, rolling
		# the body mesh around its ground-level origin and swinging
		# it ~1.2 units through the floor — and the leftover roll
		# then STAYED, because nothing idle-side ever cleared it.
		# (Same accumulation class as the v0.7 leg-z and v0.9 head-z
		# bugs; every additive pose offset needs a re-based base.)
		body_node.rotation.z = 0.0
		body_node.scale.y = 1.0 + sin(t * 2.2) * 0.025 # breathing
		head_node.rotation.y = sin(t * 0.45) * 0.22 # looking around
		head_node.rotation.x = sin(t * 0.9) * 0.04
		for i in range(tail_pivots.size()):
			tail_pivots[i].rotation.y = sin(t * 1.6 - float(i) * 0.8) * 0.35
			tail_pivots[i].rotation.x = -0.27 + sin(t * 1.1 - float(i) * 0.6) * 0.08
		if ear_l:
			ear_l.rotation.z = 0.12 + (0.35 if sin(t * 0.7) > 0.985 else 0.0)
		if ear_r:
			ear_r.rotation.z = -0.12 - (0.35 if sin(t * 0.53 + 2.0) > 0.99 else 0.0)
		# --- idle LIFE: after ~3s still (when the purr starts), rotate
		# through gentle cat actions — sit, groom, look, tail flick,
		# paw tap — 2-6s each, never twice the same in a row.
		if idle_allowed and not frozen:
			if idle_action == "":
				if idle_time >= 3.0:
					idle_next_in -= delta
					if idle_next_in <= 0.0:
						_start_idle_action()
			else:
				idle_action_t += delta
				if idle_action_t >= idle_action_dur:
					last_idle_action = idle_action
					idle_action = ""
					idle_next_in = idle_rng.randf_range(0.8, 2.2)
	_apply_idle_pose(delta, t)
	# --- v0.9 PETTING / TREAT pose (additive, composes with idle) ---
	if pet_t > 0.0:
		pet_t = maxf(0.0, pet_t - delta)
	pet_a = move_toward(pet_a, 1.0 if pet_t > 0.0 else 0.0, delta * 5.0)
	if treat_t > 0.0:
		treat_t = maxf(0.0, treat_t - delta)
	if pet_a > 0.01:
		# Lean into the hand, chin up, tail UP and waving happily.
		# The += offsets below are PER-FRAME poses, not accumulation:
		# body roll, head and tail are all re-based earlier in this
		# function (walk branch assigns them; the idle branch assigns
		# them too — body rotation.z included, see PET-SPIN FIX).
		body_node.rotation.z += 0.07 * pet_a
		head_node.rotation.z = 0.14 * pet_a
		head_node.rotation.x += -0.12 * pet_a
		for i in range(tail_pivots.size()):
			tail_pivots[i].rotation.x += -0.5 * pet_a
			tail_pivots[i].rotation.y += sin(t * 7.0 - float(i) * 0.9) * 0.22 * pet_a
	if treat_t > 0.0:
		# Head dips down to eat from the hand, then comes back up.
		# ABSOLUTE from the base position (v0.9 fix): position.z is
		# never re-based anywhere else, so a += here accumulated
		# every frame and the head slid metres off the body.
		var tk: float = 1.0 - treat_t / TREAT_DUR
		var dip: float = sin(tk * PI)
		head_node.rotation.x += 0.55 * dip
		head_node.position.y = head_base_pos.y + 0.03 * sit_a - 0.03 * dip
		head_node.position.z = head_base_pos.z + 0.018 * dip
	# --- v1.3 HELD pose: startle, then settle into the cradle -------
	held_a = move_toward(held_a, held_target, delta * 2.4)
	if startle_t > 0.0:
		startle_t = maxf(0.0, startle_t - delta)
	var startle_a: float = 0.0
	if startle_t > 0.0:
		startle_a = sin((1.0 - startle_t / STARTLE_DUR) * PI)
	if held_a > 0.001 or startle_a > 0.0:
		# Whole-body cradle pitch: head end rises, rump settles back
		# into the arms. model.rotation.x is written NOWHERE else.
		if model:
			model.rotation.x = -0.46 * held_a + 0.12 * startle_a
		body_node.position.y += -0.02 * startle_a # little tense crouch
		if leg_pivots.size() == 4:
			# Front paws fold back under the chest; back legs dangle
			# loose with a lazy sway instead of tucking stiff.
			# ASSIGNED, not +=: the leg base is only lerp-relaxed
			# toward 0 (no hard re-base), so an additive offset could
			# creep — the PET-SPIN lesson. While held the cat is
			# frozen and idle, so the true base is ~0 and an absolute
			# function of the (smoothly ramping) held_a cannot pop.
			leg_pivots[0].rotation.x = 1.5 * held_a
			leg_pivots[1].rotation.x = 1.5 * held_a
			var dangle: float = 0.5 * held_a + sin(t * 1.4) * 0.06 * held_a
			leg_pivots[2].rotation.x = dangle
			leg_pivots[3].rotation.x = dangle + sin(t * 1.4 + 0.7) * 0.04 * held_a
			# LEGS FIX: record the assigned cradle pose for the
			# mirror — it is ABSOLUTE, so the mirror must read it
			# as-is, not difference it against the idle snapshot
			# (which absorbs the assignment next frame and ate
			# ~92% of the fold in the shipped build).
			for i in range(4):
				meshy_held_snap[i] = leg_pivots[i].rotation
			meshy_held_fresh = true
		# Tail curls round the side, the way it does when he sits.
		if tail_pivots.size() == 3:
			tail_pivots[0].rotation.y += 1.0 * held_a
			tail_pivots[1].rotation.y += 0.8 * held_a
			tail_pivots[2].rotation.y += 0.55 * held_a
			tail_pivots[0].rotation.x += 0.22 * held_a
		# Chin up, looking at the person; a soft head tilt once
		# settled. rotation.x rides the idle branch's hard re-base
		# (safe to add); rotation.z has NO re-base, so assign it —
		# the pet block assigns its z-offset for the same reason.
		head_node.rotation.x += -0.34 * held_a
		head_node.rotation.z = 0.07 * held_a
		if ear_l:
			ear_l.rotation.x = -0.55 * startle_a + 0.08 * held_a
		if ear_r:
			ear_r.rotation.x = -0.55 * startle_a + 0.08 * held_a
		# Settled contentment: a slow blink every few seconds.
		if held_a > 0.9:
			var blink: float = pow(maxf(sin(t * 1.15), 0.0), 32.0)
			if eye_l_mi:
				eye_l_mi.scale.y *= 1.0 - 0.6 * blink
			if eye_r_mi:
				eye_r_mi.scale.y *= 1.0 - 0.6 * blink
			if iris_l_mi:
				iris_l_mi.scale.y *= 1.0 - 0.6 * blink
			if iris_r_mi:
				iris_r_mi.scale.y *= 1.0 - 0.6 * blink
			if pupil_l_mi:
				pupil_l_mi.scale.y *= 1.0 - 0.6 * blink
			if pupil_r_mi:
				pupil_r_mi.scale.y *= 1.0 - 0.6 * blink
	elif model and model.rotation.x != 0.0:
		model.rotation.x = 0.0
		if ear_l:
			ear_l.rotation.x = 0.0
		if ear_r:
			ear_r.rotation.x = 0.0
	# PAW SWIPE (v0.8 REWRITE, item 4): an ABSOLUTE pose, never an
	# accumulation. The undo at the top of _animate removed last
	# frame's offset, so the leg currently sits at this frame's base
	# pose; we add exactly this frame's swipe offset and remember it
	# for next frame's undo. When the timer ends the offset is 0 and
	# the next frame's undo hard-restores the exact base rotation —
	# the v0.7 bug (rotation.z += every frame, never reset anywhere)
	# is structurally impossible now.
	if paw_t > 0.0 and leg_pivots.size() == 4:
		paw_t = maxf(0.0, paw_t - delta)
		var pk: float = 1.0 - paw_t / 0.35
		var off := Vector3(-sin(pk * PI) * 1.65, 0.0, -sin(pk * PI) * 0.18)
		if paw_t <= 0.0:
			off = Vector3.ZERO # swipe over: nothing applied, undo clears the rest
		leg_pivots[1].rotation += off
		paw_applied = off
	# Hop squash: stretch a little while airborne
	hop_airborne = not is_on_floor()
	if model:
		var target_sy: float = 1.06 if hop_airborne else 1.0
		model.scale.y = lerp(model.scale.y, target_sy, min(1.0, 8.0 * delta))
	# v1.0.14: the sculpt's final pose for this frame, mirrored onto
	# the Meshy skeleton (no-op while the import is absent).
	_mirror_meshy()

func _start_idle_action() -> void:
	var choices: Array = ["sit", "groom", "look", "tailflick", "pawtap"]
	choices.erase(last_idle_action)
	idle_action = choices[idle_rng.randi_range(0, choices.size() - 1)]
	idle_action_t = 0.0
	match idle_action:
		"sit": idle_action_dur = idle_rng.randf_range(4.0, 6.0)
		"groom": idle_action_dur = idle_rng.randf_range(2.8, 3.6)
		"look": idle_action_dur = idle_rng.randf_range(2.4, 3.2)
		"tailflick": idle_action_dur = idle_rng.randf_range(2.0, 2.6)
		"pawtap": idle_action_dur = idle_rng.randf_range(2.0, 2.8)

func _idle_envelope() -> float:
	if idle_action == "":
		return 0.0
	return clampf(minf(idle_action_t / 0.35, (idle_action_dur - idle_action_t) / 0.4), 0.0, 1.0)

func _apply_idle_pose(delta: float, t: float) -> void:
	var env: float = _idle_envelope()
	var rate: float = delta * 3.4
	sit_a = move_toward(sit_a, env if idle_action == "sit" else 0.0, rate)
	groom_a = move_toward(groom_a, env if idle_action == "groom" else 0.0, rate)
	look_a = move_toward(look_a, env if idle_action == "look" else 0.0, rate)
	tail_a = move_toward(tail_a, env if idle_action == "tailflick" else 0.0, rate)
	tap_a = move_toward(tap_a, env if idle_action == "pawtap" else 0.0, rate)
	sleepy_a = move_toward(sleepy_a, 1.0 if purring else 0.0, delta * 3.0)
	# v1.0.14 MESHY: snapshot the legs exactly as the idle branch
	# left them, BEFORE this function's += pose terms land. The +=
	# terms below accumulate against the branch's lerp re-base
	# (equilibrium = term / (10*delta) — radians of garbage the
	# sculpt's short hidden legs tolerate but a real model's legs
	# cannot). LEGS FIX (2026-11-18): the mirror differences
	# against this snapshot ONLY on idle-family frames — on
	# movement frames the walk branch has already assigned the
	# swing before this snapshot is taken, and differencing ate
	# the whole gait. See _mirror_meshy for the regime split.
	if leg_pivots.size() == 4:
		for i in range(4):
			meshy_leg_snap[i] = leg_pivots[i].rotation
		meshy_leg_snap_fresh = true
	if body_node == null:
		return
	# SIT: rear drops, chest rises, front legs stay straight, tail curls round
	body_node.rotation.x = -0.62 * sit_a
	body_node.position.y += -0.048 * sit_a
	body_node.position.z = -0.016 * sit_a
	if leg_pivots.size() == 4:
		leg_pivots[0].rotation.x += 0.62 * sit_a
		leg_pivots[1].rotation.x += 0.62 * sit_a
		leg_pivots[2].rotation.x += -0.45 * sit_a
		leg_pivots[3].rotation.x += -0.45 * sit_a
		# GROOM: one front paw up to the face, head bent to lick it
		leg_pivots[1].rotation.x += -2.0 * groom_a
		# PAW TAP: little playful taps at the ground
		leg_pivots[0].rotation.x += -0.55 * maxf(0.0, sin(t * 8.5)) * tap_a
	if head_node:
		head_node.position.y = head_base_pos.y + 0.03 * sit_a
		head_node.rotation.x += (0.42 + 0.1 * sin(t * 7.0)) * groom_a + 0.3 * tap_a
		if anim_speed <= 0.4: # head yaw is only re-based while idle; never accumulate it while walking
			head_node.rotation.y += -0.3 * groom_a + sin(idle_action_t * 1.3) * 0.7 * look_a
	if tail_pivots.size() == 3:
		tail_pivots[0].rotation.y += 1.0 * sit_a
		tail_pivots[1].rotation.y += 0.8 * sit_a + sin(t * 9.0) * 0.55 * tail_a
		tail_pivots[2].rotation.y += sin(t * 11.0) * 0.6 * tail_a
	# PURR tell: gentle chest vibration + half-closed content eyes
	if purring:
		body_node.position.x = sin(t * 27.0) * 0.002
		body_node.position.z += cos(t * 23.0) * 0.0015
	else:
		body_node.position.x = 0.0
	# Eye squash bases come from the build (eye_base_y etc.) —
	# the shipping sizes when the flag is off, the North Star
	# sizes when it is on, so blinks/squints keep working on
	# either model.
	if eye_l_mi:
		eye_l_mi.scale.y = eye_base_y * (1.0 - 0.45 * sleepy_a - 0.3 * pet_a)
	if eye_r_mi:
		eye_r_mi.scale.y = eye_base_y * (1.0 - 0.45 * sleepy_a - 0.3 * pet_a)
	if iris_l_mi:
		iris_l_mi.scale.y = iris_base_y * (1.0 - 0.45 * sleepy_a - 0.3 * pet_a)
	if iris_r_mi:
		iris_r_mi.scale.y = iris_base_y * (1.0 - 0.45 * sleepy_a - 0.3 * pet_a)
	if pupil_l_mi:
		pupil_l_mi.scale.y = pupil_base_y * (1.0 - 0.45 * sleepy_a - 0.3 * pet_a)
	if pupil_r_mi:
		pupil_r_mi.scale.y = pupil_base_y * (1.0 - 0.45 * sleepy_a - 0.3 * pet_a)
	if lid_l_mi:
		lid_l_mi.position.y = lid_base_y - 0.011 * sleepy_a
	if lid_r_mi:
		lid_r_mi.position.y = lid_base_y - 0.011 * sleepy_a

func debug_set_idle_action(action_name: String) -> void:
	idle_action = action_name
	idle_action_t = 0.0
	idle_action_dur = 30.0
	idle_time = maxf(idle_time, 3.0)

func is_sitting() -> bool:
	return sit_a > 0.7

func try_hop() -> void:
	if frozen:
		return
	if is_on_floor():
		velocity.y = jump_vel

func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.4

# --- v0.7 additions ------------------------------------------------------
func do_paw_swipe() -> void:
	paw_t = 0.35

func is_paw_swiping() -> bool:
	return paw_t > 0.0

# --- v0.9 petting / treat reactions ----------------------------------
func start_pet_reaction(dur: float = 2.6) -> void:
	pet_t = maxf(pet_t, dur)

func start_treat_reaction() -> void:
	treat_t = TREAT_DUR

# --- v1.3 held pose API (called by main's capture cutscene) --------
func start_held() -> void:
	# The scoop's lift begins: startle first, then the cradle settle
	# (held_a ramps in _animate, so the tuck eases in over ~0.4s).
	held_target = 1.0
	startle_t = STARTLE_DUR

func stop_held() -> void:
	held_target = 0.0
	startle_t = 0.0

func is_held() -> bool:
	return held_a > 0.5

func is_being_petted() -> bool:
	return pet_t > 0.0

func get_forward_vec() -> Vector3:
	var f: Vector3 = global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.05 else Vector3(0, 0, 1)

func get_back_pos() -> Vector3:
	# Top of the back, mid-body — where a petting hand lands.
	# (Offset x VISUAL_SCALE: it must sit on the DRAWN cat's back.)
	return to_global(Vector3(0, 0.325, -0.02) * VISUAL_SCALE)

func get_face_pos() -> Vector3:
	# In front of the muzzle — where a treat is offered.
	return to_global(Vector3(0, 0.27, 0.42) * VISUAL_SCALE)

func apply_car_bump(dir3: Vector3) -> void:
	# Comic knockback from traffic: tossed sideways + a little hop,
	# stunned briefly. NEVER hurt — main only docks points.
	var d := dir3
	d.y = 0.0
	d = d.normalized() if d.length() > 0.05 else Vector3(1, 0, 0)
	velocity = d * 8.0 + Vector3(0, 3.6, 0)
	stun_t = 0.7

func get_tag_global_pos() -> Vector3:
	if collar_tag:
		return collar_tag.global_position
	return global_position + Vector3(0, 0.1385, 0.2285) * VISUAL_SCALE

func get_tag_facing() -> Vector3:
	# World direction the tag's printed face points: the tag
	# cylinder's local +Y, carried through the cat's own transform
	# (so it stays right however the model is posed or turned).
	if collar_tag:
		return (collar_tag.global_transform.basis.y).normalized()
	return (global_transform.basis * Vector3(0, 0, 1)).normalized()

func get_tag_label() -> Label3D:
	return tag_label

# STORY PART 1: the whole collar comes off (the opening's drop beat)
# and goes back on (the homecoming, a later build) as one piece. The
# meshes stay in the tree — only their visibility flips — so the tag
# label, the sculpt checks and the homecoming framing are unaffected.
func set_collar_visible(on: bool) -> void:
	for p in collar_parts:
		if p is Node3D:
			(p as Node3D).visible = on

func is_collar_visible() -> bool:
	return collar_tag != null and collar_tag.visible

func set_tag_name() -> void:
	# Print the cat's NAME on the collar tag (Michael, 2026-11-18:
	# the tag says "Zander", NOT the home address — the address is
	# on the title screen). One line, and the pixel size is fitted
	# to the measured string so the name spans the tag's face.
	if tag_label == null:
		return
	tag_label.text = CAT_NAME
	var font := ThemeDB.fallback_font
	var w: float = font.get_string_size(CAT_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1.0, float(tag_label.font_size)).x
	if w > 1.0:
		tag_label.pixel_size = 0.0195 / w # the name spans the 2.5 cm tag's face

func get_neck_global_pos() -> Vector3:
	# The collar sits just under the chin, ahead of the chest.
	return global_position + global_transform.basis * (Vector3(0, 0.27, 0.235) * VISUAL_SCALE)

# ============================================================
# v1.0.14 MESHY GHOST RIG — attach + per-frame mirror.
# The sculpt rig (body_node / head_node / leg_pivots / tail_pivots /
# ear_l / ear_r) keeps posing exactly as it always has; nothing
# else in the game can tell the difference. _mirror_meshy copies
# that pose onto the imported skeleton with global-pose overrides:
# each driven bone's global basis becomes (pivot rotation) x (its
# own rest basis), about its own rest origin — so lower legs, jaw,
# ears and tail tip follow their driven parents through the skin.
# ============================================================

func _attach_meshy() -> void:
	if MESHY_SCENE == null or model == null:
		return
	var inst: Node = MESHY_SCENE.instantiate()
	meshy_root = Node3D.new()
	meshy_root.name = "MeshyRoot"
	model.add_child(meshy_root)
	meshy_root.add_child(inst)
	meshy_root.scale = Vector3.ONE * MESHY_SCALE
	meshy_root.position.y = MESHY_GROUND_Y
	# Find the skeleton; silence any helper mesh that is not the cat
	# (the Meshy export carries a stray "Icosphere" helper — in the
	# Godot import it does not surface as a scene mesh, but if a
	# future export adds one it must never be drawn or measured).
	var stack: Array = [inst]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Skeleton3D:
			meshy_skel = cur as Skeleton3D
		elif cur is MeshInstance3D and (cur as MeshInstance3D).name.to_lower().contains("icosphere"):
			(cur as MeshInstance3D).visible = false
		for ch in cur.get_children():
			stack.append(ch)
	if meshy_skel == null:
		meshy_root.visible = false
		meshy_root = null
		return
	# Bone map by NAME (indices differ between Meshy exports).
	# Left/right are matched by POSITION, not by the export's .L/.R
	# labels: the sculpt's FL pivot sits at model -X, and the bone
	# whose rest origin sits at skeleton -X in the front pair is
	# "clavicle.R" — position is what the trot's diagonal pairing
	# and the paw swipe actually see.
	var want := {
		"fl": "clavicle.R", "fr": "clavicle.L",
		"bl": "rearUpr.R", "br": "rearUpr.L",
		"head": "head", "spine": "spine2",
		"ear_l": "ear.R_01", "ear_r": "ear.L_01",
		# LEGS FIX: the rest of each leg chain — the shipped
		# mirror drove ONLY the top bone, so the model's legs
		# could swing (once the gait reached them) but never
		# BEND. Same position-matched .R/.L convention as the
		# uppers: sculpt FL (-X) pairs with the .R chain.
		"fl_lo": "frontLwr.R", "fr_lo": "frontLwr.L",
		"bl_lo": "rearLwr.R", "br_lo": "rearLwr.L",
		"fl_hk": "frontHorselink.R", "fr_hk": "frontHorselink.L",
		"bl_hk": "rearHorselink.R", "br_hk": "rearHorselink.L",
		"fl_ft": "frontFoot.R", "fr_ft": "frontFoot.L",
		"bl_ft": "rearFoot.R", "br_ft": "rearFoot.L",
	}
	for role in want.keys():
		var bi: int = meshy_skel.find_bone(str(want[role]))
		if bi >= 0:
			meshy_bone[role] = bi
			meshy_rest[bi] = meshy_skel.get_bone_global_rest(bi)
	for tname in ["tail1", "tail2", "tail3", "tail4", "tail_05", "tail_06"]:
		var ti: int = meshy_skel.find_bone(tname)
		if ti >= 0:
			meshy_tail.append(ti)
			meshy_rest[ti] = meshy_skel.get_bone_global_rest(ti)
	# Every bone's rests, for the mirror's parent-first propagation
	# (global-pose overrides do NOT flow down the chain on their
	# own — children are posed from the parent's un-overridden
	# pose — so _mirror_meshy computes each bone's desired global
	# itself, composing driven ancestors in).
	for bi in range(meshy_skel.get_bone_count()):
		var gr: Transform3D = meshy_skel.get_bone_global_rest(bi)
		meshy_rest[bi] = gr
		var bp: int = meshy_skel.get_bone_parent(bi)
		if bp >= 0:
			meshy_local_rest[bi] = meshy_skel.get_bone_global_rest(bp).affine_inverse() * gr
		else:
			meshy_local_rest[bi] = gr
	# Hide the sculpt's meshes. The nodes, pivots and pose code all
	# stay live — only the drawing changes. The collar parts are NOT
	# hidden: they are re-seated onto the new neck below.
	body_node.visible = false
	head_node.visible = false
	for lp in leg_pivots:
		(lp as Node3D).visible = false
	if ear_l:
		ear_l.visible = false
	if ear_r:
		ear_r.visible = false
	if tail_pivots.size() > 0:
		(tail_pivots[0] as Node3D).visible = false
	# Re-seat the collar on the Meshy neck. The new neck is
	# plumper than the sculpt's (half-width ~0.135 in GLB units,
	# ~0.119 in model units, against the strap's 0.0835 radius) —
	# at its old size the strap sank out of sight inside the neck
	# and only the buckle poked out; grown as a plain vertical
	# ellipse it read as a giant hoop down the chest (proof shots
	# screenshots_meshy_swap/01-08). The neck also runs DIAGONALLY
	# (neck1 (0,0.279,0.228) -> head (0,0.379,0.305) in model
	# units), so the strap is TILTED square to the neck axis
	# (-52 deg about X) and only modestly grown — a collar hugging
	# the neck the way the sculpt's did. The buckle rides out to
	# the strap's new side; the D-ring + tag re-hang from the
	# strap's bottom onto the upper chest (measured chest front
	# z~0.30 at that height) so the tag and Zander's name read.
	# The parts stay in collar_parts, so the cutscene drop /
	# homecoming restore and every tag getter behave as before.
	for i in range(collar_parts.size()):
		var p = collar_parts[i]
		if not (p is Node3D):
			continue
		var n3 := p as Node3D
		if i == 0:
			n3.position = Vector3(0.0, 0.285, 0.232)
			n3.scale = Vector3(1.38, 1.25, 1.05)
			n3.rotation_degrees.x = -52.0
		elif p == collar_tag:
			n3.position = Vector3(0.0, 0.195, 0.312)
			n3.scale = Vector3.ONE * 1.25
		elif n3.position.y < 0.2:
			n3.position = Vector3(0.0, 0.212, 0.315) # the D-ring
		else:
			n3.position += Vector3(0.036, 0.037, 0.017) # buckle hardware

func _mirror_meshy() -> void:
	if meshy_skel == null or meshy_root == null or body_node == null or head_node == null:
		return
	# The walk bounce / sit drop the sculpt applies to body_node's
	# height rides the whole imported model.
	meshy_root.position.y = MESHY_GROUND_Y + body_node.position.y
	# Drivers: bone index -> extra rotation (sculpt pivot Euler)
	# applied about the bone's own origin, on top of its rest pose.
	# Global-pose overrides do not propagate to children by
	# themselves, so the loop below composes the whole skeleton
	# parent-first: each bone's desired global = (desired parent
	# global) x (its rest local), with its driver folded in — the
	# same nesting the sculpt's pivot chain produces.
	var drv: Dictionary = {}
	# LEGS FIX (2026-11-18): pick the leg-pose source by REGIME.
	# The shipped code differenced EVERY frame against the idle
	# snapshot — but _apply_idle_pose runs every frame and its
	# snapshot is taken after the walk branch assigned the swing,
	# so (raw - snapshot) cancelled the gait to ~0 rad at the
	# bones (Michael, playing v1.0.14: "when it runs the legs
	# don't move — legs are straight"). The regimes:
	#   MOVEMENT (walk/sprint/stun): the branch ASSIGNED the
	#     pivots outright this frame — raw values ARE the pose.
	#   HELD: the held block ASSIGNED an absolute cradle pose
	#     after the snapshot — read the recorded assignment.
	#   IDLE family: the pivots hold an accumulated equilibrium
	#     of _apply_idle_pose's += terms against the lerp
	#     re-base — (raw - snapshot) recovers the intended
	#     single-frame terms (sit/groom/tap), as before.
	var leg_up := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO] # upper-leg pose per leg (FL FR BL BR)
	var leg_lo := [0.0, 0.0, 0.0, 0.0] # lower-leg fold (rotation.x), mirror-synthesised
	var gallop_pitch := 0.0
	if leg_pivots.size() == 4:
		if meshy_move_raw:
			for i in range(4):
				leg_up[i] = leg_pivots[i].rotation
			# --- gait synthesis on top of the sculpt's trot ---
			# Per-leg phase: FL/BR swing with walk_phase, FR/BL
			# against it (the trot's diagonal pairing).
			var phases := [walk_phase, walk_phase + PI, walk_phase + PI, walk_phase]
			if is_sprinting:
				# GALLOP: front pair together (FL leads FR by a
				# beat), rear pair together half a cycle later,
				# bigger swing — a running cat must not trot.
				var g := walk_phase
				phases = [g, g - 0.38, g + PI - 0.38, g + PI]
				leg_up[0].x = GAIT_GALLOP_AMP * sin(phases[0])
				leg_up[1].x = GAIT_GALLOP_AMP * sin(phases[1])
				leg_up[2].x = GAIT_GALLOP_AMP * sin(phases[2])
				leg_up[3].x = GAIT_GALLOP_AMP * sin(phases[3])
				# Spine flexes with the stride; the head counter-
				# pitches below so his gaze stays level-ish.
				gallop_pitch = GAIT_GALLOP_PITCH * sin(g + 0.65)
				meshy_root.position.y += GAIT_GALLOP_BOB * sin(g - 0.45)
			else:
				for i in range(4):
					leg_up[i].x = leg_up[i].x * GAIT_WALK_GAIN
			# Lower-leg FOLD: peaks while the leg is swinging
			# forward through the air (protraction), ~zero while
			# it is planted and pushing (stance). +x pitches the
			# segment back in skeleton space — the paw trails
			# and tucks instead of the leg swinging like a peg.
			var fold_gain := 1.3 if is_sprinting else 1.0
			for i in range(4):
				var prot: float = pow(maxf(0.0, -cos(phases[i] - GAIT_FOLD_LEAD)), 1.2)
				var amp: float = (GAIT_FOLD_FRONT if i < 2 else GAIT_FOLD_REAR) * fold_gain
				leg_lo[i] = amp * prot
			if hop_airborne:
				# Airborne: front paws tuck up, rear legs trail
				# and fold — instead of trotting on thin air.
				leg_up[0].x = lerpf(leg_up[0].x, 0.30, 0.6)
				leg_up[1].x = lerpf(leg_up[1].x, 0.30, 0.6)
				leg_up[2].x = lerpf(leg_up[2].x, 0.55, 0.6)
				leg_up[3].x = lerpf(leg_up[3].x, 0.55, 0.6)
				leg_lo[0] = maxf(leg_lo[0], 0.85)
				leg_lo[1] = maxf(leg_lo[1], 0.85)
				leg_lo[2] = maxf(leg_lo[2], 0.55)
				leg_lo[3] = maxf(leg_lo[3], 0.55)
		elif meshy_held_fresh:
			# Cradle: split the sculpt's shoulder fold between
			# the upper and lower front legs so the paws tuck
			# under the chest instead of the whole leg planking
			# back; rear legs keep the assigned dangle.
			for i in range(4):
				leg_up[i] = meshy_held_snap[i]
			leg_up[0].x *= 0.78
			leg_up[1].x *= 0.78
			leg_lo[0] = 0.62 * held_a
			leg_lo[1] = 0.62 * held_a
			leg_lo[2] = 0.30 * held_a
			leg_lo[3] = 0.30 * held_a
		elif meshy_leg_snap_fresh:
			for i in range(4):
				leg_up[i] = leg_pivots[i].rotation - meshy_leg_snap[i]
		else:
			for i in range(4):
				leg_up[i] = leg_pivots[i].rotation
		meshy_leg_snap_fresh = false
		var up_roles := ["fl", "fr", "bl", "br"]
		var lo_roles := ["fl_lo", "fr_lo", "bl_lo", "br_lo"]
		var hk_roles := ["fl_hk", "fr_hk", "bl_hk", "br_hk"]
		var ft_roles := ["fl_ft", "fr_ft", "bl_ft", "br_ft"]
		for i in range(4):
			_set_drv(drv, up_roles[i], leg_up[i])
			if leg_lo[i] != 0.0:
				# Horselink + foot counter-rotate part of the
				# fold so the paw stays flatter to the ground
				# instead of pointing wherever the fold leaves it.
				_set_drv(drv, lo_roles[i], Vector3(leg_lo[i], 0, 0))
				_set_drv(drv, hk_roles[i], Vector3(-leg_lo[i] * 0.45, 0, 0))
				_set_drv(drv, ft_roles[i], Vector3(-leg_lo[i] * 0.25, 0, 0))
	# Body roll / sit pitch go to the mid-spine; the head and leg
	# drivers then compose on top of whatever the spine did,
	# exactly like the sculpt (body pitch + leg compensation are
	# separate additive terms there too).
	var spine_e: Vector3 = body_node.rotation
	spine_e.x += gallop_pitch
	_set_drv(drv, "spine", spine_e)
	var head_e: Vector3 = head_node.rotation
	head_e.x -= gallop_pitch * 0.6 # gallop: keep the head steadier than the spine
	_set_drv(drv, "head", head_e)
	# Tail: the sculpt's pivots carry a baked base curl in their
	# absolute rotations (x -0.36 walk / -0.27 idle) which the GLB's
	# rest pose already owns — mirror only the DELTA from neutral,
	# so the model's own up-curl stays and the sway/lift/wag reads.
	var tail_neutral := Vector3(-0.315, 0, 0)
	for i in range(mini(meshy_tail.size(), tail_pivots.size())):
		drv[int(meshy_tail[i])] = (tail_pivots[i] as Node3D).rotation - tail_neutral
	if meshy_tail.size() > 3 and tail_pivots.size() == 3:
		var extra: Vector3 = ((tail_pivots[2] as Node3D).rotation - tail_neutral) * 0.6
		for j in range(3, meshy_tail.size()):
			drv[int(meshy_tail[j])] = extra
	# Ears: mirror the delta from the idle base lean (+-0.12 in z).
	if ear_l:
		_set_drv(drv, "ear_l", ear_l.rotation - Vector3(0, 0, 0.12))
	if ear_r:
		_set_drv(drv, "ear_r", ear_r.rotation - Vector3(0, 0, -0.12))
	var head_bi: int = int(meshy_bone.get("head", -1))
	var head_off: Vector3 = head_node.position - head_base_pos
	var count: int = meshy_skel.get_bone_count()
	var desired: Array = []
	desired.resize(count)
	for bi in range(count):
		var bp: int = meshy_skel.get_bone_parent(bi)
		var g: Transform3D
		if bp >= 0 and desired[bp] != null:
			g = (desired[bp] as Transform3D) * (meshy_local_rest[bi] as Transform3D)
		else:
			g = meshy_local_rest[bi] as Transform3D
		if drv.has(bi):
			var e: Vector3 = drv[bi]
			g = Transform3D(Basis.from_euler(e) * g.basis, g.origin)
		if bi == head_bi:
			# treat/groom/sit also DIP the head off its base spot
			g.origin += head_off
		desired[bi] = g
		meshy_skel.set_bone_global_pose_override(bi, g, 1.0, true)

func _set_drv(drv: Dictionary, role: String, euler: Vector3) -> void:
	var bi: int = int(meshy_bone.get(role, -1))
	if bi >= 0:
		drv[bi] = euler
