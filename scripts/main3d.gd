extends Node3D
## HOMEWARD v0.7 — 3D main controller.
## Full loop in a real 3D town: random home address per run (shown
## ONLY on the title collar close-up and the COLLAR check while stopped),
## 3D animated cat + NPCs, notice->CHASE->grab capture, taken -> varied
## per-captor escape puzzles — since v1.1 a visible PANEL puzzle per
## mechanism (prompt -> panel -> down/up/down/up/PAW combo -> the cat
## is seen slipping out), replacing the old swipe gestures,
## exactly 60s pursuit (max 2), win at the correct door. Landscape,
## floating-joystick touch + keyboard. NO D-pad.
## v0.6: DUAL touch — LEFT half floating joystick moves (camera-yaw-relative), drag on
## the right side of the screen LOOKS (yaw around the cat + pitch
## clamped -10..+55 deg so you can tilt up to read street signs).
## Camera is also much closer than v0.3 (~26-27% of screen height).

const CatScript: GDScript = preload("res://scripts/cat.gd")
const TEX_GRASS: Texture2D = preload("res://assets/textures/grass.png")
const TEX_GRASS_PARK: Texture2D = preload("res://assets/textures/grass_park.png")
const TEX_ASPHALT: Texture2D = preload("res://assets/textures/asphalt.png")
const TEX_SIDEWALK: Texture2D = preload("res://assets/textures/sidewalk.png")
const TEX_ROOF: Texture2D = preload("res://assets/textures/roof.png")
const TEX_SIDING: Texture2D = preload("res://assets/textures/siding.png")
const TEX_BRICK: Texture2D = preload("res://assets/textures/brick.png")
const TEX_FOLIAGE: Texture2D = preload("res://assets/textures/foliage.png")
const TEX_WATER: Texture2D = preload("res://assets/textures/water.png")
const TEX_CLOUD: Texture2D = preload("res://assets/textures/cloud.png")
const TEX_WOOD: Texture2D = preload("res://assets/textures/wood_floor.png")
const TEX_BARK: Texture2D = preload("res://assets/textures/bark.png")
const TEX_WALLPAPER: Texture2D = preload("res://assets/textures/wallpaper.png")
# v1.0 step 2 (ART OVERHAUL): a NORMAL MAP for every world texture.
# v0.8/v0.9 surfaces were albedo-only — flat colour on smooth shapes,
# which is exactly why doubling geometry changed nothing visually.
# With normals, siding boards, brick courses, shingles, bark furrows
# and grass blades all catch raking light and shadow.
var _normal_for: Dictionary = {
	TEX_GRASS: [preload("res://assets/textures/grass_normal.png"), 1.1],
	TEX_GRASS_PARK: [preload("res://assets/textures/grass_park_normal.png"), 1.1],
	TEX_ASPHALT: [preload("res://assets/textures/asphalt_normal.png"), 0.9],
	TEX_SIDEWALK: [preload("res://assets/textures/sidewalk_normal.png"), 1.5],
	TEX_ROOF: [preload("res://assets/textures/roof_normal.png"), 1.6],
	TEX_SIDING: [preload("res://assets/textures/siding_normal.png"), 1.7],
	TEX_BRICK: [preload("res://assets/textures/brick_normal.png"), 1.6],
	TEX_FOLIAGE: [preload("res://assets/textures/foliage_normal.png"), 1.1],
	TEX_WATER: [preload("res://assets/textures/water_normal.png"), 0.7],
	TEX_BARK: [preload("res://assets/textures/bark_normal.png"), 1.9],
	TEX_WOOD: [preload("res://assets/textures/wood_floor_normal.png"), 1.0],
	TEX_WALLPAPER: [preload("res://assets/textures/wallpaper_normal.png"), 0.5],
	TEX_RUG: [preload("res://assets/textures/rug_normal.png"), 0.7],
	TEX_SOFA: [preload("res://assets/textures/sofa_fabric_normal.png"), 0.7],
}
const TEX_RUG: Texture2D = preload("res://assets/textures/rug.png")
const TEX_SOFA: Texture2D = preload("res://assets/textures/sofa_fabric.png")
const PersonScript: GDScript = preload("res://scripts/person.gd")
const EscapePanelScript: GDScript = preload("res://scripts/escape_panel.gd")

var state: String = "splash" # splash | title | play | taken | escape | win
var rng := RandomNumberGenerator.new()
var houses: Array = [] # {address, pos:Vector3, door:Vector3}
var home_index: int = 0
var home_address: String = ""
var player: CharacterBody3D = null
var npcs: Array = []
var hide_points: Array = [] # Vector3 bush / car centres
var pursuers: Dictionary = {}
var captor: Node = null
var capture_return_pos: Vector3 = Vector3.ZERO
var taken_timer: float = 0.0
var escape_step: int = 0
var latch_hits: int = 0
var latch_cooldown: float = 0.0
var meow_cooldown: float = 0.0
var bark_msg_cooldown: float = 0.0
var wrong_house_cd: Dictionary = {}
var collar_open: bool = false
var book_node: Node3D = null
var latch_node: Node3D = null
var book_home_pos: Vector3 = Vector3.ZERO
# --- v0.6 escape variants + gesture mechanisms -------------------------
var escape_steps: Array = [] # [{kind, label}] for the current capture
var escape_prog: float = 0.0 # mechanism progress 0..1 (panel-driven)
var escape_variant_idx: int = -1
var prev_variant_idx: int = -1
var prev_variant_type: String = ""
var carrier_shake: float = 0.0
var latch_pivot: Node3D = null
var latch_base_pos: Vector3 = Vector3.ZERO
var sash_node: Node3D = null
var sash_base_y: float = 0.0
var bolt_node: Node3D = null
var bolt_base_z: float = 0.0
var backdoor_pivot: Node3D = null # v1.1: the back door swings open in the escape animation
var flap_node: Node3D = null
# --- v1.1 escape PANEL puzzle (Michael's design, 2026-11-16) ---------
# Walk to the mechanism -> an unmissable PROMPT appears -> the PANEL
# opens with a big picture of the mechanism -> swipe the combination
# (down, up, down, up, PAW) on the picture -> the cat is SEEN working
# the mechanism. v1.2: the panel NO LONGER teleports the cat out — a
# finished combo OPENS the way and the player WALKS the cat out
# (Michael, 2026-11-16: "I want the door to open and you can walk
# outside"). Replaces the v0.7 room swipe gestures, which Michael
# found invisible and random-feeling.
const ESCAPE_COMBO: Array = ["down", "up", "down", "up", "paw"]
const ESCAPE_ANIM_LEN := 2.3 # legacy scripted exit — kept inert, see _open_exit
# v1.2: PAW-to-activate (Michael's fix for the v1.0.4 playtest, where
# he could not activate the puzzle at all): the trigger is a generous
# 3.0 m RADIUS around the exit point, no facing requirement — the old
# axis-aligned rect zones were invisible to a real player and nothing
# told him why nothing was happening.
const ESCAPE_TRIGGER_RADIUS := 3.0
var escape_ui_layer: CanvasLayer = null
var escape_prompt_btn: Button = null
var escape_panel = null # scripts/escape_panel.gd (Control)
var combo_index: int = 0
var escape_anim_t: float = -1.0 # legacy scripted escape (>=0 while it plays) — unused since v1.2
var escape_anim_kind: String = ""
var escape_anim_from := Vector3.ZERO
var escape_anim_pawed: bool = false
var carrier_node: Node3D = null
var carrier_door: Node3D = null
var vase_node: Node3D = null
var vase_home: Dictionary = {}
var room_title_label: Label3D = null
var theme_groups: Dictionary = {} # npc_type -> Node3D (only one visible)
# --- v1.2 DISTRACTIONS (Michael's design, 2026-11-16) ------------------
# The captor is IN the room with the cat, tidying and settling him in.
# The cat can PAW over 3 props (plant / book / vase); the crash pulls
# the captor over to right it for ~5 s of walking + 5 s of righting —
# that is the window to work the latch. No distraction: she notices
# the cat at the door in NOTICE_GRACE seconds and kindly interrupts
# (panel closes, combo lost, cat shooed off — no fail state).
const DISTRACT_RIGHT_TIME := 5.0 # seconds spent righting a toppled prop
const DISTRACT_WALK_SPEED := 2.3
const ROOM_WALK_SPEED := 1.15
const NOTICE_GRACE := 1.2 # seconds at the door, undistracted, before she notices
const NOTICE_COOLDOWN := 2.5 # grace after an interrupt before the panel may reopen
var distract_props: Array = [] # [{id, name, pivot, base, stand, toppled, anim_t, home_rot, topple_rot, bubble}]
var captor_room_state: String = "off" # off|idle|walk|to_prop|righting|return|shoo
var captor_room_target := Vector3.ZERO
var captor_room_wait: float = 0.0
var captor_anchor_idx: int = 0
var captor_prop: Dictionary = {}
var distract_queue: Array = [] # props waiting their turn to be righted
var righting_t: float = 0.0
var captor_trip_t: float = 0.0
var notice_t: float = 0.0 # time the panel has been open while she is NOT distracted
var notice_cooldown: float = 0.0
var shoo_t: float = -1.0 # >=0 while the cat hops away from the door after an interrupt
var shoo_from := Vector3.ZERO
var shoo_to := Vector3.ZERO
var distract_label: Label = null # HUD line under the message bar
var distract_bar_bg: ColorRect = null
var distract_bar_fill: ColorRect = null
var prop_prompt_btn: Button = null # "🐾 Paw the plant!" near a standing prop
var crash_labels: Array = [] # [{node, t}]
var sfx_crash: AudioStreamPlayer = null # notice.wav at a low pitch — the crash cue
# --- v1.2 PLAYER-DRIVEN EXIT (Michael's design, 2026-11-16) -----------
# On combo success the way OPENS and control returns to the player:
# the cat walks out through it himself. The escape completes when he
# crosses the threshold (+3 and the 60 s pursuit, as before). The
# openings are REAL gaps in the room walls (segmented at build time
# with invisible blockers while closed) so the cat can physically walk
# through; the opened way never closes, so he can't get soft-locked.
var exit_open: bool = false
var exit_open_kind: String = ""
var window_blocker: StaticBody3D = null # covers the window gap while closed
var petdoor_blocker: StaticBody3D = null # covers the pet-door gap while closed
var petdoor_zone := Rect2(203, -11, 6, 3.5)
var bolt_zone := Rect2(210, 1.2, 5.5, 4.6)
var carrier_zone := Rect2(191, 5, 6, 5.5)
var vase_zone := Rect2(206, 2, 6, 5)
var cam: Camera3D = null
var cam_target_pos: Vector3 = Vector3.ZERO
# --- v0.4 dual look controls -------------------------------------------
var look_yaw: float = 0.0 # radians, 0 = camera behind cat on +Z (v0.3 view)
var look_pitch_deg: float = 18.0 # camera elevation angle; + = looking down
const LOOK_PITCH_MIN := -10.0 # tilt up (read signs above eye level)
const LOOK_PITCH_MAX := 55.0 # tilt down
const LOOK_YAW_SENS := 0.0052 # rad per drag pixel
const LOOK_PITCH_SENS := 0.14 # deg per drag pixel
var look_drags: Dictionary = {} # drag index / "mouse" -> last Vector2 pos
var look_exclude_rects: Array = [] # Rect2s of A/B/SPRINT/COLLAR/MEOW buttons
var hint_label: Label = null
var hint_timer: float = 0.0

var escape_origin := Vector3(200, 0, 0)
# --- v0.6 wave 2: purr, street signs, mini-map, capture cutscene ------
var purr_player: AudioStreamPlayer = null
var purr_active: bool = false
var street_signs: Array = [] # {street, text} for every sign built
var content_points: Array = [] # v0.9: Vector3 of every house/tree/bush/prop/feature — the empty-area audit measures coverage from this
# v0.7: the mini-map is GONE entirely (Michael: no real use, and he
# does not want any aid that shows the way home). Signs only.
var cutscene_t: float = 0.0
var cutscene_from: Vector3 = Vector3.ZERO
var cutscene_dir: Vector3 = Vector3(0, 0, 1)
var fade_rect: ColorRect = null
var fade_in_t: float = -1.0
# --- v0.6 wave 3: scoreboard, stamina HUD, chase camera, pursuit-enders --
var score: int = 0
var pets_count: int = 0
var treats_count: int = 0
var score_label: Label = null
var stamina_bg: ColorRect = null
var stamina_fill: ColorRect = null
var stamina_adren: ColorRect = null
var stamina_label: Label = null
var ender_points: Array = [] # Vector3 pursuit-ender spots (cat gaps)
var ender_cooldown: float = 0.0
var chase_cam_active: bool = false
var current_cam_dist: float = 1.7
var nearest_chaser: Node = null
# --- v0.7 traffic + collar-zoom camera --------------------------------
var traffic_cars: Array = [] # {node, vel}
var traffic_timer: float = 2.5
var traffic_hit_cd: float = 0.0
var traffic_group: Node3D = null
const TRAFFIC_HIT_PENALTY := 5
var collar_zoom_t: float = 0.0 # 0 = normal camera, 1 = full collar close-up
var collar_timer: float = 0.0 # auto-close countdown while the zoom is open
var collar_caption: Label3D = null # address caption living in the 3D zoom view
var collar_btn: Button = null
var action_buttons: Array = [] # touch buttons (live rects block look drags)
var shelf_zone := Rect2(186, -9, 6, 5) # XZ rect
var sofa_zone := Rect2(196, 3, 7, 3)
var window_zone := Rect2(197, -9.5, 6, 3)

var hud_layer: CanvasLayer
var message_label: Label
var objective_label: Label
var pursuit_label: Label
var escape_label: Label
var title_panel: Control
var splash_panel: Control
var collar_panel: Control
var collar_address_label: Label
var win_panel: Control
var win_label: Label
var touch_layer: CanvasLayer
# v0.6 floating virtual JOYSTICK (the D-pad is gone): touch anywhere on
# the LEFT half -> joystick origin there; drag direction = move
# direction (camera-relative), drag distance = speed.
var joy_id: int = -999 # touch index owning the joystick (-999 = none)
var joy_mouse: bool = false
var joy_origin: Vector2 = Vector2.ZERO
var joy_current: Vector2 = Vector2.ZERO
var joy_base: Panel = null
var joy_knob: Panel = null
var message_timer: float = 0.0

var meow_players: Array = []
var meow_index: int = 0
var sfx_meow: AudioStreamPlayer
var sfx_bark: AudioStreamPlayer
var sfx_notice: AudioStreamPlayer
var sfx_win: AudioStreamPlayer
var music: AudioStreamPlayer
var splash_song_player: AudioStreamPlayer = null

# ---------------------------------------------------------------- materials/helpers
func _mat(c: Color, rough: float = 0.9, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


func _mat_tex(tex: Texture2D, tint: Color = Color.WHITE, uv: Vector3 = Vector3(1, 1, 1), rough: float = 0.94) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_scale = uv
	# v0.8 (item 3): anisotropic mip filtering — ground/asphalt stays
	# crisp at grazing angles in motion instead of smearing.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if _normal_for.has(tex): # v1.0 step 2: surface relief
		var nd: Array = _normal_for[tex]
		m.normal_enabled = true
		m.normal_texture = nd[0]
		m.normal_scale = float(nd[1])
	return m

func _glass(parent: Node, pos: Vector3, size: Vector3, col: Color, em: float) -> MeshInstance3D:
	# v1.0 step 2: window glass is a MATERIAL now, not a glowing
	# card — low roughness + a touch of metal so it mirrors the sky
	# and sun like real glass, keeping a whisper of warm emission
	# so lit windows still read as "someone's home".
	var mi := _box(parent, pos, size, col)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.12
	m.metallic = 0.3
	if em > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = em * 0.75
	mi.material_override = m
	return mi

func _paint(col: Color) -> StandardMaterial3D:
	# v1.0 step 2: CAR PAINT — metallic flake behaviour: mostly
	# metal with mid roughness, so the sky and sun reflect along
	# the bodywork. v0.9's matte 0.35-roughness colour read as
	# plastic toy cars.
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.3
	m.metallic = 0.55
	return m

func _car_glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.22, 0.3)
	m.roughness = 0.08
	m.metallic = 0.45
	return m

func _box_tex(parent: Node, pos: Vector3, size: Vector3, tex: Texture2D, tint: Color = Color.WHITE, uv: Vector3 = Vector3(1, 1, 1), collide: bool = false) -> MeshInstance3D:
	var mi := _box(parent, pos, size, Color.WHITE, collide)
	mi.material_override = _mat_tex(tex, tint, uv)
	return mi

func _box(parent: Node, pos: Vector3, size: Vector3, c: Color, collide: bool = false, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c, 0.9, emission)
	parent.add_child(mi)
	if collide:
		_add_static(mi, size)
	return mi

func _make_blocker(parent: Node, pos: Vector3, size: Vector3) -> StaticBody3D:
	# v1.2: an invisible collision plug for an escape-room wall gap.
	# The CollisionShape3D child is named "CS" so _set_blocker can
	# toggle it without a stored reference to the shape itself.
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	cs.name = "CS"
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body

func _set_blocker(body: StaticBody3D, blocked: bool) -> void:
	if body == null:
		return
	var cs := body.get_node_or_null("CS") as CollisionShape3D
	if cs:
		cs.disabled = not blocked

func _sphere(parent: Node, pos: Vector3, scl: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 24
	sm.rings = 14
	mi.mesh = sm
	mi.position = pos
	mi.scale = scl
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _cyl(parent: Node, pos: Vector3, r_top: float, r_bot: float, h: float, c: Color, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 18
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r_bot
		shape.height = h
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi

func _add_static(mi: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)

func _label3d(parent: Node, text: String, pos: Vector3, size: int, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.modulate = c
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.6)
	parent.add_child(l)
	return l

func _label3d_flat(parent: Node, text: String, pos: Vector3, size: int, c: Color, rot_y_deg: float = 0.0, pixel_size: float = 0.0042) -> Label3D:
	# v0.7: text that lives ON a surface (street signs, house boards).
	# NOT a billboard: it can only be read when you face that surface,
	# exactly like print on a real sign.
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel_size
	l.position = pos
	l.rotation_degrees = Vector3(0, rot_y_deg, 0)
	l.modulate = c
	l.outline_size = 4
	l.outline_modulate = Color(0, 0, 0, 0.3)
	l.double_sided = false
	l.no_depth_test = false
	parent.add_child(l)
	return l

func _grass_tuft(parent: Node, pos: Vector3, seed_i: int) -> void:
	# v0.7 art: crossed blade cones instead of a green ball.
	var cols: Array = [Color(0.3, 0.58, 0.28), Color(0.4, 0.66, 0.32), Color(0.34, 0.62, 0.3)]
	for bi in range(3):
		var blade := _cyl(parent, pos + Vector3((float(bi) - 1.0) * 0.09, 0.1, (float((bi + seed_i) % 3) - 1.0) * 0.08), 0.004, 0.045, 0.44, cols[(bi + seed_i) % 3])
		blade.rotation_degrees = Vector3((float(bi) - 1.0) * 9.0, 0, (float((bi * 2 + seed_i) % 3) - 1.0) * 9.0)

# --- v1.0 step 2 GROUND DETAIL (MultiMesh) ---------------------------
# Thousands of individual 3D grass blades + tiny wildflowers, each
# set in ONE draw call. At cat height the lawn stops being a green
# texture and becomes a surface the cat stands IN. Normals point
# straight up so blades shade exactly like the lawn beneath them.
func _blade_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var vi: int = 0
	for ang in [0.0, PI * 0.5]:
		var dx := Vector3(cos(ang), 0, sin(ang)) * 0.032
		var lean := Vector3(sin(ang), 0, -cos(ang)) * 0.04
		verts.append_array([-dx, dx, lean + Vector3(0, 0.26, 0) + dx * 0.22, lean + Vector3(0, 0.26, 0) - dx * 0.22])
		for k in range(4):
			normals.append(Vector3(0, 1, 0))
			uvs.append(Vector2(0, 0))
		indices.append_array([vi, vi + 1, vi + 2, vi, vi + 2, vi + 3])
		vi += 4
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _ground_spot_blocked(p: Vector3) -> bool:
	for rz in [-55.0, -11.0, 15.0, 55.0]:
		if absf(p.z - rz) < 6.4:
			return true
	for rx in [-70.0, -20.0, 24.0, 72.0]:
		if absf(p.x - rx) < 6.4:
			return true
	for hh in houses:
		if p.distance_to(hh["pos"]) < 8.6:
			return true
	if p.distance_to(Vector3(2, 0, -2)) < 5.0:
		return true # spawn clearing
	if p.distance_to(Vector3(-44, 0, 26)) < 4.5:
		return true # park pond
	if p.distance_to(Vector3(-90, 0, 76)) < 4.2:
		return true # second pond
	return false

func _scatter_multimesh(world: Node3D, srng: RandomNumberGenerator, mesh: Mesh, count: int, mat: Material, palette: Array, y_base: float, scl_min: float, scl_max: float, vis_end: float = 0.0) -> void:
	# PERF (post-v1.0.1): placements are generated EXACTLY as before
	# (same RNG draw order, same rejection rules — every blade and
	# flower lands in the same spot with the same colour), but they
	# are then bucketed into 20m grid cells, one MultiMeshInstance3D
	# per cell, each with a visibility range. A single town-wide
	# MultiMesh is always fully drawn (its bounds span the map, so
	# frustum culling never helps): all 12,000 blades were vertex-
	# processed every frame wherever the cat stood. Chunked, only
	# the cells within vis_end of the camera are drawn at all — the
	# lawn around the cat is instance-for-instance identical.
	var xforms: Array = []
	var cols: Array = []
	var placed: int = 0
	var guard: int = 0
	while placed < count and guard < count * 40:
		guard += 1
		var p := Vector3(srng.randf_range(-120, 120), y_base, srng.randf_range(-90, 90))
		if _ground_spot_blocked(p):
			continue
		var basis := Basis(Vector3.UP, srng.randf_range(0.0, TAU)).scaled(Vector3.ONE * srng.randf_range(scl_min, scl_max))
		xforms.append(Transform3D(basis, p))
		cols.append(palette[srng.randi_range(0, palette.size() - 1)])
		placed += 1
	const CELL := 20.0
	var cells: Dictionary = {}
	for i in range(xforms.size()):
		var p2: Vector3 = (xforms[i] as Transform3D).origin
		var key := Vector2i(floori(p2.x / CELL), floori(p2.z / CELL))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(i)
	for key in cells.keys():
		var idxs: Array = cells[key]
		var centre := Vector3((float(key.x) + 0.5) * CELL, 0.0, (float(key.y) + 0.5) * CELL)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = idxs.size()
		for j in range(idxs.size()):
			var t: Transform3D = xforms[idxs[j]]
			mm.set_instance_transform(j, Transform3D(t.basis, t.origin - centre))
			mm.set_instance_color(j, cols[idxs[j]])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = centre
		mmi.custom_aabb = AABB(Vector3(-CELL * 0.5 - 3.0, -1.0, -CELL * 0.5 - 3.0), Vector3(CELL + 6.0, 4.0, CELL + 6.0))
		if vis_end > 0.0:
			mmi.visibility_range_end = vis_end
		world.add_child(mmi)

# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	rng.randomize()
	_define_houses()
	home_index = rng.randi_range(0, houses.size() - 1)
	home_address = houses[home_index]["address"]
	_build_environment()
	_build_audio()
	_build_world()
	_build_escape_room()
	_spawn_player()
	_spawn_npcs()
	_build_camera()
	_build_hud()
	_build_touch_controls()
	_build_escape_ui()
	_show_splash()

func _define_houses() -> void:
	# v0.8 (items 1+2): lots AUDITED against the road grid and numbers
	# RESEQUENCED like a real street. Every lot centre is >= 14 units
	# from every vertical road centreline (Pine -70, Cedar -20, Birch
	# 24, Riverside 72), so no house footprint (x +/-5.8) intrudes into
	# or visually blocks a cross-street — v0.7's "22 Oak Avenue" stood
	# at x=-16, 4 units from the Cedar Street centreline, right in the
	# middle of the view down that street. Elm/Willow rows also pulled
	# 2 units further from their roads so paths/mailboxes stay off the
	# asphalt. Numbers now run strictly UP west->east on every street,
	# ODD on the north side, EVEN on the south side, no duplicates.
	var data: Array = [
		# Maple Street (north side of the z=-11 road -> odd), W->E
		["3 Maple Street", Vector3(-112, 0, -30)],
		["9 Maple Street", Vector3(-98, 0, -30)],
		["15 Maple Street", Vector3(-56, 0, -30)],
		["21 Maple Street", Vector3(-42, 0, -30)],
		["27 Maple Street", Vector3(-6, 0, -30)],
		["33 Maple Street", Vector3(8, 0, -30)],
		["39 Maple Street", Vector3(44, 0, -30)],
		["45 Maple Street", Vector3(98, 0, -30)],
		# Oak Avenue north row (odd), W->E
		["7 Oak Avenue", Vector3(-98, 0, 2)],
		["13 Oak Avenue", Vector3(-42, 0, 2)],
		["19 Oak Avenue, Apartment 3B", Vector3(-6, 0, 2)],
		["25 Oak Avenue", Vector3(52, 0, 2)],
		# Oak Avenue south row (even), W->E
		["4 Oak Avenue", Vector3(-112, 0, 33)],
		["10 Oak Avenue", Vector3(-98, 0, 33)],
		["16 Oak Avenue", Vector3(-56, 0, 33)],
		["22 Oak Avenue, Apartment 1C", Vector3(-42, 0, 33)],
		["28 Oak Avenue", Vector3(-2, 0, 33)],
		["34 Oak Avenue, Apartment 4A", Vector3(44, 0, 33)],
		["40 Oak Avenue", Vector3(98, 0, 33)],
		# Elm Drive (north side -> odd), W->E
		["5 Elm Drive", Vector3(-105, 0, -66)],
		["11 Elm Drive", Vector3(-49, 0, -66)],
		["17 Elm Drive", Vector3(-2, 0, -66)],
		["23 Elm Drive, Apartment 2A", Vector3(44, 0, -66)],
		["29 Elm Drive", Vector3(90, 0, -66)],
		["35 Elm Drive", Vector3(112, 0, -66)],
		# Willow Crescent (south side -> even), W->E
		["6 Willow Crescent", Vector3(-105, 0, 66)],
		["12 Willow Crescent", Vector3(-49, 0, 66)],
		["18 Willow Crescent, Apartment 1B", Vector3(2, 0, 66)],
		["20 Willow Crescent", Vector3(38, 0, 66)],
		["22 Willow Crescent", Vector3(58, 0, 66)],
		["24 Willow Crescent", Vector3(98, 0, 66)],
		# v0.9 FILL (item 1): two rows that never existed — the SOUTH
		# side of Elm Drive (even, face -Z toward the Elm road) and
		# the NORTH side of Willow Crescent (odd, face +Z toward the
		# Willow road). The blocks behind Elm and in front of Willow
		# were the biggest "nothing" chunks on the map. Same rules:
		# >= 14 from every vertical centreline, numbers strictly
		# increasing W->E, parity by side. Facing is EXPLICIT here
		# (3rd element) because the z-band heuristic below would
		# face both rows the wrong way.
		["6 Elm Drive", Vector3(-98, 0, -44), -1.0],
		["12 Elm Drive", Vector3(-42, 0, -44), -1.0],
		["18 Elm Drive", Vector3(2, 0, -44), -1.0],
		["24 Elm Drive", Vector3(48, 0, -44), -1.0],
		["30 Elm Drive", Vector3(98, 0, -44), -1.0],
		["5 Willow Crescent", Vector3(-98, 0, 44), 1.0],
		["11 Willow Crescent", Vector3(-42, 0, 44), 1.0],
		["17 Willow Crescent", Vector3(2, 0, 44), 1.0],
		["23 Willow Crescent", Vector3(42, 0, 44), 1.0],
		["29 Willow Crescent", Vector3(98, 0, 44), 1.0],
	]
	for entry in data:
		var p: Vector3 = entry[1]
		# COHERENT ADDRESSES: every row fronts the street it is named
		# for — Elm (z=-64), Maple (z=-30) and Oak-north (z=2) face +Z
		# toward their road; Oak-south (z=33) and Willow (z=64) face -Z.
		var face: float = 1.0 if (p.z < -20.0 or (p.z > -1.0 and p.z < 10.0)) else -1.0
		if entry.size() > 2:
			face = float(entry[2]) # v0.9 rows carry explicit facing
		var door: Vector3 = p + Vector3(0, 0, 4.6 * face)
		houses.append({"address": entry[0], "pos": p, "door": door, "facing": face})

# ---------------------------------------------------------------- environment/audio
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.25, 0.48, 0.88)
	psm.sky_horizon_color = Color(0.98, 0.82, 0.58)
	psm.ground_bottom_color = Color(0.4, 0.5, 0.35)
	psm.ground_horizon_color = Color(0.98, 0.82, 0.58)
	psm.sun_angle_max = 25.0
	psm.sky_energy_multiplier = 1.15
	psm.ground_energy_multiplier = 0.9
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5 # v1.0 step 2: less flat wash — form comes from the lights now, not ambient
	env.tonemap_mode = Environment.TONE_MAPPER_ACES # v0.8 (item 3): ACES keeps edges crisp; FILMIC softened the whole frame
	env.glow_enabled = false # v0.8 (item 3): bloom REMOVED — it was the main "everything goes blurry when running" cause
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06 # v1.0 step 2: calmer, more natural colour (v0.9's 1.12 pushed neon)
	env.adjustment_contrast = 1.04
	env.adjustment_brightness = 1.02
	# v1.0 step 2: DEPTH FOG — a whisper of warm haze so distance
	# falls off like real air. This is half of why flat games look
	# flat: without aerial perspective every distance shouts at
	# the same volume. Density is low: the far riverbank softens,
	# gameplay range stays crisp.
	env.fog_enabled = true
	env.fog_light_color = Color(0.87, 0.81, 0.72)
	env.fog_light_energy = 0.7
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.3
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.88, 0.72) # v0.9: warm late-afternoon gold
	sun.light_energy = 1.45 # v0.9: stronger warm key light, defined shadows
	sun.shadow_enabled = true
	sun.shadow_blur = 0.4 # v0.8 (item 3): defined shadow edges (was 1.6 painterly smear)
	# PERF (post-v1.0.1): shadow range 220 -> 80. Measured: the shadow
	# pass was ~90% of ALL rendering (25,320 draw calls / 9.9M prims
	# per frame with shadows on vs 2,626 / 1.1M with them off) because
	# at 220 the four cascades covered the whole 252x192 town and all
	# 11,878 mesh instances cast. At 80 the cascades hug the player:
	# shadows stay fully detailed where the cat actually is (and get
	# crisper — the same atlas now covers a third of the span), and
	# the far town simply has no shadow map, like the agreed "shadows
	# local to the player" direction.
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS # v1.0 step 2: crisper shadows near the camera
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	# v1.0 step 2: SKY FILL — a cool, shadowless bounce light from
	# the opposite sky, the second half of a real lighting rig.
	# Shadow sides of the cat, people and houses now grade into
	# blue-grey instead of going dead flat.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-32, 145, 0)
	fill.light_color = Color(0.72, 0.82, 1.0)
	fill.light_energy = 0.34
	fill.shadow_enabled = false
	add_child(fill)
	# Soft billboard CLOUDS (v0.5): layered sprite puffs drifting high up,
	# plus a few 3D puff clusters for parallax.
	var cloud_positions: Array = [Vector3(-70, 34, -70), Vector3(-25, 38, -85), Vector3(30, 33, -75), Vector3(75, 37, -40), Vector3(-85, 36, 10), Vector3(55, 35, 45), Vector3(-45, 39, 65), Vector3(10, 34, 85), Vector3(95, 38, 60), Vector3(-100, 33, -35)]
	for i in range(cloud_positions.size()):
		var sp := Sprite3D.new()
		sp.texture = TEX_CLOUD
		sp.position = cloud_positions[i]
		var sc: float = randf_range(20.0, 32.0)
		sp.pixel_size = sc / 512.0
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.modulate = Color(1, 1, 1, randf_range(0.9, 1.0))
		add_child(sp)
		var sp2 := Sprite3D.new()
		sp2.texture = TEX_CLOUD
		sp2.position = cloud_positions[i] + Vector3(3.5, -1.2, 0)
		sp2.pixel_size = (sc * 0.7) / 512.0
		sp2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp2.shaded = false
		sp2.modulate = Color(1, 1, 1, 0.65)
		add_child(sp2)

func _build_audio() -> void:
	# v0.6 REAL MEOW: recorded cat (Wikimedia Commons, CC BY-SA 3.0,
	# "Felis silvestris catus meows" by Tobias Puderer) — three separate
	# real meows sliced from that one recording, rotated so consecutive
	# meows never sound identical/robotic. No synthesised tone any more.
	for mp in ["res://assets/audio/meow1.wav", "res://assets/audio/meow2.wav", "res://assets/audio/meow3.wav"]:
		meow_players.append(_make_player(mp))
	sfx_meow = meow_players[0]
	sfx_bark = _make_player("res://assets/audio/bark.wav")
	sfx_notice = _make_player("res://assets/audio/notice.wav")
	# v1.2: the prop-crash cue — the notice blip dropped to a thud on
	# its OWN player, so the live notice sound is never pitch-shifted.
	sfx_crash = _make_player("res://assets/audio/notice.wav")
	sfx_crash.pitch_scale = 0.5
	sfx_crash.volume_db = -4.0
	sfx_win = _make_player("res://assets/audio/win_chime.wav")
	music = _make_player("res://assets/audio/music_pad.wav")
	music.volume_db = -14.0
	# v0.6 SPLASH TUNE (locked instrumentation): composed and rendered
	# for Homeward — felt piano melody, warm soft pad, gentle acoustic
	# guitar picking (Karplus-Strong modelled strings), and a soft
	# strings swell as the cat appears, then settling cozy. Modelled
	# real instruments, NOT chiptune/beeps. 16s, loops under the splash.
	splash_song_player = _make_player("res://assets/audio/splash_song.ogg")
	# v0.6 PURR: a real recorded cat purr ("Felis silvestris catus
	# purrs", Wikimedia Commons, CC BY-SA 3.0), cut into a seamless
	# 6.5s loop. Plays while the cat idles in town (see _process).
	purr_player = _make_player("res://assets/audio/purr.wav")
	purr_player.volume_db = -7.0
	if purr_player.stream is AudioStreamWAV:
		var pw := purr_player.stream as AudioStreamWAV
		pw.loop_mode = AudioStreamWAV.LOOP_FORWARD
		pw.loop_end = int(pw.get_length() * pw.mix_rate)
	splash_song_player.volume_db = -9.0
	# (Looping is done by replaying on finish while the splash is up —
	# see _process — because the excerpt already fades at both ends.)

func _make_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		p.stream = load(path)
	add_child(p)
	return p

# ---------------------------------------------------------------- world
func _build_world() -> void:
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	# Grass base (v0.6 EXPANDED MAP: 252 x 192, was 130 x 96) + park lawn
	var grass_base := _box(world, Vector3(0, -0.25, 0), Vector3(252, 0.5, 192), Color.WHITE)
	grass_base.material_override = _mat_tex(TEX_GRASS, Color(0.72, 0.84, 0.64), Vector3(50, 38, 1))
	# Invisible solid ground (town + escape room) so physics / jumping work
	var ground_body := StaticBody3D.new()
	var ground_cs := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(430, 1.0, 214)
	ground_cs.shape = ground_shape
	ground_cs.position = Vector3(85, -0.5, 0)
	ground_body.add_child(ground_cs)
	world.add_child(ground_body)
	var park_lawn := _box(world, Vector3(-38, 0.02, 24), Vector3(34, 0.06, 18), Color.WHITE)
	park_lawn.material_override = _mat_tex(TEX_GRASS_PARK, Color(0.78, 0.9, 0.7), Vector3(9, 5, 1))
	# Deterministic scatter RNG for the expansion (seed 777): the map is
	# identical every run, so its landmarks can be learned.
	var srng := RandomNumberGenerator.new()
	srng.seed = 777
	var road_zs: Array = [-55.0, -11.0, 15.0, 55.0]
	var road_xs: Array = [-70.0, -20.0, 24.0, 72.0]
	# Grass tufts: little crossed blade clusters scattered on the lawns
	for i in range(170): # v0.9: nearly double the ground detail
		var tp2 := Vector3(srng.randf_range(-118, 118), 0.22, srng.randf_range(-88, 88))
		var on_road_t := false
		for rz2 in road_zs:
			if abs(tp2.z - rz2) < 6.5: on_road_t = true
		for rx2 in road_xs:
			if abs(tp2.x - rx2) < 6.5: on_road_t = true
		if on_road_t:
			continue
		_grass_tuft(world, tp2, i)
	# v1.0 step 2: instanced ground detail — 8,000 grass blades and
	# 380 wildflowers, two draw calls total (see _scatter_multimesh).
	# IMPORTANT: this scatter uses its OWN seeded RNG — drawing from
	# srng here shifted every later scatter (trees/bushes) off the
	# v0.9 layout. Instance colours need vertex_color_use_as_albedo
	# or the instances render plain white (learned from the first
	# step-2 screenshots: a lawn full of white daggers).
	var detail_rng := RandomNumberGenerator.new()
	detail_rng.seed = 4242
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color.WHITE
	blade_mat.roughness = 1.0
	blade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade_mat.vertex_color_use_as_albedo = true
	_scatter_multimesh(world, detail_rng, _blade_mesh(), 12000, blade_mat, [Color(0.34, 0.56, 0.22), Color(0.3, 0.5, 0.19), Color(0.39, 0.61, 0.25), Color(0.32, 0.53, 0.2)], 0.02, 0.6, 1.1, 60.0) # PERF: blades drawn only within 60m (chunked cells)
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.06
	flower_mesh.height = 0.12
	flower_mesh.radial_segments = 6
	flower_mesh.rings = 4
	var flower_mat := StandardMaterial3D.new()
	flower_mat.albedo_color = Color.WHITE
	flower_mat.roughness = 0.75
	flower_mat.vertex_color_use_as_albedo = true
	_scatter_multimesh(world, detail_rng, flower_mesh, 380, flower_mat, [Color(0.98, 0.55, 0.65), Color(0.99, 0.85, 0.35), Color(0.97, 0.96, 0.92), Color(0.78, 0.65, 0.95)], 0.1, 0.8, 1.3, 45.0) # PERF: flowers drawn only within 45m (chunked cells)
	# Roads: FOUR horizontal + FOUR vertical (v0.6), with sidewalks + dashes
	for rz in road_zs:
		var walk_h := _box(world, Vector3(0, 0.03, rz), Vector3(252, 0.06, 9.6), Color.WHITE)
		walk_h.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(62, 2, 1))
		var road_h := _box(world, Vector3(0, 0.06, rz), Vector3(252, 0.06, 7.2), Color.WHITE)
		road_h.material_override = _mat_tex(TEX_ASPHALT, Color.WHITE, Vector3(50, 2, 1), 0.97)
		for dx in range(-120, 121, 6):
			_box(world, Vector3(dx, 0.1, rz), Vector3(2.6, 0.03, 0.35), Color(0.95, 0.85, 0.4))
	for rx in road_xs:
		var walk_v := _box(world, Vector3(rx, 0.04, 0), Vector3(9.6, 0.06, 192), Color.WHITE)
		walk_v.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(2, 48, 1))
		var road_v := _box(world, Vector3(rx, 0.07, 0), Vector3(7.2, 0.06, 192), Color.WHITE)
		road_v.material_override = _mat_tex(TEX_ASPHALT, Color.WHITE, Vector3(2, 40, 1), 0.97)
		for dz in range(-90, 91, 6):
			_box(world, Vector3(rx, 0.11, dz), Vector3(0.35, 0.03, 2.6), Color(0.95, 0.85, 0.4))
	# Street signs: EVERY street gets TWO, at opposite ends, so you can
	# always find one for the street you're on (tilt up with look-drag).
	_sign(world, "MAPLE STREET", Vector3(-58, 0, -6), "Maple Street")
	_sign(world, "MAPLE STREET", Vector3(66, 0, -16), "Maple Street")
	_sign(world, "ELM DRIVE", Vector3(-64, 0, -49), "Elm Drive")
	_sign(world, "ELM DRIVE", Vector3(100, 0, -49), "Elm Drive")
	_sign(world, "OAK AVENUE", Vector3(-14, 0, 10), "Oak Avenue")
	_sign(world, "OAK AVENUE", Vector3(58, 0, 20), "Oak Avenue")
	_sign(world, "WILLOW CRESCENT", Vector3(66, 0, 49), "Willow Crescent")
	_sign(world, "WILLOW CRESCENT", Vector3(-58, 0, 60), "Willow Crescent")
	_sign(world, "PINE STREET", Vector3(-64, 0, -16), "Pine Street", 90.0)
	_sign(world, "PINE STREET", Vector3(-76, 0, 44), "Pine Street", 90.0)
	_sign(world, "CEDAR STREET", Vector3(-26, 0, -40), "Cedar Street", 90.0)
	_sign(world, "CEDAR STREET", Vector3(-14, 0, 44), "Cedar Street", 90.0)
	_sign(world, "BIRCH LANE", Vector3(30, 0, -16), "Birch Lane", 90.0)
	_sign(world, "BIRCH LANE", Vector3(18, 0, 44), "Birch Lane", 90.0)
	_sign(world, "RIVERSIDE DRIVE", Vector3(66, 0, -40), "Riverside Drive", 90.0)
	_sign(world, "RIVERSIDE DRIVE", Vector3(78, 0, 30), "Riverside Drive", 90.0)
	_sign(world, "PARK", Vector3(-52, 0, 20.8))
	_sign(world, "THE RIVER", Vector3(58, 0, -86))
	# Houses
	var wall_cols: Array = [Color(0.96, 0.9, 0.8), Color(0.82, 0.87, 0.96), Color(0.96, 0.83, 0.72), Color(0.86, 0.93, 0.83), Color(0.95, 0.78, 0.82), Color(0.9, 0.85, 0.95), Color(0.98, 0.93, 0.72), Color(0.8, 0.92, 0.9)]
	var roof_cols: Array = [Color(0.72, 0.33, 0.28), Color(0.33, 0.47, 0.72), Color(0.42, 0.6, 0.38), Color(0.78, 0.57, 0.28), Color(0.5, 0.35, 0.55), Color(0.3, 0.55, 0.6), Color(0.65, 0.4, 0.25), Color(0.45, 0.45, 0.5)]
	for i in range(houses.size()):
		_build_house(world, houses[i], wall_cols[i % 8], roof_cols[(i * 3 + 1) % 8])
	# v0.9 STREET TREES: one shade tree in every wide gap between
	# neighbouring houses on a row (back-yard side, nudged clear of
	# the cross-streets), so no stretch of any street reads bare.
	var rows_g: Dictionary = {}
	for hh3 in houses:
		var rk: String = str(int((hh3["pos"] as Vector3).z))
		if not rows_g.has(rk):
			rows_g[rk] = []
		rows_g[rk].append(hh3)
	for rk in rows_g:
		var row_g: Array = rows_g[rk]
		row_g.sort_custom(func(a, b): return (a["pos"] as Vector3).x < (b["pos"] as Vector3).x)
		for ri in range(row_g.size() - 1):
			var xa: float = (row_g[ri]["pos"] as Vector3).x
			var xb: float = (row_g[ri + 1]["pos"] as Vector3).x
			if xb - xa > 22.0:
				var hz2: float = (row_g[ri]["pos"] as Vector3).z
				var hf2: float = float(row_g[ri]["facing"])
				var spots: Array = [(xa + xb) * 0.5]
				if xb - xa > 40.0:
					spots = [xa + 12.0, xb - 12.0] # wide gap: a tree watching each end
				for midx0 in spots:
					var midx: float = midx0
					for rxg in [-70.0, -20.0, 24.0, 72.0]:
						if absf(midx - rxg) < 9.0:
							midx += 10.0 if midx >= rxg else -10.0
					_build_tree(world, Vector3(midx, 0, hz2 - hf2 * 8.0))
	# Trees, bushes (fixed dressing + deterministic scatter in new districts)
	var tree_positions: Array = [Vector3(-56, 0, -38), Vector3(-14, 0, -40), Vector3(52, 0, -24), Vector3(54, 0, 40), Vector3(-58, 0, 40), Vector3(2, 0, 24), Vector3(-34, 0, -20), Vector3(48, 0, -4)] # v0.9: (-2,-38) moved — an Elm-south house stands there now
	for tp in tree_positions:
		_build_tree(world, tp)
	# v0.9: scatter now collects ALL valid spots, shuffles them
	# (seeded) and plants evenly across the WHOLE map — v0.8 filled
	# west-to-east until its cap ran out, which is exactly why the
	# east and south felt empty. Caps nearly doubled, too.
	var tree_cands: Array = []
	for gx in range(-112, 113, 13):
		for gz in range(-84, 85, 13):
			var cand := Vector3(float(gx) + srng.randf_range(-4, 4), 0, float(gz) + srng.randf_range(-4, 4))
			var bad := false
			for rz3 in road_zs:
				if abs(cand.z - rz3) < 7.5: bad = true
			for rx3 in road_xs:
				if abs(cand.x - rx3) < 7.5: bad = true
			for hh in houses:
				if cand.distance_to(hh["pos"]) < 9.5: bad = true
			if cand.x > -58 and cand.x < -18 and cand.z > 12 and cand.z < 36: bad = true # park 1
			if cand.x > -104 and cand.x < -64 and cand.z > 62 and cand.z < 86: bad = true # park 2
			if cand.x > 84 and cand.x < 114 and cand.z > 18 and cand.z < 48: bad = true # v0.9 playground
			if cand.x > -116 and cand.x < -84 and cand.z > 74: bad = true # v0.9 community garden
			if cand.distance_to(Vector3(0, 0, -80)) < 8.0: bad = true # clock tower
			if cand.distance_to(Vector3(2, 0, -2)) < 7.0: bad = true # spawn
			if bad:
				continue
			tree_cands.append(cand)
	for si in range(tree_cands.size() - 1, 0, -1): # seeded Fisher-Yates (map stays identical every run)
		var sj: int = srng.randi_range(0, si)
		var stmp = tree_cands[si]; tree_cands[si] = tree_cands[sj]; tree_cands[sj] = stmp
	var scattered_trees: int = 0
	for cand2 in tree_cands:
		if scattered_trees >= 46:
			break
		_build_tree(world, cand2)
		scattered_trees += 1
	var bush_positions: Array = [Vector3(-12, 0, -20), Vector3(30, 0, -22), Vector3(-30, 0, 8), Vector3(44, 0, 24), Vector3(-52, 0, -14), Vector3(6, 0, 38)]
	for bp in bush_positions:
		_build_bush(world, bp)
		hide_points.append(bp)
	var bush_cands: Array = []
	for gx2 in range(-105, 106, 17):
		for gz2 in range(-77, 78, 17):
			var bcand := Vector3(float(gx2) + srng.randf_range(-5, 5), 0, float(gz2) + srng.randf_range(-5, 5))
			var bbad := false
			for rz4 in road_zs:
				if abs(bcand.z - rz4) < 7.0: bbad = true
			for rx4 in road_xs:
				if abs(bcand.x - rx4) < 7.0: bbad = true
			for hh2 in houses:
				if bcand.distance_to(hh2["pos"]) < 9.0: bbad = true
			if bbad:
				continue
			bush_cands.append(bcand)
	for si2 in range(bush_cands.size() - 1, 0, -1):
		var sj2: int = srng.randi_range(0, si2)
		var stmp2 = bush_cands[si2]; bush_cands[si2] = bush_cands[sj2]; bush_cands[sj2] = stmp2
	var scattered_bushes: int = 0
	for bcand2 in bush_cands:
		if scattered_bushes >= 26:
			break
		_build_bush(world, bcand2)
		hide_points.append(bcand2)
		scattered_bushes += 1
	# Cars: FIVE types (v0.6), several colours, all hiding spots
	var car_data: Array = [
		[Vector3(-8, 0, -11), Color(0.8, 0.25, 0.22), "sedan"], [Vector3(36, 0, 15), Color(0.25, 0.45, 0.85), "sedan"],
		[Vector3(-38, 0, 15), Color(0.3, 0.6, 0.5), "hatchback"], [Vector3(12, 0, -11), Color(0.9, 0.88, 0.85), "van"],
		[Vector3(30, 0, -24), Color(0.5, 0.5, 0.55), "pickup"], [Vector3(44, 0, 15), Color(0.2, 0.55, 0.6), "hatchback"],
		[Vector3(52, 0, 15), Color(0.6, 0.35, 0.75), "convertible"], [Vector3(60, 0, 15), Color(0.82, 0.85, 0.9), "van"],
		[Vector3(-52, 0, -55), Color(0.35, 0.55, 0.3), "pickup"], [Vector3(80, 0, 55), Color(0.75, 0.76, 0.8), "sedan"],
		[Vector3(-88, 0, -11), Color(0.9, 0.55, 0.2), "hatchback"], [Vector3(100, 0, -11), Color(0.2, 0.3, 0.55), "van"],
		[Vector3(-100, 0, 55), Color(0.55, 0.25, 0.3), "pickup"],
	]
	for cd in car_data:
		_build_car(world, cd[0], cd[1], true, cd[2])
		hide_points.append(cd[0])
	# Park fence with a gap, benches, pond, flowers. v0.7: this fence
	# used to stand at z=15.5 — right IN the Oak Avenue roadway (the
	# bare posts in Michael's photo). It now runs along the park's
	# south edge at z=20.6 and it is SOLID (posts + rails collide),
	# with two solid runs leaving only the signed cat gap open.
	for fx in range(-54, -22, 2):
		if fx > -40 and fx < -34:
			continue # gap
		_box(world, Vector3(fx, 0.5, 20.6), Vector3(0.18, 1.0, 0.18), Color(0.6, 0.45, 0.3), true)
	_box(world, Vector3(-47, 0.85, 20.6), Vector3(14, 0.12, 0.12), Color(0.6, 0.45, 0.3), true)
	_box(world, Vector3(-47, 0.45, 20.6), Vector3(14, 0.1, 0.1), Color(0.6, 0.45, 0.3), true)
	_box(world, Vector3(-29, 0.85, 20.6), Vector3(10, 0.12, 0.12), Color(0.6, 0.45, 0.3), true)
	_box(world, Vector3(-29, 0.45, 20.6), Vector3(10, 0.1, 0.1), Color(0.6, 0.45, 0.3), true)
	# PURSUIT-ENDER SPOTS (v0.6 wave 3): cat-sized gaps in fences. Slip
	# through one mid-chase and the chase ends outright — a person
	# cannot follow. The park fence gap (x -40..-34 above) is one; two
	# garden fences get matching gaps, each signed with a paw marker.
	ender_points.append(Vector3(-37, 0, 20.6))
	# v0.7: the second garden fence used to run along x=-70 — IN the
	# Pine Street roadway. It now stands at x=-63, off the road, and
	# both garden fences are SOLID (posts + rails collide) except for
	# the signed cat gap itself.
	for gap_def in [[Vector3(58, 0, 44), "x"], [Vector3(-63, 0, -38), "z"]]:
		var gc: Vector3 = gap_def[0]
		ender_points.append(gc)
		for off in range(-8, 9, 2):
			if abs(off) < 2:
				continue # the gap itself
			var fp2: Vector3 = gc + (Vector3(off, 0, 0) if gap_def[1] == "x" else Vector3(0, 0, off))
			_box(world, fp2 + Vector3(0, 0.5, 0), Vector3(0.18, 1.0, 0.18), Color(0.6, 0.45, 0.3), true)
		for run_c in [-5.0, 5.0]:
			var rc: Vector3 = gc + (Vector3(run_c, 0, 0) if gap_def[1] == "x" else Vector3(0, 0, run_c))
			var rsize := Vector3(6.0, 0.12, 0.12) if gap_def[1] == "x" else Vector3(0.12, 0.12, 6.0)
			_box(world, rc + Vector3(0, 0.85, 0), rsize, Color(0.6, 0.45, 0.3), true)
			_box(world, rc + Vector3(0, 0.45, 0), Vector3(rsize.x, 0.1, rsize.z), Color(0.6, 0.45, 0.3), true)
		_label3d(world, "🐾 cat gap", gc + Vector3(0, 1.5, 0), 40, Color(1.0, 0.95, 0.7))
	_label3d(world, "🐾 cat gap", Vector3(-37, 1.5, 20.6), 40, Color(1.0, 0.95, 0.7))
	var pond := _cyl(world, Vector3(-44, 0.08, 26), 3.2, 3.2, 0.16, Color.WHITE)
	pond.material_override = _mat_tex(TEX_WATER, Color.WHITE, Vector3(3, 3, 1), 0.35) # pond
	content_points.append(Vector3(-44, 0, 26)) # v0.9 audit: park 1
	content_points.append(Vector3(-38, 0, 24))
	for bpos in [Vector3(-30, 0, 22), Vector3(-24, 0, 28)]:
		_box(world, bpos + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
		_box(world, bpos + Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		_box(world, bpos + Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	for i in range(26):
		var fp := Vector3(randf_range(-54, -22), 0.16, randf_range(17, 32))
		_sphere(world, fp, Vector3(0.22, 0.22, 0.22), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.9, 0.9, 0.95)][i % 3])
	# Crosswalks at the main intersections
	for cx in [-70.0, -20.0, 24.0, 72.0]:
		for cz in [-55.0, -11.0, 15.0, 55.0]:
			if not ((cx == -20.0 or cx == 24.0) or (cz == -11.0 or cz == 15.0)):
				continue
			for s in range(-3, 4):
				_box(world, Vector3(cx + float(s) * 1.05, 0.12, cz - 5.6), Vector3(0.62, 0.03, 2.6), Color(0.94, 0.94, 0.92))
				_box(world, Vector3(cx - 5.6, 0.12, cz + float(s) * 1.05), Vector3(2.6, 0.03, 0.62), Color(0.94, 0.94, 0.92))
	for i in range(36):
		var gp := Vector3(srng.randf_range(-118, 118), 0.045, srng.randf_range(-88, 88))
		var gon := false
		for rz5 in road_zs:
			if abs(gp.z - rz5) < 6.0: gon = true
		for rx5 in road_xs:
			if abs(gp.x - rx5) < 6.0: gon = true
		if gon:
			continue
		var patch := _box(world, gp, Vector3(srng.randf_range(3.0, 6.0), 0.03, srng.randf_range(2.0, 4.0)), Color.WHITE)
		patch.material_override = _mat_tex(TEX_GRASS_PARK if i % 2 == 0 else TEX_GRASS, Color(0.92, 0.98, 0.9), Vector3(2, 1, 1))
	for lp2 in [Vector2(-46, 24.5), Vector2(-41, 27.5), Vector2(-36, 23.5)]:
		_cyl(world, Vector3(lp2.x, 0.2, lp2.y), 0.55, 0.55, 0.06, Color(0.3, 0.62, 0.32))
	_sphere(world, Vector3(-43, 0.32, 26.5), Vector3(0.42, 0.3, 0.55), Color(0.98, 0.97, 0.94)) # duck body
	_sphere(world, Vector3(-42.7, 0.55, 26.9), Vector3(0.24, 0.24, 0.24), Color(0.98, 0.97, 0.94)) # duck head
	_box(world, Vector3(-42.55, 0.52, 27.12), Vector3(0.2, 0.07, 0.1), Color(0.95, 0.65, 0.2)) # beak
	for i in range(22):
		var fp2 := Vector3(srng.randf_range(-114, 114), 0.16, srng.randf_range(-86, 86))
		_sphere(world, fp2, Vector3(0.2, 0.2, 0.2), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.75, 0.6, 0.95)][i % 3])
	# Lamp posts
	for lp in [Vector3(-26, 0, -6), Vector3(18, 0, -16), Vector3(-26, 0, 20), Vector3(30, 0, 10), Vector3(-2, 0, -16), Vector3(2, 0, 20), Vector3(-64, 0, -49), Vector3(66, 0, 60), Vector3(-76, 0, 20), Vector3(30, 0, -60), Vector3(84, 0, -6), Vector3(-96, 0, 44)]:
		_cyl(world, lp + Vector3(0, 2.2, 0), 0.07, 0.09, 4.4, Color(0.25, 0.27, 0.3), true)
		_sphere(world, lp + Vector3(0, 4.5, 0), Vector3(0.5, 0.5, 0.5), Color(1.0, 0.9, 0.6))
	# ============ SECOND PARK (north-west district): lawn, pond, gazebo
	var lawn2 := _box(world, Vector3(-84, 0.02, 74), Vector3(34, 0.06, 18), Color.WHITE)
	lawn2.material_override = _mat_tex(TEX_GRASS_PARK, Color(0.78, 0.9, 0.7), Vector3(9, 5, 1))
	var pond2 := _cyl(world, Vector3(-90, 0.08, 76), 3.0, 3.0, 0.16, Color.WHITE)
	pond2.material_override = _mat_tex(TEX_WATER, Color.WHITE, Vector3(3, 3, 1), 0.35)
	content_points.append(Vector3(-90, 0, 76)) # v0.9 audit: park 2
	content_points.append(Vector3(-76, 0, 66)) # gazebo
	for bpos2 in [Vector3(-78, 0, 71), Vector3(-72, 0, 79)]:
		_box(world, bpos2 + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
		_box(world, bpos2 + Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		_box(world, bpos2 + Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	# Gazebo
	var gz_pos := Vector3(-76, 0, 66)
	_cyl(world, gz_pos + Vector3(0, 0.12, 0), 3.0, 3.2, 0.24, Color(0.8, 0.75, 0.68), true)
	for ga in [Vector2(1.7, 1.7), Vector2(-1.7, 1.7), Vector2(1.7, -1.7), Vector2(-1.7, -1.7)]:
		_cyl(world, gz_pos + Vector3(ga.x, 1.5, ga.y), 0.09, 0.09, 2.8, Color(0.92, 0.9, 0.86), true)
	var gz_roof := _cyl(world, gz_pos + Vector3(0, 3.6, 0), 0.3, 3.5, 1.4, Color.WHITE)
	gz_roof.material_override = _mat_tex(TEX_ROOF, Color(0.55, 0.35, 0.3), Vector3(3, 1, 1))
	_sphere(world, gz_pos + Vector3(0, 4.5, 0), Vector3(0.28, 0.28, 0.28), Color(0.9, 0.75, 0.3))
	for i in range(14):
		var fp3 := Vector3(srng.randf_range(-100, -68), 0.16, srng.randf_range(66, 82))
		_sphere(world, fp3, Vector3(0.2, 0.2, 0.2), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.9, 0.9, 0.95)][i % 3])
	# ============ CLOCK TOWER landmark (north centre, by the river road)
	var tower := _box(world, Vector3(0, 5, -80), Vector3(4.4, 10, 4.4), Color.WHITE, true)
	tower.material_override = _mat_tex(TEX_BRICK, Color(0.92, 0.85, 0.8), Vector3(3, 6, 1))
	_box(world, Vector3(0, 10.2, -80), Vector3(5.2, 0.4, 5.2), Color(0.6, 0.55, 0.5))
	var clock_f := _cyl(world, Vector3(0, 8.3, -77.7), 1.35, 1.35, 0.22, Color(0.97, 0.95, 0.88))
	clock_f.rotation_degrees = Vector3(90, 0, 0)
	var ch1 := _box(world, Vector3(0, 8.55, -77.55), Vector3(0.09, 0.75, 0.06), Color(0.15, 0.15, 0.17))
	ch1.rotation_degrees = Vector3(0, 0, -30)
	var ch2 := _box(world, Vector3(0.18, 8.3, -77.55), Vector3(0.09, 0.55, 0.06), Color(0.15, 0.15, 0.17))
	ch2.rotation_degrees = Vector3(0, 0, 90)
	var t_roof := _cyl(world, Vector3(0, 11.5, -80), 0.25, 3.1, 2.4, Color.WHITE)
	t_roof.material_override = _mat_tex(TEX_ROOF, Color(0.4, 0.45, 0.6), Vector3(3, 1, 1))
	_sphere(world, Vector3(0, 12.9, -80), Vector3(0.3, 0.3, 0.3), Color(0.95, 0.78, 0.3))
	_label3d(world, "🕐 OLD CLOCK TOWER", Vector3(0, 13.8, -80), 64, Color(1.0, 0.95, 0.75))
	content_points.append(Vector3(0, 0, -80)) # v0.9 audit
	# ============ BORDERS — the world CONTINUES past every edge ========
	# One invisible collision body with 4 shapes at the obstructions.
	var border_body := StaticBody3D.new()
	var b_shapes: Array = [
		[Vector3(252, 2, 1), Vector3(0, 1, -92)], [Vector3(252, 2, 1), Vector3(0, 1, 92)],
		[Vector3(1, 2, 192), Vector3(-119.8, 1, 0)], [Vector3(1, 2, 192), Vector3(119.8, 1, 0)],
	]
	for bs in b_shapes:
		var bcs := CollisionShape3D.new()
		var bsh := BoxShape3D.new()
		bsh.size = bs[0]
		bcs.shape = bsh
		bcs.position = bs[1]
		border_body.add_child(bcs)
	world.add_child(border_body)
	# NORTH: a RIVER — water, far bank, houses across the water, fence here
	var river := _box(world, Vector3(0, 0.0, -99.5), Vector3(252, 0.25, 13), Color.WHITE)
	river.material_override = _mat_tex(TEX_WATER, Color(0.85, 0.95, 1.05), Vector3(40, 2, 1), 0.3)
	var far_bank := _box(world, Vector3(0, -0.05, -115), Vector3(252, 0.6, 18), Color.WHITE)
	far_bank.material_override = _mat_tex(TEX_GRASS, Color(0.66, 0.78, 0.6), Vector3(40, 3, 1))
	for hx in [-100, -60, -20, 20, 60, 100]:
		_box(world, Vector3(hx, 2.5, -124), Vector3(10, 5, 8), Color(0.82, 0.78, 0.72))
		var sr1 := _box(world, Vector3(hx - 2.4, 5.6, -124), Vector3(6.4, 0.25, 9), Color(0.5, 0.42, 0.4))
		sr1.rotation_degrees = Vector3(0, 0, 34)
		var sr2 := _box(world, Vector3(hx + 2.4, 5.6, -124), Vector3(6.4, 0.25, 9), Color(0.5, 0.42, 0.4))
		sr2.rotation_degrees = Vector3(0, 0, -34)
		_build_pine(world, Vector3(hx + 9, 0, -120), 1.1)
	var fxi: int = 0
	for fx2 in range(-124, 125, 4):
		_box(world, Vector3(fx2, 0.55, -92), Vector3(0.16, 1.1, 0.16), Color(0.55, 0.45, 0.35))
		if fxi % 6 == 0:
			content_points.append(Vector3(fx2, 0, -92)) # v0.9 audit: the river fence is content
		fxi += 1
	_box(world, Vector3(0, 0.95, -92), Vector3(252, 0.12, 0.1), Color(0.55, 0.45, 0.35))
	_box(world, Vector3(0, 0.5, -92), Vector3(252, 0.1, 0.1), Color(0.55, 0.45, 0.35))
	# SOUTH: a tall HEDGE + a pine FOREST behind it
	var hedge := _box(world, Vector3(0, 0.85, 92), Vector3(252, 1.7, 1.4), Color.WHITE, true)
	hedge.material_override = _mat_tex(TEX_FOLIAGE, Color(0.75, 0.9, 0.72), Vector3(40, 1, 1))
	for hx2 in range(-120, 121, 8):
		_sphere(world, Vector3(hx2, 1.85, 92), Vector3(1.6, 0.8, 1.2), Color(0.42, 0.62, 0.36))
		content_points.append(Vector3(hx2, 0, 92)) # v0.9 audit: the south hedge is content
	for px in range(-120, 121, 11):
		_build_pine(world, Vector3(px + srng.randf_range(-2, 2), 0, 99 + srng.randf_range(-1.5, 1.5)), srng.randf_range(0.95, 1.3))
	for px2 in range(-116, 117, 14):
		_build_pine(world, Vector3(px2 + srng.randf_range(-3, 3), 0, 108 + srng.randf_range(-2, 2)), srng.randf_range(1.15, 1.55))
	# WEST: tall CITY BUILDINGS backing onto the edge + a fence
	var b_heights: Array = [14.0, 11.0, 17.0, 12.0, 15.0]
	var b_zs: Array = [-68.0, -38.0, -8.0, 22.0, 52.0]
	for bi in range(5):
		var bh: float = b_heights[bi]
		var bld := _box(world, Vector3(-128, bh * 0.5, b_zs[bi]), Vector3(14, bh, 22), Color.WHITE)
		bld.material_override = _mat_tex(TEX_BRICK if bi % 2 == 0 else TEX_SIDING, Color(0.8, 0.78, 0.8), Vector3(4, 6, 1))
		for wy in range(2, int(bh) - 1, 3):
			for wz in [-6, 0, 6]:
				_box(world, Vector3(-120.9, float(wy), b_zs[bi] + float(wz)), Vector3(0.12, 1.0, 0.8), Color(1.0, 0.88, 0.55), false, 0.55)
	var wzi: int = 0
	for fz in range(-93, 94, 6):
		_box(world, Vector3(-119.8, 0.55, fz), Vector3(0.16, 1.1, 0.16), Color(0.5, 0.5, 0.55))
		if wzi % 3 == 0:
			content_points.append(Vector3(-119.8, 0, fz)) # v0.9 audit: the west fence is content
		wzi += 1
	_box(world, Vector3(-119.8, 0.95, 0), Vector3(0.1, 0.12, 192), Color(0.5, 0.5, 0.55))
	_box(world, Vector3(-119.8, 0.5, 0), Vector3(0.1, 0.1, 192), Color(0.5, 0.5, 0.55))
	# EAST: CONSTRUCTION — striped barriers, cones, a half-built house + crane
	for bz3 in range(-60, 61, 15):
		_box(world, Vector3(119.8, 0.5, bz3), Vector3(0.5, 1.0, 3.4), Color(0.95, 0.5, 0.15), true)
		_box(world, Vector3(119.8, 0.72, bz3), Vector3(0.54, 0.22, 3.4), Color(0.96, 0.95, 0.92))
		content_points.append(Vector3(119.8, 0, bz3)) # v0.9 audit: construction barriers are content
	for cz3 in range(-52, 53, 13):
		var cone := _cyl(world, Vector3(118.4, 0.4, cz3), 0.06, 0.3, 0.8, Color(0.95, 0.45, 0.12))
		cone.material_override = _mat(Color(0.95, 0.45, 0.12), 0.6)
	for cpx in [126.0, 136.0]:
		for cpz in [2.0, 18.0]:
			_box(world, Vector3(cpx, 3.5, cpz), Vector3(0.45, 7, 0.45), Color(0.75, 0.6, 0.4), true)
	_box(world, Vector3(131, 3.6, 10), Vector3(11, 0.3, 18), Color(0.8, 0.68, 0.5))
	_box(world, Vector3(131, 7.1, 10), Vector3(11, 0.3, 18), Color(0.8, 0.68, 0.5))
	_cyl(world, Vector3(140, 8.5, -16), 0.35, 0.45, 17, Color(0.9, 0.6, 0.15))
	var jib := _box(world, Vector3(132, 16.8, -16), Vector3(17, 0.5, 0.5), Color(0.9, 0.6, 0.15))
	jib.rotation_degrees = Vector3(0, 0, 2)
	_cyl(world, Vector3(125, 14.2, -16), 0.03, 0.03, 5.2, Color(0.3, 0.3, 0.32))
	_box(world, Vector3(125, 11.4, -16), Vector3(0.7, 0.5, 0.7), Color(0.55, 0.4, 0.25))
	_label3d(world, "🚧 NEW HOMES — COMING SOON!", Vector3(124, 9.5, 10), 64, Color(1.0, 0.8, 0.4))
	# v0.9 FILL FEATURES (item 1): the named places that end the
	# "big chunks of nothing" — playground, community garden, bus
	# stop, little library, extra benches and lamps.
	_build_fill_features(world, srng)
	# v1.0 TOWN FILL (micro-step 1): substantial built content in the
	# blocks the v0.9 audit still left thin — promenade, shops, hall,
	# apartment block, market stalls, Willow Green, garden clusters,
	# sheds, fences and a full lamp grid — so every viewpoint reads
	# as a neighbourhood. No houses array entries (count stays 41),
	# no hide/ender points, gameplay untouched.
	_build_town_fill(world, srng)
	# v0.7 TRAFFIC: moving cars live under their own group (spawned
	# and despawned at runtime — see _process_traffic).
	traffic_group = Node3D.new()
	traffic_group.name = "Traffic"
	world.add_child(traffic_group)
	# PERF (post-v1.0.1): one build-time pass over the finished town
	# giving small clutter a visibility range (see below).
	_apply_clutter_ranges(world)

# PERF (post-v1.0.1): VISIBILITY RANGES FOR SMALL CLUTTER.
# The town is ~11,900 individual mesh instances; the main camera
# pass alone was 2,626 draw calls because every window flower,
# fence picket, road dash and mailbox was drawn at every distance.
# This pass walks the built World once and ranges only pieces that
# are too small to read from far away: thin flat pieces (dashes,
# sills, path slabs, flower boxes) get 75m, small props (pickets,
# posts, mailbox parts, flowerbed flowers, grass-tuft blades,
# bench legs) get 65m. Both ranges are far beyond the 35m zone
# where the picture must not change, and at 65-75m these pieces are
# a few pixels tall, so the range edge is not perceptible. Houses,
# trees, signs, buildings and cars are untouched and stay drawn
# across the whole map — the vista Michael asked for is intact.
# Ground decals (<= 12cm thick, lying on the ground) also stop
# casting shadows: a 3cm dash's shadow is a hairline nobody can
# see, but it was being drawn into all four shadow cascades.
# Car subtrees are skipped whole (a car must never shed parts),
# as is the (empty at build time) Traffic group.
func _apply_clutter_ranges(n: Node) -> void:
	if n.name == "Car" or n.name == "Traffic":
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		var s: Vector3 = aabb.size
		if s.y <= 0.30 and s.x <= 3.0 and s.z <= 3.0:
			mi.visibility_range_end = 75.0
			if s.y <= 0.12 and aabb.get_center().y < 0.3:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif s.x <= 0.65 and s.y <= 1.05 and s.z <= 0.65:
			mi.visibility_range_end = 65.0
	for ch in n.get_children():
		_apply_clutter_ranges(ch)

func _build_fill_features(world: Node3D, srng: RandomNumberGenerator) -> void:
	# ============ PLAYGROUND (east block, Oak/Willow, x 88..112) ====
	# Kept south of z=38: 29 Willow Crescent's front fence line is
	# at z=38.8 — nothing here touches the house.
	var pg := Vector3(97, 0, 30)
	var mat1 := _box(world, pg + Vector3(0, 0.03, 0), Vector3(19, 0.06, 15), Color.WHITE)
	mat1.material_override = _mat_tex(TEX_GRASS_PARK, Color(0.85, 0.92, 0.72), Vector3(6, 5, 1))
	# Swing set: two A-frames + top bar + two swings
	for sx in [88.5, 96.5]:
		for sz in [-1.1, 1.1]:
			var leg := _cyl(world, Vector3(sx, 1.1, 23.5 + sz), 0.05, 0.05, 2.4, Color(0.35, 0.5, 0.65), true)
			leg.rotation_degrees = Vector3(sz * 18.0, 0, 0)
	_cyl(world, Vector3(92.5, 2.25, 23.5), 0.05, 0.05, 8.6, Color(0.35, 0.5, 0.65)).rotation_degrees = Vector3(0, 0, 90)
	for swx in [90.7, 94.3]:
		for chx in [-0.22, 0.22]:
			_cyl(world, Vector3(swx + chx, 1.55, 23.5), 0.015, 0.015, 1.35, Color(0.4, 0.4, 0.45))
		_box(world, Vector3(swx, 0.85, 23.5), Vector3(0.55, 0.07, 0.3), Color(0.85, 0.4, 0.3), true)
	content_points.append(Vector3(92.5, 0, 23.5))
	# Slide: steps up, a long chute down, side rails
	for sti in range(4):
		_box(world, Vector3(106.5, 0.25 + float(sti) * 0.42, 34.0 - float(sti) * 0.1), Vector3(1.1, 0.12, 0.7), Color(0.5, 0.55, 0.6), true)
	var chute := _box(world, Vector3(103.8, 1.05, 33.9), Vector3(4.6, 0.1, 0.85), Color(0.9, 0.55, 0.2), true)
	chute.rotation_degrees = Vector3(0, 0, 22)
	for rz in [-0.45, 0.45]:
		var rail := _box(world, Vector3(103.8, 1.3, 33.9 + rz), Vector3(4.6, 0.28, 0.06), Color(0.85, 0.45, 0.18))
		rail.rotation_degrees = Vector3(0, 0, 22)
	content_points.append(Vector3(104, 0, 34))
	# Sandbox with buckets
	for b_edge in [Vector4(89, 31.2, 4.6, 0.35), Vector4(89, 34.8, 4.6, 0.35), Vector4(86.9, 33.0, 0.35, 4.0), Vector4(91.1, 33.0, 0.35, 4.0)]:
		_box(world, Vector3(b_edge.x, 0.22, b_edge.y), Vector3(b_edge.z, 0.45, b_edge.w), Color(0.75, 0.6, 0.4), true)
	var sand := _box(world, Vector3(89, 0.12, 33.0), Vector3(4.2, 0.2, 3.6), Color(0.93, 0.85, 0.62))
	sand.material_override = _mat(Color(0.93, 0.85, 0.62), 1.0)
	_cyl(world, Vector3(88.2, 0.32, 32.3), 0.16, 0.12, 0.25, Color(0.9, 0.35, 0.3))
	_cyl(world, Vector3(90.1, 0.3, 33.9), 0.14, 0.1, 0.22, Color(0.3, 0.55, 0.85))
	content_points.append(Vector3(89, 0, 33))
	# Seesaw + merry-go-round
	_cyl(world, Vector3(104, 0.35, 26.5), 0.3, 0.35, 0.7, Color(0.5, 0.4, 0.3), true)
	var plank := _box(world, Vector3(104, 0.85, 26.5), Vector3(4.4, 0.09, 0.45), Color(0.85, 0.65, 0.25), true)
	plank.rotation_degrees = Vector3(0, 0, -9)
	for hx in [-1.9, 1.9]:
		_box(world, Vector3(104 + hx, 0.98 - (0.3 if hx < 0.0 else -0.3) * 0.5, 26.5), Vector3(0.3, 0.07, 0.4), Color(0.4, 0.4, 0.45))
	_cyl(world, Vector3(95, 0.3, 35.5), 1.5, 1.5, 0.18, Color(0.8, 0.4, 0.45), true)
	_cyl(world, Vector3(95, 0.75, 35.5), 0.06, 0.06, 0.8, Color(0.45, 0.45, 0.5))
	for ha in range(4):
		var hang: float = float(ha) * PI * 0.5
		_cyl(world, Vector3(95 + cos(hang) * 1.3, 0.85, 35.5 + sin(hang) * 1.3), 0.035, 0.035, 0.5, Color(0.45, 0.45, 0.5))
	content_points.append(Vector3(95, 0, 35.5))
	_label3d(world, "🛝 PLAYGROUND", Vector3(97, 3.4, 21.8), 52, Color(1.0, 0.95, 0.75))
	_cyl(world, Vector3(97, 1.6, 21.8), 0.06, 0.08, 3.2, Color(0.5, 0.42, 0.32), true)
	# ============ COMMUNITY GARDEN (south-west band) =================
	# Plots sit on the park-2 lawn's south edge, clear of its pond.
	for gx in [-114.0, -105.0, -96.0]:
		for gz in [82.0, 87.5]:
			var plot := _box(world, Vector3(gx, 0.14, gz), Vector3(7.5, 0.28, 4.6), Color(0.4, 0.3, 0.2), true)
			plot.material_override = _mat(Color(0.4, 0.3, 0.2), 1.0)
			for cx in range(-3, 4):
				_sphere(world, Vector3(gx + float(cx) * 0.95, 0.45, gz - 1.2), Vector3(0.34, 0.3, 0.34), Color(0.45, 0.72, 0.35))
				_sphere(world, Vector3(gx + float(cx) * 0.95, 0.42, gz + 0.9), Vector3(0.3, 0.26, 0.3), Color(0.55, 0.8, 0.4))
			_sphere(world, Vector3(gx + srng.randf_range(-2.5, 2.5), 0.4, gz + srng.randf_range(-1.5, 1.5)), Vector3(0.42, 0.36, 0.42), Color(0.95, 0.55, 0.15)) # pumpkin
			content_points.append(Vector3(gx, 0, gz))
	# Scarecrow watching over the plots
	_cyl(world, Vector3(-105, 1.0, 84.7), 0.06, 0.06, 2.0, Color(0.5, 0.4, 0.28), true)
	var cross := _cyl(world, Vector3(-105, 1.55, 84.7), 0.045, 0.045, 1.5, Color(0.5, 0.4, 0.28))
	cross.rotation_degrees = Vector3(0, 0, 90)
	_sphere(world, Vector3(-105, 2.2, 84.7), Vector3(0.3, 0.32, 0.3), Color(0.92, 0.8, 0.55))
	_cyl(world, Vector3(-105, 2.5, 84.7), 0.34, 0.36, 0.1, Color(0.85, 0.65, 0.25))
	_box(world, Vector3(-105, 1.15, 84.7), Vector3(0.55, 0.8, 0.25), Color(0.7, 0.3, 0.25))
	content_points.append(Vector3(-105, 0, 84.7))
	# Potting shed at the garden's east end
	_box(world, Vector3(-88, 1.1, 88.5), Vector3(3.4, 2.2, 2.8), Color(0.55, 0.42, 0.3), true)
	var shed_roof := _box(world, Vector3(-88, 2.4, 88.5), Vector3(3.8, 0.14, 3.2), Color(0.4, 0.35, 0.3))
	shed_roof.rotation_degrees = Vector3(4, 0, 0)
	_box(world, Vector3(-88, 1.05, 87.05), Vector3(0.9, 1.9, 0.08), Color(0.35, 0.27, 0.2))
	content_points.append(Vector3(-88, 0, 88.5))
	_label3d(world, "🌻 COMMUNITY GARDEN", Vector3(-105, 3.2, 79.3), 52, Color(1.0, 0.95, 0.75))
	_cyl(world, Vector3(-105, 1.5, 79.3), 0.06, 0.08, 3.0, Color(0.5, 0.42, 0.32), true)
	# ============ BUS STOP (Oak Ave, just east of Birch Lane) =======
	_cyl(world, Vector3(28.6, 1.25, 21.6), 0.06, 0.06, 2.5, Color(0.4, 0.45, 0.5), true)
	_cyl(world, Vector3(32.4, 1.25, 21.6), 0.06, 0.06, 2.5, Color(0.4, 0.45, 0.5), true)
	var bus_roof := _box(world, Vector3(30.5, 2.6, 21.2), Vector3(4.6, 0.12, 1.7), Color(0.3, 0.55, 0.6), true)
	bus_roof.rotation_degrees = Vector3(-6, 0, 0)
	_box(world, Vector3(30.5, 0.5, 21.7), Vector3(3.4, 0.1, 0.5), Color(0.6, 0.45, 0.3), true)
	_box(world, Vector3(30.5, 1.05, 21.95), Vector3(3.4, 0.55, 0.08), Color(0.6, 0.45, 0.3))
	_box(world, Vector3(28.6, 2.15, 20.6), Vector3(1.15, 0.62, 0.08), Color(0.15, 0.3, 0.55))
	_label3d_flat(world, "BUS STOP", Vector3(28.6, 2.15, 20.55), 64, Color.WHITE, 180.0, 0.005)
	_cyl(world, Vector3(33.3, 0.45, 20.9), 0.26, 0.22, 0.9, Color(0.3, 0.5, 0.35), true) # litter bin
	content_points.append(Vector3(30.5, 0, 21.4))
	# ============ LITTLE FREE LIBRARY (Maple St, west of Cedar) =====
	_cyl(world, Vector3(-44, 0.6, -17.5), 0.07, 0.07, 1.2, Color(0.5, 0.38, 0.25), true)
	_box(world, Vector3(-44, 1.5, -17.5), Vector3(0.85, 0.95, 0.5), Color(0.65, 0.3, 0.25), true)
	var lib_roof := _box(world, Vector3(-44, 2.1, -17.5), Vector3(1.05, 0.1, 0.68), Color(0.4, 0.3, 0.22))
	lib_roof.rotation_degrees = Vector3(8, 0, 0)
	_box(world, Vector3(-44, 1.52, -17.22), Vector3(0.62, 0.72, 0.05), Color(0.75, 0.85, 0.9), false, 0.3) # glass door
	for bk in range(3):
		_box(world, Vector3(-44 - 0.18 + float(bk) * 0.18, 1.38, -17.28), Vector3(0.11, 0.42, 0.03), [Color(0.85, 0.6, 0.2), Color(0.3, 0.55, 0.8), Color(0.5, 0.75, 0.4)][bk])
	_label3d(world, "📚 TAKE A BOOK", Vector3(-44, 2.6, -17.5), 40, Color(1.0, 0.95, 0.75))
	content_points.append(Vector3(-44, 0, -17.5))
	# ============ EXTRA BENCHES in the quiet bands ===================
	for bpos3 in [Vector3(60, 0, -20), Vector3(-90, 0, 10), Vector3(110, 0, -30), Vector3(-10, 0, 80), Vector3(58, 0, 82)]:
		_box(world, bpos3 + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
		_box(world, bpos3 + Vector3(0, 0.85, -0.24), Vector3(2.2, 0.5, 0.09), Color(0.55, 0.4, 0.25))
		_box(world, bpos3 + Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		_box(world, bpos3 + Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		content_points.append(bpos3)
	# ============ RIVERSIDE STRIP: benches facing the water =========
	for bx in [-100.0, -84.0, -56.0, -38.0, 8.0, 40.0, 58.0, 86.0, 104.0]:
		var rb := Vector3(bx, 0, -81)
		_box(world, rb + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
		_box(world, rb + Vector3(0, 0.85, 0.24), Vector3(2.2, 0.5, 0.09), Color(0.55, 0.4, 0.25))
		_box(world, rb + Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		_box(world, rb + Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		content_points.append(rb)
	for tx in [-92.0, -60.0, -46.0, 16.0, 48.0, 64.0, 96.0]:
		_build_tree(world, Vector3(tx, 0, -79))
	# ============ WEST ORCHARD (Pine St to the west fence) ==========
	for ot in [Vector3(-84, 0, -2), Vector3(-80, 0, 10), Vector3(-84, 0, 26), Vector3(-78, 0, 37)]:
		_build_tree(world, ot)
	_box(world, Vector3(-86, 0.45, 6), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
	_box(world, Vector3(-86, 0.22, 6), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	_box(world, Vector3(-85.2, 0.22, 6), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	content_points.append(Vector3(-86, 0, 6))
	# ============ EAST PICNIC GROVE (Riverside to the barriers) =====
	for pt in [Vector3(86, 0, -4), Vector3(96, 0, 7), Vector3(108, 0, -6), Vector3(90, 0, 8)]:
		_build_tree(world, pt)
	_box(world, Vector3(97, 0.75, -1), Vector3(2.4, 0.1, 1.1), Color(0.65, 0.5, 0.35), true) # picnic table top
	for pb in [-0.85, 0.85]:
		_box(world, Vector3(97, 0.45, -1 + pb), Vector3(2.4, 0.08, 0.35), Color(0.6, 0.46, 0.32), true)
		_box(world, Vector3(96.2, 0.35, -1 + pb * 0.4), Vector3(0.14, 0.7, 0.14), Color(0.45, 0.35, 0.25))
		_box(world, Vector3(97.8, 0.35, -1 + pb * 0.4), Vector3(0.14, 0.7, 0.14), Color(0.45, 0.35, 0.25))
	content_points.append(Vector3(97, 0, -1))
	# ============ LONE TREES in the last gaps ========================
	_build_tree(world, Vector3(-62, 0, 79)) # south-west park band
	_build_tree(world, Vector3(16, 0, 24)) # Oak/Willow mid-block, by the bus stop
	_build_tree(world, Vector3(20, 0, -4)) # Maple/Oak mid-block

# ================================================================ v1.0 town fill
func _fill_lamp(world: Node3D, pos: Vector3) -> void:
	_cyl(world, pos + Vector3(0, 2.2, 0), 0.07, 0.09, 4.4, Color(0.25, 0.27, 0.3), true)
	_sphere(world, pos + Vector3(0, 4.5, 0), Vector3(0.5, 0.5, 0.5), Color(1.0, 0.9, 0.6))
	content_points.append(pos)

func _fill_bench(world: Node3D, pos: Vector3, rot_deg: float = 0.0) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees = Vector3(0, rot_deg, 0)
	world.add_child(g)
	_box(g, Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
	_box(g, Vector3(0, 0.85, -0.24), Vector3(2.2, 0.5, 0.09), Color(0.55, 0.4, 0.25))
	_box(g, Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	_box(g, Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	content_points.append(pos)

func _fill_flowerbed(world: Node3D, pos: Vector3, w: float = 4.2) -> void:
	var soil := _box(world, pos + Vector3(0, 0.09, 0), Vector3(w, 0.18, 1.6), Color(0.4, 0.3, 0.2))
	soil.material_override = _mat(Color(0.4, 0.3, 0.2), 1.0)
	var fr := RandomNumberGenerator.new()
	fr.seed = absi(int(pos.x * 71.0 + pos.z * 113.0)) + 5
	for i in range(9):
		var fx: float = fr.randf_range(-w * 0.42, w * 0.42)
		var fz: float = fr.randf_range(-0.55, 0.55)
		_sphere(world, pos + Vector3(fx, 0.3, fz), Vector3(0.17, 0.17, 0.17), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.9, 0.9, 0.95), Color(0.85, 0.45, 0.75)][i % 4])
		_cyl(world, pos + Vector3(fx, 0.14, fz), 0.02, 0.02, 0.2, Color(0.35, 0.6, 0.3))
	content_points.append(pos)

func _fill_mailbox(world: Node3D, pos: Vector3) -> void:
	for i in range(3):
		var mx: float = pos.x - 0.55 + float(i) * 0.55
		_cyl(world, Vector3(mx, 0.45, pos.z), 0.045, 0.045, 0.9, Color(0.5, 0.42, 0.32), true)
		_box(world, Vector3(mx, 1.0, pos.z), Vector3(0.42, 0.3, 0.3), [Color(0.3, 0.45, 0.75), Color(0.75, 0.35, 0.3), Color(0.35, 0.6, 0.4)][i], true)
	content_points.append(pos)

func _fill_shed(world: Node3D, pos: Vector3, col: Color) -> void:
	_box(world, pos + Vector3(0, 1.05, 0), Vector3(3.4, 2.1, 2.6), col, true)
	var roof := _box(world, pos + Vector3(0, 2.25, 0), Vector3(3.8, 0.14, 3.0), Color(0.4, 0.35, 0.3))
	roof.rotation_degrees = Vector3(5, 0, 0)
	_box(world, pos + Vector3(0, 1.0, 1.32), Vector3(0.9, 1.85, 0.07), Color(0.35, 0.27, 0.2))
	_box(world, pos + Vector3(-1.1, 1.45, 1.32), Vector3(0.55, 0.55, 0.07), Color(0.8, 0.88, 0.92), false, 0.25)
	content_points.append(pos)

func _fill_fence_x(world: Node3D, x0: float, x1: float, z: float) -> void:
	var n: int = int((x1 - x0) / 2.0)
	for i in range(n + 1):
		_box(world, Vector3(x0 + float(i) * 2.0, 0.5, z), Vector3(0.16, 1.0, 0.16), Color(0.6, 0.48, 0.34), true)
	_box(world, Vector3((x0 + x1) * 0.5, 0.82, z), Vector3(x1 - x0, 0.1, 0.1), Color(0.6, 0.48, 0.34), true)
	_box(world, Vector3((x0 + x1) * 0.5, 0.42, z), Vector3(x1 - x0, 0.09, 0.09), Color(0.6, 0.48, 0.34), true)
	content_points.append(Vector3((x0 + x1) * 0.5, 0, z))

# A small non-residential building (shop / hall / apartment block).
# Front face is local +Z; rot_deg turns it. NOT a houses-array entry:
# no address, no door gameplay — pure built-environment content.
func _fill_building(world: Node3D, pos: Vector3, size: Vector3, wall: Color, roof_col: Color, sign_text: String, rot_deg: float, use_brick: bool = false) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees = Vector3(0, rot_deg, 0)
	world.add_child(g)
	var body := _box(g, Vector3(0, size.y * 0.5, 0), size, Color.WHITE, true)
	if use_brick:
		body.material_override = _mat_tex(TEX_BRICK, wall, Vector3(4, 3, 1))
	else:
		body.material_override = _mat_tex(TEX_SIDING, wall, Vector3(4, 2, 1))
	var roof := _box(g, Vector3(0, size.y + 0.18, 0), Vector3(size.x + 0.7, 0.36, size.z + 0.7), roof_col, true)
	roof.material_override = _mat_tex(TEX_ROOF, roof_col, Vector3(4, 1, 1))
	_box(g, Vector3(0, 1.05, size.z * 0.5 + 0.04), Vector3(1.1, 2.1, 0.09), Color(0.32, 0.24, 0.18)) # door
	_box(g, Vector3(0.42, 1.05, size.z * 0.5 + 0.1), Vector3(0.09, 0.09, 0.06), Color(0.9, 0.78, 0.3)) # knob
	var nw: int = int(size.x / 2.6)
	for wi in range(nw):
		var wx: float = -size.x * 0.5 + 1.5 + float(wi) * 2.6
		if absf(wx) < 1.1:
			continue # keep the doorway clear
		_box(g, Vector3(wx, size.y * 0.58, size.z * 0.5 + 0.03), Vector3(1.15, 1.0, 0.07), Color(0.98, 0.9, 0.62), false, 0.4)
		_box(g, Vector3(wx, size.y * 0.58, size.z * 0.5 + 0.06), Vector3(1.25, 0.09, 0.05), Color(0.45, 0.38, 0.3))
	if size.y > 5.5: # upper floor windows for the taller blocks
		for wi2 in range(nw):
			var wx2: float = -size.x * 0.5 + 1.5 + float(wi2) * 2.6
			_box(g, Vector3(wx2, size.y * 0.82, size.z * 0.5 + 0.03), Vector3(1.15, 1.0, 0.07), Color(0.9, 0.85, 0.6), false, 0.3)
	# hanging sign board on the front, text flat on both faces
	_box(g, Vector3(0, size.y - 0.55, size.z * 0.5 + 0.3), Vector3(minf(size.x * 0.72, 6.4), 0.95, 0.1), Color(0.2, 0.3, 0.42))
	var ps: float = clampf(0.089 / float(maxi(sign_text.length(), 1)), 0.004, 0.0085)
	_label3d_flat(g, sign_text, Vector3(0, size.y - 0.55, size.z * 0.5 + 0.36), 100, Color.WHITE, 0.0, ps)
	_label3d_flat(g, sign_text, Vector3(0, size.y - 0.55, size.z * 0.5 + 0.24), 100, Color.WHITE, 180.0, ps)
	content_points.append(pos)

func _fill_stall(world: Node3D, pos: Vector3, awning_col: Color) -> void:
	for px in [-1.3, 1.3]:
		for pz in [-0.8, 0.8]:
			_cyl(world, pos + Vector3(px, 1.05, pz), 0.05, 0.05, 2.1, Color(0.5, 0.4, 0.28), true)
	_box(world, pos + Vector3(0, 0.95, 0), Vector3(3.1, 0.12, 1.9), Color(0.65, 0.5, 0.35), true) # counter
	var awn := _box(world, pos + Vector3(0, 2.35, 0), Vector3(3.6, 0.09, 2.5), awning_col, false)
	awn.rotation_degrees = Vector3(-7, 0, 0)
	for ci in range(3):
		_box(world, pos + Vector3(-1.0 + float(ci) * 1.0, 1.25, 0.25), Vector3(0.55, 0.45, 0.55), Color(0.6, 0.45, 0.3), true) # crates
		_sphere(world, pos + Vector3(-1.0 + float(ci) * 1.0, 1.58, 0.25), Vector3(0.3, 0.24, 0.3), [Color(0.9, 0.4, 0.25), Color(0.95, 0.65, 0.2), Color(0.55, 0.8, 0.4)][ci])
	content_points.append(pos)

func _fill_parking(world: Node3D, pos: Vector3, w: float, d: float, car_cols: Array, car_type: String = "sedan") -> void:
	var pad := _box(world, pos + Vector3(0, 0.04, 0), Vector3(w, 0.07, d), Color.WHITE)
	pad.material_override = _mat_tex(TEX_ASPHALT, Color(0.92, 0.92, 0.95), Vector3(3, 2, 1), 0.97)
	for i in range(car_cols.size()):
		var cx: float = pos.x - w * 0.25 if car_cols.size() > 1 else pos.x
		if i == 1:
			cx = pos.x + w * 0.25
		_build_car(world, Vector3(cx, 0, pos.z), car_cols[i], true, car_type)
	content_points.append(pos)

func _build_town_fill(world: Node3D, srng: RandomNumberGenerator) -> void:
	# ============ RIVERSIDE PROMENADE (north band, behind the bench line)
	var path := _box(world, Vector3(0, 0.04, -85), Vector3(236, 0.08, 3.4), Color.WHITE)
	path.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(58, 1, 1))
	for lx in [-100.0, -60.0, -20.0, 20.0, 60.0, 100.0]:
		_fill_lamp(world, Vector3(lx, 0, -85))
	for fb in [Vector3(-80, 0, -88.5), Vector3(36, 0, -88.5), Vector3(80, 0, -88.5)]:
		_fill_flowerbed(world, fb, 5.0)
	_fill_building(world, Vector3(-30, 0, -86), Vector3(6.5, 3.4, 4.6), Color(0.96, 0.88, 0.74), Color(0.55, 0.38, 0.3), "RIVERSIDE CAFÉ", 0.0)
	_fill_bench(world, Vector3(-52, 0, -83), 180.0)
	_fill_bench(world, Vector3(44, 0, -83), 180.0)
	# ============ RIVERSIDE COURT apartments (NE corner block)
	_fill_building(world, Vector3(100, 0, -76), Vector3(13, 10.5, 10), Color(0.9, 0.82, 0.76), Color(0.45, 0.45, 0.52), "RIVERSIDE COURT", 0.0, true)
	_fill_parking(world, Vector3(84, 0, -75), 10.0, 7.0, [Color(0.35, 0.5, 0.8), Color(0.85, 0.6, 0.25)], "hatchback")
	_fill_lamp(world, Vector3(93, 0, -68))
	_build_tree(world, Vector3(110, 0, -84))
	# ============ ELM back gardens + front-gap clusters (north mid)
	_fill_shed(world, Vector3(-112, 0, -77), Color(0.45, 0.6, 0.45))
	_fill_shed(world, Vector3(-80, 0, -77), Color(0.6, 0.48, 0.36))
	_fill_shed(world, Vector3(-58, 0, -75), Color(0.5, 0.58, 0.68))
	_fill_shed(world, Vector3(20, 0, -76), Color(0.62, 0.5, 0.4))
	_fill_bench(world, Vector3(-26, 0, -74), 0.0)
	_fill_flowerbed(world, Vector3(-21, 0, -73), 3.6)
	_build_tree(world, Vector3(-31, 0, -77))
	_fill_bench(world, Vector3(26, 0, -73), 0.0)
	for fc in [Vector3(-26, 0, -60), Vector3(20, 0, -60)]:
		_fill_flowerbed(world, fc, 4.0)
		_fill_bench(world, fc + Vector3(3.6, 0, 0.6), 0.0)
		_fill_mailbox(world, fc + Vector3(-3.4, 0, 0.4))
		_fill_fence_x(world, fc.x - 5.0, fc.x + 5.0, fc.z - 2.6)
	# ============ MAPLE west shops + front gardens
	_fill_building(world, Vector3(-95, 0, -20), Vector3(6.5, 3.6, 5), Color(0.85, 0.9, 0.96), Color(0.4, 0.5, 0.65), "MAPLE MART", 0.0)
	_fill_mailbox(world, Vector3(-108, 0, -18))
	_fill_lamp(world, Vector3(-89, 0, -17))
	for fc2 in [Vector3(-60, 0, -20), Vector3(38, 0, -20)]:
		_fill_flowerbed(world, fc2, 4.0)
		_fill_bench(world, fc2 + Vector3(3.6, 0, 0.6), 0.0)
		_fill_fence_x(world, fc2.x - 5.0, fc2.x + 5.0, fc2.z - 2.6)
	# ============ OAK back gardens (Maple/Oak mid-block, west + centre)
	_fill_shed(world, Vector3(-27, 0, -4), Color(0.55, 0.62, 0.5))
	_fill_shed(world, Vector3(-60, 0, -4), Color(0.62, 0.52, 0.42))
	_fill_fence_x(world, -66.0, -54.0, -6.5)
	_fill_flowerbed(world, Vector3(-24, 0, -1), 3.4)
	# ============ WEST END shop + park-west entrance (Oak/Willow band, west)
	_fill_building(world, Vector3(-104, 0, 23), Vector3(7, 3.8, 5.5), Color(0.96, 0.9, 0.8), Color(0.6, 0.35, 0.3), "WEST END FOODS", 180.0)
	_fill_flowerbed(world, Vector3(-61, 0, 21), 3.4)
	_fill_flowerbed(world, Vector3(-61, 0, 27.5), 3.4)
	_fill_bench(world, Vector3(-58, 0, 24), 90.0)
	_fill_lamp(world, Vector3(-63, 0, 24))
	# ============ PLAYGROUND north-east corner: climbing frame
	for ax in [99.5, 104.5]:
		for az in [-0.9, 0.9]:
			var aleg := _cyl(world, Vector3(ax, 1.15, 24.5 + az), 0.05, 0.05, 2.5, Color(0.4, 0.55, 0.4), true)
			aleg.rotation_degrees = Vector3(az * 16.0, 0, 0)
	_cyl(world, Vector3(102, 2.35, 24.5), 0.05, 0.05, 5.6, Color(0.4, 0.55, 0.4)).rotation_degrees = Vector3(0, 0, 90)
	for rung in range(5):
		_cyl(world, Vector3(100.2 + float(rung) * 0.9, 1.5, 23.55), 0.025, 0.025, 1.7, Color(0.55, 0.6, 0.55))
	_fill_bench(world, Vector3(101, 0, 21.9), 0.0)
	_fill_lamp(world, Vector3(110, 0, 28))
	content_points.append(Vector3(102, 0, 24.5))
	# ============ RIVERSIDE corner shops + lot (Birch/Riverside, Maple/Oak)
	_fill_building(world, Vector3(62, 0, -4), Vector3(6, 3.6, 5), Color(0.97, 0.9, 0.78), Color(0.65, 0.4, 0.3), "BAKERY", 180.0)
	_fill_parking(world, Vector3(62, 0, 6.5), 9.0, 4.4, [Color(0.8, 0.3, 0.28)], "sedan")
	_fill_lamp(world, Vector3(66, 0, 2.5))
	# ============ MARKET ROW stalls (east of Riverside, Maple band)
	_fill_stall(world, Vector3(88, 0, -21), Color(0.85, 0.35, 0.3))
	_fill_stall(world, Vector3(97, 0, -21), Color(0.3, 0.6, 0.62))
	_fill_stall(world, Vector3(106, 0, -21), Color(0.9, 0.7, 0.25))
	_fill_lamp(world, Vector3(97, 0, -17.5))
	_fill_bench(world, Vector3(92, 0, -17.8), 180.0)
	# ============ WILLOW south band: hall, sheds, back fences, front clusters
	_fill_building(world, Vector3(30, 0, 79), Vector3(11, 5.5, 7), Color(0.88, 0.84, 0.78), Color(0.5, 0.42, 0.38), "WILLOW HALL", 180.0, true)
	_fill_parking(world, Vector3(17, 0, 79), 8.0, 6.0, [Color(0.4, 0.55, 0.45)], "van")
	_fill_shed(world, Vector3(-52, 0, 76), Color(0.5, 0.6, 0.48))
	_fill_shed(world, Vector3(-38, 0, 77), Color(0.6, 0.5, 0.38))
	_fill_shed(world, Vector3(48, 0, 76), Color(0.52, 0.58, 0.66))
	for seg in [[-84.0, -70.0], [-30.0, -16.0], [13.0, 27.0], [71.0, 85.0]]:
		_fill_fence_x(world, seg[0], seg[1], 73.0)
	for fc3 in [Vector3(-77, 0, 60.5), Vector3(-23, 0, 60.5), Vector3(20, 0, 60.5), Vector3(78, 0, 60.5)]:
		_fill_flowerbed(world, fc3, 4.0)
		_fill_bench(world, fc3 + Vector3(3.6, 0, 0.8), 180.0)
		_fill_mailbox(world, fc3 + Vector3(-3.4, 0, 0.6))
	_fill_bench(world, Vector3(84, 0, 74), 0.0)
	_fill_flowerbed(world, Vector3(88, 0, 73), 3.6)
	# ============ WILLOW GREEN pocket park (SE block): fountain + paths
	var fpath1 := _box(world, Vector3(100, 0.03, 76), Vector3(17, 0.06, 2.2), Color.WHITE)
	fpath1.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(5, 1, 1))
	var fpath2 := _box(world, Vector3(100, 0.03, 76), Vector3(2.2, 0.06, 17), Color.WHITE)
	fpath2.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(1, 5, 1))
	_cyl(world, Vector3(100, 0.35, 76), 2.3, 2.5, 0.7, Color(0.75, 0.72, 0.68), true)
	var fwater := _cyl(world, Vector3(100, 0.62, 76), 2.0, 2.0, 0.18, Color.WHITE)
	fwater.material_override = _mat_tex(TEX_WATER, Color.WHITE, Vector3(2, 2, 1), 0.3)
	_cyl(world, Vector3(100, 0.9, 76), 0.16, 0.22, 1.1, Color(0.7, 0.68, 0.64), true)
	_sphere(world, Vector3(100, 1.6, 76), Vector3(0.34, 0.34, 0.34), Color(0.8, 0.78, 0.74))
	content_points.append(Vector3(100, 0, 76))
	_fill_bench(world, Vector3(93, 0, 69), 0.0)
	_fill_bench(world, Vector3(107, 0, 83), 180.0)
	_fill_lamp(world, Vector3(100, 0, 67.5))
	_fill_flowerbed(world, Vector3(92, 0, 83), 4.0)
	_fill_flowerbed(world, Vector3(108, 0, 69), 4.0)
	_build_tree(world, Vector3(90, 0, 85))
	_build_tree(world, Vector3(110, 0, 85))
	# ============ PARK 2 centre cluster (SW park, between pond + gazebo)
	var bed := _cyl(world, Vector3(-83, 0.16, 73), 1.8, 1.8, 0.3, Color(0.4, 0.3, 0.2), true)
	bed.material_override = _mat(Color(0.4, 0.3, 0.2), 1.0)
	for fi in range(7):
		var fa: float = float(fi) * TAU / 7.0
		_sphere(world, Vector3(-83 + cos(fa) * 1.1, 0.42, 73 + sin(fa) * 1.1), Vector3(0.19, 0.19, 0.19), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.9, 0.9, 0.95)][fi % 3])
	content_points.append(Vector3(-83, 0, 73))
	_fill_bench(world, Vector3(-79, 0, 70), -90.0)
	_fill_lamp(world, Vector3(-87, 0, 70))
	# ============ LAST GAPS (audit pass 2): park interior + house-row side gaps
	_fill_bench(world, Vector3(-27, 0, 21), 0.0) # inside park 1, by the pond path
	_fill_flowerbed(world, Vector3(-33, 0, 29), 3.6)
	_fill_flowerbed(world, Vector3(-108, 0, 26.5), 3.6) # Oak-south west front gardens
	_fill_bench(world, Vector3(-93, 0, 26.5), 180.0)
	_fill_flowerbed(world, Vector3(-113, 0, -71), 3.4) # NW corner side garden
	_fill_bench(world, Vector3(-20, 0, -47), 0.0) # Elm-south back-garden gaps
	_fill_bench(world, Vector3(24, 0, -47), 0.0)
	_fill_mailbox(world, Vector3(8, 0, -61)) # Elm-north front gap
	_fill_mailbox(world, Vector3(20, 0, 49)) # Willow-north front gap
	# ============ STREET LAMP GRID: every street gets lamps along it
	for lp in [Vector3(-45, 0, -16.6), Vector3(5, 0, -16.6), Vector3(50, 0, -16.6), Vector3(95, 0, -16.6),
			Vector3(-8, 0, 20.6), Vector3(44, 0, 20.6), Vector3(96, 0, 20.6),
			Vector3(-40, 0, -49.6), Vector3(10, 0, -49.6), Vector3(58, 0, -49.6),
			Vector3(-40, 0, 60.6), Vector3(10, 0, 60.6), Vector3(58, 0, 60.6),
			Vector3(-64.6, 0, -30), Vector3(-64.6, 0, 30), Vector3(-14.6, 0, -30), Vector3(-14.6, 0, 32),
			Vector3(29.6, 0, -32), Vector3(29.6, 0, 28), Vector3(66.6, 0, -30), Vector3(66.6, 0, 30)]:
		_fill_lamp(world, lp)

func _sign(parent: Node, text: String, pos: Vector3, street: String = "", rot_deg: float = 0.0) -> void:
	if street != "":
		street_signs.append({"street": street, "text": text})
	# v0.7 REBUILT SIGNS: ONE clean board (the old stack of three
	# overlapping boards z-fought and its billboard text floated off
	# the board, readable from anywhere). The name is now printed ON
	# both faces with flat labels flush to the board — readable only
	# when you face that side, like a real street sign.
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees = Vector3(0, rot_deg, 0)
	parent.add_child(g)
	_cyl(g, Vector3(0, 1.9, 0), 0.07, 0.09, 3.8, Color(0.35, 0.35, 0.38), true)
	_box(g, Vector3(0, 3.75, 0), Vector3(5.4, 1.06, 0.14), Color(0.13, 0.34, 0.23))
	_sphere(g, Vector3(-2.45, 3.75, 0.09), Vector3(0.07, 0.07, 0.05), Color(0.8, 0.8, 0.78))
	_sphere(g, Vector3(2.45, 3.75, 0.09), Vector3(0.07, 0.07, 0.05), Color(0.8, 0.8, 0.78))
	var ps: float = clampf(0.089 / float(maxi(text.length(), 1)), 0.004, 0.0085)
	_label3d_flat(g, text, Vector3(0, 3.75, 0.078), 100, Color.WHITE, 0.0, ps)
	_label3d_flat(g, text, Vector3(0, 3.75, -0.078), 100, Color.WHITE, 180.0, ps)

func _build_house(parent: Node, h: Dictionary, wall_col: Color, roof_col: Color) -> void:
	content_points.append(h["pos"]) # v0.9 empty-area audit
	# v0.6 HOUSES WITH CHARACTER: every house is dressed by a
	# deterministic per-address RNG (seeded from the address string),
	# so the SAME house looks the SAME every run — a navigation
	# landmark while hunting a remembered address — but no two
	# houses share the same combination of roof pitch, porch style,
	# door colour, shutters, flowers, hedge, fence, mailbox, path,
	# yard prop and window glow.
	var p: Vector3 = h["pos"]
	var g := Node3D.new()
	g.position = p
	parent.add_child(g)
	var facing: float = float(h.get("facing", 1.0)) # door side (fronts its named street)
	var hr := RandomNumberGenerator.new()
	hr.seed = absi(str(h["address"]).hash()) * 7919 + 13
	var roof_angle: float = [30.0, 38.0, 46.0][hr.randi_range(0, 2)]
	var door_cols: Array = [Color(0.45, 0.3, 0.17), Color(0.55, 0.2, 0.18), Color(0.2, 0.38, 0.55), Color(0.25, 0.5, 0.3), Color(0.6, 0.45, 0.15), Color(0.35, 0.25, 0.45)]
	var door_col: Color = door_cols[hr.randi_range(0, door_cols.size() - 1)]
	var warm_glow: bool = hr.randf() < 0.5
	var glass_col := Color(0.98, 0.87, 0.58) if warm_glow else Color(0.72, 0.87, 0.95)
	var glass_em: float = 0.42 if warm_glow else 0.25
	# Walls + foundation
	var found := _box(g, Vector3(0, 0.15, 0), Vector3(8.6, 0.3, 7.6), Color.WHITE)
	found.material_override = _mat_tex(TEX_BRICK, Color(0.85, 0.8, 0.78), Vector3(5, 1, 1))
	var walls := _box(g, Vector3(0, 2.0, 0), Vector3(8.2, 3.7, 7.2), Color.WHITE, true)
	walls.material_override = _mat_tex(TEX_SIDING, wall_col.lightened(0.25), Vector3(5, 2, 1))
	_box(g, Vector3(0, 0.5, facing * 4.1), Vector3(4.5, 0.25, 1.6), Color(0.7, 0.6, 0.5), true) # porch step (v0.7: solid)
	# Pitched roof: two slanted slabs (pitch varies per house) + ridge
	var slab_y: float = 4.35 + (roof_angle - 30.0) * 0.03
	for s in [-1.0, 1.0]:
		var slab := _box(g, Vector3(s * 2.05, slab_y, 0), Vector3(5.4, 0.22, 8.2), Color.WHITE)
		slab.material_override = _mat_tex(TEX_ROOF, roof_col.lightened(0.3), Vector3(3, 5, 1))
		slab.rotation_degrees = Vector3(0, 0, s * -roof_angle)
	_box(g, Vector3(0, 5.15 + (roof_angle - 30.0) * 0.045, 0), Vector3(0.5, 0.3, 8.2), roof_col.darkened(0.15))
	# Chimney (70% of houses)
	if hr.randf() < 0.7:
		var chim := _box(g, Vector3(hr.randf_range(1.6, 3.0) * (1.0 if hr.randf() < 0.5 else -1.0), 5.2, -1.5), Vector3(0.9, 1.6, 0.9), Color.WHITE)
		chim.material_override = _mat_tex(TEX_BRICK, Color.WHITE, Vector3(1, 2, 1))
	# Dormer on the +X slope (40%)
	if hr.randf() < 0.4:
		_box(g, Vector3(3.35, 4.15, -0.8), Vector3(1.0, 1.05, 1.15), wall_col.lightened(0.3))
		_glass(g, Vector3(3.9, 4.15, -0.8), Vector3(0.1, 0.7, 0.8), glass_col, glass_em)
		var d_roof := _box(g, Vector3(3.45, 4.85, -0.8), Vector3(1.5, 0.14, 1.5), roof_col.darkened(0.1))
		d_roof.rotation_degrees = Vector3(0, 0, -18)
	# v0.9 BAY WINDOW (55% of houses): a real protruding bay with
	# three glass faces, its own little roof and a flower ledge —
	# houses gain a whole new read from the street.
	if hr.randf() < 0.55:
		var bay_x: float = -2.6 if hr.randf() < 0.5 else 2.6
		_box(g, Vector3(bay_x, 1.85, facing * 3.95), Vector3(2.0, 2.1, 0.75), wall_col.lightened(0.3), true)
		_glass(g, Vector3(bay_x, 1.95, facing * 4.36), Vector3(1.7, 1.5, 0.1), glass_col, glass_em)
		var bay_side1 := _glass(g, Vector3(bay_x - 0.98, 1.95, facing * 4.1), Vector3(0.1, 1.5, 0.6), glass_col, glass_em)
		bay_side1.rotation_degrees = Vector3(0, facing * 32.0, 0)
		var bay_side2 := _glass(g, Vector3(bay_x + 0.98, 1.95, facing * 4.1), Vector3(0.1, 1.5, 0.6), glass_col, glass_em)
		bay_side2.rotation_degrees = Vector3(0, facing * -32.0, 0)
		var bay_roof := _box(g, Vector3(bay_x, 3.05, facing * 4.0), Vector3(2.3, 0.14, 1.05), roof_col.darkened(0.1))
		bay_roof.rotation_degrees = Vector3(facing * 10.0, 0, 0)
		_box(g, Vector3(bay_x, 0.72, facing * 4.3), Vector3(1.9, 0.24, 0.34), Color(0.6, 0.35, 0.3)) # flower ledge
		_sphere(g, Vector3(bay_x - 0.45, 0.9, facing * 4.34), Vector3(0.2, 0.16, 0.16), Color(0.95, 0.45, 0.55))
		_sphere(g, Vector3(bay_x + 0.4, 0.92, facing * 4.34), Vector3(0.18, 0.15, 0.15), Color(0.98, 0.8, 0.3))
	# v0.9 GABLE TRIM: white fascia along both roof slopes at the
	# front + a round attic vent — the roofline reads "built", not
	# two slabs leaning together.
	for s2 in [-1.0, 1.0]:
		var fascia := _box(g, Vector3(s2 * 2.05, slab_y - 0.02, facing * 4.14), Vector3(5.5, 0.3, 0.12), Color(0.95, 0.94, 0.9))
		fascia.rotation_degrees = Vector3(0, 0, s2 * -roof_angle)
	var vent := _cyl(g, Vector3(0, 4.35, facing * 3.64), 0.34, 0.34, 0.1, Color(0.92, 0.9, 0.85))
	vent.rotation_degrees = Vector3(90, 0, 0)
	_cyl(g, Vector3(0, 4.35, facing * 3.7), 0.2, 0.2, 0.06, roof_col.darkened(0.2)).rotation_degrees = Vector3(90, 0, 0)
	# Door with frame + step light (door colour varies per house)
	_box(g, Vector3(0, 1.4, facing * 3.62), Vector3(1.6, 2.95, 0.16), Color(0.92, 0.9, 0.84)) # door frame
	_box(g, Vector3(0, 1.35, facing * 3.68), Vector3(1.3, 2.7, 0.18), door_col)
	_glass(g, Vector3(0, 2.25, facing * 3.78), Vector3(0.7, 0.6, 0.06), glass_col, glass_em) # door window
	_sphere(g, Vector3(0.45, 1.35, facing * 3.8), Vector3(0.12, 0.12, 0.08), Color(0.9, 0.75, 0.3))
	_sphere(g, Vector3(-0.85, 2.6, facing * 3.8), Vector3(0.16, 0.16, 0.1), Color(1.0, 0.9, 0.55)) # porch light
	# Porch style: 0 = posts + roof, 1 = step only, 2 = full-width porch
	var porch_style: int = hr.randi_range(0, 2)
	if porch_style == 0:
		_cyl(g, Vector3(-1.9, 1.3, facing * 4.3), 0.09, 0.09, 2.6, Color(0.85, 0.82, 0.78), true)
		_cyl(g, Vector3(1.9, 1.3, facing * 4.3), 0.09, 0.09, 2.6, Color(0.85, 0.82, 0.78), true)
		var porch_roof := _box(g, Vector3(0, 2.85, facing * 4.15), Vector3(4.6, 0.14, 1.9), roof_col.darkened(0.1))
		porch_roof.rotation_degrees = Vector3(facing * 12.0, 0, 0)
	elif porch_style == 2:
		for px3 in [-3.4, 3.4]:
			_cyl(g, Vector3(px3, 1.3, facing * 4.3), 0.09, 0.09, 2.6, Color(0.85, 0.82, 0.78), true)
		var wide_roof := _box(g, Vector3(0, 2.85, facing * 4.15), Vector3(7.6, 0.14, 1.9), roof_col.darkened(0.1))
		wide_roof.rotation_degrees = Vector3(facing * 12.0, 0, 0)
		_box(g, Vector3(0, 0.28, facing * 4.25), Vector3(7.6, 0.3, 1.7), Color(0.72, 0.62, 0.5), true) # porch deck (v0.7: solid)
		# v0.9 porch RAILING: top rail + balusters, with a gap at the
		# front step so the path still reads.
		for seg_c in [-2.35, 2.35]:
			_box(g, Vector3(seg_c, 1.0, facing * 5.02), Vector3(2.7, 0.09, 0.09), Color(0.88, 0.85, 0.8), true)
			for bx in range(-2, 3):
				_cyl(g, Vector3(seg_c + float(bx) * 0.55, 0.68, facing * 5.02), 0.035, 0.035, 0.62, Color(0.88, 0.85, 0.8))
	# Front windows: frames, mullions, glow (warm/cool), shutters (55%),
	# flower boxes (60%) or plain sills
	var has_shutters: bool = hr.randf() < 0.55
	var has_flowers: bool = hr.randf() < 0.6
	for wx in [-2.6, 2.6]:
		_box(g, Vector3(wx, 2.3, facing * 3.62), Vector3(1.75, 1.55, 0.13), Color(0.92, 0.9, 0.84)) # frame
		_glass(g, Vector3(wx, 2.3, facing * 3.68), Vector3(1.5, 1.3, 0.14), glass_col, glass_em)
		_box(g, Vector3(wx, 2.3, facing * 3.72), Vector3(0.09, 1.3, 0.1), Color(0.5, 0.4, 0.3)) # mullion V
		_box(g, Vector3(wx, 2.3, facing * 3.72), Vector3(1.5, 0.09, 0.1), Color(0.5, 0.4, 0.3)) # mullion H
		if has_shutters:
			_box(g, Vector3(wx - 1.05, 2.3, facing * 3.66), Vector3(0.32, 1.45, 0.08), roof_col.darkened(0.05))
			_box(g, Vector3(wx + 1.05, 2.3, facing * 3.66), Vector3(0.32, 1.45, 0.08), roof_col.darkened(0.05))
		if has_flowers:
			_box(g, Vector3(wx, 1.42, facing * 3.72), Vector3(1.6, 0.28, 0.3), Color(0.6, 0.35, 0.3)) # flower box
			_sphere(g, Vector3(wx - 0.4, 1.6, facing * 3.75), Vector3(0.22, 0.18, 0.18), Color(0.95, 0.45, 0.55))
			_sphere(g, Vector3(wx + 0.35, 1.62, facing * 3.75), Vector3(0.2, 0.16, 0.16), Color(0.98, 0.8, 0.3))
		else:
			_box(g, Vector3(wx, 1.45, facing * 3.7), Vector3(1.7, 0.12, 0.34), Color(0.88, 0.86, 0.82)) # plain sill
	for wz in [-1.8, 1.8]:
		_glass(g, Vector3(4.15, 2.3, wz), Vector3(0.14, 1.3, 1.5), glass_col, glass_em)
		_glass(g, Vector3(-4.15, 2.3, wz), Vector3(0.14, 1.3, 1.5), glass_col, glass_em)
	# v1.0 step 2 HOUSE DRESSING: white corner boards, a gutter
	# with a downspout on the front eave, and foundation shrubs —
	# the carpentry details that separate a house from a box with
	# a roof texture.
	for cx2 in [-4.02, 4.02]:
		for cz2 in [-3.52, 3.52]:
			_box(g, Vector3(cx2, 2.0, cz2), Vector3(0.2, 3.7, 0.2), Color(0.94, 0.93, 0.9))
	var gutter := _cyl(g, Vector3(0, 3.92, facing * 3.78), 0.07, 0.07, 8.3, Color(0.88, 0.87, 0.84))
	gutter.rotation_degrees = Vector3(0, 0, 90)
	_cyl(g, Vector3(3.95, 1.95, facing * 3.78), 0.05, 0.05, 3.9, Color(0.88, 0.87, 0.84)) # downspout
	for shx in [-3.3, 3.3]:
		var shrub := _sphere(g, Vector3(shx, 0.42, facing * 3.95), Vector3(0.85, 0.62, 0.6), Color.WHITE)
		shrub.material_override = _mat_tex(TEX_FOLIAGE, Color(0.8, 0.95, 0.75), Vector3(2, 2, 2))
	# Address sign + brass number plaque (IDENTICAL system on every house:
	# this is how you find home)
	_box(g, Vector3(0, 3.35, facing * 3.78), Vector3(5.6, 1.05, 0.1), Color(0.93, 0.92, 0.88))
	_box(g, Vector3(0, 3.35, facing * 3.84), Vector3(5.4, 0.92, 0.1), Color(0.1, 0.1, 0.14))
	var addr_rot: float = 0.0 if facing > 0.0 else 180.0
	var addr_ps: float = clampf(4.9 / (0.55 * float(h["address"].length()) * 88.0), 0.0035, 0.006)
	_label3d_flat(g, h["address"], Vector3(0, 3.35, facing * 3.92), 88, Color(1.0, 0.95, 0.6), addr_rot, addr_ps)
	_box(g, Vector3(1.15, 1.7, facing * 3.72), Vector3(0.85, 0.55, 0.08), Color(0.75, 0.6, 0.25))
	_label3d_flat(g, h["address"].split(" ")[0], Vector3(1.15, 1.7, facing * 3.78), 72, Color(0.15, 0.12, 0.05), addr_rot, 0.005)
	h["plaque"] = h["address"].split(" ")[0] # the number on the plaque == the address number
	# Path: 0 = slab, 1 = stepping stones
	if hr.randi_range(0, 1) == 0:
		_box(g, Vector3(0, 0.05, facing * 5.6), Vector3(1.6, 0.08, 2.4), Color(0.85, 0.83, 0.76))
	else:
		for stp in [4.9, 5.9, 6.9]:
			_box(g, Vector3(0, 0.05, facing * stp), Vector3(0.95, 0.08, 0.7), Color(0.82, 0.8, 0.74))
	# Mailbox: 0 = red post box, 1 = black wall box by the door, 2 = none
	var mb_style: int = hr.randi_range(0, 2)
	if mb_style == 0:
		_cyl(g, Vector3(2.8, 0.5, facing * 6.4), 0.05, 0.05, 1.0, Color(0.4, 0.35, 0.3), true)
		_box(g, Vector3(2.8, 1.1, facing * 6.4), Vector3(0.7, 0.45, 0.5), Color(0.6, 0.25, 0.22))
	elif mb_style == 1:
		_box(g, Vector3(-1.25, 1.5, facing * 3.74), Vector3(0.6, 0.42, 0.22), Color(0.16, 0.16, 0.18))
	# Front hedge (45%)
	if hr.randf() < 0.45:
		for hx3 in [-2.9, 2.9]:
			var hg := _box(g, Vector3(hx3, 0.35, facing * 5.4), Vector3(3.2, 0.7, 0.5), Color.WHITE, true)
			hg.material_override = _mat_tex(TEX_FOLIAGE, Color(0.85, 0.98, 0.82), Vector3(2, 1, 1))
	# Side picket fences (40%)
	if hr.randf() < 0.4:
		for sx5 in [-5.6, 5.6]:
			for pz3 in [3.4, 4.3, 5.2, 6.1, 7.0]:
				_box(g, Vector3(sx5, 0.45, facing * pz3), Vector3(0.14, 0.9, 0.3), Color(0.94, 0.93, 0.9), true)
			_box(g, Vector3(sx5, 0.62, facing * 5.2), Vector3(0.08, 0.1, 3.9), Color(0.94, 0.93, 0.9), true)
	# One yard prop: birdbath / bench / bike / mini tree / bush cluster
	var prop_x: float = [-3.2, 3.4, -1.7][hr.randi_range(0, 2)]
	var prop_z: float = facing * 5.9
	match hr.randi_range(0, 5):
		1: # birdbath
			_cyl(g, Vector3(prop_x, 0.45, prop_z), 0.09, 0.16, 0.9, Color(0.85, 0.84, 0.8), true)
			_cyl(g, Vector3(prop_x, 0.95, prop_z), 0.5, 0.35, 0.18, Color(0.88, 0.87, 0.83))
		2: # bench
			_box(g, Vector3(prop_x, 0.5, prop_z), Vector3(1.7, 0.1, 0.5), Color(0.6, 0.45, 0.3), true)
			_box(g, Vector3(prop_x, 0.95, prop_z - facing * 0.22), Vector3(1.7, 0.7, 0.09), Color(0.6, 0.45, 0.3))
			_box(g, Vector3(prop_x - 0.7, 0.25, prop_z), Vector3(0.12, 0.5, 0.45), Color(0.45, 0.33, 0.22))
			_box(g, Vector3(prop_x + 0.7, 0.25, prop_z), Vector3(0.12, 0.5, 0.45), Color(0.45, 0.33, 0.22))
		3: # bike (simple: two wheel discs + frame bars)
			for bwx in [-0.55, 0.55]:
				var bwheel := _cyl(g, Vector3(prop_x + bwx, 0.42, prop_z), 0.42, 0.42, 0.06, Color(0.15, 0.15, 0.16))
				bwheel.rotation_degrees = Vector3(90, 0, 0)
			var bframe := _box(g, Vector3(prop_x, 0.62, prop_z), Vector3(1.15, 0.09, 0.09), Color(0.75, 0.3, 0.25))
			bframe.rotation_degrees = Vector3(0, 0, -8)
			_box(g, Vector3(prop_x + 0.5, 0.95, prop_z), Vector3(0.4, 0.07, 0.3), Color(0.3, 0.25, 0.2))
		4: # mini tree
			var mt := Node3D.new()
			mt.position = Vector3(prop_x, 0, prop_z)
			mt.scale = Vector3(0.62, 0.62, 0.62)
			g.add_child(mt)
			_build_tree(mt, Vector3.ZERO, false)
		5: # bush cluster
			_sphere(g, Vector3(prop_x, 0.45, prop_z), Vector3(1.1, 0.85, 1.1), Color(0.45, 0.68, 0.38))
			_sphere(g, Vector3(prop_x + 0.7, 0.35, prop_z + 0.3), Vector3(0.8, 0.65, 0.8), Color(0.52, 0.74, 0.42))
func _build_tree(parent: Node, pos: Vector3, track: bool = true) -> void:
	if track:
		content_points.append(pos) # v0.9 empty-area audit
	# v0.7 TREES THAT LOOK LIKE TREES (Michael: v0.6 was "a brown
	# thing" — a cylinder with three smooth balls). Now: a tapered
	# trunk with angled branches and an IRREGULAR layered canopy of
	# many jittered blobs in varied greens. Three types by position
	# seed: 0 round leafy, 1 pine, 2 blossom-birch (pale bark).
	var tr := RandomNumberGenerator.new()
	tr.seed = absi(int(pos.x * 131.0 + pos.z * 197.0)) + 7
	var ttype: int = tr.randi_range(0, 2)
	if ttype == 1:
		_build_pine(parent, pos, tr.randf_range(0.95, 1.25))
		return
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	var bark := Color(0.5, 0.36, 0.22) if ttype == 0 else Color(0.85, 0.82, 0.76)
	var trunk := _cyl(g, Vector3(0, 1.25, 0), 0.13, 0.3, 2.5, Color.WHITE, true)
	trunk.material_override = _mat_tex(TEX_BARK, bark, Vector3(1, 2, 1)) # v0.8: real bark grain, not floor planks
	for bi in range(5): # v0.9: five real branches reaching into the canopy
		var ang: float = float(bi) * 1.26 + tr.randf_range(-0.3, 0.3)
		var br := _cyl(g, Vector3(cos(ang) * 0.42, 2.62, sin(ang) * 0.42), 0.045, 0.09, 1.3, Color.WHITE)
		br.material_override = _mat_tex(TEX_BARK, bark, Vector3(1, 1, 1))
		br.rotation_degrees = Vector3(sin(ang) * 38.0, 0, -cos(ang) * 38.0)
	# v1.0 step 2: root flare — three buttress roots gripping the
	# ground, so the trunk PLANTS instead of poking out of the lawn.
	for ri in range(3):
		var ra: float = float(ri) * 2.1 + tr.randf_range(-0.3, 0.3)
		var root := _cyl(g, Vector3(cos(ra) * 0.3, 0.22, sin(ra) * 0.3), 0.03, 0.11, 0.55, Color.WHITE)
		root.material_override = _mat_tex(TEX_BARK, bark, Vector3(1, 1, 1))
		root.rotation_degrees = Vector3(sin(ra) * 32.0, 0, -cos(ra) * 32.0)
	var greens: Array = [Color(0.62, 0.85, 0.55), Color(0.5, 0.78, 0.45), Color(0.72, 0.92, 0.6), Color(0.42, 0.7, 0.4)]
	var pinks: Array = [Color(0.98, 0.82, 0.86), Color(0.95, 0.75, 0.82), Color(0.9, 0.88, 0.7), Color(0.98, 0.88, 0.9)]
	# v1.0 step 2 CANOPY REBUILD: many SMALLER puffs (finer grain —
	# big smooth blobs were the "lollipop" read), over a DARK
	# interior core so the canopy has real depth: dark inside,
	# mid-tones at the surface, bright crown on top, like light
	# falling into leaves.
	for ci2 in range(6):
		var ca2: float = tr.randf_range(0.0, TAU)
		var core := _sphere(g, Vector3(cos(ca2) * 0.45, 3.35 + tr.randf_range(-0.3, 0.3), sin(ca2) * 0.45), Vector3(0.95, 0.8, 0.95), Color.WHITE)
		var dc: Color = (greens if ttype == 0 else pinks)[tr.randi_range(0, 3)].darkened(0.45)
		core.material_override = _mat_tex(TEX_FOLIAGE, dc, Vector3(2, 2, 2))
	for bi2 in range(27):
		var a2: float = tr.randf_range(0.0, TAU)
		var r2: float = tr.randf_range(0.0, 1.35)
		var bp := Vector3(cos(a2) * r2, 3.3 + tr.randf_range(-0.55, 0.85), sin(a2) * r2)
		if bi2 == 0:
			bp = Vector3(0, 3.55, 0)
		var bs: float = tr.randf_range(0.55, 1.05)
		var blob := _sphere(g, bp, Vector3(bs, bs * tr.randf_range(0.75, 0.95), bs), Color.WHITE)
		var cc: Color = (greens if ttype == 0 else pinks)[tr.randi_range(0, 3)]
		blob.material_override = _mat_tex(TEX_FOLIAGE, cc, Vector3(2, 2, 2))
	# v0.9 crown highlights: smaller, brighter puffs on top where the
	# sun catches — gives the canopy a lit, three-dimensional top.
	var hi_col: Color = Color(0.85, 0.98, 0.68) if ttype == 0 else Color(1.0, 0.92, 0.94)
	for hi in range(6):
		var ha: float = tr.randf_range(0.0, TAU)
		var hb := _sphere(g, Vector3(cos(ha) * tr.randf_range(0.2, 0.8), 4.15 + tr.randf_range(-0.15, 0.3), sin(ha) * tr.randf_range(0.2, 0.8)), Vector3(0.62, 0.5, 0.62), Color.WHITE)
		hb.material_override = _mat_tex(TEX_FOLIAGE, hi_col, Vector3(2, 2, 2))
	if ttype == 0 and tr.randf() < 0.6:
		for ap in [Vector3(0.8, 2.9, 0.7), Vector3(-0.7, 3.4, 0.5), Vector3(0.1, 2.6, -0.9), Vector3(-0.3, 3.1, 0.9)]:
			_sphere(g, ap, Vector3(0.15, 0.15, 0.15), Color(0.88, 0.25, 0.2)) # apples

func _build_bush(parent: Node, pos: Vector3) -> void:
	content_points.append(pos) # v0.9 empty-area audit
	# v0.7: an irregular cluster of six jittered blobs in varied
	# greens (never smooth balls), some with berries/flowers.
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	var br := RandomNumberGenerator.new()
	br.seed = absi(int(pos.x * 57.0 + pos.z * 91.0)) + 11
	var greens: Array = [Color(0.55, 0.8, 0.48), Color(0.45, 0.72, 0.42), Color(0.66, 0.88, 0.55), Color(0.5, 0.76, 0.44), Color(0.6, 0.84, 0.5), Color(0.47, 0.74, 0.43)]
	for bi in range(6):
		var bp := Vector3(br.randf_range(-0.55, 0.55), 0.42 + br.randf_range(-0.1, 0.25), br.randf_range(-0.55, 0.55))
		if bi == 0:
			bp = Vector3(0, 0.55, 0)
		var bs: float = br.randf_range(0.7, 1.15)
		var blob := _sphere(g, bp, Vector3(bs, bs * 0.78, bs), Color.WHITE)
		blob.material_override = _mat_tex(TEX_FOLIAGE, greens[bi], Vector3(2, 2, 2))
	if br.randf() < 0.5:
		for fi in range(4):
			_sphere(g, Vector3(br.randf_range(-0.7, 0.7), br.randf_range(0.5, 0.95), br.randf_range(-0.7, 0.7)), Vector3(0.09, 0.09, 0.09), Color(0.95, 0.45, 0.55) if fi % 2 == 0 else Color(0.98, 0.85, 0.4))

func _build_car(parent: Node, pos: Vector3, col: Color, along_x: bool, car_type: String = "sedan", for_traffic: bool = false) -> Node3D:
	if not for_traffic:
		content_points.append(pos) # v0.9 empty-area audit
	# v0.6 VARIED CARS: five silhouettes — sedan, hatchback, pickup,
	# van, convertible — each in several colours. All are solid
	# obstacles and hiding spots ("hide ⛺"), as before.
	var g := Node3D.new()
	g.name = "Car" # PERF: named so the clutter-range pass can skip car subtrees (a car must never lose parts at range)
	g.position = pos
	if not along_x:
		g.rotation_degrees = Vector3(0, 90, 0)
	parent.add_child(g)
	var glass := Color(0.2, 0.26, 0.33)
	match car_type:
		"hatchback":
			var hb := _box(g, Vector3(0, 0.55, 0), Vector3(3.4, 0.72, 1.8), col, true)
			hb.material_override = _paint(col)
			var hc := _box(g, Vector3(-0.25, 1.18, 0), Vector3(1.95, 0.62, 1.62), glass)
			hc.material_override = _car_glass()
			var hback := _box(g, Vector3(-1.28, 1.1, 0), Vector3(0.5, 0.75, 1.6), glass)
			hback.rotation_degrees = Vector3(0, 0, 24)
			hback.material_override = _car_glass()
			_car_wheels(g, 2.35)
		"pickup":
			var pb := _box(g, Vector3(0, 0.55, 0), Vector3(4.2, 0.7, 1.85), col, true)
			pb.material_override = _paint(col)
			var pc := _box(g, Vector3(1.15, 1.22, 0), Vector3(1.5, 0.72, 1.7), col)
			pc.material_override = _paint(col)
			var pw := _box(g, Vector3(1.2, 1.3, 0), Vector3(1.2, 0.5, 1.74), glass)
			pw.material_override = _car_glass()
			for bz4 in [-0.86, 0.86]: # open bed walls
				_box(g, Vector3(-1.05, 1.05, bz4), Vector3(2.0, 0.42, 0.1), col.darkened(0.12))
			_box(g, Vector3(-2.05, 1.05, 0), Vector3(0.1, 0.42, 1.8), col.darkened(0.12))
			_car_wheels(g, 3.1)
		"van":
			var vb := _box(g, Vector3(0, 1.05, 0), Vector3(4.3, 1.85, 1.9), col, true)
			vb.material_override = _paint(col)
			var vw := _box(g, Vector3(1.95, 1.45, 0), Vector3(0.5, 0.7, 1.7), glass)
			vw.rotation_degrees = Vector3(0, 0, -14)
			vw.material_override = _car_glass()
			_box(g, Vector3(0.2, 1.15, 0.97), Vector3(2.2, 0.9, 0.04), glass.darkened(0.1)) # side windows band
			_box(g, Vector3(0.2, 1.15, -0.97), Vector3(2.2, 0.9, 0.04), glass.darkened(0.1))
			_box(g, Vector3(-0.9, 0.75, 0.97), Vector3(0.06, 0.5, 0.5), Color(0.3, 0.3, 0.33)) # sliding door rail detail
			_car_wheels(g, 3.2)
		"convertible":
			var cb := _box(g, Vector3(0, 0.48, 0), Vector3(3.8, 0.58, 1.75), col, true)
			cb.material_override = _paint(col)
			_box(g, Vector3(-0.15, 0.82, 0), Vector3(1.9, 0.16, 1.5), Color(0.16, 0.14, 0.13)) # open cockpit
			for sz in [-0.42, 0.42]:
				_box(g, Vector3(0.35, 0.88, sz), Vector3(0.5, 0.3, 0.55), Color(0.85, 0.8, 0.7)) # seats
			var cws := _box(g, Vector3(1.15, 0.95, 0), Vector3(0.06, 0.5, 1.5), glass)
			cws.rotation_degrees = Vector3(0, 0, -18)
			cws.material_override = _car_glass()
			_box(g, Vector3(-1.55, 0.8, 0), Vector3(0.7, 0.22, 1.4), col.darkened(0.15)) # folded top
			_car_wheels(g, 2.6)
		_: # sedan (the v0.5 design)
			var sb := _box(g, Vector3(0, 0.55, 0), Vector3(3.9, 0.75, 1.8), col, true)
			sb.material_override = _paint(col)
			var sc2 := _box(g, Vector3(-0.2, 1.2, 0), Vector3(2.0, 0.65, 1.6), glass)
			sc2.material_override = _car_glass()
			_car_wheels(g, 2.5)
	# v0.9: PAIRED headlights + taillights, bumpers and a grille —
	# v0.8 had a single light blob floating on each end.
	for lz in [-0.55, 0.55]:
		_box(g, Vector3(1.99, 0.62, lz), Vector3(0.08, 0.2, 0.42), Color(1, 0.95, 0.7), false, 0.8)
		_box(g, Vector3(-1.99, 0.62, lz), Vector3(0.08, 0.2, 0.42), Color(0.9, 0.2, 0.15), false, 0.6)
	_box(g, Vector3(2.0, 0.32, 0), Vector3(0.18, 0.24, 1.86), Color(0.22, 0.22, 0.25)) # front bumper
	_box(g, Vector3(-2.0, 0.32, 0), Vector3(0.18, 0.24, 1.86), Color(0.22, 0.22, 0.25)) # rear bumper
	_box(g, Vector3(2.02, 0.58, 0), Vector3(0.05, 0.26, 0.9), Color(0.3, 0.3, 0.34)) # grille
	_cyl(g, Vector3(-1.7, 0.18, -0.5), 0.05, 0.05, 0.22, Color(0.55, 0.56, 0.6)).rotation_degrees = Vector3(0, 0, 90) # exhaust
	_box(g, Vector3(0.95, 1.02, 0.99), Vector3(0.16, 0.09, 0.12), col.darkened(0.15)) # mirror R (v0.7 detail)
	_box(g, Vector3(0.95, 1.02, -0.99), Vector3(0.16, 0.09, 0.12), col.darkened(0.15)) # mirror L
	# v0.8 car surface detail: door seams + handles + sill line on both flanks
	for fz2 in [0.915, -0.915]:
		_box(g, Vector3(0.1, 0.62, fz2), Vector3(0.03, 0.62, 0.02), col.darkened(0.28))
		_box(g, Vector3(0.42, 0.82, fz2), Vector3(0.3, 0.05, 0.03), Color(0.25, 0.25, 0.28))
		_box(g, Vector3(-0.5, 0.82, fz2), Vector3(0.3, 0.05, 0.03), Color(0.25, 0.25, 0.28))
		_box(g, Vector3(0.0, 0.3, fz2), Vector3(3.1, 0.05, 0.02), col.darkened(0.2))
	_box(g, Vector3(-2.0, 0.55, 0), Vector3(0.04, 0.24, 0.7), Color(0.95, 0.95, 0.92)) # rear plate
	if not for_traffic:
		_label3d(g, "hide ⛺", Vector3(0, 2.1, 0), 40, Color(1, 1, 1, 0.85))
	return g

func _car_wheels(g: Node, span: float) -> void:
	for wx in [-span * 0.5, span * 0.5]:
		for wz in [-0.82, 0.82]:
			var wheel := _cyl(g, Vector3(wx, 0.32, wz), 0.32, 0.32, 0.18, Color(0.1, 0.1, 0.11))
			wheel.rotation_degrees = Vector3(90, 0, 0)
			var hub := _cyl(g, Vector3(wx, 0.32, wz + (0.1 if wz > 0.0 else -0.1)), 0.15, 0.15, 0.03, Color(0.62, 0.64, 0.68)) # v0.8 hubcap
			hub.rotation_degrees = Vector3(90, 0, 0)
			hub.material_override = _mat(Color(0.62, 0.64, 0.68), 0.3, 0.0) # v1.0 step 2: polished hub metal
			hub.material_override.metallic = 0.75
			# v0.9: dark wheel-arch trim over every wheel
			_box(g, Vector3(wx, 0.68, wz + (0.06 if wz > 0.0 else -0.06)), Vector3(0.78, 0.14, 0.1), Color(0.16, 0.16, 0.18))

func _build_pine(parent: Node, pos: Vector3, s: float = 1.0) -> void:
	# v0.7: FOUR ragged, slightly offset tiers over a tapered trunk —
	# reads as a pine from across the map, not a green cone lollipop.
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	var pr := RandomNumberGenerator.new()
	pr.seed = absi(int(pos.x * 71.0 + pos.z * 113.0)) + 3
	var ptrunk := _cyl(g, Vector3(0, 0.9 * s, 0), 0.13 * s, 0.22 * s, 1.8 * s, Color.WHITE, true)
	ptrunk.material_override = _mat_tex(TEX_BARK, Color(0.55, 0.42, 0.3), Vector3(1, 2, 1))
	var tiers: Array = [[2.0, 1.75], [3.1, 1.35], [4.15, 0.95], [5.1, 0.55]]
	for ti in range(tiers.size()):
		var tc := _cyl(g, Vector3(pr.randf_range(-0.09, 0.09) * s, tiers[ti][0] * s, pr.randf_range(-0.09, 0.09) * s), 0.12 * s, tiers[ti][1] * s, 1.9 * s, Color.WHITE)
		tc.material_override = _mat_tex(TEX_FOLIAGE, Color(0.5 + 0.07 * float(ti), 0.72 + 0.05 * float(ti), 0.46), Vector3(2, 2, 2))

# ---------------------------------------------------------------- escape room (3D interior at x≈200)
func _build_escape_room() -> void:
	var room := Node3D.new()
	room.name = "EscapeRoom"
	add_child(room)
	var o: Vector3 = escape_origin
	# --- Floor: textured wood planks + patterned rug with fringe ---
	var floor_mi := _box(room, o + Vector3(0, -0.1, 0), Vector3(28, 0.3, 20), Color.WHITE)
	floor_mi.material_override = _mat_tex(TEX_WOOD, Color(1.05, 0.98, 0.9), Vector3(9, 7, 1))
	var rug := _box(room, o + Vector3(0, 0.06, 3), Vector3(9, 0.06, 6), Color.WHITE)
	rug.material_override = _mat_tex(TEX_RUG, Color.WHITE, Vector3(1, 1, 1))
	for fx in range(-4, 5):
		_box(room, o + Vector3(float(fx), 0.07, 6.25), Vector3(0.09, 0.03, 0.5), Color(0.92, 0.88, 0.8))
		_box(room, o + Vector3(float(fx), 0.07, -0.25), Vector3(0.09, 0.03, 0.5), Color(0.92, 0.88, 0.8))
	# --- Walls: wallpaper above, wood wainscot + baseboards below ---
	# v1.2: the SOUTH and WEST walls are still single slabs. The NORTH
	# and EAST walls are built from SEGMENTS with real gaps at the
	# window, the pet door and the back-door doorway — the player now
	# WALKS the cat out himself, so the openings must be physical.
	# While an exit is closed its gap is plugged by an invisible
	# blocker (window_blocker / petdoor_blocker) or by the solid back
	# door panel itself; _open_exit removes the plug. Wallpaper repeat
	# scales with each segment's length so the pattern density matches
	# the old full walls.
	var wall_s := _box(room, o + Vector3(0, 2, 10), Vector3(28, 4, 0.5), Color.WHITE, true)
	wall_s.material_override = _mat_tex(TEX_WALLPAPER, Color.WHITE, Vector3(10, 2, 1))
	var wains_s := _box(room, o + Vector3(0, 0.55, 9.6), Vector3(28, 1.1, 0.18), Color.WHITE)
	wains_s.material_override = _mat_tex(TEX_WOOD, Color(0.78, 0.62, 0.45), Vector3(12, 1, 1))
	var wall_w := _box(room, o + Vector3(-14, 2, 0), Vector3(0.5, 4, 20), Color.WHITE, true)
	wall_w.material_override = _mat_tex(TEX_WALLPAPER, Color.WHITE, Vector3(7, 2, 1))
	var wains_w := _box(room, o + Vector3(-13.72, 0.55, 0), Vector3(0.18, 1.1, 20), Color.WHITE)
	wains_w.material_override = _mat_tex(TEX_WOOD, Color(0.78, 0.62, 0.45), Vector3(8, 1, 1))
	# North wall (z = -10): segments are [x-centre, width, y-centre, height].
	# Window gap x -2.9..2.9, y 0.72..3.68 — pet-door gap x 4.85..7.15, y 0..1.58.
	for seg in [[-8.45, 11.1, 2.0, 4.0], [3.875, 1.95, 2.0, 4.0], [10.575, 6.85, 2.0, 4.0], [0.0, 5.8, 0.36, 0.72], [0.0, 5.8, 3.84, 0.32], [6.0, 2.3, 2.79, 2.42]]:
		var nseg := _box(room, o + Vector3(float(seg[0]), float(seg[2]), -10), Vector3(float(seg[1]), float(seg[3]), 0.5), Color.WHITE, true)
		nseg.material_override = _mat_tex(TEX_WALLPAPER, Color.WHITE, Vector3(float(seg[1]) / 2.8, 2, 1))
	# East wall (x = 14): segments are [z-centre, length, y-centre, height].
	# Back-door doorway gap z 2.28..4.52, y 0..3.02 (plugged by the door).
	for seg2 in [[-3.86, 12.28, 2.0, 4.0], [7.26, 5.48, 2.0, 4.0], [3.4, 2.24, 3.51, 0.98]]:
		var eseg := _box(room, o + Vector3(14, float(seg2[2]), float(seg2[0])), Vector3(0.5, float(seg2[3]), float(seg2[1])), Color.WHITE, true)
		eseg.material_override = _mat_tex(TEX_WALLPAPER, Color.WHITE, Vector3(float(seg2[1]) / 2.857, 2, 1))
	# Wainscot: north in two pieces (gap at the pet door so the cat
	# doesn't clip through it walking out), east likewise at the door.
	for wseg in [[-4.6, 18.8], [10.6, 6.8]]:
		var wn := _box(room, o + Vector3(float(wseg[0]), 0.55, -9.6), Vector3(float(wseg[1]), 1.1, 0.18), Color.WHITE)
		wn.material_override = _mat_tex(TEX_WOOD, Color(0.78, 0.62, 0.45), Vector3(float(wseg[1]) / 2.33, 1, 1))
	for wseg2 in [[-3.86, 12.28], [7.26, 5.48]]:
		var we := _box(room, o + Vector3(13.72, 0.55, float(wseg2[0])), Vector3(0.18, 1.1, float(wseg2[1])), Color.WHITE)
		we.material_override = _mat_tex(TEX_WOOD, Color(0.78, 0.62, 0.45), Vector3(float(wseg2[1]) / 2.5, 1, 1))
	# Invisible plugs for the two north gaps (toggled by _open_exit /
	# _reset_escape_props). The shape child is named "CS" for toggling.
	window_blocker = _make_blocker(room, o + Vector3(0, 2.2, -10), Vector3(5.8, 2.96, 0.5))
	petdoor_blocker = _make_blocker(room, o + Vector3(6, 0.79, -10), Vector3(2.3, 1.58, 0.5))
	# Ceiling beams (dark wood)
	for bx in [-9.0, 0.0, 9.0]:
		var beam := _box(room, o + Vector3(bx, 3.92, 0), Vector3(0.5, 0.22, 20), Color.WHITE)
		beam.material_override = _mat_tex(TEX_WOOD, Color(0.5, 0.36, 0.22), Vector3(1, 6, 1))
	room_title_label = _label3d(room, "💛 A cozy cat-lover's home — find a way out!", o + Vector3(0, 3.4, -9.4), 64, Color(0.35, 0.22, 0.14))
	# Warm interior lighting: ceiling pendant + floor lamp glow
	var pendant := OmniLight3D.new()
	pendant.position = o + Vector3(0, 3.2, 1)
	pendant.light_color = Color(1.0, 0.85, 0.62)
	pendant.light_energy = 0.85
	pendant.omni_range = 19.0
	room.add_child(pendant)
	_cyl(room, o + Vector3(0, 3.75, 1), 0.03, 0.03, 0.5, Color(0.3, 0.28, 0.26))
	_sphere(room, o + Vector3(0, 3.45, 1), Vector3(0.55, 0.4, 0.55), Color(1.0, 0.9, 0.65))
	var lamp_light := OmniLight3D.new()
	lamp_light.position = o + Vector3(12, 2.6, -7)
	lamp_light.light_color = Color(1.0, 0.8, 0.55)
	lamp_light.light_energy = 0.5
	lamp_light.omni_range = 9.0
	room.add_child(lamp_light)
	# ============ BOOKCASE (step 1) — real detailed bookcase ============
	var shelf_pos := o + Vector3(-11, 0, -8)
	var case := _box(room, shelf_pos + Vector3(0, 1.5, -0.25), Vector3(5.4, 3.2, 0.5), Color.WHITE, true)
	case.material_override = _mat_tex(TEX_WOOD, Color(0.66, 0.48, 0.3), Vector3(3, 2, 1))
	for sx2 in [-2.55, 2.55]:
		var side := _box(room, shelf_pos + Vector3(sx2, 1.5, 0.15), Vector3(0.28, 3.2, 0.9), Color.WHITE)
		side.material_override = _mat_tex(TEX_WOOD, Color(0.6, 0.43, 0.27), Vector3(1, 2, 1))
	var top_board := _box(room, shelf_pos + Vector3(0, 3.18, 0.15), Vector3(5.5, 0.24, 1.0), Color.WHITE)
	top_board.material_override = _mat_tex(TEX_WOOD, Color(0.6, 0.43, 0.27), Vector3(3, 1, 1))
	var book_cols: Array = [Color(0.8, 0.25, 0.25), Color(0.25, 0.45, 0.8), Color(0.3, 0.65, 0.35), Color(0.85, 0.65, 0.2), Color(0.6, 0.35, 0.75), Color(0.9, 0.55, 0.3), Color(0.3, 0.6, 0.65), Color(0.75, 0.4, 0.5)]
	for shelf_i in range(3):
		var sy: float = 0.55 + float(shelf_i) * 0.95
		var board := _box(room, shelf_pos + Vector3(0, sy - 0.28, 0.15), Vector3(5.2, 0.12, 0.9), Color.WHITE)
		board.material_override = _mat_tex(TEX_WOOD, Color(0.6, 0.43, 0.27), Vector3(3, 1, 1))
		var bx2: float = -2.25
		var bi: int = 0
		while bx2 < 2.1:
			if shelf_i == 2 and bx2 > 0.0 and bx2 < 1.3:
				bx2 += 0.42 # leave the gap where the puzzle book sits (top shelf)
				continue
			var bw: float = 0.26 + fmod(abs(sin(float(shelf_i * 17 + bi * 7))) * 0.5, 0.2)
			var bh: float = 0.62 + fmod(abs(cos(float(bi * 5 + shelf_i * 3))) * 0.6, 0.3)
			var bk := _box(room, shelf_pos + Vector3(bx2 + bw * 0.5, sy + bh * 0.5 - 0.22, 0.3), Vector3(bw, bh, 0.5), book_cols[(bi + shelf_i * 3) % book_cols.size()])
			if bi % 7 == 4:
				bk.rotation_degrees = Vector3(0, 0, -9) # one leaning book per row
			_box(room, shelf_pos + Vector3(bx2 + bw * 0.5, sy + bh - 0.3, 0.57), Vector3(bw * 0.9, 0.07, 0.03), Color(0.95, 0.9, 0.75)) # page block line
			bx2 += bw + 0.035
			bi += 1
		# a horizontal stack at the end of two shelves
		if shelf_i < 2:
			for st in range(3):
				_box(room, shelf_pos + Vector3(2.0, sy + 0.02 + float(st) * 0.15, 0.3), Vector3(0.62, 0.13, 0.48), book_cols[(shelf_i + st + 2) % book_cols.size()])
	# The puzzle book: BIG, red, gold-banded — must read clearly
	book_node = _box(room, shelf_pos + Vector3(0.6, 2.2, 0.6), Vector3(0.6, 1.0, 0.4), Color(0.88, 0.16, 0.16))
	book_home_pos = book_node.position
	_box(book_node, Vector3(0, 0.28, 0.21), Vector3(0.62, 0.1, 0.02), Color(0.95, 0.78, 0.3))
	_box(book_node, Vector3(0, -0.28, 0.21), Vector3(0.62, 0.1, 0.02), Color(0.95, 0.78, 0.3))
	# Plant + framed photo on top of the bookcase
	_cyl(room, shelf_pos + Vector3(-2.0, 3.45, 0.15), 0.22, 0.17, 0.35, Color(0.75, 0.4, 0.3))
	var case_plant := _sphere(room, shelf_pos + Vector3(-2.0, 3.85, 0.15), Vector3(0.55, 0.5, 0.55), Color.WHITE)
	case_plant.material_override = _mat_tex(TEX_FOLIAGE, Color.WHITE, Vector3(1, 1, 1))
	_box(room, shelf_pos + Vector3(2.0, 3.55, 0.1), Vector3(0.7, 0.55, 0.08), Color(0.5, 0.35, 0.2))
	_sphere(room, shelf_pos + Vector3(2.0, 3.58, 0.16), Vector3(0.2, 0.18, 0.04), Color(0.94, 0.55, 0.16)) # tiny cat portrait head
	# ============ SOFA (step 2) — cushions, pillows, throw ============
	var sofa_pos := o + Vector3(0, 0, 4.5)
	var sofa_base := _box(room, sofa_pos + Vector3(0, 0.55, 0), Vector3(6.5, 1.1, 2.2), Color.WHITE, true)
	sofa_base.material_override = _mat_tex(TEX_SOFA, Color.WHITE, Vector3(4, 1, 1))
	for cx in [-2.05, 0.0, 2.05]:
		var seat := _box(room, sofa_pos + Vector3(cx, 1.06, 0.25), Vector3(1.95, 0.28, 1.7), Color.WHITE)
		seat.material_override = _mat_tex(TEX_SOFA, Color(1.12, 1.12, 1.15), Vector3(1, 1, 1))
		var back_c := _sphere(room, sofa_pos + Vector3(cx, 1.62, -0.78), Vector3(2.0, 1.05, 0.55), Color.WHITE)
		back_c.material_override = _mat_tex(TEX_SOFA, Color(1.05, 1.05, 1.1), Vector3(1, 1, 1))
	_box(room, sofa_pos + Vector3(-3.1, 1.0, 0), Vector3(0.5, 1.6, 2.2), Color(0.4, 0.5, 0.8))
	_box(room, sofa_pos + Vector3(3.1, 1.0, 0), Vector3(0.5, 1.6, 2.2), Color(0.4, 0.5, 0.8))
	var pillow1 := _box(room, sofa_pos + Vector3(-2.3, 1.45, -0.45), Vector3(0.85, 0.85, 0.3), Color(0.92, 0.62, 0.25))
	pillow1.rotation_degrees = Vector3(-12, 0, 10)
	var pillow2 := _box(room, sofa_pos + Vector3(2.4, 1.45, -0.45), Vector3(0.85, 0.85, 0.3), Color(0.85, 0.4, 0.45))
	pillow2.rotation_degrees = Vector3(-12, 0, -8)
	var throw := _box(room, sofa_pos + Vector3(3.05, 1.55, 0.5), Vector3(0.6, 1.15, 1.6), Color(0.9, 0.8, 0.55))
	throw.rotation_degrees = Vector3(0, 0, 6)
	# Coffee table on the rug: books, mug, remote
	_box(room, o + Vector3(0, 0.42, 1.2), Vector3(3.4, 0.16, 1.6), Color(0.62, 0.45, 0.3))
	for cx2 in [-1.45, 1.45]:
		for cz2 in [-0.6, 0.6]:
			_cyl(room, o + Vector3(cx2, 0.2, 1.2 + cz2), 0.07, 0.07, 0.4, Color(0.5, 0.36, 0.22))
	_box(room, o + Vector3(-0.9, 0.58, 1.1), Vector3(0.7, 0.14, 0.5), Color(0.3, 0.5, 0.75))
	_box(room, o + Vector3(-0.88, 0.71, 1.12), Vector3(0.6, 0.12, 0.44), Color(0.8, 0.35, 0.3))
	_cyl(room, o + Vector3(0.7, 0.62, 1.4), 0.11, 0.09, 0.24, Color(0.92, 0.55, 0.3)) # mug
	_box(room, o + Vector3(1.2, 0.53, 1.0), Vector3(0.42, 0.05, 0.14), Color(0.15, 0.15, 0.17)) # remote
	# Armchair + side table + reading lamp (corner)
	var chair := _box(room, o + Vector3(9.5, 0.55, 7.5), Vector3(2.4, 1.1, 2.2), Color.WHITE)
	chair.material_override = _mat_tex(TEX_SOFA, Color(1.25, 0.95, 0.85), Vector3(2, 1, 1))
	chair.rotation_degrees = Vector3(0, -35, 0)
	_box(room, o + Vector3(12.3, 0.5, 4.6), Vector3(1.1, 1.0, 1.1), Color(0.6, 0.44, 0.29))
	_cyl(room, o + Vector3(12.3, 1.35, 4.6), 0.05, 0.07, 0.7, Color(0.35, 0.33, 0.3))
	_sphere(room, o + Vector3(12.3, 1.85, 4.6), Vector3(0.5, 0.42, 0.5), Color(1.0, 0.88, 0.6))
	# ============ WINDOW — REAL window (v0.6 rework) ============
	# Proper frame + sill, two sashes with muntin grids, believable
	# glass (transparent, slight blue, reflective sheen) over a bright
	# "outside" backdrop (sky, sun, hills, clouds), curtains, and a
	# REAL brass latch: a base plate + a lever on a pivot that the
	# player flips from the escape panel (v1.1). The lower sash
	# (sash_node) physically slides up when the window is pushed open.
	var win_pos := o + Vector3(0, 2.2, -9.6)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.8, 0.92, 1.0, 0.2)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.06
	glass_mat.metallic = 0.0
	var sheen_mat := StandardMaterial3D.new()
	sheen_mat.albedo_color = Color(1, 1, 1, 0.1)
	sheen_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# "Outside": bright sky panel + sun + hills + clouds behind the glass
	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.albedo_color = Color(0.32, 0.58, 0.92)
	var sky_panel := _box(room, win_pos + Vector3(0, 0, -0.22), Vector3(5.2, 2.9, 0.06), Color.WHITE)
	sky_panel.material_override = sky_mat
	_sphere(room, win_pos + Vector3(1.55, 0.78, -0.17), Vector3(0.46, 0.46, 0.1), Color(1.0, 0.93, 0.55))
	_sphere(room, win_pos + Vector3(-2.6, -1.15, -0.16), Vector3(2.6, 1.1, 0.1), Color(0.3, 0.58, 0.3))
	_sphere(room, win_pos + Vector3(2.7, -1.25, -0.16), Vector3(2.8, 1.0, 0.1), Color(0.36, 0.64, 0.34))
	_sphere(room, win_pos + Vector3(-1.5, 0.85, -0.16), Vector3(0.85, 0.3, 0.08), Color(1, 1, 1))
	_sphere(room, win_pos + Vector3(0.6, 1.0, -0.16), Vector3(0.65, 0.24, 0.08), Color(1, 1, 1))
	# Outer frame (4 chunky painted boards) + sloped sill + apron
	_box(room, win_pos + Vector3(0, 1.44, 0.02), Vector3(5.5, 0.34, 0.34), Color(0.96, 0.94, 0.9))
	_box(room, win_pos + Vector3(0, -1.44, 0.02), Vector3(5.5, 0.34, 0.34), Color(0.96, 0.94, 0.9))
	_box(room, win_pos + Vector3(-2.62, 0, 0.02), Vector3(0.34, 3.2, 0.34), Color(0.96, 0.94, 0.9))
	_box(room, win_pos + Vector3(2.62, 0, 0.02), Vector3(0.34, 3.2, 0.34), Color(0.96, 0.94, 0.9))
	var sill := _box(room, win_pos + Vector3(0, -1.66, 0.22), Vector3(5.9, 0.16, 0.66), Color(0.96, 0.94, 0.9))
	sill.rotation_degrees = Vector3(7, 0, 0)
	_box(room, win_pos + Vector3(0, -1.78, 0.05), Vector3(5.5, 0.14, 0.2), Color(0.9, 0.87, 0.82))
	# Upper sash (fixed): glass + muntins
	var up_glass := _box(room, win_pos + Vector3(0, 0.73, 0), Vector3(4.85, 1.3, 0.05), Color.WHITE)
	up_glass.material_override = glass_mat
	_box(room, win_pos + Vector3(0, 0.73, 0.05), Vector3(0.09, 1.3, 0.06), Color(0.96, 0.94, 0.9))
	_box(room, win_pos + Vector3(0, 0.73, 0.05), Vector3(4.85, 0.09, 0.06), Color(0.96, 0.94, 0.9))
	_box(room, win_pos + Vector3(0, 1.36, 0.03), Vector3(4.95, 0.15, 0.1), Color(0.96, 0.94, 0.9))
	var up_sheen := _box(room, win_pos + Vector3(-1.3, 0.73, 0.06), Vector3(0.45, 1.25, 0.02), Color.WHITE)
	up_sheen.material_override = sheen_mat
	up_sheen.rotation_degrees = Vector3(0, 0, 18)
	# Lower sash (sash_node): slides UP when pushed open
	sash_node = Node3D.new()
	sash_node.position = win_pos + Vector3(0, -0.7, 0.07)
	room.add_child(sash_node)
	sash_base_y = sash_node.position.y
	var lo_glass := _box(sash_node, Vector3(0, 0, 0), Vector3(4.85, 1.28, 0.05), Color.WHITE)
	lo_glass.material_override = glass_mat
	_box(sash_node, Vector3(0, 0.66, 0.02), Vector3(4.95, 0.17, 0.1), Color(0.96, 0.94, 0.9)) # meeting rail (top)
	_box(sash_node, Vector3(0, -0.66, 0.02), Vector3(4.95, 0.15, 0.1), Color(0.96, 0.94, 0.9))
	_box(sash_node, Vector3(-2.44, 0, 0.02), Vector3(0.15, 1.4, 0.1), Color(0.96, 0.94, 0.9))
	_box(sash_node, Vector3(2.44, 0, 0.02), Vector3(0.15, 1.4, 0.1), Color(0.96, 0.94, 0.9))
	_box(sash_node, Vector3(0, 0, 0.05), Vector3(0.09, 1.28, 0.06), Color(0.96, 0.94, 0.9))
	_box(sash_node, Vector3(0, 0, 0.05), Vector3(4.85, 0.09, 0.06), Color(0.96, 0.94, 0.9))
	var lo_sheen := _box(sash_node, Vector3(1.2, 0, 0.06), Vector3(0.45, 1.2, 0.02), Color.WHITE)
	lo_sheen.material_override = sheen_mat
	lo_sheen.rotation_degrees = Vector3(0, 0, 18)
	# THE LATCH: base plate + keeper + lever on a pivot (flips up when
	# swiped open). Sits on the meeting rail, right of centre.
	_box(room, win_pos + Vector3(0.8, 0.14, 0.14), Vector3(0.32, 0.15, 0.09), Color(0.45, 0.36, 0.18)) # keeper (upper rail)
	latch_pivot = Node3D.new()
	latch_pivot.position = win_pos + Vector3(0.8, -0.06, 0.16)
	room.add_child(latch_pivot)
	latch_base_pos = latch_pivot.position
	var latch_plate := _box(latch_pivot, Vector3(0, 0, 0), Vector3(0.36, 0.19, 0.07), Color(0.5, 0.4, 0.2))
	latch_plate.material_override = _mat(Color(0.5, 0.4, 0.2), 0.35)
	latch_node = _box(latch_pivot, Vector3(-0.24, 0, 0.07), Vector3(0.56, 0.11, 0.09), Color(0.78, 0.62, 0.26))
	latch_node.material_override = _mat(Color(0.78, 0.62, 0.26), 0.3)
	_sphere(latch_pivot, Vector3(-0.52, 0, 0.07), Vector3(0.1, 0.1, 0.1), Color(0.85, 0.68, 0.3)) # lever knob
	_sphere(latch_pivot, Vector3(0, 0, 0.08), Vector3(0.07, 0.07, 0.07), Color(0.35, 0.28, 0.14)) # pivot screw
	# Curtains + rod + sill plant (kept, repositioned to the new frame)
	for cx3 in [-3.05, 3.05]:
		for pleat in range(4):
			_box(room, win_pos + Vector3(cx3 + (float(pleat) - 1.5) * 0.24, -0.1, 0.32), Vector3(0.2, 3.0, 0.16), Color(0.82, 0.5, 0.42) if pleat % 2 == 0 else Color(0.74, 0.44, 0.38))
	var rod := _cyl(room, win_pos + Vector3(0, 1.68, 0.32), 0.045, 0.045, 7.2, Color(0.55, 0.42, 0.25))
	rod.rotation_degrees = Vector3(0, 0, 90)
	_cyl(room, win_pos + Vector3(-1.7, -1.5, 0.3), 0.16, 0.12, 0.26, Color(0.75, 0.4, 0.3)) # sill plant pot
	var sill_plant := _sphere(room, win_pos + Vector3(-1.7, -1.22, 0.3), Vector3(0.4, 0.36, 0.4), Color.WHITE)
	sill_plant.material_override = _mat_tex(TEX_FOLIAGE, Color.WHITE, Vector3(1, 1, 1))
	_label3d(room, "Window", win_pos + Vector3(0, 1.95, 0), 56, Color(0.2, 0.3, 0.4))
	# Pet door with frame + a REAL swinging FLAP (flap_node pivots at
	# its top edge; pushing swipes swing it open). v1.1: the frame is
	# a real 4-piece border around a dark opening (it was one solid
	# slab with the flap embedded in it), so the flap reads clearly
	# and the cat can be SEEN slipping through in the escape moment.
	_box(room, o + Vector3(6, 0.74, -9.74), Vector3(1.9, 1.38, 0.05), Color(0.05, 0.05, 0.08)) # dark opening
	_box(room, o + Vector3(6, 1.495, -9.68), Vector3(2.1, 0.16, 0.3), Color(0.96, 0.94, 0.9)) # frame top
	_box(room, o + Vector3(6, -0.005, -9.68), Vector3(2.1, 0.14, 0.3), Color(0.96, 0.94, 0.9)) # frame threshold
	_box(room, o + Vector3(4.975, 0.74, -9.68), Vector3(0.15, 1.35, 0.3), Color(0.96, 0.94, 0.9)) # frame L
	_box(room, o + Vector3(7.025, 0.74, -9.68), Vector3(0.15, 1.35, 0.3), Color(0.96, 0.94, 0.9)) # frame R
	flap_node = Node3D.new()
	flap_node.position = o + Vector3(6, 1.42, -9.60)
	room.add_child(flap_node)
	var flap_mat := StandardMaterial3D.new()
	flap_mat.albedo_color = Color(0.35, 0.8, 0.5, 0.78)
	flap_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flap_mat.emission_enabled = true
	flap_mat.emission = Color(0.2, 0.5, 0.3)
	flap_mat.emission_energy_multiplier = 0.35
	var flap := _box(flap_node, Vector3(0, -0.68, 0), Vector3(1.7, 1.36, 0.1), Color.WHITE)
	flap.material_override = flap_mat
	_box(flap_node, Vector3(0, -0.06, 0.03), Vector3(1.78, 0.12, 0.06), Color(0.85, 0.83, 0.78)) # flap hinge bar
	_label3d(room, "Pet door", o + Vector3(6, 1.95, -9.5), 48, Color(0.2, 0.45, 0.25))
	# ============ KITCHEN corner (east wall) ============
	var counter := _box(room, o + Vector3(12.9, 0.95, -4.5), Vector3(1.9, 0.14, 8.5), Color(0.88, 0.85, 0.8), true)
	counter.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(1, 4, 1))
	var cabbody := _box(room, o + Vector3(13.1, 0.45, -4.5), Vector3(1.6, 0.85, 8.5), Color.WHITE)
	cabbody.material_override = _mat_tex(TEX_WOOD, Color(0.82, 0.68, 0.5), Vector3(4, 1, 1))
	for hx in range(4):
		_box(room, o + Vector3(12.25, 0.62, -7.6 + float(hx) * 2.05), Vector3(0.06, 0.08, 0.7), Color(0.4, 0.38, 0.36)) # cabinet handles
	_box(room, o + Vector3(12.85, 1.06, -7.2), Vector3(1.5, 0.08, 2.2), Color(0.16, 0.16, 0.18)) # stove top
	for bx2 in [-0.45, 0.45]:
		for bz2 in [-0.6, 0.6]:
			_cyl(room, o + Vector3(12.85 + bx2, 1.12, -7.2 + bz2), 0.26, 0.26, 0.04, Color(0.3, 0.3, 0.34))
	_sphere(room, o + Vector3(12.7, 1.3, -5.2), Vector3(0.34, 0.3, 0.34), Color(0.82, 0.84, 0.88)) # kettle
	_cyl(room, o + Vector3(12.7, 1.58, -5.2), 0.05, 0.08, 0.14, Color(0.6, 0.62, 0.66))
	_box(room, o + Vector3(13.2, 1.75, 0.5), Vector3(1.5, 3.5, 2.2), Color(0.88, 0.9, 0.93), true) # fridge
	_box(room, o + Vector3(12.4, 2.2, 0.5), Vector3(0.06, 0.8, 0.1), Color(0.5, 0.52, 0.56)) # fridge handle
	_box(room, o + Vector3(12.44, 2.85, 0.5), Vector3(0.04, 0.5, 0.7), Color(0.95, 0.75, 0.3)) # fridge note
	_cyl(room, o + Vector3(12.8, 1.1, -2.2), 0.5, 0.4, 0.18, Color(0.8, 0.5, 0.3)) # fruit bowl
	for fr in [Vector3(12.6, 1.28, -2.4), Vector3(13.0, 1.28, -2.1), Vector3(12.8, 1.3, -2.25)]:
		_sphere(room, o + fr, Vector3(0.17, 0.17, 0.17), Color(0.95, 0.6, 0.2))
	# Wall cabinets + hanging pans
	var wallcab := _box(room, o + Vector3(13.3, 2.9, -5.5), Vector3(1.1, 1.3, 5.5), Color.WHITE)
	wallcab.material_override = _mat_tex(TEX_WOOD, Color(0.82, 0.68, 0.5), Vector3(3, 1, 1))
	for px in range(3):
		_cyl(room, o + Vector3(12.6, 2.0 - float(px) * 0.05, -3.4 - float(px) * 0.8), 0.26, 0.26, 0.07, Color(0.35, 0.36, 0.4))
	# ============ Personal touches ============
	# Fireplace (south wall) with mantel, photo frames, warm glow
	_box(room, o + Vector3(-7, 0.9, 9.55), Vector3(3.6, 1.8, 0.7), Color(0.62, 0.35, 0.28))
	_box(room, o + Vector3(-7, 0.75, 9.2), Vector3(2.2, 1.3, 0.3), Color(0.14, 0.1, 0.09))
	_box(room, o + Vector3(-7, 0.55, 9.05), Vector3(1.7, 0.8, 0.2), Color(1.0, 0.55, 0.18), false, 0.9) # fire glow
	_box(room, o + Vector3(-7, 1.95, 9.5), Vector3(4.1, 0.18, 0.85), Color(0.55, 0.4, 0.26)) # mantel
	_box(room, o + Vector3(-8.2, 2.35, 9.45), Vector3(0.65, 0.5, 0.08), Color(0.5, 0.35, 0.2))
	_sphere(room, o + Vector3(-8.2, 2.38, 9.5), Vector3(0.18, 0.16, 0.04), Color(0.94, 0.55, 0.16))
	_cyl(room, o + Vector3(-5.9, 2.3, 9.45), 0.05, 0.07, 0.4, Color(0.92, 0.88, 0.8)) # candle
	# Picture frames on west wall: big cat portrait + landscapes
	_box(room, o + Vector3(-13.65, 2.3, 1.5), Vector3(0.14, 1.7, 2.1), Color(0.5, 0.35, 0.2))
	_box(room, o + Vector3(-13.55, 2.3, 1.5), Vector3(0.1, 1.45, 1.85), Color(0.96, 0.9, 0.78))
	_sphere(room, o + Vector3(-13.45, 2.25, 1.5), Vector3(0.08, 0.62, 0.62), Color(0.94, 0.55, 0.16)) # portrait cat head (flat)
	for sx4 in [-0.28, 0.28]:
		_box(room, o + Vector3(-13.45, 2.95, 1.5 + sx4), Vector3(0.06, 0.3, 0.16), Color(0.94, 0.55, 0.16))
	_sphere(room, o + Vector3(-13.42, 2.32, 1.32), Vector3(0.05, 0.11, 0.11), Color(0.2, 0.6, 0.25))
	_sphere(room, o + Vector3(-13.42, 2.32, 1.68), Vector3(0.05, 0.11, 0.11), Color(0.2, 0.6, 0.25))
	for pz in [-3.5, 5.5]:
		_box(room, o + Vector3(-13.65, 2.4, pz), Vector3(0.14, 1.0, 1.4), Color(0.45, 0.32, 0.2))
		_box(room, o + Vector3(-13.55, 2.4, pz), Vector3(0.1, 0.8, 1.2), Color(0.65, 0.78, 0.9) if pz < 0 else Color(0.6, 0.8, 0.55))
	# Wall clock (north wall, east side)
	var clock_face := _cyl(room, o + Vector3(9, 3.0, -9.65), 0.55, 0.55, 0.1, Color(0.97, 0.95, 0.9))
	clock_face.rotation_degrees = Vector3(90, 0, 0)
	var hand1 := _box(room, o + Vector3(9, 3.12, -9.55), Vector3(0.06, 0.4, 0.04), Color(0.15, 0.15, 0.17))
	hand1.rotation_degrees = Vector3(0, 0, 25)
	# Cat tree, cat bed, bowls, yarn — this person loves a cat
	_cyl(room, o + Vector3(-12.3, 0.9, 6.5), 0.16, 0.2, 1.8, Color(0.78, 0.68, 0.55), true)
	_cyl(room, o + Vector3(-12.3, 1.85, 6.5), 0.75, 0.75, 0.14, Color(0.85, 0.6, 0.45))
	_cyl(room, o + Vector3(-12.3, 0.35, 6.5), 0.6, 0.6, 0.12, Color(0.85, 0.6, 0.45))
	_sphere(room, o + Vector3(-10.5, 0.22, 8.3), Vector3(1.0, 0.32, 1.0), Color(0.85, 0.45, 0.5)) # cat bed
	_sphere(room, o + Vector3(-10.5, 0.3, 8.3), Vector3(0.78, 0.24, 0.78), Color(0.95, 0.85, 0.7))
	_cyl(room, o + Vector3(-8.6, 0.12, 8.6), 0.32, 0.24, 0.22, Color(0.35, 0.6, 0.8)) # water bowl
	_cyl(room, o + Vector3(-7.8, 0.12, 8.6), 0.32, 0.24, 0.22, Color(0.9, 0.55, 0.3)) # food bowl
	_sphere(room, o + Vector3(5.5, 0.28, 7.8), Vector3(0.3, 0.3, 0.3), Color(0.85, 0.3, 0.35)) # yarn ball
	var yarn_wrap := _box(room, o + Vector3(5.5, 0.28, 7.8), Vector3(0.64, 0.1, 0.64), Color(0.7, 0.22, 0.28))
	yarn_wrap.rotation_degrees = Vector3(20, 30, 10)
	# Dining table (kept from v0.4, warmer wood) + chairs + plant centrepiece
	var dtable := _box(room, o + Vector3(9, 0.8, 4), Vector3(4.5, 0.25, 2.6), Color.WHITE, true)
	dtable.material_override = _mat_tex(TEX_WOOD, Color(0.9, 0.78, 0.62), Vector3(3, 2, 1))
	for cx5 in [-1.8, 1.8]:
		for cz5 in [-1.0, 1.0]:
			_cyl(room, o + Vector3(9 + cx5, 0.35, 4 + cz5), 0.09, 0.09, 0.7, Color(0.55, 0.38, 0.24))
	for chx in [-1.2, 1.2]:
		_box(room, o + Vector3(9 + chx, 0.5, 6.1), Vector3(0.95, 1.0, 0.14), Color(0.6, 0.44, 0.29))
		_box(room, o + Vector3(9 + chx, 1.25, 6.25), Vector3(0.95, 1.1, 0.12), Color(0.6, 0.44, 0.29))
	_cyl(room, o + Vector3(9, 1.15, 4), 0.2, 0.14, 0.45, Color(0.75, 0.4, 0.3))
	var table_plant := _sphere(room, o + Vector3(9, 1.6, 4), Vector3(0.5, 0.5, 0.5), Color.WHITE)
	table_plant.material_override = _mat_tex(TEX_FOLIAGE, Color.WHITE, Vector3(1, 1, 1))
	# Floor lamp by the sofa + big plant in the corner (kept positions, richer)
	_cyl(room, o + Vector3(12, 1.4, -7), 0.06, 0.09, 2.8, Color(0.3, 0.3, 0.33))
	_sphere(room, o + Vector3(12, 3.0, -7), Vector3(0.65, 0.5, 0.65), Color(1.0, 0.88, 0.6))
	_cyl(room, o + Vector3(-11, 0.5, -5.5), 0.42, 0.32, 1.0, Color(0.75, 0.4, 0.3))
	var corner_plant := _sphere(room, o + Vector3(-11, 1.7, -5.5), Vector3(1.15, 1.25, 1.15), Color.WHITE)
	corner_plant.material_override = _mat_tex(TEX_FOLIAGE, Color.WHITE, Vector3(2, 2, 2))
	# Coat hooks + shoes by the pet door
	for hx2 in range(3):
		_sphere(room, o + Vector3(3.6 + float(hx2) * 0.7, 2.2, -9.6), Vector3(0.09, 0.09, 0.12), Color(0.5, 0.38, 0.24))
	_box(room, o + Vector3(3.8, 1.55, -9.55), Vector3(0.55, 1.15, 0.14), Color(0.4, 0.5, 0.7)) # hanging coat
	for shx in [4.6, 5.3]:
		_box(room, o + Vector3(shx, 0.12, -9.2), Vector3(0.32, 0.22, 0.7), Color(0.55, 0.35, 0.25))


	# ============ BACK DOOR with SLIDING BOLT (shopkeeper exit) ====
	var bd_pos := o + Vector3(13.62, 0, 3.4)
	# v1.1 fix: the frame is a BORDER (lintel + two jambs), not a
	# solid block — the old solid block filled the doorway and hid
	# both the dark doorway panel and the cat crossing through it.
	_box(room, bd_pos + Vector3(0.05, 3.22, 0), Vector3(0.24, 0.36, 2.3), Color(0.92, 0.9, 0.84)) # frame lintel
	_box(room, bd_pos + Vector3(0.05, 1.65, -1.06), Vector3(0.24, 3.3, 0.18), Color(0.92, 0.9, 0.84)) # frame jamb (north)
	_box(room, bd_pos + Vector3(0.05, 1.65, 1.06), Vector3(0.24, 3.3, 0.18), Color(0.92, 0.9, 0.84)) # frame jamb (south)
	_box(room, bd_pos + Vector3(0.13, 1.5, 0), Vector3(0.05, 3.0, 1.95), Color(0.05, 0.04, 0.05)) # v1.1: dark doorway, revealed when the door swings open
	# v1.1: the door panel hangs on a hinge pivot (backdoor_pivot) so
	# the escape animation can swing it open; the bolt rides the door,
	# the keeper stays on the frame — like a real sliding bolt.
	backdoor_pivot = Node3D.new()
	backdoor_pivot.position = bd_pos + Vector3(-0.08, 0, -0.975)
	room.add_child(backdoor_pivot)
	var bd_door := _box(backdoor_pivot, Vector3(0, 1.5, 0.975), Vector3(0.14, 3.0, 1.95), Color.WHITE, true)
	bd_door.material_override = _mat_tex(TEX_WOOD, Color(0.62, 0.45, 0.28), Vector3(1, 2, 1))
	_box(bd_door, Vector3(-0.09, 0.6, 0), Vector3(0.05, 1.0, 1.3), Color(0.5, 0.36, 0.22)) # door panel inset
	_box(bd_door, Vector3(-0.09, -0.75, 0), Vector3(0.05, 0.9, 1.3), Color(0.5, 0.36, 0.22))
	_sphere(bd_door, Vector3(-0.14, -0.15, 0.78), Vector3(0.09, 0.09, 0.09), Color(0.8, 0.65, 0.3)) # knob
	_box(room, bd_pos + Vector3(-0.2, 1.95, -0.82), Vector3(0.08, 0.22, 0.2), Color(0.4, 0.32, 0.16)) # bolt keeper
	_box(room, bd_pos + Vector3(-0.2, 1.95, -0.18), Vector3(0.08, 0.22, 0.34), Color(0.4, 0.32, 0.16)) # bolt base plate
	bolt_node = _box(bd_door, Vector3(-0.16, 0.45, -0.42), Vector3(0.09, 0.11, 0.66), Color(0.78, 0.62, 0.26))
	bolt_node.material_override = _mat(Color(0.78, 0.62, 0.26), 0.3)
	_sphere(bolt_node, Vector3(-0.06, 0, 0.22), Vector3(0.08, 0.08, 0.08), Color(0.85, 0.68, 0.3)) # bolt thumb knob
	bolt_base_z = bolt_node.position.z
	var bd_label := _label3d(room, "Back door — slide the bolt!", bd_pos + Vector3(-0.7, 3.55, 0), 50, Color(0.3, 0.22, 0.12))
	bd_label.rotation_degrees = Vector3(0, -90, 0)
	# ============ CAT CARRIER (wriggle-out start for some variants) ==
	carrier_node = Node3D.new()
	carrier_node.position = o + Vector3(-6, 0, 7.5)
	room.add_child(carrier_node)
	var cbody := _box(carrier_node, Vector3(0, 0.62, 0), Vector3(1.7, 1.15, 1.15), Color(0.72, 0.78, 0.88), true)
	cbody.material_override = _mat(Color(0.72, 0.78, 0.88), 0.5)
	_box(carrier_node, Vector3(0, 1.27, 0), Vector3(0.7, 0.13, 0.2), Color(0.35, 0.38, 0.45)) # handle
	for vx in [-0.5, 0.0, 0.5]:
		_box(carrier_node, Vector3(vx, 0.85, 0.59), Vector3(0.22, 0.09, 0.03), Color(0.4, 0.44, 0.52)) # vents
	carrier_door = Node3D.new()
	carrier_door.position = Vector3(-0.78, 0.6, 0.58)
	carrier_node.add_child(carrier_door)
	for bx3 in [0.18, 0.55, 0.92, 1.29]:
		_box(carrier_door, Vector3(bx3, 0, 0), Vector3(0.06, 1.02, 0.05), Color(0.3, 0.32, 0.38))
	for by3 in [-0.45, 0.0, 0.45]:
		_box(carrier_door, Vector3(0.74, by3, 0), Vector3(1.5, 0.06, 0.05), Color(0.3, 0.32, 0.38))
	_box(carrier_door, Vector3(1.42, 0.1, 0.05), Vector3(0.12, 0.2, 0.08), Color(0.85, 0.6, 0.2)) # door clip
	_label3d(room, "Cat carrier", o + Vector3(-6, 1.85, 7.5), 48, Color(0.3, 0.35, 0.5))
	# ============ Tall VASE on the dining table ======================
	# v1.2: rebuilt as a PIVOT group on the table top (was a lone
	# cylinder + a separate flowers sphere) so it can be one of the
	# knock-over distraction props — body and flowers topple together.
	# vase_node keeps pointing at the group so _reset_escape_props /
	# vase_home work as before.
	var vase_pivot := Node3D.new()
	vase_pivot.position = o + Vector3(10.6, 0.925, 4.0)
	room.add_child(vase_pivot)
	vase_node = vase_pivot
	var vase_body := _cyl(vase_pivot, Vector3(0, 0.4, 0), 0.13, 0.23, 0.8, Color(0.25, 0.55, 0.6))
	vase_body.material_override = _mat(Color(0.25, 0.55, 0.6), 0.25)
	_sphere(vase_pivot, Vector3(0, 0.93, 0), Vector3(0.3, 0.35, 0.3), Color(0.95, 0.6, 0.65)) # flowers in vase
	vase_home = {"pos": vase_node.position, "rot": vase_node.rotation}
	# ============ PER-CAPTOR DRESSING (one group visible at a time) ==
	var tw := Node3D.new()
	tw.name = "ThemeWoman"
	room.add_child(tw)
	theme_groups["woman"] = tw
	theme_groups["pedestrian"] = tw
	_sphere(tw, o + Vector3(3, 0.16, 7.6), Vector3(0.17, 0.17, 0.17), Color(0.6, 0.6, 0.65)) # toy mouse
	_sphere(tw, o + Vector3(3.35, 0.14, 7.85), Vector3(0.07, 0.07, 0.3), Color(0.6, 0.6, 0.65))
	var wand := _cyl(tw, o + Vector3(-4, 0.55, 6.2), 0.025, 0.025, 1.1, Color(0.85, 0.5, 0.6))
	wand.rotation_degrees = Vector3(0, 0, 35)
	_sphere(tw, o + Vector3(-4.35, 1.05, 6.2), Vector3(0.22, 0.3, 0.22), Color(0.95, 0.6, 0.75)) # feather puff
	_box(tw, o + Vector3(-1.5, 1.28, 4.8), Vector3(1.7, 0.13, 1.5), Color(0.95, 0.65, 0.75)) # pink blanket on sofa
	var tk := Node3D.new()
	tk.name = "ThemeKid"
	room.add_child(tk)
	theme_groups["kid"] = tk
	var block_cols: Array = [Color(0.9, 0.3, 0.25), Color(0.25, 0.5, 0.9), Color(0.95, 0.8, 0.25), Color(0.35, 0.75, 0.35), Color(0.85, 0.45, 0.85), Color(0.95, 0.55, 0.2)]
	var block_pos: Array = [Vector3(4.5, 0.28, -2), Vector3(5.2, 0.28, -1.4), Vector3(4.8, 0.83, -1.7), Vector3(-3, 0.28, 1), Vector3(-2.3, 0.28, 1.5), Vector3(7.5, 0.28, 7)]
	for bi2 in range(block_pos.size()):
		var blk := _box(tk, o + block_pos[bi2], Vector3(0.55, 0.55, 0.55), block_cols[bi2])
		blk.rotation_degrees = Vector3(0, float(bi2) * 27.0, 0)
	_sphere(tk, o + Vector3(6.5, 0.45, -3.5), Vector3(0.45, 0.45, 0.45), Color(0.95, 0.55, 0.2)) # ball
	_box(tk, o + Vector3(-2, 2.5, 9.68), Vector3(2.3, 1.5, 0.08), Color(0.98, 0.85, 0.3)) # poster
	_sphere(tk, o + Vector3(-2, 2.55, 9.6), Vector3(0.06, 0.4, 0.4), Color(0.9, 0.4, 0.2)) # poster star (flat)
	_box(tk, o + Vector3(8.5, 0.22, 7.5), Vector3(0.9, 0.35, 0.45), Color(0.85, 0.3, 0.3)) # toy car
	var td := Node3D.new()
	td.name = "ThemeDog"
	room.add_child(td)
	theme_groups["dogwalker"] = td
	_sphere(td, o + Vector3(10.5, 0.55, -6.5), Vector3(0.9, 0.62, 1.15), Color(0.97, 0.96, 0.93)) # the dog: body
	_sphere(td, o + Vector3(10.5, 0.98, -7.35), Vector3(0.44, 0.42, 0.44), Color(0.97, 0.96, 0.93)) # head
	_box(td, o + Vector3(10.22, 1.12, -7.3), Vector3(0.14, 0.34, 0.2), Color(0.72, 0.58, 0.42)) # ear L
	_box(td, o + Vector3(10.78, 1.12, -7.3), Vector3(0.14, 0.34, 0.2), Color(0.72, 0.58, 0.42)) # ear R
	_sphere(td, o + Vector3(10.5, 1.0, -7.72), Vector3(0.13, 0.11, 0.11), Color(0.2, 0.16, 0.14)) # nose
	var dtail := _cyl(td, o + Vector3(10.5, 0.85, -5.5), 0.05, 0.08, 0.55, Color(0.97, 0.96, 0.93))
	dtail.rotation_degrees = Vector3(-50, 0, 0)
	_sphere(td, o + Vector3(10.5, 0.2, -4.6), Vector3(1.15, 0.3, 1.15), Color(0.5, 0.62, 0.85)) # big dog bed
	_cyl(td, o + Vector3(8.8, 0.12, -4.2), 0.34, 0.26, 0.22, Color(0.35, 0.6, 0.8)) # dog water bowl
	_cyl(td, o + Vector3(9.6, 0.12, -4.2), 0.34, 0.26, 0.22, Color(0.6, 0.4, 0.3)) # dog food bowl
	var ts := Node3D.new()
	ts.name = "ThemeShop"
	room.add_child(ts)
	theme_groups["shopkeeper"] = ts
	for cr in [Vector3(-12, 0.66, 2), Vector3(-12, 1.98, 2), Vector3(-10.55, 0.66, 2.4), Vector3(-12, 0.66, 3.6)]:
		var crate := _box(ts, o + cr, Vector3(1.3, 1.3, 1.3), Color.WHITE, true)
		crate.material_override = _mat_tex(TEX_WOOD, Color(0.85, 0.7, 0.5), Vector3(1, 1, 1))
	_box(ts, o + Vector3(-13.35, 1.85, 4), Vector3(0.5, 0.1, 4.2), Color(0.6, 0.45, 0.3)) # stock shelf board
	for ji in range(5):
		_cyl(ts, o + Vector3(-13.35, 2.12, 2.4 + float(ji) * 0.8), 0.15, 0.15, 0.45, [Color(0.9, 0.6, 0.3), Color(0.5, 0.75, 0.4), Color(0.85, 0.4, 0.4), Color(0.6, 0.6, 0.85), Color(0.9, 0.8, 0.35)][ji]) # stock jars
	_box(ts, o + Vector3(11.5, 0.5, 8.6), Vector3(0.9, 1.0, 0.65), Color(0.85, 0.72, 0.52)) # paper bag stack
	_box(ts, o + Vector3(12.5, 0.4, 8.2), Vector3(0.8, 0.8, 0.6), Color(0.8, 0.66, 0.47))
	var shop_sign := _label3d(ts, "🛒 STOCK ROOM", o + Vector3(-12.7, 3.1, 2.8), 56, Color(0.4, 0.3, 0.15))
	shop_sign.rotation_degrees = Vector3(0, 90, 0)
	for tg in theme_groups.values():
		(tg as Node3D).visible = false
	# ============ v1.2 DISTRACTION PROPS =============================
	# Three knock-over props (plant / book / vase), each a pivot the
	# cat can topple with PAW. Registered in distract_props with the
	# spot the captor stands in to right it ("stand" — picked BESIDE
	# the furniture, never inside a solid piece). They are NOT escape
	# steps: the suite's one-mechanism rule stands.
	var plant_pivot := Node3D.new()
	plant_pivot.position = o + Vector3(-6.5, 0.0, -6.8)
	room.add_child(plant_pivot)
	_cyl(plant_pivot, Vector3(0, 0.3, 0), 0.3, 0.24, 0.6, Color(0.75, 0.4, 0.3)) # terracotta pot
	_cyl(plant_pivot, Vector3(0, 0.58, 0), 0.34, 0.34, 0.1, Color(0.6, 0.3, 0.22)) # pot rim
	var plant_leaf := _sphere(plant_pivot, Vector3(0, 1.02, 0), Vector3(0.62, 0.55, 0.62), Color.WHITE)
	plant_leaf.material_override = _mat_tex(TEX_FOLIAGE, Color(0.75, 0.9, 0.7), Vector3(1, 1, 1))
	var plant_leaf2 := _sphere(plant_pivot, Vector3(0.28, 0.82, 0.12), Vector3(0.4, 0.38, 0.4), Color.WHITE)
	plant_leaf2.material_override = _mat_tex(TEX_FOLIAGE, Color(0.85, 0.95, 0.75), Vector3(1, 1, 1))
	distract_props.append({"id": "plant", "name": "the plant", "pivot": plant_pivot, "base": o + Vector3(-6.5, 0, -6.8), "stand": o + Vector3(-5.55, 0, -5.85), "toppled": false, "anim_t": 1.0, "home_rot": plant_pivot.rotation, "topple_rot": Vector3(0, 0, -1.85), "bubble": "Oh no — my plant! 🌱"})
	var book_pivot := Node3D.new()
	book_pivot.position = o + Vector3(1.15, 0.5, 1.35) # standing on the coffee table
	room.add_child(book_pivot)
	_box(book_pivot, Vector3(0, 0.34, 0), Vector3(0.58, 0.68, 0.2), Color(0.25, 0.45, 0.8)) # cover
	_box(book_pivot, Vector3(0.045, 0.34, 0), Vector3(0.5, 0.6, 0.19), Color(0.95, 0.92, 0.82)) # pages
	_box(book_pivot, Vector3(0, 0.34, 0.105), Vector3(0.58, 0.1, 0.02), Color(0.9, 0.75, 0.3)) # gold band
	distract_props.append({"id": "book", "name": "the book", "pivot": book_pivot, "base": o + Vector3(1.15, 0, 1.35), "stand": o + Vector3(1.15, 0, 2.75), "toppled": false, "anim_t": 1.0, "home_rot": book_pivot.rotation, "topple_rot": Vector3(-1.5, 0, 0), "bubble": "My book! 📖"})
	distract_props.append({"id": "vase", "name": "the vase", "pivot": vase_pivot, "base": o + Vector3(10.6, 0, 4.0), "stand": o + Vector3(12.1, 0, 4.0), "toppled": false, "anim_t": 1.0, "home_rot": vase_pivot.rotation, "topple_rot": Vector3(0, 0, 1.65), "bubble": "Oh! The vase! 🌷"})


# ---------------------------------------------------------------- actors/camera
func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(CatScript)
	player.position = Vector3(2, 0.2, -2)
	add_child(player)
	player.set("main_ref", self)

func _spawn_npcs() -> void:
	# v0.9 (item 2): MORE neighbours — 22 out walking (was 14),
	# spread over the whole map including the filled east/south
	# districts. The first of each type is the sheet character
	# (outfit 0); repeats get outfit/hair variants from person.gd.
	var defs: Array = [
		["woman", Vector3(-30, 0.2, -6)], ["kid", Vector3(36, 0.2, -14)], ["dogwalker", Vector3(-36, 0.2, 20)],
		["shopkeeper", Vector3(46, 0.2, 6)], ["pedestrian", Vector3(-44, 0.2, -22)], ["pedestrian", Vector3(50, 0.2, 34)],
		["woman", Vector3(8, 0.2, 26)], ["kid", Vector3(-52, 0.2, 28)],
		["woman", Vector3(84, 0.2, -44)], ["kid", Vector3(-86, 0.2, 38)], ["dogwalker", Vector3(60, 0.2, 66)],
		["shopkeeper", Vector3(-60, 0.2, -70)], ["pedestrian", Vector3(100, 0.2, 20)], ["pedestrian", Vector3(-100, 0.2, -80)],
		["woman", Vector3(-112, 0.2, -48)], ["kid", Vector3(108, 0.2, 38)], ["dogwalker", Vector3(-58, 0.2, 84)],
		["shopkeeper", Vector3(80, 0.2, -72)], ["pedestrian", Vector3(14, 0.2, -84)], ["pedestrian", Vector3(-14, 0.2, 48)],
		["woman", Vector3(110, 0.2, -6)], ["pedestrian", Vector3(34, 0.2, 84)],
	]
	# Interaction roles: v1.0 — grabbers are 25% of EVERYONE, as
	# Michael set on 2026-11-15 (he first said 20%, then settled on
	# 25%): in v0.9 play the single grabber (1 of 22, the v0.7 rate)
	# left him barely able to get anyone interested and it felt
	# boring. 25% of 22 is 5.5, so SIX neighbours seek the cat out;
	# the extra five came out of the friendly pool. The rest:
	# 8 FRIENDLY (pets +1 / treats +5 on paw/meow) and 8 who simply
	# never notice the cat ("ignore").
	var roles: Array = ["friendly", "grabber", "friendly", "friendly", "ignore", "grabber", "friendly", "friendly", "grabber", "ignore", "friendly", "ignore", "ignore", "ignore", "grabber", "friendly", "ignore", "grabber", "ignore", "friendly", "grabber", "ignore"]
	var type_counts: Dictionary = {}
	for i in range(defs.size()):
		var d: Array = defs[i]
		var occ: int = int(type_counts.get(d[0], 0))
		type_counts[d[0]] = occ + 1
		var npc: CharacterBody3D = CharacterBody3D.new()
		npc.set_script(PersonScript)
		npc.set("npc_type", d[0])
		npc.set("role", roles[i])
		npc.set("outfit_idx", occ)
		npc.position = d[1]
		add_child(npc)
		npc.set("main_ref", self)
		npc.set("player_ref", player)
		npcs.append(npc)

# --- v0.4 close third-person ORBIT camera + dual look controls ---------
# Town/play: MUCH closer than v0.3. Orbit distance 3.7 (v0.3: ~5.9 to the
# cat), default pitch 18 deg -> the ~1.25-unit cat fills ~26% of the
# screen height (v0.3 measured 17.2%). SCALE FIX (post-v1.0.3): the
# cat is now a real-cat ~0.52 units ear-to-paw (was ~1.5), so the
# orbit distance is 1.7 and the look height 0.30 — the cat keeps
# roughly the same screen share and framing he had. The camera
# orbits the cat:
# look_yaw rotates it around the cat, look_pitch_deg raises/lowers it
# (clamped -10..+55). Movement is camera-yaw-relative (cat.gd uses the
# cam_yaw value this script publishes every frame), so turning the
# camera turns movement sensibly. At yaw=0 the camera sits behind the
# cat on +Z exactly like v0.3, so up = away from camera by default.
# Escape room: slightly farther orbit (5.4) so the room still frames;
# the collision pull-in below keeps the camera inside its walls.
# v1.2 READABILITY (Michael's v1.0.4 playtest — the real-scale cat was
# hard to see): orbit back in toward the old perspective. Pre-scale-fix
# the cat filled ~0.40 of the frame height ratio (1.5m at 3.7m); the
# scale step left 0.31 (0.52m at 1.7m). With the model drawn at 1.25x
# (0.64m) and the orbit at 1.45m the ratio is ~0.44 — slightly BETTER
# than the framing he liked. Look height follows the drawn back.
const CAM_TOWN_DIST := 1.45
const CAM_ESCAPE_DIST := 5.0
const CAM_LOOK_HEIGHT := 0.38
const CAM_FOV := 62.0

func _camera_dist() -> float:
	return CAM_ESCAPE_DIST if state == "escape" else CAM_TOWN_DIST

# One entry point for ALL look input (touch drag, mouse drag, keys, tests).
func apply_look_drag(drag_delta: Vector2) -> void:
	look_yaw = wrapf(look_yaw - drag_delta.x * LOOK_YAW_SENS, -PI, PI)
	# Drag up (negative y) -> pitch down toward -10 -> camera drops and
	# you LOOK UP at signs; drag down -> look down from higher up.
	look_pitch_deg = clampf(look_pitch_deg + drag_delta.y * LOOK_PITCH_SENS, LOOK_PITCH_MIN, LOOK_PITCH_MAX)

func _look_press_blocked(pos: Vector2) -> bool:
	# A press that starts on an action button must never start a look
	# drag. v0.7: checks the buttons' LIVE rects (they are anchored to
	# the real screen corner now, not fixed 1280x720 coordinates).
	for b in action_buttons:
		if (b as Control).get_global_rect().has_point(pos):
			return true
	return false

func _input(event: InputEvent) -> void:
	if state == "cutscene":
		# skippable with a tap/click after ~1s (keys go via _unhandled_input)
		if cutscene_t >= 1.0 and ((event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)):
			skip_cutscene()
		return
	if state == "splash":
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			dismiss_splash()
		return
	if collar_open and (state == "play" or state == "escape"):
		# A tap anywhere except the COLLAR button itself closes the
		# collar zoom (the button toggles via its own callback).
		var press_pos := Vector2(-9999, -9999)
		if event is InputEventScreenTouch and event.pressed:
			press_pos = (event as InputEventScreenTouch).position
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			press_pos = (event as InputEventMouseButton).position
		if press_pos.x > -9000.0 and (collar_btn == null or not collar_btn.get_global_rect().has_point(press_pos)):
			_close_collar()
			return
	if escape_panel != null and escape_panel.visible:
		return # v1.1: the escape panel owns ALL input while open — the cat stays put, swipes go to the panel
	if state == "escape" and ((escape_prompt_btn != null and escape_prompt_btn.visible) or (prop_prompt_btn != null and prop_prompt_btn.visible)):
		# A press ON either escape prompt button is the button's own —
		# never a joystick or look-drag start.
		var pp := Vector2(-9999, -9999)
		if event is InputEventScreenTouch and event.pressed:
			pp = (event as InputEventScreenTouch).position
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pp = (event as InputEventMouseButton).position
		if pp.x > -9000.0:
			if escape_prompt_btn != null and escape_prompt_btn.visible and escape_prompt_btn.get_global_rect().has_point(pp):
				return
			if prop_prompt_btn != null and prop_prompt_btn.visible and prop_prompt_btn.get_global_rect().has_point(pp):
				return
	if state != "play" and state != "escape":
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var vp := get_viewport().get_visible_rect().size
		if t.pressed:
			if t.position.x < vp.x * 0.45 and joy_id == -999:
				joy_id = t.index
				joy_origin = t.position
				joy_current = t.position
			elif t.position.x >= vp.x * 0.45 and not _look_press_blocked(t.position):
				look_drags[t.index] = t.position
		else:
			if t.index == joy_id:
				joy_id = -999
			look_drags.erase(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == joy_id:
			joy_current = d.position
		elif look_drags.has(d.index):
			apply_look_drag(d.relative)
			look_drags[d.index] = d.position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var vp2 := get_viewport().get_visible_rect().size
			if mb.pressed:
				if mb.position.x < vp2.x * 0.45 and not joy_mouse:
					joy_mouse = true
					joy_origin = mb.position
					joy_current = mb.position
				elif mb.position.x >= vp2.x * 0.45 and not _look_press_blocked(mb.position):
					look_drags["mouse"] = mb.position
			else:
				joy_mouse = false
				look_drags.erase("mouse")
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if joy_mouse:
			joy_current = mm.position
		elif look_drags.has("mouse"):
			apply_look_drag(mm.relative)
			look_drags["mouse"] = mm.position

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = CAM_FOV
	cam.near = 0.08
	cam.far = 400.0 # v0.7: far plane set EXPLICITLY — distant streets, signs and houses stay drawn (v0.6 left the default and things clipped early). PERF (post-v1.0.1): 800 -> 400 — the town diagonal is ~317m and the escape-room shell is ~330m from the far map edge, so EVERYTHING in the world still fits inside 400 from any viewpoint: nothing visible is clipped, the depth range halves, and the standing ">= 400" test still passes.
	add_child(cam)
	cam.position = player.global_position + Vector3(0, 0.85, 1.75)
	cam.look_at(player.global_position + Vector3(0, CAM_LOOK_HEIGHT, 0), Vector3.UP)
	cam.current = true
	cam_target_pos = cam.position

func _update_camera(delta: float) -> void:
	if cam == null or player == null:
		return
	var look_target: Vector3 = player.global_position + Vector3(0, CAM_LOOK_HEIGHT, 0)
	var dist: float = _camera_dist()
	# CHASE CAMERA: still third-person behind the cat, but the frame
	# eases out and biases toward the pursuer so BOTH stay in frame —
	# you can watch them gaining or falling behind the whole chase.
	# (The position lerp below smooths this in/out: no hard cut.)
	chase_cam_active = false
	nearest_chaser = null
	if state == "play":
		var best_d: float = 1e9
		for n in npcs:
			var m: String = str(n.get("mode"))
			if m == "chase" or m == "pursue" or m == "tell":
				var d: float = (n as Node3D).global_position.distance_to(player.global_position)
				if d < best_d:
					best_d = d
					nearest_chaser = n
		if nearest_chaser != null:
			chase_cam_active = true
			dist = 5.6 # v1.2: 6.8 was tuned for the old big cat — closer now so the small cat AND the pursuer both read clearly (Michael: "hard to see people chasing him")
			var cp: Vector3 = (nearest_chaser as Node3D).global_position
			look_target = player.global_position.lerp(cp, 0.28) + Vector3(0, CAM_LOOK_HEIGHT, 0)
	current_cam_dist = dist
	var pitch_rad: float = deg_to_rad(look_pitch_deg)
	var behind: Vector3 = Basis(Vector3.UP, look_yaw) * Vector3(0, 0, 1)
	var desired: Vector3 = look_target + behind * (cos(pitch_rad) * dist) + Vector3(0, sin(pitch_rad) * dist, 0)
	desired.y = maxf(desired.y, 0.35) # never sink under the ground when looking up
	# COLLAR ZOOM (v0.7, item 12): while the collar check is open the
	# camera eases in close on the cat's neck — the REAL 3D collar and
	# round paw tag fill the frame, with the address caption in-scene
	# by the tag. Smooth in and out via collar_zoom_t + smoothstep.
	collar_zoom_t = move_toward(collar_zoom_t, 1.0 if collar_open else 0.0, delta * 1.7)
	if collar_zoom_t > 0.001 and player:
		var neck: Vector3 = player.call("get_neck_global_pos")
		var front: Vector3 = (player.global_transform.basis * Vector3(0, 0, 1)).normalized()
		var rightv: Vector3 = (player.global_transform.basis * Vector3(1, 0, 0)).normalized()
		var collar_desired: Vector3 = neck + front * 0.46 + rightv * 0.13 + Vector3(0, 0.07, 0)
		var k: float = collar_zoom_t * collar_zoom_t * (3.0 - 2.0 * collar_zoom_t)
		desired = desired.lerp(collar_desired, k)
		look_target = look_target.lerp(neck + Vector3(0, -0.035, 0), k)
	# ESCAPE CAMERA (v1.1): while the visible escape plays, frame the
	# exit and the cat together. The room's orbit camera can wedge
	# into furniture at some mechanisms (at the carrier it ends up
	# inside the fireplace and blacks out) — and the whole point of
	# the moment is that you WATCH him slip out. The damp below eases
	# to and from the vantage, so there's no cut.
	var escape_cam_active: bool = false
	if state == "escape" and escape_anim_t >= 0.0 and player:
		escape_cam_active = true
		var exit_pos: Vector3 = _escape_exit_pos(escape_anim_kind)
		look_target = exit_pos.lerp(player.global_position + Vector3(0, 0.25, 0), 0.45)
		desired = _escape_cam_pos(escape_anim_kind)
	# Snap (don't sweep across the map) when the cat teleports, e.g. into
	# or out of the escape room ~200 units away.
	if cam_target_pos.distance_to(desired) > 20.0:
		cam_target_pos = desired
	# v1.0 step 3 (motion): frame-rate-INDEPENDENT exponential damp.
	# The old weight, min(1, 7*delta), is a linear approximation whose
	# effective smoothing time constant changes with the presentation
	# rate (stiffer at 60 Hz, softer at 120 Hz), so the camera's glide
	# felt different — and fought the physics-stepped cat differently —
	# depending on the panel. 1-exp(-k*delta) is the exact form: same
	# k = 7.0, same feel at any refresh rate.
	var cam_damp_w: float = 1.0 - exp(-7.0 * delta)
	cam_target_pos = cam_target_pos.lerp(desired, cam_damp_w)
	var cam_pos: Vector3 = cam_target_pos
	# Collision pull-in: cast from the cat toward the wanted camera spot;
	# if a house / car / tree / room wall is in between, stop just short
	# of it instead of clipping through it. Skipped while the escape
	# camera is framing an exit: the vantages are hand-placed with
	# clear sight lines, and the ray only drags the shot off them
	# (it clipped a door-side prop and ruined the bolt framing).
	var space := get_world_3d().direct_space_state
	if space != null and not escape_cam_active:
		var dir: Vector3 = cam_pos - look_target
		if dir.length() > 0.5:
			var query := PhysicsRayQueryParameters3D.create(look_target, cam_pos)
			var exclude: Array[RID] = []
			if player is PhysicsBody3D:
				exclude.append((player as PhysicsBody3D).get_rid())
			for npc in npcs:
				if npc is PhysicsBody3D:
					exclude.append((npc as PhysicsBody3D).get_rid())
			query.exclude = exclude
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				var hit_pos: Vector3 = hit["position"]
				var pulled: Vector3 = hit_pos - dir.normalized() * 0.3
				if pulled.distance_to(look_target) >= 0.4:
					cam_pos = pulled
				else:
					# Cat is backed right up against the obstacle: squeeze
					# the camera into the small gap that remains.
					cam_pos = look_target + dir.normalized() * 0.4
	cam.position = cam_pos
	if cam.position.distance_to(look_target) > 0.3:
		cam.look_at(look_target, Vector3.UP)

# ---------------------------------------------------------------- HUD (same layout as v0.1)
func _hud_label(parent: Node, text: String, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = Color.WHITE
	settings.outline_size = 5
	settings.outline_color = Color(0, 0, 0, 0.6)
	l.label_settings = settings
	parent.add_child(l)
	return l

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var top := ColorRect.new()
	top.color = Color(0.08, 0.1, 0.16, 0.72)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.size = Vector2(1280, 70)
	hud_layer.add_child(top)
	objective_label = _hud_label(hud_layer, "🐾 HOMEWARD — Find your way home.", Vector2(16, 16), 24)
	# Scoreboard (v0.7): BIGGER, on its own gold-rimmed pill, anchored
	# to the top-right of the actual screen — it was too easy to miss
	# in v0.6. The stamina bar sits under the top bar; its RED segment
	# appears only in a chase (adrenaline).
	var score_pill := Panel.new()
	var sps := StyleBoxFlat.new()
	sps.bg_color = Color(0.05, 0.07, 0.12, 0.88)
	sps.corner_radius_top_left = 16; sps.corner_radius_top_right = 16
	sps.corner_radius_bottom_left = 16; sps.corner_radius_bottom_right = 16
	sps.border_color = Color(1.0, 0.85, 0.4, 0.9)
	sps.set_border_width_all(2)
	score_pill.add_theme_stylebox_override("panel", sps)
	score_pill.anchor_left = 1.0
	score_pill.anchor_right = 1.0
	score_pill.offset_left = -452
	score_pill.offset_right = -10
	score_pill.offset_top = 8
	score_pill.offset_bottom = 60
	score_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(score_pill)
	score_label = _hud_label(score_pill, "", Vector2(6, 4), 30)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_label.offset_left = 6
	score_label.offset_right = -12
	score_label.offset_top = 8
	score_label.offset_bottom = -4
	_update_score_label()
	stamina_bg = ColorRect.new()
	stamina_bg.color = Color(0, 0, 0, 0.55)
	stamina_bg.position = Vector2(16, 78)
	stamina_bg.size = Vector2(260, 14)
	hud_layer.add_child(stamina_bg)
	stamina_fill = ColorRect.new()
	stamina_fill.color = Color(0.45, 0.9, 0.45, 0.95)
	stamina_fill.position = Vector2(17, 79)
	stamina_fill.size = Vector2(258, 12)
	hud_layer.add_child(stamina_fill)
	stamina_adren = ColorRect.new()
	stamina_adren.color = Color(0.95, 0.25, 0.2, 0.95)
	stamina_adren.position = Vector2(275, 79)
	stamina_adren.size = Vector2(0, 12)
	hud_layer.add_child(stamina_adren)
	stamina_label = _hud_label(hud_layer, "⚡", Vector2(282, 70), 18)
	pursuit_label = _hud_label(hud_layer, "", Vector2(16, 104), 26)
	pursuit_label.label_settings.font_color = Color(1.0, 0.55, 0.5)
	message_label = _hud_label(hud_layer, "", Vector2(16, 560), 26)
	message_label.anchor_top = 1.0
	message_label.anchor_bottom = 1.0
	message_label.offset_top = -160
	message_label.offset_bottom = -118
	escape_label = _hud_label(hud_layer, "", Vector2(16, 134), 26)
	escape_label.label_settings.font_color = Color(1.0, 0.95, 0.6)
	# v0.7 COLLAR CHECK = CAMERA ZOOM (item 12): the old 2D panel with
	# a sprite is GONE. The game camera flies in on the real 3D cat
	# (see _update_camera); this caption lives IN the 3D scene, just
	# in front of the cat's chest under the real collar tag, and is
	# only visible while zoomed. FIXED_Y billboard: it turns to face
	# the camera around the vertical axis but stays part of the scene.
	collar_caption = Label3D.new()
	collar_caption.font_size = 44
	collar_caption.pixel_size = 0.0012
	collar_caption.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	collar_caption.modulate = Color(1.0, 0.95, 0.7)
	collar_caption.outline_size = 8
	collar_caption.outline_modulate = Color(0, 0, 0, 0.55)
	collar_caption.position = Vector3(0, 0.02, 0.36) # just under the real tag (local 0,0.158,0.288)
	collar_caption.visible = false
	player.add_child(collar_caption)
	title_panel = _make_panel(hud_layer, Vector2(240, 40), Vector2(800, 640), Color(0.09, 0.11, 0.2, 0.97))
	# v0.7: centre the panel on the ACTUAL screen (was fixed at
	# (240,40) of a 1280x720 design — off-centre on Michael's phone).
	title_panel.set_anchors_preset(Control.PRESET_CENTER)
	title_panel.offset_left = -400
	title_panel.offset_right = 400
	title_panel.offset_top = -320
	title_panel.offset_bottom = 320
	_hud_label(title_panel, "🐾  HOMEWARD 3D  🐾", Vector2(170, 18), 44)
	var cat_tr := TextureRect.new()
	if ResourceLoader.exists("res://assets/sprites/cat.png"):
		cat_tr.texture = load("res://assets/sprites/cat.png")
	cat_tr.position = Vector2(70, 90); cat_tr.size = Vector2(192, 144)
	cat_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_panel.add_child(cat_tr)
	var tag_tr := TextureRect.new()
	if ResourceLoader.exists("res://assets/sprites/collar_tag.png"):
		tag_tr.texture = load("res://assets/sprites/collar_tag.png")
	tag_tr.position = Vector2(300, 70); tag_tr.size = Vector2(220, 220)
	tag_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_panel.add_child(tag_tr)
	_hud_label(title_panel, "Your collar tag says your home is:", Vector2(90, 300), 26)
	var addr := _hud_label(title_panel, home_address, Vector2(30, 340), 38)
	addr.label_settings.font_color = Color(1.0, 0.9, 0.45)
	addr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	addr.custom_minimum_size = Vector2(740, 55)
	_hud_label(title_panel, "Memorise it! Find that house. Don't let kind people\ntake you home with them — press C when stopped to re-check.", Vector2(70, 410), 23)
	var start_btn := Button.new()
	start_btn.text = "▶  START  —  Find Home!"
	start_btn.position = Vector2(200, 520)
	start_btn.size = Vector2(400, 80)
	start_btn.add_theme_font_size_override("font_size", 30)
	start_btn.pressed.connect(start_game)
	title_panel.add_child(start_btn)
	win_panel = _make_panel(hud_layer, Vector2(290, 130), Vector2(700, 460), Color(0.12, 0.2, 0.12, 0.97))
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.offset_left = -350
	win_panel.offset_right = 350
	win_panel.offset_top = -230
	win_panel.offset_bottom = 230
	win_label = _hud_label(win_panel, "", Vector2(40, 40), 30)
	win_label.custom_minimum_size = Vector2(620, 240)
	var again := Button.new()
	again.text = "🔁  Play Again (new address!)"
	again.position = Vector2(130, 320)
	again.size = Vector2(440, 80)
	again.add_theme_font_size_override("font_size", 26)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	win_panel.add_child(again)
	win_panel.visible = false
	_build_splash()
	# Cutscene fade rect (the mini-map was removed entirely in v0.7)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(fade_rect)

# ---------------------------------------------------------------- splash (v0.6)
# A proper cute opening screen BEFORE the collar/title: warm golden
# panel, Michael's own front-view cat art from his reference sheet
# (assets/sprites/splash_cat.png, cropped from that sheet), the title,
# and a clear Tap to Start. It never shows the address — that stays on
# the collar close-up that follows. Dismiss via the button, any tap /
# click, or any key; dismiss_splash() is also what tests call.
func _build_splash() -> void:
	# v0.7: the splash is anchored FULL-RECT and every element is
	# centred by anchors, so it fills and centres on ANY screen —
	# in v0.6 it was a fixed 1280x720 panel that sat in a corner of
	# Michael's wider phone screen with everything off-centre.
	splash_panel = _make_panel(hud_layer, Vector2(0, 0), Vector2(1280, 720), Color(1.0, 0.98, 0.94, 1.0))
	splash_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_panel.offset_left = 0
	splash_panel.offset_top = 0
	splash_panel.offset_right = 0
	splash_panel.offset_bottom = 0
	var sun_glow := _hud_label(splash_panel, "☀️", Vector2(1050, 36), 90)
	sun_glow.label_settings.font_color = Color(1.0, 0.8, 0.3)
	sun_glow.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sun_glow.offset_left = -240
	sun_glow.offset_right = -20
	sun_glow.offset_top = 30
	sun_glow.offset_bottom = 140
	sun_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var band := _make_panel(splash_panel, Vector2(0, 636), Vector2(1280, 84), Color(0.96, 0.78, 0.45, 1.0))
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_left = 0
	band.offset_right = 0
	band.offset_top = -84
	band.offset_bottom = 0
	var title := _hud_label(splash_panel, "HOMEWARD", Vector2(0, 26), 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 0
	title.offset_right = 0
	title.offset_top = 26
	title.offset_bottom = 136
	title.label_settings.font_color = Color(0.45, 0.22, 0.08)
	var sub := _hud_label(splash_panel, "A little cat. A long way home.", Vector2(0, 128), 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_left = 0
	sub.offset_right = 0
	sub.offset_top = 128
	sub.offset_bottom = 172
	sub.label_settings.font_color = Color(0.55, 0.35, 0.16)
	var card := _make_panel(splash_panel, Vector2(492, 163), Vector2(296, 482), Color(0.88, 0.62, 0.3, 1.0))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -148
	card.offset_right = 148
	card.offset_top = -181
	card.offset_bottom = 301
	var cat_tr := TextureRect.new()
	if ResourceLoader.exists("res://assets/sprites/splash_cat.png"):
		cat_tr.texture = load("res://assets/sprites/splash_cat.png")
	cat_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cat_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	cat_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_tr.set_anchors_preset(Control.PRESET_CENTER)
	cat_tr.offset_left = -135
	cat_tr.offset_right = 135
	cat_tr.offset_top = -168
	cat_tr.offset_bottom = 288
	splash_panel.add_child(cat_tr)
	var start_btn := Button.new()
	start_btn.text = "Tap to Start"
	start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	start_btn.offset_left = -200
	start_btn.offset_right = 200
	start_btn.offset_top = -71
	start_btn.offset_bottom = -13
	start_btn.add_theme_font_size_override("font_size", 30)
	start_btn.pressed.connect(dismiss_splash)
	splash_panel.add_child(start_btn)
	splash_panel.visible = false

func _show_splash() -> void:
	state = "splash"
	title_panel.visible = false
	splash_panel.visible = true
	if player:
		player.set("frozen", true)
	if splash_song_player and splash_song_player.stream:
		splash_song_player.volume_db = -9.0
		splash_song_player.play()

func dismiss_splash() -> void:
	if state != "splash":
		return
	splash_panel.visible = false
	if splash_song_player and splash_song_player.playing:
		var tw := create_tween()
		tw.tween_property(splash_song_player, "volume_db", -42.0, 0.9)
		tw.tween_callback(splash_song_player.stop)
	_show_title()

func _make_panel(parent: Node, pos: Vector2, size: Vector2, color: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 18; style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18; style.corner_radius_bottom_right = 18
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

# ---------------------------------------------------------------- touch controls
func _build_touch_controls() -> void:
	touch_layer = CanvasLayer.new()
	touch_layer.layer = 5
	add_child(touch_layer)
	# NO D-pad (removed in v0.6): movement is the floating joystick —
	# its base + knob appear wherever the left thumb lands.
	joy_base = Panel.new()
	joy_base.size = Vector2(116, 116)
	joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jbs := StyleBoxFlat.new()
	jbs.bg_color = Color(1, 1, 1, 0.13)
	jbs.corner_radius_top_left = 58; jbs.corner_radius_top_right = 58
	jbs.corner_radius_bottom_left = 58; jbs.corner_radius_bottom_right = 58
	jbs.border_color = Color(1, 1, 1, 0.55)
	jbs.set_border_width_all(2)
	joy_base.add_theme_stylebox_override("panel", jbs)
	joy_base.visible = false
	touch_layer.add_child(joy_base)
	joy_knob = Panel.new()
	joy_knob.size = Vector2(56, 56)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jks := StyleBoxFlat.new()
	jks.bg_color = Color(1, 1, 1, 0.4)
	jks.corner_radius_top_left = 28; jks.corner_radius_top_right = 28
	jks.corner_radius_bottom_left = 28; jks.corner_radius_bottom_right = 28
	jks.border_color = Color(1, 1, 1, 0.8)
	jks.set_border_width_all(2)
	joy_knob.add_theme_stylebox_override("panel", jks)
	joy_knob.visible = false
	touch_layer.add_child(joy_knob)
	_round_action("A\nHOP", Vector2(1178, 590), 92, Color(0.85, 0.3, 0.3, 0.88), _on_hop_pressed)
	_round_action("B\nPAW", Vector2(1066, 614), 84, Color(0.3, 0.45, 0.9, 0.88), func() -> void: _on_interact())
	_round_action("MEOW", Vector2(1146, 492), 70, Color(0.55, 0.4, 0.85, 0.85), func() -> void: _on_meow())
	collar_btn = _round_action("COLLAR", Vector2(1062, 506), 70, Color(0.3, 0.65, 0.55, 0.85), func() -> void: _toggle_collar())
	# v0.7: NO Sprint button — sprint is pushing the joystick all the
	# way (Michael's final decision). NO Map button — mini-map removed.
	# Presses starting on a button never start a look drag; the live
	# button rects are checked in _look_press_blocked.
	# Discoverable look-area indicator: a soft circle on the right edge.
	# It is display-only (mouse_filter IGNORE) — dragging anywhere on the
	# right half (off the buttons) is what actually looks around.
	var look_dot := Button.new()
	look_dot.text = "👀\nLOOK"
	look_dot.anchor_left = 1.0
	look_dot.anchor_right = 1.0
	look_dot.anchor_top = 0.5
	look_dot.anchor_bottom = 0.5
	look_dot.offset_left = -84
	look_dot.offset_right = -12
	look_dot.offset_top = -36
	look_dot.offset_bottom = 36
	look_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	look_dot.focus_mode = Control.FOCUS_NONE
	look_dot.add_theme_font_size_override("font_size", 14)
	look_dot.add_theme_stylebox_override("normal", _round_style(Color(0.1, 0.14, 0.22, 0.5), 72))
	look_dot.add_theme_stylebox_override("pressed", _round_style(Color(0.1, 0.14, 0.22, 0.5), 72))
	look_dot.add_theme_stylebox_override("hover", _round_style(Color(0.1, 0.14, 0.22, 0.5), 72))
	look_dot.add_theme_stylebox_override("disabled", _round_style(Color(0.1, 0.14, 0.22, 0.5), 72))
	touch_layer.add_child(look_dot)
	# Start-of-run hint (fades after ~7 seconds of play).
	hint_label = _hud_label(touch_layer, "🐾 LEFT side: touch & drag to MOVE — push ALL the way to sprint!\n👀 RIGHT side: drag to LOOK — tilt UP to read the street signs!", Vector2(330, 92), 26)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.offset_left = -310
	hint_label.offset_right = 310
	hint_label.offset_top = 92
	hint_label.offset_bottom = 162
	hint_label.visible = false
	touch_layer.visible = false

# ---------------------------------------------------------------- escape UI (v1.1 panel puzzle)
func _build_escape_ui() -> void:
	# Own layer ABOVE the touch controls (layer 5): the prompt and the
	# panel are modal to the escape — nothing else should draw over
	# them or steal their taps.
	escape_ui_layer = CanvasLayer.new()
	escape_ui_layer.layer = 8
	add_child(escape_ui_layer)
	# THE PROMPT: a big warm dialogue-style button, bottom-centre,
	# shown only while the cat stands at the current mechanism.
	escape_prompt_btn = Button.new()
	escape_prompt_btn.text = "🐾 PAW the latch!"
	escape_prompt_btn.anchor_left = 0.5
	escape_prompt_btn.anchor_right = 0.5
	escape_prompt_btn.anchor_top = 1.0
	escape_prompt_btn.anchor_bottom = 1.0
	escape_prompt_btn.offset_left = -340.0
	escape_prompt_btn.offset_right = 340.0
	escape_prompt_btn.offset_top = -196.0
	escape_prompt_btn.offset_bottom = -120.0
	escape_prompt_btn.pivot_offset = Vector2(340, 38)
	escape_prompt_btn.add_theme_font_size_override("font_size", 31)
	escape_prompt_btn.add_theme_color_override("font_color", Color(0.25, 0.16, 0.08))
	escape_prompt_btn.add_theme_color_override("font_hover_color", Color(0.25, 0.16, 0.08))
	escape_prompt_btn.add_theme_color_override("font_pressed_color", Color(0.25, 0.16, 0.08))
	var prompt_col := Color(1.0, 0.85, 0.45, 0.97)
	escape_prompt_btn.add_theme_stylebox_override("normal", _prompt_style(prompt_col))
	escape_prompt_btn.add_theme_stylebox_override("pressed", _prompt_style(prompt_col.lightened(0.12)))
	escape_prompt_btn.add_theme_stylebox_override("hover", _prompt_style(prompt_col))
	escape_prompt_btn.pressed.connect(_on_escape_prompt_pressed)
	escape_prompt_btn.visible = false
	escape_ui_layer.add_child(escape_prompt_btn)
	# v1.2 DISTRACTION HUD: a status line + a slim window bar under the
	# message bar. Added BEFORE the panel so the modal panel draws over
	# them (the panel carries its own status strip while it is open).
	distract_label = Label.new()
	distract_label.anchor_left = 0.5
	distract_label.anchor_right = 0.5
	distract_label.offset_left = -430.0
	distract_label.offset_right = 430.0
	distract_label.offset_top = 128.0
	distract_label.offset_bottom = 168.0
	distract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distract_label.add_theme_font_size_override("font_size", 25)
	distract_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	distract_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.08, 0.05, 0.9))
	distract_label.add_theme_constant_override("shadow_offset_x", 2)
	distract_label.add_theme_constant_override("shadow_offset_y", 2)
	distract_label.visible = false
	escape_ui_layer.add_child(distract_label)
	distract_bar_bg = ColorRect.new()
	distract_bar_bg.color = Color(0.08, 0.08, 0.12, 0.55)
	distract_bar_bg.anchor_left = 0.5
	distract_bar_bg.anchor_right = 0.5
	distract_bar_bg.offset_left = -260.0
	distract_bar_bg.offset_right = 260.0
	distract_bar_bg.offset_top = 170.0
	distract_bar_bg.offset_bottom = 182.0
	distract_bar_bg.visible = false
	escape_ui_layer.add_child(distract_bar_bg)
	distract_bar_fill = ColorRect.new()
	distract_bar_fill.color = Color(0.45, 0.9, 0.45, 0.95)
	distract_bar_fill.visible = false
	distract_bar_bg.add_child(distract_bar_fill) # positioned relative to the bar in _update_distract_hud
	# v1.2 PROP PROMPT: the twin of the mechanism prompt, shown while
	# the cat stands by a standing knock-over prop. Tapping it (or
	# pressing PAW) topples the prop.
	prop_prompt_btn = Button.new()
	prop_prompt_btn.text = "🐾 Paw it over!"
	prop_prompt_btn.anchor_left = 0.5
	prop_prompt_btn.anchor_right = 0.5
	prop_prompt_btn.anchor_top = 1.0
	prop_prompt_btn.anchor_bottom = 1.0
	prop_prompt_btn.offset_left = -340.0
	prop_prompt_btn.offset_right = 340.0
	prop_prompt_btn.offset_top = -292.0
	prop_prompt_btn.offset_bottom = -216.0
	prop_prompt_btn.add_theme_font_size_override("font_size", 29)
	prop_prompt_btn.add_theme_color_override("font_color", Color(0.16, 0.2, 0.3))
	prop_prompt_btn.add_theme_color_override("font_hover_color", Color(0.16, 0.2, 0.3))
	prop_prompt_btn.add_theme_color_override("font_pressed_color", Color(0.16, 0.2, 0.3))
	var prop_col := Color(0.62, 0.82, 1.0, 0.97)
	prop_prompt_btn.add_theme_stylebox_override("normal", _prompt_style(prop_col))
	prop_prompt_btn.add_theme_stylebox_override("pressed", _prompt_style(prop_col.lightened(0.12)))
	prop_prompt_btn.add_theme_stylebox_override("hover", _prompt_style(prop_col))
	prop_prompt_btn.pressed.connect(_on_prop_prompt_pressed)
	prop_prompt_btn.visible = false
	escape_ui_layer.add_child(prop_prompt_btn)
	# THE PANEL (scripts/escape_panel.gd): picture + combo + PAW.
	# Anchors are set HERE, before it enters the tree — the same
	# pattern as fade_rect (a script setting its own anchors in its
	# _ready leaves the rect at size 0; verified by probe).
	escape_panel = EscapePanelScript.new()
	escape_panel.set("on_input", Callable(self, "escape_panel_input"))
	escape_panel.set("on_close", Callable(self, "_close_escape_panel"))
	escape_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	escape_ui_layer.add_child(escape_panel)

func _prompt_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 18; s.corner_radius_top_right = 18
	s.corner_radius_bottom_left = 18; s.corner_radius_bottom_right = 18
	s.border_color = Color(0.55, 0.38, 0.15)
	s.set_border_width_all(3)
	return s

func _round_style(color: Color, diameter: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	var r: int = diameter / 2
	s.corner_radius_top_left = r; s.corner_radius_top_right = r
	s.corner_radius_bottom_left = r; s.corner_radius_bottom_right = r
	s.border_color = Color(1, 1, 1, 0.7)
	s.set_border_width_all(2)
	return s

func _round_action(text: String, pos: Vector2, diameter: int, color: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	# v0.7: anchored to the bottom-right of the REAL screen (pos is
	# the old 1280x720 design position) so the buttons hug the corner
	# at any phone aspect ratio.
	b.anchor_left = 1.0
	b.anchor_top = 1.0
	b.anchor_right = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = pos.x - 1280.0
	b.offset_top = pos.y - 720.0
	b.offset_right = b.offset_left + diameter
	b.offset_bottom = b.offset_top + diameter
	b.add_theme_font_size_override("font_size", 17 if diameter < 80 else 20)
	b.add_theme_stylebox_override("normal", _round_style(color, diameter))
	b.add_theme_stylebox_override("pressed", _round_style(color.lightened(0.25), diameter))
	b.add_theme_stylebox_override("hover", _round_style(color, diameter))
	b.pressed.connect(on_press)
	touch_layer.add_child(b)
	action_buttons.append(b)
	return b

func _round_hold(text: String, pos: Vector2, diameter: int, color: Color, on_hold: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(diameter, diameter)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", _round_style(color, diameter))
	b.add_theme_stylebox_override("pressed", _round_style(color.lightened(0.25), diameter))
	b.add_theme_stylebox_override("hover", _round_style(color, diameter))
	b.button_down.connect(func() -> void: on_hold.call(true))
	b.button_up.connect(func() -> void: on_hold.call(false))
	touch_layer.add_child(b)
	return b

func _on_hop_pressed() -> void:
	if player:
		player.try_hop()

func _on_sprint_hold(p: bool) -> void:
	if player:
		player.set("touch_sprint", p)

func _apply_joystick() -> void:
	if player == null:
		return
	var active_joy: bool = joy_id != -999 or joy_mouse
	if active_joy:
		var v: Vector2 = (joy_current - joy_origin) / 85.0
		if v.length() > 1.0:
			v = v.normalized()
		player.set("touch_dir", v)
		if joy_base:
			joy_base.visible = true
			joy_base.position = joy_origin - Vector2(58, 58)
		if joy_knob:
			joy_knob.visible = true
			joy_knob.position = joy_origin + v * 40.0 - Vector2(28, 28)
	else:
		player.set("touch_dir", Vector2.ZERO)
		if joy_base: joy_base.visible = false
		if joy_knob: joy_knob.visible = false

# ---------------------------------------------------------------- flow
func _show_title() -> void:
	state = "title"
	title_panel.visible = true
	if player:
		player.set("frozen", true)

func start_game() -> void:
	title_panel.visible = false
	touch_layer.visible = true
	state = "play"
	if splash_song_player and splash_song_player.playing:
		splash_song_player.stop()
	if player:
		player.set("frozen", false)
	if music.stream:
		var wav := music.stream as AudioStreamWAV
		if wav:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		music.play()
	if hint_label:
		hint_label.visible = true
	hint_timer = 7.0
	show_message("Find home: the address from your collar tag. Avoid lingering near people!", 5.0)

func show_message(text: String, seconds: float = 3.0) -> void:
	message_label.text = text
	message_timer = seconds

func _toggle_collar() -> void:
	if state != "play" and state != "escape":
		return
	if collar_open:
		_close_collar()
		return
	if player and player.has_method("is_moving") and player.is_moving():
		show_message("Stop first, then check your collar.", 2.0)
		return
	# v0.7: opening the collar check starts the CAMERA ZOOM onto the
	# real collar (see _update_camera) and shows the in-scene caption.
	collar_open = true
	collar_timer = 6.0
	if collar_caption:
		collar_caption.text = "🏠 " + home_address
		collar_caption.visible = true
	if player: player.set("frozen", true)

func _close_collar() -> void:
	if not collar_open:
		return
	collar_open = false
	if collar_caption:
		collar_caption.visible = false
	if player: player.set("frozen", false)

func _on_meow() -> void:
	if state != "play" or meow_cooldown > 0.0 or player == null:
		return
	meow_cooldown = 1.2
	if meow_players.size() > 0:
		var mp: AudioStreamPlayer = meow_players[meow_index % meow_players.size()]
		meow_index += 1
		mp.pitch_scale = randf_range(0.97, 1.04) # tiny natural variation
		mp.play()
	# v0.7 (item 15): a meow is INSTANT attention — everyone in
	# earshot (8 units; sound carries further than a paw swipe)
	# reacts right now, notice meter bypassed entirely. Friendly:
	# joy + approach. Grabber: straight into the RUN tell.
	var heard := false
	for npc in npcs:
		if npc.global_position.distance_to(player.global_position) < 8.0:
			npc.call("react_to_attention")
			heard = true
	show_message("😺 Meow! Everyone nearby heard that…" if heard else "😺 Meow!", 2.0)

func _on_interact() -> void:
	if state == "escape":
		_escape_interact()
	elif state == "play":
		_paw_action()
		_check_door(true)

# v0.7 PAW (items 13+15): the B / PAW button always DOES something —
# a real paw-swipe animation on the cat, and anyone within reach
# (3.2 units) reacts INSTANTLY, no notice-meter wait: a friendly
# person lights up with "Oh, a cat!", a GRABBER is provoked straight
# into their RUN tell + chase. Pawing thin air = just the swipe.
func _paw_action() -> void:
	if player == null:
		return
	player.call("do_paw_swipe")
	var best: Node = null
	var best_d: float = 3.2
	for npc in npcs:
		var d: float = (npc as Node3D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = npc
	if best:
		var result: String = str(best.call("react_to_attention"))
		if result == "tell":
			show_message("😬 You pawed the WRONG person — RUN!", 2.0)
		elif result == "notice":
			show_message("🐾 They noticed you — because you pawed them!", 1.6)

func on_chase_started(npc: Node) -> void:
	if state != "play":
		return
	sfx_notice.play()
	show_message("🏃 CHASE! " + str(npc.get("display_name")) + " is after you — SPRINT, jink, hide, break away!", 2.5)

func on_chase_ended(_npc: Node) -> void:
	if state == "play":
		show_message("💨 You broke away! They lost you.", 2.0)

func on_grabber_tell(npc: Node) -> void:
	if state != "play":
		return
	sfx_notice.play()
	show_message("❗ " + str(npc.get("display_name")) + ": \"Here, kitty kitty!\" — RUN!", 2.2)

# ---------------------------------------------------------------- traffic (v0.7)
const TRAFFIC_ROADS_H: Array = [-55.0, -11.0, 15.0, 55.0] # z of the horizontal roads
const TRAFFIC_ROADS_V: Array = [-70.0, -20.0, 24.0, 72.0] # x of the vertical roads

func spawn_traffic_car() -> Node3D:
	# One car enters at a map edge and drives straight down a street.
	# Right-hand lanes; varied types and colours (the v0.6 car set).
	if traffic_group == null:
		return null
	var types: Array = ["sedan", "hatchback", "pickup", "van", "convertible"]
	var cols: Array = [Color(0.8, 0.25, 0.22), Color(0.25, 0.45, 0.85), Color(0.3, 0.6, 0.5), Color(0.9, 0.88, 0.85), Color(0.5, 0.5, 0.55), Color(0.6, 0.35, 0.75), Color(0.2, 0.55, 0.6)]
	var dir_sign: float = 1.0 if rng.randf() < 0.5 else -1.0
	var speed: float = rng.randf_range(7.0, 10.0)
	var node: Node3D
	var vel: Vector3
	if rng.randf() < 0.55:
		var rz: float = TRAFFIC_ROADS_H[rng.randi_range(0, TRAFFIC_ROADS_H.size() - 1)]
		var lane: float = rz + (1.8 if dir_sign > 0.0 else -1.8)
		node = _build_car(traffic_group, Vector3(-124.0 * dir_sign, 0, lane), cols[rng.randi_range(0, cols.size() - 1)], true, types[rng.randi_range(0, types.size() - 1)], true)
		node.rotation_degrees = Vector3(0, 0.0 if dir_sign > 0.0 else 180.0, 0)
		vel = Vector3(speed * dir_sign, 0, 0)
	else:
		var rx: float = TRAFFIC_ROADS_V[rng.randi_range(0, TRAFFIC_ROADS_V.size() - 1)]
		var lane2: float = rx + (-1.8 if dir_sign > 0.0 else 1.8)
		node = _build_car(traffic_group, Vector3(lane2, 0, -90.0 * dir_sign), cols[rng.randi_range(0, cols.size() - 1)], true, types[rng.randi_range(0, types.size() - 1)], true)
		node.rotation_degrees = Vector3(0, -90.0 if dir_sign > 0.0 else 90.0, 0)
		vel = Vector3(0, 0, speed * dir_sign)
	traffic_cars.append({"node": node, "vel": vel})
	return node

func _process_traffic(delta: float) -> void:
	if traffic_hit_cd > 0.0:
		traffic_hit_cd -= delta
	traffic_timer -= delta
	if traffic_timer <= 0.0:
		traffic_timer = rng.randf_range(3.5, 6.5)
		if traffic_cars.size() < 3:
			spawn_traffic_car()
	var dead: Array = []
	for tc in traffic_cars:
		var n: Node3D = tc["node"]
		n.position += (tc["vel"] as Vector3) * delta
		# PERF (post-v1.0.1): a traffic car is only DRAWN within 150m
		# of the cat (it keeps driving while hidden, so it still
		# arrives on schedule). Cars spawn at the map edges, often
		# 200m+ away across town — pure draw calls until they near.
		n.visible = player == null or n.position.distance_squared_to(player.global_position) < 22500.0
		if absf(n.position.x) > 128.0 or absf(n.position.z) > 93.0:
			dead.append(tc)
		elif state == "play" and player and traffic_hit_cd <= 0.0:
			var d: Vector3 = player.global_position - n.position
			d.y = 0.0
			if d.length() < 2.3:
				traffic_hit_cd = 2.5
				apply_traffic_hit(tc["vel"])
	for tc in dead:
		traffic_cars.erase(tc)
		(tc["node"] as Node).queue_free()

func apply_traffic_hit(car_vel: Vector3) -> void:
	# v0.7: points ONLY. The cat is startled and comically bounced —
	# never hurt, never captured, no game over.
	score = maxi(0, score - TRAFFIC_HIT_PENALTY)
	_update_score_label()
	if player:
		player.call("apply_car_bump", car_vel.normalized())
	show_message("🚗 Whoa! A car startled you — -%d points! (You're fine, just bounced.)" % TRAFFIC_HIT_PENALTY, 2.5)

# ---------------------------------------------------------------- score
func _update_score_label() -> void:
	if score_label:
		score_label.text = "⭐ %d   🐾 Pets %d   🍪 Treats %d" % [score, pets_count, treats_count]

func on_pet(_npc: Node) -> void:
	score += 1
	pets_count += 1
	_update_score_label()

func on_treat(_npc: Node) -> void:
	score += 5
	treats_count += 1
	_update_score_label()
	show_message("🍪 A treat! +5 points — worth getting close… carefully.", 2.0)

func apply_capture_penalty() -> int:
	# Being taken home costs 20% of your score.
	var lost: int = int(round(float(score) * 0.2))
	score -= lost
	_update_score_label()
	return lost

func apply_escape_bonus() -> void:
	# Escaping earns +3 back — deliberately less than a capture cost.
	score += 3
	_update_score_label()

func on_dog_bark(pos: Vector3) -> void:
	if player and player.global_position.distance_to(pos) < 20.0:
		if not sfx_bark.playing:
			sfx_bark.play()
		if bark_msg_cooldown <= 0.0:
			bark_msg_cooldown = 5.0
			show_message("🐶 Woof! The little dog spotted you!", 2.0)

func update_player_hiding(p: Node) -> void:
	var hidden := false
	var pp: Vector3 = (p as Node3D).global_position
	if pp.x < 150.0: # only in town, not the escape room
		for hp in hide_points:
			var d: Vector3 = pp - (hp as Vector3)
			d.y = 0.0
			if d.length() < 2.6:
				hidden = true
				break
	p.set("is_hidden", hidden)
	var hl: Label3D = p.get("hide_label")
	if hl:
		hl.visible = hidden

func _xz_rect_has(r: Rect2, p: Vector3) -> bool:
	return r.has_point(Vector2(p.x, p.z))

# ---------------------------------------------------------------- taken / escape / pursuit
func on_cat_taken(npc: Node) -> void:
	if state != "play":
		return
	var lost_pts: int = apply_capture_penalty()
	if lost_pts > 0:
		show_message("⭐ Taken! You lost %d points (20%% of your score)." % lost_pts, 2.5)
	captor = npc
	capture_return_pos = player.global_position
	pursuers.erase(npc)
	# v0.6 CAPTURE CUTSCENE: bend down, scoop him up, carry him away,
	# fade into that captor's escape room (~5.2s, skippable after 1s).
	state = "cutscene"
	cutscene_t = 0.0
	cutscene_from = player.global_position
	var f: Vector3 = -npc.global_transform.basis.z
	f.y = 0.0
	cutscene_dir = f.normalized() if f.length() > 0.05 else Vector3(0, 0, 1)
	if player: player.set("frozen", true)
	sfx_notice.play()
	show_message("💛 " + str(npc.get("display_name")) + " scooped you up! \"Come home with me, kitty!\"  (tap to skip)", 3.0)

func _held_pos(npc: Node) -> Vector3:
	var f: Vector3 = -npc.global_transform.basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.05 else Vector3(0, 0, 1)
	return npc.global_position + f * 0.48 + Vector3(0, 1.02, 0)

func _process_cutscene(delta: float) -> void:
	cutscene_t += delta
	var npc = captor
	if npc == null:
		_enter_escape()
		return
	var mdl = npc.get("model")
	if cutscene_t < 1.1:
		# bend down toward the cat
		var k: float = cutscene_t / 1.1
		if mdl:
			mdl.rotation.x = 0.38 * sin(k * PI * 0.5)
		player.velocity = Vector3.ZERO
	elif cutscene_t < 1.9:
		# lift him up into their arms
		if mdl:
			mdl.rotation.x = 0.38 * (1.0 - (cutscene_t - 1.1) / 0.8)
		var k2: float = clampf((cutscene_t - 1.1) / 0.8, 0.0, 1.0)
		player.global_position = player.global_position.lerp(_held_pos(npc), k2)
		player.rotation.y = lerp_angle(player.rotation.y, npc.rotation.y, k2)
	else:
		# walk away carrying him; camera follows the pair
		if mdl:
			mdl.rotation.x = 0.0
		npc.set("velocity", cutscene_dir * 2.2)
		npc.call("move_and_slide")
		npc.call("_animate", delta, 2.2)
		player.global_position = _held_pos(npc)
		player.rotation.y = npc.rotation.y
		if cutscene_t >= 4.4 and fade_rect:
			fade_rect.color.a = clampf((cutscene_t - 4.4) / 0.8, 0.0, 1.0)
	if cutscene_t >= 5.2:
		_enter_escape()

func skip_cutscene() -> void:
	if state != "cutscene":
		return
	if fade_rect:
		fade_rect.color.a = 1.0
	_enter_escape()

# ---------------------------------------------------------------- escape variants (v0.7 REDESIGN)
# ONE logical exit mechanism per capture — Michael: the v0.6 chains
# (knock a book / vase, hop the sofa, THEN the real mechanism) felt
# like the same arbitrary checklist every time. Now each capture is
# a single way out that you find and work, themed to the captor:
# the WINDOW (flip the latch, push the sash — two workings, one
# mechanism), the PET DOOR flap, the back-door BOLT, or the CARRIER
# door you wriggle open from inside (that house keeps carriers by
# the door — you bolt straight out). Since v1.1 each working is the
# escape PANEL combo (prompt -> panel -> down/up/down/up/PAW -> the
# visible escape); see the panel section below.
# Never the same mechanism twice in a row. 15-45s, always doable.
func _variant_pool(ctype: String) -> Array:
	match ctype:
		"kid":
			return [["petdoor"], ["latch", "winpush"], ["carrier"]]
		"dogwalker":
			return [["petdoor"], ["carrier"], ["latch", "winpush"]]
		"shopkeeper":
			return [["bolt"], ["latch", "winpush"], ["petdoor"]]
		_:
			return [["latch", "winpush"], ["petdoor"], ["carrier"]]

func _pick_escape_variant(ctype: String) -> Array:
	var pool: Array = _variant_pool(ctype)
	var idx: int = rng.randi_range(0, pool.size() - 1)
	var guard: int = 0
	while pool.size() > 1 and ctype == prev_variant_type and idx == prev_variant_idx and guard < 8:
		idx = rng.randi_range(0, pool.size() - 1)
		guard += 1
	prev_variant_idx = idx
	prev_variant_type = ctype
	escape_variant_idx = idx
	var steps: Array = []
	for kind in pool[idx]:
		steps.append({"kind": kind})
	return steps

func current_escape_kinds() -> Array:
	var out: Array = []
	for s in escape_steps:
		out.append(s["kind"])
	return out

func _step_zone(kind: String) -> Rect2:
	match kind:
		"latch", "winpush": return window_zone
		"petdoor": return petdoor_zone
		"bolt": return bolt_zone
		"carrier": return carrier_zone
	return Rect2()

func _step_text(kind: String) -> String:
	# v1.2: the hint points you at the mechanism AND at the way in —
	# press PAW when you get there (Michael's fix: pawing is how you
	# activate the puzzle; the prompt says so too). It also names the
	# distraction game: she's in the room, so knock something over
	# before you work the door, or she'll notice in about a second.
	match kind:
		"carrier": return "You're shut in a CARRIER! Press PAW by it to wriggle the door — but knock something over first, she's watching!"
		"latch": return "Find the WINDOW! Press PAW by it to work the brass latch — knock something over first, she's watching!"
		"winpush": return "The latch is open! Press PAW by the window to push it up — keep her distracted!"
		"petdoor": return "Find the PET DOOR! Press PAW by it to work the flap — knock something over first, she's watching!"
		"bolt": return "Find the BACK DOOR! Press PAW by it to slide the bolt — knock something over first, she's watching!"
	return ""

func _update_escape_label() -> void:
	if escape_step < escape_steps.size():
		escape_label.text = "🚪 ESCAPE %d/%d: %s" % [escape_step + 1, escape_steps.size(), _step_text(escape_steps[escape_step]["kind"])]

func _reset_escape_props() -> void:
	if book_node:
		book_node.position = book_home_pos
		book_node.rotation = Vector3.ZERO
	if latch_pivot:
		latch_pivot.rotation.z = 0.0
		latch_pivot.position = latch_base_pos
	if sash_node:
		sash_node.position.y = sash_base_y
	if bolt_node:
		bolt_node.position.z = bolt_base_z
	if backdoor_pivot:
		backdoor_pivot.rotation.y = 0.0
	if flap_node:
		flap_node.rotation.x = 0.0
	if carrier_door:
		carrier_door.rotation.y = 0.0
	if carrier_node:
		carrier_node.rotation.z = 0.0
	if vase_node and not vase_home.is_empty():
		vase_node.position = vase_home["pos"]
		vase_node.rotation = vase_home["rot"]
	# v1.1: panel puzzle state fully reset for the next capture.
	escape_anim_t = -1.0
	combo_index = 0
	carrier_shake = 0.0
	if escape_panel:
		escape_panel.hide_panel()
	if escape_prompt_btn:
		escape_prompt_btn.visible = false
	# v1.2: distraction props upright, captor back out of the room,
	# the way out CLOSED and plugged again, all room state cleared.
	for p in distract_props:
		p["toppled"] = false
		p["anim_t"] = 1.0
		(p["pivot"] as Node3D).rotation = p["home_rot"]
	distract_queue.clear()
	captor_prop = {}
	captor_room_state = "off"
	righting_t = 0.0
	captor_trip_t = 0.0
	notice_t = 0.0
	notice_cooldown = 0.0
	shoo_t = -1.0
	exit_open = false
	exit_open_kind = ""
	_set_blocker(window_blocker, true)
	_set_blocker(petdoor_blocker, true)
	for cl in crash_labels:
		if is_instance_valid(cl["node"]):
			(cl["node"] as Node).queue_free()
	crash_labels.clear()
	if distract_label:
		distract_label.visible = false
	if distract_bar_bg:
		distract_bar_bg.visible = false
	if prop_prompt_btn:
		prop_prompt_btn.visible = false

func _apply_escape_theme(ctype: String) -> void:
	for tg in theme_groups.values():
		(tg as Node3D).visible = false
	var grp: Node3D = theme_groups.get(ctype, theme_groups.get("woman"))
	if grp:
		grp.visible = true
	if room_title_label:
		match ctype:
			"kid": room_title_label.text = "🧸 A family house — kid energy everywhere!"
			"dogwalker": room_title_label.text = "🐶 The dog walker's house — mind the dog!"
			"shopkeeper": room_title_label.text = "🛒 The shop's back room — find the back door!"
			_: room_title_label.text = "💛 A cozy cat-lover's home — find a way out!"

func _enter_escape() -> void:
	state = "escape"
	fade_in_t = 0.6 # fade back in from the capture cutscene
	if pursuit_label:
		pursuit_label.text = "" # v1.2 hygiene: a caught-mid-pursuit cat shouldn't carry the town pursuit banner into the room
	if captor:
		var cm = captor.get("model")
		if cm:
			cm.rotation.x = 0.0
	var ctype := "woman"
	if captor and captor.get("npc_type") != null:
		ctype = str(captor.get("npc_type"))
	escape_steps = _pick_escape_variant(ctype)
	escape_step = 0
	escape_prog = 0.0
	_reset_escape_props()
	_apply_escape_theme(ctype)
	if escape_steps.size() > 0 and escape_steps[0]["kind"] == "carrier":
		player.global_position = escape_origin + Vector3(-6, 0.3, 7.5) # you start INSIDE the carrier
	else:
		player.global_position = escape_origin + Vector3(0, 0.3, 6)
	if player: player.set("frozen", false)
	# v1.2: the captor is IN THE ROOM with the cat (Michael's design) —
	# settling him in, tidying up. She ambles between the room anchors
	# (see _update_captor_room); her town chase state is cleared so she
	# reads as a calm host, never angry.
	if captor:
		captor.set("mode", "wander")
		captor.set("notice", 0.0)
		captor.set("grab_progress", 0.0)
		(captor as Node3D).global_position = escape_origin + Vector3(-3.5, 0.25, 1.8)
		captor_anchor_idx = 0
		captor_room_state = "idle"
		captor_room_wait = 2.0
		_room_face(player.global_position, 1.0)
		captor.call("show_bubble", "There we are — home sweet home! 💛", 2.6)
	_update_escape_label()
	show_message("You are inside their home — and so is she! Knock something over to distract her, then work the way out! 🐾", 3.6)

func _advance_escape_step() -> void:
	escape_step += 1
	escape_prog = 0.0
	combo_index = 0
	if escape_step >= escape_steps.size():
		escape_label.text = "🎉 You're out!"
		_complete_escape()
	else:
		_update_escape_label()

func _escape_interact() -> void:
	# v1.2: PAW is THE way in (Michael's fix — the v1.1 panel needed a
	# prompt tap he never found). PAW / E at the mechanism opens the
	# panel; PAW by a standing prop topples it for a distraction;
	# anywhere else it just points you at the hint.
	if escape_step >= escape_steps.size() or escape_anim_t >= 0.0 or exit_open:
		return
	if player:
		player.call("do_paw_swipe")
	if _escape_at_mechanism():
		_open_escape_panel()
	elif topple_prop_at_cat():
		pass # the crash + message in topple_prop say it all
	else:
		show_message("Paw the way out to work it — or paw a plant, book or vase over to distract her! 🐾", 1.8)

# ---------------------------------------------------------------- v1.1 escape PANEL puzzle
# Michael's flow (2026-11-16): walk to the mechanism and a big
# PROMPT appears — no hunting, no random swiping. Tapping it (or
# PAW/E) opens the PANEL: a close-up picture of the mechanism. Swipe
# the combination ON THE PICTURE — down, up, down, up, then PAW —
# each correct input lights a chip and works the real 3D mechanism a
# notch; a wrong one gently slips the sequence back. Completing the
# combo on the LAST step plays the visible escape: the cat works the
# mechanism and slips out in front of you, no hard cut.
func _escape_at_mechanism() -> bool:
	# v1.2: a generous RADIUS around the exit point (was: axis-aligned
	# rect zones against the walls). No facing requirement, no precise
	# spot to find — if the cat is within ESCAPE_TRIGGER_RADIUS of the
	# way out, PAW works. The rect zones (_step_zone) are retired.
	if state != "escape" or escape_step >= escape_steps.size() or player == null or exit_open:
		return false
	var kind: String = escape_steps[escape_step]["kind"]
	var d: Vector3 = player.global_position - _escape_exit_pos(kind)
	d.y = 0.0
	return d.length() < ESCAPE_TRIGGER_RADIUS

# World spot of each exit, for the escape camera's framing.
func _escape_exit_pos(kind: String) -> Vector3:
	var o: Vector3 = escape_origin
	match kind:
		"latch", "winpush":
			return o + Vector3(0, 0.8, -9.5)
		"petdoor":
			return o + Vector3(6, 0.6, -9.6)
		"bolt":
			return o + Vector3(13.4, 1.0, 3.4)
		"carrier":
			return o + Vector3(-6, 0.5, 7.9)
	return player.global_position

# Camera vantage per exit (see the ESCAPE CAMERA note in
# _update_camera): clear of the furniture, looking at the exit.
func _escape_cam_pos(kind: String) -> Vector3:
	var o: Vector3 = escape_origin
	match kind:
		"latch", "winpush":
			return o + Vector3(1.8, 1.7, -4.6)
		"petdoor":
			return o + Vector3(8.6, 1.6, -4.8)
		"bolt":
			return o + Vector3(4.5, 2.0, 1.6)
		"carrier":
			return o + Vector3(-10.5, 1.6, 9.0)
	return player.global_position + Vector3(0, 1.5, 5.0)

func _escape_prompt_text(kind: String) -> String:
	# v1.2: the prompt INSTRUCTS PAWING (Michael's fix) — tapping the
	# prompt still works, but PAW is the verb the player is taught.
	match kind:
		"latch": return "🐾 PAW the window latch!"
		"winpush": return "🐾 PAW to push the window open!"
		"petdoor": return "🐾 PAW the pet door!"
		"bolt": return "🐾 PAW the bolt!"
		"carrier": return "🐾 PAW to wriggle out of the carrier!"
	return "🐾 PAW the way out!"

func _on_escape_prompt_pressed() -> void:
	if _escape_at_mechanism() and escape_anim_t < 0.0:
		_open_escape_panel()

func _open_escape_panel() -> void:
	var kind: String = escape_steps[escape_step]["kind"]
	combo_index = 0
	escape_prog = 0.0
	notice_t = 0.0 # v1.2: the notice clock starts as the panel opens
	# (notice_cooldown is NOT cleared: right after an interruption she
	# is still suspicious and the grace is halved — see _update_escape_room.)
	_update_mechanism_visuals(kind)
	if escape_panel:
		escape_panel.open_for(kind)
	if player:
		player.set("frozen", true) # the cat stays put while you work the panel
	if escape_prompt_btn:
		escape_prompt_btn.visible = false

func _close_escape_panel() -> void:
	if escape_panel:
		escape_panel.hide_panel()
	if player and escape_anim_t < 0.0:
		player.set("frozen", false)

# One entry point for ALL panel inputs (picture swipes, the panel's
# PAW button, PC arrow keys + Space, and the automated tests).
func escape_panel_input(inp: String) -> void:
	if escape_panel == null or not escape_panel.visible:
		return
	if state != "escape" or escape_step >= escape_steps.size() or escape_anim_t >= 0.0:
		return
	var kind: String = escape_steps[escape_step]["kind"]
	var expected: String = str(ESCAPE_COMBO[combo_index])
	if inp == expected:
		combo_index += 1
		escape_prog = float(combo_index) / float(ESCAPE_COMBO.size())
		_update_mechanism_visuals(kind)
		if kind == "carrier":
			carrier_shake = 0.25 # the carrier rattles as you wriggle its door
		escape_panel.set_combo(combo_index)
		if combo_index >= ESCAPE_COMBO.size():
			_panel_combo_success()
	else:
		# Gentle reset — and forgiving: a DOWN swipe counts as the
		# first step of the new try, since the combo starts with one.
		combo_index = 1 if inp == str(ESCAPE_COMBO[0]) else 0
		escape_prog = float(combo_index) / float(ESCAPE_COMBO.size())
		_update_mechanism_visuals(kind)
		escape_panel.set_combo(combo_index)
		escape_panel.show_slip("Oops — it slipped back! Start again: ↓ ↑ ↓ ↑ then PAW 🐾")

func _panel_combo_success() -> void:
	var kind: String = escape_steps[escape_step]["kind"]
	if escape_panel:
		escape_panel.hide_panel()
	if escape_step < escape_steps.size() - 1:
		# One mechanism, two workings (the window: latch, then push).
		# The worked mechanism STAYS worked — only the combo resets.
		sfx_notice.play()
		show_message("Click! The latch flipped open!", 1.8)
		if player:
			player.set("frozen", false)
		_advance_escape_step()
	else:
		# v1.2: NO scripted exit any more (Michael: "I want the door
		# to open and you can walk outside"). The way OPENS and the
		# player walks the cat out himself — _check_exit_crossed in
		# _process_escape finishes the escape at the threshold.
		_open_exit(kind)

# ------------------------------------------------- v1.2 open exit
# The combo is done: the mechanism finishes opening for real (sash
# up, flap unlatched, door swung wide, carrier door open) and CONTROL
# RETURNS TO THE PLAYER. The opening stays open — no timer, nothing
# to re-do — so the cat can never be soft-locked inside. For the
# carrier the cat still has the house to leave: the pet door is the
# way out (its plug lifts too — walking out is locomotion, not a
# second puzzle; the suite's one-mechanism rule is about combos).
func _open_exit(kind: String) -> void:
	exit_open = true
	exit_open_kind = kind
	escape_prog = 1.0
	_update_mechanism_visuals(kind)
	if player:
		player.set("frozen", false)
		player.call("do_paw_swipe")
	sfx_notice.play()
	match kind:
		"latch", "winpush":
			if sash_node:
				sash_node.position.y = sash_base_y + 1.2 # the rest of the way up
			_set_blocker(window_blocker, false)
			show_message("The window's OPEN — hop out! 🪟🐾", 2.6)
		"petdoor":
			if flap_node:
				flap_node.rotation.x = 0.55 # unlatched and ajar
			_set_blocker(petdoor_blocker, false)
			show_message("The pet door's unlocked — push through! 🐾", 2.6)
		"bolt":
			if backdoor_pivot:
				backdoor_pivot.rotation.y = -1.75 # swung wide into the room
			show_message("The back door's OPEN — walk out! 🚪🐾", 2.6)
		"carrier":
			_set_blocker(petdoor_blocker, false)
			if flap_node:
				flap_node.rotation.x = 0.55
			show_message("You're out of the carrier! Now slip out the PET DOOR! 🐾", 3.0)
	if escape_label:
		escape_label.text = "🚪 The way is OPEN — walk out!"
	if captor and not captor_distracted():
		captor.call("show_bubble", "Oh my — how did you…? 😮", 2.2)

# The escape completes when the cat actually crosses the threshold —
# that's when the +3 and the 60 s pursuit begin (unchanged contract).
func _check_exit_crossed() -> void:
	if player == null:
		return
	var p: Vector3 = player.global_position
	var o: Vector3 = escape_origin
	var crossed := false
	match exit_open_kind:
		"latch", "winpush":
			crossed = p.z < o.z - 10.35 and absf(p.x - o.x) < 3.1
		"petdoor", "carrier":
			crossed = p.z < o.z - 10.35 and p.x > o.x + 4.6 and p.x < o.x + 7.4
		"bolt":
			crossed = p.x > o.x + 14.35 and p.z > o.z + 2.1 and p.z < o.z + 4.7
	if crossed:
		exit_open = false
		_complete_escape()

# The unlatched pet-door flap swings as the cat pushes through it.
func _update_flap_push() -> void:
	if flap_node == null or player == null:
		return
	if exit_open_kind != "petdoor" and exit_open_kind != "carrier":
		return
	var fp: Vector3 = escape_origin + Vector3(6, 0, -9.6)
	var d: Vector3 = player.global_position - fp
	d.y = 0.0
	var target: float = 1.7 if d.length() < 1.3 else 0.55
	flap_node.rotation.x = lerpf(flap_node.rotation.x, target, 0.35)

# ------------------------------------------------- v1.2 distractions
# The captor's room routine. She ambles between anchors tidying up;
# a toppled prop pulls her over at a hurry and keeps her busy for the
# walk + DISTRACT_RIGHT_TIME of righting (bent over it, restoring it
# in the last second). While the panel is open she otherwise STANDS
# AND WATCHES the cat — that's what makes the undistracted notice
# clock real. Movement reuses the capture cutscene's proven pattern:
# main sets velocity and calls move_and_slide + _animate from
# _process, because person.gd idles its NPCs outside "play" state.
func _room_anchors() -> Array:
	var o: Vector3 = escape_origin
	return [o + Vector3(-3.5, 0, 1.8), o + Vector3(11.6, 0, -4.5), o + Vector3(11.3, 0, 6.4), o + Vector3(-4.2, 0, 8.0)]

func _nearest_anchor() -> Vector3:
	var anchors: Array = _room_anchors()
	var best: Vector3 = anchors[0]
	var bd := 1e18
	for i in range(anchors.size()):
		var d: float = (captor as Node3D).global_position.distance_to(anchors[i])
		if d < bd:
			bd = d
			best = anchors[i]
			captor_anchor_idx = i
	return best

func captor_distracted() -> bool:
	return captor_room_state == "to_prop" or captor_room_state == "righting"

func distraction_time_left() -> float:
	var t := 0.0
	if captor_room_state == "to_prop" and not captor_prop.is_empty() and captor:
		var d: Vector3 = (captor as Node3D).global_position - (captor_prop["stand"] as Vector3)
		d.y = 0.0
		t += d.length() / DISTRACT_WALK_SPEED + DISTRACT_RIGHT_TIME
	elif captor_room_state == "righting":
		t += righting_t
	t += float(distract_queue.size()) * (DISTRACT_RIGHT_TIME + 2.0) # a queued prop is another errand after this one
	return t

func _room_face(world_pos: Vector3, delta: float) -> void:
	if captor == null:
		return
	var npc := captor as Node3D
	var to: Vector3 = world_pos - npc.global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	npc.rotation.y = lerp_angle(npc.rotation.y, atan2(to.x, to.z), minf(1.0, 8.0 * delta))

func _room_move_toward(target: Vector3, speed: float, delta: float) -> bool:
	# Returns true on arrival. See the cutscene pattern note above.
	if captor == null:
		return true
	var npc := captor as CharacterBody3D
	var to: Vector3 = target - npc.global_position
	to.y = 0.0
	if to.length() < 0.45:
		npc.velocity = Vector3(0, npc.velocity.y, 0)
		return true
	var dir: Vector3 = to.normalized()
	npc.velocity = Vector3(dir.x * speed, npc.velocity.y, dir.z * speed)
	npc.move_and_slide()
	npc.call("_animate", delta, speed)
	_room_face(npc.global_position + dir, delta)
	return false

func _update_captor_room(delta: float) -> void:
	if captor == null or captor_room_state == "off":
		return
	var panel_open: bool = escape_panel != null and escape_panel.visible
	# Panel open + not busy with a prop = she stands and watches the
	# cat at the door. (Shooing continues — she's already coming over.)
	if panel_open and captor_room_state != "to_prop" and captor_room_state != "righting" and captor_room_state != "shoo":
		_room_face(player.global_position, delta)
		return
	match captor_room_state:
		"idle":
			captor_room_wait -= delta
			if captor_room_wait <= 0.0:
				var anchors: Array = _room_anchors()
				captor_anchor_idx = (captor_anchor_idx + 1) % anchors.size()
				captor_room_target = anchors[captor_anchor_idx]
				captor_room_state = "walk"
		"walk", "return":
			if _room_move_toward(captor_room_target, ROOM_WALK_SPEED, delta):
				captor_room_state = "idle"
				captor_room_wait = randf_range(2.5, 4.5)
		"to_prop":
			captor_trip_t += delta
			if _room_move_toward(captor_prop["stand"], DISTRACT_WALK_SPEED, delta) or captor_trip_t > 12.0:
				captor_room_state = "righting"
				righting_t = DISTRACT_RIGHT_TIME
				captor_trip_t = 0.0
				_room_face((captor_prop["pivot"] as Node3D).global_position, 1.0)
				captor.call("show_bubble", "Let's get you back up… 💛", 1.8)
		"righting":
			righting_t -= delta
			_room_face((captor_prop["pivot"] as Node3D).global_position, delta)
			var mdl = captor.get("model")
			if mdl:
				(mdl as Node3D).rotation.x = 0.45 + sin(float(Time.get_ticks_msec()) * 0.01) * 0.04 # bent over it, fussing
			if righting_t <= 1.0:
				# The last second: the prop rises back into place.
				var u: float = clampf(1.0 - righting_t, 0.0, 1.0)
				(captor_prop["pivot"] as Node3D).rotation = (captor_prop["topple_rot"] as Vector3).lerp(captor_prop["home_rot"] as Vector3, _ease(u))
			if righting_t <= 0.0:
				captor_prop["toppled"] = false
				(captor_prop["pivot"] as Node3D).rotation = captor_prop["home_rot"]
				if mdl:
					(mdl as Node3D).rotation.x = 0.0
				captor.call("show_bubble", "There we go! 💛", 1.6)
				if not distract_queue.is_empty():
					captor_prop = distract_queue.pop_front()
					captor_trip_t = 0.0
					captor_room_state = "to_prop"
				else:
					captor_prop = {}
					captor_room_state = "return"
					captor_room_target = _nearest_anchor()
		"shoo":
			# She hurries over to the cat (kindly) after spotting him at
			# the door, then goes back to her tidying.
			captor_trip_t += delta
			var cp: Vector3 = (captor as Node3D).global_position
			var pp: Vector3 = player.global_position if player else cp
			var dd: Vector3 = pp - cp
			dd.y = 0.0
			if dd.length() < 1.15 or captor_trip_t > 3.0:
				captor_trip_t = 0.0
				captor_room_state = "return"
				captor_room_target = _nearest_anchor()
			else:
				_room_move_toward(pp, DISTRACT_WALK_SPEED, delta)

func _nearest_standing_prop() -> Dictionary:
	if player == null:
		return {}
	var best: Dictionary = {}
	var bd := 1.7 # paw reach (XZ) — generous, no precise spot needed
	for p in distract_props:
		if bool(p["toppled"]):
			continue
		var d: Vector3 = player.global_position - (p["base"] as Vector3)
		d.y = 0.0
		if d.length() < bd:
			bd = d.length()
			best = p
	return best

func topple_prop_at_cat() -> bool:
	var p: Dictionary = _nearest_standing_prop()
	if p.is_empty():
		return false
	if player:
		player.call("do_paw_swipe")
	topple_prop(p)
	return true

func topple_prop(p: Dictionary) -> void:
	if p.is_empty() or bool(p["toppled"]):
		return
	p["toppled"] = true
	p["anim_t"] = 0.0
	if sfx_crash:
		sfx_crash.play()
	var lbl := _label3d(self, "💥 CRASH!", (p["base"] as Vector3) + Vector3(0, 1.7, 0), 72, Color(1.0, 0.8, 0.3))
	crash_labels.append({"node": lbl, "t": 0.0, "y0": lbl.position.y})
	if captor:
		captor.call("show_bubble", str(p["bubble"]), 2.2)
		if captor_room_state == "idle" or captor_room_state == "walk" or captor_room_state == "return" or captor_room_state == "shoo":
			captor_prop = p
			captor_trip_t = 0.0
			captor_room_state = "to_prop"
		else:
			distract_queue.append(p) # she's already busy — this one queues
	show_message("💥 You knocked over %s! She's distracted — quick, work the way out! 🐾" % str(p["name"]), 2.8)

func _on_prop_prompt_pressed() -> void:
	if state == "escape":
		topple_prop_at_cat()

# She noticed the cat at the door: the panel closes, the combo is
# lost, and the cat is kindly shooed off with a little hop. NO fail
# state, no score loss — the only cost is the combo and her being
# extra watchful (halved grace) for a few seconds after.
func _interrupt_escape() -> void:
	if escape_step >= escape_steps.size():
		return
	var kind: String = escape_steps[escape_step]["kind"]
	if escape_panel:
		escape_panel.hide_panel()
	combo_index = 0
	escape_prog = 0.0
	_update_mechanism_visuals(kind)
	notice_t = 0.0
	notice_cooldown = NOTICE_COOLDOWN
	if player:
		player.set("frozen", false)
	if sfx_notice:
		sfx_notice.play()
	if captor:
		captor.call("show_bubble", "What are you up to, little one? 💛", 2.4)
		captor_trip_t = 0.0
		captor_room_state = "shoo"
	if player:
		var exitp: Vector3 = _escape_exit_pos(kind)
		var away: Vector3 = player.global_position - exitp
		away.y = 0.0
		if away.length() < 0.2:
			away = escape_origin - exitp
			away.y = 0.0
		away = away.normalized()
		shoo_from = player.global_position
		shoo_to = shoo_from + away * 1.9
		var o: Vector3 = escape_origin
		shoo_to.x = clampf(shoo_to.x, o.x - 12.5, o.x + 12.5)
		shoo_to.z = clampf(shoo_to.z, o.z - 8.6, o.z + 8.6)
		shoo_to.y = shoo_from.y
		shoo_t = 0.0
		player.set("frozen", true)
		player.call("do_paw_swipe")
	show_message("👀 She spotted you at the door! Knock something over to distract her first! 🐾", 3.0)

# Per-frame room life: shoo hop, topple falls, crash cues, the
# captor's routine, the notice clock, prompts and the HUD.
func _update_escape_room(delta: float) -> void:
	if shoo_t >= 0.0 and player:
		shoo_t += delta
		var u: float = clampf(shoo_t / 0.45, 0.0, 1.0)
		var pos: Vector3 = shoo_from.lerp(shoo_to, _ease(u))
		pos.y = shoo_from.y + sin(u * PI) * 0.22
		player.global_position = pos
		player.set("velocity", Vector3.ZERO)
		if u >= 1.0:
			shoo_t = -1.0
			if escape_panel == null or not escape_panel.visible:
				player.set("frozen", false)
	for p in distract_props:
		if float(p["anim_t"]) < 1.0:
			p["anim_t"] = minf(1.0, float(p["anim_t"]) + delta / 0.35)
			(p["pivot"] as Node3D).rotation = (p["home_rot"] as Vector3).lerp(p["topple_rot"] as Vector3, _ease(float(p["anim_t"])))
	for i in range(crash_labels.size() - 1, -1, -1):
		var cl: Dictionary = crash_labels[i]
		cl["t"] = float(cl["t"]) + delta
		var node = cl["node"]
		if is_instance_valid(node):
			(node as Node3D).position.y = float(cl["y0"]) + float(cl["t"]) * 0.8
			(node as Label3D).modulate.a = clampf(1.1 - float(cl["t"]), 0.0, 1.0)
		if float(cl["t"]) > 1.1:
			if is_instance_valid(node):
				(node as Node).queue_free()
			crash_labels.remove_at(i)
	_update_captor_room(delta)
	# The notice clock: only an UNDISTRACTED panel visit counts down.
	var panel_open: bool = escape_panel != null and escape_panel.visible
	if panel_open:
		var grace: float = NOTICE_GRACE * (0.5 if notice_cooldown > 0.0 else 1.0)
		if captor_distracted():
			notice_t = 0.0
		else:
			notice_t += delta
			if notice_t >= grace:
				_interrupt_escape()
				panel_open = false
		if panel_open and escape_panel.visible:
			if captor_distracted():
				var left: float = distraction_time_left()
				var what: String = str(captor_prop.get("name", "the mess")) if not captor_prop.is_empty() else "the mess"
				escape_panel.set_status("💥 She's busy with %s — %.0fs!" % [what, ceil(left)], clampf(left / 12.0, 0.0, 1.0), false)
			else:
				escape_panel.set_status("👀 She's watching — she'll notice you!", clampf(notice_t / grace, 0.0, 1.0), true)
	else:
		notice_t = 0.0
		if notice_cooldown > 0.0:
			notice_cooldown -= delta
	if prop_prompt_btn:
		var near: Dictionary = _nearest_standing_prop()
		var show_prop: bool = not near.is_empty() and not panel_open and not exit_open and escape_anim_t < 0.0 and shoo_t < 0.0
		prop_prompt_btn.visible = show_prop
		if show_prop:
			prop_prompt_btn.text = "🐾 Paw %s over!" % str(near["name"])
	_update_distract_hud()

func _update_distract_hud() -> void:
	if distract_label == null:
		return
	var panel_open: bool = escape_panel != null and escape_panel.visible
	var show: bool = state == "escape" and not panel_open and escape_anim_t < 0.0
	distract_label.visible = show
	if not show:
		distract_bar_bg.visible = false
		return
	if exit_open:
		distract_label.text = "🚪 The way out is OPEN — walk out, quickly!"
		distract_bar_bg.visible = false
	elif captor_distracted():
		var left: float = distraction_time_left()
		var what: String = str(captor_prop.get("name", "the mess")) if not captor_prop.is_empty() else "the mess"
		distract_label.text = "💥 She's busy with %s — %.0fs to work the way out!" % [what, ceil(left)]
		distract_bar_bg.visible = true
		distract_bar_fill.visible = true
		distract_bar_fill.color = Color(0.45, 0.9, 0.45, 0.95)
		distract_bar_fill.position = Vector2(2, 2)
		distract_bar_fill.size = Vector2(516.0 * clampf(left / 12.0, 0.0, 1.0), 8)
	else:
		distract_label.text = "👀 She's in the room with you — knock something over to distract her! 🐾"
		distract_bar_bg.visible = false

func _update_mechanism_visuals(kind: String) -> void:
	match kind:
		"latch":
			if latch_pivot:
				latch_pivot.rotation.z = -escape_prog * 1.85 # lever swings UP = unlocked
				latch_pivot.position = latch_base_pos
		"winpush":
			if sash_node:
				sash_node.position.y = sash_base_y + escape_prog * 0.15 # it budges as you push
		"bolt":
			if bolt_node:
				bolt_node.position.z = bolt_base_z + escape_prog * 0.5
		"petdoor":
			if flap_node:
				flap_node.rotation.x = escape_prog * 1.0
		"carrier":
			if carrier_door:
				carrier_door.rotation.y = -escape_prog * 1.5

# ---------------------------------------------------------------- the visible escape (v1.1)
# The combo is done — now you WATCH it happen: the mechanism finishes
# opening and the cat slips through the exit over ~2.3 s, fading out
# only as he passes through, then _complete_escape picks the flow up
# exactly where it always did (bonus, teleport home-side, pursuit).
func _start_escape_animation(kind: String) -> void:
	escape_anim_kind = kind
	escape_anim_t = 0.0
	escape_anim_pawed = false
	if player:
		escape_anim_from = player.global_position
		player.set("frozen", true)
		player.call("do_paw_swipe")
		match kind:
			"latch", "winpush", "petdoor":
				player.rotation.y = PI # face the exit (north wall)
			"bolt":
				player.rotation.y = PI * 0.5 # face the back door (+x)
			"carrier":
				player.rotation.y = 0.0 # face out of the carrier (+z)
	sfx_notice.play()
	match kind:
		"latch", "winpush": show_message("The window's open — out you go! 💛", 2.2)
		"petdoor": show_message("The flap gives — you squeeze through! 💛", 2.2)
		"bolt": show_message("Clunk! The bolt's open — out the back door! 💛", 2.2)
		"carrier": show_message("The carrier door pops open — out you wriggle! 💛", 2.2)

func _ease(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)

func _anim_seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)

func _update_escape_animation() -> void:
	if player == null:
		return
	var t: float = escape_anim_t
	var o: Vector3 = escape_origin
	var p0: Vector3 = escape_anim_from
	var pos: Vector3 = p0
	player.set("velocity", Vector3.ZERO)
	match escape_anim_kind:
		"latch", "winpush":
			# The sash slides the rest of the way up...
			if sash_node:
				sash_node.position.y = sash_base_y + 0.15 + _ease(_anim_seg(t, 0.0, 0.9)) * 1.05
			# ...the cat pads to the window, hops onto the sill, and
			# slips through the opening to the garden side.
			var sill := Vector3(o.x, 0.72, o.z - 9.35)
			var thru := Vector3(o.x, 0.35, o.z - 10.75)
			if t < 0.45:
				pos = p0
			elif t < 0.85:
				pos = p0.lerp(Vector3(o.x, 0.3, o.z - 8.55), _ease(_anim_seg(t, 0.45, 0.85)))
			elif t < 1.3:
				var u: float = _anim_seg(t, 0.85, 1.3)
				pos = Vector3(o.x, 0.3, o.z - 8.55).lerp(sill, _ease(u))
				pos.y += sin(u * PI) * 0.3
			elif t < 1.85:
				var u2: float = _anim_seg(t, 1.3, 1.85)
				pos = sill.lerp(thru, u2)
				pos.y += sin(u2 * PI) * 0.12
			else:
				pos = thru
		"petdoor":
			# The flap swings wide as the cat shoulders through it.
			if flap_node:
				var swing: float = 1.0 + 0.9 * sin(_anim_seg(t, 0.7, 1.6) * PI * 0.5)
				if t > 1.6:
					swing = lerpf(1.9, 0.5, _anim_seg(t, 1.6, 2.3))
				flap_node.rotation.x = swing
			var p1 := Vector3(o.x + 6.0, 0.3, o.z - 8.75)
			var p_mid := Vector3(o.x + 6.0, 0.78, o.z - 9.8)
			var p2 := Vector3(o.x + 6.0, 0.3, o.z - 10.85)
			if t < 0.45:
				pos = p0
			elif t < 0.8:
				pos = p0.lerp(p1, _ease(_anim_seg(t, 0.45, 0.8)))
			elif t < 1.25:
				# The flap sits high in the wall for a cat his size,
				# so he scrambles UP into the opening as he shoves
				# through — body in the hole, not under it.
				pos = p1.lerp(p_mid, _ease(_anim_seg(t, 0.8, 1.25)))
			elif t < 1.7:
				pos = p_mid.lerp(p2, _anim_seg(t, 1.25, 1.7))
			else:
				pos = p2
		"bolt":
			# The bolt is already slid (the combo did that) — the door
			# swings open and the cat trots through the doorway.
			if backdoor_pivot:
				backdoor_pivot.rotation.y = _ease(_anim_seg(t, 0.3, 0.95)) * -1.75 # swings INTO the room, fully visible
			var b1 := Vector3(o.x + 12.45, 0.3, o.z + 3.4)
			var b2 := Vector3(o.x + 14.75, 0.3, o.z + 3.4)
			if t < 0.5:
				pos = p0
			elif t < 0.95:
				pos = p0.lerp(b1, _ease(_anim_seg(t, 0.5, 0.95)))
			elif t < 1.85:
				pos = b1.lerp(b2, _ease(_anim_seg(t, 1.0, 1.85)))
			else:
				pos = b2
		"carrier":
			# The door is open (the combo worked it) — the cat hops
			# out of the carrier and lands on the rug, free.
			if carrier_node and t < 0.4:
				carrier_node.rotation.z = sin(t * 40.0) * 0.02 * (0.4 - t)
			elif carrier_node:
				carrier_node.rotation.z = 0.0
			var c1 := Vector3(o.x - 6.45, 0.3, o.z + 8.75)
			if t < 0.5:
				pos = p0
			elif t < 1.15:
				var u4: float = _anim_seg(t, 0.5, 1.15)
				pos = p0.lerp(c1, _ease(u4))
				pos.y += sin(u4 * PI) * 0.3
			else:
				pos = c1
				if t >= 1.2 and not escape_anim_pawed:
					escape_anim_pawed = true
					player.call("do_paw_swipe") # a little triumphant paw
	player.global_position = pos
	# Fade out only as he passes through, so the town-side arrival
	# (in _complete_escape) can fade back in — no hard cut anywhere.
	if fade_rect:
		fade_rect.color.a = clampf((t - (ESCAPE_ANIM_LEN - 0.5)) / 0.5, 0.0, 1.0)

func _process_escape(delta: float) -> void:
	if escape_anim_t >= 0.0:
		# Legacy scripted exit (v1.1) — unreachable since v1.2 replaced
		# it with the player-driven walk-out; kept inert for reference.
		escape_anim_t += delta
		_update_escape_animation()
		if escape_anim_t >= ESCAPE_ANIM_LEN:
			escape_anim_t = -1.0
			_complete_escape()
		return
	# v1.2: the room is alive every frame of the escape — the captor's
	# routine, toppling props, the notice clock, prompts and HUD.
	_update_escape_room(delta)
	if exit_open:
		# The way is open: the player walks the cat out himself. The
		# escape completes at the threshold (see _check_exit_crossed).
		_check_exit_crossed()
		_update_flap_push()
		if escape_prompt_btn:
			escape_prompt_btn.visible = false
		return
	if escape_step >= escape_steps.size():
		return
	# THE PROMPT: visible only while the cat stands at the current
	# mechanism with the panel closed — unmissable, and it says
	# exactly what to do.
	if escape_prompt_btn:
		var show_prompt: bool = _escape_at_mechanism() and (escape_panel == null or not escape_panel.visible)
		escape_prompt_btn.visible = show_prompt
		if show_prompt:
			escape_prompt_btn.text = _escape_prompt_text(escape_steps[escape_step]["kind"])
			var s: float = 1.0 + 0.03 * sin(float(Time.get_ticks_msec()) * 0.006)
			escape_prompt_btn.scale = Vector2(s, s)
	# Carrier shake decay (panel combo feedback).
	if carrier_shake > 0.0:
		carrier_shake -= delta
		if carrier_node:
			carrier_node.rotation.z = sin(float(Time.get_ticks_msec()) * 0.07) * 0.03 if carrier_shake > 0.0 else 0.0
func _complete_escape() -> void:
	apply_escape_bonus()
	state = "play"
	escape_label.text = ""
	fade_in_t = 0.6 # the threshold crossing fades over the town-side arrival — no visible pop
	# v1.2: the room goes quiet behind him — captor out of room mode,
	# any righting bend undone, room HUD/prompts hidden (the pursuit
	# below re-aims her at the town exactly as before).
	captor_room_state = "off"
	exit_open = false
	if distract_label:
		distract_label.visible = false
	if distract_bar_bg:
		distract_bar_bg.visible = false
	if prop_prompt_btn:
		prop_prompt_btn.visible = false
	if captor:
		var cm3 = captor.get("model")
		if cm3:
			(cm3 as Node3D).rotation.x = 0.0
	if escape_prompt_btn:
		escape_prompt_btn.visible = false
	if escape_panel:
		escape_panel.hide_panel()
	if player:
		player.set("frozen", false)
	player.global_position = capture_return_pos + Vector3(2.5, 0.3, 1.5)
	if captor:
		captor.global_position = capture_return_pos + Vector3(-4, 0.3, -2)
		if pursuers.size() < 2:
			pursuers[captor] = 60.0
			captor.call("start_pursuit")
	show_message("You escaped! +3 points 💛 They'll look for you for 60 seconds — hide in bushes or behind cars!", 4.0)

func _check_door(manual: bool) -> void:
	if player == null:
		return
	for i in range(houses.size()):
		var door: Vector3 = houses[i]["door"]
		if player.global_position.distance_to(door) < 2.8:
			if i == home_index:
				_win()
				return
			elif manual:
				show_message("🚪 Not home — this is " + houses[i]["address"] + ". Keep looking!", 2.5)
			return

func _win() -> void:
	state = "win"
	if player: player.set("frozen", true)
	touch_layer.visible = false
	sfx_win.play()
	win_label.text = "🎉 YOU'RE HOME! 🎉\n\n🏠 " + home_address + "\n\nYour real owner opens the door:\n\"There you are! I missed you!\" 💛\n\n⭐ Final score: %d  (🐾 %d pets · 🍪 %d treats)\nWell done, little explorer." % [score, pets_count, treats_count]
	win_panel.visible = true

# ---------------------------------------------------------------- per-frame
func _process(delta: float) -> void:
	_apply_joystick()
	_process_traffic(delta)
	# Splash song: replay while the player lingers on the splash.
	if state == "splash" and splash_song_player and splash_song_player.stream and not splash_song_player.playing:
		splash_song_player.volume_db = -9.0
		splash_song_player.play()
	# Publish the camera yaw so movement is camera-relative (cat.gd).
	if player:
		player.set("cam_yaw", look_yaw)
	# PC look keys: J/L orbit left/right, I/K tilt up/down.
	if state == "play" or state == "escape":
		var lk := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_J): lk.x -= 140.0 * delta
		if Input.is_physical_key_pressed(KEY_L): lk.x += 140.0 * delta
		if Input.is_physical_key_pressed(KEY_I): lk.y -= 140.0 * delta
		if Input.is_physical_key_pressed(KEY_K): lk.y += 140.0 * delta
		if lk != Vector2.ZERO:
			apply_look_drag(lk)
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0 and hint_label:
			hint_label.visible = false
	_update_camera(delta)
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_label.text = ""
	if meow_cooldown > 0.0: meow_cooldown -= delta
	if bark_msg_cooldown > 0.0: bark_msg_cooldown -= delta
	if latch_cooldown > 0.0: latch_cooldown -= delta
	# PURR (v0.6): town gameplay only — cat still ~3s, nobody chasing.
	# Starts at the 3s mark, stops the moment he moves / is chased /
	# is captured. The cat model adds the visual tell (see cat.gd).
	var any_chase := false
	for n in npcs:
		if str(n.get("mode")) == "chase" or str(n.get("mode")) == "pursue" or str(n.get("mode")) == "tell":
			any_chase = true
	# Stamina / adrenaline wiring + HUD bar (red segment only in chase).
	if player:
		player.call("set_chase_mode", any_chase and state == "play")
		if stamina_fill:
			var st: float = float(player.get("stamina"))
			var ad: float = float(player.get("adrenaline")) if any_chase else 0.0
			stamina_fill.size.x = 258.0 * clampf(st / 100.0, 0.0, 1.0)
			stamina_fill.color = Color(0.95, 0.6, 0.3, 0.95) if st < 30.0 else Color(0.45, 0.9, 0.45, 0.95)
			stamina_adren.size.x = 258.0 * clampf(ad / 100.0, 0.0, 1.0)
			stamina_adren.position.x = 17.0 + stamina_fill.size.x
			stamina_label.visible = any_chase
	# Pursuit-ender spots: slip through a cat gap mid-chase and every
	# active chase ends outright.
	if ender_cooldown > 0.0:
		ender_cooldown -= delta
	if state == "play" and any_chase and ender_cooldown <= 0.0 and player:
		for ep in ender_points:
			var ed: Vector3 = player.global_position - (ep as Vector3)
			ed.y = 0.0
			if ed.length() < 1.7:
				ender_cooldown = 5.0
				for n in npcs:
					if str(n.get("mode")) == "chase" or str(n.get("mode")) == "tell":
						n.call("end_chase_via_spot")
				show_message("🐾 You slipped through the cat gap — they can't follow!", 2.5)
				break
	var want_purr: bool = state == "play" and not collar_open and player != null and not bool(player.get("frozen")) and (float(player.get("idle_time")) >= 3.0 or bool(player.call("is_being_petted"))) and not any_chase # v0.9: he purrs while being petted, too
	if want_purr != purr_active:
		purr_active = want_purr
		if player:
			player.set("purring", want_purr)
		if purr_player:
			if want_purr:
				purr_player.play()
			else:
				purr_player.stop()
	if player:
		player.set("idle_allowed", state == "play" and not collar_open)
	# Collar zoom auto-close: a few seconds is enough to memorise
	# the address; the camera eases back out on its own.
	if collar_open:
		collar_timer -= delta
		if collar_timer <= 0.0:
			_close_collar()
	# Fade back in after the cutscene hands over to the escape room.
	if fade_in_t >= 0.0:
		fade_in_t -= delta
		if fade_rect:
			fade_rect.color.a = clampf(fade_in_t / 0.6, 0.0, 1.0)
		if fade_in_t <= 0.0:
			fade_in_t = -1.0
	if state == "cutscene":
		_process_cutscene(delta)
		return
	if state == "escape":
		_process_escape(delta)
		return
	if state != "play":
		return
	if pursuers.size() > 0:
		var finished: Array = []
		var best: float = 999.0
		for npc in pursuers.keys():
			pursuers[npc] = float(pursuers[npc]) - delta
			best = min(best, float(pursuers[npc]))
			if float(pursuers[npc]) <= 0.0:
				finished.append(npc)
		for npc in finished:
			pursuers.erase(npc)
			npc.call("stop_pursuit")
			show_message("Phew — they gave up looking and went back to their day. 💛", 2.5)
		if pursuers.size() > 0:
			pursuit_label.text = "💛 Being looked for: %d seconds left — hide!" % int(ceil(best))
		else:
			pursuit_label.text = ""
	else:
		pursuit_label.text = ""
	for i in range(houses.size()):
		if float(wrong_house_cd.get(i, 0.0)) > 0.0:
			wrong_house_cd[i] = float(wrong_house_cd[i]) - delta
	if player:
		for i in range(houses.size()):
			if i != home_index and player.global_position.distance_to(houses[i]["door"]) < 2.4 and float(wrong_house_cd.get(i, 0.0)) <= 0.0:
				wrong_house_cd[i] = 5.0
				show_message("🚪 Not home — this is " + houses[i]["address"] + ".", 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if state == "cutscene" and cutscene_t >= 1.0:
			skip_cutscene()
		elif state == "splash":
			dismiss_splash()
		elif state == "title" and (k == KEY_ENTER or k == KEY_SPACE):
			start_game()
		elif state == "play" or state == "escape":
			if escape_panel != null and escape_panel.visible:
				# v1.1 panel on PC: arrow keys swipe, Space/E is the PAW, Esc steps away.
				if k == KEY_DOWN:
					escape_panel_input("down")
				elif k == KEY_UP:
					escape_panel_input("up")
				elif k == KEY_SPACE or k == KEY_E:
					escape_panel_input("paw")
				elif k == KEY_ESCAPE:
					_close_escape_panel()
			elif k == KEY_E:
				_on_interact()
			elif k == KEY_C:
				_toggle_collar()
			elif k == KEY_M:
				_on_meow()
			elif k == KEY_SPACE:
				if player: player.try_hop()
