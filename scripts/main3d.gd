extends Node3D
## HOMEWARD v0.7 — 3D main controller.
## Full loop in a real 3D town: random home address per run (shown
## ONLY on the title screen at the start of the run),
## 3D animated cat + NPCs, notice->CHASE->grab capture, taken -> varied
## per-captor escape puzzles — since v1.1 a visible PANEL puzzle per
## mechanism (prompt -> panel -> the A/B button combo, randomly
## rolled per start since v1.0.21 -> the cat is seen slipping out),
## replacing the old swipe gestures,
## exactly 30s pursuit (max 2), win at the correct door. Landscape,
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
const TEX_CHAINLINK: Texture2D = preload("res://assets/textures/chainlink.png") # SHELTER PASS 2: diamond-mesh alpha texture for the kennel runs
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
const TownCatScript: GDScript = preload("res://scripts/town_cat.gd") # v1.0.22: the Meshy town cats
const TOWN_CAT_SCENES: Dictionary = {
	"town_tabby": preload("res://assets/models/town_tabby.glb"),
	"black_cat": preload("res://assets/models/black_cat.glb"),
	"white_cat": preload("res://assets/models/white_cat.glb"),
	"calico_cat": preload("res://assets/models/calico_cat.glb"),
	"gray_tabby": preload("res://assets/models/gray_tabby.glb"),
	"siamese_cat": preload("res://assets/models/siamese_cat.glb"),
	"tortoiseshell_cat": preload("res://assets/models/tortoiseshell_cat.glb"),
	"russian_blue_cat": preload("res://assets/models/russian_blue_cat.glb"),
}
const EscapePanelScript: GDScript = preload("res://scripts/escape_panel.gd")
const OpeningCutsceneScript: GDScript = preload("res://scripts/opening_cutscene.gd") # STORY PART 1: the opening cutscene + pound start module

var state: String = "splash" # splash | title | play | taken | escape | win
var rng := RandomNumberGenerator.new()
var houses: Array = [] # {address, pos:Vector3, door:Vector3}
var civic_lots: Array = [] # v1.0.29: {model, pos, facing, hx, hz} — Meshy civic/commercial buildings placed on converted house lots
var building_footprints: Array = [] # v1.0.29: {pos, hx, hz} rects for every Meshy building (civic lots + the bakery), used by the footprint queries
var home_index: int = 0
var home_address: String = ""
var player: CharacterBody3D = null
var npcs: Array = []
var town_cats: Array = [] # v1.0.22: the eight Meshy town cats wandering the streets
var cat_meow_count: int = 0 # v1.0.26 suite handle: town-cat meow-backs played
var cat_play_count: int = 0 # v1.0.26 suite handle: completed town-cat play sessions that scored
var town_pops: Array = [] # v1.0.26: floating "+3" pops in town [{node, t, y0}], ticked in _process
var flower_spots: Array = [] # v1.0.26: scattered wildflower positions (proof/suite handle)
var placed_flower_spots: Array = [] # v1.0.26 completion: base positions of every _place_flowers site flower (proof handle)
var playground_model: Node3D = null # v1.0.23: the Meshy playground structure in the park (suite handle)
# v1.0.23: where the park kids play — spots AROUND the playground
# structure (its collision box spans x 83.4..88.6, z 28.05..31.95
# at the park, centre (86, 30)): by the swings end, by the tower
# end, in front of the bridge, at both ends, and on the path.
const PARK_SPOTS: Array = [
	Vector3(88.8, 0, 32.8), Vector3(83.2, 0, 32.8), Vector3(86, 0, 33.6),
	Vector3(91.4, 0, 29.6), Vector3(80.6, 0, 29.6), Vector3(86, 0, 25.8),
]
var pickup_street: String = "" # v1.0.22: street of the officer's latest capture — feeds the intake card only
var intake_card_label: Label3D = null # v1.0.22: the card on Zander's cage front (see _build_intake_card)
var hide_points: Array = [] # Vector3 bush / car centres
var pursuers: Dictionary = {}
const PURSUIT_DURATION := 30.0 # v1.0.13: post-escape pursuit length in seconds (Michael, 2026-11-17: 60 -> 30)
var captor: Node = null
var capture_return_pos: Vector3 = Vector3.ZERO
var taken_timer: float = 0.0
var escape_step: int = 0
var latch_hits: int = 0
var latch_cooldown: float = 0.0
var meow_cooldown: float = 0.0
var bark_msg_cooldown: float = 0.0
var wrong_house_cd: Dictionary = {}
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
# opens with a big picture of the mechanism -> enter the combination
# -> the cat is SEEN working the mechanism. v1.2: the panel NO LONGER
# teleports the cat out — a finished combo OPENS the way and the
# player WALKS the cat out (Michael, 2026-11-16: "I want the door to
# open and you can walk outside"). Replaces the v0.7 room swipe
# gestures, which Michael found invisible and random-feeling.
# v1.0.21 (Michael's direction): the combination itself changed —
# the old fixed swipe pattern (down, up, down, up, PAW) is GONE. The
# combo is now a sequence of the A and B buttons (A = HOP, B = PAW),
# ESCAPE_COMBO_LEN presses long, RANDOMLY ROLLED every time the
# puzzle starts (_roll_escape_combo, called from _open_escape_panel)
# — the same mechanism in both rooms (house back door, pound door).
const ESCAPE_COMBO_LEN := 5
var escape_combo: Array = [] # the CURRENT start's rolled combo: "A"/"B" strings
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
# The cat can PAW over almost every loose object in the room (v1.5:
# 17 props — plant / book / vase plus lamps, mug, cushion, fruit bowl,
# shoes, picture, book stack, yarn, sill plant, wastebasket, coat
# stand, stool, watering can); the crash pulls
# the captor over to right it for ~5 s of walking + 5 s of righting —
# that is the window to work the latch. No distraction: the captor
# notices the cat at the door in NOTICE_GRACE seconds and kindly
# interrupts (panel closes, combo lost, cat shooed off — no fail).
const DISTRACT_RIGHT_TIME := 5.0 # seconds spent righting a toppled prop
const DISTRACT_WALK_SPEED := 2.3
const ROOM_WALK_SPEED := 1.15
const NOTICE_GRACE := 1.2 # seconds at the door, undistracted, before the captor notices
const NOTICE_COOLDOWN := 2.5 # grace after an interrupt before the panel may reopen
var distract_props: Array = [] # [{id, name, pivot, base, stand, toppled, anim_t, home_rot, topple_rot, bubble}]
# SHELTER WARD (2026-11-18): the pound's cages and their animals.
# Each entry: {name, gate_pivot, gate_blocker, gate_pos, open_yaw,
# animal (root), bob, body, head, ear_l, ear_r, home_pos, home_yaw,
# freed, gate_t, animal_state ("in"/"out"/"gone"), animal_t, wp
# (waypoints), wp_i, phase}. Pawing a gate frees the animal: +5.
var ward_cages: Array = []
var ward_pops: Array = [] # floating "Freed X! +5" labels [{node, t, y0}]
var ward_time: float = 0.0
# v1.0.17 CAPTURE DESTINATION SPLIT (Michael's v1.0.15 play report):
# TWO escape rooms now share the escape_origin slot — the shelter
# ward (the animal-control officer's captures only) and a house
# interior (everyone else's). Both builds register into the same
# member vars (blockers, pivots, theme_groups, distract_props,
# ward_cages…); the boot sequence snapshots each room's set, and
# _activate_escape_room swaps the live set plus visibility and
# collision on every escape entry.
var shelter_room_node: Node3D = null
var house_room_node: Node3D = null
var shelter_room_set: Dictionary = {}
var house_room_set: Dictionary = {}
var escape_room_is_house: bool = false
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
# crosses the threshold (+3 and the 30 s pursuit, as before). The
# openings are REAL gaps in the room walls (segmented at build time
# with invisible blockers while closed) so the cat can physically walk
# through; the opened way never closes, so he can't get soft-locked.
var exit_open: bool = false
var exit_open_kind: String = ""
var window_blocker: StaticBody3D = null # covers the window gap while closed
var petdoor_blocker: StaticBody3D = null # covers the pet-door gap while closed
var petdoor_zone := Rect2(563, -11, 6, 3.5) # MAP DOUBLING: +360 with escape_origin
var bolt_zone := Rect2(570, 1.2, 5.5, 4.6)
var carrier_zone := Rect2(551, 5, 6, 5.5)
var vase_zone := Rect2(566, 2, 6, 5)
var cam: Camera3D = null
var cam_target_pos: Vector3 = Vector3.ZERO
# --- v0.4 dual look controls -------------------------------------------
var look_yaw: float = 0.0 # radians, 0 = camera behind cat on +Z (v0.3 view)
var look_pitch_deg: float = CAM_TOWN_PITCH # camera elevation angle; + = looking down. v1.3 CAMERA FRAMING: default was 18 — at the old cat-scale orbit that steep tilt pushed people's faces/bars and the signs out of the top of the frame (see the camera constants block). 4 keeps a slight downward tilt so the cat sits in frame with ground at his feet, while the raised anchor + wider FOV (below) do the work of fitting people and signs; the verified escape-room shots were taken at pitch 6-10, so the room's regime is unchanged in kind.
const CAM_TOWN_PITCH := 4.0 # the shipped town default pitch — restored on escape completion (v1.4, see _complete_escape)
const LOOK_PITCH_MIN := -22.0 # tilt up (read signs above eye level). v1.3: was -10 — measured useless for the 3.75m sign boards (whole board still above the frame at max tilt from 3m); -22 frames the whole board from 2-3m.
const LOOK_PITCH_MAX := 55.0 # tilt down
const LOOK_YAW_SENS := 0.0052 # rad per drag pixel
const LOOK_PITCH_SENS := 0.14 # deg per drag pixel
var look_drags: Dictionary = {} # drag index / "mouse" -> last Vector2 pos
var look_exclude_rects: Array = [] # Rect2s of A/B/MEOW buttons
var hint_label: Label = null
var hint_timer: float = 0.0

var escape_origin := Vector3(560, 0, 0) # MAP DOUBLING: moved +360 east with the town (was 200)
# --- v0.6 wave 2: purr, street signs, mini-map, capture cutscene ------
var purr_player: AudioStreamPlayer = null
var purr_active: bool = false
var street_signs: Array = [] # {street, text} for every sign built
var content_points: Array = [] # v0.9: Vector3 of every house/tree/bush/prop/feature — the empty-area audit measures coverage from this
var tree_registry: Array = [] # v1.0.27: {node, r} for every tree/pine planted — audited against driveways + parked cars at build end (see _audit_tree_clearance)
var parked_car_spots: Array = [] # v1.0.27: Vector3 of every STATIC car (driveway, parking lot, diorama) — traffic and the pound van are NOT here
var driveway_pads: Array = [] # v1.0.27: {cx, cz, hx, hz} per driveway pad — computed once from _driveway_data(); gates ground scatter (_paved_spot) and the tree audit
# v0.7: the mini-map is GONE entirely (Michael: no real use, and he
# does not want any aid that shows the way home). Signs only.
var cutscene_t: float = 0.0
var cutscene_from: Vector3 = Vector3.ZERO
var cutscene_dir: Vector3 = Vector3(0, 0, 1)
# v1.3 scoop state: the capture-beat anchors (see _process_cutscene)
var cutscene_cat_yaw0: float = 0.0
var cutscene_npc_yaw0: float = 0.0
var cutscene_npc_from: Vector3 = Vector3.ZERO
var cutscene_face_yaw: float = 0.0
var cutscene_held_started: bool = false
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
# --- v0.7 traffic -------------------------------------------------------
var traffic_cars: Array = [] # {node, vel}
var _car_variant: int = 0 # v1.0.21: rotates the Meshy vehicle picks inside a car type (see _vehicle_scene)
# v1.0.22: the Meshy vehicle GLBs carry their nose toward -X in
# their own scene space — probe-measured on all eight (side
# renders with axis markers, tests/nose_probe.gd). But EVERY
# orientation consumer in the town works in the town convention
# NOSE = car-root +X: the traffic spawn rotations, the driveway
# parking turn, and the pound van's yaw maths (forward =
# (cos yaw, 0, -sin yaw) IS the root's +X at that yaw). v1.0.21
# trusted a comment claiming the models were normalised nose
# +X and skipped the turn, so every car drove tail-first
# (Michael, playing v1.0.21: "all the cars drive backwards").
# _build_car — the ONE place every vehicle in the game is
# built — yaws the model instance by this much, which puts the
# nose on +X where the whole town expects it.
const VEHICLE_MODEL_YAW := 180.0
# v1.0.21: each Meshy vehicle's real-world envelope (length X,
# height Y, width Z, metres) — the collision box in _build_car is
# sized from these. Measured off the imported models (Blender).
const VEHICLE_DIMS := {
	"res://assets/models/van_animal_control.glb": Vector3(4.0, 2.04, 2.0),
	"res://assets/models/car_sports.glb": Vector3(4.35, 1.27, 2.01),
	"res://assets/models/car_sedan.glb": Vector3(4.3, 1.65, 2.14),
	"res://assets/models/car_compact.glb": Vector3(3.9, 1.55, 2.02),
	"res://assets/models/truck_pickup.glb": Vector3(4.6, 1.88, 2.45),
	"res://assets/models/car_police.glb": Vector3(4.5, 1.76, 2.08),
	"res://assets/models/van_delivery.glb": Vector3(4.4, 1.91, 2.06),
	"res://assets/models/suv.glb": Vector3(4.56, 1.67, 2.12),
}
var traffic_timer: float = 2.5
var traffic_hit_cd: float = 0.0
var traffic_group: Node3D = null
const TRAFFIC_HIT_PENALTY := 5
# --- POUND VAN (Michael, 2026-11-17) ----------------------------------
# Exactly ONE white ANIMAL CONTROL van patrols the town's roads on a
# continuous loop, forever. If the cat comes within the worker's
# sight of the van (or of the worker himself, on foot), the
# being-noticed meter builds — since v1.0.21 exactly like a
# grabber's (see _pound_update_notice) — and when it fills, the van
# pulls over to the kerb, the worker (white uniform,
# net in hand — the same kind man from the story's opening) gets out
# and comes after the cat. He is never a villain: he is trying to
# get a lost cat home. A catch routes through the ORDINARY capture
# flow (scoop cutscene -> the back-door bolt escape room — "back at
# the pound, another little puzzle to get out" -> walk out -> his
# pursuit). When he loses the cat, or the pursuit timer runs out,
# he walks back to the van, gets in, and the patrol resumes — so
# encounters recur naturally as the van keeps circulating.
# player_collared is THE collar flag: story mode will set it true
# when the cat has a collar again, and while it is true the worker
# NEVER engages ("they're always after you — until you have a
# collar on"). It defaults to false: in the current game the cat
# reads as collarless to him. No collar gameplay hangs off it yet.
var player_collared: bool = false
var story: Node = null # STORY PART 1: the opening cutscene module (scripts/opening_cutscene.gd) — created in _ready; owns the title -> cutscene -> pound flow
const POUND_SPOT_RADIUS := 12.0 # m — RETIRED in v1.0.21: the old instant-spot radius. Engagement is the notice meter now (his detect_radius, person.gd poundworker = 12.0, coincidentally the same reach); kept only so older notes resolve.
const POUND_VAN_SPEED := 8.5 # patrol cruise, in line with traffic (7-10)
const POUND_RETURN_SPEED := 5.0 # his jog back to the van (brisk, not chase-fast)
const POUND_CHASE_SPEED := 6.4 # set on the worker in person.gd (inside the locked 6.0-7.0 chaser band)
var pound_van: Node3D = null
var pound_worker: CharacterBody3D = null
var pound_state: String = "patrol" # patrol | pullover | exit | chase | away | return | depot_in | depot | depot_out (v1.0.21: the last three are the garage legs)
var pound_route: Array = [] # patrol waypoints (Vector3, on the right-hand lanes)
var pound_route_idx: int = 0
var pound_van_speed: float = 0.0
var pound_van_yaw: float = 0.0 # heading in car space: forward = (cos yaw, 0, -sin yaw)
var pound_stop_pos: Vector3 = Vector3.ZERO # the kerb spot the van pulls into
var pound_stop_yaw: float = 0.0
var pound_kerb_dir: Vector3 = Vector3(0, 0, 1) # unit XZ: which side the kerb (and his door) is on
var pound_exit_t: float = 0.0
var pound_engage_cd: float = 0.0 # grace seconds after he gets back in before he can engage again
# --- v1.0.21: the pound DEPOT (garage) + the officer notice meter --
# (Michael's v1.0.20 play report) ----------------------------------
# THE GARAGE: the patrol route used to END at its west waypoint in a
# coin-flip U-turn — the target flips from the west waypoint to the
# far-east one and the van teardrops around it, north or south on
# microscopic yaw differences (traced headless: swings reaching
# z=0 in one run, z=24 in another, at the end of Oak Avenue),
# through the front yards and on a wider swing through a house.
# Michael: "when the pound van goes it just drives into the
# building. If it's going to drive into the building it better be a
# garage. Something that makes sense." So the route's end is now a
# DEPOT on the north side of the z=15 road at the west end: an
# open-front garage bay with the shelter office attached, built by
# _build_pound_depot. After an encounter, once the worker is back in
# the van, the van finishes its round to the depot
# (pound_heading_home), turns in and parks INSIDE the bay (state
# "depot_in" -> "depot"); after a dwell it reverses out to the
# apron and pulls away onto patrol ("depot_out"). No U-turn remains
# anywhere in the van's driving, and no van leg leaves the roads /
# the depot apron (audited in the suite).
const POUND_HOME_POS := Vector3(-112, 0, -1.9) # the parking spot INSIDE the garage bay
const POUND_HOME_YAW := PI * 0.5 # parked facing north, into the bay: forward = (cos yaw, 0, -sin yaw) = (0, 0, -1)
const POUND_DEPOT_DWELL := 12.0 # seconds parked in the bay before he pulls out again
var pound_heading_home: bool = false # set when the worker gets back in after an encounter; cleared as the depot turn-in begins (an engagement interrupts it)
var pound_depot_t: float = 0.0 # dwell timer while pound_state == "depot"
var pound_path: Array = [] # Vector3 waypoints of the current depot driving leg
var pound_path_idx: int = 0
var pound_backing_out: bool = false # depot_out, phase 1: reversing straight out of the bay
var pound_depot_solids: Array = [] # Rect2 (XZ) of the depot's solid geometry — the suite's van audit holds the van's body out of every one
# THE NOTICE METER: the officer now notices the cat the way every
# grabber does (see _pound_update_notice) — proximity to him OR to
# his van builds the same being-noticed bar (person.gd's sight
# range, fill rate and decay, read off his own definition), shown
# over the van while he rides in it and over his own head once he
# is on foot. Only a FULL meter starts the pull-over / chase.
var pound_notice: float = 0.0
var pound_bar_root: Node3D = null # the notice meter over the VAN (built like person.gd's overhead bar)
var pound_bar_fill: MeshInstance3D = null
var pound_bar_label: Label3D = null
# POUND RETURN FIX (2026-11-17): stuck watch for the walk back to
# the van — see _pound_return_target / the "return" branch. The
# waypoints are the fix; this watch is belt and braces so a wedge
# the waypoints don't know about can never kill the patrol again.
var pound_return_best: float = INF # smallest distance to the current return target seen since it was picked
var pound_return_still_t: float = 0.0 # seconds since that distance last improved
var pound_return_stuck_total: float = 0.0 # total no-progress seconds this return (sidestep time excluded)
var pound_return_sidesteps: int = 0 # sidesteps tried this return
var pound_return_dodge: Vector3 = Vector3.ZERO # active sidestep target (valid while pound_return_dodge_t > 0)
var pound_return_dodge_t: float = 0.0
var pound_return_last_target: Vector3 = Vector3.ZERO # target last frame — a waypoint switch restarts the improvement watch
var pound_return_has_target: bool = false
# v1.0.8: the in-play COLLAR check (button + camera zoom + all its
# state) is REMOVED entirely — under the new story the collar falls
# off before the pound, so there is nothing to re-check mid-run.
# The name print ON the 3D tag stays (cat.set_tag_name — "Zander").
var action_buttons: Array = [] # touch buttons (live rects block look drags)
var run_btn: Button = null # RUN hold button (sits beside MEOW)
var run_on: bool = false # v1.0.14: RUN HELD state: true only while the button is physically held down
var run_touch_id: int = -999 # v1.0.18: touch index currently holding RUN (-999 = none) — RUN is claimed/released on the raw touch channel in _input (see the v1.0.18 note there), not only via the Button's emulated-mouse signals
var hop_btn: Button = null # v1.0.21: the A / HOP button — claimed on the raw touch channel in _input (see the v1.0.21 note there)
var paw_btn: Button = null # v1.0.21: the B / PAW button — same raw-channel claim
var meow_btn: Button = null # v1.0.21: the MEOW button — same raw-channel claim
var _action_echo_latch: Dictionary = {} # v1.0.24: action name -> true while the Button-signal echo of a raw-touch-claimed tap is still expected; the Button handler consumes the latch and stands down — STATE-based, not a timer (v1.0.21's 150 ms window let a slow tap's echo through). See _fire_action / _action_claimed_recently.
var _panel_press_owner: Dictionary = {} # v1.0.24: combo letter ("A"/"B") -> the press that owns it ("touch:<index>" / "mouse"); while the escape panel is open a letter registers ONE step per physical press and further presses are ignored until that owner's release is seen. See the panel branch of _input.
var shelf_zone := Rect2(546, -9, 6, 5) # XZ rect (MAP DOUBLING: +360 with escape_origin)
var sofa_zone := Rect2(556, 3, 7, 3)
var window_zone := Rect2(557, -9.5, 6, 3)

var hud_layer: CanvasLayer
var hud_top_bar: ColorRect = null # v1.0.16: gameplay HUD chrome (was a _build_hud local)
var score_pill: Panel = null # v1.0.16: ditto — the gold pill score_label sits in
var gameplay_hud_on: bool = false # v1.0.16: gameplay HUD hidden until START
var message_label: Label
var objective_label: Label
var pursuit_label: Label
var escape_label: Label
var title_panel: Control
var splash_panel: Control
# v1.0.9 (launch-crash fix): the world build used to run as ONE
# synchronous block inside _ready (~34k nodes, 7-17 s) before the
# first frame could present — on Michael's S26 the launch watchdog
# killed the app during that black pause. The build now streams in
# across frames BEHIND the splash; build_complete / build_finished
# are the deterministic wait point for the title flow and for the
# test/screenshot harnesses.
var build_complete: bool = false
signal build_finished
var _splash_tap_queued: bool = false
# v1.0.10 (diagnostic + self-healing build): a flushed per-stage
# boot log, a staged town reveal and a crash marker. If a launch
# dies before the title has been stable for ~2 s, the marker it
# leaves behind does NOT say "complete" and the NEXT launch boots
# in safe mode (sun shadows off, lamp halos skipped).
# v1.0.14: the on-screen boot-stage readout, the "Loading the
# town…" splash note and the amber safe-mode note are GONE —
# Michael doesn't want the game narrating its loading ("just hit
# start and it starts"). The machinery stays, fully invisible:
# the boot log file, the crash marker and safe mode itself.
var boot_safe_mode: bool = false
var sun_light: DirectionalLight3D = null
var _title_stable_t: float = -1.0
const BOOT_LOG_PATH := "user://homeward_boot.log"
const BOOT_MARKER_PATH := "user://boot_marker.txt"
# ------------------------------------------------------------------
# BISECT SWITCH (v1.0.12) — LEGACY_TOWN_ONLY
# v1.0.7 (the 41-house town) is the last build verified running on
# Michael's S26; every doubled-map build since (v1.0.8–v1.0.11)
# dies on his phone during the world build, and the VM here has
# never reproduced it. Three mechanism theories (launch sequencing,
# reveal spike, build pacing) were implemented and ruled out by
# phone tests, so this switch bisects the CONTENT delta instead:
# when true, world generation produces the pre-doubling town only —
# the original four cross streets (Pine/Cedar/Birch/Riverside), the
# original 41 houses, no east district (Harbour/Summit/Quarry/
# Meadow/Sunset streets, the 90 doubling houses, Harbour Market
# Row, Meadow Court, Sunset Green) — while everything else stays
# exactly the current game: dusk, the NPC look overhaul, all 48
# people (east spawns relocated west, roles untouched), traffic
# and the pound van on the legacy street network, the staged
# 60 ms-chunked build, the boot readout, the staged reveal, the
# crash marker and safe mode. Flip it back to false and the full
# doubled town generates again, bit for bit as in v1.0.11.
const LEGACY_TOWN_ONLY := true # v1.0.12 SHIPS WITH THE SWITCH ON (bisect build) — set false to restore the doubled town
var _chunk_t0: int = 0
# v1.0.11 build profiling: per-stage wall-clock duration, longest
# unbroken synchronous stretch (main-thread work between presented
# frames) and static memory at stage boundaries — appended to the
# boot log at every stage change so a phone death leaves numbers,
# not just a stage name.
var _stage_t0: int = 0
var _stage_name: String = ""
var _stage_mem0: int = 0
var _stage_max_stretch: int = 0
var _resume_ms: int = 0
var _yield_wait_total: int = 0 # cumulative ms spent WAITING on presented frames inside _build_frame (lets per-item timers report pure work, not work + waits)
var _houses_max_ms: int = 0
var _houses_max_addr: String = ""
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
# MESSAGE DISCIPLINE (2026-11-18): the bottom message band shows ONE
# message at a time — show_message() queues behind the message on
# screen instead of overwriting it, and the queue drains in order as
# each message's time runs out (see _process). Held: the escape-room
# entry message, when the opening's pound entry must keep it back
# until the cage gate opens (released by the story module).
var message_queue: Array = [] # [{text, seconds}] waiting their turn
var held_escape_message: String = ""
var held_escape_seconds: float = 0.0
# The entry message is TWO beats (v1.0.15 HUD fix): beat 2 waits in
# the second held slot and queues behind beat 1 on release, so the
# band never carries the whole instruction as one long line.
var held_escape_message_2: String = ""
var held_escape_seconds_2: float = 0.0

var meow_players: Array = []
var meow_index: int = 0
var sfx_meow: AudioStreamPlayer
var sfx_bark: AudioStreamPlayer
var sfx_notice: AudioStreamPlayer
var sfx_win: AudioStreamPlayer
var music: AudioStreamPlayer
var splash_song_player: AudioStreamPlayer = null

# ---------------------------------------------------------------- materials/helpers
# v1.0.28 PERF (Michael: "compress and preload as much as possible
# so it runs smoothly on my S26 with no jankiness"): the town is
# built from ~14k box/sphere/cylinder parts, and every helper below
# used to mint a BRAND-NEW mesh and material for every single part —
# thousands of duplicate GPU resources, a long allocation-heavy
# build, and steady memory/GC pressure in play. Materials and
# primitive meshes are now cached and shared by their parameters
# (the same pattern person.gd already used for its materials).
# Nothing about the rendered result changes: same colours, same
# sizes, same surfaces — one resource where there used to be
# hundreds of identical copies. (Verified safe: no code anywhere
# mutates a material or primitive mesh in place after a helper
# returns it; per-instance changes always replace material_override.)
var _mat_cache: Dictionary = {}
var _mat_tex_cache: Dictionary = {}
var _glass_mat_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _cyl_mesh_cache: Dictionary = {}
var _unit_sphere_mesh: SphereMesh = null

func _mat(c: Color, rough: float = 0.9, emission: float = 0.0) -> StandardMaterial3D:
	var key: String = str(c) + "|" + str(rough) + "|" + str(emission)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m


func _mat_tex(tex: Texture2D, tint: Color = Color.WHITE, uv: Vector3 = Vector3(1, 1, 1), rough: float = 0.94) -> StandardMaterial3D:
	var key: String = str(tex) + "|" + str(tint) + "|" + str(uv) + "|" + str(rough)
	if _mat_tex_cache.has(key):
		return _mat_tex_cache[key]
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
	_mat_tex_cache[key] = m
	return m

# SHELTER WARD: chain-link mesh — one shared diamond-weave alpha
# texture (generated once), a fresh material per panel so each
# panel's repeat matches its size. Alpha-scissored, double-sided:
# it reads as real wire mesh, not glass and not solid bars.
var _chainlink_tex: Texture2D = null

func _chainlink_texture() -> Texture2D:
	if _chainlink_tex != null:
		return _chainlink_tex
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wire := Color(0.72, 0.75, 0.8, 1.0)
	for y in range(96):
		for x in range(96):
			var d1: int = posmod(x + y, 24)
			var d2: int = posmod(x - y, 24)
			if d1 < 3 or d2 < 3 or d1 > 22 or d2 > 22:
				img.set_pixel(x, y, wire)
	_chainlink_tex = ImageTexture.create_from_image(img)
	return _chainlink_tex

func _chainlink_mat(size: Vector2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _chainlink_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.45
	m.roughness = 0.5
	m.uv1_scale = Vector3(maxf(size.x, 0.1) / 0.44, maxf(size.y, 0.1) / 0.44, 1)
	return m

# A chain-link panel: a quad at pos (absolute in parent space),
# facing -z by default; yaw_deg turns it (the west cage bank's
# fronts face +x, yaw -90).
func _mesh_panel(parent: Node, pos: Vector3, size: Vector2, yaw_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _chainlink_mat(size)
	mi.position = pos
	mi.rotation_degrees = Vector3(0, 180.0 + yaw_deg, 0)
	parent.add_child(mi)
	return mi

func _glass(parent: Node, pos: Vector3, size: Vector3, col: Color, em: float) -> MeshInstance3D:
	# v1.0 step 2: window glass is a MATERIAL now, not a glowing
	# card — low roughness + a touch of metal so it mirrors the sky
	# and sun like real glass, keeping a whisper of warm emission
	# so lit windows still read as "someone's home".
	var mi := _box(parent, pos, size, col)
	# v1.0.28 PERF: glass materials shared by (colour, emission).
	var gkey: String = str(col) + "|" + str(em)
	if _glass_mat_cache.has(gkey):
		mi.material_override = _glass_mat_cache[gkey]
		return mi
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.12
	m.metallic = 0.3
	if em > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = em * 0.75
	_glass_mat_cache[gkey] = m
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

func _box_mesh_for(size: Vector3) -> BoxMesh:
	# v1.0.28 PERF: one BoxMesh per distinct size, shared town-wide.
	var key: String = str(size)
	if _box_mesh_cache.has(key):
		return _box_mesh_cache[key]
	var bm := BoxMesh.new()
	bm.size = size
	_box_mesh_cache[key] = bm
	return bm

func _box(parent: Node, pos: Vector3, size: Vector3, c: Color, collide: bool = false, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh_for(size)
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
	cs.shape = _box_shape_for(size) # v1.0.28 PERF: shared shape (the CS toggle is per-node, not per-shape)
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
	# v1.0.28 PERF: every sphere in the game is the same unit sphere
	# scaled by the node — share the one mesh.
	if _unit_sphere_mesh == null:
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 24
		sm.rings = 14
		_unit_sphere_mesh = sm
	mi.mesh = _unit_sphere_mesh
	mi.position = pos
	mi.scale = scl
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _cyl(parent: Node, pos: Vector3, r_top: float, r_bot: float, h: float, c: Color, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	# v1.0.28 PERF: cylinder meshes shared by (radii, height).
	var ckey: String = str(r_top) + "|" + str(r_bot) + "|" + str(h)
	if _cyl_mesh_cache.has(ckey):
		mi.mesh = _cyl_mesh_cache[ckey]
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = h
		cm.radial_segments = 18
		_cyl_mesh_cache[ckey] = cm
		mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		# v1.0.28 PERF: cylinder shapes shared by (radius, height).
		var skey: String = "cyl|" + str(r_bot) + "|" + str(h)
		if _box_shape_cache.has(skey):
			cs.shape = _box_shape_cache[skey]
		else:
			var shape := CylinderShape3D.new()
			shape.radius = r_bot
			shape.height = h
			_box_shape_cache[skey] = shape
			cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi

var _box_shape_cache: Dictionary = {}

func _box_shape_for(size: Vector3) -> BoxShape3D:
	# v1.0.28 PERF: collision shapes shared by size as well — a
	# shape resource is read-only in play, so 1,000+ identical wall
	# boxes never needed 1,000+ identical shapes.
	var key: String = str(size)
	if _box_shape_cache.has(key):
		return _box_shape_cache[key]
	var shape := BoxShape3D.new()
	shape.size = size
	_box_shape_cache[key] = shape
	return shape

func _add_static(mi: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = _box_shape_for(size)
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

var _tuft_cone: ArrayMesh = null

func _tuft_cone_mesh() -> ArrayMesh:
	# The grass-tuft cone (r 0.045 -> 0.004, h 0.44, centred on
	# its origin exactly like the CylinderMesh it replaces) with
	# the v1.0.26 steep-lean normals — a cylinder's true outward
	# normals are near-horizontal and go black on the anti-sun
	# side under the dusk rig, the same failure as the multimesh
	# blades (see _blade_mesh). Built once, shared by every tuft.
	if _tuft_cone != null:
		return _tuft_cone
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rb := 0.045
	var rt := 0.004
	var hh := 0.22 # half height — the cone is centred, like _cyl's
	var vi: int = 0
	for s in range(6):
		var a0 := float(s) * PI / 3.0
		var a1 := float(s + 1) * PI / 3.0
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		verts.append_array([d0 * rb + Vector3(0, -hh, 0), d1 * rb + Vector3(0, -hh, 0), d1 * rt + Vector3(0, hh, 0), d0 * rt + Vector3(0, hh, 0)])
		var n := (d0 + d1).normalized()
		var nn := Vector3(n.x, (rb - rt) / (hh * 2.0), n.z).normalized()
		nn = (nn * 0.38 + Vector3.UP * 0.62).normalized()
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
	_tuft_cone = ArrayMesh.new()
	_tuft_cone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _tuft_cone

func _grass_tuft(parent: Node, pos: Vector3, seed_i: int) -> void:
	# v0.7 art: crossed blade cones instead of a green ball.
	# v1.0.26: shared steep-normal cone mesh instead of _cyl
	# (same silhouette, same spots — see _tuft_cone_mesh).
	var cols: Array = [Color(0.3, 0.58, 0.28), Color(0.4, 0.66, 0.32), Color(0.34, 0.62, 0.3)]
	for bi in range(3):
		var blade := MeshInstance3D.new()
		blade.mesh = _tuft_cone_mesh()
		blade.position = pos + Vector3((float(bi) - 1.0) * 0.09, 0.1, (float((bi + seed_i) % 3) - 1.0) * 0.08)
		blade.material_override = _mat(cols[(bi + seed_i) % 3])
		parent.add_child(blade)
		blade.rotation_degrees = Vector3((float(bi) - 1.0) * 9.0, 0, (float((bi * 2 + seed_i) % 3) - 1.0) * 9.0)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # v1.0.28 PERF: a 9cm grass blade's shadow is sub-pixel at the dusk sun angle — don't pay shadow-pass cost for thousands of them

# --- v1.0 step 2 GROUND DETAIL (MultiMesh) ---------------------------
# Thousands of individual 3D grass blades + tiny wildflowers, each
# set in ONE draw call. At cat height the lawn stops being a green
# texture and becomes a surface the cat stands IN. Normals point
# straight up so blades shade exactly like the lawn beneath them.
func _blade_mesh() -> ArrayMesh:
	# v1.0.23 (was: two crossed quads with straight-up normals and
	# a double-sided material): THE BLACK SPIKES Michael saw on
	# every lawn in v1.0.21 were these blades. Diagnosis (bisected
	# in a scratch scene under the game's own dusk rig): the
	# quads' winding makes one side of each quad a BACK face; a
	# double-sided material flips a back face's normal, so the
	# up normal became (0,-1,0) and the face was lit only by the
	# sky's dark ground side — pure black from most viewpoints,
	# while the tuft cones and the lawn (real outward normals)
	# shaded green. The blade is now a slim 4-sided cone with
	# proper outward normals — the same construction as the tuft
	# blades — and shades like grass from every side. (Instance
	# colours were never the problem: the flower instances on the
	# same path always rendered correctly.)
	# v1.0.26: AND YET Michael's v1.0.25 play still showed black
	# spikes. Re-bisected in a scratch scene under this exact dusk
	# rig (tests/blade_lab.gd): the cone's normals are nearly
	# HORIZONTAL (y ≈ 0.13), so a blade face turned away from the
	# low amber sun gets no direct light at all — only the dim
	# horizon band of the sky ambient — and ACES crushes it to
	# black. A blade is a thin cone, so from any anti-sun
	# viewpoint the WHOLE blade reads as a black spike; the lawn
	# itself never does this because its normal points up into
	# the sun and the bright sky. (Reversed winding proved to be
	# the mirror image — black from the sun side instead — so
	# winding was never the issue.) The normals now lean 62%
	# toward straight up (y ≈ 0.87): every face keeps some sun
	# and sky light, blades shade green from every compass
	# point, and the cone keeps a slight outward lean so it
	# still has a lit side and a shade side. Same geometry,
	# same winding, same instance colours.
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
		nn = (nn * 0.38 + Vector3.UP * 0.62).normalized() # v1.0.26: steep lean (see above)
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
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# v1.0.26: PAVED ground that is not a road band — the riverside
# promenade slab, the parking pads, and the two pocket-park path
# crosses. Michael, playing v1.0.25: grass tufts were poking up
# through the promenade concrete ("grass coming out of the
# sidewalk"). Ground scatter (tufts + the multimesh blades and
# flowers) must never land on any of it. Rects carry a small
# margin so nothing sprouts at a slab's edge either.
func _paved_spot(p: Vector3) -> bool:
	# The promenade: one long sidewalk slab along the river band.
	var prom_cx: float = 0.0 if LEGACY_TOWN_ONLY else 126.0
	var prom_half: float = 122.0 if LEGACY_TOWN_ONLY else 244.0
	if absf(p.x - prom_cx) <= prom_half + 0.35 and p.z >= -87.05 and p.z <= -82.95:
		return true
	# Parking pads: [centre x, centre z, half w, half d] per pad
	# (the _fill_parking calls in _build_town_fill).
	for pad in [[84.0, -75.0, 5.0, 3.5], [62.0, 6.5, 4.5, 2.2], [16.0, 79.0, 4.0, 3.0], [234.0, -75.0, 5.0, 3.5]]:
		if absf(p.x - float(pad[0])) <= float(pad[2]) + 0.35 and absf(p.z - float(pad[1])) <= float(pad[3]) + 0.35:
			return true
	# Pocket-park path crosses + their fountain discs: Willow
	# Green (100, 76) and Sunset Green (296, 79 — doubled town).
	for pc in [Vector2(100, 76), Vector2(296, 79)]:
		if absf(p.x - pc.x) <= 8.85 and absf(p.z - pc.y) <= 1.45:
			return true
		if absf(p.x - pc.x) <= 1.45 and absf(p.z - pc.y) <= 8.85:
			return true
		if Vector2(p.x - pc.x, p.z - pc.y).length() < 2.9:
			return true
	# v1.0.27: driveway pads — the last paved surface the scatter
	# gate didn't know (Michael's v1.0.26 shots: tufts sprouting
	# along driveway/sidewalk edges). Rects are precomputed from
	# the driveway table before anything scatters.
	for dp in driveway_pads:
		if absf(p.x - float(dp["cx"])) <= float(dp["hx"]) + 0.35 and absf(p.z - float(dp["cz"])) <= float(dp["hz"]) + 0.35:
			return true
	return false

func _ground_spot_blocked(p: Vector3) -> bool:
	if _paved_spot(p): # v1.0.26: promenade / pads / park paths
		return true
	for rz in [-55.0, -11.0, 15.0, 55.0]:
		if absf(p.z - rz) < 6.4:
			return true
	for rx in [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0]:
		if absf(p.x - rx) < 6.4:
			return true
	for hh in houses:
		if p.distance_to(hh["pos"]) < 8.6:
			return true
	for cl in civic_lots: # v1.0.29: no ground scatter inside the Meshy civic buildings either
		if p.distance_to(cl["pos"]) < 9.6:
			return true
	if p.distance_to(Vector3(62, 0, -4)) < 7.5:
		return true # v1.0.29: the Meshy bakery's footprint
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
	var scatter_x_max: float = 118.0 if LEGACY_TOWN_ONLY else 372.0 # BISECT (v1.0.12): legacy scatter stops at the legacy east edge
	while placed < count and guard < count * 40:
		guard += 1
		# v1.0.11 chunking: tick FIRST, before the rejection check —
		# rejected candidates are most of the work (every candidate is
		# distance-checked against all 131 houses) and a `continue`
		# must never be able to skip the breathing. This loop was the
		# single longest unbroken stretch in the whole build (881 ms
		# for 24k blades). Same RNG draw order, same placements.
		await _build_tick()
		var p := Vector3(srng.randf_range(-120, scatter_x_max), y_base, srng.randf_range(-90, 90))
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
		await _build_tick()
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
			if j % 512 == 511:
				await _build_tick()
		await _build_tick()
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = centre + Vector3(0.013, 0, 0.017) # MAP DOUBLING: a hair off the grid — a chunk origin landing exactly on a (whole-number) house position made the mailbox audit count the chunk as a house
		mmi.custom_aabb = AABB(Vector3(-CELL * 0.5 - 3.0, -1.0, -CELL * 0.5 - 3.0), Vector3(CELL + 6.0, 4.0, CELL + 6.0))
		if vis_end > 0.0:
			mmi.visibility_range_end = vis_end
		world.add_child(mmi)

func _flower_stem_mesh() -> ArrayMesh:
	# v1.0.26: a wildflower stem — a thin cone (r 0.011 -> 0.006,
	# h 0.26) standing on the ground plane, with the same
	# steep-lean normals as the grass blades so it shades green
	# from every side under the dusk rig.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rb := 0.011
	var rt := 0.006
	var bh := 0.26
	var vi: int = 0
	for s in range(5):
		var a0 := float(s) * TAU / 5.0
		var a1 := float(s + 1) * TAU / 5.0
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		verts.append_array([d0 * rb, d1 * rb, d1 * rt + Vector3(0, bh, 0), d0 * rt + Vector3(0, bh, 0)])
		var n := (d0 + d1).normalized()
		var nn := Vector3(n.x, (rb - rt) / bh, n.z).normalized()
		nn = (nn * 0.38 + Vector3.UP * 0.62).normalized()
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
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _append_blob(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, centre: Vector3, r: float, squash: float) -> void:
	# One squashed sphere blob for the flower head (petal or
	# centre), appended into the arrays being built.
	var lon_steps := 7
	var lat_steps := 4
	var base := verts.size()
	for la in range(lat_steps + 1):
		var phi := -PI * 0.5 + PI * float(la) / float(lat_steps)
		for lo in range(lon_steps + 1):
			var theta := TAU * float(lo) / float(lon_steps)
			var d := Vector3(cos(phi) * cos(theta), sin(phi), cos(phi) * sin(theta))
			verts.append(centre + Vector3(d.x * r, d.y * r * squash, d.z * r))
			normals.append(Vector3(d.x, d.y / maxf(squash, 0.05), d.z).normalized())
			uvs.append(Vector2(0, 0))
	for la in range(lat_steps):
		for lo in range(lon_steps):
			var a := base + la * (lon_steps + 1) + lo
			var b := a + lon_steps + 1
			indices.append_array([a, b, a + 1, b, b + 1, a + 1])

func _flower_head_mesh() -> ArrayMesh:
	# v1.0.26: a daisy-like head at the top of the stem — a
	# flattened centre disc with six petal blobs in a ring, all
	# in local space around y = 0.27. No colour array: the
	# instance colour tints the whole head via the material's
	# vertex-colour-as-albedo, exactly like the old spheres.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	_append_blob(verts, normals, uvs, indices, Vector3(0, 0.278, 0), 0.037, 0.5)
	for k in range(6):
		var ang := float(k) * PI / 3.0
		_append_blob(verts, normals, uvs, indices, Vector3(cos(ang) * 0.045, 0.268, sin(ang) * 0.045), 0.030, 0.42)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _scatter_flowers(world: Node3D, srng: RandomNumberGenerator, count: int, palette: Array) -> void:
	# v1.0.26: placements follow _scatter_multimesh's rules
	# exactly (same ranges, same _ground_spot_blocked lawn-only
	# rejection — promenade, parking pads and park paths
	# included), then split into TWO multimeshes per 20 m cell
	# sharing every placement: stems on a plain green material
	# (no instance colours, so a pink head never tints its
	# stem) and heads instance-coloured from the palette. Same
	# 45 m visibility range as the old bare-sphere scatter.
	# Positions are kept in flower_spots as a proof handle.
	var stem_mesh := _flower_stem_mesh()
	var head_mesh := _flower_head_mesh()
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.30, 0.52, 0.22)
	stem_mat.roughness = 1.0
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color.WHITE
	head_mat.roughness = 0.7
	head_mat.vertex_color_use_as_albedo = true
	var xforms: Array = []
	var cols: Array = []
	var placed: int = 0
	var guard: int = 0
	var scatter_x_max: float = 118.0 if LEGACY_TOWN_ONLY else 372.0
	while placed < count and guard < count * 40:
		guard += 1
		await _build_tick()
		var p := Vector3(srng.randf_range(-120, scatter_x_max), 0.02, srng.randf_range(-90, 90))
		if _ground_spot_blocked(p):
			continue
		var basis := Basis(Vector3.UP, srng.randf_range(0.0, TAU)).scaled(Vector3.ONE * srng.randf_range(0.8, 1.3))
		xforms.append(Transform3D(basis, p))
		cols.append(palette[srng.randi_range(0, palette.size() - 1)])
		flower_spots.append(p)
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
		for part in range(2):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = part == 1
			mm.mesh = stem_mesh if part == 0 else head_mesh
			mm.instance_count = idxs.size()
			for j in range(idxs.size()):
				var t: Transform3D = xforms[idxs[j]]
				mm.set_instance_transform(j, Transform3D(t.basis, t.origin - centre))
				if part == 1:
					mm.set_instance_color(j, cols[idxs[j]])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = stem_mat if part == 0 else head_mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.position = centre + Vector3(0.013, 0, 0.017)
			mmi.custom_aabb = AABB(Vector3(-CELL * 0.5 - 3.0, -1.0, -CELL * 0.5 - 3.0), Vector3(CELL + 6.0, 4.0, CELL + 6.0))
			mmi.visibility_range_end = 45.0
			world.add_child(mmi)

func _place_flowers(world: Node3D, spots: Array) -> void:
	# v1.0.26 completion: the hand-scattered flower sites (park
	# scatter, town scatter, park-2 scatter, every _fill_flowerbed,
	# the park-2 ring bed) used to place BARE COLOURED SPHERES —
	# Michael asked for proper flowers, so they now share
	# _scatter_flowers' construction: stems on a plain green
	# material + instance-coloured daisy heads, two multimeshes
	# per site (the sites are small; two draw calls each).
	# spots: Array of [base Vector3, Color, scale float]. Yaw is
	# derived from the position so callers keep their exact RNG
	# draw order — placements and colours are unchanged.
	if spots.is_empty():
		return
	var stem_mesh := _flower_stem_mesh()
	var head_mesh := _flower_head_mesh()
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.30, 0.52, 0.22)
	stem_mat.roughness = 1.0
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color.WHITE
	head_mat.roughness = 0.7
	head_mat.vertex_color_use_as_albedo = true
	var centre := Vector3.ZERO
	for s in spots:
		centre += (s as Array)[0]
		placed_flower_spots.append((s as Array)[0])
	centre /= float(spots.size())
	centre.y = 0.0
	var lo := Vector3(1e9, 0, 1e9)
	var hi := Vector3(-1e9, 0, -1e9)
	for s2 in spots:
		var p3: Vector3 = (s2 as Array)[0]
		lo.x = minf(lo.x, p3.x)
		lo.z = minf(lo.z, p3.z)
		hi.x = maxf(hi.x, p3.x)
		hi.z = maxf(hi.z, p3.z)
	for part in range(2):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = part == 1
		mm.mesh = stem_mesh if part == 0 else head_mesh
		mm.instance_count = spots.size()
		for j in range(spots.size()):
			var s3: Array = spots[j]
			var p4: Vector3 = s3[0]
			var yaw := fmod(p4.x * 12.9898 + p4.z * 78.233, TAU)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * float(s3[2]))
			mm.set_instance_transform(j, Transform3D(basis, p4 - centre))
			if part == 1:
				mm.set_instance_color(j, s3[1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = stem_mat if part == 0 else head_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = centre + Vector3(0.013, 0, 0.017) # same mailbox-audit hair off the grid as the scatters
		var ext := Vector3(maxf(hi.x - lo.x, 1.0) * 0.5 + 1.5, 0.0, maxf(hi.z - lo.z, 1.0) * 0.5 + 1.5)
		mmi.custom_aabb = AABB(Vector3(-ext.x, -0.5, -ext.z), Vector3(ext.x * 2.0, 2.0, ext.z * 2.0))
		world.add_child(mmi)

# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	rng.randomize()
	_define_houses()
	home_index = rng.randi_range(0, houses.size() - 1)
	home_address = houses[home_index]["address"]
	# v1.0.10: read LAST launch's crash marker before anything is
	# built — an incomplete marker means safe mode for THIS launch.
	# Then stamp this launch's marker immediately, so a death at any
	# later point leaves evidence behind.
	_check_boot_marker()
	_boot_write_marker("starting")
	_boot_log("launch safe_mode=%s" % str(boot_safe_mode))
	# v1.0.9: ONLY the splash path runs synchronously — environment,
	# audio and every UI layer — so the first frame presents in well
	# under a second. Everything else (cat, camera, the world
	# itself) streams in behind the splash in _build_world_async();
	# the splash's cat is the 2D picture, so nothing is missing.
	_build_environment()
	_build_audio()
	_build_hud()
	_build_touch_controls()
	_build_escape_ui()
	# STORY PART 1: the opening cutscene + pound start module. It
	# orchestrates the existing cat / pound worker / van through
	# their APIs; start_game() hands the run over to it.
	story = OpeningCutsceneScript.new()
	add_child(story)
	story.call("setup", self)
	_show_splash()
	_build_world_async()

# v1.0.11: THE frame yield for build code. Notes the unbroken
# synchronous stretch that just ended (main-thread work since the
# last presented frame) into the current stage's stats, presents a
# frame, and re-arms both clocks. Every build-path frame await goes
# through here so the stretch accounting has no blind spots.
func _build_frame() -> void:
	var now := Time.get_ticks_msec()
	if _resume_ms > 0:
		_stage_max_stretch = maxi(_stage_max_stretch, now - _resume_ms)
	await get_tree().process_frame
	_resume_ms = Time.get_ticks_msec()
	_chunk_t0 = _resume_ms
	_yield_wait_total += _resume_ms - now

# v1.0.9: yield to the frame clock whenever the current build chunk
# has burned through its time budget, so the splash keeps presenting
# (and the phone's watchdog stays fed) while the town streams in.
# Callers must `await` this — a chunk that comes in under budget
# returns immediately without yielding.
# v1.0.11: budget 200 -> 100 ms. Michael's S26 died DURING the
# "Placing houses" stage in v1.0.10 (screenshot evidence, in safe
# mode, before the reveal) — and the v1.0.11 profiling run showed
# why the old budget wasn't protection enough: whole build sections
# never called _build_tick at all (the 24k-blade scatter ran 881 ms
# in ONE call; the street-trees block ~383 ms; the whole-world
# clutter walk ~229 ms), and the sections that did tick could still
# park the main thread for a full 200 ms budget plus frame time,
# back to back, while memory climbed 106 -> 434 MB. Now every
# substantial build loop ticks, and the budget is 60 ms — chosen
# so budget + the largest indivisible item (one person's model
# build inside add_child, ~43 ms on this VM) stays near ~100 ms.
# On the phone every one of these items costs a fraction of the
# VM's time, so the margin there is wide.
const BUILD_CHUNK_BUDGET_MS := 60
func _build_tick() -> void:
	if Time.get_ticks_msec() - _chunk_t0 >= BUILD_CHUNK_BUDGET_MS:
		await _build_frame()

# v1.0.9: the world build, sequenced across frames behind the
# splash: town geometry in budget-sized chunks, then the escape
# room, the neighbours (chunked), and finally the pound van.
# Sequencing ONLY — the finished world is identical to the old
# synchronous build: same calls, same order, same counts.
func _check_boot_marker() -> void:
	# v1.0.10: a previous launch that never reached a stable title
	# leaves a marker that does not say "complete" -> safe mode.
	boot_safe_mode = false
	if FileAccess.file_exists(BOOT_MARKER_PATH):
		var f := FileAccess.open(BOOT_MARKER_PATH, FileAccess.READ)
		if f:
			var txt := f.get_as_text().strip_edges()
			f.close()
			boot_safe_mode = txt != "" and txt != "complete"

func _boot_write_marker(text: String) -> void:
	var f := FileAccess.open(BOOT_MARKER_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()

func _boot_log(stage: String) -> void:
	# Open/write/close per stage so every line is flushed even if
	# the process dies during the NEXT stage.
	var f := FileAccess.open(BOOT_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(BOOT_LOG_PATH, FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("%s  %s" % [Time.get_datetime_string_from_system(), stage])
		f.close()

func _set_boot_stage(text: String, pct: int) -> void:
	# v1.0.10: update the boot log and the crash marker, then WAIT
	# one presented frame before returning — the stage's work must
	# never run in the same frame that first names it, so a death
	# leaves the stage on disk.
	# v1.0.11: first, close out the PREVIOUS stage's profile line
	# (duration / longest unbroken stretch / memory) into the log.
	# v1.0.14: the on-screen readout that used to mirror `shown` is
	# removed — the log + marker writes below are the whole job now.
	var now := Time.get_ticks_msec()
	_log_stage_profile()
	var shown := text
	if pct >= 0:
		shown = "%s %d%%" % [text, pct]
	_stage_name = text
	_stage_t0 = now
	_stage_mem0 = int(OS.get_static_memory_usage())
	_stage_max_stretch = 0
	_boot_log(shown)
	_boot_write_marker(shown)
	await _build_frame()

func _log_stage_profile() -> void:
	# v1.0.11: append the current stage's numbers to the boot log
	# and reset the stretch counter for whatever comes next.
	if _stage_name == "":
		return
	var now := Time.get_ticks_msec()
	if _resume_ms > 0:
		_stage_max_stretch = maxi(_stage_max_stretch, now - _resume_ms)
		_resume_ms = now # the closing partial stretch is now accounted; don't let the next _build_frame count it twice
	var mem_now := int(OS.get_static_memory_usage())
	_boot_log("profile stage '%s' took %d ms, longest stretch %d ms, mem %d -> %d MB" % [_stage_name, now - _stage_t0, _stage_max_stretch, _stage_mem0 / 1048576, mem_now / 1048576])
	if _stage_name == "Placing houses" and _houses_max_addr != "":
		_boot_log("profile houses slowest single house %d ms (%s)" % [_houses_max_ms, _houses_max_addr])
	_stage_max_stretch = 0

# v1.0.25 PERF (Michael's order: compress + preload so the S26 never
# hitches): every model resource is already preload()ed, but a texture
# only reaches the GPU the first time its model is DRAWN — which used
# to happen mid-play, one type at a time, as things scrolled into
# view. Here, behind the splash, one instance of every distinct
# person / cat / dog / vehicle model is placed in front of the boot
# camera for a few frames so every texture upload and shader compile
# happens during loading instead. Instances are freed before the
# reveal; nothing about gameplay changes.
const WARMUP_MODEL_PATHS: Array = [
	"res://assets/models/officer.glb", "res://assets/models/young_woman.glb",
	"res://assets/models/excited_kid.glb", "res://assets/models/dog_walker.glb",
	"res://assets/models/shopkeeper.glb", "res://assets/models/mail_carrier.glb",
	"res://assets/models/gardener.glb", "res://assets/models/skateboarder.glb",
	"res://assets/models/baker.glb", "res://assets/models/construction_worker.glb",
	"res://assets/models/coffee_shop_owner.glb", "res://assets/models/jogger.glb",
	"res://assets/models/street_musician.glb", "res://assets/models/little_dog.glb",
	"res://assets/models/car_sports.glb", "res://assets/models/car_sedan.glb",
	"res://assets/models/car_compact.glb", "res://assets/models/truck_pickup.glb",
	"res://assets/models/car_police.glb", "res://assets/models/van_delivery.glb",
	"res://assets/models/suv.glb", "res://assets/models/van_animal_control.glb",
]
var warmup_count: int = 0 # suite handle: how many distinct models were warmed

func _warmup_models() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_boot_log("warmup skipped: no camera yet")
		return
	var scenes: Array = []
	for p in WARMUP_MODEL_PATHS:
		var ps: PackedScene = load(p)
		if ps != null:
			scenes.append(ps)
	for key in TOWN_CAT_SCENES:
		scenes.append(TOWN_CAT_SCENES[key])
	var basis_xform: Transform3D = cam.global_transform
	var fwd: Vector3 = -basis_xform.basis.z
	var right: Vector3 = basis_xform.basis.x
	var up: Vector3 = basis_xform.basis.y
	var nodes: Array = []
	var i: int = 0
	for ps in scenes:
		var inst: Node3D = (ps as PackedScene).instantiate()
		var col: int = i % 6
		var row: int = i / 6
		inst.position = basis_xform.origin + fwd * 12.0 + right * (float(col) - 2.5) * 3.0 + up * (float(row) * 2.6 - 2.0)
		add_child(inst)
		nodes.append(inst)
		i += 1
	await _build_frame()
	await _build_frame()
	await _build_frame()
	for n in nodes:
		(n as Node).queue_free()
	warmup_count = nodes.size()
	_boot_log("warmup: %d distinct models drawn behind the splash" % warmup_count)
	await _build_frame()

var gpu_warm_count: int = 0 # suite handle: distinct scenes the v1.0.26 GPU warm-up presented

# v1.0.26 PRELOAD/WARM-UP: the final boot pass, run after the
# staged reveal with the whole town live. _warmup_models() drew
# every model once behind the splash, but a model first drawn
# under the splash's lighting still pays its real shader-variant
# and upload costs the first time it appears IN PLAY — in the
# dusk sun on the street, and again under the shelter's interior
# lights. So: park the boot camera over an open street, stand one
# of every unique scene in front of it in the sun (every person
# type + the little dog, all 8 town cats, Zander, all 8 vehicles
# including the animal-control van, the playground), hold 3
# presented frames, swing the camera inside the shelter for 2
# frames so the ward's materials compile too, then free the
# cluster and put the camera back. Goal: zero first-appearance
# GPU uploads or shader compiles during play.
func _warm_up_gpu() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_boot_log("gpu warmup skipped: no camera yet")
		return
	var saved_xform: Transform3D = cam.global_transform
	var scenes: Array = []
	for p in WARMUP_MODEL_PATHS:
		var ps: PackedScene = load(p)
		if ps != null:
			scenes.append(ps)
	for key in TOWN_CAT_SCENES:
		scenes.append(TOWN_CAT_SCENES[key])
	scenes.append(preload("res://assets/models/zander.glb"))
	scenes.append(preload("res://assets/models/playground.glb"))
	var anchor := Vector3(0, 0, -11) # an open stretch of street, full dusk sun
	cam.global_position = anchor + Vector3(0, 3.4, 14.5)
	cam.look_at(anchor + Vector3(0, 0.8, 0), Vector3.UP)
	var nodes: Array = []
	var i: int = 0
	for ps in scenes:
		var inst: Node3D = (ps as PackedScene).instantiate()
		var col: int = i % 8
		var row: int = i / 8
		inst.position = anchor + Vector3((float(col) - 3.5) * 2.8, 0.1, -float(row) * 3.2)
		add_child(inst)
		nodes.append(inst)
		i += 1
	await _build_frame()
	await _build_frame()
	await _build_frame()
	cam.global_position = escape_origin + Vector3(6.5, 2.1, 6.5)
	cam.look_at(escape_origin + Vector3(-3, 1.0, -3), Vector3.UP)
	await _build_frame()
	await _build_frame()
	for n in nodes:
		(n as Node).queue_free()
	cam.global_transform = saved_xform
	gpu_warm_count = nodes.size()
	_boot_log("gpu warmup: %d distinct scenes presented in sun + shelter" % gpu_warm_count)
	await _build_frame()

func _build_world_async() -> void:
	_chunk_t0 = Time.get_ticks_msec()
	_resume_ms = _chunk_t0
	_compute_driveway_pads() # v1.0.27: pad rects must exist before the first scatter/planting reads them
	await _set_boot_stage("Starting…", 5)
	_spawn_player()
	_build_camera()
	await _build_frame()
	await _build_world()
	await _build_frame()
	await _set_boot_stage("Finishing touches", 65)
	await _build_escape_room()
	# v1.0.17: snapshot the shelter's room set, build the HOUSE room
	# into the same member vars, snapshot its set too, then rest on
	# the shelter (the opening's destination) until the first
	# capture routes somewhere.
	shelter_room_set = _capture_room_set(shelter_room_node)
	theme_groups = {}
	distract_props = []
	ward_cages = []
	await _build_house_room()
	house_room_set = _capture_room_set(house_room_node)
	_activate_escape_room(false)
	_build_escape_exterior() # v1.0.25: the street outside the escape rooms' doors (see below)
	await _build_frame()
	await _set_boot_stage("People", 75)
	await _spawn_npcs()
	_spawn_town_cats()
	await _build_frame()
	_build_pound_depot() # v1.0.21: the pound's garage + office at the west end (before the van, so its home exists when it first returns)
	await _spawn_pound()
	await _build_frame() # v1.0.11: the van + worker build is its own chunk; don't let it merge into the reveal's first stretch
	await _set_boot_stage("Warming up", 80)
	await _warmup_models() # v1.0.25 PERF: draw every model once behind the splash so nothing first-loads mid-play
	await _staged_reveal()
	await _set_boot_stage("Warming up the graphics", 97)
	_audit_tree_clearance() # v1.0.27: every tree + parked car exists by now — enforce canopy clearance before play
	await _warm_up_gpu() # v1.0.26: last pass — every unique scene presented in sun + shelter before play
	_log_stage_profile()
	_stage_name = ""
	build_complete = true
	build_finished.emit()
	if _splash_tap_queued and state == "splash":
		_splash_tap_queued = false
		dismiss_splash()

# v1.0.10 STAGED REVEAL: instead of World.visible flipping the whole
# town on in one presented frame (~11.4k draw calls hitting the GPU
# at once — the leading suspect for the S26 post-splash crash), the
# world's visible children are partitioned into 4 geographic bands
# by x and revealed band by band, with presented frames (and
# boot-log stage updates) between steps. No single presented frame goes
# from no-town to full-town. Children that were invisible for their
# own reasons are left exactly as they were.
func _staged_reveal() -> void:
	var world_node := get_node_or_null("World") as Node3D
	if world_node == null:
		return
	var edges := [-40.0, 60.0, 160.0] # town x spans -126..378
	var bands: Array = [[], [], [], []]
	for child in world_node.get_children():
		var n3 := child as Node3D
		if n3 and n3.visible:
			var b := 0
			for e in edges:
				if n3.global_position.x >= e:
					b += 1
			(bands[b] as Array).append(n3)
			n3.visible = false
		await _build_tick() # v1.0.11 chunking: ~4,650 children is not free
	_boot_write_marker("Showing the town")
	world_node.visible = true
	for i in range(4):
		await _set_boot_stage("Showing the town %d/4" % (i + 1), 82 + i * 4)
		for n3 in bands[i]:
			(n3 as Node3D).visible = true
			await _build_tick() # v1.0.11 chunking: flipping ~1-1.7k nodes visible measured up to ~185 ms unbroken on the VM — spread it like everything else
		await _build_frame()
		await _build_frame()

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
		# MAP DOUBLING (Michael, 2026-11-16/17: "double the size of
		# the map" + houses MORE DENSE — "there's still a lot of
		# space"): the town grows EAST. Five new cross streets
		# (Harbour 128, Summit 176, Quarry 224, Meadow 272, Sunset
		# 320) carry the four avenues east to a new border at
		# x=371.8, doubling the playable area. Every row below
		# keeps the standing rules: centres >= 11 from every
		# vertical centreline (footprints clear the corridors),
		# numbers strictly UP west->east, odd north / even south,
		# facing explicit. Spacing within each new block is ~13 —
		# noticeably tighter than the old rows' 40-50 gaps.
		# --- old-town INFILL: the widest empty gaps in the
		# existing rows (skipping lots that would swallow the
		# playground, the gazebo or the front-gap clusters) ---
		["11 Maple Street", Vector3(-84, 0, -30), 1.0],
		["41 Maple Street", Vector3(58, 0, -30), 1.0],
		["11 Oak Avenue", Vector3(-56, 0, 2), 1.0],
		["21 Oak Avenue", Vector3(38, 0, 2), 1.0],
		["30 Oak Avenue", Vector3(10, 0, 33), -1.0],
		["36 Oak Avenue", Vector3(58, 0, 33), -1.0],
		["7 Elm Drive", Vector3(-84, 0, -66), 1.0],
		["25 Elm Drive", Vector3(58, 0, -66), 1.0],
		["8 Elm Drive", Vector3(-84, 0, -44), -1.0],
		["26 Elm Drive", Vector3(60, 0, -44), -1.0],
		["7 Willow Crescent", Vector3(-84, 0, 44), 1.0],
		# --- EAST DISTRICT: the four avenues extended ---
		# Maple Street north row (odd)
		["43 Maple Street", Vector3(84, 0, -30), 1.0],
		["47 Maple Street", Vector3(112, 0, -30), 1.0],
		["53 Maple Street", Vector3(146, 0, -30), 1.0],
		["59 Maple Street", Vector3(159, 0, -30), 1.0],
		["65 Maple Street", Vector3(194, 0, -30), 1.0],
		["71 Maple Street", Vector3(207, 0, -30), 1.0],
		["77 Maple Street", Vector3(242, 0, -30), 1.0],
		["83 Maple Street", Vector3(255, 0, -30), 1.0],
		["89 Maple Street", Vector3(290, 0, -30), 1.0],
		["95 Maple Street", Vector3(303, 0, -30), 1.0],
		["101 Maple Street", Vector3(339, 0, -30), 1.0],
		["107 Maple Street", Vector3(352, 0, -30), 1.0],
		# Oak Avenue north row (odd)
		["31 Oak Avenue", Vector3(90, 0, 2), 1.0],
		["37 Oak Avenue", Vector3(104, 0, 2), 1.0],
		["43 Oak Avenue", Vector3(146, 0, 2), 1.0],
		["49 Oak Avenue", Vector3(159, 0, 2), 1.0],
		["55 Oak Avenue", Vector3(194, 0, 2), 1.0],
		["61 Oak Avenue", Vector3(207, 0, 2), 1.0],
		["67 Oak Avenue", Vector3(242, 0, 2), 1.0],
		["73 Oak Avenue", Vector3(255, 0, 2), 1.0],
		["79 Oak Avenue", Vector3(290, 0, 2), 1.0],
		["85 Oak Avenue", Vector3(303, 0, 2), 1.0],
		["91 Oak Avenue", Vector3(339, 0, 2), 1.0],
		["97 Oak Avenue", Vector3(352, 0, 2), 1.0],
		# Oak Avenue south row (even) — no lots in the first block:
		# the playground owns x 87..109 at this band.
		["46 Oak Avenue", Vector3(146, 0, 33), -1.0],
		["52 Oak Avenue", Vector3(159, 0, 33), -1.0],
		["58 Oak Avenue", Vector3(194, 0, 33), -1.0],
		["64 Oak Avenue", Vector3(207, 0, 33), -1.0],
		["70 Oak Avenue", Vector3(242, 0, 33), -1.0],
		["76 Oak Avenue", Vector3(255, 0, 33), -1.0],
		["82 Oak Avenue", Vector3(290, 0, 33), -1.0],
		["88 Oak Avenue", Vector3(303, 0, 33), -1.0],
		["94 Oak Avenue", Vector3(339, 0, 33), -1.0],
		["100 Oak Avenue", Vector3(352, 0, 33), -1.0],
		# Elm Drive north row (odd)
		["41 Elm Drive", Vector3(146, 0, -66), 1.0],
		["47 Elm Drive", Vector3(159, 0, -66), 1.0],
		["53 Elm Drive", Vector3(194, 0, -66), 1.0],
		["59 Elm Drive", Vector3(207, 0, -66), 1.0],
		["65 Elm Drive", Vector3(242, 0, -66), 1.0],
		["71 Elm Drive", Vector3(255, 0, -66), 1.0],
		["77 Elm Drive", Vector3(290, 0, -66), 1.0],
		["83 Elm Drive", Vector3(303, 0, -66), 1.0],
		["89 Elm Drive", Vector3(339, 0, -66), 1.0],
		["95 Elm Drive", Vector3(352, 0, -66), 1.0],
		# Elm Drive south row (even)
		["28 Elm Drive", Vector3(84, 0, -44), -1.0],
		["32 Elm Drive", Vector3(112, 0, -44), -1.0],
		["38 Elm Drive", Vector3(146, 0, -44), -1.0],
		["44 Elm Drive", Vector3(159, 0, -44), -1.0],
		["50 Elm Drive", Vector3(194, 0, -44), -1.0],
		["56 Elm Drive", Vector3(207, 0, -44), -1.0],
		["62 Elm Drive", Vector3(242, 0, -44), -1.0],
		["68 Elm Drive", Vector3(255, 0, -44), -1.0],
		["74 Elm Drive", Vector3(290, 0, -44), -1.0],
		["80 Elm Drive", Vector3(303, 0, -44), -1.0],
		["86 Elm Drive", Vector3(339, 0, -44), -1.0],
		["92 Elm Drive", Vector3(352, 0, -44), -1.0],
		# Willow Crescent north row (odd)
		["27 Willow Crescent", Vector3(84, 0, 44), 1.0],
		["31 Willow Crescent", Vector3(112, 0, 44), 1.0],
		["37 Willow Crescent", Vector3(146, 0, 44), 1.0],
		["43 Willow Crescent", Vector3(159, 0, 44), 1.0],
		["49 Willow Crescent", Vector3(194, 0, 44), 1.0],
		["55 Willow Crescent", Vector3(207, 0, 44), 1.0],
		["61 Willow Crescent", Vector3(242, 0, 44), 1.0],
		["67 Willow Crescent", Vector3(255, 0, 44), 1.0],
		["73 Willow Crescent", Vector3(290, 0, 44), 1.0],
		["79 Willow Crescent", Vector3(303, 0, 44), 1.0],
		["85 Willow Crescent", Vector3(339, 0, 44), 1.0],
		["91 Willow Crescent", Vector3(352, 0, 44), 1.0],
		# Willow Crescent south row (even)
		["30 Willow Crescent", Vector3(112, 0, 66), -1.0],
		["36 Willow Crescent", Vector3(146, 0, 66), -1.0],
		["42 Willow Crescent", Vector3(159, 0, 66), -1.0],
		["48 Willow Crescent", Vector3(194, 0, 66), -1.0],
		["54 Willow Crescent", Vector3(207, 0, 66), -1.0],
		["60 Willow Crescent", Vector3(242, 0, 66), -1.0],
		["66 Willow Crescent", Vector3(255, 0, 66), -1.0],
		["72 Willow Crescent", Vector3(290, 0, 66), -1.0],
		["78 Willow Crescent", Vector3(303, 0, 66), -1.0],
		["84 Willow Crescent", Vector3(339, 0, 66), -1.0],
		["90 Willow Crescent", Vector3(352, 0, 66), -1.0],
	]
	# BISECT (v1.0.12): the first 41 entries above are the original
	# pre-doubling houses; everything after them is MAP DOUBLING
	# content (11 old-town infill + 79 east-district houses).
	# LEGACY_TOWN_ONLY keeps the original 41 only.
	if LEGACY_TOWN_ONLY:
		data = data.slice(0, 41)
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
	# v1.0.29: eleven house lots convert to the Meshy civic /
	# commercial buildings (each civic model appears exactly once).
	# The remaining houses are re-sequenced per street row so the
	# numbers stay clean and sequential, and each house lot gets one
	# of the seven Meshy house models — never the same model on two
	# adjacent lots along a street (see _assign_house_models).
	var kept: Array = []
	civic_lots.clear()
	for h in houses:
		var key: String = "%d,%d" % [int(h["pos"].x), int(h["pos"].z)]
		if CIVIC_CONVERSIONS.has(key):
			civic_lots.append({"model": String(CIVIC_CONVERSIONS[key]), "pos": h["pos"], "facing": h["facing"], "hx": 0.0, "hz": 0.0})
		else:
			kept.append(h)
	houses = kept
	_renumber_houses()
	_assign_house_models()

# v1.0.29: re-sequence house numbers along each street row (W->E),
# keeping the odd-north / even-south parity and the ", Apartment X"
# suffix attached to its lot. Steps of 6 match the historic spacing.
func _renumber_houses() -> void:
	var starts: Dictionary = {"Maple Street|1": 3, "Oak Avenue|1": 7, "Oak Avenue|-1": 4, "Elm Drive|1": 5, "Elm Drive|-1": 6, "Willow Crescent|1": 5, "Willow Crescent|-1": 6}
	var rows: Dictionary = {}
	for h in houses:
		var addr: String = h["address"]
		var suffix: String = ""
		var ci: int = addr.find(",")
		if ci >= 0:
			suffix = addr.substr(ci)
			addr = addr.left(ci)
		var sp: int = addr.find(" ")
		var street: String = addr.substr(sp + 1)
		h["suffix"] = suffix
		h["street"] = street
		var rk: String = street + "|" + str(int(h["facing"]))
		if not rows.has(rk):
			rows[rk] = []
		rows[rk].append(h)
	for rk in rows.keys():
		var row: Array = rows[rk]
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].x < b["pos"].x)
		var n: int = int(starts.get(rk, 3))
		for h in row:
			h["address"] = str(n) + " " + h["street"] + h["suffix"]
			h["plaque"] = str(n)
			n += 6

# v1.0.29: assign the Meshy house models along each street row.
# Stepping by 2 through a 7-model cycle guarantees no two adjacent
# lots share a model; the per-row offsets were chosen so lots that
# FACE each other across a street (nearly the same x, opposite
# rows) don't share one either.
func _assign_house_models() -> void:
	var rows: Dictionary = {}
	for h in houses:
		var rk: String = h["street"] + "|" + str(int(h["facing"]))
		if not rows.has(rk):
			rows[rk] = []
		rows[rk].append(h)
	for rk in rows.keys():
		var row: Array = rows[rk]
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].x < b["pos"].x)
		var off: int = int(HOUSE_ROW_OFFSETS.get(rk, 0))
		for i in range(row.size()):
			row[i]["model"] = HOUSE_MODEL_SEQ[(off + 2 * i) % HOUSE_MODEL_SEQ.size()]

# ---------------------------------------------------------------- environment/audio
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	# DUSK (Michael, 2026-11-17): "give the city the shading of
	# dusk — it just seems too bright and flat." The sky now grades
	# from a deep evening blue overhead down to a warm amber band
	# at the horizon, and the ground side falls off into dusk
	# shadow colours instead of midday green-grey.
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
	env.ambient_light_energy = 0.45 # v1.0 step 2: less flat wash — form comes from the lights now, not ambient. DUSK: a touch lower again; the sky it samples is now blue-over-amber, so shadowed sides pick up evening colour instead of grey.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES # v0.8 (item 3): ACES keeps edges crisp; FILMIC softened the whole frame
	env.glow_enabled = false # v0.8 (item 3): bloom REMOVED — it was the main "everything goes blurry when running" cause
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.10 # v1.0 step 2: calmer, more natural colour (v0.9's 1.12 pushed neon). DUSK: back up a notch — flat colours need the extra richness once the light goes warm and low.
	env.adjustment_contrast = 1.06 # DUSK: a little more separation between lit and shadow sides (was 1.04)
	env.adjustment_brightness = 1.0 # DUSK: the midday lift (1.02) comes off; exposure now comes from the lamps and the low sun
	# v1.0 step 2: DEPTH FOG — a whisper of warm haze so distance
	# falls off like real air. This is half of why flat games look
	# flat: without aerial perspective every distance shouts at
	# the same volume. Density is low: the far riverbank softens,
	# gameplay range stays crisp.
	env.fog_enabled = true
	env.fog_light_color = Color(0.90, 0.58, 0.38) # DUSK: the haze now matches the amber horizon, so distance melts into sunset instead of grey-cream
	env.fog_light_energy = 0.75
	env.fog_density = 0.0020 # DUSK: slightly denser (was 0.0016) — more aerial perspective at range, gameplay distances stay crisp
	env.fog_sky_affect = 0.35
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	# DUSK: the sun drops from -48 to -44 degrees and its colour
	# goes from pale gold to deep amber. The angle is a measured
	# perf compromise: the shadow pass already redraws ~8,400
	# instances at -48, and lowering the sun sweeps its frustum
	# flatter across the dense town — -24 measured +2,500 draw
	# calls, -30 +2,000, -38 +1,100, all over the ~11k budget.
	# -44 lands +518 (11,468 total) while still raking light
	# noticeably lower than midday; the rest of the dusk mood is
	# carried by colour — amber sun, blue fill, sunset sky, fog.
	sun.rotation_degrees = Vector3(-44, -35, 0)
	sun.light_color = Color(1.0, 0.60, 0.32) # DUSK: deep amber (v0.9 was pale late-afternoon gold 1.0/0.88/0.72)
	sun.light_energy = 1.30 # DUSK: a touch softer than midday's 1.45 — the lamps and sky now share the work
	sun.shadow_enabled = not boot_safe_mode # v1.0.10: safe mode kills the shadow pass (the biggest single GPU cost)
	sun_light = sun
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
	fill.light_color = Color(0.42, 0.55, 0.85) # DUSK: deeper evening blue (was a pale daytime 0.72/0.82/1.0) — shadow sides read blue, not grey
	fill.light_energy = 0.30
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
		sp.modulate = Color(1.0, 0.70, 0.52, randf_range(0.9, 1.0)) # DUSK: clouds catch the sunset — warm peach, not midday white (they are unshaded sprites, so the tint IS their lighting)
		add_child(sp)
		var sp2 := Sprite3D.new()
		sp2.texture = TEX_CLOUD
		sp2.position = cloud_positions[i] + Vector3(3.5, -1.2, 0)
		sp2.pixel_size = (sc * 0.7) / 512.0
		sp2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp2.shaded = false
		sp2.modulate = Color(1.0, 0.66, 0.50, 0.65) # DUSK: ditto, the softer under-layer slightly deeper
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

# ---------------------------------------------------------------- island
# ISLAND (Michael, 2026-11-18): "I'm getting to the end of the map
# and it's just like nothingness... at least make that nothingness
# maybe like it could be an island." The town ground sits in the
# middle of an island: a grass apron runs ISLAND_MARGIN metres
# past the town footprint on every side, a sandy beach slopes
# down from the apron edge, and the sea meets the slope partway
# down (the waterline) and runs out past the camera far plane in
# every direction, so the horizon is always sea, never void.
# NATURAL SHORE (Michael, same day, after seeing the first pass):
# "Make sure it's not just like a straight line and blue. I don't
# want to see just a straight line and then just a sea of blue. I
# want to see almost like a beach — some brown, not perfect
# edges." So the beach width now wanders with smooth noise —
# bays where the water cuts in close, points where the sand juts
# out — the sand is patchy tans and browns with a darker wet band
# and a pale foam line at the waterline (vertex colours), and the
# sea grades from pale shallows at the shore to the deep dusk
# blue further out (vertex colours on the one sea mesh, far rings
# multiplying back to exactly the old flat-sea tint). Still THREE
# meshes (apron, beach, sea) and one collision body, whose wall
# segments now FOLLOW the wandering waterline ~2 m landward of
# it, so the cat stops at the shore — he doesn't swim and doesn't
# wade. The island follows town_cx / town_w, so the doubled town
# (when the bisect switch flips back) gets the same island around
# its own ground with no extra code.
const ISLAND_MARGIN := 30.0 # grass past the town ground edge
const ISLAND_BEACH_W := 20.0 # mean beach slope run, apron edge -> beach foot
const ISLAND_TOP_Y := -0.04 # apron top (a hair under the town ground top)
const ISLAND_BOT_Y := -0.90 # beach foot, below the water
const ISLAND_WATER_Y := -0.62 # sea level: meets the beach ~2/3 down
const ISLAND_CORNER_R := 40.0 # rounded island corners
# The visible waterline (x/z Vector2s, in outline order), filled
# in by _build_island — the island shot-runner probe checks the
# shore collision against these very points.
var island_waterline_pts: Array = []

func _island_outline(cx: float, hx: float, hz: float, r: float) -> Array:
	# Rounded-rectangle outline as [{p, n}] (Vector2s in the x/z
	# plane, n = outward normal), walked east -> north -> west ->
	# south. DENSE: straights are subdivided every ~9 m and the
	# corner arcs every 7.5 degrees, so the beach built on this
	# outline has enough points along its length for the shoreline
	# to wander. Offsetting a point along its normal moves it
	# straight out from the apron edge.
	var pts: Array = []
	# east straight, south -> north (also emits the walk's first point)
	var e_steps: int = maxi(1, int(round(2.0 * (hz - r) / 9.0)))
	for i in range(e_steps + 1):
		var t: float = float(i) / float(e_steps)
		pts.append({"p": Vector2(cx + hx, lerpf(-hz + r, hz - r, t)), "n": Vector2(1, 0)})
	# corner arcs: 12 steps of 7.5 deg; each arc emits its end
	# point, which is the next straight's start (not re-emitted)
	var arc_steps: int = 12
	for i in range(1, arc_steps + 1): # NE arc, 0..90 deg
		var a: float = deg_to_rad(90.0 * float(i) / float(arc_steps))
		var d := Vector2(cos(a), sin(a))
		pts.append({"p": Vector2(cx + hx - r, hz - r) + d * r, "n": d})
	var n_steps: int = maxi(1, int(round(2.0 * (hx - r) / 9.0)))
	for i in range(1, n_steps + 1): # north straight, east -> west
		var t2: float = float(i) / float(n_steps)
		pts.append({"p": Vector2(lerpf(cx + hx - r, cx - hx + r, t2), hz), "n": Vector2(0, 1)})
	for i in range(1, arc_steps + 1): # NW arc, 90..180 deg
		var a2: float = deg_to_rad(90.0 + 90.0 * float(i) / float(arc_steps))
		var d2 := Vector2(cos(a2), sin(a2))
		pts.append({"p": Vector2(cx - hx + r, hz - r) + d2 * r, "n": d2})
	for i in range(1, e_steps + 1): # west straight, north -> south
		var t3: float = float(i) / float(e_steps)
		pts.append({"p": Vector2(cx - hx, lerpf(hz - r, -hz + r, t3)), "n": Vector2(-1, 0)})
	for i in range(1, arc_steps + 1): # SW arc, 180..270 deg
		var a3: float = deg_to_rad(180.0 + 90.0 * float(i) / float(arc_steps))
		var d3 := Vector2(cos(a3), sin(a3))
		pts.append({"p": Vector2(cx - hx + r, -hz + r) + d3 * r, "n": d3})
	for i in range(1, n_steps + 1): # south straight, west -> east
		var t4: float = float(i) / float(n_steps)
		pts.append({"p": Vector2(lerpf(cx - hx + r, cx + hx - r, t4), -hz), "n": Vector2(0, -1)})
	for i in range(1, arc_steps): # SE arc, 270..360 deg (360 = first point, via wrap)
		var a4: float = deg_to_rad(270.0 + 90.0 * float(i) / float(arc_steps))
		var d4 := Vector2(cos(a4), sin(a4))
		pts.append({"p": Vector2(cx + hx - r, -hz + r) + d4 * r, "n": d4})
	return pts

func _island_beach_w(theta: float) -> float:
	# Beach width at a point, from its angle around the island
	# centre: a sum of smooth sinusoids, so the waterline wanders
	# in gentle bays and points — never a long straight run, never
	# symmetric. Integer frequencies keep it continuous all the
	# way round the loop (including across the +/-pi wrap).
	var v: float = 0.34 * sin(3.0 * theta + 1.7) + 0.20 * sin(5.0 * theta + 0.3)
	v += 0.13 * sin(9.0 * theta + 2.6) + 0.07 * sin(17.0 * theta + 0.9)
	return clampf(ISLAND_BEACH_W * (1.0 + v), 7.0, 34.0)

func _build_island(world: Node3D, town_cx: float, town_w: float) -> void:
	var hx: float = town_w * 0.5 + ISLAND_MARGIN
	var hz: float = 96.0 + ISLAND_MARGIN
	var outline: Array = _island_outline(town_cx, hx, hz, ISLAND_CORNER_R)
	var count: int = outline.size()
	var wl_frac: float = (ISLAND_WATER_Y - ISLAND_TOP_Y) / (ISLAND_BOT_Y - ISLAND_TOP_Y)
	# Per-point shore data: cumulative outline length (for UVs and
	# the sand patchiness), beach width (noise), the waterline
	# point, and the shore-collision centre-line point (the
	# waterline pulled 1.5 m landward, so a 1 m thick wall centred
	# on it presents its face exactly ~2 m short of the water).
	var cum: Array = [0.0]
	for i in range(count):
		var pa: Vector2 = outline[i]["p"]
		var pb: Vector2 = outline[(i + 1) % count]["p"]
		cum.append(float(cum[i]) + pa.distance_to(pb))
	var widths := PackedFloat32Array()
	var patches := PackedColorArray()
	var wl_pts: Array = []
	var col_pts: Array = []
	for i in range(count):
		var e: Dictionary = outline[i]
		var p: Vector2 = e["p"]
		var n: Vector2 = e["n"]
		var w: float = _island_beach_w(atan2(p.y, p.x - town_cx))
		widths.append(w)
		wl_pts.append(p + n * (w * wl_frac))
		col_pts.append(p + n * (w * wl_frac - 1.5))
		var s: float = float(cum[i])
		var pn: float = 0.5 + 0.5 * sin(s * 0.021 + 1.3) * sin(s * 0.0083 + 0.5)
		var pc: Color = Color(1, 1, 1).lerp(Color(0.84, 0.74, 0.62), pn * 0.55)
		var grain: float = 0.97 + 0.05 * sin(s * 0.11 + 0.7)
		patches.append(Color(pc.r * grain, pc.g * grain, pc.b * grain))
	island_waterline_pts = wl_pts.duplicate()
	# --- grass apron: ONE triangle fan over the outline, UVs in
	# world units at the town grass tiling (50 repeats per 252 m)
	# so the apron reads as the same lawn running on. Its edge
	# stays the steady rounded outline — the wandering all happens
	# seaward of it, in the beach.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.append(Vector3(town_cx, ISLAND_TOP_Y, 0.0))
	normals.append(Vector3.UP)
	uvs.append(Vector2(town_cx, 0.0) * 0.198)
	for e in outline:
		var p: Vector2 = e["p"]
		verts.append(Vector3(p.x, ISLAND_TOP_Y, p.y))
		normals.append(Vector3.UP)
		uvs.append(p * 0.198)
	var idx := PackedInt32Array()
	for i in range(count):
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % count)
	var top_arrays: Array = []
	top_arrays.resize(Mesh.ARRAY_MAX)
	top_arrays[Mesh.ARRAY_VERTEX] = verts
	top_arrays[Mesh.ARRAY_NORMAL] = normals
	top_arrays[Mesh.ARRAY_TEX_UV] = uvs
	top_arrays[Mesh.ARRAY_INDEX] = idx
	var top_mesh := ArrayMesh.new()
	top_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays)
	var top := MeshInstance3D.new()
	top.name = "IslandTop"
	top.mesh = top_mesh
	var top_mat := _mat_tex(TEX_GRASS, Color(0.66, 0.78, 0.58), Vector3(1, 1, 1))
	top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	top.material_override = top_mat
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(top)
	# SHORELINE ACCESS (v1.0.14): the apron and beach carry real
	# floor collision (trimesh from the very meshes above), so the
	# cat can walk out of town across the grass and down the sand
	# to the shore wall — before this, the town ground box ended
	# at x=-150 / z=+/-107 and he would have fallen through the
	# island. The town box (top y=0) still wins inside the town;
	# the apron top sits 4 cm lower, an invisible step down.
	top.create_trimesh_collision()
	# --- beach: ONE strip of quad rows down the slope, each point
	# offset along its normal by ITS OWN noise width, so the foot
	# of the beach — and the waterline crossing it — wanders. The
	# rows carry the colour story (vertex colours multiplying the
	# sand tint): dry sand at the top, patchy browns along the
	# length, a darker WET band, then a pale FOAM line right at
	# the waterline. Row: [t down the slope, colour, patch strength]
	var rows: Array = [
		[0.0, Color(1.03, 1.00, 0.94), 1.0],
		[0.35, Color(0.99, 0.95, 0.88), 1.0],
		[0.56, Color(0.80, 0.71, 0.60), 0.8],
		[0.645, Color(1.10, 1.08, 1.02), 0.35],
		[wl_frac, Color(1.06, 1.05, 1.00), 0.35],
		[1.0, Color(0.55, 0.50, 0.45), 0.5],
	]
	var bverts := PackedVector3Array()
	var bnormals := PackedVector3Array()
	var buvs := PackedVector2Array()
	var bcols := PackedColorArray()
	for i in range(count):
		var j: int = (i + 1) % count
		var p0: Vector2 = outline[i]["p"]
		var p1: Vector2 = outline[j]["p"]
		var n0: Vector2 = outline[i]["n"]
		var n1: Vector2 = outline[j]["n"]
		var w0: float = widths[i]
		var w1: float = widths[j]
		var tilt0: float = (ISLAND_TOP_Y - ISLAND_BOT_Y) / w0
		var tilt1: float = (ISLAND_TOP_Y - ISLAND_BOT_Y) / w1
		var nr0 := Vector3(-n0.x * tilt0, 1.0, -n0.y * tilt0).normalized()
		var nr1 := Vector3(-n1.x * tilt1, 1.0, -n1.y * tilt1).normalized()
		var u0: float = float(cum[i]) * 0.198
		var u1: float = float(cum[i + 1]) * 0.198
		for r in range(rows.size() - 1):
			var t0: float = float(rows[r][0])
			var t1: float = float(rows[r + 1][0])
			var y0: float = lerpf(ISLAND_TOP_Y, ISLAND_BOT_Y, t0)
			var y1: float = lerpf(ISLAND_TOP_Y, ISLAND_BOT_Y, t1)
			var a0 := Vector3(p0.x + n0.x * w0 * t0, y0, p0.y + n0.y * w0 * t0)
			var a1 := Vector3(p0.x + n0.x * w0 * t1, y1, p0.y + n0.y * w0 * t1)
			var b0 := Vector3(p1.x + n1.x * w1 * t0, y0, p1.y + n1.y * w1 * t0)
			var b1 := Vector3(p1.x + n1.x * w1 * t1, y1, p1.y + n1.y * w1 * t1)
			var rc0: Color = rows[r][1]
			var rc1: Color = rows[r + 1][1]
			var pc0: Color = Color(1, 1, 1).lerp(patches[i], float(rows[r][2]))
			var pc1: Color = Color(1, 1, 1).lerp(patches[j], float(rows[r][2]))
			var pd0: Color = Color(1, 1, 1).lerp(patches[i], float(rows[r + 1][2]))
			var pd1: Color = Color(1, 1, 1).lerp(patches[j], float(rows[r + 1][2]))
			bverts.append_array([a0, a1, b0, b0, a1, b1])
			bnormals.append_array([nr0, nr0, nr1, nr1, nr0, nr1])
			bcols.append_array([rc0 * pc0, rc1 * pd0, rc0 * pc1, rc0 * pc1, rc1 * pd0, rc1 * pd1])
			buvs.append_array([Vector2(u0, t0 * 1.2), Vector2(u0, t1 * 1.2), Vector2(u1, t0 * 1.2), Vector2(u1, t0 * 1.2), Vector2(u0, t1 * 1.2), Vector2(u1, t1 * 1.2)])
	var beach_arrays: Array = []
	beach_arrays.resize(Mesh.ARRAY_MAX)
	beach_arrays[Mesh.ARRAY_VERTEX] = bverts
	beach_arrays[Mesh.ARRAY_NORMAL] = bnormals
	beach_arrays[Mesh.ARRAY_TEX_UV] = buvs
	beach_arrays[Mesh.ARRAY_COLOR] = bcols
	var beach_mesh := ArrayMesh.new()
	beach_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, beach_arrays)
	var beach := MeshInstance3D.new()
	beach.name = "IslandBeach"
	beach.mesh = beach_mesh
	# Sand = the grass grain tinted dry-straw: it gives the slope a
	# surface instead of flat colour, and (being a textured ground
	# surface, like every other ground in town) it keeps the suite's
	# clutter catch-all from mistaking the ring for a prop.
	var beach_mat := _mat_tex(TEX_GRASS, Color(1.06, 0.9, 0.55), Vector3(1, 1, 1), 0.98)
	beach_mat.vertex_color_use_as_albedo = true
	beach_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beach.material_override = beach_mat
	beach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(beach)
	# SHORELINE ACCESS (v1.0.14): beach floor collision, as above.
	beach.create_trimesh_collision()
	# --- the sea: ONE mesh built as rings around the waterline
	# outline, so the shallow edge hugs the wandering shore.
	# Vertex colours grade it from pale sandy shallows at the
	# waterline out to the deep dusk blue; the far rings multiply
	# back to exactly the old flat-sea tint (shallow tint x deep
	# vertex colour = (0.36, 0.52, 0.85)), and the amber fog still
	# melts the distance into the horizon. UVs keep the river's
	# texture tiling (one tile per ~9.6 m).
	var sea_offs: Array = [0.0, 6.0, 18.0, 45.0, 110.0, 260.0, 520.0, 950.0]
	var sea_cols: Array = [
		Color(1.00, 1.00, 1.00), Color(0.97, 0.98, 0.99), Color(0.88, 0.90, 0.95),
		Color(0.74, 0.79, 0.90), Color(0.62, 0.685, 0.895), Color(0.58, 0.667, 0.895),
		Color(0.58, 0.667, 0.895), Color(0.58, 0.667, 0.895),
	]
	var sverts := PackedVector3Array()
	var snormals := PackedVector3Array()
	var suvs := PackedVector2Array()
	var scols := PackedColorArray()
	var sidx := PackedInt32Array()
	sverts.append(Vector3(town_cx, ISLAND_WATER_Y, 0.0))
	snormals.append(Vector3.UP)
	suvs.append(Vector2(town_cx, 0.0) * 0.1045)
	scols.append(sea_cols[sea_cols.size() - 1])
	for k in range(sea_offs.size()):
		var off: float = float(sea_offs[k])
		for i in range(count):
			var wp: Vector2 = wl_pts[i] + (outline[i]["n"] as Vector2) * off
			sverts.append(Vector3(wp.x, ISLAND_WATER_Y, wp.y))
			snormals.append(Vector3.UP)
			suvs.append(wp * 0.1045)
			scols.append(sea_cols[k])
	for i in range(count): # centre fan out to the waterline ring
		sidx.append(0)
		sidx.append(1 + i)
		sidx.append(1 + (i + 1) % count)
	for k in range(sea_offs.size() - 1):
		var base0: int = 1 + k * count
		var base1: int = 1 + (k + 1) * count
		for i in range(count):
			var j2: int = (i + 1) % count
			sidx.append(base0 + i)
			sidx.append(base1 + i)
			sidx.append(base0 + j2)
			sidx.append(base0 + j2)
			sidx.append(base1 + i)
			sidx.append(base1 + j2)
	var sea_arrays: Array = []
	sea_arrays.resize(Mesh.ARRAY_MAX)
	sea_arrays[Mesh.ARRAY_VERTEX] = sverts
	sea_arrays[Mesh.ARRAY_NORMAL] = snormals
	sea_arrays[Mesh.ARRAY_TEX_UV] = suvs
	sea_arrays[Mesh.ARRAY_COLOR] = scols
	sea_arrays[Mesh.ARRAY_INDEX] = sidx
	var sea_mesh := ArrayMesh.new()
	sea_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sea_arrays)
	var water := MeshInstance3D.new()
	water.name = "IslandWater"
	water.mesh = sea_mesh
	var water_mat := _mat_tex(TEX_WATER, Color(0.62, 0.78, 0.95), Vector3(1, 1, 1), 0.28)
	water_mat.vertex_color_use_as_albedo = true
	water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.material_override = water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(water)
	# --- shore collision: wall segments FOLLOWING the waterline
	# (chords of ~9 m along the collision centre-line), so
	# anything that ever gets past the town border still stops
	# ~2 m short of the water everywhere — at the bays where the
	# sea cuts in close just as much as at the points.
	var shore := StaticBody3D.new()
	shore.name = "IslandShore"
	var seg_a: Vector2 = col_pts[0]
	for step in range(1, count + 1):
		var q: Vector2 = col_pts[step % count]
		if seg_a.distance_to(q) >= 9.0 or step == count:
			if seg_a.distance_to(q) > 0.5:
				var d: Vector2 = q - seg_a
				var cs := CollisionShape3D.new()
				var sh := BoxShape3D.new()
				sh.size = Vector3(d.length() + 1.2, 3.0, 1.0)
				cs.shape = sh
				var mid: Vector2 = (seg_a + q) * 0.5
				cs.position = Vector3(mid.x, 0.5, mid.y)
				cs.rotation.y = atan2(-d.y, d.x)
				shore.add_child(cs)
			seg_a = q
	world.add_child(shore)

# ---------------------------------------------------------------- world

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "World"
	# v1.0.9: the town builds INVISIBLE and is revealed whole when
	# the build completes (_build_world_async). The opaque splash
	# covers the screen the entire time, so the player sees no
	# difference — but loading frames stay cheap (nothing to render
	# but the splash), on the phone and everywhere else.
	world.visible = false
	add_child(world)
	# Grass base (v0.6 EXPANDED MAP: 252 x 192, was 130 x 96) + park lawn
	# MAP DOUBLING: the lawn now runs 504 x 192 (x -126..378) — the
	# town grew EAST by a full second district (see _define_houses).
	# BISECT (v1.0.12): in LEGACY_TOWN_ONLY mode the ground, roads
	# and borders use the pre-doubling 252-wide footprint centred
	# on x=0, and every scatter range stops at the legacy east edge.
	var town_cx: float = 0.0 if LEGACY_TOWN_ONLY else 126.0 # footprint centre x
	var town_w: float = 252.0 if LEGACY_TOWN_ONLY else 504.0 # footprint width
	var town_east: float = 119.8 if LEGACY_TOWN_ONLY else 371.8 # east border wall x
	var x_hi: float = 118.0 if LEGACY_TOWN_ONLY else 366.0 # scatter east edge
	var grass_base := _box(world, Vector3(town_cx, -0.25, 0), Vector3(town_w, 0.5, 192), Color.WHITE)
	grass_base.material_override = _mat_tex(TEX_GRASS, Color(0.72, 0.84, 0.64), Vector3(50.0 if LEGACY_TOWN_ONLY else 100.0, 38, 1))
	# Invisible solid ground (town + escape room) so physics / jumping work
	# SHORELINE ACCESS (v1.0.14): this used to be ONE 760-wide box
	# centred at x=230 — it roofed the whole EAST beach at y=0, so
	# out there the cat would have floated half a metre over the
	# sloping sand. Now the town box hugs the town footprint (the
	# island trimesh floor takes over past it, 4 cm lower) and the
	# escape room gets its own smaller box.
	var ground_body := StaticBody3D.new()
	var ground_cs := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(town_w + 24.0, 1.0, 214)
	ground_cs.shape = ground_shape
	ground_cs.position = Vector3(town_cx, -0.5, 0)
	ground_body.add_child(ground_cs)
	var room_cs := CollisionShape3D.new()
	var room_shape := BoxShape3D.new()
	room_shape.size = Vector3(60, 1.0, 60)
	room_cs.shape = room_shape
	room_cs.position = Vector3(560, -0.5, 0)
	ground_body.add_child(room_cs)
	world.add_child(ground_body)
	# ISLAND: grass apron + beach + sea around the town ground
	# (three meshes and one collision body — see _build_island).
	_build_island(world, town_cx, town_w)
	var park_lawn := _box(world, Vector3(-38, 0.02, 24), Vector3(34, 0.06, 18), Color.WHITE)
	park_lawn.material_override = _mat_tex(TEX_GRASS_PARK, Color(0.78, 0.9, 0.7), Vector3(9, 5, 1))
	# Deterministic scatter RNG for the expansion (seed 777): the map is
	# identical every run, so its landmarks can be learned.
	var srng := RandomNumberGenerator.new()
	srng.seed = 777
	var road_zs: Array = [-55.0, -11.0, 15.0, 55.0]
	var road_xs: Array = [-70.0, -20.0, 24.0, 72.0] if LEGACY_TOWN_ONLY else [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0] # MAP DOUBLING: + Harbour/Summit/Quarry/Meadow/Sunset (BISECT: legacy mode keeps the original four cross streets)
	# Grass tufts: little crossed blade clusters scattered on the lawns
	for i in range(170 if LEGACY_TOWN_ONLY else 340): # v0.9: nearly double the ground detail; MAP DOUBLING: doubled again for the east district (BISECT: legacy count in legacy mode)
		await _build_tick() # v1.0.11 chunking (before the road check, so `continue` can't skip it)
		var tp2 := Vector3(srng.randf_range(-118, x_hi), 0.22, srng.randf_range(-88, 88))
		var on_road_t := false
		for rz2 in road_zs:
			if abs(tp2.z - rz2) < 6.5: on_road_t = true
		for rx2 in road_xs:
			if abs(tp2.x - rx2) < 6.5: on_road_t = true
		# v1.0.26: the tufts obey the SAME ground rule as the
		# multimesh scatter — grass only, never on sidewalks,
		# paths, parking pads or the promenade (their old check
		# knew only the road bands, so tufts sprouted through
		# the promenade concrete).
		if on_road_t or _ground_spot_blocked(tp2):
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
	# v1.0.23: no CULL_DISABLED here any more — the blade is a cone
	# now (see _blade_mesh); double-sided rendering was half of
	# the black-spike bug.
	blade_mat.vertex_color_use_as_albedo = true
	await _scatter_multimesh(world, detail_rng, _blade_mesh(), 12000 if LEGACY_TOWN_ONLY else 24000, blade_mat, [Color(0.34, 0.56, 0.22), Color(0.3, 0.5, 0.19), Color(0.39, 0.61, 0.25), Color(0.32, 0.53, 0.2)], 0.02, 0.6, 1.1, 60.0) # PERF: blades drawn only within 60m (chunked cells); MAP DOUBLING: count doubled with the area (cells keep the draw cost flat) (BISECT: pre-doubling count in legacy mode)
	# v1.0.26 FLOWERS (Michael, playing v1.0.25, asked what the
	# little coloured balls on the lawn were): this scatter used
	# to drop bare coloured SPHERES — no stem, no petals — so
	# they read as balls sitting on the grass. A flower is now a
	# thin green stem lifting a petal head clear of the blades,
	# built and scattered by _scatter_flowers: same count, same
	# 45 m cell range, same lawn-only rejection (promenade and
	# pads included), two multimeshes per occupied cell — stems
	# on a plain green material the instance colours never
	# touch, heads instance-coloured from this same palette.
	await _scatter_flowers(world, detail_rng, 380 if LEGACY_TOWN_ONLY else 760, [Color(0.98, 0.55, 0.65), Color(0.99, 0.85, 0.35), Color(0.97, 0.96, 0.92), Color(0.78, 0.65, 0.95)])
	await _set_boot_stage("Building streets", 40) # v1.0.10 boot readout
	# Roads: FOUR horizontal + NINE vertical (v0.6 had four vertical;
	# MAP DOUBLING added five east), with sidewalks + dashes
	# BISECT (v1.0.12): the horizontals span the footprint (town_w)
	# and the verticals come from road_xs — legacy mode builds the
	# original 4 + 4 street grid only.
	var dash_hi: int = 121 if LEGACY_TOWN_ONLY else 373
	for rz in road_zs:
		var walk_h := _box(world, Vector3(town_cx, 0.03, rz), Vector3(town_w, 0.06, 9.6), Color.WHITE)
		walk_h.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(62.0 if LEGACY_TOWN_ONLY else 124.0, 2, 1))
		var road_h := _box(world, Vector3(town_cx, 0.06, rz), Vector3(town_w, 0.06, 7.2), Color.WHITE)
		road_h.material_override = _mat_tex(TEX_ASPHALT, Color.WHITE, Vector3(50.0 if LEGACY_TOWN_ONLY else 100.0, 2, 1), 0.97)
		for dx in range(-120, dash_hi, 6):
			_box(world, Vector3(dx, 0.1, rz), Vector3(2.6, 0.03, 0.35), Color(0.95, 0.85, 0.4))
			await _build_tick() # v1.0.11 chunking: 83 dashes per road had no yield at all
	for rx in road_xs:
		var walk_v := _box(world, Vector3(rx, 0.04, 0), Vector3(9.6, 0.06, 192), Color.WHITE)
		walk_v.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(2, 48, 1))
		var road_v := _box(world, Vector3(rx, 0.07, 0), Vector3(7.2, 0.06, 192), Color.WHITE)
		road_v.material_override = _mat_tex(TEX_ASPHALT, Color.WHITE, Vector3(2, 40, 1), 0.97)
		for dz in range(-90, 91, 6):
			_box(world, Vector3(rx, 0.11, dz), Vector3(0.35, 0.03, 2.6), Color(0.95, 0.85, 0.4))
			await _build_tick() # v1.0.11 chunking
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
	# MAP DOUBLING: the five new east cross streets, two signs each
	# BISECT (v1.0.12): no east streets in legacy mode, no east signs.
	if not LEGACY_TOWN_ONLY:
		_sign(world, "HARBOUR STREET", Vector3(122, 0, -16), "Harbour Street", 90.0)
		_sign(world, "HARBOUR STREET", Vector3(134, 0, 44), "Harbour Street", 90.0)
		_sign(world, "SUMMIT AVENUE", Vector3(170, 0, -16), "Summit Avenue", 90.0)
		_sign(world, "SUMMIT AVENUE", Vector3(182, 0, 44), "Summit Avenue", 90.0)
		_sign(world, "QUARRY LANE", Vector3(218, 0, -16), "Quarry Lane", 90.0)
		_sign(world, "QUARRY LANE", Vector3(230, 0, 44), "Quarry Lane", 90.0)
		_sign(world, "MEADOW DRIVE", Vector3(266, 0, -16), "Meadow Drive", 90.0)
		_sign(world, "MEADOW DRIVE", Vector3(278, 0, 44), "Meadow Drive", 90.0)
		_sign(world, "SUNSET DRIVE", Vector3(314, 0, -16), "Sunset Drive", 90.0)
		_sign(world, "SUNSET DRIVE", Vector3(326, 0, 44), "Sunset Drive", 90.0)
	_sign(world, "PARK", Vector3(-52, 0, 20.8))
	_sign(world, "THE RIVER", Vector3(58, 0, -86))
	await _build_tick()
	await _set_boot_stage("Placing houses", 55) # v1.0.10 boot readout
	# Houses
	var wall_cols: Array = [Color(0.96, 0.9, 0.8), Color(0.82, 0.87, 0.96), Color(0.96, 0.83, 0.72), Color(0.86, 0.93, 0.83), Color(0.95, 0.78, 0.82), Color(0.9, 0.85, 0.95), Color(0.98, 0.93, 0.72), Color(0.8, 0.92, 0.9)]
	var roof_cols: Array = [Color(0.72, 0.33, 0.28), Color(0.33, 0.47, 0.72), Color(0.42, 0.6, 0.38), Color(0.78, 0.57, 0.28), Color(0.5, 0.35, 0.55), Color(0.3, 0.55, 0.6), Color(0.65, 0.4, 0.25), Color(0.45, 0.45, 0.5)]
	for i in range(houses.size()):
		var _ht := Time.get_ticks_msec()
		var _yw := _yield_wait_total
		await _build_house(world, houses[i], wall_cols[i % 8], roof_cols[(i * 3 + 1) % 8])
		# Pure construction work only: subtract the time the house's
		# own internal ticks spent waiting on presented frames.
		var _hd := (Time.get_ticks_msec() - _ht) - (_yield_wait_total - _yw)
		if _hd > _houses_max_ms:
			_houses_max_ms = _hd
			_houses_max_addr = str(houses[i]["address"])
		# v1.0.11: every 16 houses the marker + boot log name the
		# exact house reached, so a launch that dies in this loop
		# leaves evidence on disk. (The on-screen splash counter
		# that used to mirror this was removed in v1.0.14.)
		if (i + 1) % 16 == 0:
			_boot_write_marker("Placing houses — %d/%d" % [i + 1, houses.size()])
			_boot_log("Placing houses — %d/%d" % [i + 1, houses.size()])
		await _build_tick()
	# v1.0.29: the Meshy civic/commercial buildings on the lots
	# converted in _define_houses (school, library, stations...).
	_build_civic_buildings(world)
	await _build_tick()
	await _set_boot_stage("Street trees", 56) # v1.0.12 readout: this block hid under "Placing houses" with no stage of its own
	var street_trees_planted: int = 0
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
					for rxg in road_xs:
						if absf(midx - rxg) < 9.0:
							midx += 10.0 if midx >= rxg else -10.0
					_build_tree(world, Vector3(midx, 0, hz2 - hf2 * 8.0))
					street_trees_planted += 1
					await _build_tick() # v1.0.11 chunking: this whole street-trees block ran ~383 ms with no yield at all
	await _build_tick()
	# Trees, bushes (fixed dressing + deterministic scatter in new districts)
	var tree_positions: Array = [Vector3(-56, 0, -38), Vector3(-14, 0, -40), Vector3(52, 0, -24), Vector3(54, 0, 40), Vector3(-58, 0, 40), Vector3(2, 0, 24), Vector3(-34, 0, -20), Vector3(48, 0, -4)] # v0.9: (-2,-38) moved — an Elm-south house stands there now
	for tp in tree_positions:
		_build_tree(world, tp)
	# v0.9: scatter now collects ALL valid spots, shuffles them
	# (seeded) and plants evenly across the WHOLE map — v0.8 filled
	# west-to-east until its cap ran out, which is exactly why the
	# east and south felt empty. Caps nearly doubled, too.
	await _set_boot_stage("Scattering trees", 58) # v1.0.12 readout: the tree scatter hid under "Placing houses" too
	var tree_cap: int = 46 if LEGACY_TOWN_ONLY else 92 # MAP DOUBLING: cap doubled with the area (BISECT: pre-doubling cap in legacy mode)
	var tree_scan_hi: int = 113 if LEGACY_TOWN_ONLY else 361 # BISECT: candidate scan stops at the legacy east edge
	var tree_cands: Array = []
	for gx in range(-112, tree_scan_hi, 13):
		await _build_tick() # v1.0.11 chunking: the candidate scan distance-checks every grid point against all 131 houses, unyielded before
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
			if cand.distance_to(Vector3(248, 0, -76)) < 10.5: bad = true # MAP DOUBLING: Meadow Court block
			if cand.distance_to(Vector3(296, 0, 79)) < 6.5: bad = true # MAP DOUBLING: Sunset Green fountain
			if cand.distance_to(Vector3(197, 0, -21)) < 6.5: bad = true # MAP DOUBLING: Harbour Market stalls
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
		if scattered_trees >= tree_cap:
			break
		_build_tree(world, cand2)
		scattered_trees += 1
		await _build_tick()
	var bush_positions: Array = [Vector3(-12, 0, -20), Vector3(30, 0, -22), Vector3(-30, 0, 8), Vector3(44, 0, 24), Vector3(-52, 0, -18.5), Vector3(6, 0, 38)] # CLUTTER: the -52 bush stood at z=-14, inside the Maple asphalt; now north of its sidewalk
	for bp in bush_positions:
		_build_bush(world, bp)
		hide_points.append(bp)
	await _set_boot_stage("Scattering bushes", 59) # v1.0.12 readout: the bush scatter hid under "Placing houses" too
	var bush_cap: int = 26 if LEGACY_TOWN_ONLY else 52 # MAP DOUBLING: cap doubled with the area (BISECT: pre-doubling cap in legacy mode)
	var bush_scan_hi: int = 106 if LEGACY_TOWN_ONLY else 358 # BISECT: candidate scan stops at the legacy east edge
	var bush_cands: Array = []
	for gx2 in range(-105, bush_scan_hi, 17):
		await _build_tick() # v1.0.11 chunking (same scan pattern as the trees)
		for gz2 in range(-77, 78, 17):
			var bcand := Vector3(float(gx2) + srng.randf_range(-5, 5), 0, float(gz2) + srng.randf_range(-5, 5))
			var bbad := false
			for rz4 in road_zs:
				if abs(bcand.z - rz4) < 7.0: bbad = true
			for rx4 in road_xs:
				if abs(bcand.x - rx4) < 7.0: bbad = true
			for hh2 in houses:
				if bcand.distance_to(hh2["pos"]) < 9.0: bbad = true
			if bcand.distance_to(Vector3(248, 0, -76)) < 10.5: bbad = true # MAP DOUBLING: Meadow Court
			if bcand.distance_to(Vector3(296, 0, 79)) < 6.5: bbad = true # MAP DOUBLING: Sunset Green
			if bcand.distance_to(Vector3(197, 0, -21)) < 6.5: bbad = true # MAP DOUBLING: Harbour Market
			if bbad:
				continue
			bush_cands.append(bcand)
	for si2 in range(bush_cands.size() - 1, 0, -1):
		var sj2: int = srng.randi_range(0, si2)
		var stmp2 = bush_cands[si2]; bush_cands[si2] = bush_cands[sj2]; bush_cands[sj2] = stmp2
	var scattered_bushes: int = 0
	for bcand2 in bush_cands:
		if scattered_bushes >= bush_cap:
			break
		_build_bush(world, bcand2)
		await _build_tick()
		hide_points.append(bcand2)
		scattered_bushes += 1
	# Cars: FIVE types (v0.6), several colours, all hiding spots.
	# STREETS (Michael, 2026-11-16): "there shouldn't be anything
	# but cars on streets... there should be cars in people's
	# driveways and moving cars on the streets, not just cars
	# sitting still on the street." The v0.6 set parked TWELVE of
	# its thirteen cars ON the roadways (centred on the Maple /
	# Oak / Elm / Willow centrelines) and the thirteenth on a
	# lawn. Every one now sits in a house DRIVEWAY (see
	# _park_in_driveway) — same cars, colours and types, still
	# hiding spots — so the only vehicles on a roadway are the
	# moving traffic. Audit: tests/StreetsProbe.tscn (0 on asphalt,
	# also asserted in the test suite).
	await _build_tick()
	var house_by_pos: Dictionary = {}
	for hh in houses:
		house_by_pos["%d,%d" % [int(hh["pos"].x), int(hh["pos"].z)]] = hh
	var driveway_data: Array = _driveway_data() # v1.0.27: shared with _compute_driveway_pads (see _park_in_driveway)
	for dd in driveway_data:
		var dh: Dictionary = house_by_pos["%d,%d" % [int((dd[0] as Vector3).x), int((dd[0] as Vector3).z)]]
		var dpos: Vector3 = _park_in_driveway(world, dh["pos"], float(dh["facing"]), float(dd[2]), float(dd[1]), dd[3], dd[4])
		hide_points.append(dpos)
		await _build_tick()
	await _build_tick()
	# Park fence with a gap, benches, pond, flowers. v0.7: this fence
	# used to stand at z=15.5 — right IN the Oak Avenue roadway (the
	# bare posts in Michael's photo). It now runs along the park's
	# south edge at z=20.6 and it is SOLID (posts + rails collide),
	# with two solid runs leaving only the cat gap open.
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
	# garden fences get matching gaps. (Floating "cat gap" labels over
	# the gaps removed 2026-11-18 at Michael's direction — the gaps
	# stay, unsigned.)
	ender_points.append(Vector3(-37, 0, 20.6))
	# v0.7: the second garden fence used to run along x=-70 — IN the
	# Pine Street roadway. It now stands at x=-63, off the road, and
	# both garden fences are SOLID (posts + rails collide) except for
	# the cat gap itself.
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
	var pond := _cyl(world, Vector3(-44, 0.08, 26), 3.2, 3.2, 0.16, Color.WHITE)
	pond.material_override = _mat_tex(TEX_WATER, Color.WHITE, Vector3(3, 3, 1), 0.35) # pond
	content_points.append(Vector3(-44, 0, 26)) # v0.9 audit: park 1
	content_points.append(Vector3(-38, 0, 24))
	for bpos in [Vector3(-30, 0, 22), Vector3(-27, 0, 28)]: # CLUTTER: the -24 bench's east end crossed the Cedar corridor
		_box(world, bpos + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
		_box(world, bpos + Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		_box(world, bpos + Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	var park_flower_spots: Array = []
	for i in range(26):
		var fp := Vector3(randf_range(-54, -24.5), 0.16, randf_range(19.2, 32)) # CLUTTER: z<19.2 put flowers on the Oak asphalt (edge 18.6); x>-24.5 put them on Cedar (edge -23.6)
		park_flower_spots.append([Vector3(fp.x, 0.02, fp.z), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.9, 0.9, 0.95)][i % 3], 1.15]) # v1.0.26 completion: stem+daisy via _place_flowers (was a bare sphere)
		await _build_tick() # v1.0.11 chunking
	_place_flowers(world, park_flower_spots)
	await _build_tick()
	# Crosswalks at the main intersections (BISECT: road_xs is the
	# legacy four in legacy mode, all nine otherwise)
	for cx in road_xs:
		await _build_tick() # v1.0.11 chunking (before the filter, so `continue` can't skip it)
		for cz in [-55.0, -11.0, 15.0, 55.0]:
			if not ((cx == -20.0 or cx == 24.0) or (cz == -11.0 or cz == 15.0)):
				continue
			for s in range(-3, 4):
				_box(world, Vector3(cx + float(s) * 1.05, 0.12, cz - 5.6), Vector3(0.62, 0.03, 2.6), Color(0.94, 0.94, 0.92))
				_box(world, Vector3(cx - 5.6, 0.12, cz + float(s) * 1.05), Vector3(2.6, 0.03, 0.62), Color(0.94, 0.94, 0.92))
	for i in range(36 if LEGACY_TOWN_ONLY else 72): # MAP DOUBLING: count doubled with the area (BISECT: pre-doubling count in legacy mode)
		await _build_tick() # v1.0.11 chunking (before the road check, so `continue` can't skip it)
		var gp := Vector3(srng.randf_range(-118, x_hi), 0.045, srng.randf_range(-88, 88))
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
	var town_flower_spots: Array = []
	for i in range(22 if LEGACY_TOWN_ONLY else 44): # MAP DOUBLING: count doubled with the area (BISECT: pre-doubling count in legacy mode)
		await _build_tick() # v1.0.11 chunking (before the road check, so `continue` can't skip it)
		var fp2 := Vector3(srng.randf_range(-114, x_hi), 0.16, srng.randf_range(-86, 86))
		# CLUTTER: this scatter had NO road check — flowers landed
		# on asphalt. Same exclusion as the grass tufts/patches.
		var fon := false
		for rz6 in road_zs:
			if abs(fp2.z - rz6) < 5.0: fon = true
		for rx6 in road_xs:
			if abs(fp2.x - rx6) < 5.0: fon = true
		if fon:
			continue
		town_flower_spots.append([Vector3(fp2.x, 0.02, fp2.z), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.75, 0.6, 0.95)][i % 3], 1.05]) # v1.0.26 completion: stem+daisy via _place_flowers (was a bare sphere)
	_place_flowers(world, town_flower_spots)
	await _build_tick()
	# Lamp posts
	for lp in [Vector3(-26, 0, -6), Vector3(18, 0, -16), Vector3(-26, 0, 20), Vector3(30, 0, 10), Vector3(-2, 0, -16), Vector3(2, 0, 20), Vector3(-64, 0, -49), Vector3(66, 0, 60), Vector3(-76, 0, 20), Vector3(30, 0, -60), Vector3(84, 0, -6), Vector3(-96, 0, 44)]:
		_cyl(world, lp + Vector3(0, 2.2, 0), 0.07, 0.09, 4.4, Color(0.25, 0.27, 0.3), true)
		_sphere(world, lp + Vector3(0, 4.5, 0), Vector3(0.5, 0.5, 0.5), Color(1.0, 0.9, 0.6))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ SECOND PARK (north-west district): lawn, pond, gazebo
	var lawn2 := _box(world, Vector3(-84, 0.02, 74), Vector3(34, 0.06, 18), Color.WHITE)
	lawn2.material_override = _mat_tex(TEX_GRASS_PARK, Color(0.78, 0.9, 0.7), Vector3(9, 5, 1))
	var pond2 := _cyl(world, Vector3(-90, 0.08, 76), 3.0, 3.0, 0.16, Color.WHITE)
	pond2.material_override = _mat_tex(TEX_WATER, Color.WHITE, Vector3(3, 3, 1), 0.35)
	content_points.append(Vector3(-90, 0, 76)) # v0.9 audit: park 2
	content_points.append(Vector3(-78, 0, 66)) # gazebo
	for bpos2 in [Vector3(-78, 0, 71), Vector3(-76, 0, 79)]: # CLUTTER: the -72 bench stood in the Pine corridor
		_box(world, bpos2 + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
		_box(world, bpos2 + Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		_box(world, bpos2 + Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	# Gazebo — CLUTTER: at x=-76 its platform edge (r 3.2) and
	# roof (r 3.5) overhung the Pine Street asphalt; at x=-78
	# both clear the road and its sidewalk.
	var gz_pos := Vector3(-78, 0, 66)
	_cyl(world, gz_pos + Vector3(0, 0.12, 0), 3.0, 3.2, 0.24, Color(0.8, 0.75, 0.68), true)
	for ga in [Vector2(1.7, 1.7), Vector2(-1.7, 1.7), Vector2(1.7, -1.7), Vector2(-1.7, -1.7)]:
		_cyl(world, gz_pos + Vector3(ga.x, 1.5, ga.y), 0.09, 0.09, 2.8, Color(0.92, 0.9, 0.86), true)
	var gz_roof := _cyl(world, gz_pos + Vector3(0, 3.6, 0), 0.3, 3.5, 1.4, Color.WHITE)
	gz_roof.material_override = _mat_tex(TEX_ROOF, Color(0.55, 0.35, 0.3), Vector3(3, 1, 1))
	_sphere(world, gz_pos + Vector3(0, 4.5, 0), Vector3(0.28, 0.28, 0.28), Color(0.9, 0.75, 0.3))
	var park2_flower_spots: Array = []
	for i in range(14):
		var fp3 := Vector3(srng.randf_range(-100, -75), 0.16, srng.randf_range(66, 82)) # CLUTTER: x>-75 put flowers on the Pine asphalt (road edge -73.6)
		park2_flower_spots.append([Vector3(fp3.x, 0.03, fp3.z), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.9, 0.9, 0.95)][i % 3], 1.05]) # v1.0.26 completion: stem+daisy via _place_flowers (was a bare sphere)
	_place_flowers(world, park2_flower_spots)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
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
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ BORDERS — the world CONTINUES past every edge ========
	# SHORELINE ACCESS (v1.0.14, Michael: "the road just ends
	# randomly" — he could SEE the water but the town border held
	# him far short of it): the old invisible border body (4 walls
	# at z=+/-92 and x=-119.8 / town_east) is GONE. The player can
	# now walk out of town across the island apron and beach, and
	# the ONLY stop is the IslandShore collision at the waterline
	# (see _build_island). The visible dressing below stays as the
	# town's edge fiction, opened with gaps where the streets meet
	# it (see border_gaps): the north/west fence rails and the
	# south hedge are built in segments with a gap at every street
	# end. NPCs, the pound van and traffic keep their own town
	# bounds and never follow him out.
	var border_gaps := func(v: float, centres: Array) -> bool:
		for gc in centres:
			if absf(v - float(gc)) < 4.5:
				return true
		return false
	var border_cuts := func(lo: float, hi: float, centres: Array) -> Array:
		# Solid intervals of [lo, hi] once the street gaps are cut.
		var cs: Array = centres.duplicate()
		cs.sort()
		var out: Array = []
		var cur2: float = lo
		for gc in cs:
			var glo: float = float(gc) - 4.5
			var ghi: float = float(gc) + 4.5
			if glo > cur2:
				out.append([cur2, glo])
			cur2 = maxf(cur2, ghi)
		if cur2 < hi:
			out.append([cur2, hi])
		return out
	# NORTH: a RIVER — water, far bank, houses across the water, fence here
	# v1.0.26: the channel (and the far bank) now spans the whole
	# island width at this latitude (town_w + 76), running out
	# through the beach to the sea at both ends like a river
	# mouth — when it was only town-wide, Zander could walk
	# around its ends and across it (the water box has no
	# collision; the apron runs beneath it), and the far-bank
	# houses read as reachable town. Michael, playing v1.0.25:
	# "there's just a random river... and then houses on the
	# other side... it needs to be fixed."
	var river := _box(world, Vector3(town_cx, 0.0, -99.5), Vector3(town_w + 76.0, 0.25, 13), Color.WHITE)
	river.material_override = _mat_tex(TEX_WATER, Color(0.85, 0.95, 1.05), Vector3(50.0 if LEGACY_TOWN_ONLY else 90.0, 2, 1), 0.3)
	var far_bank := _box(world, Vector3(town_cx, -0.05, -115), Vector3(town_w + 76.0, 0.6, 18), Color.WHITE)
	far_bank.material_override = _mat_tex(TEX_GRASS, Color(0.66, 0.78, 0.6), Vector3(50.0 if LEGACY_TOWN_ONLY else 90.0, 3, 1))
	# v1.0.26: the river's SHORE WALL — the same stop the island
	# sea shore gives him (IslandShore in _build_island): an
	# invisible bank along the near shore, so he stands at the
	# water's edge but never ON the water, anywhere along the
	# channel. It spans the widened channel end to end, so there
	# is no flank to walk around inside the island; beyond its
	# ends is beach and the sea's own shore wall. Traffic is
	# kinematic and the townsfolk keep their own town bounds, so
	# nothing else meets this wall.
	var river_shore := StaticBody3D.new()
	river_shore.name = "RiverShore"
	var river_cs := CollisionShape3D.new()
	var river_shape := BoxShape3D.new()
	river_shape.size = Vector3(town_w + 76.0, 1.8, 0.8)
	river_cs.shape = river_shape
	river_cs.position = Vector3(town_cx, 0.7, -92.55)
	river_shore.add_child(river_cs)
	world.add_child(river_shore)
	for hx in ([-100, -60, -20, 20, 60, 100] if LEGACY_TOWN_ONLY else [-100, -60, -20, 20, 60, 100, 140, 180, 220, 260, 300, 340]):
		_box(world, Vector3(hx, 2.5, -124), Vector3(10, 5, 8), Color(0.82, 0.78, 0.72))
		var sr1 := _box(world, Vector3(hx - 2.4, 5.6, -124), Vector3(6.4, 0.25, 9), Color(0.5, 0.42, 0.4))
		sr1.rotation_degrees = Vector3(0, 0, 34)
		var sr2 := _box(world, Vector3(hx + 2.4, 5.6, -124), Vector3(6.4, 0.25, 9), Color(0.5, 0.42, 0.4))
		sr2.rotation_degrees = Vector3(0, 0, -34)
		# v1.0.26: close this row's gable ends. These backdrop
		# houses are plain boxes + two roof slabs on their own
		# build path, so the triangle under the roof stood open
		# (Michael's v1.0.25 screenshot: the white shore house
		# hollow under its roof) — the v1.0.25 gable fix covered
		# the town houses (_build_house) and the escape diorama,
		# not this row. A wall-coloured prism fills the triangle:
		# its slope (2.43 over a 3.6 half-span) matches the slabs'
		# 34 degrees, its base tucks into the wall top and its
		# edges under the slabs. (Named ShoreGableInfill, not
		# GableInfill: the suite's gable audit counts nodes named
		# GableInfill against the town houses one-for-one.)
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.left_to_right = 0.5
		prism.size = Vector3(7.2, 2.43, 7.96)
		gable.mesh = prism
		gable.position = Vector3(hx, 6.16, -124)
		gable.material_override = _mat(Color(0.82, 0.78, 0.72))
		gable.name = "ShoreGableInfill"
		world.add_child(gable)
		_build_pine(world, Vector3(hx + 9, 0, -120), 1.1)
		await _build_tick() # v1.0.11 chunking
	var fxi: int = 0
	for fx2 in range(-124, (121 if LEGACY_TOWN_ONLY else 377), 4):
		# SHORELINE ACCESS: no post inside a street gap (see above).
		if not border_gaps.call(float(fx2), road_xs):
			_box(world, Vector3(fx2, 0.55, -92), Vector3(0.16, 1.1, 0.16), Color(0.55, 0.45, 0.35))
			if fxi % 6 == 0:
				content_points.append(Vector3(fx2, 0, -92)) # v0.9 audit: the river fence is content
		await _build_tick()
		fxi += 1
	# SHORELINE ACCESS: the rails run in segments, cut at the streets.
	for cut in border_cuts.call(town_cx - town_w * 0.5, town_cx + town_w * 0.5, road_xs):
		var ca: float = float(cut[0])
		var cb: float = float(cut[1])
		_box(world, Vector3((ca + cb) * 0.5, 0.95, -92), Vector3(cb - ca, 0.12, 0.1), Color(0.55, 0.45, 0.35))
		_box(world, Vector3((ca + cb) * 0.5, 0.5, -92), Vector3(cb - ca, 0.1, 0.1), Color(0.55, 0.45, 0.35))
	# SOUTH: a tall HEDGE + a pine FOREST behind it
	# SHORELINE ACCESS: the hedge is the one border dressing with
	# real collision, so it is built in segments with a gap at
	# every cross street — the streets now run out through it to
	# the shore (the pine forest behind stays as-is; its trunks
	# are spaced wide enough to weave through).
	for cut in border_cuts.call(town_cx - town_w * 0.5, town_cx + town_w * 0.5, road_xs):
		var ha: float = float(cut[0])
		var hb: float = float(cut[1])
		var hedge := _box(world, Vector3((ha + hb) * 0.5, 0.85, 92), Vector3(hb - ha, 1.7, 1.4), Color.WHITE, true)
		hedge.material_override = _mat_tex(TEX_FOLIAGE, Color(0.75, 0.9, 0.72), Vector3(40.0 if LEGACY_TOWN_ONLY else 80.0, 1, 1))
	for hx2 in range(-120, (121 if LEGACY_TOWN_ONLY else 373), 8):
		if border_gaps.call(float(hx2), road_xs):
			await _build_tick() # gap in the hedge: no blob floating over the opening
			continue
		_sphere(world, Vector3(hx2, 1.85, 92), Vector3(1.6, 0.8, 1.2), Color(0.42, 0.62, 0.36))
		content_points.append(Vector3(hx2, 0, 92)) # v0.9 audit: the south hedge is content
		await _build_tick() # v1.0.11 chunking: 62 hedge blobs had no yield
	for px in range(-120, (121 if LEGACY_TOWN_ONLY else 373), 11):
		_build_pine(world, Vector3(px + srng.randf_range(-2, 2), 0, 99 + srng.randf_range(-1.5, 1.5)), srng.randf_range(0.95, 1.3))
		await _build_tick()
	for px2 in range(-116, (117 if LEGACY_TOWN_ONLY else 373), 14):
		_build_pine(world, Vector3(px2 + srng.randf_range(-3, 3), 0, 108 + srng.randf_range(-2, 2)), srng.randf_range(1.15, 1.55))
		await _build_tick()
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
		await _build_tick() # v1.0.11 chunking
	var wzi: int = 0
	for fz in range(-93, 94, 6):
		# SHORELINE ACCESS: no post inside an avenue gap.
		if not border_gaps.call(float(fz), road_zs):
			_box(world, Vector3(-119.8, 0.55, fz), Vector3(0.16, 1.1, 0.16), Color(0.5, 0.5, 0.55))
			if wzi % 3 == 0:
				content_points.append(Vector3(-119.8, 0, fz)) # v0.9 audit: the west fence is content
		wzi += 1
	# SHORELINE ACCESS: the rails run in segments, cut at the avenues.
	for cut in border_cuts.call(-96.0, 96.0, road_zs):
		var wa: float = float(cut[0])
		var wb: float = float(cut[1])
		_box(world, Vector3(-119.8, 0.95, (wa + wb) * 0.5), Vector3(0.1, 0.12, wb - wa), Color(0.5, 0.5, 0.55))
		_box(world, Vector3(-119.8, 0.5, (wa + wb) * 0.5), Vector3(0.1, 0.1, wb - wa), Color(0.5, 0.5, 0.55))
	# BISECT (v1.0.12): the construction dressing sits at the DOUBLED
	# town's east edge (x ~372-392). In legacy mode the east wall is
	# back at x=119.8 and this site is not generated at all.
	if not LEGACY_TOWN_ONLY:
		# EAST: CONSTRUCTION — striped barriers, cones, a half-built house + crane
		# MAP DOUBLING: the whole site moved +252 east with the border.
		for bz3 in range(-60, 61, 15):
			_box(world, Vector3(371.8, 0.5, bz3), Vector3(0.5, 1.0, 3.4), Color(0.95, 0.5, 0.15), true)
			_box(world, Vector3(371.8, 0.72, bz3), Vector3(0.54, 0.22, 3.4), Color(0.96, 0.95, 0.92))
			content_points.append(Vector3(371.8, 0, bz3)) # v0.9 audit: construction barriers are content
		for cz3 in range(-52, 53, 13):
			var cone := _cyl(world, Vector3(370.4, 0.4, cz3), 0.06, 0.3, 0.8, Color(0.95, 0.45, 0.12))
			cone.material_override = _mat(Color(0.95, 0.45, 0.12), 0.6)
		for cpx in [378.0, 388.0]:
			for cpz in [2.0, 18.0]:
				_box(world, Vector3(cpx, 3.5, cpz), Vector3(0.45, 7, 0.45), Color(0.75, 0.6, 0.4), true)
		_box(world, Vector3(383, 3.6, 10), Vector3(11, 0.3, 18), Color(0.8, 0.68, 0.5))
		_box(world, Vector3(383, 7.1, 10), Vector3(11, 0.3, 18), Color(0.8, 0.68, 0.5))
		_cyl(world, Vector3(392, 8.5, -16), 0.35, 0.45, 17, Color(0.9, 0.6, 0.15))
		var jib := _box(world, Vector3(384, 16.8, -16), Vector3(17, 0.5, 0.5), Color(0.9, 0.6, 0.15))
		jib.rotation_degrees = Vector3(0, 0, 2)
		_cyl(world, Vector3(377, 14.2, -16), 0.03, 0.03, 5.2, Color(0.3, 0.3, 0.32))
		_box(world, Vector3(377, 11.4, -16), Vector3(0.7, 0.5, 0.7), Color(0.55, 0.4, 0.25))
		_label3d(world, "🚧 NEW HOMES — COMING SOON!", Vector3(376, 9.5, 10), 64, Color(1.0, 0.8, 0.4))
	# v0.9 FILL FEATURES (item 1): the named places that end the
	# "big chunks of nothing" — playground, community garden, bus
	# stop, little library, extra benches and lamps.
	await _set_boot_stage("Town places", 60) # v1.0.12 readout: the POI fills hid under "Placing houses" with no stage of their own
	await _build_fill_features(world, srng)
	# v1.0 TOWN FILL (micro-step 1): substantial built content in the
	# blocks the v0.9 audit still left thin — promenade, shops, hall,
	# apartment block, market stalls, Willow Green, garden clusters,
	# sheds, fences and a full lamp grid — so every viewpoint reads
	# as a neighbourhood. No houses array entries (count stays 41),
	# no hide/ender points, gameplay untouched.
	await _set_boot_stage("Town fill", 61) # v1.0.12 readout
	await _build_town_fill(world, srng)
	# MAP DOUBLING: the east district's own places and per-block
	# dressing (market row, apartment court, pocket park, clusters,
	# lamp grid, promenade extension).
	# BISECT (v1.0.12): not generated at all in legacy mode.
	if not LEGACY_TOWN_ONLY:
		await _set_boot_stage("East district", 62) # v1.0.12 readout
		await _build_east_district(world, srng)
	# v0.7 TRAFFIC: moving cars live under their own group (spawned
	# and despawned at runtime — see _process_traffic).
	traffic_group = Node3D.new()
	traffic_group.name = "Traffic"
	world.add_child(traffic_group)
	# PERF (post-v1.0.1): one build-time pass over the finished town
	# giving small clutter a visibility range (see below).
	await _build_frame() # v1.0.9: a clean frame before the whole-world clutter walk
	await _set_boot_stage("Tidying clutter", 63) # v1.0.12 readout: the whole-world clutter walk hid under "Placing houses" too
	await _apply_clutter_ranges(world)

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
	# v1.0.11 chunking: this was a recursive walk over the WHOLE
	# built world (~34k nodes, a global_transform multiply per mesh)
	# with no yield anywhere — a single ~229 ms unbroken stretch at
	# the end of the "Placing houses" stage. Same nodes, same rules,
	# same result: collect the walk iteratively (Car/Traffic subtrees
	# skipped whole, exactly as before), then process the flat list
	# under the normal chunk budget.
	var stack: Array = [n]
	var nodes: Array = []
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur.name == "Car" or cur.name == "Traffic":
			continue
		nodes.append(cur)
		for ch in cur.get_children():
			stack.append(ch)
		if nodes.size() % 1024 == 0:
			await _build_tick()
	var clutter_i: int = 0
	for cur2 in nodes:
		if cur2 is MeshInstance3D:
			var mi := cur2 as MeshInstance3D
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			var s: Vector3 = aabb.size
			if s.y <= 0.30 and s.x <= 3.0 and s.z <= 3.0:
				mi.visibility_range_end = 75.0
				if s.y <= 0.12 and aabb.get_center().y < 0.3:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif s.x <= 0.65 and s.y <= 1.05 and s.z <= 0.65:
				mi.visibility_range_end = 65.0
		clutter_i += 1
		await _build_tick()

func _build_fill_features(world: Node3D, srng: RandomNumberGenerator) -> void:
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ PLAYGROUND PARK (west side of the Oak block) ====
	# v1.0.23 (Michael's direction): the old code-built playground
	# equipment (swing frame, slide steps + chute, seesaw, sandbox,
	# merry-go-round) is REMOVED — in his v1.0.21 play it stood in
	# 40 Oak Avenue's side yard, a metre or two from its walls, and
	# read as the house's own porch/stairs broken apart and
	# floating. In its place, a proper park on the block's OPEN
	# west side (verified by an occupancy probe: 40 Oak's walls
	# span x 93.9..102.1, z 29.4..36.6 and the neighbouring lots
	# are empty; the park's ground x 76.5..93.5, z 22.5..36.5
	# touches nothing): a defined lawn, a path in from the Oak Ave
	# sidewalk, benches and trees, and the Meshy playground
	# structure (assets/models/playground.glb — slimmed from
	# 27 MB / 717k tris to ~1.5 MB / 30k tris; static prop)
	# grounded at kid scale: 2.6x its modelled size = ~4.9 x 3.7 m
	# footprint, ~2.7 m tall against the Excited Kid's 1.15 m. One
	# solid collision box over the footprint so the cat (and the
	# kids) can't walk through it; the kids play AROUND it at
	# PARK_SPOTS (see _spawn_npcs / person.gd park dwell).
	var pg := Vector3(85, 0, 29.5)
	var mat1 := _box(world, pg + Vector3(0, 0.03, 0), Vector3(17, 0.06, 14), Color.WHITE)
	mat1.material_override = _mat_tex(TEX_GRASS_PARK, Color(0.85, 0.92, 0.72), Vector3(7, 5, 1))
	# Path: from the Oak Ave sidewalk to the structure.
	var ppath := _box(world, Vector3(86, 0.045, 24.0), Vector3(2.6, 0.03, 9.5), Color(0.88, 0.84, 0.74))
	ppath.material_override = _mat(Color(0.88, 0.84, 0.74), 1.0)
	# The playground structure. The GLB's origin sits mid-height
	# (its AABB spans y -0.528..0.52), so the instance is lifted
	# by 0.528 * scale to rest its base exactly on the ground.
	var pg_root := Node3D.new()
	pg_root.position = Vector3(86, 0, 30)
	world.add_child(pg_root)
	var pg_model := (preload("res://assets/models/playground.glb") as PackedScene).instantiate() as Node3D
	pg_model.scale = Vector3.ONE * 2.6
	pg_model.position.y = 0.528 * 2.6
	pg_root.add_child(pg_model)
	playground_model = pg_model
	var pg_body := StaticBody3D.new()
	var pg_cs := CollisionShape3D.new()
	var pg_shape := BoxShape3D.new()
	pg_shape.size = Vector3(5.2, 2.4, 3.9)
	pg_cs.shape = pg_shape
	pg_cs.position = Vector3(0, 1.2, 0)
	pg_body.add_child(pg_cs)
	pg_root.add_child(pg_body)
	content_points.append(Vector3(86, 0, 30))
	# Benches watching the structure + trees at the park corners.
	_fill_bench(world, Vector3(80.5, 0, 24.8), 0.0)
	_fill_bench(world, Vector3(91.5, 0, 24.8), 0.0)
	_build_tree(world, Vector3(80.0, 0, 35.5))
	_build_tree(world, Vector3(92.0, 0, 36.5))
	_build_tree(world, Vector3(79.5, 0, 23.0))
	_label3d(world, "PLAYGROUND", Vector3(86, 3.3, 21.6), 52, Color(1.0, 0.95, 0.75))
	_cyl(world, Vector3(86, 1.55, 21.6), 0.06, 0.08, 3.1, Color(0.5, 0.42, 0.32), true)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
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
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
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
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
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
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ EXTRA BENCHES in the quiet bands ===================
	for bpos3 in [Vector3(60, 0, -20), Vector3(-90, 0, 10), Vector3(110, 0, -30), Vector3(-10, 0, 80), Vector3(58, 0, 82)]:
		_box(world, bpos3 + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
		_box(world, bpos3 + Vector3(0, 0.85, -0.24), Vector3(2.2, 0.5, 0.09), Color(0.55, 0.4, 0.25))
		_box(world, bpos3 + Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		_box(world, bpos3 + Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		content_points.append(bpos3)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
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
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ WEST ORCHARD (Pine St to the west fence) ==========
	for ot in [Vector3(-84, 0, -2), Vector3(-80, 0, 10), Vector3(-84, 0, 26), Vector3(-78, 0, 37)]:
		_build_tree(world, ot)
	_box(world, Vector3(-86, 0.45, 6), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
	_box(world, Vector3(-86, 0.22, 6), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	_box(world, Vector3(-85.2, 0.22, 6), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
	content_points.append(Vector3(-86, 0, 6))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ EAST PICNIC GROVE (Riverside to the barriers) =====
	for pt in [Vector3(86, 0, -4), Vector3(96, 0, 7), Vector3(108, 0, -6), Vector3(90, 0, 8)]:
		_build_tree(world, pt)
	_box(world, Vector3(97, 0.75, -1), Vector3(2.4, 0.1, 1.1), Color(0.65, 0.5, 0.35), true) # picnic table top
	for pb in [-0.85, 0.85]:
		_box(world, Vector3(97, 0.45, -1 + pb), Vector3(2.4, 0.08, 0.35), Color(0.6, 0.46, 0.32), true)
		_box(world, Vector3(96.2, 0.35, -1 + pb * 0.4), Vector3(0.14, 0.7, 0.14), Color(0.45, 0.35, 0.25))
		_box(world, Vector3(97.8, 0.35, -1 + pb * 0.4), Vector3(0.14, 0.7, 0.14), Color(0.45, 0.35, 0.25))
	content_points.append(Vector3(97, 0, -1))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ LONE TREES in the last gaps ========================
	_build_tree(world, Vector3(-62, 0, 79)) # south-west park band
	_build_tree(world, Vector3(16, 0, 24)) # Oak/Willow mid-block, by the bus stop
	_build_tree(world, Vector3(20, 0, -4)) # Maple/Oak mid-block

# ================================================================ v1.0 town fill
func _fill_lamp(world: Node3D, pos: Vector3) -> void:
	_cyl(world, pos + Vector3(0, 2.2, 0), 0.07, 0.09, 4.4, Color(0.25, 0.27, 0.3), true)
	# DUSK: the lamps are ON. The head gets a warm emissive
	# material (energy 2.4 — bright enough to read as a lit bulb
	# through the ACES tonemap) and a faint unshaded halo shell
	# so it glows from down the street. NO dynamic light per
	# lamp (the perf budget forbids it): the emissive + halo do
	# the whole job for the price of one extra culled sphere.
	# The halo casts no shadow, writes no depth (no sorting
	# artefacts against windows/fences) and range-culls at 65 m
	# like the rest of the small clutter.
	var head := _sphere(world, pos + Vector3(0, 4.5, 0), Vector3(0.5, 0.5, 0.5), Color(1.0, 0.82, 0.48))
	head.material_override = _mat(Color(1.0, 0.80, 0.44), 0.35, 2.4)
	if boot_safe_mode:
		content_points.append(pos)
		return # v1.0.10 safe mode: no halo shells (one less transparent pass per lamp)
	var halo := _sphere(world, pos + Vector3(0, 4.5, 0), Vector3(0.95, 0.95, 0.95), Color(1.0, 0.75, 0.42))
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.74, 0.40, 0.10)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.visibility_range_end = 65.0
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
	var bed_spots: Array = []
	for i in range(9):
		var fx: float = fr.randf_range(-w * 0.42, w * 0.42)
		var fz: float = fr.randf_range(-0.55, 0.55)
		bed_spots.append([pos + Vector3(fx, 0.10, fz), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.9, 0.9, 0.95), Color(0.85, 0.45, 0.75)][i % 4], 0.95]) # v1.0.26 completion: stem+daisy via _place_flowers (was a ball on a stick)
	_place_flowers(world, bed_spots)
	content_points.append(pos)

func _fill_mailbox(world: Node3D, pos: Vector3) -> void:
	# CLUTTER (Michael, 2026-11-17): ONE mailbox. The old version
	# built a row of THREE boxes on posts — the "houses with
	# three mailboxes" he spotted. A mailbox is a single box on
	# a single post, built in a group named "Mailbox" so the
	# clutter audit can count mailboxes (tests/ClutterProbe.tscn).
	# NOTE: the town fill no longer calls this — every house now
	# carries exactly its own one mailbox (see _build_house).
	var g := Node3D.new()
	g.name = "Mailbox"
	g.position = pos
	world.add_child(g)
	_cyl(g, Vector3(0, 0.45, 0), 0.045, 0.045, 0.9, Color(0.5, 0.42, 0.32), true)
	_box(g, Vector3(0, 1.0, 0), Vector3(0.42, 0.3, 0.3), Color(0.3, 0.45, 0.75), true)
	content_points.append(pos)

func _fill_shed(world: Node3D, pos: Vector3, col: Color) -> void:
	_box(world, pos + Vector3(0, 1.05, 0), Vector3(3.4, 2.1, 2.6), col, true)
	var roof := _box(world, pos + Vector3(0, 2.25, 0), Vector3(3.8, 0.14, 3.0), Color(0.4, 0.35, 0.3))
	roof.rotation_degrees = Vector3(5, 0, 0)
	_box(world, pos + Vector3(0, 1.0, 1.32), Vector3(0.9, 1.85, 0.07), Color(0.35, 0.27, 0.2))
	_box(world, pos + Vector3(-1.1, 1.45, 1.32), Vector3(0.55, 0.55, 0.07), Color(0.8, 0.88, 0.92), false, 0.25)
	content_points.append(pos)

func _fill_fence_x(world: Node3D, x0: float, x1: float, z: float) -> void:
	# CLUTTER (Michael, 2026-11-17): a fence run must NEVER cross
	# a roadway. The old runs were drawn straight through the
	# vertical road corridors — the Willow back fences at z=73
	# crossed Pine, Cedar, Birch AND Riverside, and the Elm
	# front-gap fences crossed Cedar and Birch. Runs are now
	# CLIPPED against every vertical asphalt corridor (+0.5
	# margin) and only the surviving segments are built, so a
	# fence always stops at the road's edge like a real one.
	var segs: Array = [[x0, x1]]
	for rx in [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0]:
		var lo: float = rx - 3.6 - 0.5
		var hi: float = rx + 3.6 + 0.5
		var next: Array = []
		for sg in segs:
			var a: float = float(sg[0])
			var b: float = float(sg[1])
			if b <= lo or a >= hi:
				next.append([a, b])
			else:
				if a < lo:
					next.append([a, lo])
				if b > hi:
					next.append([hi, b])
		segs = next
	for sg in segs:
		var a: float = float(sg[0])
		var b: float = float(sg[1])
		if b - a < 1.5:
			continue # a stub shorter than one panel isn't a fence
		var n: int = int((b - a) / 2.0)
		for i in range(n + 1):
			_box(world, Vector3(a + float(i) * 2.0, 0.5, z), Vector3(0.16, 1.0, 0.16), Color(0.6, 0.48, 0.34), true)
		if b - (a + float(n) * 2.0) > 0.4:
			_box(world, Vector3(b, 0.5, z), Vector3(0.16, 1.0, 0.16), Color(0.6, 0.48, 0.34), true) # end post
		_box(world, Vector3((a + b) * 0.5, 0.82, z), Vector3(b - a, 0.1, 0.1), Color(0.6, 0.48, 0.34), true)
		_box(world, Vector3((a + b) * 0.5, 0.42, z), Vector3(b - a, 0.09, 0.09), Color(0.6, 0.48, 0.34), true)
		content_points.append(Vector3((a + b) * 0.5, 0, z))

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
		parked_car_spots.append(Vector3(cx, 0, pos.z)) # v1.0.27: static car — the tree audit keeps canopies off it
		await _build_tick() # v1.0.11 chunking: a whole car build between every breath
	content_points.append(pos)

func _build_town_fill(world: Node3D, srng: RandomNumberGenerator) -> void:
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ RIVERSIDE PROMENADE (north band, behind the bench line)
	var path := _box(world, Vector3(0.0 if LEGACY_TOWN_ONLY else 126.0, 0.04, -85), Vector3(244.0 if LEGACY_TOWN_ONLY else 488.0, 0.08, 3.4), Color.WHITE) # MAP DOUBLING: path extended east with the town (BISECT: legacy span in legacy mode)
	path.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(120, 1, 1))
	# CLUTTER: the Cedar lamp stood at x=-20 — the Cedar Street
	# centreline, in the roadway where Cedar meets the promenade.
	# It now stands on the east verge at x=-14.5. The x=20 lamp
	# sits at 19.4: its pole and head always cleared the Cedar
	# asphalt (edge x=20.4), but the 0.95m glow-halo shell
	# overhung the edge by ~7cm and tripped the clutter catch-all
	# — 19.4 puts the whole lamp honestly clear of the roadway.
	for lx in [-100.0, -60.0, -14.5, 19.4, 60.0, 100.0]:
		_fill_lamp(world, Vector3(lx, 0, -85))
	for fb in [Vector3(-80, 0, -88.5), Vector3(36, 0, -88.5), Vector3(80, 0, -88.5)]:
		_fill_flowerbed(world, fb, 5.0)
	_fill_building(world, Vector3(-30, 0, -86), Vector3(6.5, 3.4, 4.6), Color(0.96, 0.88, 0.74), Color(0.55, 0.38, 0.3), "RIVERSIDE CAFÉ", 0.0)
	_fill_bench(world, Vector3(-52, 0, -83), 180.0)
	_fill_bench(world, Vector3(44, 0, -83), 180.0)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ RIVERSIDE COURT apartments (NE corner block)
	_fill_building(world, Vector3(100, 0, -76), Vector3(13, 10.5, 10), Color(0.9, 0.82, 0.76), Color(0.45, 0.45, 0.52), "RIVERSIDE COURT", 0.0, true)
	await _fill_parking(world, Vector3(84, 0, -75), 10.0, 7.0, [Color(0.35, 0.5, 0.8), Color(0.85, 0.6, 0.25)], "hatchback")
	_fill_lamp(world, Vector3(93, 0, -68))
	_build_tree(world, Vector3(110, 0, -84))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ ELM back gardens + front-gap clusters (north mid)
	_fill_shed(world, Vector3(-112, 0, -77), Color(0.45, 0.6, 0.45))
	_fill_shed(world, Vector3(-80, 0, -77), Color(0.6, 0.48, 0.36))
	_fill_shed(world, Vector3(-58, 0, -75), Color(0.5, 0.58, 0.68))
	# CLUTTER: the shed at x=20 jutted into the Birch Lane
	# corridor (its east wall crossed the asphalt edge); it now
	# sits at x=16, clear of both Cedar and Birch. The bench at
	# (26,-73) also stood in the Birch corridor, and the
	# flowerbed at (-21,-73) crossed Cedar — both shifted west/
	# east onto grass, and the west bench moved so the bed and
	# bench don't overlap.
	_fill_shed(world, Vector3(16, 0, -76), Color(0.62, 0.5, 0.4))
	_fill_bench(world, Vector3(-33, 0, -74), 0.0)
	_fill_flowerbed(world, Vector3(-26.5, 0, -73), 3.6)
	_build_tree(world, Vector3(-31, 0, -77))
	_fill_bench(world, Vector3(31, 0, -73), 0.0)
	# CLUTTER: these "front gap" clusters were centred beside the
	# cross-streets, so their benches and flowerbeds spilled into
	# the Cedar/Birch roadways (and each carried a THREE-mailbox
	# cluster). Centres shifted onto grass; the mailbox clusters
	# are GONE — every house has exactly its own one mailbox.
	for fc in [Vector3(-30, 0, -60), Vector3(14, 0, -60)]:
		_fill_flowerbed(world, fc, 4.0)
		_fill_bench(world, fc + Vector3(3.6, 0, 0.6), 0.0)
		_fill_fence_x(world, fc.x - 5.0, fc.x + 5.0, fc.z - 2.6)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ MAPLE west shops + front gardens
	_fill_building(world, Vector3(-95, 0, -20), Vector3(6.5, 3.6, 5), Color(0.85, 0.9, 0.96), Color(0.4, 0.5, 0.65), "MAPLE MART", 0.0)
	# CLUTTER: a stray three-mailbox cluster stood here — removed
	# (mailboxes live at houses now, exactly one each).
	_fill_lamp(world, Vector3(-89, 0, -17))
	for fc2 in [Vector3(-60, 0, -20), Vector3(38, 0, -20)]:
		_fill_flowerbed(world, fc2, 4.0)
		_fill_bench(world, fc2 + Vector3(3.6, 0, 0.6), 0.0)
		_fill_fence_x(world, fc2.x - 5.0, fc2.x + 5.0, fc2.z - 2.6)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ OAK back gardens (Maple/Oak mid-block, west + centre)
	_fill_shed(world, Vector3(-27, 0, -4), Color(0.55, 0.62, 0.5))
	_fill_shed(world, Vector3(-60, 0, -4), Color(0.62, 0.52, 0.42))
	_fill_fence_x(world, -66.0, -54.0, -6.5)
	_fill_flowerbed(world, Vector3(-27, 0, -1), 3.4) # CLUTTER: was at -24, its east edge crossed the Cedar corridor
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ WEST END shop + park-west entrance (Oak/Willow band, west)
	_fill_building(world, Vector3(-104, 0, 23), Vector3(7, 3.8, 5.5), Color(0.96, 0.9, 0.8), Color(0.6, 0.35, 0.3), "WEST END FOODS", 180.0)
	_fill_flowerbed(world, Vector3(-61, 0, 21), 3.4)
	_fill_flowerbed(world, Vector3(-61, 0, 27.5), 3.4)
	_fill_bench(world, Vector3(-58, 0, 24), 90.0)
	_fill_lamp(world, Vector3(-63, 0, 24))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ PLAYGROUND PARK south edge: bench + lamp ======
	# v1.0.23: the old code-built climbing frame that stood here is
	# removed with the rest of the old playground equipment (see
	# the park build in _build_fill_features); the bench and lamp
	# stay — they front the new park.
	_fill_bench(world, Vector3(101, 0, 21.9), 0.0)
	_fill_lamp(world, Vector3(110, 0, 28))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ RIVERSIDE corner shops + lot (Birch/Riverside, Maple/Oak)
	# v1.0.29: the code-built bakery is replaced by the Meshy bakery
	# model (its one appearance in town), front facing the parking
	# lot and Maple Avenue; footprint registered like the civics.
	content_points.append(Vector3(62, 0, -4)) # v0.9 empty-area audit
	var bg := Node3D.new()
	bg.name = "Civic_bakery"
	bg.position = Vector3(62, 0, -4)
	world.add_child(bg)
	var bdims: Dictionary = _place_building_model(bg, "bakery", 1.0)
	building_footprints.append({"pos": Vector3(62, 0, -4), "hx": float(bdims["w"]) * 0.5, "hz": float(bdims["d"]) * 0.5})
	await _fill_parking(world, Vector3(62, 0, 6.5), 9.0, 4.4, [Color(0.8, 0.3, 0.28)], "sedan")
	_fill_lamp(world, Vector3(66, 0, 2.5))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ MARKET ROW stalls (east of Riverside, Maple band)
	_fill_stall(world, Vector3(88, 0, -21), Color(0.85, 0.35, 0.3))
	_fill_stall(world, Vector3(97, 0, -21), Color(0.3, 0.6, 0.62))
	_fill_stall(world, Vector3(106, 0, -21), Color(0.9, 0.7, 0.25))
	_fill_lamp(world, Vector3(97, 0, -17.5))
	_fill_bench(world, Vector3(92, 0, -17.8), 180.0)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ WILLOW south band: hall, sheds, back fences, front clusters
	# CLUTTER: Willow Hall stood at x=30 with its west wall AND
	# its hanging sign inside the Birch Lane corridor (footprint
	# x 24.5..35.5 vs asphalt from 20.4) — a building in the
	# street. It now sits at x=36, fully inside its block, and
	# its lot shifted 1 west so the lot's east edge also clears
	# the asphalt.
	_fill_building(world, Vector3(36, 0, 79), Vector3(11, 5.5, 7), Color(0.88, 0.84, 0.78), Color(0.5, 0.42, 0.38), "WILLOW HALL", 180.0, true)
	await _fill_parking(world, Vector3(16, 0, 79), 8.0, 6.0, [Color(0.4, 0.55, 0.45)], "van")
	_fill_shed(world, Vector3(-52, 0, 76), Color(0.5, 0.6, 0.48))
	_fill_shed(world, Vector3(-38, 0, 77), Color(0.6, 0.5, 0.38))
	_fill_shed(world, Vector3(48, 0, 76), Color(0.52, 0.58, 0.66))
	for seg in [[-84.0, -70.0], [-30.0, -16.0], [13.0, 27.0], [71.0, 85.0]]:
		_fill_fence_x(world, seg[0], seg[1], 73.0)
	# CLUTTER: same front-gap fix as Elm — the Pine/Cedar/Birch
	# clusters' benches and flowerbeds stood in those roadways
	# and one cluster's mailboxes stood IN Riverside Drive.
	# Centres shifted onto grass; mailbox clusters removed.
	for fc3 in [Vector3(-82, 0, 60.5), Vector3(-29, 0, 60.5), Vector3(14, 0, 60.5), Vector3(78, 0, 60.5)]:
		_fill_flowerbed(world, fc3, 4.0)
		_fill_bench(world, fc3 + Vector3(3.6, 0, 0.8), 180.0)
	_fill_bench(world, Vector3(84, 0, 74), 0.0)
	_fill_flowerbed(world, Vector3(88, 0, 73), 3.6)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
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
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ PARK 2 centre cluster (SW park, between pond + gazebo)
	var bed := _cyl(world, Vector3(-83, 0.16, 73), 1.8, 1.8, 0.3, Color(0.4, 0.3, 0.2), true)
	bed.material_override = _mat(Color(0.4, 0.3, 0.2), 1.0)
	var ring_spots: Array = []
	for fi in range(7):
		var fa: float = float(fi) * TAU / 7.0
		ring_spots.append([Vector3(-83 + cos(fa) * 1.1, 0.22, 73 + sin(fa) * 1.1), [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35), Color(0.9, 0.9, 0.95)][fi % 3], 0.9]) # v1.0.26 completion: stem+daisy via _place_flowers (was a bare sphere)
	_place_flowers(world, ring_spots)
	content_points.append(Vector3(-83, 0, 73))
	_fill_bench(world, Vector3(-79, 0, 70), -90.0)
	_fill_lamp(world, Vector3(-87, 0, 70))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ LAST GAPS (audit pass 2): park interior + house-row side gaps
	_fill_bench(world, Vector3(-27, 0, 21), 0.0) # inside park 1, by the pond path
	_fill_flowerbed(world, Vector3(-33, 0, 29), 3.6)
	_fill_flowerbed(world, Vector3(-108, 0, 26.5), 3.6) # Oak-south west front gardens
	_fill_bench(world, Vector3(-93, 0, 26.5), 180.0)
	_fill_flowerbed(world, Vector3(-113, 0, -71), 3.4) # NW corner side garden
	# CLUTTER: these two benches stood CENTRED on the Cedar
	# Street and Birch Lane centrelines — the "random benches on
	# the street" Michael photographed. They now rest on the
	# grass verges west/east of those roads. The two stray
	# three-mailbox clusters that stood here are removed.
	_fill_bench(world, Vector3(-27, 0, -47), 0.0) # Elm-south front-garden gap, west of Cedar
	_fill_bench(world, Vector3(31, 0, -47), 0.0) # Elm-south front-garden gap, east of Birch
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ STREET LAMP GRID: every street gets lamps along it
	for lp in [Vector3(-45, 0, -16.6), Vector3(5, 0, -16.6), Vector3(50, 0, -16.6), Vector3(95, 0, -16.6),
			Vector3(-8, 0, 20.6), Vector3(44, 0, 20.6), Vector3(96, 0, 20.6),
			Vector3(-40, 0, -49.6), Vector3(10, 0, -49.6), Vector3(58, 0, -49.6),
			Vector3(-40, 0, 60.6), Vector3(10, 0, 60.6), Vector3(58, 0, 60.6),
			Vector3(-64.6, 0, -30), Vector3(-64.6, 0, 30), Vector3(-14.6, 0, -30), Vector3(-14.6, 0, 32),
			Vector3(29.6, 0, -32), Vector3(29.6, 0, 28), Vector3(66.6, 0, -30), Vector3(66.6, 0, 30)]:
		_fill_lamp(world, lp)

func _build_east_district(world: Node3D, srng: RandomNumberGenerator) -> void:
	# MAP DOUBLING — the east district's own content. The houses,
	# roads, signs and scatter are built elsewhere; this is the
	# named places + per-block dressing that keeps the new half
	# from reading as a copy-paste suburb, in the same style and
	# with the same helpers as the v1.0 town fill. Block centres
	# sit midway between the new cross streets.
	var centres: Array = [152.0, 200.0, 248.0, 296.0, 352.0]
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ HARBOUR MARKET ROW (Maple band, Summit block)
	_fill_stall(world, Vector3(188, 0, -21), Color(0.85, 0.35, 0.3))
	_fill_stall(world, Vector3(197, 0, -21), Color(0.3, 0.6, 0.62))
	_fill_stall(world, Vector3(206, 0, -21), Color(0.9, 0.7, 0.25))
	_fill_lamp(world, Vector3(197, 0, -17.5))
	_fill_bench(world, Vector3(183, 0, -17.8), 180.0)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ MEADOW COURT apartments (Elm north band, Quarry block)
	_fill_building(world, Vector3(248, 0, -76), Vector3(13, 10.5, 10), Color(0.88, 0.8, 0.74), Color(0.42, 0.48, 0.55), "MEADOW COURT", 0.0, true)
	await _fill_parking(world, Vector3(234, 0, -75), 10.0, 7.0, [Color(0.35, 0.5, 0.8), Color(0.85, 0.6, 0.25)], "hatchback")
	_fill_lamp(world, Vector3(233, 0, -69))
	_build_tree(world, Vector3(262, 0, -88))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ SUNSET GREEN pocket park (Willow south band, Meadow block)
	var spath1 := _box(world, Vector3(296, 0.03, 79), Vector3(17, 0.06, 2.2), Color.WHITE)
	spath1.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(5, 1, 1))
	var spath2 := _box(world, Vector3(296, 0.03, 79), Vector3(2.2, 0.06, 17), Color.WHITE)
	spath2.material_override = _mat_tex(TEX_SIDEWALK, Color.WHITE, Vector3(1, 5, 1))
	_cyl(world, Vector3(296, 0.35, 79), 2.3, 2.5, 0.7, Color(0.75, 0.72, 0.68), true)
	var swater := _cyl(world, Vector3(296, 0.62, 79), 2.0, 2.0, 0.18, Color.WHITE)
	swater.material_override = _mat_tex(TEX_WATER, Color.WHITE, Vector3(2, 2, 1), 0.3)
	_cyl(world, Vector3(296, 0.9, 79), 0.16, 0.22, 1.1, Color(0.7, 0.68, 0.64), true)
	_sphere(world, Vector3(296, 1.6, 79), Vector3(0.34, 0.34, 0.34), Color(0.8, 0.78, 0.74))
	content_points.append(Vector3(296, 0, 79))
	_fill_bench(world, Vector3(289, 0, 72), 0.0)
	_fill_bench(world, Vector3(303, 0, 86), 180.0)
	_fill_lamp(world, Vector3(297, 0, 70.5))
	_fill_flowerbed(world, Vector3(288, 0, 86), 4.0)
	_fill_flowerbed(world, Vector3(304, 0, 72), 4.0)
	_build_tree(world, Vector3(286, 0, 89))
	_build_tree(world, Vector3(306, 0, 89))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ PER-BLOCK DRESSING (all five new blocks)
	var shed_cols: Array = [Color(0.45, 0.6, 0.45), Color(0.6, 0.48, 0.36), Color(0.5, 0.58, 0.68), Color(0.62, 0.5, 0.4), Color(0.55, 0.62, 0.5)]
	for ci in range(centres.size()):
		var c: float = centres[ci]
		# Elm back gardens: a shed + a tree behind the north row
		# (the Quarry block's shed spot is Meadow Court itself).
		if ci != 2:
			_fill_shed(world, Vector3(c, 0, -77), shed_cols[ci])
		_build_tree(world, Vector3(c + 10.0, 0, -78))
		# Maple front-gap clusters (flowerbed + bench + fence) —
		# the Summit block's spot is the Harbour Market instead.
		if ci != 1:
			_fill_flowerbed(world, Vector3(c, 0, -20), 4.0)
			_fill_bench(world, Vector3(c + 3.6, 0, -19.4), 0.0)
			_fill_fence_x(world, c - 5.0, c + 5.0, -22.6)
		# Oak front-gap clusters, facing the south row's fronts
		_fill_flowerbed(world, Vector3(c, 0, 24.5), 4.0)
		_fill_bench(world, Vector3(c + 3.6, 0, 25.3), 180.0)
		if ci == 1:
			_fill_flowerbed(world, Vector3(216, 0, 24.5), 4.0) # the Summit block's mid-gap sat empty between two clusters
		# Willow back fences + sheds (the Meadow block's is
		# Sunset Green, dressed above).
		if ci != 3:
			_fill_fence_x(world, c - 7.0, c + 7.0, 73.0)
			_fill_shed(world, Vector3(c, 0, 77), shed_cols[(ci + 2) % shed_cols.size()])
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ PROMENADE EAST: lamps, flowerbeds, river benches, trees
	for lx2 in [140.0, 188.0, 236.0, 284.0, 332.0]:
		_fill_lamp(world, Vector3(lx2, 0, -85))
	for fb2 in [Vector3(164, 0, -88.5), Vector3(212, 0, -88.5), Vector3(260, 0, -88.5), Vector3(308, 0, -88.5), Vector3(356, 0, -88.5)]:
		_fill_flowerbed(world, fb2, 5.0)
	for bx2 in [136.0, 160.0, 184.0, 208.0, 232.0, 256.0, 280.0, 304.0, 328.0, 352.0]:
		var rb2 := Vector3(bx2, 0, -81)
		_box(world, rb2 + Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.55), Color(0.55, 0.4, 0.25), true)
		_box(world, rb2 + Vector3(0, 0.85, 0.24), Vector3(2.2, 0.5, 0.09), Color(0.55, 0.4, 0.25))
		_box(world, rb2 + Vector3(-0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		_box(world, rb2 + Vector3(0.8, 0.22, 0), Vector3(0.15, 0.45, 0.5), Color(0.4, 0.3, 0.2))
		content_points.append(rb2)
	for tx2 in [148.0, 168.0, 196.0, 216.0, 244.0, 264.0, 292.0, 312.0, 340.0, 360.0]: # x kept >= 8 from every cross-street centreline: a canopy blob overhangs ~1m and the clutter audit counts overhang as on-road
		_build_tree(world, Vector3(tx2, 0, -79))
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ STREET LAMP GRID EAST: every street lit, as west
	for lp2 in [Vector3(140, 0, -16.6), Vector3(188, 0, -16.6), Vector3(236, 0, -16.6), Vector3(284, 0, -16.6), Vector3(332, 0, -16.6),
			Vector3(140, 0, 20.6), Vector3(188, 0, 20.6), Vector3(236, 0, 20.6), Vector3(284, 0, 20.6), Vector3(332, 0, 20.6),
			Vector3(140, 0, -49.6), Vector3(188, 0, -49.6), Vector3(236, 0, -49.6), Vector3(284, 0, -49.6), Vector3(332, 0, -49.6),
			Vector3(140, 0, 60.6), Vector3(188, 0, 60.6), Vector3(236, 0, 60.6), Vector3(284, 0, 60.6), Vector3(332, 0, 60.6),
			Vector3(133.4, 0, -30), Vector3(133.4, 0, 30), Vector3(181.4, 0, -30), Vector3(181.4, 0, 30),
			Vector3(229.4, 0, -30), Vector3(229.4, 0, 30), Vector3(277.4, 0, -30), Vector3(277.4, 0, 30),
			Vector3(325.4, 0, -30), Vector3(325.4, 0, 30)]:
		_fill_lamp(world, lp2)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ EAST VERGE TREES: green against the construction
	# border, and content for the far-east audit cells.
	for tv in [Vector3(363, 0, -62), Vector3(363, 0, -40), Vector3(363, 0, -28), Vector3(363, 0, 4), Vector3(363, 0, 36), Vector3(363, 0, 48), Vector3(363, 0, 62), Vector3(363, 0, 80)]:
		_build_tree(world, tv)
	await _build_tick()
	await _build_tick() # v1.0.11 chunking: sub-section boundary
	# ============ BACK-GARDEN TREES: midway shade trees in the
	# Elm and Willow back bands, so no land cell sits empty (the
	# v0.9 empty-area audit walks the whole doubled map).
	for bt in [Vector3(170, 0, -74), Vector3(218, 0, -74), Vector3(266, 0, -74), Vector3(314, 0, -74),
			Vector3(234, 0, -80), Vector3(335, 0, -80),
			Vector3(170, 0, 74), Vector3(230, 0, 74), Vector3(266, 0, 74), Vector3(314, 0, 74),
			Vector3(136, 0, 80), Vector3(332, 0, 80)]:
		_build_tree(world, bt)

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

# --- v1.0.29: Meshy building models -------------------------------------
# Every building in town is now one of the slimmed Meshy GLBs under
# assets/models/buildings/ (1024px textures, ~1 MB each). Per model:
# "yaw" — the extra rotation that turns the model's own front (the
# door / signage face, identified from 4-face renders checked
# against the reference photos) to +Z before the lot's facing is
# applied; "tw" / "td" — the target footprint in metres the model
# is uniformly scaled to fit; "hcap" — a height cap so the tall
# narrow models don't tower over the street.
const BUILDING_MODELS: Dictionary = {
	"school": {"yaw": 0.0, "tw": 11.2, "td": 8.6, "hcap": 9.5},
	"elementary_school": {"yaw": 0.0, "tw": 11.2, "td": 8.2, "hcap": 9.5},
	"library": {"yaw": 0.0, "tw": 9.6, "td": 8.4, "hcap": 8.5},
	"police_station": {"yaw": 0.0, "tw": 9.4, "td": 8.4, "hcap": 8.0},
	"fire_station": {"yaw": 90.0, "tw": 10.4, "td": 8.4, "hcap": 8.6},
	"diner": {"yaw": 0.0, "tw": 9.4, "td": 7.8, "hcap": 8.0},
	"corner_store": {"yaw": 0.0, "tw": 9.4, "td": 8.2, "hcap": 8.6},
	"bistro": {"yaw": 0.0, "tw": 9.2, "td": 8.2, "hcap": 9.0},
	"corner_cafe": {"yaw": 0.0, "tw": 9.2, "td": 8.4, "hcap": 8.4},
	"corner_cafe_2": {"yaw": 90.0, "tw": 9.0, "td": 7.6, "hcap": 8.6},
	"apartment_block": {"yaw": 90.0, "tw": 10.2, "td": 8.4, "hcap": 12.5},
	"bakery": {"yaw": 0.0, "tw": 6.8, "td": 5.0, "hcap": 7.0},
	"house_modern": {"yaw": -90.0, "tw": 8.6, "td": 7.6, "hcap": 8.4},
	"house_red": {"yaw": 0.0, "tw": 8.6, "td": 7.6, "hcap": 8.4},
	"house_blue": {"yaw": 0.0, "tw": 8.6, "td": 7.6, "hcap": 8.4},
	"house_beige": {"yaw": 0.0, "tw": 8.6, "td": 7.6, "hcap": 8.4},
	"house_white_tall": {"yaw": 0.0, "tw": 8.6, "td": 7.6, "hcap": 8.4},
	"house_blue_bungalow": {"yaw": 0.0, "tw": 8.6, "td": 7.6, "hcap": 8.4},
	"house_cream_balcony": {"yaw": 0.0, "tw": 8.6, "td": 7.6, "hcap": 8.4},
}
const HOUSE_MODEL_SEQ: Array = ["house_modern", "house_red", "house_blue", "house_beige", "house_white_tall", "house_blue_bungalow", "house_cream_balcony"]
# Per street-row offsets into HOUSE_MODEL_SEQ for _assign_house_
# models (keyed "street|facing"). With the step of 2, usage across
# the legacy town is 4-5 lots per model and no cross-street facing
# pair shares a model either.
const HOUSE_ROW_OFFSETS: Dictionary = {"Maple Street|1": 0, "Oak Avenue|1": 0, "Oak Avenue|-1": 0, "Elm Drive|1": 3, "Elm Drive|-1": 4, "Willow Crescent|1": 1, "Willow Crescent|-1": 2}
# House lots converted to civic/commercial buildings, keyed by
# "x,z" of the lot position. Michael's placement rules (2026-11-
# 20): every civic model appears EXACTLY ONCE in town — this table
# plus the bakery's fixed site in _build_town_fill is the whole
# civic set, and the suite audits it.
const CIVIC_CONVERSIONS: Dictionary = {
	"-6,-30": "school", "8,-30": "elementary_school",
	"-98,2": "corner_store", "-42,2": "diner", "-6,2": "apartment_block",
	"-112,33": "fire_station", "-56,33": "corner_cafe", "-42,33": "police_station",
	"-2,-66": "library", "44,-66": "corner_cafe_2",
	"2,44": "bistro",
}

var _building_aabbs: Dictionary = {} # model name -> local AABB, measured once per model

func _building_aabb(model: String) -> AABB:
	if _building_aabbs.has(model):
		return _building_aabbs[model]
	var inst: Node3D = (load("res://assets/models/buildings/" + model + ".glb") as PackedScene).instantiate()
	var state: Array = [false]
	var box: AABB = _measure_aabb(inst, Transform3D.IDENTITY, AABB(), state)
	inst.free()
	_building_aabbs[model] = box
	return box

func _measure_aabb(n: Node, xf: Transform3D, box: AABB, state: Array) -> AABB:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var lb: AABB = xf * (n as MeshInstance3D).get_aabb()
		if state[0]:
			box = box.merge(lb)
		else:
			box = lb
			state[0] = true
	for c in n.get_children():
		box = _measure_aabb(c, xf, box, state)
	return box

# Instance a Meshy building model into group g: front facing the
# lot's street, base resting on the ground, AABB centred on the
# lot, uniformly scaled to the model's target footprint, plus a
# static box collision matching the footprint so the cat and the
# neighbours can't walk through the walls. Returns the placed
# size {"w", "d", "h"} in metres.
func _place_building_model(g: Node3D, model: String, facing: float) -> Dictionary:
	var spec: Dictionary = BUILDING_MODELS[model]
	var ab: AABB = _building_aabb(model)
	var yaw_off: float = float(spec["yaw"])
	var swapped: bool = int(round(absf(yaw_off))) == 90
	var raw_w: float = ab.size.z if swapped else ab.size.x
	var raw_d: float = ab.size.x if swapped else ab.size.z
	var s: float = minf(float(spec["tw"]) / raw_w, float(spec["td"]) / raw_d)
	s = minf(s, float(spec["hcap"]) / ab.size.y)
	var yaw: float = yaw_off + (0.0 if facing > 0.0 else 180.0)
	var pivot := Node3D.new()
	pivot.name = "Model_" + model
	pivot.rotation_degrees.y = yaw
	g.add_child(pivot)
	var inst: Node3D = (load("res://assets/models/buildings/" + model + ".glb") as PackedScene).instantiate()
	pivot.add_child(inst)
	inst.scale = Vector3.ONE * s
	var centre: Vector3 = ab.get_center()
	inst.position = Vector3(-centre.x * s, -ab.position.y * s, -centre.z * s)
	var w: float = raw_w * s
	var d: float = raw_d * s
	var hgt: float = ab.size.y * s
	var body := StaticBody3D.new()
	body.name = "BuildingBody"
	var cs := CollisionShape3D.new()
	cs.shape = _box_shape_for(Vector3(maxf(w - 0.25, 0.5), hgt * 0.94, maxf(d - 0.25, 0.5)))
	cs.position = Vector3(0, hgt * 0.47, 0)
	body.add_child(cs)
	g.add_child(body)
	return {"w": w, "d": d, "h": hgt}

# v1.0.29: build the civic/commercial buildings on the converted
# lots (the set in CIVIC_CONVERSIONS — each model exactly once).
func _build_civic_buildings(world: Node3D) -> void:
	for lot in civic_lots:
		content_points.append(lot["pos"]) # v0.9 empty-area audit
		var g := Node3D.new()
		g.name = "Civic_" + String(lot["model"])
		g.position = lot["pos"]
		world.add_child(g)
		var dims: Dictionary = _place_building_model(g, String(lot["model"]), float(lot["facing"]))
		lot["hx"] = float(dims["w"]) * 0.5
		lot["hz"] = float(dims["d"]) * 0.5
		building_footprints.append({"pos": lot["pos"], "hx": lot["hx"], "hz": lot["hz"]})

func _build_house(parent: Node, h: Dictionary, wall_col: Color, roof_col: Color) -> void:
	content_points.append(h["pos"]) # v0.9 empty-area audit
	# v1.0.29: the code-built shell is gone — each lot wears one of
	# the seven Meshy house models (assigned per street row in
	# _define_houses; never the same model on two adjacent lots).
	# The address board, number plaque, path, mailbox, hedges,
	# fences and yard prop carry over from the old builder, hung on
	# the model's real front face, so the lot keeps its identity:
	# same address, same plaque, same driveway, same seeded
	# dressing every run. (wall_col / roof_col are unused now — the
	# models bring their own colours — but the signature stays so
	# the build loop above is untouched.)
	var p: Vector3 = h["pos"]
	var g := Node3D.new()
	g.position = p
	parent.add_child(g)
	var facing: float = float(h.get("facing", 1.0)) # door side (fronts its named street)
	var hr := RandomNumberGenerator.new()
	hr.seed = absi(str(h["address"]).hash()) * 7919 + 13
	var dims: Dictionary = _place_building_model(g, String(h["model"]), facing)
	var fz: float = float(dims["d"]) * 0.5 # the placed model's front wall face
	var hgt: float = float(dims["h"])
	var door_x: float = 0.0 # the Meshy fronts carry their door at centre
	await _build_tick() # v1.0.11 chunking
	# Foundation shrubs against the front corners (v1.0 dressing).
	for shx in [-float(dims["w"]) * 0.4, float(dims["w"]) * 0.4]:
		var shrub := _sphere(g, Vector3(shx, 0.42, facing * (fz + 0.35)), Vector3(0.85, 0.62, 0.6), Color.WHITE)
		shrub.material_override = _mat_tex(TEX_FOLIAGE, Color(0.8, 0.95, 0.75), Vector3(2, 2, 2))
	# Address sign + brass number plaque (IDENTICAL system on every house:
	# this is how you find home). The board rides the model's front
	# wall, dropping on low houses so it stays on the wall face.
	var board_y: float = clampf(hgt * 0.66, 2.45, 3.1)
	_box(g, Vector3(0, board_y, facing * (fz + 0.18)), Vector3(5.6, 1.05, 0.1), Color(0.93, 0.92, 0.88))
	_box(g, Vector3(0, board_y, facing * (fz + 0.24)), Vector3(5.4, 0.92, 0.1), Color(0.1, 0.1, 0.14))
	var addr_rot: float = 0.0 if facing > 0.0 else 180.0
	var addr_ps: float = clampf(4.9 / (0.55 * float(h["address"].length()) * 88.0), 0.0035, 0.006)
	_label3d_flat(g, h["address"], Vector3(0, board_y, facing * (fz + 0.32)), 88, Color(1.0, 0.95, 0.6), addr_rot, addr_ps)
	var plaque_y: float = 1.7 if board_y > 2.9 else 1.3
	var plaque_x: float = door_x + 1.15
	_box(g, Vector3(plaque_x, plaque_y, facing * (fz + 0.12)), Vector3(0.85, 0.55, 0.08), Color(0.75, 0.6, 0.25))
	_label3d_flat(g, h["address"].split(" ")[0], Vector3(plaque_x, plaque_y, facing * (fz + 0.18)), 72, Color(0.15, 0.12, 0.05), addr_rot, 0.005)
	h["plaque"] = h["address"].split(" ")[0] # the number on the plaque == the address number
	# Path: 0 = slab, 1 = stepping stones (leads to the door)
	if hr.randi_range(0, 1) == 0:
		_box(g, Vector3(door_x, 0.05, facing * 5.6), Vector3(1.6, 0.08, 2.4), Color(0.85, 0.83, 0.76))
	else:
		for stp in [4.9, 5.9, 6.9]:
			_box(g, Vector3(door_x, 0.05, facing * stp), Vector3(0.95, 0.08, 0.7), Color(0.82, 0.8, 0.74))
	# Mailbox: EXACTLY ONE per house (CLUTTER, Michael 2026-11-17:
	# he found houses with three mailboxes and houses with none).
	# Style 0 = red post box out by the path, 1 = black wall box
	# by the door — never none, never two. Built in a group named
	# "Mailbox" so the clutter audit can count one per house.
	var mb_style: int = hr.randi_range(0, 1)
	var mb := Node3D.new()
	mb.name = "Mailbox"
	g.add_child(mb)
	if mb_style == 0:
		mb.position = Vector3(2.8, 0, facing * 6.4)
		_cyl(mb, Vector3(0, 0.5, 0), 0.05, 0.05, 1.0, Color(0.4, 0.35, 0.3), true)
		_box(mb, Vector3(0, 1.1, 0), Vector3(0.7, 0.45, 0.5), Color(0.6, 0.25, 0.22))
	else:
		mb.position = Vector3(door_x - 1.25, 0, facing * (fz + 0.14)) # wall box rides beside the door
		_box(mb, Vector3(0, 1.5, 0), Vector3(0.6, 0.42, 0.22), Color(0.16, 0.16, 0.18))
	# Front hedge (45%; the pair flanks the path)
	if hr.randf() < 0.45:
		for hx3 in [door_x - 3.4, door_x + 3.4]:
			var hg := _box(g, Vector3(hx3, 0.35, facing * 5.4), Vector3(3.2, 0.7, 0.5), Color.WHITE, true)
			hg.material_override = _mat_tex(TEX_FOLIAGE, Color(0.85, 0.98, 0.82), Vector3(2, 1, 1))
	# Side picket fences (40%)
	if hr.randf() < 0.4:
		for sx5 in [-5.6, 5.6]:
			for pz3 in [3.4, 4.3, 5.2, 6.1, 7.0]:
				_box(g, Vector3(sx5, 0.45, facing * pz3), Vector3(0.14, 0.9, 0.3), Color(0.94, 0.93, 0.9), true)
			_box(g, Vector3(sx5, 0.62, facing * 5.2), Vector3(0.08, 0.1, 3.9), Color(0.94, 0.93, 0.9), true)
	await _build_tick() # v1.0.11 chunking
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
			# v1.0.29: never on the driveway side of the lot — a
			# yard tree at the pad's edge hangs its canopy over the
			# driveway and the parked car (the v1.0.27 tree audit).
			var drv_side: float = 0.0
			for dd in _driveway_data():
				if (dd[0] as Vector3) == p:
					drv_side = float(dd[1])
			if drv_side != 0.0 and signf(prop_x) == drv_side and absf(prop_x) > 2.5:
				prop_x = 3.4 if prop_x < 0.0 else -3.2
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
	tree_registry.append({"node": g, "r": 2.4}) # v1.0.27: canopy reach (blobs to 1.35 + puff radius) for the clearance audit
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

# v1.0.27: the driveway-car table — [lot position, side of the
# front path (+1/-1), road z, colour, type] — shared by the town
# build (which parks the cars below) and _compute_driveway_pads
# (which derives the pad rects the scatter gate and tree audit
# read), so the three can never drift apart.
# v1.0.29: keyed by LOT POSITION, not address — the Meshy building
# swap re-sequences the house numbers (and the numbers differ
# between the legacy and doubled towns), while lot positions are
# stable in both. The three lots that became civic buildings (the
# old 27 + 33 Maple Street, the old 16 Oak Avenue) lost their
# driveway cars with their houses.
func _driveway_data() -> Array:
	var data: Array = [
		[Vector3(44, 0, -30), -1.0, -11.0, Color(0.25, 0.45, 0.85), "sedan"],
		[Vector3(-42, 0, -30), 1.0, -11.0, Color(0.3, 0.6, 0.5), "hatchback"],
		[Vector3(98, 0, -30), -1.0, -11.0, Color(0.5, 0.5, 0.55), "pickup"],
		[Vector3(-56, 0, -30), 1.0, -11.0, Color(0.2, 0.55, 0.6), "hatchback"],
		[Vector3(-98, 0, -30), -1.0, -11.0, Color(0.6, 0.35, 0.75), "convertible"],
		[Vector3(-112, 0, -30), 1.0, -11.0, Color(0.2, 0.3, 0.55), "van"],
		[Vector3(-2, 0, 33), 1.0, 15.0, Color(0.82, 0.85, 0.9), "van"],
		[Vector3(44, 0, 33), 1.0, 15.0, Color(0.75, 0.76, 0.8), "sedan"],
		[Vector3(98, 0, 33), -1.0, 15.0, Color(0.9, 0.55, 0.2), "hatchback"],
		[Vector3(-98, 0, 33), 1.0, 15.0, Color(0.55, 0.25, 0.3), "pickup"],
	]
	# MAP DOUBLING: three of the new east houses get driveway cars
	# too. BISECT (v1.0.12): skipped in legacy mode — those houses
	# don't exist there.
	if not LEGACY_TOWN_ONLY:
		data += [
			[Vector3(146, 0, -30), -1.0, -11.0, Color(0.35, 0.5, 0.8), "sedan"],
			[Vector3(290, 0, -30), 1.0, -11.0, Color(0.85, 0.6, 0.25), "hatchback"],
			[Vector3(290, 0, 33), 1.0, 15.0, Color(0.3, 0.6, 0.5), "sedan"],
		]
	return data


# v1.0.27: derive every driveway pad's rect from the house data,
# using _park_in_driveway's own formula. Runs at the very top of
# the world build: ground scatter (which reads the rects through
# _paved_spot) is planted long before the cars are parked.
func _compute_driveway_pads() -> void:
	driveway_pads.clear()
	var by_pos: Dictionary = {}
	for hh in houses:
		by_pos["%d,%d" % [int(hh["pos"].x), int(hh["pos"].z)]] = hh
	for dd in _driveway_data():
		var pk: String = "%d,%d" % [int((dd[0] as Vector3).x), int((dd[0] as Vector3).z)]
		if not by_pos.has(pk):
			continue
		var dh: Dictionary = by_pos[pk]
		var hp: Vector3 = dh["pos"]
		var facing: float = float(dh["facing"])
		var pad_near: float = hp.z + facing * 3.7
		var pad_far: float = float(dd[2]) - facing * 5.1
		driveway_pads.append({
			"cx": hp.x + float(dd[1]) * 4.6, "cz": (pad_near + pad_far) * 0.5,
			"hx": 1.4, "hz": absf(pad_far - pad_near) * 0.5})


# v1.0.27 TREE CLEARANCE (Michael's v1.0.26 play photos): a pine
# planted at a lot corner hung its whole lowest tier over the
# driveway, swallowing the parked car; another trunk stood in
# the promenade slab. Trees are planted from half a dozen places
# (street gaps, fixed dressing, the seeded scatter, parks, the
# backdrop rows, the escape diorama) and NONE of them knew where
# the driveways and parked cars would be — the scatter even
# predates the parking. So clearance is enforced HERE, once, at
# the end of the build, over every registered tree: a tree whose
# canopy circle reaches a driveway pad or a parked car, or whose
# trunk stands on pavement / in a road band / against a house,
# is moved to the nearest spot that passes every test (widening
# rings, scatter-grade validity); a tree with nowhere to go is
# culled rather than left intersecting.
func _tree_spot_clear(p: Vector3, r: float) -> bool:
	for dp in driveway_pads:
		var dx: float = maxf(absf(p.x - float(dp["cx"])) - float(dp["hx"]), 0.0)
		var dz: float = maxf(absf(p.z - float(dp["cz"])) - float(dp["hz"]), 0.0)
		if Vector2(dx, dz).length() < r + 0.25:
			return false
	for cp in parked_car_spots:
		if Vector2(p.x - (cp as Vector3).x, p.z - (cp as Vector3).z).length() < r + 2.5:
			return false
	if _paved_spot(p):
		return false
	# Road bands (same centrelines the scatter gate uses; trunk +
	# a margin inside the sidewalk's outer edge). The bands are
	# FINITE — a road only exists along its real extent, so the
	# shore pines, the far-bank backdrop and the escape-room
	# diorama (all far outside the road grid) are not flagged by
	# a centreline's infinite extension.
	var bands_z: Array = [-55.0, -11.0, 15.0, 55.0]
	var bands_x: Array = [-70.0, -20.0, 24.0, 72.0]
	var road_x_extent: float = 132.0
	if not LEGACY_TOWN_ONLY:
		bands_x += [128.0, 176.0, 224.0, 272.0, 320.0]
		road_x_extent = 388.0
	if p.x >= -132.0 and p.x <= road_x_extent:
		for rz in bands_z:
			if absf(p.z - float(rz)) < 5.3:
				return false
	if absf(p.z) <= 97.0:
		for rx in bands_x:
			if absf(p.x - float(rx)) < 5.3:
				return false
	for hh in houses:
		if p.distance_to(hh["pos"]) < 6.0:
			return false
	return true


func _audit_tree_clearance() -> void:
	var moved: int = 0
	var culled: int = 0
	for te in tree_registry:
		var node := te["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var r: float = float(te["r"])
		if _tree_spot_clear(node.position, r):
			continue
		var placed_ok := false
		for rad in [2.0, 3.5, 5.0, 7.0, 9.0, 11.0, 13.0, 16.0]:
			if placed_ok:
				break
			for k in range(12):
				var ang: float = TAU * float(k) / 12.0 + rad * 0.7
				var cand := Vector3(node.position.x + cos(ang) * rad, 0, node.position.z + sin(ang) * rad)
				if cand.x < -118.0 or cand.x > 370.0 or cand.z < -88.0 or cand.z > 88.0:
					continue
				if _ground_spot_blocked(cand):
					continue
				if not _tree_spot_clear(cand, r):
					continue
				var clash := false
				for te2 in tree_registry:
					var n2 := te2["node"] as Node3D
					if n2 != null and n2 != node and is_instance_valid(n2) and n2.visible:
						if Vector2(cand.x - n2.position.x, cand.z - n2.position.z).length() < r + float(te2["r"]) + 0.5:
							clash = true
							break
				if clash:
					continue
				node.position = cand
				placed_ok = true
				moved += 1
				break
		if not placed_ok:
			node.visible = false
			culled += 1
	_boot_log("tree clearance audit: moved=%d culled=%d of %d trees" % [moved, culled, tree_registry.size()])


func _park_in_driveway(world: Node3D, house_pos: Vector3, facing: float, road_z: float, side: float, col: Color, car_type: String) -> Vector3:
	# STREETS (Michael, 2026-11-16): a parked car belongs in a
	# DRIVEWAY. Lays a concrete pad from the house's front wall to
	# the sidewalk edge, offset to one side of the front path (the
	# path, door, mailbox, hedges and yard props all sit within
	# +/-3.5 of the house centre or behind the car's nose line, so
	# a pad centred 4.6 to the side clears them), and parks the car
	# on it perpendicular to the street like a real driveway car.
	# Returns the car's position (it stays a hiding spot).
	var pad_near: float = house_pos.z + facing * 3.7 # just at the front wall / foundation edge
	var pad_far: float = road_z - facing * 5.1 # sidewalk inner edge (band half 4.8) + a small verge
	var pad_cz: float = (pad_near + pad_far) * 0.5
	var pad_len: float = absf(pad_far - pad_near)
	var cx: float = house_pos.x + side * 4.6
	var pad := _box(world, Vector3(cx, 0.03, pad_cz), Vector3(2.8, 0.06, pad_len), Color.WHITE)
	pad.material_override = _mat_tex(TEX_SIDEWALK, Color(0.94, 0.94, 0.96), Vector3(1, 3, 1))
	var car_pos := Vector3(cx, 0.06, pad_cz) # wheels rest ON the pad, not sunk in it
	_build_car(world, car_pos, col, false, car_type)
	parked_car_spots.append(car_pos) # v1.0.27: static car — the tree audit keeps canopies off it
	return car_pos

func _vehicle_scene(car_type: String) -> PackedScene:
	# v1.0.21: which Meshy model a car_type wears. The traffic /
	# driveway type names are the town's own (sedan, hatchback,
	# pickup, van, convertible) — the models rotate inside a type
	# so a street never repeats one car, and the police car turns
	# up occasionally in the sedan pool. "pound" is the Animal
	# Control van, used only by _spawn_pound.
	_car_variant += 1
	match car_type:
		"pickup":
			return preload("res://assets/models/truck_pickup.glb")
		"van":
			return preload("res://assets/models/van_delivery.glb")
		"convertible":
			return preload("res://assets/models/car_sports.glb")
		"pound":
			return preload("res://assets/models/van_animal_control.glb")
		"hatchback":
			var hp: Array = [preload("res://assets/models/car_compact.glb"), preload("res://assets/models/car_sedan.glb"), preload("res://assets/models/suv.glb")]
			return hp[_car_variant % hp.size()]
		_: # sedan
			if _car_variant % 7 == 0:
				return preload("res://assets/models/car_police.glb")
			var sp: Array = [preload("res://assets/models/car_sedan.glb"), preload("res://assets/models/suv.glb"), preload("res://assets/models/car_compact.glb")]
			return sp[_car_variant % sp.size()]

func _build_car(parent: Node, pos: Vector3, col: Color, along_x: bool, car_type: String = "sedan", for_traffic: bool = false) -> Node3D:
	if not for_traffic:
		content_points.append(pos) # v0.9 empty-area audit
	# v1.0.21 (Michael's all-Meshy rule — "do a build now with all
	# the cars included"): the code-built box cars are GONE. Every
	# vehicle on the street — traffic, driveway and lot cars, and
	# the pound van via the "pound" type — is a Meshy model from
	# assets/models, instantiated under the same "Car" root with
	# the conventions the town was built around: nose toward +X
	# (the models arrive nose toward -X — the instance is turned
	# to suit, see VEHICLE_MODEL_YAW), ground at y=0, one solid
	# box body so the cat still bumps into them and hides at
	# them. `col` stays in the signature
	# (the town's builders pass it) but the models carry their
	# own colours now. The models were decimated + texture-capped
	# in Blender before import (see vehicles_src): one mesh, one
	# material each, so a car costs ONE draw call where the box
	# build cost dozens.
	var g := Node3D.new()
	g.name = "Car" # PERF: named so the clutter-range pass can skip car subtrees (a car must never lose parts at range)
	g.position = pos
	if not along_x:
		g.rotation_degrees = Vector3(0, 90, 0)
	parent.add_child(g)
	var scene: PackedScene = _vehicle_scene(car_type)
	var inst: Node3D = scene.instantiate()
	inst.rotation_degrees = Vector3(0, VEHICLE_MODEL_YAW, 0) # v1.0.22: nose -X -> the town's +X (see the const)
	g.add_child(inst)
	var dims: Vector3 = VEHICLE_DIMS.get(scene.resource_path, Vector3(4.2, 1.5, 2.0))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(dims.x, dims.y * 0.85, dims.z)
	cs.shape = shape
	cs.position = Vector3(0, dims.y * 0.42, 0)
	body.add_child(cs)
	g.add_child(body)
	if not for_traffic:
		_label3d(g, "hide ⛺", Vector3(0, 2.1, 0), 40, Color(1, 1, 1, 0.85))
	return g

func _car_nose_dir(car_root: Node3D) -> Vector3:
	# v1.0.22: the world direction a car's NOSE points, flattened.
	# _build_car guarantees the model's nose lies along the car
	# root's +X (VEHICLE_MODEL_YAW), so the nose in the world is
	# the root's X axis. The suite holds traffic cars and the
	# patrolling pound van to this against their actual motion —
	# the check v1.0.21 didn't have when it shipped them backwards.
	var x: Vector3 = car_root.global_transform.basis.x
	x.y = 0.0
	return x.normalized() if x.length() > 0.001 else Vector3.RIGHT

func _build_pine(parent: Node, pos: Vector3, s: float = 1.0) -> void:
	# v0.7: FOUR ragged, slightly offset tiers over a tapered trunk —
	# reads as a pine from across the map, not a green cone lollipop.
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	tree_registry.append({"node": g, "r": 1.85 * s + 0.35}) # v1.0.27: lowest tier radius 1.75*s + margin, for the clearance audit
	var pr := RandomNumberGenerator.new()
	pr.seed = absi(int(pos.x * 71.0 + pos.z * 113.0)) + 3
	var ptrunk := _cyl(g, Vector3(0, 0.9 * s, 0), 0.13 * s, 0.22 * s, 1.8 * s, Color.WHITE, true)
	ptrunk.material_override = _mat_tex(TEX_BARK, Color(0.55, 0.42, 0.3), Vector3(1, 2, 1))
	var tiers: Array = [[2.0, 1.75], [3.1, 1.35], [4.15, 0.95], [5.1, 0.55]]
	for ti in range(tiers.size()):
		var tc := _cyl(g, Vector3(pr.randf_range(-0.09, 0.09) * s, tiers[ti][0] * s, pr.randf_range(-0.09, 0.09) * s), 0.12 * s, tiers[ti][1] * s, 1.9 * s, Color.WHITE)
		tc.material_override = _mat_tex(TEX_FOLIAGE, Color(0.5 + 0.07 * float(ti), 0.72 + 0.05 * float(ti), 0.46), Vector3(2, 2, 2))


# ------------------------------------------------- v1.0.17: two escape rooms, one slot
# The shelter build and the house build both register their nodes
# into the same member vars. These helpers snapshot a room's set
# after its build, swap the live set, and switch a room subtree on
# or off (visible + collidable) so only the active room is present
# for the player.
func _capture_room_set(room_node: Node3D) -> Dictionary:
	return {
		"room": room_node,
		"window_blocker": window_blocker,
		"petdoor_blocker": petdoor_blocker,
		"room_title_label": room_title_label,
		"book_node": book_node,
		"book_home_pos": book_home_pos,
		"latch_pivot": latch_pivot,
		"latch_node": latch_node,
		"latch_base_pos": latch_base_pos,
		"sash_node": sash_node,
		"sash_base_y": sash_base_y,
		"flap_node": flap_node,
		"bolt_node": bolt_node,
		"bolt_base_z": bolt_base_z,
		"backdoor_pivot": backdoor_pivot,
		"carrier_node": carrier_node,
		"carrier_door": carrier_door,
		"vase_node": vase_node,
		"vase_home": vase_home,
		"theme_groups": theme_groups,
		"distract_props": distract_props,
		"ward_cages": ward_cages,
	}

func _apply_room_set(s: Dictionary) -> void:
	window_blocker = s["window_blocker"]
	petdoor_blocker = s["petdoor_blocker"]
	room_title_label = s["room_title_label"]
	book_node = s["book_node"]
	book_home_pos = s["book_home_pos"]
	latch_pivot = s["latch_pivot"]
	latch_node = s["latch_node"]
	latch_base_pos = s["latch_base_pos"]
	sash_node = s["sash_node"]
	sash_base_y = s["sash_base_y"]
	flap_node = s["flap_node"]
	bolt_node = s["bolt_node"]
	bolt_base_z = s["bolt_base_z"]
	backdoor_pivot = s["backdoor_pivot"]
	carrier_node = s["carrier_node"]
	carrier_door = s["carrier_door"]
	vase_node = s["vase_node"]
	vase_home = s["vase_home"]
	theme_groups = s["theme_groups"]
	distract_props = s["distract_props"]
	ward_cages = s["ward_cages"]

func _set_room_subtree_active(root: Node, on: bool) -> void:
	if root == null:
		return
	(root as Node3D).visible = on
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		var co := n as CollisionObject3D
		if co == null:
			continue
		if on:
			if co.has_meta("room_off_layer"):
				co.collision_layer = int(co.get_meta("room_off_layer"))
				co.collision_mask = int(co.get_meta("room_off_mask"))
		else:
			if not co.has_meta("room_off_layer"):
				co.set_meta("room_off_layer", co.collision_layer)
				co.set_meta("room_off_mask", co.collision_mask)
			co.collision_layer = 0
			co.collision_mask = 0

func _activate_escape_room(house: bool) -> void:
	escape_room_is_house = house
	_apply_room_set(house_room_set if house else shelter_room_set)
	_set_room_subtree_active(shelter_room_node, not house)
	_set_room_subtree_active(house_room_node, house)
	# The opening's pound cage is a child of main, not of the shelter
	# room — it belongs to the pound only, so it follows the shelter.
	var cage := get_node_or_null("PoundCage")
	if cage != null:
		_set_room_subtree_active(cage, not house)

func _build_house_room() -> void:
	# v1.0.17 (Michael's v1.0.15 play report): the HOUSE interior is
	# back. This is the pre-shelter living-room build (recovered from
	# the v1.0.13 prototype), restored as its OWN room so a regular
	# townsperson's capture lands in a house again — couch, coffee
	# table, the plant / book / vase knock-overs — while the officer's
	# capture keeps the shelter ward. The room shares the shelter's
	# origin and layout (same zones, anchors and prop spots), so all
	# the escape machinery works unchanged; _activate_escape_room
	# swaps which room's nodes the shared member vars point at and
	# hides + de-collides the other. It registers into the same member
	# vars the shelter build uses; the boot sequence snapshots each
	# room's set right after its build.
	var room := Node3D.new()
	room.name = "HouseRoom"
	add_child(room)
	house_room_node = room
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	var stack_pivot: Node3D = null # v1.5: the bottom shelf's horizontal stack is a knock-over prop (built into this pivot, registered later)
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
		# a horizontal stack at the end of two shelves — the bottom
		# shelf's stack sits in its own pivot so the cat can knock
		# it over (v1.5 distraction prop, registered below).
		if shelf_i < 2:
			if shelf_i == 0:
				stack_pivot = Node3D.new()
				stack_pivot.position = shelf_pos + Vector3(2.0, sy - 0.045, 0.3)
				room.add_child(stack_pivot)
				for st in range(3):
					_box(stack_pivot, Vector3(0, 0.065 + float(st) * 0.15, 0), Vector3(0.62, 0.13, 0.48), book_cols[(shelf_i + st + 2) % book_cols.size()])
			else:
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	var pillow_pivot := Node3D.new() # v1.5: this cushion is a knock-over prop (registered below)
	pillow_pivot.position = sofa_pos + Vector3(-2.3, 1.45, -0.45)
	room.add_child(pillow_pivot)
	var pillow1 := _box(pillow_pivot, Vector3(0, 0, 0), Vector3(0.85, 0.85, 0.3), Color(0.92, 0.62, 0.25))
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
	var mug_pivot := Node3D.new() # v1.5: the mug is a knock-over prop (registered below)
	mug_pivot.position = o + Vector3(0.7, 0.5, 1.4)
	room.add_child(mug_pivot)
	_cyl(mug_pivot, Vector3(0, 0.12, 0), 0.11, 0.09, 0.24, Color(0.92, 0.55, 0.3)) # mug
	_box(room, o + Vector3(1.2, 0.53, 1.0), Vector3(0.42, 0.05, 0.14), Color(0.15, 0.15, 0.17)) # remote
	# Armchair + side table + reading lamp (corner)
	var chair := _box(room, o + Vector3(9.5, 0.55, 7.5), Vector3(2.4, 1.1, 2.2), Color.WHITE)
	chair.material_override = _mat_tex(TEX_SOFA, Color(1.25, 0.95, 0.85), Vector3(2, 1, 1))
	chair.rotation_degrees = Vector3(0, -35, 0)
	_box(room, o + Vector3(12.3, 0.5, 4.6), Vector3(1.1, 1.0, 1.1), Color(0.6, 0.44, 0.29))
	var tlamp_pivot := Node3D.new() # v1.5: the reading lamp is a knock-over prop (registered below)
	tlamp_pivot.position = o + Vector3(12.3, 1.0, 4.6)
	room.add_child(tlamp_pivot)
	_cyl(tlamp_pivot, Vector3(0, 0.35, 0), 0.05, 0.07, 0.7, Color(0.35, 0.33, 0.3))
	_sphere(tlamp_pivot, Vector3(0, 0.85, 0), Vector3(0.5, 0.42, 0.5), Color(1.0, 0.88, 0.6))
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	var sill_pivot := Node3D.new() # v1.5: the sill plant is a knock-over prop (registered below)
	sill_pivot.position = win_pos + Vector3(-1.7, -1.63, 0.3)
	room.add_child(sill_pivot)
	_cyl(sill_pivot, Vector3(0, 0.13, 0), 0.16, 0.12, 0.26, Color(0.75, 0.4, 0.3)) # sill plant pot
	var sill_plant := _sphere(sill_pivot, Vector3(0, 0.41, 0), Vector3(0.4, 0.36, 0.4), Color.WHITE)
	sill_plant.material_override = _mat_tex(TEX_FOLIAGE, Color.WHITE, Vector3(1, 1, 1))
	_label3d(room, "Window", win_pos + Vector3(0, 1.95, 0), 56, Color(0.2, 0.3, 0.4))
	# Pet door with frame + a REAL swinging FLAP (flap_node pivots at
	# its top edge; pushing swipes swing it open). v1.1: the frame is
	# a real 4-piece border around a dark opening (it was one solid
	# slab with the flap embedded in it), so the flap reads clearly
	# and the cat can be SEEN slipping through in the escape moment.
	# v1.0.25: the pet door's near-black backing panel is GONE
	# too — through the swung flap the street outside shows,
	# not a black rectangle.
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	var fruit_pivot := Node3D.new() # v1.5: the fruit bowl is a knock-over prop (registered below)
	fruit_pivot.position = o + Vector3(12.8, 1.02, -2.2)
	room.add_child(fruit_pivot)
	_cyl(fruit_pivot, Vector3(0, 0.08, 0), 0.5, 0.4, 0.18, Color(0.8, 0.5, 0.3)) # fruit bowl
	for fr in [Vector3(-0.2, 0.26, -0.2), Vector3(0.2, 0.26, 0.1), Vector3(0, 0.28, -0.05)]:
		_sphere(fruit_pivot, fr, Vector3(0.17, 0.17, 0.17), Color(0.95, 0.6, 0.2))
	# Wall cabinets + hanging pans
	var wallcab := _box(room, o + Vector3(13.3, 2.9, -5.5), Vector3(1.1, 1.3, 5.5), Color.WHITE)
	wallcab.material_override = _mat_tex(TEX_WOOD, Color(0.82, 0.68, 0.5), Vector3(3, 1, 1))
	for px in range(3):
		_cyl(room, o + Vector3(12.6, 2.0 - float(px) * 0.05, -3.4 - float(px) * 0.8), 0.26, 0.26, 0.07, Color(0.35, 0.36, 0.4))
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	var frame_pivot: Node3D = null # v1.5: the south landscape frame can be knocked crooked (registered below)
	for pz in [-3.5, 5.5]:
		if pz > 0.0:
			frame_pivot = Node3D.new()
			frame_pivot.position = o + Vector3(-13.65, 2.4, pz)
			room.add_child(frame_pivot)
			_box(frame_pivot, Vector3(0, 0, 0), Vector3(0.14, 1.0, 1.4), Color(0.45, 0.32, 0.2))
			_box(frame_pivot, Vector3(0.1, 0, 0), Vector3(0.1, 0.8, 1.2), Color(0.6, 0.8, 0.55))
		else:
			_box(room, o + Vector3(-13.65, 2.4, pz), Vector3(0.14, 1.0, 1.4), Color(0.45, 0.32, 0.2))
			_box(room, o + Vector3(-13.55, 2.4, pz), Vector3(0.1, 0.8, 1.2), Color(0.65, 0.78, 0.9))
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
	var yarn_pivot := Node3D.new() # v1.5: the yarn ball is a knock-over prop (registered below)
	yarn_pivot.position = o + Vector3(5.5, 0, 7.8)
	room.add_child(yarn_pivot)
	_sphere(yarn_pivot, Vector3(0, 0.28, 0), Vector3(0.3, 0.3, 0.3), Color(0.85, 0.3, 0.35)) # yarn ball
	var yarn_wrap := _box(yarn_pivot, Vector3(0, 0.28, 0), Vector3(0.64, 0.1, 0.64), Color(0.7, 0.22, 0.28))
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
	var flamp_pivot := Node3D.new() # v1.5: the floor lamp is a knock-over prop (registered below)
	flamp_pivot.position = o + Vector3(12, 0, -7)
	room.add_child(flamp_pivot)
	_cyl(flamp_pivot, Vector3(0, 1.4, 0), 0.06, 0.09, 2.8, Color(0.3, 0.3, 0.33))
	_sphere(flamp_pivot, Vector3(0, 3.0, 0), Vector3(0.65, 0.5, 0.65), Color(1.0, 0.88, 0.6))
	_cyl(room, o + Vector3(-11, 0.5, -5.5), 0.42, 0.32, 1.0, Color(0.75, 0.4, 0.3))
	var corner_plant := _sphere(room, o + Vector3(-11, 1.7, -5.5), Vector3(1.15, 1.25, 1.15), Color.WHITE)
	corner_plant.material_override = _mat_tex(TEX_FOLIAGE, Color.WHITE, Vector3(2, 2, 2))
	# Coat hooks + shoes by the pet door
	for hx2 in range(3):
		_sphere(room, o + Vector3(3.6 + float(hx2) * 0.7, 2.2, -9.6), Vector3(0.09, 0.09, 0.12), Color(0.5, 0.38, 0.24))
	_box(room, o + Vector3(3.8, 1.55, -9.55), Vector3(0.55, 1.15, 0.14), Color(0.4, 0.5, 0.7)) # hanging coat
	var shoes_pivot := Node3D.new() # v1.5: the shoes by the door are a knock-over prop (registered below)
	shoes_pivot.position = o + Vector3(4.95, 0, -9.2)
	room.add_child(shoes_pivot)
	for shx in [-0.35, 0.35]:
		_box(shoes_pivot, Vector3(shx, 0.12, 0), Vector3(0.32, 0.22, 0.7), Color(0.55, 0.35, 0.25))


	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ BACK DOOR with SLIDING BOLT (shopkeeper exit) ====
	var bd_pos := o + Vector3(13.62, 0, 3.4)
	# v1.1 fix: the frame is a BORDER (lintel + two jambs), not a
	# solid block — the old solid block filled the doorway and hid
	# both the dark doorway panel and the cat crossing through it.
	_box(room, bd_pos + Vector3(0.05, 3.22, 0), Vector3(0.24, 0.36, 2.3), Color(0.92, 0.9, 0.84)) # frame lintel
	_box(room, bd_pos + Vector3(0.05, 1.65, -1.06), Vector3(0.24, 3.3, 0.18), Color(0.92, 0.9, 0.84)) # frame jamb (north)
	_box(room, bd_pos + Vector3(0.05, 1.65, 1.06), Vector3(0.24, 3.3, 0.18), Color(0.92, 0.9, 0.84)) # frame jamb (south)
	# v1.0.25: NO dark doorway panel here any more. The v1.1
	# near-black plug filled the open doorway with fake void —
	# exactly the "door opens onto blackness" Michael reported.
	# The escape exterior (street, houses, road) stands outside
	# now, and the open door reveals IT.
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ v1.5 NEW LOOSE PROPS (knock-over additions) ========
	# Michael (2026-11-17): "I want to be able to knock over almost
	# everything in the house." Four modest additions where the room
	# was sparse — a wastebasket by the kitchen, a coat stand in the
	# south-east corner, a stool by the counter, a watering can by
	# the corner plant. All registered as distraction props below.
	var basket_pivot := Node3D.new()
	basket_pivot.position = o + Vector3(11.6, 0, -8.7)
	room.add_child(basket_pivot)
	_cyl(basket_pivot, Vector3(0, 0.35, 0), 0.34, 0.27, 0.7, Color(0.55, 0.58, 0.62)) # wastebasket
	_cyl(basket_pivot, Vector3(0, 0.71, 0), 0.36, 0.36, 0.07, Color(0.45, 0.48, 0.52)) # rim
	_sphere(basket_pivot, Vector3(0.08, 0.6, 0.04), Vector3(0.17, 0.17, 0.17), Color(0.95, 0.94, 0.9)) # crumpled paper
	var coatstand_pivot := Node3D.new()
	coatstand_pivot.position = o + Vector3(12.7, 0, 8.7)
	room.add_child(coatstand_pivot)
	_cyl(coatstand_pivot, Vector3(0, 0.07, 0), 0.42, 0.46, 0.14, Color(0.4, 0.3, 0.2)) # base
	_cyl(coatstand_pivot, Vector3(0, 1.05, 0), 0.06, 0.06, 2.0, Color(0.5, 0.38, 0.24)) # pole
	for hk in [Vector3(0.3, 1.92, 0), Vector3(-0.3, 1.92, 0), Vector3(0, 1.92, 0.3)]:
		_sphere(coatstand_pivot, hk, Vector3(0.1, 0.1, 0.1), Color(0.6, 0.45, 0.28)) # hooks
	_box(coatstand_pivot, Vector3(0.3, 1.32, 0), Vector3(0.52, 1.05, 0.18), Color(0.45, 0.35, 0.55)) # a hanging coat
	var stool_pivot := Node3D.new()
	stool_pivot.position = o + Vector3(10.7, 0, -5.8)
	room.add_child(stool_pivot)
	_cyl(stool_pivot, Vector3(0, 0.62, 0), 0.44, 0.44, 0.1, Color(0.62, 0.45, 0.3)) # seat
	for lg in [Vector3(0.3, 0.3, 0), Vector3(-0.3, 0.3, 0.18), Vector3(-0.05, 0.3, -0.32)]:
		_cyl(stool_pivot, lg, 0.05, 0.05, 0.6, Color(0.5, 0.36, 0.22)) # legs
	var can_pivot := Node3D.new()
	can_pivot.position = o + Vector3(-9.7, 0, -4.9)
	room.add_child(can_pivot)
	_cyl(can_pivot, Vector3(0, 0.28, 0), 0.27, 0.3, 0.55, Color(0.35, 0.55, 0.35)) # watering can body
	_cyl(can_pivot, Vector3(0, 0.6, 0), 0.12, 0.12, 0.1, Color(0.3, 0.48, 0.3)) # filler cap
	var spout := _cyl(can_pivot, Vector3(0.36, 0.34, 0), 0.05, 0.1, 0.55, Color(0.3, 0.48, 0.3)) # spout
	spout.rotation_degrees = Vector3(0, 0, -55)
	_box(can_pivot, Vector3(-0.32, 0.36, 0), Vector3(0.08, 0.42, 0.08), Color(0.3, 0.48, 0.3)) # handle
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ v1.5: ALMOST EVERYTHING KNOCKS OVER ================
	# Michael (2026-11-17): more than "just a couple things" — every
	# plausible loose object in the room joins the SAME distraction
	# system (paw range, topple, cue, she rights it, queueing).
	# "base" is the floor XZ the paw reach is measured from (for
	# objects on furniture it is the furniture's XZ; for the cushion
	# it is the floor in front of the sofa, where the cat stands).
	# "cue" scales the crash: crash (hard), clatter (small/hard),
	# thud (soft). Furniture and fixtures stay put by design: sofa,
	# tables, bookcase, counters, fridge, fireplace, cat tree, the
	# door and the carrier are never props.
	distract_props.append({"id": "floorlamp", "name": "the floor lamp", "pivot": flamp_pivot, "base": o + Vector3(12, 0, -7), "stand": o + Vector3(10.7, 0, -8.2), "toppled": false, "anim_t": 1.0, "home_rot": flamp_pivot.rotation, "topple_rot": Vector3(0, 0, 1.3), "bubble": "The lamp! 💡", "cue": "crash"})
	distract_props.append({"id": "tablelamp", "name": "the table lamp", "pivot": tlamp_pivot, "base": o + Vector3(12.3, 0, 4.6), "stand": o + Vector3(11.2, 0, 5.6), "toppled": false, "anim_t": 1.0, "home_rot": tlamp_pivot.rotation, "topple_rot": Vector3(-1.25, 0, 0), "bubble": "Careful — the lamp! 💡", "cue": "clatter"})
	distract_props.append({"id": "mug", "name": "the mug", "pivot": mug_pivot, "base": o + Vector3(0.7, 0, 1.4), "stand": o + Vector3(0.2, 0, 2.9), "toppled": false, "anim_t": 1.0, "home_rot": mug_pivot.rotation, "topple_rot": Vector3(0, 0, 1.45), "bubble": "My tea! ☕", "cue": "clatter"})
	distract_props.append({"id": "cushion", "name": "the cushion", "pivot": pillow_pivot, "base": o + Vector3(-2.3, 0, 5.2), "stand": o + Vector3(-2.3, 0, 6.0), "toppled": false, "anim_t": 1.0, "home_rot": pillow_pivot.rotation, "topple_rot": Vector3(0.35, 0.25, 0.95), "bubble": "The cushions! 🛋️", "cue": "thud"})
	distract_props.append({"id": "fruitbowl", "name": "the fruit bowl", "pivot": fruit_pivot, "base": o + Vector3(12.8, 0, -2.2), "stand": o + Vector3(11.4, 0, -2.2), "toppled": false, "anim_t": 1.0, "home_rot": fruit_pivot.rotation, "topple_rot": Vector3(0, 0, 1.5), "bubble": "The fruit! 🍊", "cue": "clatter"})
	distract_props.append({"id": "shoes", "name": "the shoes", "pivot": shoes_pivot, "base": o + Vector3(4.95, 0, -9.2), "stand": o + Vector3(4.95, 0, -8.1), "toppled": false, "anim_t": 1.0, "home_rot": shoes_pivot.rotation, "topple_rot": Vector3(-0.5, 0, 0.7), "bubble": "My shoes! 👟", "cue": "thud"})
	distract_props.append({"id": "picture", "name": "the picture", "pivot": frame_pivot, "base": o + Vector3(-13.65, 0, 5.5), "stand": o + Vector3(-12.2, 0, 4.6), "toppled": false, "anim_t": 1.0, "home_rot": frame_pivot.rotation, "topple_rot": Vector3(0.45, 0, 0), "bubble": "The picture's crooked! 🖼️", "cue": "clatter"})
	distract_props.append({"id": "bookstack", "name": "the book stack", "pivot": stack_pivot, "base": o + Vector3(-9, 0, -7.7), "stand": o + Vector3(-9, 0, -6.5), "toppled": false, "anim_t": 1.0, "home_rot": stack_pivot.rotation, "topple_rot": Vector3(1.15, 0, 0), "bubble": "The books! 📚", "cue": "clatter"})
	distract_props.append({"id": "yarn", "name": "the ball of yarn", "pivot": yarn_pivot, "base": o + Vector3(5.5, 0, 7.8), "stand": o + Vector3(5.5, 0, 6.6), "toppled": false, "anim_t": 1.0, "home_rot": yarn_pivot.rotation, "topple_rot": Vector3(0, 0, 2.4), "bubble": "The yarn! 🧶", "cue": "thud"})
	distract_props.append({"id": "sillplant", "name": "the little plant", "pivot": sill_pivot, "base": o + Vector3(-1.7, 0, -9.3), "stand": o + Vector3(-1.7, 0, -8.2), "toppled": false, "anim_t": 1.0, "home_rot": sill_pivot.rotation, "topple_rot": Vector3(0, 0, -1.3), "bubble": "Not the windowsill plant! 🌿", "cue": "clatter"})
	distract_props.append({"id": "wastebasket", "name": "the wastebasket", "pivot": basket_pivot, "base": o + Vector3(11.6, 0, -8.7), "stand": o + Vector3(10.4, 0, -8.1), "toppled": false, "anim_t": 1.0, "home_rot": basket_pivot.rotation, "topple_rot": Vector3(0, 0, 1.6), "bubble": "The bin! 🗑️", "cue": "crash"})
	distract_props.append({"id": "coatstand", "name": "the coat stand", "pivot": coatstand_pivot, "base": o + Vector3(12.7, 0, 8.7), "stand": o + Vector3(11.5, 0, 7.7), "toppled": false, "anim_t": 1.0, "home_rot": coatstand_pivot.rotation, "topple_rot": Vector3(-1.25, 0, 0), "bubble": "The coat stand! 🧥", "cue": "crash"})
	distract_props.append({"id": "stool", "name": "the stool", "pivot": stool_pivot, "base": o + Vector3(10.7, 0, -5.8), "stand": o + Vector3(9.7, 0, -4.9), "toppled": false, "anim_t": 1.0, "home_rot": stool_pivot.rotation, "topple_rot": Vector3(0, 0, -1.5), "bubble": "The stool! 🪑", "cue": "crash"})
	distract_props.append({"id": "wateringcan", "name": "the watering can", "pivot": can_pivot, "base": o + Vector3(-9.7, 0, -4.9), "stand": o + Vector3(-8.6, 0, -4.1), "toppled": false, "anim_t": 1.0, "home_rot": can_pivot.rotation, "topple_rot": Vector3(0, 0, -1.5), "bubble": "The watering can! 🌻", "cue": "clatter"})


# ---------------------------------------------------------------- actors/camera


# ---------------------------------------------------------------- escape room (3D interior at x≈200)
func _build_intake_card(room: Node3D, o: Vector3) -> void:
	# v1.0.22 INTAKE CARD (Michael's street clue, 2026-11-19): a
	# paper card pinned on the front of ZANDER'S cage in the ward,
	# like the info cards on the other kennels. It names the street
	# he was picked up on (see street_name_at / on_cat_taken). It is
	# a physical card in the room and nothing more — no prompt, no
	# popup, never surfaced anywhere else: the player learns the
	# street only by walking up to the cage and reading it.
	# The cage stands centred at o + (0, 0, 8.55) with its gate on
	# the north front (see opening_cutscene._ensure_cage); the card
	# sits on the fixed mesh panel east of the gate.
	var card := _box(room, o + Vector3(0.86, 0.74, 8.55 - 1.16), Vector3(0.56, 0.4, 0.015), Color(0.96, 0.94, 0.88))
	card.name = "IntakeCard"
	var pin := _box(room, o + Vector3(0.86, 0.9, 8.55 - 1.17), Vector3(0.05, 0.05, 0.02), Color(0.75, 0.2, 0.2))
	pin.name = "IntakeCardPin"
	intake_card_label = Label3D.new()
	intake_card_label.name = "IntakeCardText"
	intake_card_label.font_size = 64
	intake_card_label.pixel_size = 0.0016
	intake_card_label.modulate = Color(0.16, 0.14, 0.12)
	intake_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intake_card_label.position = o + Vector3(0.86, 0.76, 8.55 - 1.175)
	intake_card_label.rotation_degrees = Vector3(0, 180, 0) # face the room, like the POUND sign
	room.add_child(intake_card_label)
	_refresh_intake_card()

func _diorama_house(parent: Node, pos: Vector3, yaw_deg: float, wall_c: Color, roof_c: Color) -> void:
	# A plain house front for the escape-room diorama (see
	# _build_escape_exterior): town materials and proportions,
	# lit windows, a gable roof WITH its infill — but registered
	# nowhere (not a game house: no address, no win check).
	var g := Node3D.new()
	g.name = "DioramaHouse"
	g.position = pos
	g.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(g)
	var found := _box(g, Vector3(0, 0.15, 0), Vector3(8.6, 0.3, 7.6), Color.WHITE)
	found.material_override = _mat_tex(TEX_BRICK, Color(0.85, 0.8, 0.78), Vector3(5, 1, 1))
	var walls := _box(g, Vector3(0, 2.0, 0), Vector3(8.2, 3.7, 7.2), Color.WHITE, true)
	walls.material_override = _mat_tex(TEX_SIDING, wall_c, Vector3(5, 2, 1))
	var eave_d: float = 3.85
	var slab_y_d: float = eave_d + 0.5 + 5.0 * 0.03
	for s in [-1.0, 1.0]:
		var slab := _box(g, Vector3(s * 8.2 * 0.25, slab_y_d, 0), Vector3(8.2 * 0.66, 0.22, 8.2), Color.WHITE)
		slab.material_override = _mat_tex(TEX_ROOF, roof_c.lightened(0.25), Vector3(3, 5, 1))
		slab.rotation_degrees = Vector3(0, 0, s * -35.0)
	var prism := PrismMesh.new()
	prism.left_to_right = 0.5
	prism.size = Vector3(5.66, 2.06, 7.16)
	var gable := MeshInstance3D.new()
	gable.mesh = prism
	gable.position = Vector3(0, eave_d + 0.97, 0)
	gable.material_override = walls.material_override
	g.add_child(gable)
	_box(g, Vector3(0, 1.35, 3.68), Vector3(1.3, 2.7, 0.18), Color(0.45, 0.3, 0.17)) # door, street face
	_glass(g, Vector3(-2.4, 2.0, 3.64), Vector3(1.4, 1.3, 0.08), Color(0.98, 0.87, 0.58), 0.42)
	_glass(g, Vector3(2.4, 2.0, 3.64), Vector3(1.4, 1.3, 0.08), Color(0.98, 0.87, 0.58), 0.42)

func _build_escape_exterior() -> void:
	# v1.0.25 (Michael: "the door opens onto black — I want to
	# SEE THE STREET"): both escape rooms share the slot at
	# escape_origin, hundreds of metres east of the town with
	# NOTHING outside their walls — so the open back door, the
	# window and the pet door all framed empty void, which at
	# dusk renders as a black rectangle in the doorway. The
	# rooms stay in their slot (the whole escape system is keyed
	# to it), so the street comes to the rooms: a permanent
	# exterior diorama around the north and east sides — lawn,
	# sidewalks, a road bend, house fronts, lamps, a parked car
	# — real geometry lit by the same dusk sky as the town.
	# Walking out still crosses the same thresholds onto it,
	# and the escape completes exactly as before.
	var o: Vector3 = escape_origin
	var ext := Node3D.new()
	ext.name = "EscapeExterior"
	add_child(ext)
	# Lawn apron (solid: the cat steps out onto it in the steps
	# before the crossing check fires).
	var lawn := _box(ext, o + Vector3(6, -0.06, -14), Vector3(64, 0.12, 62), Color.WHITE, true)
	lawn.material_override = _mat_tex(TEX_GRASS, Color(0.75, 0.85, 0.62), Vector3(16, 16, 1))
	# Sidewalks along the room's north and east walls.
	var walk_n := _box(ext, o + Vector3(1, 0.012, -11.8), Vector3(36, 0.05, 3.2), Color.WHITE)
	walk_n.material_override = _mat_tex(TEX_SIDEWALK, Color(0.95, 0.93, 0.88), Vector3(10, 1, 1))
	var walk_e := _box(ext, o + Vector3(15.8, 0.012, 0), Vector3(3.2, 0.05, 26), Color.WHITE)
	walk_e.material_override = _mat_tex(TEX_SIDEWALK, Color(0.95, 0.93, 0.88), Vector3(1, 8, 1))
	# The road: along the north side, bending down the east side.
	var road_n := _box(ext, o + Vector3(4, 0.006, -23.5), Vector3(72, 0.04, 7.6), Color.WHITE)
	road_n.material_override = _mat_tex(TEX_ASPHALT, Color(0.9, 0.9, 0.92), Vector3(14, 2, 1))
	var road_e := _box(ext, o + Vector3(23.5, 0.006, -4), Vector3(7.6, 0.04, 46), Color.WHITE)
	road_e.material_override = _mat_tex(TEX_ASPHALT, Color(0.9, 0.9, 0.92), Vector3(2, 10, 1))
	# House fronts across the road, street faces toward the room.
	_diorama_house(ext, o + Vector3(-12, 0, -33.5), 0.0, Color(0.97, 0.92, 0.78), Color(0.72, 0.33, 0.28))
	_diorama_house(ext, o + Vector3(2, 0, -33.5), 0.0, Color(0.62, 0.72, 0.55), Color(0.33, 0.47, 0.72))
	_diorama_house(ext, o + Vector3(16, 0, -33.5), 0.0, Color(0.9, 0.7, 0.66), Color(0.42, 0.6, 0.38))
	_diorama_house(ext, o + Vector3(33.5, 0, 4), -90.0, Color(0.55, 0.65, 0.78), Color(0.5, 0.35, 0.55))
	# A parked Meshy car on the north road, street lamps, pines.
	_build_car(ext, o + Vector3(-4, 0, -21.6), Color(0.7, 0.75, 0.8), true, "compact", true)
	parked_car_spots.append(o + Vector3(-4, 0, -21.6)) # v1.0.27: static car (the flag above only skips the census) — the tree audit keeps canopies off it
	_fill_lamp(ext, o + Vector3(-6, 0, -18.6))
	_fill_lamp(ext, o + Vector3(18.6, 0, -6))
	_build_pine(ext, o + Vector3(-16, 0, -14), 1.0)
	_build_pine(ext, o + Vector3(20, 0, -16), 1.15)
	_build_pine(ext, o + Vector3(-18, 0, 2), 0.9)

func _build_escape_room() -> void:
	var room := Node3D.new()
	room.name = "EscapeRoom"
	add_child(room)
	shelter_room_node = room
	var o: Vector3 = escape_origin
	# --- Floor: pale institutional tile + a plain washable mat ---
	# SHELTER REDESIGN (2026-11-18, Michael: "the pound is exactly
	# the same as everyone's house… make it a regular animal
	# shelter"): the wood planks and the patterned rug are gone.
	# The mat keeps the rug's exact footprint — a mid-game capture
	# still lands the cat "on the rug" at its south edge.
	var floor_mi := _box(room, o + Vector3(0, -0.1, 0), Vector3(28, 0.3, 20), Color.WHITE)
	# POUND FIX: warm tint on the concrete — under the ceiling the
	# room is lit by its own lights plus the dusk sky's ambient,
	# which dragged the blue-grey slab texture to a saturated
	# blue. The warm tint brings it back to the photo's concrete.
	floor_mi.material_override = _mat_tex(TEX_SIDEWALK, Color(1.0, 0.93, 0.83), Vector3(9, 7, 1))
	var rug := _box(room, o + Vector3(0, 0.06, 3), Vector3(9, 0.06, 6), Color.WHITE)
	rug.material_override = _mat(Color(0.63, 0.59, 0.51), 0.95) # POUND FIX: lightened + warmed (see floor note above)
	_build_intake_card(room, o)
	for fx in range(-4, 5):
		_box(room, o + Vector3(float(fx), 0.07, 6.25), Vector3(0.09, 0.03, 0.5), Color(0.45, 0.48, 0.52))
		_box(room, o + Vector3(float(fx), 0.07, -0.25), Vector3(0.09, 0.03, 0.5), Color(0.45, 0.48, 0.52))
	# --- Walls: clinical shelter paint — white above, a beige
	# tile wainscot band below, like Michael's reference photo
	# (the wallpaper is gone with the house) ---
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
	wall_s.material_override = _mat(Color(0.94, 0.96, 0.94), 0.94)
	var wains_s := _box(room, o + Vector3(0, 0.55, 9.6), Vector3(28, 1.1, 0.18), Color.WHITE)
	wains_s.material_override = _mat(Color(0.74, 0.68, 0.58), 0.9)
	var wall_w := _box(room, o + Vector3(-14, 2, 0), Vector3(0.5, 4, 20), Color.WHITE, true)
	wall_w.material_override = _mat(Color(0.94, 0.96, 0.94), 0.94)
	var wains_w := _box(room, o + Vector3(-13.72, 0.55, 0), Vector3(0.18, 1.1, 20), Color.WHITE)
	wains_w.material_override = _mat(Color(0.74, 0.68, 0.58), 0.9)
	# North wall (z = -10): segments are [x-centre, width, y-centre, height].
	# Window gap x -2.9..2.9, y 0.72..3.68 — pet-door gap x 4.85..7.15, y 0..1.58.
	for seg in [[-8.45, 11.1, 2.0, 4.0], [3.875, 1.95, 2.0, 4.0], [10.575, 6.85, 2.0, 4.0], [0.0, 5.8, 0.36, 0.72], [0.0, 5.8, 3.84, 0.32], [6.0, 2.3, 2.79, 2.42]]:
		var nseg := _box(room, o + Vector3(float(seg[0]), float(seg[2]), -10), Vector3(float(seg[1]), float(seg[3]), 0.5), Color.WHITE, true)
		nseg.material_override = _mat(Color(0.94, 0.96, 0.94), 0.94)
	# East wall (x = 14): segments are [z-centre, length, y-centre, height].
	# Back-door doorway gap z 2.28..4.52, y 0..3.02 (plugged by the door).
	for seg2 in [[-3.86, 12.28, 2.0, 4.0], [7.26, 5.48, 2.0, 4.0], [3.4, 2.24, 3.51, 0.98]]:
		var eseg := _box(room, o + Vector3(14, float(seg2[2]), float(seg2[0])), Vector3(0.5, float(seg2[3]), float(seg2[1])), Color.WHITE, true)
		eseg.material_override = _mat(Color(0.94, 0.96, 0.94), 0.94)
	# Wainscot: north in two pieces (gap at the pet door so the cat
	# doesn't clip through it walking out), east likewise at the door.
	for wseg in [[-4.6, 18.8], [10.6, 6.8]]:
		var wn := _box(room, o + Vector3(float(wseg[0]), 0.55, -9.6), Vector3(float(wseg[1]), 1.1, 0.18), Color.WHITE)
		wn.material_override = _mat(Color(0.74, 0.68, 0.58), 0.9)
	for wseg2 in [[-3.86, 12.28], [7.26, 5.48]]:
		var we := _box(room, o + Vector3(13.72, 0.55, float(wseg2[0])), Vector3(0.18, 1.1, float(wseg2[1])), Color.WHITE)
		we.material_override = _mat(Color(0.74, 0.68, 0.58), 0.9)
	# Invisible plugs for the two north gaps (toggled by _open_exit /
	# _reset_escape_props). The shape child is named "CS" for toggling.
	window_blocker = _make_blocker(room, o + Vector3(0, 2.2, -10), Vector3(5.8, 2.96, 0.5))
	petdoor_blocker = _make_blocker(room, o + Vector3(6, 0.79, -10), Vector3(2.3, 1.58, 0.5))
	# POUND FIX (2026-11-18): the room had NO ceiling — the dusk
	# sun poured straight in over the 4 m walls, washing the whole
	# ward pink and leaving evening sky over every wall top, which
	# is most of why the shipped pound read as a house interior in
	# play. Michael's reference photo is a ROOFED ward lit by its
	# own ceiling lights. A shallow upper band seals the walls and
	# a plain slab caps the room, so the interior lights below do
	# the lighting at any hour. The slab collides ONLY so the
	# follow camera's pull-in ray stops beneath it at full pitch;
	# nothing in the room ever reaches it.
	for band in [[0, 10], [0, -10]]:
		var wb := _box(room, o + Vector3(float(band[0]), 4.32, float(band[1])), Vector3(28.5, 0.64, 0.5), Color.WHITE)
		wb.material_override = _mat(Color(0.94, 0.96, 0.94), 0.94)
	for band2 in [[-14], [14]]:
		var wb2 := _box(room, o + Vector3(float(band2[0]), 4.32, 0), Vector3(0.5, 0.64, 20.5), Color.WHITE)
		wb2.material_override = _mat(Color(0.94, 0.96, 0.94), 0.94)
	var ceil := _box(room, o + Vector3(0, 4.72, 0), Vector3(28.5, 0.25, 20.5), Color.WHITE, true)
	ceil.material_override = _mat(Color(0.95, 0.95, 0.94), 0.95)
	# Ceiling beams, raised to sit just under the new slab.
	for bx in [-9.0, 0.0, 9.0]:
		var beam := _box(room, o + Vector3(bx, 4.48, 0), Vector3(0.5, 0.22, 20), Color.WHITE)
		beam.material_override = _mat(Color(0.93, 0.93, 0.92), 0.9)
	room_title_label = _label3d(room, "🐾 ANIMAL SHELTER — find a way out!", o + Vector3(0, 3.4, -9.4), 64, Color(0.15, 0.33, 0.3))
	# Interior lighting: with the sun shut out, the ward's own
	# ceiling lights carry the room (cooler and plainer than the
	# old house warmth — shelter light). Two pendants now: one
	# over the room's middle, one over the kennel-row end.
	var pendant := OmniLight3D.new()
	pendant.position = o + Vector3(0, 3.2, 1)
	pendant.light_color = Color(1.0, 0.97, 0.9)
	pendant.light_energy = 1.3
	pendant.omni_range = 19.0
	room.add_child(pendant)
	_cyl(room, o + Vector3(0, 4.05, 1), 0.03, 0.03, 1.3, Color(0.3, 0.28, 0.26))
	var pendant2 := OmniLight3D.new()
	pendant2.position = o + Vector3(-8, 3.2, 1)
	pendant2.light_color = Color(1.0, 0.97, 0.9)
	pendant2.light_energy = 0.95
	pendant2.omni_range = 13.0
	room.add_child(pendant2)
	_cyl(room, o + Vector3(-8, 4.05, 1), 0.03, 0.03, 1.3, Color(0.3, 0.28, 0.26))
	# Flat ceiling light panels, mounted under the beams
	# (institutional — the pendant's warm glass shade is gone
	# with the house).
	for lpx in [0.0, -8.0]:
		var lpanel := _box(room, o + Vector3(lpx, 4.36, 1), Vector3(2.6, 0.07, 1.1), Color.WHITE)
		lpanel.material_override = _mat(Color(0.97, 0.98, 1.0), 0.6, 0.55)
	var lamp_light := OmniLight3D.new()
	lamp_light.position = o + Vector3(12, 2.6, -1.5)
	lamp_light.light_color = Color(1.0, 0.97, 0.9)
	lamp_light.light_energy = 0.7
	lamp_light.omni_range = 10.5
	room.add_child(lamp_light)
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ SUPPLY RACK (was the bookcase) ============
	# SHELTER WARD: the wooden bookcase is gone — open steel
	# racking stands in its place (storage bins, kibble, folded
	# towels). The shelf boards keep their exact heights and the
	# towel-stack prop pivot is untouched, so every reach and
	# reset is unchanged.
	var shelf_pos := o + Vector3(-11, 0, -8)
	# POUND FIX: the unit's solid back and side panels made it a
	# closed cabinet — the "bookshelf" silhouette Michael still
	# saw in play. Open racking now: four corner posts, two back
	# rails, no back panel. An invisible blocker keeps the old
	# panel's exact footprint, so the cat's collision is unchanged.
	_make_blocker(room, shelf_pos + Vector3(0, 1.5, -0.25), Vector3(5.4, 3.2, 0.5))
	var rack_steel := _mat(Color(0.6, 0.63, 0.67), 0.5)
	rack_steel.metallic = 0.5
	for px3 in [-2.55, 2.55]:
		for pz3 in [-0.3, 0.6]:
			var post := _box(room, shelf_pos + Vector3(px3, 1.5, pz3), Vector3(0.1, 3.2, 0.1), Color.WHITE)
			post.material_override = rack_steel
	for ry2 in [1.05, 2.2]:
		var rail := _box(room, shelf_pos + Vector3(0, ry2, -0.3), Vector3(5.2, 0.09, 0.07), Color.WHITE)
		rail.material_override = rack_steel
	var top_board := _box(room, shelf_pos + Vector3(0, 3.18, 0.15), Vector3(5.5, 0.24, 1.0), Color.WHITE)
	top_board.material_override = _mat(Color(0.6, 0.63, 0.67), 0.55)
	var tin_cols: Array = [Color(0.75, 0.55, 0.3), Color(0.45, 0.6, 0.7), Color(0.6, 0.7, 0.5), Color(0.8, 0.7, 0.45)]
	var stack_pivot: Node3D = null # v1.5: the bottom shelf's towel stack is a knock-over prop (built into this pivot, registered later)
	for shelf_i in range(3):
		var sy: float = 0.55 + float(shelf_i) * 0.95
		var board := _box(room, shelf_pos + Vector3(0, sy - 0.28, 0.15), Vector3(5.2, 0.12, 0.9), Color.WHITE)
		board.material_override = _mat(Color(0.62, 0.65, 0.69), 0.5)
		# Shelf dressing — POUND FIX: lidded storage bins and
		# kibble sacks, the stores a ward actually keeps. (The old
		# unbroken rows of upright tins read as books on a bookcase
		# from across the room — Michael's "still the bookshelf".
		# A few tins stay, grouped at one end of the top shelf
		# like an opened case of food.)
		var bin_cols: Array = [Color(0.55, 0.62, 0.7), Color(0.62, 0.66, 0.6), Color(0.5, 0.55, 0.62)]
		for bx2 in range(2):
			var bcol: Color = bin_cols[(bx2 + shelf_i) % bin_cols.size()]
			var binx: float = -2.0 + float(bx2) * 1.28 + float(shelf_i % 2) * 0.3
			_box(room, shelf_pos + Vector3(binx, sy + 0.13, 0.28), Vector3(1.06, 0.5, 0.52), bcol)
			_box(room, shelf_pos + Vector3(binx, sy + 0.41, 0.28), Vector3(1.12, 0.07, 0.56), bcol.darkened(0.18))
		if shelf_i == 0:
			_box(room, shelf_pos + Vector3(0.55, sy + 0.2, 0.3), Vector3(0.5, 0.66, 0.42), Color(0.85, 0.62, 0.3)) # kibble sack
			_box(room, shelf_pos + Vector3(0.55, sy + 0.56, 0.3), Vector3(0.44, 0.08, 0.36), Color(0.72, 0.5, 0.24)) # its folded top
		if shelf_i == 1:
			_box(room, shelf_pos + Vector3(0.5, sy + 0.13, 0.3), Vector3(0.62, 0.5, 0.5), Color(0.55, 0.62, 0.7)) # kibble bin
			_box(room, shelf_pos + Vector3(0.5, sy + 0.42, 0.3), Vector3(0.66, 0.08, 0.54), Color(0.42, 0.48, 0.56)) # bin lid
		if shelf_i == 2:
			for tn in range(3):
				_cyl(room, shelf_pos + Vector3(1.74 + float(tn) * 0.34, sy + 0.05, 0.3), 0.14, 0.14, 0.34, tin_cols[tn % tin_cols.size()])
		# a folded stack at the end of two shelves — the bottom
		# shelf's stack sits in its own pivot so the cat can knock
		# it over (v1.5 distraction prop, registered below).
		if shelf_i < 2:
			if shelf_i == 0:
				stack_pivot = Node3D.new()
				stack_pivot.position = shelf_pos + Vector3(2.0, sy - 0.045, 0.3)
				room.add_child(stack_pivot)
				for st in range(3):
					_box(stack_pivot, Vector3(0, 0.065 + float(st) * 0.15, 0), Vector3(0.62, 0.13, 0.48), [Color(0.92, 0.93, 0.95), Color(0.75, 0.83, 0.9), Color(0.88, 0.9, 0.85)][st])
			else:
				for st in range(3):
					_box(room, shelf_pos + Vector3(2.0, sy + 0.02 + float(st) * 0.15, 0.3), Vector3(0.62, 0.13, 0.48), [Color(0.9, 0.88, 0.8), Color(0.8, 0.85, 0.9), Color(0.93, 0.93, 0.95)][st])
	# The intake binder: BIG, red, white-labelled — the ward's
	# paperwork, LYING FLAT on the top shelf (book_node keeps its
	# name and home so the reset code is untouched). POUND FIX:
	# standing upright it was the most book-like object in the
	# room — a big red book on a shelf, readable across the ward.
	book_node = _box(room, shelf_pos + Vector3(0.6, 2.3, 0.3), Vector3(0.66, 0.14, 0.5), Color(0.88, 0.16, 0.16))
	book_home_pos = book_node.position
	_box(book_node, Vector3(0, 0.08, 0), Vector3(0.44, 0.02, 0.3), Color(0.95, 0.94, 0.9))
	# Storage bins on top of the unit (the plant and the framed
	# photo went with the house).
	_box(room, shelf_pos + Vector3(-1.9, 3.55, 0.15), Vector3(1.1, 0.5, 0.65), Color(0.55, 0.62, 0.7))
	_box(room, shelf_pos + Vector3(-0.6, 3.55, 0.15), Vector3(1.1, 0.5, 0.65), Color(0.65, 0.68, 0.6))
	_box(room, shelf_pos + Vector3(1.9, 3.5, 0.12), Vector3(0.95, 0.42, 0.6), Color(0.7, 0.66, 0.55))
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ STAFF BENCH + WORK TROLLEY (was the sofa set) ==
	# SHELTER WARD: the sofa, coffee table and armchair are GONE.
	# A steel staff bench holds the blanket-stack prop; a stainless
	# work trolley holds the water bowl and the intake clipboard;
	# a slim stand by the work counter holds the spray bottle.
	# Every prop pivot keeps its exact position.
	var bench_top := _box(room, o + Vector3(-2.3, 0.99, 4.3), Vector3(3.0, 0.1, 1.7), Color.WHITE, true)
	bench_top.material_override = _mat(Color(0.62, 0.65, 0.69), 0.5)
	for bx3 in [-1.35, 1.35]:
		for bz3 in [-0.7, 0.7]:
			_box(room, o + Vector3(-2.3 + bx3, 0.47, 4.3 + bz3), Vector3(0.09, 0.95, 0.09), Color(0.45, 0.48, 0.52))
	_box(room, o + Vector3(-2.3, 0.18, 4.3), Vector3(2.7, 0.06, 1.4), Color(0.55, 0.58, 0.62)) # bench lower shelf
	_box(room, o + Vector3(-3.1, 0.32, 4.3), Vector3(0.8, 0.24, 0.9), Color(0.6, 0.66, 0.72)) # a crate under the bench
	var pillow_pivot := Node3D.new() # v1.5: the blanket stack is a knock-over prop (registered below)
	pillow_pivot.position = o + Vector3(-2.3, 1.45, 4.05)
	room.add_child(pillow_pivot)
	for bl in range(3):
		var blanket := _box(pillow_pivot, Vector3(0, -0.34 + float(bl) * 0.17, 0), Vector3(0.9, 0.16, 0.62), [Color(0.75, 0.83, 0.9), Color(0.92, 0.9, 0.82), Color(0.7, 0.8, 0.68)][bl])
		blanket.rotation_degrees = Vector3(0, float(bl) * 4.0 - 4.0, 0)
	# Stainless work trolley on the mat: water bowl + clipboard.
	var trolley_top := _box(room, o + Vector3(0.9, 0.455, 1.35), Vector3(2.6, 0.07, 1.5), Color.WHITE)
	trolley_top.material_override = _mat(Color(0.7, 0.72, 0.75), 0.35)
	_box(room, o + Vector3(0.9, 0.14, 1.35), Vector3(2.3, 0.05, 1.2), Color(0.6, 0.62, 0.66)) # trolley lower shelf
	for tx2 in [-1.15, 1.15]:
		for tz2 in [-0.6, 0.6]:
			_cyl(room, o + Vector3(0.9 + tx2, 0.24, 1.35 + tz2), 0.04, 0.04, 0.44, Color(0.45, 0.48, 0.52))
			_sphere(room, o + Vector3(0.9 + tx2, 0.03, 1.35 + tz2), Vector3(0.07, 0.07, 0.07), Color(0.3, 0.3, 0.33)) # casters
	_box(room, o + Vector3(0.15, 0.24, 1.5), Vector3(0.5, 0.18, 0.7), Color(0.55, 0.62, 0.7)) # a supply box on the lower shelf
	var mug_pivot := Node3D.new() # v1.5: the water bowl is a knock-over prop (registered below)
	mug_pivot.position = o + Vector3(0.7, 0.5, 1.4)
	room.add_child(mug_pivot)
	_cyl(mug_pivot, Vector3(0, 0.07, 0), 0.17, 0.11, 0.14, Color(0.62, 0.65, 0.7)) # steel water bowl
	_cyl(mug_pivot, Vector3(0, 0.135, 0), 0.145, 0.145, 0.02, Color(0.4, 0.6, 0.8)) # the water in it
	# Slim stand by the work counter, holding the spray bottle.
	_cyl(room, o + Vector3(12.3, 0.04, 4.6), 0.3, 0.34, 0.08, Color(0.4, 0.42, 0.46))
	_cyl(room, o + Vector3(12.3, 0.5, 4.6), 0.045, 0.045, 0.92, Color(0.5, 0.52, 0.56))
	_box(room, o + Vector3(12.3, 0.98, 4.6), Vector3(0.55, 0.04, 0.55), Color(0.58, 0.6, 0.64))
	var tlamp_pivot := Node3D.new() # v1.5: the spray bottle is a knock-over prop (registered below)
	tlamp_pivot.position = o + Vector3(12.3, 1.0, 4.6)
	room.add_child(tlamp_pivot)
	_cyl(tlamp_pivot, Vector3(0, 0.15, 0), 0.085, 0.095, 0.3, Color(0.85, 0.87, 0.9)) # spray bottle body
	_cyl(tlamp_pivot, Vector3(0, 0.34, 0), 0.03, 0.03, 0.08, Color(0.3, 0.5, 0.75))
	_box(tlamp_pivot, Vector3(0.05, 0.4, 0), Vector3(0.2, 0.06, 0.07), Color(0.3, 0.5, 0.75)) # trigger head
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ WINDOW — shelter security opening =============
	# Steel frame + sill, two chain-link mesh panels over a plain
	# bright "outside" glow, and a REAL brass latch: a base plate
	# + a lever on a pivot that the player flips from the escape
	# panel (v1.1). The lower panel (sash_node) physically slides
	# up when the window is pushed open. (v0.6 built this as a
	# house window with glass sashes over a painted landscape —
	# see the POUND FIX note at win_pos below.)
	var win_pos := o + Vector3(0, 2.2, -9.6)
	# POUND FIX (2026-11-18): the old window was a HOUSE window —
	# glass sashes and a roller blind over a painted landscape
	# (blue sky, sun, green hills), dead centre of the player's
	# view from the cage. It is a shelter security opening now:
	# chain-link mesh in a steel frame over plain overexposed
	# daylight — the ward's own visual language, like the photo's
	# bright mesh fronts. The lower panel still slides up
	# (sash_node) and the brass latch works exactly as before.
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.84, 0.9, 0.96)
	var glow_panel := _box(room, win_pos + Vector3(0, 0, -0.22), Vector3(5.2, 2.9, 0.06), Color.WHITE)
	glow_panel.material_override = glow_mat
	var win_steel := _mat(Color(0.52, 0.56, 0.6), 0.45)
	win_steel.metallic = 0.55
	# Outer frame (4 chunky steel boards) + sloped sill + apron
	for fpart in [[Vector3(0, 1.44, 0.02), Vector3(5.5, 0.34, 0.34)], [Vector3(0, -1.44, 0.02), Vector3(5.5, 0.34, 0.34)], [Vector3(-2.62, 0, 0.02), Vector3(0.34, 3.2, 0.34)], [Vector3(2.62, 0, 0.02), Vector3(0.34, 3.2, 0.34)]]:
		var fb := _box(room, win_pos + (fpart[0] as Vector3), fpart[1] as Vector3, Color.WHITE)
		fb.material_override = win_steel
	var sill := _box(room, win_pos + Vector3(0, -1.66, 0.22), Vector3(5.9, 0.16, 0.66), Color.WHITE)
	sill.material_override = win_steel
	sill.rotation_degrees = Vector3(7, 0, 0)
	var apron := _box(room, win_pos + Vector3(0, -1.78, 0.05), Vector3(5.5, 0.14, 0.2), Color.WHITE)
	apron.material_override = win_steel
	# Upper panel (fixed): chain-link mesh + steel cross bars
	_mesh_panel(room, win_pos + Vector3(0, 0.73, 0), Vector2(4.85, 1.3))
	var up_bar_v := _box(room, win_pos + Vector3(0, 0.73, 0.05), Vector3(0.09, 1.3, 0.06), Color.WHITE)
	up_bar_v.material_override = win_steel
	var up_bar_h := _box(room, win_pos + Vector3(0, 0.73, 0.05), Vector3(4.85, 0.09, 0.06), Color.WHITE)
	up_bar_h.material_override = win_steel
	var up_rail := _box(room, win_pos + Vector3(0, 1.36, 0.03), Vector3(4.95, 0.15, 0.1), Color.WHITE)
	up_rail.material_override = win_steel
	# Lower sash (sash_node): slides UP when pushed open
	sash_node = Node3D.new()
	sash_node.position = win_pos + Vector3(0, -0.7, 0.07)
	room.add_child(sash_node)
	sash_base_y = sash_node.position.y
	_mesh_panel(sash_node, Vector3(0, 0, 0), Vector2(4.85, 1.28))
	for lpart in [[Vector3(0, 0.66, 0.02), Vector3(4.95, 0.17, 0.1)], [Vector3(0, -0.66, 0.02), Vector3(4.95, 0.15, 0.1)], [Vector3(-2.44, 0, 0.02), Vector3(0.15, 1.4, 0.1)], [Vector3(2.44, 0, 0.02), Vector3(0.15, 1.4, 0.1)], [Vector3(0, 0, 0.05), Vector3(0.09, 1.28, 0.06)], [Vector3(0, 0, 0.05), Vector3(4.85, 0.09, 0.06)]]:
		var lb := _box(sash_node, lpart[0] as Vector3, lpart[1] as Vector3, Color.WHITE)
		lb.material_override = win_steel
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
	# POUND FIX: the roller blind is gone (a house fitting on a
	# security opening). The treat jar stays on the steel sill.
	var sill_pivot := Node3D.new() # v1.5: the treat jar is a knock-over prop (registered below)
	sill_pivot.position = win_pos + Vector3(-1.7, -1.63, 0.3)
	room.add_child(sill_pivot)
	_cyl(sill_pivot, Vector3(0, 0.15, 0), 0.15, 0.13, 0.3, Color(0.8, 0.6, 0.35)) # treat jar
	_cyl(sill_pivot, Vector3(0, 0.32, 0), 0.16, 0.16, 0.05, Color(0.5, 0.35, 0.2)) # its lid
	for tr in [Vector3(-0.06, 0.24, -0.04), Vector3(0.07, 0.26, 0.05), Vector3(0.0, 0.22, 0.08)]:
		_sphere(sill_pivot, tr, Vector3(0.055, 0.055, 0.055), Color(0.65, 0.45, 0.25)) # treats inside
	_label3d(room, "Window", win_pos + Vector3(0, 1.95, 0), 56, Color(0.2, 0.3, 0.4))
	# Pet door with frame + a REAL swinging FLAP (flap_node pivots at
	# its top edge; pushing swipes swing it open). v1.1: the frame is
	# a real 4-piece border around a dark opening (it was one solid
	# slab with the flap embedded in it), so the flap reads clearly
	# and the cat can be SEEN slipping through in the escape moment.
	# v1.0.25: the pet door's near-black backing panel is GONE
	# too — through the swung flap the street outside shows,
	# not a black rectangle.
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ UTILITY / WASH corner (east wall) ============
	# SHELTER WARD: the kitchen is gone — a wash counter with a
	# deep sink, the wall hose from Michael's photo, open shelves
	# and a tall storage cabinet. The counter keeps its footprint
	# (the treat-bin prop sits on it where it always sat).
	var counter := _box(room, o + Vector3(12.9, 0.95, -4.5), Vector3(1.9, 0.14, 8.5), Color(0.88, 0.85, 0.8), true)
	counter.material_override = _mat(Color(0.72, 0.74, 0.77), 0.35)
	var cabbody := _box(room, o + Vector3(13.1, 0.45, -4.5), Vector3(1.6, 0.85, 8.5), Color.WHITE)
	cabbody.material_override = _mat(Color(0.78, 0.8, 0.82), 0.7)
	for hx in range(4):
		_box(room, o + Vector3(12.25, 0.62, -7.6 + float(hx) * 2.05), Vector3(0.06, 0.08, 0.7), Color(0.4, 0.38, 0.36)) # cabinet handles
	# The wash sink where the stove was: dark basin + a gooseneck tap.
	_box(room, o + Vector3(12.85, 1.03, -7.2), Vector3(1.4, 0.07, 2.0), Color(0.3, 0.32, 0.36))
	_box(room, o + Vector3(12.85, 0.99, -7.2), Vector3(1.15, 0.05, 1.7), Color(0.2, 0.22, 0.26))
	_cyl(room, o + Vector3(13.5, 1.22, -7.2), 0.045, 0.045, 0.4, Color(0.55, 0.57, 0.6))
	var tap_arm := _cyl(room, o + Vector3(13.28, 1.42, -7.2), 0.04, 0.04, 0.45, Color(0.55, 0.57, 0.6))
	tap_arm.rotation_degrees = Vector3(0, 0, 90)
	_cyl(room, o + Vector3(13.06, 1.32, -7.2), 0.035, 0.035, 0.2, Color(0.55, 0.57, 0.6))
	# Tall storage cabinet where the fridge was (food + meds).
	_box(room, o + Vector3(13.2, 1.75, 0.5), Vector3(1.5, 3.5, 2.2), Color(0.8, 0.82, 0.84), true)
	_box(room, o + Vector3(12.42, 2.4, -0.05), Vector3(0.05, 0.7, 0.08), Color(0.45, 0.47, 0.5))
	_box(room, o + Vector3(12.42, 2.4, 1.05), Vector3(0.05, 0.7, 0.08), Color(0.45, 0.47, 0.5))
	_box(room, o + Vector3(12.43, 2.9, 0.5), Vector3(0.04, 0.55, 0.8), Color(0.95, 0.94, 0.9)) # cabinet label card
	# THE HOSE, coiled on the wall — straight from the photo.
	for hi in range(3):
		var loop := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.34
		tm.outer_radius = 0.44
		loop.mesh = tm
		loop.material_override = _mat(Color(0.16, 0.16, 0.18), 0.7)
		loop.position = o + Vector3(13.66, 2.15 - float(hi) * 0.16, -5.4)
		loop.rotation_degrees = Vector3(0, 0, 90)
		room.add_child(loop)
	_cyl(room, o + Vector3(13.7, 2.62, -5.4), 0.05, 0.05, 0.3, Color(0.5, 0.3, 0.15)) # hose tap
	_box(room, o + Vector3(13.6, 1.15, -5.15), Vector3(0.12, 0.5, 0.18), Color(0.2, 0.2, 0.22)) # nozzle hanging
	var fruit_pivot := Node3D.new() # v1.5: the treat bin is a knock-over prop (registered below)
	fruit_pivot.position = o + Vector3(12.8, 1.02, -2.2)
	room.add_child(fruit_pivot)
	_box(fruit_pivot, Vector3(0, 0.16, 0), Vector3(0.56, 0.32, 0.44), Color(0.45, 0.6, 0.62)) # treat bin tub
	_box(fruit_pivot, Vector3(0, 0.35, 0), Vector3(0.6, 0.07, 0.48), Color(0.35, 0.48, 0.5)) # its lid
	# Open steel shelves over the counter (the wall cabinets went
	# with the house): bins, tins and a stack of clean bowls.
	for shy in [2.45, 3.05]:
		_box(room, o + Vector3(13.25, shy, -5.5), Vector3(1.05, 0.06, 5.2), Color(0.62, 0.65, 0.69))
	_box(room, o + Vector3(13.3, 2.62, -7.3), Vector3(0.8, 0.3, 0.9), Color(0.55, 0.62, 0.7))
	_box(room, o + Vector3(13.3, 2.62, -6.2), Vector3(0.8, 0.3, 0.7), Color(0.66, 0.68, 0.6))
	for bi3 in range(3):
		_cyl(room, o + Vector3(13.25, 2.56 + float(bi3) * 0.11, -4.2), 0.2, 0.16, 0.1, Color(0.75, 0.77, 0.8))
	for ji2 in range(3):
		_cyl(room, o + Vector3(13.25, 3.22, -6.8 + float(ji2) * 0.75), 0.13, 0.13, 0.3, [Color(0.85, 0.6, 0.3), Color(0.5, 0.7, 0.45), Color(0.8, 0.45, 0.4)][ji2])
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ Personal touches ============
	# SHELTER REDESIGN: the south-wall fireplace is GONE — a shelter
	# has no fireplace; kennel B of the new south-wall row stands
	# where it was (the row is built at the end of this function).
	# West-wall boards (the picture frames went with the house):
	# an ADOPT board south of the cage bank, a staff whiteboard
	# north of it, and the notice board that can be knocked
	# crooked (the "picture" prop, same pivot as ever).
	_box(room, o + Vector3(-13.68, 2.3, 7.7), Vector3(0.12, 1.7, 1.9), Color(0.45, 0.5, 0.55))
	_box(room, o + Vector3(-13.6, 2.3, 7.7), Vector3(0.08, 1.5, 1.7), Color(0.96, 0.95, 0.9))
	for card_i in range(6):
		_box(room, o + Vector3(-13.54, 2.62 - float(card_i / 3) * 0.62, 7.15 + float(card_i % 3) * 0.55), Vector3(0.05, 0.48, 0.42), [Color(0.9, 0.6, 0.35), Color(0.55, 0.7, 0.85), Color(0.65, 0.8, 0.6), Color(0.85, 0.55, 0.6), Color(0.6, 0.6, 0.8), Color(0.9, 0.8, 0.45)][card_i])
	_label3d(room, "ADOPT ME!", o + Vector3(-13.45, 3.28, 7.7), 44, Color(0.75, 0.3, 0.2)).rotation_degrees = Vector3(0, 90, 0)
	_box(room, o + Vector3(-13.68, 2.4, -5.8), Vector3(0.12, 1.1, 1.6), Color(0.45, 0.5, 0.55))
	_box(room, o + Vector3(-13.6, 2.4, -5.8), Vector3(0.08, 0.95, 1.45), Color(0.97, 0.97, 0.96))
	# POUND FIX: the board's old cross grid read as a small paned
	# window from across the room. Rota lines instead: a red
	# header strip, ruled horizontal lines, two sticky notes —
	# a staff board, not a window.
	_box(room, o + Vector3(-13.54, 2.78, -5.8), Vector3(0.04, 0.09, 1.3), Color(0.75, 0.3, 0.25))
	for gy2 in range(4):
		_box(room, o + Vector3(-13.54, 2.58 - float(gy2) * 0.17, -5.8), Vector3(0.04, 0.03, 1.15), Color(0.6, 0.65, 0.72))
	_box(room, o + Vector3(-13.54, 2.02, -6.25), Vector3(0.04, 0.16, 0.16), Color(0.95, 0.8, 0.4))
	_box(room, o + Vector3(-13.54, 2.02, -5.95), Vector3(0.04, 0.16, 0.16), Color(0.6, 0.75, 0.9))
	var frame_pivot: Node3D = null # v1.5: the notice board can be knocked crooked (registered below)
	frame_pivot = Node3D.new()
	frame_pivot.position = o + Vector3(-13.65, 2.4, 5.5)
	room.add_child(frame_pivot)
	_box(frame_pivot, Vector3(0, 0, 0), Vector3(0.14, 1.0, 1.4), Color(0.45, 0.5, 0.55))
	_box(frame_pivot, Vector3(0.1, 0, 0), Vector3(0.1, 0.8, 1.2), Color(0.96, 0.95, 0.9))
	for card_j in range(4):
		_box(frame_pivot, Vector3(0.16, 0.18 - float(card_j / 2) * 0.38, -0.28 + float(card_j % 2) * 0.55), Vector3(0.04, 0.3, 0.42), [Color(0.95, 0.8, 0.4), Color(0.6, 0.75, 0.9), Color(0.9, 0.6, 0.55), Color(0.65, 0.85, 0.65)][card_j])
	# Wall clock (north wall, east side)
	var clock_face := _cyl(room, o + Vector3(9, 3.0, -9.65), 0.55, 0.55, 0.1, Color(0.97, 0.95, 0.9))
	clock_face.rotation_degrees = Vector3(90, 0, 0)
	var hand1 := _box(room, o + Vector3(9, 3.12, -9.55), Vector3(0.06, 0.4, 0.04), Color(0.15, 0.15, 0.17))
	hand1.rotation_degrees = Vector3(0, 0, 25)
	# Storage bins in the south-west corner (the cat tree went
	# with the house — the residents have the cage bank now).
	_box(room, o + Vector3(-12.6, 0.35, 6.6), Vector3(1.3, 0.7, 1.1), Color(0.55, 0.62, 0.7), true)
	_box(room, o + Vector3(-12.6, 1.05, 6.6), Vector3(1.15, 0.62, 0.95), Color(0.65, 0.68, 0.6))
	_sphere(room, o + Vector3(-11.7, 0.22, 8.65), Vector3(1.0, 0.32, 1.0), Color(0.85, 0.45, 0.5)) # cat bed — SHELTER: inside kennel A now
	_sphere(room, o + Vector3(-11.7, 0.3, 8.65), Vector3(0.78, 0.24, 0.78), Color(0.95, 0.85, 0.7))
	_cyl(room, o + Vector3(-8.6, 0.12, 8.6), 0.32, 0.24, 0.22, Color(0.35, 0.6, 0.8)) # water bowl
	_cyl(room, o + Vector3(-7.8, 0.12, 8.6), 0.32, 0.24, 0.22, Color(0.9, 0.55, 0.3)) # food bowl
	var yarn_pivot := Node3D.new() # v1.5: the yarn ball is a knock-over prop (registered below)
	yarn_pivot.position = o + Vector3(5.5, 0, 7.8)
	room.add_child(yarn_pivot)
	_sphere(yarn_pivot, Vector3(0, 0.28, 0), Vector3(0.3, 0.3, 0.3), Color(0.85, 0.3, 0.35)) # yarn ball
	var yarn_wrap := _box(yarn_pivot, Vector3(0, 0.28, 0), Vector3(0.64, 0.1, 0.64), Color(0.7, 0.22, 0.28))
	yarn_wrap.rotation_degrees = Vector3(20, 30, 10)
	# Stainless WORK COUNTER (the dining set went with the house):
	# the bowl-stack prop stands on it where the vase stood.
	var wcounter := _box(room, o + Vector3(10.4, 0.88, 4.0), Vector3(3.2, 0.08, 1.6), Color.WHITE, true)
	wcounter.material_override = _mat(Color(0.7, 0.72, 0.75), 0.35)
	for cx5 in [-1.4, 1.4]:
		for cz5 in [-0.65, 0.65]:
			_box(room, o + Vector3(10.4 + cx5, 0.42, 4.0 + cz5), Vector3(0.09, 0.84, 0.09), Color(0.45, 0.48, 0.52))
	_box(room, o + Vector3(10.4, 0.2, 4.0), Vector3(2.9, 0.05, 1.3), Color(0.58, 0.6, 0.64)) # counter lower shelf
	_box(room, o + Vector3(9.2, 0.99, 3.6), Vector3(0.9, 0.14, 0.6), Color(0.5, 0.52, 0.56)) # the pet scale
	_cyl(room, o + Vector3(9.2, 1.12, 3.6), 0.11, 0.11, 0.12, Color(0.9, 0.9, 0.88)) # scale dial
	_box(room, o + Vector3(11.6, 0.99, 4.5), Vector3(0.7, 0.14, 0.5), Color(0.88, 0.9, 0.85)) # a folded towel
	# Standing WORK LIGHT by the wash counter + a laundry bin in
	# the north-west corner (the floor lamp and the big house
	# plant went with the house).
	var flamp_pivot := Node3D.new() # v1.5: the work light is a knock-over prop (registered below)
	flamp_pivot.position = o + Vector3(12, 0, -7)
	room.add_child(flamp_pivot)
	_cyl(flamp_pivot, Vector3(0, 0.05, 0), 0.34, 0.38, 0.1, Color(0.32, 0.33, 0.36))
	_cyl(flamp_pivot, Vector3(0, 1.45, 0), 0.05, 0.05, 2.8, Color(0.32, 0.33, 0.36))
	var wl_head := _box(flamp_pivot, Vector3(0, 2.95, 0), Vector3(0.78, 0.3, 0.2), Color(0.25, 0.26, 0.3))
	wl_head.rotation_degrees = Vector3(-18, 0, 0)
	for wl in [-0.19, 0.19]:
		var wl_face := _box(flamp_pivot, Vector3(wl, 2.93, -0.11), Vector3(0.3, 0.2, 0.03), Color.WHITE)
		wl_face.material_override = _mat(Color(1.0, 0.97, 0.88), 0.5, 0.7)
		wl_face.rotation_degrees = Vector3(-18, 0, 0)
	_box(room, o + Vector3(-11, 0.45, -5.5), Vector3(1.05, 0.9, 1.05), Color(0.6, 0.63, 0.67), true) # laundry bin
	_box(room, o + Vector3(-11, 0.93, -5.5), Vector3(1.15, 0.07, 1.15), Color(0.48, 0.5, 0.54)) # bin rim
	_box(room, o + Vector3(-11, 0.86, -5.5), Vector3(0.8, 0.16, 0.8), Color(0.85, 0.87, 0.9)) # towels in it
	# Leash hooks + staff wellingtons by the pet door
	for hx2 in range(3):
		_sphere(room, o + Vector3(3.6 + float(hx2) * 0.7, 2.2, -9.6), Vector3(0.09, 0.09, 0.12), Color(0.5, 0.52, 0.55))
	_box(room, o + Vector3(3.75, 1.6, -9.55), Vector3(0.07, 1.05, 0.05), Color(0.75, 0.3, 0.25)) # a hanging leash
	_box(room, o + Vector3(4.45, 1.66, -9.55), Vector3(0.07, 0.95, 0.05), Color(0.3, 0.45, 0.7)) # another leash
	var shoes_pivot := Node3D.new() # v1.5: the boots by the door are a knock-over prop (registered below)
	shoes_pivot.position = o + Vector3(4.95, 0, -9.2)
	room.add_child(shoes_pivot)
	for shx in [-0.35, 0.35]:
		_box(shoes_pivot, Vector3(shx, 0.09, 0.08), Vector3(0.3, 0.18, 0.66), Color(0.25, 0.35, 0.25)) # boot foot
		_box(shoes_pivot, Vector3(shx, 0.36, -0.12), Vector3(0.28, 0.55, 0.3), Color(0.28, 0.38, 0.28)) # boot shaft


	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ BACK DOOR with SLIDING BOLT (shopkeeper exit) ====
	var bd_pos := o + Vector3(13.62, 0, 3.4)
	# v1.1 fix: the frame is a BORDER (lintel + two jambs), not a
	# solid block — the old solid block filled the doorway and hid
	# both the dark doorway panel and the cat crossing through it.
	_box(room, bd_pos + Vector3(0.05, 3.22, 0), Vector3(0.24, 0.36, 2.3), Color(0.92, 0.9, 0.84)) # frame lintel
	_box(room, bd_pos + Vector3(0.05, 1.65, -1.06), Vector3(0.24, 3.3, 0.18), Color(0.92, 0.9, 0.84)) # frame jamb (north)
	_box(room, bd_pos + Vector3(0.05, 1.65, 1.06), Vector3(0.24, 3.3, 0.18), Color(0.92, 0.9, 0.84)) # frame jamb (south)
	# v1.0.25: NO dark doorway panel here any more. The v1.1
	# near-black plug filled the open doorway with fake void —
	# exactly the "door opens onto blackness" Michael reported.
	# The escape exterior (street, houses, road) stands outside
	# now, and the open door reveals IT.
	# v1.1: the door panel hangs on a hinge pivot (backdoor_pivot) so
	# the escape animation can swing it open; the bolt rides the door,
	# the keeper stays on the frame — like a real sliding bolt.
	backdoor_pivot = Node3D.new()
	backdoor_pivot.position = bd_pos + Vector3(-0.08, 0, -0.975)
	room.add_child(backdoor_pivot)
	var bd_door := _box(backdoor_pivot, Vector3(0, 1.5, 0.975), Vector3(0.14, 3.0, 1.95), Color.WHITE, true)
	bd_door.material_override = _mat(Color(0.62, 0.68, 0.64), 0.6) # SHELTER WARD: painted steel, like the photo's end door
	_box(bd_door, Vector3(-0.09, 0.6, 0), Vector3(0.05, 1.0, 1.3), Color(0.52, 0.58, 0.54)) # door panel inset
	_box(bd_door, Vector3(-0.09, -0.75, 0), Vector3(0.05, 0.9, 1.3), Color(0.52, 0.58, 0.54))
	_sphere(bd_door, Vector3(-0.14, -0.15, 0.78), Vector3(0.09, 0.09, 0.09), Color(0.8, 0.65, 0.3)) # knob
	_box(room, bd_pos + Vector3(-0.2, 1.95, -0.82), Vector3(0.08, 0.22, 0.2), Color(0.4, 0.32, 0.16)) # bolt keeper
	_box(room, bd_pos + Vector3(-0.2, 1.95, -0.18), Vector3(0.08, 0.22, 0.34), Color(0.4, 0.32, 0.16)) # bolt base plate
	bolt_node = _box(bd_door, Vector3(-0.16, 0.45, -0.42), Vector3(0.09, 0.11, 0.66), Color(0.78, 0.62, 0.26))
	bolt_node.material_override = _mat(Color(0.78, 0.62, 0.26), 0.3)
	_sphere(bolt_node, Vector3(-0.06, 0, 0.22), Vector3(0.08, 0.08, 0.08), Color(0.85, 0.68, 0.3)) # bolt thumb knob
	bolt_base_z = bolt_node.position.z
	var bd_label := _label3d(room, "Back door — slide the bolt!", bd_pos + Vector3(-0.7, 3.55, 0), 50, Color(0.3, 0.22, 0.12))
	bd_label.rotation_degrees = Vector3(0, -90, 0)
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ BOWL STACK on the work counter ===================
	# v1.2: rebuilt as a PIVOT group on the counter top (was a lone
	# cylinder + a separate flowers sphere) so it can be one of the
	# knock-over distraction props — the bowls topple together.
	# vase_node keeps pointing at the group so _reset_escape_props /
	# vase_home work as before.
	var vase_pivot := Node3D.new()
	vase_pivot.position = o + Vector3(10.6, 0.925, 4.0)
	room.add_child(vase_pivot)
	vase_node = vase_pivot
	# SHELTER WARD: the vase is now a stack of steel food bowls
	# on the work counter (same pivot, same home, same topple).
	for bwl in range(3):
		_cyl(vase_pivot, Vector3(0, 0.07 + float(bwl) * 0.13, 0), 0.3 - float(bwl) * 0.035, 0.22 - float(bwl) * 0.03, 0.13, Color(0.68, 0.7, 0.74))
	vase_home = {"pos": vase_node.position, "rot": vase_node.rotation}
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
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
	_box(tw, o + Vector3(-1.5, 1.1, 4.8), Vector3(1.7, 0.13, 1.5), Color(0.95, 0.65, 0.75)) # pink blanket on the staff bench
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
	# POUND FIX: the pound worker had NO theme of his own, so
	# _apply_escape_theme fell back to the cat-lover's dressing —
	# a pink blanket, a feather wand and a toy mouse inside the
	# pound. His group is plain shelter kit: a folded grey-blue
	# blanket on the staff bench where the pink one sat, and a
	# stack of intake forms on the work trolley.
	var tp := Node3D.new()
	tp.name = "ThemePound"
	room.add_child(tp)
	theme_groups["poundworker"] = tp
	_box(tp, o + Vector3(-1.5, 1.1, 4.8), Vector3(1.7, 0.13, 1.5), Color(0.6, 0.65, 0.72)) # folded blanket, shelter grey-blue
	_box(tp, o + Vector3(1.55, 0.53, 1.1), Vector3(0.5, 0.05, 0.36), Color(0.96, 0.95, 0.9)) # intake forms on the trolley
	_box(tp, o + Vector3(1.55, 0.57, 1.1), Vector3(0.44, 0.04, 0.3), Color(0.9, 0.88, 0.82))
	for tg in theme_groups.values():
		(tg as Node3D).visible = false
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ v1.5 NEW LOOSE PROPS (knock-over additions) ========
	# Michael (2026-11-17): "I want to be able to knock over almost
	# everything in the house." Four modest additions where the room
	# was sparse — a wastebasket by the wash counter, a leash rack
	# (was a coat stand) in the south-east corner, a stool by the
	# counter, a bucket by the laundry bin. All registered below.
	var basket_pivot := Node3D.new()
	basket_pivot.position = o + Vector3(11.6, 0, -8.7)
	room.add_child(basket_pivot)
	_cyl(basket_pivot, Vector3(0, 0.35, 0), 0.34, 0.27, 0.7, Color(0.55, 0.58, 0.62)) # wastebasket
	_cyl(basket_pivot, Vector3(0, 0.71, 0), 0.36, 0.36, 0.07, Color(0.45, 0.48, 0.52)) # rim
	_sphere(basket_pivot, Vector3(0.08, 0.6, 0.04), Vector3(0.17, 0.17, 0.17), Color(0.95, 0.94, 0.9)) # crumpled paper
	var coatstand_pivot := Node3D.new()
	coatstand_pivot.position = o + Vector3(12.7, 0, 8.7)
	room.add_child(coatstand_pivot)
	_cyl(coatstand_pivot, Vector3(0, 0.07, 0), 0.42, 0.46, 0.14, Color(0.42, 0.44, 0.48)) # base
	_cyl(coatstand_pivot, Vector3(0, 1.05, 0), 0.06, 0.06, 2.0, Color(0.5, 0.52, 0.56)) # pole
	for hk in [Vector3(0.3, 1.92, 0), Vector3(-0.3, 1.92, 0), Vector3(0, 1.92, 0.3)]:
		_sphere(coatstand_pivot, hk, Vector3(0.1, 0.1, 0.1), Color(0.55, 0.57, 0.6)) # hooks
	# SHELTER WARD: it is a LEASH RACK now — leads hang from the hooks.
	_box(coatstand_pivot, Vector3(0.3, 1.35, 0), Vector3(0.07, 1.0, 0.04), Color(0.75, 0.3, 0.25))
	_box(coatstand_pivot, Vector3(-0.3, 1.4, 0), Vector3(0.07, 0.9, 0.04), Color(0.3, 0.45, 0.7))
	_box(coatstand_pivot, Vector3(0, 1.3, 0.3), Vector3(0.04, 1.05, 0.07), Color(0.35, 0.6, 0.4))
	var stool_pivot := Node3D.new()
	stool_pivot.position = o + Vector3(10.7, 0, -5.8)
	room.add_child(stool_pivot)
	_cyl(stool_pivot, Vector3(0, 0.62, 0), 0.44, 0.44, 0.1, Color(0.62, 0.45, 0.3)) # seat
	for lg in [Vector3(0.3, 0.3, 0), Vector3(-0.3, 0.3, 0.18), Vector3(-0.05, 0.3, -0.32)]:
		_cyl(stool_pivot, lg, 0.05, 0.05, 0.6, Color(0.5, 0.36, 0.22)) # legs
	var can_pivot := Node3D.new()
	can_pivot.position = o + Vector3(-9.7, 0, -4.9)
	room.add_child(can_pivot)
	_cyl(can_pivot, Vector3(0, 0.28, 0), 0.27, 0.3, 0.55, Color(0.5, 0.56, 0.62)) # the bucket
	_cyl(can_pivot, Vector3(0, 0.57, 0), 0.29, 0.29, 0.06, Color(0.42, 0.47, 0.53)) # bucket rim
	_cyl(can_pivot, Vector3(0, 0.5, 0), 0.24, 0.24, 0.03, Color(0.4, 0.55, 0.7)) # water in it
	var handle := _cyl(can_pivot, Vector3(0, 0.72, 0), 0.02, 0.02, 0.52, Color(0.35, 0.38, 0.42)) # handle
	handle.rotation_degrees = Vector3(0, 0, 90)
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ v1.2 DISTRACTION PROPS =============================
	# Three knock-over props (ids plant / book / vase — shelter
	# skins now: mop bucket / clipboard / bowl stack), each a pivot the
	# cat can topple with PAW. Registered in distract_props with the
	# spot the captor stands in to right it ("stand" — picked BESIDE
	# the furniture, never inside a solid piece). They are NOT escape
	# steps: the suite's one-mechanism rule stands.
	# SHELTER WARD: the plant is a MOP BUCKET now — same pivot,
	# same base/stand/topple, same id ("plant"), same contract.
	var plant_pivot := Node3D.new()
	plant_pivot.position = o + Vector3(-6.5, 0.0, -6.8)
	room.add_child(plant_pivot)
	_cyl(plant_pivot, Vector3(0, 0.28, 0), 0.3, 0.25, 0.56, Color(0.55, 0.58, 0.62)) # mop bucket
	_cyl(plant_pivot, Vector3(0, 0.57, 0), 0.32, 0.32, 0.07, Color(0.45, 0.48, 0.52)) # bucket rim
	_cyl(plant_pivot, Vector3(0, 0.53, 0), 0.26, 0.26, 0.03, Color(0.4, 0.55, 0.7)) # soapy water
	var mop_handle := _cyl(plant_pivot, Vector3(0.22, 0.95, 0), 0.025, 0.025, 1.25, Color(0.6, 0.48, 0.3)) # mop handle
	mop_handle.rotation_degrees = Vector3(0, 0, -16)
	_box(plant_pivot, Vector3(0.05, 0.66, 0), Vector3(0.3, 0.26, 0.3), Color(0.88, 0.86, 0.78)) # mop head
	distract_props.append({"id": "plant", "name": "the mop bucket", "pivot": plant_pivot, "base": o + Vector3(-6.5, 0, -6.8), "stand": o + Vector3(-5.55, 0, -5.85), "toppled": false, "anim_t": 1.0, "home_rot": plant_pivot.rotation, "topple_rot": Vector3(0, 0, -1.85), "bubble": "The mop bucket! 🧹"})
	var book_pivot := Node3D.new()
	book_pivot.position = o + Vector3(1.15, 0.5, 1.35) # standing on the work trolley
	room.add_child(book_pivot)
	_box(book_pivot, Vector3(0, 0.35, 0), Vector3(0.52, 0.7, 0.04), Color(0.5, 0.42, 0.32)) # clipboard board
	_box(book_pivot, Vector3(0, 0.33, 0.03), Vector3(0.45, 0.6, 0.02), Color(0.96, 0.95, 0.9)) # intake form
	_box(book_pivot, Vector3(0, 0.67, 0.03), Vector3(0.2, 0.07, 0.05), Color(0.55, 0.57, 0.6)) # the clip
	_box(book_pivot, Vector3(0, 0.45, 0.045), Vector3(0.36, 0.03, 0.01), Color(0.6, 0.65, 0.8)) # form lines
	_box(book_pivot, Vector3(0, 0.33, 0.045), Vector3(0.36, 0.03, 0.01), Color(0.6, 0.65, 0.8))
	distract_props.append({"id": "book", "name": "the clipboard", "pivot": book_pivot, "base": o + Vector3(1.15, 0, 1.35), "stand": o + Vector3(1.15, 0, 2.75), "toppled": false, "anim_t": 1.0, "home_rot": book_pivot.rotation, "topple_rot": Vector3(-1.5, 0, 0), "bubble": "The intake clipboard! 📋"})
	distract_props.append({"id": "vase", "name": "the bowl stack", "pivot": vase_pivot, "base": o + Vector3(10.6, 0, 4.0), "stand": o + Vector3(12.1, 0, 4.0), "toppled": false, "anim_t": 1.0, "home_rot": vase_pivot.rotation, "topple_rot": Vector3(0, 0, 1.65), "bubble": "The bowls! 🥣"})
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ v1.5: ALMOST EVERYTHING KNOCKS OVER ================
	# Michael (2026-11-17): more than "just a couple things" — every
	# plausible loose object in the room joins the SAME distraction
	# system (paw range, topple, cue, she rights it, queueing).
	# "base" is the floor XZ the paw reach is measured from (for
	# objects on furniture it is the furniture's XZ; for the cushion
	# it is the floor in front of the sofa, where the cat stands).
	# "cue" scales the crash: crash (hard), clatter (small/hard),
	# thud (soft). Fixtures stay put by design: the bench, the
	# trolley, the counters, the shelf unit, the cage bank, the
	# door and the carrier are never props.
	distract_props.append({"id": "floorlamp", "name": "the work light", "pivot": flamp_pivot, "base": o + Vector3(12, 0, -7), "stand": o + Vector3(10.7, 0, -8.2), "toppled": false, "anim_t": 1.0, "home_rot": flamp_pivot.rotation, "topple_rot": Vector3(0, 0, 1.3), "bubble": "The work light! 💡", "cue": "crash"})
	distract_props.append({"id": "tablelamp", "name": "the spray bottle", "pivot": tlamp_pivot, "base": o + Vector3(12.3, 0, 4.6), "stand": o + Vector3(11.2, 0, 5.6), "toppled": false, "anim_t": 1.0, "home_rot": tlamp_pivot.rotation, "topple_rot": Vector3(-1.25, 0, 0), "bubble": "The disinfectant! 🧴", "cue": "clatter"})
	distract_props.append({"id": "mug", "name": "the water bowl", "pivot": mug_pivot, "base": o + Vector3(0.7, 0, 1.4), "stand": o + Vector3(0.2, 0, 2.9), "toppled": false, "anim_t": 1.0, "home_rot": mug_pivot.rotation, "topple_rot": Vector3(0, 0, 1.45), "bubble": "The water bowl! 💧", "cue": "clatter"})
	distract_props.append({"id": "cushion", "name": "the blanket stack", "pivot": pillow_pivot, "base": o + Vector3(-2.3, 0, 5.2), "stand": o + Vector3(-2.3, 0, 6.0), "toppled": false, "anim_t": 1.0, "home_rot": pillow_pivot.rotation, "topple_rot": Vector3(0.35, 0.25, 0.95), "bubble": "The blankets! 🧺", "cue": "thud"})
	distract_props.append({"id": "fruitbowl", "name": "the treat bin", "pivot": fruit_pivot, "base": o + Vector3(12.8, 0, -2.2), "stand": o + Vector3(11.4, 0, -2.2), "toppled": false, "anim_t": 1.0, "home_rot": fruit_pivot.rotation, "topple_rot": Vector3(0, 0, 1.5), "bubble": "The treats! 🍖", "cue": "clatter"})
	distract_props.append({"id": "shoes", "name": "the boots", "pivot": shoes_pivot, "base": o + Vector3(4.95, 0, -9.2), "stand": o + Vector3(4.95, 0, -8.1), "toppled": false, "anim_t": 1.0, "home_rot": shoes_pivot.rotation, "topple_rot": Vector3(-0.5, 0, 0.7), "bubble": "My boots! 👢", "cue": "thud"})
	distract_props.append({"id": "picture", "name": "the notice board", "pivot": frame_pivot, "base": o + Vector3(-13.65, 0, 5.5), "stand": o + Vector3(-12.2, 0, 4.6), "toppled": false, "anim_t": 1.0, "home_rot": frame_pivot.rotation, "topple_rot": Vector3(0.45, 0, 0), "bubble": "The notice board! 📌", "cue": "clatter"})
	distract_props.append({"id": "bookstack", "name": "the towel stack", "pivot": stack_pivot, "base": o + Vector3(-9, 0, -7.7), "stand": o + Vector3(-9, 0, -6.5), "toppled": false, "anim_t": 1.0, "home_rot": stack_pivot.rotation, "topple_rot": Vector3(1.15, 0, 0), "bubble": "The towels! 🧼", "cue": "clatter"})
	distract_props.append({"id": "yarn", "name": "the ball of yarn", "pivot": yarn_pivot, "base": o + Vector3(5.5, 0, 7.8), "stand": o + Vector3(5.5, 0, 6.6), "toppled": false, "anim_t": 1.0, "home_rot": yarn_pivot.rotation, "topple_rot": Vector3(0, 0, 2.4), "bubble": "The yarn! 🧶", "cue": "thud"})
	distract_props.append({"id": "sillplant", "name": "the treat jar", "pivot": sill_pivot, "base": o + Vector3(-1.7, 0, -9.3), "stand": o + Vector3(-1.7, 0, -8.2), "toppled": false, "anim_t": 1.0, "home_rot": sill_pivot.rotation, "topple_rot": Vector3(0, 0, -1.3), "bubble": "Not the treat jar! 🍯", "cue": "clatter"})
	distract_props.append({"id": "wastebasket", "name": "the wastebasket", "pivot": basket_pivot, "base": o + Vector3(11.6, 0, -8.7), "stand": o + Vector3(10.4, 0, -8.1), "toppled": false, "anim_t": 1.0, "home_rot": basket_pivot.rotation, "topple_rot": Vector3(0, 0, 1.6), "bubble": "The bin! 🗑️", "cue": "crash"})
	distract_props.append({"id": "coatstand", "name": "the leash rack", "pivot": coatstand_pivot, "base": o + Vector3(12.7, 0, 8.7), "stand": o + Vector3(11.5, 0, 7.7), "toppled": false, "anim_t": 1.0, "home_rot": coatstand_pivot.rotation, "topple_rot": Vector3(-1.25, 0, 0), "bubble": "The leashes! 🦮", "cue": "crash"})
	distract_props.append({"id": "stool", "name": "the stool", "pivot": stool_pivot, "base": o + Vector3(10.7, 0, -5.8), "stand": o + Vector3(9.7, 0, -4.9), "toppled": false, "anim_t": 1.0, "home_rot": stool_pivot.rotation, "topple_rot": Vector3(0, 0, -1.5), "bubble": "The stool! 🪑", "cue": "crash"})
	distract_props.append({"id": "wateringcan", "name": "the bucket", "pivot": can_pivot, "base": o + Vector3(-9.7, 0, -4.9), "stand": o + Vector3(-8.6, 0, -4.1), "toppled": false, "anim_t": 1.0, "home_rot": can_pivot.rotation, "topple_rot": Vector3(0, 0, -1.5), "bubble": "The bucket! 🪣", "cue": "clatter"})
	await _build_tick() # v1.0.11 chunking: escape-room section boundary
	# ============ SHELTER KENNEL ROW (south wall) =================
	# SHELTER WARD (2026-11-18, Michael's reference photo): the
	# south end of the room is a proper kennel ward — a row of
	# runs along the wall, each fronted with CHAIN-LINK (the barred
	# fronts are gone), Zander's own cage (built by the opening
	# module) centred in the row. Every other run holds an ANIMAL,
	# and every gate really opens: paw one and the resident runs
	# out (+5). A second tier stacks over three of them, and the
	# west wall carries a bank of smaller stacked cat cages (see
	# _build_cage_bank). Two staff gaps stay open on purpose: the
	# west bay (the carrier's spot, the supply shelf, and the
	# captor's south anchor in front of it) and the yarn nook —
	# every prop base, stand spot and room anchor keeps its exact
	# reach, and no escape path changes length.
	var steel2 := _mat(Color(0.55, 0.58, 0.62), 0.45)
	steel2.metallic = 0.6
	var panel_mat2 := _mat(Color(0.78, 0.85, 0.8), 0.85)
	var slab_mat2 := _mat(Color(0.46, 0.45, 0.43), 0.8) # POUND FIX: warmed to concrete (was blue-grey)
	# [centre x, width, name card, blanket colour, kind, coat, pattern]
	var kennel_units: Array = [
		[-11.7, 2.6, "BISCUIT", Color(0.5, 0.62, 0.85), "cat", Color(0.55, 0.55, 0.6), 0],
		[-8.3, 2.6, "MITTENS", Color(0.85, 0.6, 0.45), "cat", Color(0.92, 0.92, 0.9), 0],
		[3.35, 2.6, "PEPPER", Color(0.55, 0.75, 0.55), "dog", Color(0.55, 0.4, 0.28), 0],
		[7.35, 2.2, "MOCHI", Color(0.8, 0.55, 0.7), "cat", Color(0.9, 0.8, 0.62), 1],
	]
	for ku in kennel_units:
		_build_one_kennel(room, o, float(ku[0]), float(ku[1]), 0.0, str(ku[2]), ku[3], steel2, panel_mat2, slab_mat2, str(ku[4]), ku[5], int(ku[6]))
	for ku2 in [[-11.7, 2.6, "WILLOW", "cat", Color(0.2, 0.2, 0.22), 0], [-8.3, 2.6, "SUNNY", "cat", Color(0.9, 0.55, 0.25), 1], [3.35, 2.6, "CLOVER", "cat", Color(0.75, 0.75, 0.78), 2]]:
		_build_one_kennel(room, o, float(ku2[0]), float(ku2[1]), 1.52, str(ku2[2]), Color(0.72, 0.7, 0.78), steel2, panel_mat2, slab_mat2, str(ku2[3]), ku2[4], int(ku2[5]))
	# The ward's big wall sign, board-mounted over the row.
	var sign_board := _box(room, o + Vector3(0, 3.35, 9.62), Vector3(7.0, 0.95, 0.08), Color.WHITE)
	sign_board.material_override = _mat(Color(0.4, 0.55, 0.46), 0.85)
	_label3d(room, "ANIMAL SHELTER", o + Vector3(0, 3.35, 9.45), 84, Color(1.0, 0.97, 0.85))
	# Staff bay dressing: a supply shelf on the wall (food, bowls,
	# treats) and a spare carrier waiting by the used one.
	for sh_y in [0.95, 1.55]:
		_box(room, o + Vector3(-4.2, sh_y, 9.4), Vector3(1.9, 0.07, 0.5), Color(0.75, 0.72, 0.66))
	_box(room, o + Vector3(-4.75, 1.36, 9.4), Vector3(0.55, 0.75, 0.4), Color(0.85, 0.62, 0.3)) # food bag
	_box(room, o + Vector3(-4.75, 1.77, 9.4), Vector3(0.5, 0.36, 0.34), Color(0.6, 0.7, 0.85)) # kibble box
	_cyl(room, o + Vector3(-3.72, 1.04, 9.4), 0.16, 0.13, 0.1, Color(0.35, 0.6, 0.8)) # spare bowls
	_cyl(room, o + Vector3(-3.72, 1.14, 9.4), 0.16, 0.13, 0.1, Color(0.9, 0.55, 0.3))
	for jx in range(3):
		_cyl(room, o + Vector3(-4.75 + float(jx) * 0.55, 1.7, 9.4), 0.11, 0.11, 0.24, [Color(0.9, 0.6, 0.3), Color(0.5, 0.75, 0.4), Color(0.85, 0.4, 0.4)][jx]) # treat jars
	_label3d(room, "SUPPLIES", o + Vector3(-4.2, 2.05, 9.45), 40, Color(0.2, 0.35, 0.33))
	var spare := _box(room, o + Vector3(-5.95, 0.64, 9.05), Vector3(1.7, 1.15, 1.15), Color.WHITE)
	spare.material_override = _mat(Color(0.72, 0.78, 0.88), 0.5)
	_box(room, o + Vector3(-5.95, 1.29, 9.05), Vector3(0.7, 0.13, 0.2), Color(0.35, 0.38, 0.45)) # spare carrier handle
	# The stacked cat-cage bank on the west wall (Michael: "vertical
	# stacked cages") — built last, it owns the west wall's middle.
	_build_cage_bank(room, o, steel2, panel_mat2, slab_mat2)


# One kennel of the shelter row (see _build_escape_room), in the
# reference photo's style: slab floor, blanket, solid side
# dividers, and a CHAIN-LINK front — a fixed mesh panel plus a
# real gate on a pivot, with a latch, a paper info card clipped
# to it, food + water bowls and a name card. The resident animal
# idles inside; paw the gate (once Zander is out of his own cage)
# and it swings open and the animal RUNS out (+5 — see
# free_ward_cage). base_y 0 = the floor tier; 1.52 = the stacked
# tier, resting on the one below.
func _build_one_kennel(room: Node3D, o: Vector3, cx: float, w: float, base_y: float, kname: String, blanket_col: Color, steel: Material, panel_mat: Material, slab_mat: Material, kind: String = "cat", coat: Color = Color(0.8, 0.6, 0.4), pattern: int = 0) -> void:
	var c: Vector3 = o + Vector3(cx, base_y, 8.6)
	var slab := _box(room, c + Vector3(0, 0.03, 0), Vector3(w, 0.06, 2.2), Color.WHITE)
	slab.material_override = slab_mat
	var blanket := _box(room, c + Vector3(-w * 0.24, 0.08, 0.5), Vector3(0.95, 0.04, 0.85), Color.WHITE)
	blanket.material_override = _mat(blanket_col, 0.95)
	for sx in [-1.0, 1.0]:
		var side := _box(room, c + Vector3(sx * (w * 0.5 - 0.03), 0.78, 0), Vector3(0.06, 1.44, 2.2), Color.WHITE, true)
		side.material_override = panel_mat
	for px2 in [-w * 0.5 + 0.035, w * 0.5 - 0.035]:
		var post := _box(room, c + Vector3(px2, 0.78, -1.1), Vector3(0.07, 1.5, 0.07), Color.WHITE)
		post.material_override = steel
	var top_rail := _box(room, c + Vector3(0, 1.47, -1.1), Vector3(w, 0.06, 0.07), Color.WHITE)
	top_rail.material_override = steel
	var bot_rail := _box(room, c + Vector3(0, 0.1, -1.1), Vector3(w, 0.05, 0.06), Color.WHITE)
	bot_rail.material_override = steel
	# The gate takes the east ~1 m of the front, hinged on its
	# west post; the rest of the front is a fixed mesh panel with
	# the photo's mid rail.
	var gx: float = w * 0.22
	var gate_w: float = 0.98
	var gate_left: float = gx - gate_w * 0.5
	var fixed_w: float = gate_left + w * 0.5
	_mesh_panel(room, c + Vector3(-w * 0.5 + fixed_w * 0.5, 0.78, -1.1), Vector2(fixed_w, 1.36))
	var mid_rail := _box(room, c + Vector3(-w * 0.5 + fixed_w * 0.5, 0.78, -1.13), Vector3(fixed_w, 0.05, 0.05), Color.WHITE)
	mid_rail.material_override = steel
	var gate_pivot := Node3D.new()
	gate_pivot.position = c + Vector3(gate_left, 0, -1.1)
	room.add_child(gate_pivot)
	for gpart in [[gate_w * 0.5, 1.32, gate_w, 0.05], [gate_w * 0.5, 0.22, gate_w, 0.05], [0.025, 0.77, 0.05, 1.15], [gate_w - 0.025, 0.77, 0.05, 1.15], [gate_w * 0.5, 0.77, gate_w, 0.05]]:
		var gp := _box(gate_pivot, Vector3(float(gpart[0]), float(gpart[1]), 0), Vector3(float(gpart[2]), float(gpart[3]), 0.05), Color.WHITE)
		gp.material_override = steel
	_mesh_panel(gate_pivot, Vector3(gate_w * 0.5, 0.77, 0), Vector2(gate_w - 0.08, 1.06))
	_box(gate_pivot, Vector3(gate_w - 0.12, 0.82, -0.05), Vector3(0.16, 0.09, 0.05), Color(0.35, 0.3, 0.18)) # gate latch
	# Bowls in the front corner, like every good kennel.
	_cyl(room, c + Vector3(w * 0.5 - 0.32, 0.12, -0.72), 0.16, 0.13, 0.12, Color(0.35, 0.6, 0.8))
	_cyl(room, c + Vector3(w * 0.5 - 0.68, 0.12, -0.72), 0.16, 0.13, 0.12, Color(0.9, 0.55, 0.3))
	# Name card over the gate + the paper info card from the photo.
	_label3d(room, kname, c + Vector3(0, 1.7, -1.16), 40, Color(0.2, 0.35, 0.33))
	_box(room, c + Vector3(gx - 0.22, 1.12, -1.17), Vector3(0.34, 0.42, 0.02), Color(0.97, 0.96, 0.92))
	_box(room, c + Vector3(gx - 0.22, 1.24, -1.19), Vector3(0.24, 0.03, 0.01), Color(0.6, 0.65, 0.8))
	_box(room, c + Vector3(gx - 0.22, 1.1, -1.19), Vector3(0.24, 0.03, 0.01), Color(0.6, 0.65, 0.8))
	# Containment: a fixed plug over the mesh panel and the gate's
	# own plug — the gate's drops when the animal is freed.
	_make_blocker(room, c + Vector3(-w * 0.5 + fixed_w * 0.5, 0.75, -1.1), Vector3(fixed_w, 1.5, 0.12))
	var gate_blocker := _make_blocker(room, c + Vector3(gx, 0.75, -1.1), Vector3(gate_w, 1.5, 0.12))
	# The resident, idling on its blanket.
	var animal := _make_ward_animal(room, c + Vector3(-w * 0.24, 0.1, 0.45), kind, coat, pattern, 0.9)
	_register_ward_cage(kname, gate_pivot, gate_blocker, c + Vector3(gx, 0, -1.1), 1.85, animal, Vector3(0, 0, -1), o)


# The stacked cat-cage bank on the west wall: three columns by
# three tiers of small chain-link cages (Michael: "vertical
# stacked cages"). Six hold cats (their gates open, +5 each);
# three are empty — bedding and a bowl, fixed fronts. Fronts face
# the room (+x); the bank's footprint (x −14..−13, z −3.4..3.8)
# stays clear of the shelf unit, the picture stand spot and the
# captor's west anchor.
func _build_cage_bank(room: Node3D, o: Vector3, steel: Material, panel_mat: Material, slab_mat: Material) -> void:
	var fx: float = -13.0 # the front plane
	# Frame: end uprights, tier slabs, column dividers.
	for ez in [-3.38, 3.78]:
		var up := _box(room, o + Vector3(-13.47, 1.47, ez), Vector3(0.92, 2.94, 0.08), Color.WHITE, true)
		up.material_override = panel_mat
	for sy in [0.03, 0.98, 1.96, 2.92]:
		var sl := _box(room, o + Vector3(-13.47, sy, 0.2), Vector3(0.94, 0.06, 7.24), Color.WHITE, sy > 0.1)
		sl.material_override = slab_mat
	for dz in [-1.05, 1.45]:
		var dv := _box(room, o + Vector3(-13.47, 1.47, dz), Vector3(0.92, 2.88, 0.06), Color.WHITE, true)
		dv.material_override = panel_mat
	# [column centre z, tier base y, name, coat, pattern] — "" = empty
	var units: Array = [
		[-2.2, 0.0, "PICKLE", Color(0.9, 0.55, 0.25), 1],
		[0.2, 0.0, "TOFU", Color(0.93, 0.92, 0.9), 0],
		[2.6, 0.0, "BEAN", Color(0.2, 0.2, 0.22), 0],
		[-2.2, 0.98, "OLIVE", Color(0.6, 0.6, 0.65), 2],
		[0.2, 0.98, "MISO", Color(0.85, 0.7, 0.5), 2],
		[2.6, 0.98, "", Color.WHITE, 0],
		[-2.2, 1.96, "", Color.WHITE, 0],
		[0.2, 1.96, "", Color.WHITE, 0],
		[2.6, 1.96, "WIDGET", Color(0.88, 0.78, 0.6), 1],
	]
	var blanket_cols: Array = [Color(0.5, 0.62, 0.85), Color(0.85, 0.6, 0.45), Color(0.55, 0.75, 0.55), Color(0.8, 0.55, 0.7), Color(0.72, 0.7, 0.78)]
	var ui: int = 0
	for un in units:
		var zc: float = float(un[0])
		var yb: float = float(un[1])
		var uname: String = str(un[2])
		var bc: Color = blanket_cols[ui % blanket_cols.size()]
		ui += 1
		var bedding := _box(room, o + Vector3(-13.58, yb + 0.08, zc - 0.45), Vector3(0.68, 0.04, 0.85), Color.WHITE)
		bedding.material_override = _mat(bc, 0.95)
		_cyl(room, o + Vector3(-13.22, yb + 0.1, zc + 0.78), 0.13, 0.1, 0.1, Color(0.35, 0.6, 0.8)) # bowl
		# front posts + rails
		for pz2 in [zc - 1.11, zc + 1.11]:
			var fp := _box(room, o + Vector3(fx, yb + 0.49, pz2), Vector3(0.06, 0.92, 0.06), Color.WHITE)
			fp.material_override = steel
		for ry in [yb + 0.05, yb + 0.93]:
			var fr := _box(room, o + Vector3(fx, ry, zc), Vector3(0.05, 0.05, 2.28), Color.WHITE)
			fr.material_override = steel
		if uname == "":
			# Empty cage: one fixed mesh front, no gate, no registry.
			_mesh_panel(room, o + Vector3(fx, yb + 0.49, zc), Vector2(2.2, 0.82), -90.0)
			_make_blocker(room, o + Vector3(fx, yb + 0.49, zc), Vector3(0.12, 0.95, 2.24))
			continue
		# Occupied: fixed mesh on the north part, a gate on the south.
		_mesh_panel(room, o + Vector3(fx, yb + 0.49, zc - 0.545), Vector2(1.13, 0.82), -90.0)
		_make_blocker(room, o + Vector3(fx, yb + 0.49, zc - 0.545), Vector3(0.12, 0.95, 1.13))
		var gpivot := Node3D.new()
		gpivot.position = o + Vector3(fx, yb, zc + 0.05)
		room.add_child(gpivot)
		for gpart in [[0.94, 0.05, 1.0], [0.12, 0.05, 1.0]]:
			var gr := _box(gpivot, Vector3(0, float(gpart[0]), float(gpart[2]) * 0.5), Vector3(0.05, float(gpart[1]), float(gpart[2])), Color.WHITE)
			gr.material_override = steel
		for gz2 in [0.03, 0.97]:
			var gs := _box(gpivot, Vector3(0, 0.49, gz2), Vector3(0.05, 0.86, 0.05), Color.WHITE)
			gs.material_override = steel
		_mesh_panel(gpivot, Vector3(0, 0.49, 0.5), Vector2(0.92, 0.78), -90.0)
		_box(gpivot, Vector3(-0.05, 0.55, 0.86), Vector3(0.05, 0.08, 0.14), Color(0.35, 0.3, 0.18)) # latch
		_box(gpivot, Vector3(0, 1.06, 0.55), Vector3(0.02, 0.3, 0.34), Color(0.97, 0.96, 0.92)) # info card
		var gblock := _make_blocker(room, o + Vector3(fx, yb + 0.49, zc + 0.55), Vector3(0.12, 0.95, 1.0))
		var card := _label3d(room, uname, o + Vector3(fx + 0.12, yb + 1.12, zc + 0.55), 36, Color(0.2, 0.35, 0.33))
		card.rotation_degrees = Vector3(0, 90, 0)
		var animal := _make_ward_animal(room, o + Vector3(-13.58, yb + 0.1, zc - 0.35), "cat", un[3], int(un[4]), 0.62)
		(animal["root"] as Node3D).rotation.y = -PI * 0.5 # face the room
		_register_ward_cage(uname, gpivot, gblock, o + Vector3(fx, yb, zc + 0.55), 1.85, animal, Vector3(1, 0, 0), o)


# A little stylised ward animal in the game's look, built from
# the same primitives as everything else: a sitting loaf of a cat
# (patterns: 0 solid, 1 tabby stripes, 2 pale chest/patches) or a
# small standing dog. Faces −z at yaw 0. Returns the node handles
# the ward tick animates (breathing body, turning head, ear flick,
# and the "bob" child the breakout run bounces on).
func _make_ward_animal(parent: Node, pos: Vector3, kind: String, coat: Color, pattern: int, s: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var bob := Node3D.new()
	root.add_child(bob)
	var dark: Color = coat.darkened(0.4)
	var body: MeshInstance3D
	var head: MeshInstance3D
	var ear_l: MeshInstance3D
	var ear_r: MeshInstance3D
	if kind == "dog":
		body = _sphere(bob, Vector3(0, 0.42 * s, 0.02 * s), Vector3(0.6, 0.46, 0.78) * s, coat)
		head = _sphere(bob, Vector3(0, 0.64 * s, -0.46 * s), Vector3(0.4, 0.38, 0.4) * s, coat)
		_box(bob, Vector3(0, 0.54 * s, -0.68 * s), Vector3(0.2, 0.15, 0.22) * s, dark) # snout
		ear_l = _box(bob, Vector3(-0.22 * s, 0.6 * s, -0.44 * s), Vector3(0.1, 0.3, 0.16) * s, dark) # floppy ears
		ear_r = _box(bob, Vector3(0.22 * s, 0.6 * s, -0.44 * s), Vector3(0.1, 0.3, 0.16) * s, dark)
		for lx in [-0.17, 0.17]:
			for lz in [-0.22, 0.26]:
				_cyl(bob, Vector3(lx * s, 0.17 * s, lz * s), 0.05 * s, 0.05 * s, 0.34 * s, dark) # legs
		var tail := _cyl(bob, Vector3(0, 0.62 * s, 0.44 * s), 0.035 * s, 0.045 * s, 0.4 * s, coat) # tail, up
		tail.rotation_degrees = Vector3(-38, 0, 0)
		_sphere(bob, Vector3(-0.08 * s, 0.68 * s, -0.63 * s), Vector3(0.055, 0.055, 0.055) * s, Color(0.1, 0.08, 0.08)) # eyes
		_sphere(bob, Vector3(0.08 * s, 0.68 * s, -0.63 * s), Vector3(0.055, 0.055, 0.055) * s, Color(0.1, 0.08, 0.08))
	else:
		body = _sphere(bob, Vector3(0, 0.17 * s, 0), Vector3(0.52, 0.36, 0.64) * s, coat)
		head = _sphere(bob, Vector3(0, 0.42 * s, -0.3 * s), Vector3(0.42, 0.4, 0.42) * s, coat)
		ear_l = _cyl(bob, Vector3(-0.12 * s, 0.66 * s, -0.3 * s), 0.0, 0.08 * s, 0.17 * s, coat) # cone ears
		ear_r = _cyl(bob, Vector3(0.12 * s, 0.66 * s, -0.3 * s), 0.0, 0.08 * s, 0.17 * s, coat)
		_sphere(bob, Vector3(-0.09 * s, 0.46 * s, -0.48 * s), Vector3(0.05, 0.05, 0.05) * s, Color(0.1, 0.08, 0.08)) # eyes
		_sphere(bob, Vector3(0.09 * s, 0.46 * s, -0.48 * s), Vector3(0.05, 0.05, 0.05) * s, Color(0.1, 0.08, 0.08))
		_sphere(bob, Vector3(0, 0.38 * s, -0.51 * s), Vector3(0.04, 0.03, 0.03) * s, Color(0.85, 0.5, 0.5)) # nose
		var ctail := _cyl(bob, Vector3(0.3 * s, 0.05 * s, -0.02 * s), 0.04 * s, 0.04 * s, 0.52 * s, dark) # tail curled round
		ctail.rotation_degrees = Vector3(90, 0, 0)
		if pattern == 1: # tabby stripes across the back
			for si in range(3):
				_box(bob, Vector3(0, 0.33 * s, (-0.18 + 0.16 * float(si)) * s), Vector3(0.44, 0.05, 0.09) * s, dark)
		elif pattern == 2: # pale chest + a dark ear
			_sphere(bob, Vector3(0, 0.28 * s, -0.3 * s), Vector3(0.26, 0.28, 0.2) * s, Color(0.95, 0.94, 0.9))
			ear_r.material_override = _mat(dark, 0.9)
	return {"root": root, "bob": bob, "body": body, "head": head, "ear_l": ear_l, "ear_r": ear_r, "body_base": body.scale}


# Register one freeable cage (see ward_cages for the record
# shape). The animal's way out alternates between the pet door
# and the window so a mass breakout scatters both ways.
func _register_ward_cage(kname: String, gate_pivot: Node3D, gate_blocker: StaticBody3D, gate_pos: Vector3, open_yaw: float, animal: Dictionary, out_dir: Vector3, o: Vector3) -> void:
	var root := animal["root"] as Node3D
	ward_cages.append({
		"name": kname, "gate_pivot": gate_pivot, "gate_blocker": gate_blocker,
		"gate_pos": gate_pos, "open_yaw": open_yaw, "out_dir": out_dir,
		"animal": root, "bob": animal["bob"], "body": animal["body"],
		"head": animal["head"], "ear_l": animal["ear_l"], "ear_r": animal["ear_r"],
		"body_base": animal["body_base"],
		"home_pos": root.position, "home_yaw": root.rotation.y,
		"freed": false, "gate_t": -1.0, "animal_state": "in", "animal_t": 0.0,
		"wp": [], "wp_i": 0, "phase": randf() * 10.0,
		"exit_target": o + (Vector3(6, 0, -9.2) if ward_cages.size() % 2 == 0 else Vector3(0, 0, -9.1)),
	})


# PAW at a cage gate: the nearest still-closed cage whose gate is
# within reach of the cat. Returns true when one was freed.
func _free_cage_at_cat() -> bool:
	if _cat_caged() or player == null:
		return false
	var best: Dictionary = {}
	var best_d: float = 2.2
	for cg in ward_cages:
		if bool(cg["freed"]):
			continue
		var gp: Vector3 = cg["gate_pos"]
		var d: float = Vector2(player.global_position.x - gp.x, player.global_position.z - gp.z).length()
		if d < best_d:
			best_d = d
			best = cg
	if best.is_empty():
		return false
	free_ward_cage(best)
	return true


# Open one cage: the gate swings, the plug drops, the points land
# (+5, treat-tier — Gary's pick on Michael's scale) with a
# floating pop and a message, and the animal RUNS — out of the
# cage, across the ward and out of the room. Once per visit.
func free_ward_cage(cg: Dictionary) -> void:
	if bool(cg["freed"]):
		return
	cg["freed"] = true
	cg["gate_t"] = 0.0
	_set_blocker(cg["gate_blocker"], false)
	var gp: Vector3 = cg["gate_pos"]
	var od: Vector3 = cg["out_dir"]
	var hy: float = (cg["home_pos"] as Vector3).y
	cg["wp"] = [
		gp - od * 0.25 + Vector3(0, hy - gp.y, 0),
		gp + od * 1.15 + Vector3(0, hy - gp.y, 0),
		Vector3(gp.x + od.x * 2.3, 0.0, gp.z + od.z * 2.3),
		cg["exit_target"],
	]
	cg["wp_i"] = 0
	cg["animal_state"] = "out"
	cg["animal_t"] = 0.0
	score += 5
	_update_score_label()
	show_message("🐾 You freed %s! +5" % str(cg["name"]), 2.4)
	var pop := _label3d(self, "Freed %s! +5" % str(cg["name"]), gp + Vector3(0, 1.75, 0) - od * 0.4, 64, Color(1.0, 0.85, 0.3))
	ward_pops.append({"node": pop, "t": 0.0, "y0": pop.position.y})


# Every cage closed again, every animal home: called on each
# entry into the escape room, so a new pound visit can be broken
# out all over again.
func _reset_ward_cages() -> void:
	for cg in ward_cages:
		cg["freed"] = false
		cg["gate_t"] = -1.0
		(cg["gate_pivot"] as Node3D).rotation.y = 0.0
		_set_blocker(cg["gate_blocker"], true)
		var root := cg["animal"] as Node3D
		if root != null and is_instance_valid(root):
			root.position = cg["home_pos"]
			root.rotation = Vector3(0, float(cg["home_yaw"]), 0)
			root.visible = true
			(cg["bob"] as Node3D).position.y = 0.0
		cg["animal_state"] = "in"
		cg["animal_t"] = 0.0
		cg["wp"] = []
		cg["wp_i"] = 0
	for pp in ward_pops:
		if is_instance_valid(pp["node"]):
			(pp["node"] as Node).queue_free()
	ward_pops.clear()


# The ward's per-frame life, ticked from _update_escape_room:
# gates swing, caged animals breathe / look around / flick an
# ear, freed animals RUN their waypoints out of the room, and
# the score pops rise and fade.
func _update_ward(delta: float) -> void:
	ward_time += delta
	for i in range(ward_pops.size() - 1, -1, -1):
		var pp: Dictionary = ward_pops[i]
		pp["t"] = float(pp["t"]) + delta
		var pt: float = float(pp["t"])
		var pnode := pp["node"] as Label3D
		if pnode == null or not is_instance_valid(pnode):
			ward_pops.remove_at(i)
			continue
		pnode.position.y = float(pp["y0"]) + pt * 0.55
		pnode.modulate.a = clampf(1.3 - pt / 1.6, 0.0, 1.0)
		if pt > 1.6:
			pnode.queue_free()
			ward_pops.remove_at(i)
	for cg in ward_cages:
		if float(cg["gate_t"]) >= 0.0:
			cg["gate_t"] = float(cg["gate_t"]) + delta
			var k: float = clampf(float(cg["gate_t"]) / 0.5, 0.0, 1.0)
			(cg["gate_pivot"] as Node3D).rotation.y = float(cg["open_yaw"]) * (1.0 - pow(1.0 - k, 2.0))
			if k >= 1.0:
				cg["gate_t"] = -1.0
		var root := cg["animal"] as Node3D
		if root == null or not is_instance_valid(root):
			continue
		var st: String = str(cg["animal_state"])
		if st == "in":
			var ph: float = float(cg["phase"])
			(cg["body"] as Node3D).scale = (cg["body_base"] as Vector3) * (1.0 + 0.035 * sin(ward_time * 2.1 + ph))
			(cg["head"] as Node3D).rotation.y = 0.38 * sin(ward_time * 0.33 + ph * 1.7)
			(cg["ear_l"] as Node3D).rotation.z = 0.55 if fmod(ward_time + ph * 3.1, 4.3) < 0.13 else 0.0
		elif st == "out":
			cg["animal_t"] = float(cg["animal_t"]) + delta
			if float(cg["animal_t"]) < 0.3:
				continue # a beat while the gate swings open
			var wps: Array = cg["wp"]
			var wi: int = int(cg["wp_i"])
			if wi >= wps.size():
				cg["animal_state"] = "gone"
				root.visible = false
				(cg["bob"] as Node3D).position.y = 0.0
				continue
			var target: Vector3 = wps[wi]
			var d: Vector3 = target - root.position
			var step: float = 5.2 * delta
			if d.length() <= step:
				root.position = target
				cg["wp_i"] = wi + 1
			else:
				root.position = root.position + d.normalized() * step
			if Vector2(d.x, d.z).length() > 0.05:
				root.look_at(root.position + Vector3(d.x, 0, d.z), Vector3.UP)
			(cg["bob"] as Node3D).position.y = absf(sin(float(cg["animal_t"]) * 11.0)) * 0.16


# ---------------------------------------------------------------- actors/camera
func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(CatScript)
	player.position = Vector3(2, 0.2, -2)
	add_child(player)
	player.set("main_ref", self)
	player.call("set_tag_name") # the tag says his NAME ("Zander"), not the address

# --- v1.0.25: the canonical house footprint (the same rect
# person.gd's line-of-sight uses: house pos ± 4.4 x, ± 3.9 z).
# Spawn points, wander targets and town-cat homes/targets are
# validated against it — before this build, one inhabitant
# spawned INSIDE 22 Willow Crescent and two town cats had their
# homes inside house footprints, wedged from birth.
# v1.0.29: every building rect in town — the houses (canonical
# ±4.4 x / ±3.9 z) plus the Meshy civic buildings and the bakery,
# whose real footprints are registered as they are placed. Spawn
# points, wander targets and cat homes validate against all of
# them, so nobody can be wedged inside a civic building either.
func _building_rects() -> Array:
	var rects: Array = []
	for h in houses:
		rects.append([h["pos"].x, h["pos"].z, 4.4, 3.9])
	for fp in building_footprints:
		rects.append([fp["pos"].x, fp["pos"].z, fp["hx"], fp["hz"]])
	return rects

func point_in_house_footprint(p: Vector3, pad: float = 0.0) -> bool:
	for r in _building_rects():
		if absf(p.x - float(r[0])) < float(r[2]) + pad and absf(p.z - float(r[1])) < float(r[3]) + pad:
			return true
	return false

func push_out_of_houses(p: Vector3, pad: float = 0.8) -> Vector3:
	# Nearest spot outside every footprint: push along whichever
	# axis penetrates least, repeat until clear (rows can overlap
	# a pushed point into the next house).
	var out := p
	var rects: Array = _building_rects()
	for pass_i in range(4):
		var moved := false
		for r in rects:
			var cx: float = float(r[0])
			var cz: float = float(r[1])
			var ex: float = float(r[2]) + pad
			var ez: float = float(r[3]) + pad
			var dx: float = out.x - cx
			var dz: float = out.z - cz
			if absf(dx) < ex and absf(dz) < ez:
				if ex - absf(dx) < ez - absf(dz):
					out.x = cx + (ex if dx >= 0.0 else -ex)
				else:
					out.z = cz + (ez if dz >= 0.0 else -ez)
				moved = true
		if not moved:
			break
	return out

# v1.0.25: where a wedged wanderer should walk OUT to. Near a
# house (the porch-pocket case), the point radially away from
# that house's centre, 8.5 m out — clear of the footprint, the
# porch step, the hedge and the side block, in the one
# direction a pocket always leaves open. Elsewhere, the first
# clear point on a 9 m ring around the spot.
func escape_point_from_houses(p: Vector3) -> Vector3:
	var best_c := Vector3.ZERO
	var best_d := 1e18
	var centres: Array = []
	for h in houses:
		centres.append(h["pos"])
	for fp in building_footprints: # v1.0.29: civic buildings wedge NPCs the same way houses do
		centres.append(fp["pos"])
	for c in centres:
		var d: float = Vector2(p.x - c.x, p.z - c.z).length()
		if d < best_d:
			best_d = d
			best_c = c
	if best_d < 9.0:
		var c2: Vector3 = best_c
		var dir := Vector2(p.x - c2.x, p.z - c2.z)
		if dir.length() < 0.1:
			dir = Vector2(0.0, 1.0)
		dir = dir.normalized()
		# Always land at least 4 m FARTHER OUT than the wedged
		# spot: at a fence end ~8 m from the centre, a fixed
		# 8.5 m ring is the NPC's own feet and the "escape"
		# changes nothing (measured in the warm-up sim).
		var rr: float = maxf(8.5, best_d + 4.0)
		return Vector3(clampf(c2.x + dir.x * rr, -114.0, 114.0), 0.0, clampf(c2.z + dir.y * rr, -86.0, 86.0))
	for k in range(8):
		var ang: float = randf() * TAU
		var cand := Vector3(clampf(p.x + cos(ang) * 9.0, -114.0, 114.0), 0.0, clampf(p.z + sin(ang) * 9.0, -86.0, 86.0))
		if not point_in_house_footprint(cand, 0.7):
			return cand
	return Vector3(clampf(p.x, -114.0, 114.0), 0.0, clampf(p.z + 9.0, -86.0, 86.0))

func _spawn_town_cats() -> void:
	# v1.0.22: the eight Meshy TOWN CATS wander the town as ambient
	# animals (Michael's all-Meshy street rule — the old code-built
	# strays are gone). Each is its own little CharacterBody3D with
	# a procedural trot (the GLBs are rigged but carry no clips —
	# see town_cat.gd). Spots sit on grass/verge near known NPC
	# spots in the legacy town, clear of the road centrelines.
	# v1.0.26: every home now sits on a street VERGE / front lawn
	# (about 6 m off a road centreline, just past the sidewalk),
	# spread across the whole town, and each cat carries the
	# name + meow pitch its interactions use. Michael, playing
	# v1.0.25, only ever met ONE cat — the old homes let them
	# range the back gardens where the player never goes.
	var spots: Array = [
		["town_tabby", Vector3(-24, 0.2, -5), "the town tabby", 1.12], ["black_cat", Vector3(30, 0.2, -19), "the black cat", 0.88],
		["white_cat", Vector3(-31, 0.2, 21), "the white fluffy cat", 1.24], ["calico_cat", Vector3(66, 0.2, 3), "the calico cat", 1.04],
		["gray_tabby", Vector3(3, 0.2, 49), "the grey tabby", 0.96], ["siamese_cat", Vector3(-14, 0.2, 33), "the Siamese cat", 1.18],
		["tortoiseshell_cat", Vector3(79, 0.2, -32), "the tortoiseshell cat", 0.92], ["russian_blue_cat", Vector3(55, 0.2, 63), "the Russian Blue", 1.08],
	]
	for d in spots:
		var cat := CharacterBody3D.new()
		cat.set_script(TownCatScript)
		# v1.0.25: two of the eight homes sat INSIDE house
		# footprints (calico at 25 Oak Avenue's, russian blue at
		# 22 Willow Crescent's) — push every home clear first.
		var home_pos: Vector3 = push_out_of_houses(d[1], 0.9)
		cat.set("model_scene", TOWN_CAT_SCENES[d[0]])
		cat.set("player_ref", player)
		cat.set("main_ref", self)
		cat.set("display_name", d[2])
		cat.set("meow_pitch", d[3])
		cat.set("home", home_pos)
		cat.position = home_pos
		add_child(cat)
		town_cats.append(cat)

func _spawn_npcs() -> void:
	# v0.9 (item 2): MORE neighbours — 22 out walking (was 14),
	# spread over the whole map including the filled east/south
	# districts. The first of each type is the sheet character
	# (outfit 0); repeats get outfit/hair variants from person.gd.
	# POPULATION STEP (post-v1.0.5, Michael's direction 2026-11-16):
	# 34 out walking (was 22) — he asked for a busier town while
	# keeping ~25% as the ones to avoid. The 12 newcomers (defs
	# 23-34 below) are seeded in the newer areas that had nobody:
	# riverside promenade + cafe, market row, the playground,
	# Willow Green, the Riverside Court block, the bakery corner,
	# the community garden, Willow Hall and Maple Mart.
	var defs: Array = [
		["woman", Vector3(-30, 0.2, -6)], ["kid", Vector3(36, 0.2, -14)], ["dogwalker", Vector3(-36, 0.2, 20)],
		["shopkeeper", Vector3(46, 0.2, 6)], ["mailcarrier", Vector3(-44, 0.2, -22)], ["gardener", Vector3(50, 0.2, 34)],
		["woman", Vector3(8, 0.2, 26)], ["kid", Vector3(-52, 0.2, 28)],
		["woman", Vector3(84, 0.2, -37)], ["kid", Vector3(-86, 0.2, 38)], ["dogwalker", Vector3(60, 0.2, 66)], # MAP DOUBLING: this neighbour moved z -44 -> -37 — a new Elm S house now stands at (84,-44)
		["shopkeeper", Vector3(-60, 0.2, -70)], ["skateboarder", Vector3(100, 0.2, 20)], ["baker", Vector3(-100, 0.2, -80)],
		["woman", Vector3(-112, 0.2, -48)], ["kid", Vector3(108, 0.2, 38)], ["dogwalker", Vector3(-58, 0.2, 84)],
		["shopkeeper", Vector3(80, 0.2, -72)], ["construction", Vector3(14, 0.2, -84)], ["coffeeowner", Vector3(-14, 0.2, 48)],
		["woman", Vector3(110, 0.2, -6)], ["jogger", Vector3(34, 0.2, 84)],
		["woman", Vector3(-38, 0.2, -83)], ["musician", Vector3(58, 0.2, -85)], ["shopkeeper", Vector3(97, 0.2, -17)],
		["kid", Vector3(93, 0.2, 25)], ["woman", Vector3(88, 0.2, 19)], ["dogwalker", Vector3(106, 0.2, 73)],
		["mailcarrier", Vector3(103, 0.2, 80)], ["woman", Vector3(102, 0.2, -60)], ["gardener", Vector3(56, 0.2, -8)],
		["dogwalker", Vector3(-95, 0.2, 76)], ["skateboarder", Vector3(24, 0.2, 74)], ["woman", Vector3(-84, 0.2, -14)],
		# MAP DOUBLING: 14 more neighbours (defs 35-48) — most in
		# the new east district (Harbour Market, Meadow Court,
		# Sunset Green, the new streets and promenade), plus one
		# old-town infill walker. Roles below keep the split at
		# exactly 25% to avoid: 12 / 19 / 17 of 48.
		["shopkeeper", Vector3(193, 0.2, -19)], ["baker", Vector3(198, 0.2, -24)], ["woman", Vector3(252, 0.2, -59)],
		["dogwalker", Vector3(300, 0.2, 74)], ["construction", Vector3(340, 0.2, 22)], ["woman", Vector3(160, 0.2, 58)],
		["coffeeowner", Vector3(214, 0.2, -72)], ["kid", Vector3(255, 0.2, 24)], ["woman", Vector3(305, 0.2, -38)],
		["jogger", Vector3(348, 0.2, -18)], ["kid", Vector3(182, 0.2, 8)], ["woman", Vector3(150, 0.2, -83)],
		["musician", Vector3(58, 0.2, -18)], ["woman", Vector3(326, 0.2, -61)],
	]
	# BISECT (v1.0.12): in legacy mode the MAP DOUBLING neighbours
	# above keep their types and their order in the array — so the
	# role split below (exactly 25% grabbers) is untouched — but
	# the 13 of them who spawn in the east district (x > 120) move
	# to legacy-town spots, and everyone's wander range is capped
	# at the legacy east edge (see the wander_x_max set below).
	if LEGACY_TOWN_ONLY:
		var legacy_spots: Array = [
			Vector3(-88, 0.2, -17), Vector3(-102, 0.2, 24), Vector3(66, 0.2, -59),
			Vector3(-64, 0.2, 74), Vector3(88, 0.2, 22), Vector3(-16, 0.2, 58),
			Vector3(76, 0.2, -72), Vector3(20, 0.2, 24), Vector3(-96, 0.2, -38),
			Vector3(104, 0.2, -18), Vector3(44, 0.2, 8), Vector3(-48, 0.2, -83),
			Vector3(96, 0.2, -61),
		]
		var li: int = 0
		for i in range(defs.size()):
			if (defs[i][1] as Vector3).x > 120.0 and li < legacy_spots.size():
				var dd: Array = defs[i]
				dd[1] = legacy_spots[li]
				li += 1
	# Interaction roles: v1.0 — grabbers are 25% of EVERYONE, as
	# Michael set on 2026-11-15 (he first said 20%, then settled on
	# 25%): in v0.9 play the single grabber (1 of 22, the v0.7 rate)
	# left him barely able to get anyone interested and it felt
	# boring. 25% of 22 is 5.5, so SIX neighbours seek the cat out;
	# the extra five came out of the friendly pool. The rest:
	# 8 FRIENDLY (pets +1 / treats +5 on paw/meow) and 8 who simply
	# never notice the cat ("ignore").
	# POPULATION STEP: 34 total. 25% of 34 is 8.5 — rounded UP to
	# NINE grabbers, same call as 5.5 -> 6 (Michael's intent is
	# more action, not less). The 12 newcomers carry 3 grabber /
	# 5 friendly / 4 ignore, giving totals of 9 / 13 / 12 —
	# friendly stays >= ignore so scoring chances grow fastest.
	var roles: Array = ["friendly", "grabber", "friendly", "friendly", "ignore", "grabber", "friendly", "friendly", "grabber", "ignore", "friendly", "ignore", "ignore", "ignore", "grabber", "friendly", "ignore", "grabber", "ignore", "friendly", "grabber", "ignore", "friendly", "ignore", "friendly", "friendly", "grabber", "friendly", "ignore", "grabber", "ignore", "friendly", "ignore", "grabber",
		# MAP DOUBLING: roles for defs 35-48 (3 grabber / 6 friendly / 5 ignore)
		"friendly", "ignore", "friendly", "friendly", "ignore", "grabber", "ignore", "friendly", "friendly", "ignore", "grabber", "friendly", "ignore", "grabber"]
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
		npc.set("wander_x_max", 112.0 if LEGACY_TOWN_ONLY else 366.0) # BISECT (v1.0.12): legacy NPCs never wander east
		# v1.0.25: never spawn inside a house — defs[10] (the
		# dogwalker at (60, 66)) stood inside 22 Willow Crescent's
		# footprint, entombed in its collision from birth.
		var spawn_pos: Vector3 = push_out_of_houses(d[1], 0.8)
		npc.position = spawn_pos
		add_child(npc)
		npc.set("main_ref", self)
		npc.set("player_ref", player)
		# The _ready pick ran before main_ref existed, so it could
		# not validate against houses — pick again, validated.
		npc.call("_pick_wander_target")
		# v1.0.23 PARK DWELL: kids and the skateboarder who spawn
		# in the playground park's block (the kid at (93, 25), the
		# kid at (108, 38), the skateboarder at (100, 20)) are park
		# dwellers — person.gd walks them between the park's play
		# spots and lingers there, instead of only wandering the
		# streets. Matched on the FINAL spawn position (after the
		# legacy-mode relocation above), so it holds in both towns.
		var sp: Vector3 = spawn_pos # v1.0.25: the validated spawn (park spots are never pushed — no houses there)
		if (d[0] == "kid" or d[0] == "skateboarder") and sp.x > 74.0 and sp.x < 118.0 and sp.z > 17.0 and sp.z < 42.0:
			npc.set("park_dweller", true)
			npc.set("park_spots", PARK_SPOTS)
		npcs.append(npc)
		await _build_tick()

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
# Escape room: its own indoor profile since v1.0.20 (orbit 3.0, FOV
# 70, pitch floored at 26, and a pull-in that lifts instead of
# pinning the camera to the cat) — see the v1.0.20 note in
# _update_camera. The collision pull-in below keeps the camera
# inside its walls.
# v1.2 READABILITY (Michael's v1.0.4 playtest — the real-scale cat was
# hard to see): orbit back in toward the old perspective. Pre-scale-fix
# the cat filled ~0.40 of the frame height ratio (1.5m at 3.7m); the
# scale step left 0.31 (0.52m at 1.7m). With the model drawn at 1.25x
# (0.64m) and the orbit at 1.45m the ratio is ~0.44 — slightly BETTER
# than the framing he liked. Look height follows the drawn back.
# v1.3 CAMERA FRAMING (Michael's v1.0.5 playtest: "when you go up to a
# person you can't see the progress bar... I can't look up and see the
# street signs... it's too close in" — and, same call, "I don't want
# the cat looking tiny either"). Measured with tests/CamProbe.tscn
# (real camera, viewport fractions, y 0=top 1=bottom) at the OLD
# values (dist 1.45, look height 0.38, FOV 62, pitch 18): a person
# 1.2m from the cat had her FACE at y=-0.13 and the notice bar (label
# centre 3.02m up) at y=-0.85 — off the top of the screen; the bar
# stayed off-screen even 5m away (y=-0.13), and even at max look-up
# (-10) it only entered at 3m+, at the very edge. The 3.75m sign
# boards were off-screen at default pitch even 6m away, and at max
# look-up the whole board only fit from 6m. Causes: the orbit was
# cat-scale short, the 18-degree default tilt aimed the frustum at
# the ground (top edge only 13 degrees above horizontal), the -10
# look-up floor barely tilted the view axis up, and FOV 62 is narrow.
# Fix, framing-first (Michael: not at the cost of a tiny cat): orbit
# out a little (1.45 -> 2.0), the town look anchor UP to 1.15 (the
# camera flies higher and flatter, so a person's head + bar fit at
# conversational distance), town FOV out to 70, default pitch down
# to 4, look-up range extended to -22. AFTER measurements (same
# probe + tests/ShotRunnerCamera.tscn): at the default pitch a
# person 1.2m away has face y=0.35, head top ~0.17 and the notice
# bar centre y=0.05 — the whole figure in frame; at 2m the bar
# sits at y=0.11+, at 5m 0.26. At max look-up the whole sign board
# is comfortably framed from 2-3m (top y=0.29 at 3m), and
# even at the default pitch its centre is in frame from 3m. The
# cat's measured screen share goes 0.36 -> 0.21 of frame height —
# above the 0.17 of the v0.3 framing he played happily, and he sits
# lower-centre with the people and signs in the frame above him,
# which is the point. (An intermediate tuning at dist 2.2 / FOV 72
# measured the cat at only 0.18 — pulled back in: distance is the
# one lever that shrinks him, so it moved least.) The ESCAPE room
# kept its old framing (CAM_LOOK_HEIGHT 0.38, FOV 62, dist 5.0)
# until v1.0.20, which gave the room its own indoor profile (dist
# 3.0, FOV 70, pitch floor 26, pull-in lift — see _update_camera);
# the room's 0.38 look anchor is unchanged, and the capture
# cutscene keeps FOV 62.
const CAM_TOWN_DIST := 2.0
const CAM_ESCAPE_DIST := 3.0 # v1.0.20: was 5.0 — the indoor profile (see the v1.0.20 note in _update_camera)
const CAM_LOOK_HEIGHT := 0.38 # escape-room look anchor (unchanged)
const CAM_TOWN_LOOK_HEIGHT := 1.15 # town/chase look anchor (v1.3)
const CAM_FOV := 62.0 # cutscene FOV (unchanged)
const CAM_ESCAPE_FOV := 70.0 # v1.0.20: the escape room uses the town's wider FOV (was CAM_FOV 62)
const CAM_TOWN_FOV := 70.0 # town play FOV (v1.3)
const CAM_ESCAPE_PITCH := 26.0 # v1.0.20: indoor pitch — set on room entry, and the escape camera never rides below it
const CAM_ESCAPE_MIN_DIST := 2.0 # v1.0.20: indoors the pull-in lifts instead of pinning the camera closer than this to the cat
const CAM_ESCAPE_LIFT_MAX := 3.9 # v1.0.20: the indoor lift's cap, metres above the look anchor (the ward ceiling's underside is ~4.6)
const CHASE_CAM_DIST := 6.4 # the close-chase orbit (v1.2: 6.8 -> 6.4 for the smaller cat so he AND the pursuer read clearly; v1.3: the aim raise below keeps the pursuer's CHASE/GRAB bar in frame — y=0.15 at 5m behind, ShotRunnerCamera)
const CHASE_AIM_MAX := 1.5 # v1.0.13: max metres the chase aim may drift from the cat toward the chaser (see the pursuit-camera note in _update_camera)
const CHASE_DIST_NEAR := 8.0 # v1.0.13: at or below this cat<->chaser gap the full chase distance applies (ordinary chases live here)
const CHASE_DIST_FAR := 15.0 # v1.0.13: at or above this gap the framing is the plain town distance again (she cannot share the frame from there anyway)

func _camera_dist() -> float:
	return CAM_ESCAPE_DIST if state == "escape" else CAM_TOWN_DIST

# The look anchor for the CURRENT state: the escape room keeps the
# framing it was verified with; everywhere else uses the raised
# town anchor so people fit in frame (v1.3).
func _look_height() -> float:
	return CAM_LOOK_HEIGHT if state == "escape" else CAM_TOWN_LOOK_HEIGHT

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
	if escape_panel != null and escape_panel.visible:
		# v1.0.22 (Michael's direction): the panel owns input while
		# open — BUT the escape combination is entered on the game's
		# OWN on-screen A (HOP) / B (PAW) buttons (the duplicate
		# on-panel buttons are gone). The panel Control covers the
		# whole screen, so the Buttons' own signals never fire; the
		# presses are claimed HERE, on the raw channels, exactly like
		# the v1.0.18/v1.0.21 action claims, and routed to the panel.
		# v1.0.24 (Michael's v1.0.22 play report: "I hit B once and
		# multiple Bs were hit… then when I hit A it wouldn't work" —
		# escaping was effectively impossible): the v1.0.22 branch
		# claimed a press from BOTH event generations — the raw
		# InputEventScreenTouch AND the InputEventMouseButton the
		# engine synthesizes from the same tap (emulate_mouse_from_
		# touch is on) — each arriving as its own _input call, with
		# NO dedupe of any kind on this path, so one physical tap
		# registered TWO combo steps. (The HUD Buttons' pressed
		# signals are NOT a third path: the panel is a full-screen
		# MOUSE_FILTER_STOP Control that accepts every GUI event, so
		# they never fire while it is open.) The fix is a state-based
		# latch, not a timer: a combo letter registers exactly once
		# per physical press, owned by that press's source
		# (_panel_press_owner) until the matching release is seen;
		# every echo press in between is ignored, however long the
		# tap is held. A mouse press arriving while any touch owns a
		# letter IS the touch's emulated echo and is ignored whole.
		if event is InputEventScreenTouch:
			var pt := event as InputEventScreenTouch
			if pt.pressed:
				var act2: String = _claim_action_touch(pt.position)
				var letter2: String = "A" if act2 == "hop" else ("B" if act2 == "paw" else "")
				if letter2 != "" and not _panel_press_owner.has(letter2):
					_panel_press_owner[letter2] = "touch:" + str(pt.index)
					escape_panel_input(letter2)
			else:
				var owner2: String = "touch:" + str(pt.index)
				for letter3 in _panel_press_owner.keys():
					if str(_panel_press_owner[letter3]) == owner2:
						_panel_press_owner.erase(letter3)
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var pm := event as InputEventMouseButton
			if pm.pressed:
				if _panel_press_owner.is_empty():
					var act3: String = _claim_action_touch(pm.position)
					var letter4: String = "A" if act3 == "hop" else ("B" if act3 == "paw" else "")
					if letter4 != "" and not _panel_press_owner.has(letter4):
						_panel_press_owner[letter4] = "mouse"
						escape_panel_input(letter4)
			else:
				for letter5 in _panel_press_owner.keys():
					if str(_panel_press_owner[letter5]) == "mouse":
						_panel_press_owner.erase(letter5)
		return
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
		# v1.0.18 RUN FIX (Michael's S26 report: "the run button isn't
		# working" — he could never run, so every chase ended in an
		# instant capture): the RUN hold is claimed and released HERE,
		# on the raw multi-touch channel — the same channel the
		# joystick and the look drags use — instead of relying on the
		# Button's button_down/button_up signals. Those signals ride
		# the touch->mouse emulation channel (the project leaves
		# emulate_mouse_from_touch at its default true), which is a
		# SINGLE-pointer channel: while the left thumb holds the
		# joystick, the right thumb's press on RUN never reaches the
		# Button as a GUI press. Verified headless: a raw
		# InputEventScreenTouch landing square on a Button fires
		# nothing at all; only an (emulated) mouse press fires it.
		# RUN is the one control that MUST work while another finger
		# is down, so it is driven by touch index, like the joystick.
		# The Button stays as the visual and the desktop-mouse path;
		# both routes call _on_run_hold, which is idempotent, and the
		# release is matched by touch index wherever the finger lifts.
		if t.pressed:
			if state == "play" and run_touch_id == -999 and run_btn != null and run_btn.is_visible_in_tree() and run_btn.get_global_rect().has_point(t.position):
				run_touch_id = t.index
				_on_run_hold(true)
		elif t.index == run_touch_id:
			run_touch_id = -999
			_on_run_hold(false)
		# v1.0.21 HOP FIX (Michael's v1.0.20 report: "you can't jump
		# while running — you have to stop, then jump, then press
		# forward"): the A (HOP), B (PAW) and MEOW buttons had the
		# SAME disease v1.0.18 cured for RUN — they were wired only
		# to their Buttons' pressed signals, which ride the
		# single-pointer touch->mouse emulation channel, so with the
		# joystick thumb down a press on HOP never fired. (The cat's
		# physics was never the block: velocity.x/z are driven from
		# the input every physics frame, airborne included, and
		# try_hop only gates on is_on_floor — the press simply never
		# arrived.) The three momentary actions are now claimed HERE,
		# on the raw multi-touch channel, exactly like RUN: a press
		# landing on a button's live rect fires the action at once,
		# whatever else is held. The Buttons stay as the visuals and
		# the desktop-mouse path; their handlers ignore the
		# emulated-mouse echo of a tap the raw channel already fired
		# (_action_claimed_recently). A claimed press starts no
		# joystick / look drag (the rects already block look drags;
		# the claim also skips the registration below).
		var action_claimed := false
		if t.pressed:
			var act: String = _claim_action_touch(t.position)
			if act != "":
				action_claimed = true
				_fire_action(act)
		if t.pressed and not action_claimed:
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
	cam.far = 720.0 # v0.7: far plane set EXPLICITLY — distant streets, signs and houses stay drawn (v0.6 left the default and things clipped early). PERF (post-v1.0.1): 800 -> 400 when the town diagonal was ~317m. MAP DOUBLING: 720 — the doubled town's diagonal is ~539m and the relocated escape-room shell sits ~700m from the far west edge, so everything in the world still fits inside the far plane from any viewpoint; the standing ">= 400" test still passes.
	add_child(cam)
	cam.position = player.global_position + Vector3(0, 0.85, 1.75)
	cam.look_at(player.global_position + Vector3(0, _look_height(), 0), Vector3.UP)
	cam.current = true
	cam_target_pos = cam.position

func _update_camera(delta: float) -> void:
	if cam == null or player == null:
		return
	var look_target: Vector3 = player.global_position + Vector3(0, _look_height(), 0)
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
		if pound_worker != null: # POUND VAN: the chase camera frames his chases too
			var pwm2: String = str(pound_worker.get("mode"))
			if pwm2 == "chase" or pwm2 == "pursue" or pwm2 == "tell":
				var d2: float = pound_worker.global_position.distance_to(player.global_position)
				if d2 < best_d:
					best_d = d2
					nearest_chaser = pound_worker
		if nearest_chaser != null:
			chase_cam_active = true
			var cp: Vector3 = (nearest_chaser as Node3D).global_position
			# v1.0.13 PURSUIT CAMERA (Michael's v1.0.7 + v1.0.12
			# reports: after escaping, the cat is a tiny dot for the
			# WHOLE pursuit and the view only recovers when it ends).
			# Root cause, measured on the real path with
			# tests/PursuitCamProbe.tscn: the chase framing was tuned
			# for a TOWN chase, where the chaser is always within a
			# few metres (that chase ends on distance/LOS). The
			# post-escape pursuit is different — mode "pursue" runs
			# the full timer while she homes in from arbitrarily far
			# away, and the sprinting cat (11.5 vs her ~6.5) opens
			# the gap to 30 m+. The old aim lerp dragged the aim
			# point gap x 0.28 metres from the cat (8.4 m at a 30 m
			# gap) and the fixed 6.4 orbit sat behind THAT point:
			# camera ~14 m from the cat, cat at 0.03 of the frame,
			# for as long as the timer ran. (The v1.4 pitch/yaw
			# reset in _complete_escape is real and stays — pitch
			# measured 4 in every post-exit probe row; it was never
			# the cause of this.) Two bounds, both inert at
			# ordinary-chase range: (1) the aim offset toward the
			# chaser is capped at CHASE_AIM_MAX so the aim never
			# leaves the cat; (2) the orbit distance eases back to
			# the town distance as the gap passes the range where
			# she can share the frame anyway, and returns to the
			# full chase distance as she closes in. The +0.45 aim
			# raise (v1.3, keeps her overhead bar in frame) fades
			# with the same weight, so far-gap framing is exactly
			# the town framing.
			var to_chaser: Vector3 = cp - player.global_position
			to_chaser.y = 0.0
			var aim_off: Vector3 = to_chaser * 0.28
			if aim_off.length() > CHASE_AIM_MAX:
				aim_off = aim_off.normalized() * CHASE_AIM_MAX
			var close_w: float = 1.0 - smoothstep(CHASE_DIST_NEAR, CHASE_DIST_FAR, best_d)
			dist = lerpf(CAM_TOWN_DIST, CHASE_CAM_DIST, close_w)
			look_target = player.global_position + aim_off + Vector3(0, _look_height() + 0.45 * close_w, 0)
	current_cam_dist = dist
	# v1.0.20 INDOOR CAMERA (Michael's v1.0.17 play screenshot: the
	# camera jammed right up behind Zander indoors — the cat filling
	# roughly half the screen, a bare wall corner and a strip of
	# carpet, the room, the captor, the props and the back door out
	# of view). The room inherited the town's 4-degree pitch, so the
	# camera rode at ~0.7 m — furniture height — and the collision
	# pull-in below spent the whole escape squeezing it in behind
	# the cat (measured 1.68 m from him in a corner staging, 0.4 m
	# at the limit). Indoors the camera now has its own profile: a
	# closer orbit (CAM_ESCAPE_DIST 3.0), the town's wider FOV
	# (CAM_ESCAPE_FOV) and this pitch floor — the escape camera
	# never rides below CAM_ESCAPE_PITCH, so it looks down into the
	# room over the furniture instead of along the floor.
	# _enter_escape also SETS look_pitch_deg to CAM_ESCAPE_PITCH so
	# the stored value starts there; the floor covers a pitch the
	# player dragged down in town and carried through the door.
	# Outdoors nothing changes: the floor applies to "escape" only,
	# and the town/chase framing above is untouched.
	var pitch_deg: float = look_pitch_deg
	if state == "escape":
		pitch_deg = maxf(pitch_deg, CAM_ESCAPE_PITCH)
	var pitch_rad: float = deg_to_rad(pitch_deg)
	var behind: Vector3 = Basis(Vector3.UP, look_yaw) * Vector3(0, 0, 1)
	var desired: Vector3 = look_target + behind * (cos(pitch_rad) * dist) + Vector3(0, sin(pitch_rad) * dist, 0)
	desired.y = maxf(desired.y, 0.35) # never sink under the ground when looking up
	# v1.3 FOV by state: town play runs the wider 70 so people + their
	# overhead bars fit at conversational distance. v1.0.20: the
	# escape room joins it (CAM_ESCAPE_FOV) — a small room needs the
	# width more than the street does; the capture cutscene keeps
	# the 62 it was verified with.
	# (v1.0.8: the collar-zoom FOV blend is gone with the collar check.)
	if state == "cutscene":
		cam.fov = CAM_FOV
	elif state == "escape":
		cam.fov = CAM_ESCAPE_FOV
	else:
		cam.fov = CAM_TOWN_FOV
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
	if state == "cutscene" and captor != null and captor is Node3D:
		# v1.3 SCOOP CAMERA: frame the PAIR, not just the cat. The
		# plain follow cam loses him behind her body the moment she
		# turns for home (he's cradled at her chest now, not at her
		# back), so during the capture beat the shot eases to a
		# three-quarter view off her front — the bend, the lift, the
		# cradle and the walk-off all keep both of them in frame.
		# The position damp below smooths the swing; the escape
		# room's teleport snap takes over when the beat ends.
		var npc_pos: Vector3 = (captor as Node3D).global_position
		look_target = player.global_position.lerp(npc_pos, 0.38) + Vector3(0, 0.62, 0)
		var cyaw: float = (captor as Node3D).rotation.y
		var cam_dir := Vector3(sin(cyaw - 0.7), 0, cos(cyaw - 0.7))
		desired = look_target + cam_dir * 2.7 + Vector3(0, 0.95, 0)
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
	# v1.0.20 INDOOR LIFT: the pull-in above can still squeeze the
	# room camera to 0.4 m when the cat backs into a corner — and
	# the mechanisms are IN the walls (the back-door bolt, the cage
	# latch), so he works them with his back to the room, exactly
	# when he needs to see the captor coming. Indoors, a pull that
	# would pin the camera closer than CAM_ESCAPE_MIN_DIST to the
	# cat lifts it instead: straight up from the pulled (in-room)
	# point until the gap is made up, capped under the ward's
	# ceiling. The cat stays framed and the floor around him —
	# captor, props, door — opens up beneath the camera.
	var aim_target: Vector3 = look_target
	if state == "escape" and not escape_cam_active:
		if cam_pos.distance_to(look_target) < CAM_ESCAPE_MIN_DIST:
			var horiz_gap: float = Vector2(cam_pos.x - look_target.x, cam_pos.z - look_target.z).length()
			var lift_y: float = sqrt(maxf(CAM_ESCAPE_MIN_DIST * CAM_ESCAPE_MIN_DIST - horiz_gap * horiz_gap, 0.49))
			cam_pos.y = minf(maxf(cam_pos.y, look_target.y + lift_y), look_target.y + CAM_ESCAPE_LIFT_MAX)
			# A lifted camera looks down steeply, which pushes a
			# standing captor across the room out of the top of the
			# frame — the one person the player is watching for.
			# Raise the aim with the lift so she stays in frame; the
			# cat drops to the lower third, still fully readable.
			aim_target.y += (cam_pos.y - look_target.y) * 0.35
	cam.position = cam_pos
	# v1.5: 0.3 -> 0.12 — a tight dead zone, so the camera keeps
	# re-aiming during close approaches instead of holding a stale
	# angle (the old 0.3 left it un-aimed inside 0.3 of the target).
	if cam.position.distance_to(aim_target) > 0.12:
		cam.look_at(aim_target, Vector3.UP)

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
	hud_top_bar = ColorRect.new()
	hud_top_bar.color = Color(0.08, 0.1, 0.16, 0.72)
	hud_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_top_bar.size = Vector2(1280, 70)
	hud_layer.add_child(hud_top_bar)
	objective_label = _hud_label(hud_layer, "🐾 ZANDER'S RUN — Find your way home.", Vector2(16, 16), 24)
	# HUD wrap fix (v1.0.15): the header stops before the score pill
	# and wraps rather than ever running under it / off the edge.
	objective_label.anchor_right = 1.0
	objective_label.offset_right = -470
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Scoreboard (v0.7): BIGGER, on its own gold-rimmed pill, anchored
	# to the top-right of the actual screen — it was too easy to miss
	# in v0.6. The stamina bar sits under the top bar; its RED segment
	# appears only in a chase (adrenaline).
	score_pill = Panel.new()
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
	# HUD wrap fix (v1.0.15, Michael's v1.0.14 play): the band used to
	# size itself to its text, so a long message ran off BOTH edges as
	# one unreadable line. Now it spans the screen with margins and
	# wraps to at most 2 lines; the band's bottom edge is unchanged
	# and the text is bottom-aligned, so a 1-line message sits exactly
	# where it always did and a 2-line one grows upward.
	message_label.anchor_left = 0.0
	message_label.anchor_right = 1.0
	message_label.anchor_top = 1.0
	message_label.anchor_bottom = 1.0
	message_label.offset_left = 24
	message_label.offset_right = -24
	message_label.offset_top = -196
	message_label.offset_bottom = -118
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.max_lines_visible = 2
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	escape_label = _hud_label(hud_layer, "", Vector2(16, 134), 26)
	escape_label.label_settings.font_color = Color(1.0, 0.95, 0.6)
	# Same wrap fix for the ESCAPE objective line: full width with
	# margins, up to 2 lines, never off the right edge again.
	escape_label.anchor_right = 1.0
	escape_label.offset_left = 16
	escape_label.offset_right = -16
	escape_label.offset_bottom = 208
	escape_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	escape_label.max_lines_visible = 2
	# v1.0.16: none of the gameplay HUD shows behind the splash or
	# the title panel — it all appears when START is pressed.
	_set_gameplay_hud_visible(false)
	# v1.0.17 (Michael's direction): the title panel does NOT show
	# the run's home address — it is generated internally (win
	# condition, house numbering) but never displayed here. The 3D
	# tag's own face carries his NAME instead (see cat.set_tag_name,
	# called from _spawn_player).
	# v1.0.8: the old in-play COLLAR check (button + camera zoom) is
	# removed — under the new story the collar is lost before the
	# pound, so there is no mid-run re-check any more.
	title_panel = _make_panel(hud_layer, Vector2(240, 40), Vector2(800, 560), Color(0.09, 0.11, 0.2, 0.97))
	# v0.7: centre the panel on the ACTUAL screen (was fixed at
	# (240,40) of a 1280x720 design — off-centre on Michael's phone).
	# v1.0.17: the panel is shorter now that the address block is
	# gone (640 -> 560 tall); contents rebalanced below.
	title_panel.set_anchors_preset(Control.PRESET_CENTER)
	title_panel.offset_left = -400
	title_panel.offset_right = 400
	title_panel.offset_top = -280
	title_panel.offset_bottom = 280
	# v1.0.23 TITLE RESTYLE (Michael's mockup): the opaque navy
	# panel becomes frosted glass — translucent blue-grey, strongly
	# rounded corners, a pale rim and a soft drop shadow, the town
	# glowing through it at dusk.
	var tp_style := StyleBoxFlat.new()
	tp_style.bg_color = Color(0.40, 0.48, 0.64, 0.60)
	tp_style.set_corner_radius_all(36)
	tp_style.set_border_width_all(2)
	tp_style.border_color = Color(0.88, 0.92, 1.0, 0.40)
	tp_style.shadow_size = 28
	tp_style.shadow_color = Color(0.02, 0.03, 0.08, 0.45)
	tp_style.shadow_offset = Vector2(0, 8)
	title_panel.add_theme_stylebox_override("panel", tp_style)
	# Title with real paw prints flanking it (the mockup's orange
	# paws — the old brownish emoji glyphs are gone).
	var title_lbl := _hud_label(title_panel, "ZANDER'S RUN", Vector2(190, 20), 46)
	title_lbl.size = Vector2(420, 64)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for paw_x in [150.0, 594.0]:
		var paw_tr := TextureRect.new()
		if ResourceLoader.exists("res://assets/sprites/paw_print.png"):
			paw_tr.texture = load("res://assets/sprites/paw_print.png")
		paw_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paw_tr.position = Vector2(paw_x, 26); paw_tr.size = Vector2(56, 56)
		paw_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_panel.add_child(paw_tr)
	# The art (the same cover illustration as before — icon.png's
	# scene) in a rounded-corner frame: a pale rim panel behind a
	# landscape crop whose corners are rounded in the texture
	# itself (assets/sprites/title_art.png, generated from
	# icon.png). (cat.png itself is untouched — the 3D fallback in
	# _spawn_player still uses it.)
	var art_frame := Panel.new()
	var af_style := StyleBoxFlat.new()
	af_style.bg_color = Color(0.93, 0.95, 0.98, 0.85)
	af_style.set_corner_radius_all(26)
	art_frame.add_theme_stylebox_override("panel", af_style)
	art_frame.position = Vector2(54, 100); art_frame.size = Vector2(404, 256)
	title_panel.add_child(art_frame)
	var cat_tr := TextureRect.new()
	if ResourceLoader.exists("res://assets/sprites/title_art.png"):
		cat_tr.texture = load("res://assets/sprites/title_art.png")
	cat_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cat_tr.position = Vector2(59, 105); cat_tr.size = Vector2(394, 246)
	cat_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_panel.add_child(cat_tr)
	# v1.0.23: the collar-tag graphic is REMOVED (Michael's
	# mockup) — in its place a clean glowing paw-print medallion:
	# a cream disc with an orange paw and a soft warm glow, drawn
	# into assets/sprites/paw_medallion.png.
	var med_tr := TextureRect.new()
	if ResourceLoader.exists("res://assets/sprites/paw_medallion.png"):
		med_tr.texture = load("res://assets/sprites/paw_medallion.png")
	med_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	med_tr.position = Vector2(541, 140); med_tr.size = Vector2(176, 176)
	med_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_panel.add_child(med_tr)
	# v1.0.17: the "Your collar tag says your home is:" line and the
	# gold address label are REMOVED (Michael's direction) — the
	# panel now goes straight from the art row to the instructions,
	# which no longer tell the player to memorise an address.
	_hud_label(title_panel, "Find your way home — and don't let kind people\ntake you home with them.", Vector2(70, 372), 23)
	# v1.0.23: the START button gets the mockup's treatment — a
	# soft orange glow halo behind a gradient-orange pill
	# (assets/sprites/start_btn.png). The pill is a plain
	# TextureRect layered under an invisible button: a
	# StyleBoxTexture's texture margins would force the button
	# far bigger than its rect (its minimum size is the margins'
	# sum), which is exactly what the first v1.0.23 pass did.
	var glow_panel := Panel.new()
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 0.55, 0.12, 0.32)
	glow_style.set_corner_radius_all(54)
	glow_panel.add_theme_stylebox_override("panel", glow_style)
	glow_panel.position = Vector2(186, 422); glow_panel.size = Vector2(428, 108)
	glow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(glow_panel)
	var start_pill := TextureRect.new()
	if ResourceLoader.exists("res://assets/sprites/start_btn.png"):
		start_pill.texture = load("res://assets/sprites/start_btn.png")
	start_pill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	start_pill.stretch_mode = TextureRect.STRETCH_SCALE
	start_pill.position = Vector2(200, 436); start_pill.size = Vector2(400, 80)
	start_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(start_pill)
	var start_btn := Button.new()
	start_btn.focus_mode = Control.FOCUS_NONE # v1.0.22: no focus square
	start_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	start_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	start_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	start_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	if ResourceLoader.exists("res://assets/sprites/start_btn.png") and ResourceLoader.exists("res://assets/sprites/start_btn_pressed.png"):
		var pill_up: Texture2D = load("res://assets/sprites/start_btn.png")
		var pill_dn: Texture2D = load("res://assets/sprites/start_btn_pressed.png")
		start_btn.button_down.connect(func(): start_pill.texture = pill_dn)
		start_btn.button_up.connect(func(): start_pill.texture = pill_up)
	start_btn.add_theme_color_override("font_color", Color.WHITE)
	start_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	start_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	start_btn.text = "▶  START  —  Find Home!"
	start_btn.position = Vector2(200, 436)
	start_btn.size = Vector2(400, 80)
	start_btn.add_theme_font_size_override("font_size", 30)
	start_btn.pressed.connect(start_game)
	title_panel.add_child(start_btn)
	# v1.0.10: subtle build tag so Michael can confirm which build
	# he is running from the title screen itself.
	var ver := _hud_label(title_panel, "v1.0.30", Vector2(706, 522), 16)
	ver.label_settings.font_color = Color(0.78, 0.83, 0.95)
	win_panel = _make_panel(hud_layer, Vector2(290, 130), Vector2(700, 460), Color(0.12, 0.2, 0.12, 0.97))
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.offset_left = -350
	win_panel.offset_right = 350
	win_panel.offset_top = -230
	win_panel.offset_bottom = 230
	win_label = _hud_label(win_panel, "", Vector2(40, 40), 30)
	win_label.custom_minimum_size = Vector2(620, 240)
	var again := Button.new()
	again.focus_mode = Control.FOCUS_NONE # v1.0.22: no focus square
	again.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	# v1.0.14: the boot-stage readout + amber safe-mode note that
	# used to be created here (on the HUD layer, above splash AND
	# title) are removed — nothing on screen narrates the loading
	# anymore. The boot log file, the crash marker and safe mode
	# itself (sun shadows off, lamp halos skipped) all stay,
	# invisible. See _set_boot_stage / _check_boot_marker.

func _set_gameplay_hud_visible(v: bool) -> void:
	# v1.0.16: one switch for the whole gameplay HUD — top bar +
	# objective label, score pill + label, stamina bar + label and
	# the pursuit / message / escape labels. Hidden while the
	# splash and title panel are up (Michael's v1.0.15 screenshot:
	# the live HUD framed the title panel, score pill at zero, the
	# header clipped at the panel's edge); shown by start_game.
	# The nodes all stay in the tree — only visibility toggles.
	gameplay_hud_on = v
	if hud_top_bar: hud_top_bar.visible = v
	if objective_label: objective_label.visible = v
	if score_pill: score_pill.visible = v
	if score_label: score_label.visible = v
	if stamina_bg: stamina_bg.visible = v
	if stamina_fill: stamina_fill.visible = v
	if stamina_adren: stamina_adren.visible = v
	if stamina_label: stamina_label.visible = v
	if pursuit_label: pursuit_label.visible = v
	if message_label: message_label.visible = v
	if escape_label: escape_label.visible = v

# ---------------------------------------------------------------- splash (v0.6)
# A proper cute opening screen BEFORE the collar/title. It never
# shows the address — that stays on the collar close-up that
# follows. Dismiss via any tap / click or any key; dismiss_splash()
# is also what tests call.
# v1.0.14 (cover): the splash IS Michael's chosen cover art now —
# the Grok illustration with the officer's face edited kind
# (assets/sprites/splash_cover.png). The cover already carries the
# title, the "Find your way home." tagline and the TAP TO START
# pill baked into the picture, so the game draws NOTHING over it:
# the sun emoji, gold band, title/tagline labels, cat card and the
# Tap to Start BUTTON that used to be composed here are all gone.
# The whole splash is the tap target instead — _input() routes any
# tap / click during state == "splash" to dismiss_splash(), and an
# early tap still queues until the build completes (see
# dismiss_splash). The town still streams in behind the splash.
func _build_splash() -> void:
	# Anchored FULL-RECT so it fills ANY screen (v0.7 lesson: a
	# fixed 1280x720 panel sat in a corner of Michael's wider phone
	# screen with everything off-centre). The panel behind the
	# picture is a deep dusk tone, only visible as slim side bands
	# on an ultra-wide phone.
	splash_panel = _make_panel(hud_layer, Vector2(0, 0), Vector2(1280, 720), Color(0.10, 0.08, 0.18, 1.0))
	splash_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_panel.offset_left = 0
	splash_panel.offset_top = 0
	splash_panel.offset_right = 0
	splash_panel.offset_bottom = 0
	var cover := TextureRect.new()
	if ResourceLoader.exists("res://assets/sprites/splash_cover.png"):
		cover.texture = load("res://assets/sprites/splash_cover.png")
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# KEEP_ASPECT_CENTERED, not COVERED: the cover is shown EXACTLY
	# as it is — baked title at the top and baked TAP TO START at
	# the bottom can never be cropped off by a wider screen. At the
	# game's 1280x720 the art (1792x1008, the v2 cover with the
	# officer in the white uniform) fills the screen exactly;
	# wider phones get the dusk-tone side bands.
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.offset_left = 0
	cover.offset_top = 0
	cover.offset_right = 0
	cover.offset_bottom = 0
	splash_panel.add_child(cover)
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
	if not build_complete:
		# v1.0.9: the town is still streaming in behind the splash —
		# remember the tap and honour it the moment the build lands
		# (see _build_world_async), never into a half-built town.
		_splash_tap_queued = true
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
	hop_btn = _round_action("A\nHOP", Vector2(1178, 590), 92, Color(0.85, 0.3, 0.3, 0.88), func() -> void: if not _action_claimed_recently("hop"): _on_hop_pressed())
	paw_btn = _round_action("B\nPAW", Vector2(1066, 614), 84, Color(0.3, 0.45, 0.9, 0.88), func() -> void: if not _action_claimed_recently("paw"): _on_interact())
	meow_btn = _round_action("MEOW", Vector2(1146, 492), 70, Color(0.55, 0.4, 0.85, 0.85), func() -> void: if not _action_claimed_recently("meow"): _on_meow())
	run_btn = _round_hold("RUN", Vector2(1062, 492), 70, Color(0.35, 0.38, 0.42, 0.85), _on_run_hold)
	_refresh_run_button()
	# RUN button (Michael's direction, superseding v0.7's
	# push-to-sprint): a MOMENTARY hold button beside MEOW, in the
	# spot the COLLAR button used to occupy. v1.0.13 shipped it as a
	# press-to-toggle; Michael played that and reversed it the same
	# day (v1.0.14): "you only run when it's pressed" — hold RUN =
	# run, let go = walk. The joystick alone NEVER sprints now (a
	# full push "rocketed off"). The button's fill IS the state:
	# grey = not held, green = held; the text always stays "RUN"
	# (_refresh_run_button). NO Map button — mini-map removed.
	# v1.0.8: NO COLLAR button either — the collar check is removed
	# entirely (the collar is lost before the pound in the new story).
	# Presses starting on a button never start a look drag; the live
	# button rects are checked in _look_press_blocked.
	# v1.0.8: NO on-screen LOOK button (Michael: "We don't need the
	# look button"). The old indicator was display-only anyway
	# (mouse_filter IGNORE) — dragging anywhere on the right half of
	# the screen (off the action buttons) is what looks around, via
	# _input / apply_look_drag, and that path is unchanged. The
	# start-of-run hint below still explains the drag.
	# Start-of-run hint (fades after ~7 seconds of play).
	hint_label = _hud_label(touch_layer, "🐾 LEFT side: touch & drag to MOVE — HOLD RUN to run!\n👀 RIGHT side: drag to LOOK — tilt UP to read the street signs!", Vector2(330, 92), 26)
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
	escape_prompt_btn.focus_mode = Control.FOCUS_NONE # v1.0.22: no focus square
	escape_prompt_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	distract_label.offset_left = -500.0
	distract_label.offset_right = 500.0
	distract_label.offset_top = 178.0
	distract_label.offset_bottom = 218.0
	distract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# HUD wrap fix (v1.0.15): the status line's text is wider than
	# the old 860px box — widen the box and let it wrap inside it.
	distract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	distract_bar_bg.offset_top = 220.0
	distract_bar_bg.offset_bottom = 232.0
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
	prop_prompt_btn.focus_mode = Control.FOCUS_NONE # v1.0.22: no focus square
	prop_prompt_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	# THE PANEL (scripts/escape_panel.gd): picture + combo + A/B buttons.
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
	b.focus_mode = Control.FOCUS_NONE # v1.0.22: no square outline / focus box on any touch button
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	b.focus_mode = Control.FOCUS_NONE # v1.0.22: no square outline / focus box on any touch button
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.text = text
	# Same bottom-right anchoring and action-button registration as
	# _round_action (pos is the old 1280x720 design position), so a
	# hold button sits and blocks look-drags identically — only the
	# signal wiring differs (down/up instead of pressed).
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
	b.button_down.connect(func() -> void: on_hold.call(true))
	b.button_up.connect(func() -> void: on_hold.call(false))
	touch_layer.add_child(b)
	action_buttons.append(b)
	return b

func _on_hop_pressed() -> void:
	if player:
		player.try_hop()

# v1.0.21: the raw-touch claim for the momentary action buttons
# (see the v1.0.21 note in _input). Returns the action a press at
# `pos` lands on ("" = none). The buttons are live-rect checked,
# exactly like _look_press_blocked.
func _claim_action_touch(pos: Vector2) -> String:
	if hop_btn != null and hop_btn.is_visible_in_tree() and hop_btn.get_global_rect().has_point(pos):
		return "hop"
	if paw_btn != null and paw_btn.is_visible_in_tree() and paw_btn.get_global_rect().has_point(pos):
		return "paw"
	if meow_btn != null and meow_btn.is_visible_in_tree() and meow_btn.get_global_rect().has_point(pos):
		return "meow"
	return ""

func _fire_action(action: String) -> void:
	_action_echo_latch[action] = true # v1.0.24: this tap's Button-signal echo is still to come — the handler will consume the latch and stand down (see _action_claimed_recently)
	match action:
		"hop": _on_hop_pressed()
		"paw": _on_interact()
		"meow": _on_meow()

func _action_claimed_recently(action: String) -> bool:
	# v1.0.24: STATE-based (was v1.0.21's 150 ms timer). The raw
	# touch claim latches the action in _fire_action; the Button's
	# own pressed handler — the emulated-mouse echo of the same tap,
	# which Godot delivers on RELEASE — consumes the latch and
	# stands down, so one physical tap fires the action exactly once
	# however long it was held (a slow tap outlasted the old timer
	# and its echo fired the action a second time). A handler call
	# with no latch set is a genuine mouse click and fires normally.
	if bool(_action_echo_latch.get(action, false)):
		_action_echo_latch.erase(action)
		return true
	return false

func _on_sprint_hold(p: bool) -> void:
	# Legacy hold-style setter (pre-v1.0.13 Sprint button remnant).
	# Kept so any old driver setting touch_sprint through main still
	# works — it now routes through the RUN hold handler so the
	# button's held state and fill stay in sync.
	_on_run_hold(p)

func _on_run_hold(p: bool) -> void:
	# v1.0.14: RUN is MOMENTARY — hold to run, release to walk.
	# (v1.0.13 shipped Michael's press-to-toggle; he played it and
	# reversed it the same day: "I want it to be momentary. You
	# press it and you're running while you press it… you only run
	# when it's pressed.") The press only engages in play; the
	# RELEASE always clears, even if the state changed mid-hold
	# (e.g. a capture while holding RUN), so the flag can never
	# stick on. The stamina/winded gate in cat.gd is untouched: an
	# empty pool still drops the cat to walk while held, and sprint
	# resumes on recovery for as long as he keeps holding.
	if p:
		if state != "play" or player == null:
			return
		run_on = true
	else:
		run_on = false
	if player:
		player.set("touch_sprint", run_on)
	_refresh_run_button()

func _refresh_run_button() -> void:
	if run_btn == null:
		return
	# Michael's refinement: the label NEVER changes — it always says
	# "RUN". Green fill alone means the button is HELD; the normal
	# grey fill means it is not.
	run_btn.text = "RUN"
	if run_on:
		var on_style := _round_style(Color(0.22, 0.72, 0.28, 0.95), 70)
		run_btn.add_theme_stylebox_override("normal", on_style)
		run_btn.add_theme_stylebox_override("hover", on_style)
		run_btn.add_theme_stylebox_override("pressed", _round_style(Color(0.3, 0.85, 0.35, 0.95), 70))
	else:
		var off_style := _round_style(Color(0.35, 0.38, 0.42, 0.85), 70)
		run_btn.add_theme_stylebox_override("normal", off_style)
		run_btn.add_theme_stylebox_override("hover", off_style)
		run_btn.add_theme_stylebox_override("pressed", _round_style(Color(0.45, 0.48, 0.52, 0.85), 70))

func _apply_joystick() -> void:
	if player == null:
		return
	# v1.0.14: RUN is momentary — if play ends mid-hold (capture,
	# escape, win) and a button_up never reaches the hidden button,
	# force the release here so touch_sprint can never stick on.
	# v1.0.18: the touch claim gets the same treatment — a release
	# swallowed by the state change must not mute the next RUN press.
	if state != "play" and (run_on or run_touch_id != -999):
		run_on = false
		run_touch_id = -999
		player.set("touch_sprint", false)
		_refresh_run_button()
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
	_title_stable_t = 0.0 # v1.0.10: arm the crash-marker completion timer (see _process)
	_boot_write_marker("title")
	_boot_log("title shown")
	if player:
		player.set("frozen", true)

func start_game() -> void:
	if not build_complete:
		return # v1.0.9: play is never enterable into a half-built town
	# v1.0.10: reaching play is proof the boot succeeded — complete
	# the crash marker even if the 2 s title timer hasn't fired yet.
	_boot_write_marker("complete")
	_boot_log("Ready (play started)")
	_title_stable_t = -1.0
	title_panel.visible = false
	_set_gameplay_hud_visible(true) # v1.0.16: the gameplay HUD arrives with the run
	touch_layer.visible = true
	if splash_song_player and splash_song_player.playing:
		splash_song_player.stop()
	if music.stream:
		var wav := music.stream as AudioStreamWAV
		if wav:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		music.play()
	# STORY PART 1: START no longer drops the cat straight into
	# town — the opening cutscene plays first (he leaves home,
	# loses his collar, the pound van takes him in) and the run
	# proper begins with the pound escape. The module owns that
	# flow; if it is somehow absent, fall back to the old
	# straight-to-play start so START can never soft-lock.
	if story and story.has_method("begin_opening"):
		story.call("begin_opening")
	else:
		state = "play"
		if player:
			player.set("frozen", false)
		if hint_label:
			hint_label.visible = true
		hint_timer = 7.0
		show_message("Find home: the address from your collar tag. Avoid lingering near people!", 5.0)

func show_message(text: String, seconds: float = 3.0) -> void:
	# One message at a time: if a message is already on screen, this
	# one waits in the queue and takes its turn when the band frees
	# up — messages never overwrite or stack on each other. The
	# queue stays short (the two oldest waiters are the most the
	# game ever lines up; beyond that the stalest waiter is dropped).
	if message_timer > 0.0 and message_label.text != "":
		if message_queue.size() >= 2:
			message_queue.pop_front()
		message_queue.append({"text": text, "seconds": seconds})
		return
	message_label.text = text
	message_timer = seconds

func release_held_escape_message() -> void:
	# Called by the opening module the moment the cage gate opens:
	# the escape-room instructions held back at pound entry now take
	# their turn in the message band (queued behind the gate's own
	# message, never stacked on it).
	if held_escape_message != "":
		var t: String = held_escape_message
		var s: float = held_escape_seconds
		var t2: String = held_escape_message_2
		var s2: float = held_escape_seconds_2
		held_escape_message = ""
		held_escape_message_2 = ""
		show_message(t, s)
		if t2 != "":
			# Beat 2 takes its turn right behind beat 1 through the
			# ordinary queue — never stacked on it.
			show_message(t2, s2)

func clear_message_band() -> void:
	# Chapter break: empty the message band and its queue at once.
	# Used when the opening deposits the cat in the pound cage —
	# the ride-over line's turn is done, and from that moment the
	# cage prompt is the only instruction on screen.
	message_queue.clear()
	message_timer = 0.0
	message_label.text = ""

func _cat_caged() -> bool:
	# STORY PART 1: while the opening has the cat shut in the pound
	# cage (or the capture that puts him there is still inbound),
	# the cage prompt is the ONLY instruction on screen — the escape
	# header and the distraction line stay hidden until the gate
	# opens.
	return story != null and story.has_method("cage_active") and bool(story.call("cage_active"))

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
	# v1.0.26 (Michael's ask): town cats in earshot MEOW BACK.
	for tc in town_cats:
		if (tc as Node3D).global_position.distance_to(player.global_position) < 6.5:
			tc.call("meow_back")
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
	# v1.0.26 (Michael's ask): pawing AT a town cat starts a
	# play session — the cat rolls over and plays; a completed
	# session scores +3 once per cat per run (see town_cat.gd).
	# The cat must be the closest thing pawed: a nearer person
	# keeps the existing person interaction.
	var best_cat: Node = null
	var best_cat_d: float = 2.6
	for tc in town_cats:
		var cd: float = (tc as Node3D).global_position.distance_to(player.global_position)
		if cd < best_cat_d:
			best_cat_d = cd
			best_cat = tc
	if best_cat != null and (best == null or best_cat_d < best_d):
		if bool(best_cat.call("start_play")):
			show_message("🐱 Play time!", 1.4)
		return
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
	if npc == pound_worker:
		show_message("🚐 The pound worker spotted you: \"There you are! Let's get you home!\" — RUN!", 2.4)
	else:
		show_message("❗ " + str(npc.get("display_name")) + ": \"Here, kitty kitty!\" — RUN!", 2.2)

# ---------------------------------------------------------------- traffic (v0.7)
const TRAFFIC_ROADS_H: Array = [-55.0, -11.0, 15.0, 55.0] # z of the horizontal roads
const TRAFFIC_ROADS_V: Array = [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0] # MAP DOUBLING: + the five east cross streets # x of the vertical roads

# BISECT (v1.0.12): the vertical traffic streets actually in use —
# the legacy four when LEGACY_TOWN_ONLY, all nine otherwise. Used
# by traffic spawning and by the pound van's pull-over logic.
func _traffic_roads_v() -> Array:
	return [-70.0, -20.0, 24.0, 72.0] if LEGACY_TOWN_ONLY else TRAFFIC_ROADS_V

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
		node = _build_car(traffic_group, Vector3((124.0 if LEGACY_TOWN_ONLY else 382.0) if dir_sign < 0.0 else (-124.0 if LEGACY_TOWN_ONLY else -130.0), 0, lane), cols[rng.randi_range(0, cols.size() - 1)], true, types[rng.randi_range(0, types.size() - 1)], true) # MAP DOUBLING: spawn just off the new edges (BISECT: just off the legacy edges in legacy mode)
		node.rotation_degrees = Vector3(0, 0.0 if dir_sign > 0.0 else 180.0, 0)
		vel = Vector3(speed * dir_sign, 0, 0)
	else:
		var v_roads: Array = _traffic_roads_v() # BISECT (v1.0.12): legacy cross streets only in legacy mode
		var rx: float = v_roads[rng.randi_range(0, v_roads.size() - 1)]
		var lane2: float = rx + (-1.8 if dir_sign > 0.0 else 1.8)
		node = _build_car(traffic_group, Vector3(lane2, 0, -90.0 * dir_sign), cols[rng.randi_range(0, cols.size() - 1)], true, types[rng.randi_range(0, types.size() - 1)], true)
		node.rotation_degrees = Vector3(0, -90.0 if dir_sign > 0.0 else 90.0, 0)
		vel = Vector3(0, 0, speed * dir_sign)
	traffic_cars.append({"node": node, "vel": vel})
	return node

func _process_traffic(delta: float) -> void:
	if traffic_group == null:
		return # v1.0.9: no world yet — traffic starts once the build lands
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
		if n.position.x > (126.0 if LEGACY_TOWN_ONLY else 384.0) or n.position.x < (-126.0 if LEGACY_TOWN_ONLY else -132.0) or absf(n.position.z) > 93.0: # MAP DOUBLING: east despawn moved with the border (BISECT: legacy borders in legacy mode)
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

# ---------------------------------------------------------------- pound van (Michael, 2026-11-17)
func _build_pound_depot() -> void:
	# v1.0.21: the pound's home — an open-front GARAGE BAY with the
	# shelter office attached, on the north side of the z=15 road at
	# the west end of town (the patrol route's end). The bay faces
	# the road (opening toward +z); the van parks facing north at
	# POUND_HOME_POS. Geometry is plain boxes in the town's own
	# build language; the solid pieces register their XZ rects in
	# pound_depot_solids for the suite's van audit. Clearances
	# (audited headless against every building AABB in the town):
	# the backdrop block to the west ends at x=-121, 7 Oak Avenue's
	# walls start at x=-101.8, the Maple road corridor starts at
	# z=-7.4 — the depot (x -120.3..-105, z -6.1..11.5) touches none.
	var world_node := get_node("World")
	var depot := Node3D.new()
	depot.name = "PoundDepot"
	world_node.add_child(depot)
	var wall_col := Color(0.88, 0.86, 0.82) # shelter-block off-white, kin to the ward inside
	var trim_col := Color(0.10, 0.30, 0.55) # the van's own blue
	var roof_col := Color(0.32, 0.34, 0.38)
	# The apron: concrete from the road's edge to the bay mouth.
	_box(depot, Vector3(-112, 0.03, 6.5), Vector3(14.0, 0.06, 10.0), Color(0.62, 0.62, 0.64))
	# Bay walls (interior x -114.6..-109.4, z -5.4..1.6).
	_box(depot, Vector3(-114.85, 1.65, -1.9), Vector3(0.5, 3.3, 7.5), wall_col, true) # west wall
	_box(depot, Vector3(-109.15, 1.65, -1.9), Vector3(0.5, 3.3, 7.5), wall_col, true) # east wall
	_box(depot, Vector3(-112, 1.65, -5.65), Vector3(6.2, 3.3, 0.5), wall_col, true) # back wall
	_box(depot, Vector3(-112, 3.45, -1.9), Vector3(6.7, 0.3, 8.4), roof_col) # roof slab
	_box(depot, Vector3(-112, 2.95, 1.75), Vector3(6.7, 0.7, 0.5), trim_col) # header over the opening (clear height below it: 2.6 — the van is 2.2)
	_box(depot, Vector3(-114.85, 0.5, 1.85), Vector3(0.5, 1.0, 0.5), trim_col) # mouth posts
	_box(depot, Vector3(-109.15, 0.5, 1.85), Vector3(0.5, 1.0, 0.5), trim_col)
	# The shelter office, attached on the west side.
	_box(depot, Vector3(-117.6, 1.5, -1.9), Vector3(5.4, 3.0, 7.5), Color(0.80, 0.78, 0.74), true)
	_box(depot, Vector3(-117.6, 3.15, -1.9), Vector3(6.0, 0.3, 8.1), roof_col) # office roof slab
	_box(depot, Vector3(-117.6, 1.15, 1.87), Vector3(1.0, 2.3, 0.06), Color(0.35, 0.25, 0.16), true) # office door (front face)
	_box(depot, Vector3(-119.3, 1.8, 1.87), Vector3(1.3, 0.9, 0.06), Color(0.72, 0.87, 0.95)) # office window
	_box(depot, Vector3(-115.9, 1.8, 1.87), Vector3(1.3, 0.9, 0.06), Color(0.72, 0.87, 0.95))
	# Signs the player can read from the road.
	_label3d(depot, "POUND", Vector3(-112, 2.95, 2.35), 72, Color(0.85, 0.92, 1.0))
	_label3d(depot, "🐾 ANIMAL SHELTER", Vector3(-117.6, 2.55, 2.3), 54, Color(0.15, 0.33, 0.3))
	pound_depot_solids = [
		Rect2(-115.1, -5.65, 0.5, 7.5), # bay west wall
		Rect2(-109.4, -5.65, 0.5, 7.5), # bay east wall
		Rect2(-115.1, -5.9, 6.2, 0.5), # bay back wall
		Rect2(-120.3, -5.65, 5.4, 7.5), # the office block
	]

func _build_pound_van_bar() -> void:
	# v1.0.21: the being-noticed meter over the VAN — the same rig
	# person.gd builds over a grabber's head (frame + track + yellow
	# fill, BAR_W x BAR_H), riding above the roof while the worker
	# is inside. Once he is on foot, his own bar takes over (main
	# mirrors pound_notice onto him — see _pound_update_notice).
	pound_bar_root = Node3D.new()
	pound_bar_root.position = Vector3(0, 2.85, 0)
	pound_bar_root.visible = false
	pound_van.add_child(pound_bar_root)
	var frame := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(2.13, 0.32)
	frame.mesh = fq
	frame.material_override = _pound_bar_material(Color(0.03, 0.03, 0.05, 0.92))
	pound_bar_root.add_child(frame)
	var track := MeshInstance3D.new()
	var tq := QuadMesh.new()
	tq.size = Vector2(2.05, 0.24)
	track.mesh = tq
	track.position.z = 0.006
	track.material_override = _pound_bar_material(Color(0.23, 0.20, 0.16, 0.95))
	pound_bar_root.add_child(track)
	pound_bar_fill = MeshInstance3D.new()
	var iq := QuadMesh.new()
	iq.size = Vector2(1.0, 0.18)
	pound_bar_fill.mesh = iq
	pound_bar_fill.position.z = 0.012
	pound_bar_fill.material_override = _pound_bar_material(Color(1.0, 0.85, 0.3))
	pound_bar_root.add_child(pound_bar_fill)
	pound_bar_label = Label3D.new()
	pound_bar_label.text = ""
	pound_bar_label.font_size = 44
	pound_bar_label.pixel_size = 0.009
	pound_bar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pound_bar_label.position = Vector3(0, 0.52, 0)
	pound_bar_label.modulate = Color(1.0, 0.85, 0.3)
	pound_bar_label.outline_size = 8
	pound_bar_root.add_child(pound_bar_label)

func _pound_bar_material(c: Color) -> StandardMaterial3D:
	# person.gd's bar material recipe (unshaded, double-sided,
	# no depth test so the meter reads through the van roof line).
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _update_pound_van_bar() -> void:
	# Show/aim the van's notice meter for the CURRENT pound_notice.
	# Visible only while he rides (patrol / the depot legs with a
	# meter up — in practice patrol) and through the pull-over and
	# getting-out beats at full; hidden once his own bar takes over.
	if pound_bar_root == null:
		return
	var show: bool = pound_notice > 0.03 and (pound_state == "patrol" or pound_state == "pullover" or pound_state == "exit")
	pound_bar_root.visible = show
	if not show:
		return
	pound_bar_label.text = "👀"
	var f: float = clampf(pound_notice, 0.0, 1.0)
	pound_bar_fill.scale = Vector3(maxf(2.05 * f, 0.001), 1.0, 1.0)
	pound_bar_fill.position.x = -2.05 * 0.5 + 2.05 * f * 0.5
	# Yaw-face the camera, like person.gd's bar (the van's own yaw
	# must not swing the meter away from the player).
	var cam3d := get_viewport().get_camera_3d()
	if cam3d:
		var cp := cam3d.global_position
		var bp := pound_bar_root.global_position
		pound_bar_root.global_rotation = Vector3(0, atan2(cp.x - bp.x, cp.z - bp.z), 0)

# v1.0.25: the flashing light bar and the two-tone siren are
# REMOVED ENTIRELY (Michael, 2026-11-19, reversing his v1.0.21/22
# request: they "are not working, it's really weird — just get
# rid of it"). _build_pound_light_rig, _pound_lights_active and
# _pound_update_lights are gone, the lamp nodes are never built,
# and there is no siren player. The Meshy van's own moulded roof
# bar stays as unlit model geometry. The proximity NOTICE METER
# behaviour is unchanged — it just no longer lights or sounds
# anything.

func _spawn_pound() -> void:
	# The patrol circuit: one right-hand loop around the whole
	# town, driven on the traffic lanes (lane offsets as in
	# spawn_traffic_car): east along the z=15 road, north up
	# Sunset Drive (x=320), west along the z=-55 road, south down
	# the x=-70 road, and around again — forever.
	if LEGACY_TOWN_ONLY:
		# BISECT (v1.0.12): the same circuit on the legacy streets —
		# east along the z=15 road, north up Riverside Drive (x=72),
		# west along the z=-55 road, south down Pine Street (x=-70).
		pound_route = [
			Vector3(-116.0, 0, 16.8),
			Vector3(73.8, 0, 16.8),
			Vector3(73.8, 0, -56.8),
			Vector3(-71.8, 0, -56.8),
			Vector3(-71.8, 0, 16.8),
		]
	else:
		pound_route = [
			Vector3(-116.0, 0, 16.8),
			Vector3(321.8, 0, 16.8),
			Vector3(321.8, 0, -56.8),
			Vector3(-71.8, 0, -56.8),
			Vector3(-71.8, 0, 16.8),
		]
	pound_route_idx = 1
	pound_van = _build_car(traffic_group, pound_route[0], Color(0.96, 0.96, 0.94), true, "pound", true)
	pound_van.name = "PoundVan"
	pound_van_yaw = 0.0
	pound_van.rotation.y = 0.0
	# v1.0.30: the code-added blue Label3D lettering on the van's
	# flanks ("POUND" / "ANIMAL CONTROL", both sides) is REMOVED
	# ENTIRELY (Michael, 2026-11-20, from his v1.0.29 play
	# screenshot: the letters floated over/through the body at a
	# wildly wrong scale). The Meshy van's own texture already
	# carries ANIMAL CONTROL lettering and a paw print — the van
	# needs no labels of ours. The depot's POUND header sign is a
	# separate static and stays.
	await _build_frame() # v1.0.11 chunking: van build and worker build are two chunks, not one ~112 ms stretch
	# The worker: a person.gd "poundworker" (white uniform, cap,
	# net in hand) with the grabber role, so his chase, grab and
	# capture ARE the game's own machinery. He is NOT one of the
	# 48 town NPCs — never added to npcs, so the population and
	# its 25% avoid-share are exactly as they were. Main drives
	# him (active = false) except while he is chasing / pursuing,
	# when his own brain takes over.
	pound_worker = CharacterBody3D.new()
	pound_worker.set_script(PersonScript)
	pound_worker.set("npc_type", "poundworker")
	pound_worker.set("role", "grabber")
	pound_worker.set("outfit_idx", 0)
	pound_worker.set("wide_bounds", true)
	pound_worker.position = pound_route[0] + Vector3(0, 0.15, 0)
	add_child(pound_worker)
	pound_worker.set("main_ref", self)
	pound_worker.set("player_ref", player)
	pound_worker.set("active", false)
	pound_worker.visible = false
	_build_pound_van_bar() # v1.0.21: the notice meter over the van

func _pound_forward() -> Vector3:
	return Vector3(cos(pound_van_yaw), 0, -sin(pound_van_yaw))

func _pound_pin_worker() -> void:
	# Riding: he travels inside the van, unseen, until he gets out.
	pound_worker.global_position = pound_van.position + Vector3(0, 0.15, 0)

func _pound_drive_route(delta: float, cruise: float) -> void:
	var target: Vector3 = pound_route[pound_route_idx]
	var to: Vector3 = target - pound_van.position
	to.y = 0.0
	if to.length() < 7.0:
		pound_route_idx = (pound_route_idx + 1) % pound_route.size()
		target = pound_route[pound_route_idx]
		to = target - pound_van.position
		to.y = 0.0
	var want_yaw: float = atan2(-to.z, to.x)
	pound_van_yaw = lerp_angle(pound_van_yaw, want_yaw, minf(1.0, 1.15 * delta))
	var turn_gap: float = absf(angle_difference(pound_van_yaw, want_yaw))
	var spd: float = cruise * clampf(1.15 - turn_gap, 0.45, 1.0)
	# A careful driver: if the cat is standing in the road just
	# ahead and the worker is NOT getting out (the cat is hidden,
	# on cooldown, or someone else is already after him), the van
	# stops and waits rather than driving through him.
	if player and state == "play":
		var rel: Vector3 = player.global_position - pound_van.position
		rel.y = 0.0
		var fwd: Vector3 = _pound_forward()
		var ahead: float = rel.dot(fwd)
		var side: float = rel.dot(Vector3(-fwd.z, 0, fwd.x))
		if ahead > 0.5 and ahead < 5.0 and absf(side) < 1.7:
			spd = 0.0
	pound_van_speed = move_toward(pound_van_speed, spd, (7.0 if spd < pound_van_speed else 3.5) * delta)
	pound_van.position += _pound_forward() * pound_van_speed * delta
	pound_van.rotation.y = pound_van_yaw

func _pound_gates_open() -> bool:
	# THE COLLAR FLAG (player_collared): while the cat has a collar
	# on, the worker never engages — story mode will set the flag
	# when the cat is collared again. It defaults to false.
	if player_collared:
		return false
	if pound_engage_cd > 0.0:
		return false
	if player == null:
		return false
	if bool(player.get("is_hidden")):
		return false # a cat he can't see is a cat he can't help
	if not pursuers.is_empty():
		return false # someone is already looking for the cat
	for n in npcs:
		var m: String = str(n.get("mode"))
		if m == "chase" or m == "pursue" or m == "tell":
			return false # never pile his chase onto one already running
	return true

func _pound_update_notice(delta: float) -> void:
	# v1.0.21: the officer notices the cat the way every grabber
	# does (Michael: "it should be just like one of those people who
	# wants to take me home. If I'm around the van or the animal
	# control person either or, the things should start and the guy
	# should start chasing me"). Runs in the two states where he can
	# still be SPOTTED rather than already engaging: "patrol" (he is
	# riding in the van — proximity to the VAN counts and the meter
	# shows over the van) and "return" (he is on foot walking back —
	# proximity to HIM counts and the meter shows over his own head,
	# mirrored onto his notice var for his own bar rig). The sight
	# maths are person.gd's own: detect_radius range, house
	# line-of-sight, a fill rate scaled by closeness, slower against
	# a sprinting cat, decay when unseen — with detect_radius /
	# fill_rate read off his own poundworker definition, so he
	# notices exactly like a grabber person does. (His line-of-sight
	# check measures from wherever HE stands, and while he rides he
	# is pinned at the van, so the van's sight lines come free.)
	# Only a FULL meter starts the old flow: the pull-over (from
	# patrol) or the re-engage (from return) — and the existing exit
	# beat then hands him to his own brain for the RUN tell and the
	# chase. Before v1.0.21 there was NO meter at all: stepping
	# inside a bare 12 m radius slammed him straight out of the van,
	# and on foot nothing built up at all.
	if pound_worker == null or pound_van == null or player == null:
		return
	if pound_state != "patrol" and pound_state != "return":
		return
	# His notice_cooldown is a real gate (a chase end sets 3 s of
	# it) — but while MAIN drives him his brain is off, so the
	# cooldown would never tick down and the gate would stay shut
	# forever after his first chase. Main ticks it down here,
	# exactly as his own brain would if it were running.
	if float(pound_worker.get("notice_cooldown")) > 0.0:
		pound_worker.set("notice_cooldown", maxf(0.0, float(pound_worker.get("notice_cooldown")) - delta))
	var gates: bool = _pound_gates_open() and float(pound_worker.get("notice_cooldown")) <= 0.0
	var anchor: Vector3 = pound_van.global_position if pound_state == "patrol" else (pound_worker as Node3D).global_position
	var d3: Vector3 = player.global_position - anchor
	d3.y = 0.0
	var dist: float = d3.length()
	var sight: float = float(pound_worker.get("detect_radius"))
	var seen: bool = false
	if gates and dist < sight and not bool(player.get("is_hidden")):
		seen = bool(pound_worker.call("_has_line_of_sight")) # person.gd's LOS takes NO argument (it reads his own player_ref) — passing one makes call() fail and return null, which reads as "never seen"
	if seen:
		var closeness: float = clampf(1.0 - dist / sight, 0.0, 1.0)
		var rate: float = float(pound_worker.get("fill_rate")) * (0.35 + closeness * 0.95)
		if bool(player.get("is_sprinting")): # the cat's var is is_sprinting — a wrong name here returns null, and bool(null) THROWS, aborting the whole update
			rate *= 0.55
		pound_notice = minf(1.0, pound_notice + rate * delta)
	else:
		pound_notice = maxf(0.0, pound_notice - 0.55 * delta)
	if pound_state == "return":
		pound_worker.set("notice", pound_notice) # his own bar draws from this...
		pound_worker.call("_update_labels") # ...but his brain is OFF while main drives him (active=false freezes person.gd whole, labels included), so main refreshes his label rig directly
	_update_pound_van_bar()
	if pound_notice >= 1.0:
		if pound_state == "patrol":
			pound_heading_home = false # an engagement interrupts the drive home
			_pound_begin_pullover()
		else:
			# The same re-engage the old instant spot produced: he
			# turns on the cat where he stands.
			pound_worker.set("active", true)
			pound_worker.set("notice", 1.0)
			pound_worker.call("_start_chase") # no argument — see the LOS note above
			pound_state = "chase"
			_pound_reset_return_watch()
			pound_notice = 0.0

func _pound_begin_pullover() -> void:
	# Pull to the kerb on HIS side of the road he is on, rolling a
	# little way forward as he stops — parallel to the kerb at the
	# asphalt's edge (offset 2.75 of a 3.6 half-width), clear of
	# the road centre and of the far lane.
	var fwd: Vector3 = _pound_forward()
	if absf(fwd.x) > absf(fwd.z):
		var centre: float = TRAFFIC_ROADS_H[0]
		var bd: float = 1e9
		for rz in TRAFFIC_ROADS_H:
			if absf(pound_van.position.z - rz) < bd:
				bd = absf(pound_van.position.z - rz)
				centre = rz
		var side_sign: float = signf(pound_van.position.z - centre)
		if side_sign == 0.0:
			side_sign = 1.0
		pound_stop_pos = pound_van.position + fwd * 6.0
		pound_stop_pos.z = centre + side_sign * 2.75
		pound_kerb_dir = Vector3(0, 0, side_sign)
	else:
		var v_roads2: Array = _traffic_roads_v() # BISECT (v1.0.12): nearest cross street among the streets that exist
		var centre2: float = v_roads2[0]
		var bd2: float = 1e9
		for rx in v_roads2:
			if absf(pound_van.position.x - rx) < bd2:
				bd2 = absf(pound_van.position.x - rx)
				centre2 = rx
		var side_sign2: float = signf(pound_van.position.x - centre2)
		if side_sign2 == 0.0:
			side_sign2 = 1.0
		pound_stop_pos = pound_van.position + fwd * 6.0
		pound_stop_pos.x = centre2 + side_sign2 * 2.75
		pound_kerb_dir = Vector3(side_sign2, 0, 0)
	pound_stop_pos.y = 0.0
	pound_stop_yaw = pound_van_yaw
	pound_state = "pullover"

func _pound_drive_pullover(delta: float) -> void:
	var to: Vector3 = pound_stop_pos - pound_van.position
	to.y = 0.0
	var dist: float = to.length()
	# Arrive: close enough, OR the stop point has slipped behind
	# the front bumper on the final approach (snapping the last
	# step of a park is invisible at these speeds). Aiming straight
	# at the point the whole way in keeps the approach a gentle
	# diagonal; the snap squares him to the road at the end.
	# (An earlier version blended the heading onto the road
	# direction during the approach and could circle the stop
	# point forever, never arriving.)
	if dist < 0.8 or (dist < 2.0 and to.dot(_pound_forward()) < 0.0):
		pound_van.position = pound_stop_pos
		pound_van_yaw = pound_stop_yaw
		pound_van.rotation.y = pound_van_yaw
		pound_van_speed = 0.0
		_pound_worker_out()
		return
	var want_yaw: float = atan2(-to.z, to.x)
	pound_van_yaw = lerp_angle(pound_van_yaw, want_yaw, minf(1.0, 2.2 * delta))
	pound_van_speed = move_toward(pound_van_speed, clampf(dist * 0.8, 0.35, 4.2), 8.0 * delta)
	pound_van.position += _pound_forward() * pound_van_speed * delta
	pound_van.rotation.y = pound_van_yaw

func _pound_door_pos() -> Vector3:
	# Where he stands when he gets out / climbs back in: beside
	# the cab, on the kerb side of the parked van.
	return pound_van.position + _pound_forward() * 0.9 + pound_kerb_dir * 1.7 + Vector3(0, 0.2, 0)

func _pound_worker_out() -> void:
	pound_state = "exit"
	pound_exit_t = 0.75
	pound_worker.global_position = _pound_door_pos()
	pound_worker.rotation.y = atan2(pound_kerb_dir.x, pound_kerb_dir.z)
	pound_worker.visible = true
	var m = pound_worker.get("model")
	if m:
		(m as Node3D).visible = true
	pound_worker.call("set_expression", "happy")

func _pound_clear_label() -> void:
	var nl = pound_worker.get("notice_label")
	if nl:
		(nl as Label3D).text = ""

func _pound_reset_return_watch() -> void:
	# POUND RETURN FIX: (re)arm the stuck watch — called whenever a
	# return begins, ends, or is interrupted by a re-engagement.
	pound_return_best = INF
	pound_return_still_t = 0.0
	pound_return_stuck_total = 0.0
	pound_return_sidesteps = 0
	pound_return_dodge_t = 0.0
	pound_return_has_target = false

func _pound_return_target(door: Vector3) -> Vector3:
	# POUND RETURN FIX (2026-11-17): where the walk back to the van
	# should aim this frame. The old routing walked him straight at
	# the door (routing around the nose only from the road side),
	# and from behind the van that line presses him onto the rear
	# face — he wedged on its corner for good, pound_state stuck at
	# "return", patrol dead for the session; from deep in a front
	# yard the same straight line speared him on fences/flowerbeds
	# short of the door. Now every side gets the nose rule's
	# treatment: waypoints on the KERB CORRIDOR line (the door's own
	# line, lat 1.7 — clear of the flank, inside the fence line),
	# picked by where he stands in van space (lon = along the van,
	# + = ahead of the nose; lat = toward the kerb).
	var fwd: Vector3 = _pound_forward()
	var rel: Vector3 = pound_worker.global_position - pound_van.position
	var lon: float = rel.dot(fwd)
	var lat: float = rel.dot(pound_kerb_dir)
	if lat > 2.6:
		# Deep in a front yard: head straight OUT to the corridor
		# line first, then along it to the door — never a diagonal
		# across the lawn. (Once he is inside the out-point's
		# arrival bubble the aim switches to the door itself —
		# _pound_move_worker parks him at < 0.8 from a target, so
		# a waypoint he has effectively reached must stop being
		# the target or he stands on it forever.)
		var out_pt: Vector3 = pound_van.position + fwd * lon + pound_kerb_dir * 1.7 + Vector3(0, 0.2, 0)
		if pound_worker.global_position.distance_to(out_pt) > 0.85:
			return out_pt
		return door
	if lon < -2.6 and lat < 1.6:
		# Behind the van: around the BACK first — a rear waypoint
		# clear of the rear bumper, on the corridor line — then
		# forward along the kerb side to the door. Inside the rear
		# waypoint's arrival bubble the aim steps forward to a
		# mid-flank corridor point instead (same parking rule as
		# the out-point above; from there the region rules above
		# hand him on to the door).
		var rear_pt: Vector3 = pound_van.position + fwd * -3.8 + pound_kerb_dir * 1.7 + Vector3(0, 0.2, 0)
		if pound_worker.global_position.distance_to(rear_pt) > 0.85:
			return rear_pt
		return pound_van.position + fwd * -1.0 + pound_kerb_dir * 1.7 + Vector3(0, 0.2, 0)
	if lat < 0.6:
		# Road side (the original nose rule): around the nose,
		# then back along the kerb side.
		return pound_van.position + fwd * 3.4 + pound_kerb_dir * 1.7 + Vector3(0, 0.2, 0)
	return door

func _pound_move_worker(target: Vector3, speed: float, delta: float) -> bool:
	# Main-driven walking (the _room_move_toward pattern): set the
	# velocity, move NOW, animate — his own brain is parked
	# (active = false) so nothing fights the motion. Returns true
	# on arrival.
	var npc := pound_worker as CharacterBody3D
	var mdl = pound_worker.get("model")
	if mdl and not (mdl as Node3D).visible:
		(mdl as Node3D).visible = true # the distance-hider may have parked his model during a long pursuit
	var to: Vector3 = target - npc.global_position
	to.y = 0.0
	if to.length() < 0.8:
		npc.velocity = Vector3(0, npc.velocity.y, 0)
		npc.call("_animate", delta, 0.0)
		return true
	var dir: Vector3 = to.normalized()
	npc.velocity = Vector3(dir.x * speed, -2.0, dir.z * speed)
	npc.move_and_slide()
	npc.rotation.y = lerp_angle(npc.rotation.y, atan2(dir.x, dir.z), minf(1.0, 8.0 * delta))
	npc.call("_animate", delta, speed)
	return false

func _update_pound(delta: float) -> void:
	if pound_van == null or pound_worker == null:
		return
	if state == "splash" or state == "title":
		# The town is alive behind the title screens: the van
		# patrols, but the worker never engages before play starts.
		if pound_state == "patrol":
			_pound_drive_route(delta, POUND_VAN_SPEED)
			_pound_pin_worker()
		elif pound_state == "depot_in" or pound_state == "depot" or pound_state == "depot_out":
			_update_pound_depot(delta) # v1.0.21: the garage legs run behind the title too
		return
	if state != "play":
		return # cutscene / escape / win: he is busy being the captor (or the moment is frozen)
	if pound_engage_cd > 0.0:
		pound_engage_cd -= delta
	_pound_update_notice(delta) # v1.0.21: the officer's grabber notice meter (patrol + return states; self-gated)
	match pound_state:
		"patrol":
			if pound_heading_home and pound_route_idx == 0 and pound_van.position.x <= -109.0 and pound_van.position.z > 8.0:
				# v1.0.21: the west end of the round, level with the
				# depot — turn in and park in the garage (the depot
				# arms below drive it from the next frame).
				pound_heading_home = false
				pound_notice = 0.0
				pound_state = "depot_in"
				pound_path = [Vector3(-112, 0, 11.0), Vector3(-112, 0, 5.0), POUND_HOME_POS]
				pound_path_idx = 0
			else:
				_pound_drive_route(delta, POUND_VAN_SPEED)
				_pound_pin_worker()
		"pullover":
			_pound_drive_pullover(delta)
			if pound_state == "pullover":
				_pound_pin_worker() # still parking: he rides. (On the arrival frame _pound_worker_out has already put him at the door — pinning then would drag him back inside.)
		"exit":
			pound_exit_t -= delta
			if pound_exit_t <= 0.0:
				# Out he comes — the game's own grabber tell + chase
				# take it from here (his line: "There you are!
				# Let's get you home!").
				pound_state = "chase"
				pound_worker.set("active", true)
				pound_worker.set("notice", 1.0)
				pound_worker.call("_start_chase")
		"chase":
			var wm: String = str(pound_worker.get("mode"))
			if wm != "chase" and wm != "tell" and wm != "pursue":
				# He lost the cat — the ordinary chase lose rules
				# (distance / line of sight / cat gap) fired inside
				# person.gd. Take the wheel back and walk him home
				# to the van. (A capture leaves "play" instead, and
				# on_cat_taken moves him to "away".)
				pound_state = "return"
				pound_worker.set("active", false)
				pound_notice = 0.0 # v1.0.21: the meter starts empty on the walk back; it can build again from here
				pound_worker.set("notice", 0.0)
				_pound_clear_label()
				_pound_reset_return_watch()
		"return":
			# v1.0.21: no instant re-spot on this walk any more — if
			# the cat comes back into his view, the notice meter
			# builds over his head and only a FULL meter turns him
			# around (see _pound_update_notice, which runs before
			# this match). The walk itself is unchanged.
			var door: Vector3 = _pound_door_pos()
			var target: Vector3 = _pound_return_target(door)
			# POUND RETURN FIX: stuck watch. The waypoints are
			# the fix; this only fires if scenery the waypoints
			# don't know about still wedges him in real play.
			# No progress for ~2.5 s -> a sidestep; ~6 s total
			# of no progress -> quietly place him at the door.
			if pound_return_dodge_t > 0.0:
				pound_return_dodge_t -= delta
				target = pound_return_dodge
			else:
				var wpos: Vector3 = pound_worker.global_position
				var dt2: Vector3 = target - wpos
				dt2.y = 0.0
				if not pound_return_has_target or pound_return_last_target.distance_squared_to(target) > 0.04:
					pound_return_best = INF
					pound_return_still_t = 0.0
					pound_return_has_target = true
				pound_return_last_target = target
				if dt2.length() < pound_return_best - 0.05:
					pound_return_best = dt2.length()
					pound_return_still_t = 0.0
				else:
					pound_return_still_t += delta
					pound_return_stuck_total += delta
				if pound_return_stuck_total >= 6.0:
					# Last resort: he is wedged somewhere the
					# waypoints can't clear. A tiny pop at the
					# door after 6 stuck seconds beats a patrol
					# that never resumes.
					print("POUND RETURN FAILSAFE: teleported worker to the door after ", snappedf(pound_return_stuck_total, 0.1), "s stuck (target was ", target, ")")
					pound_worker.global_position = door + pound_kerb_dir * 0.3
					_pound_reset_return_watch()
					target = door
				elif pound_return_still_t >= 2.5:
					# Sidestep: a brisk step perpendicular to
					# the blocked line — kerb side first, the
					# other side if he is still stuck after —
					# then resume the routed walk.
					var dirv: Vector3 = dt2.normalized()
					var perp: Vector3 = Vector3(-dirv.z, 0, dirv.x)
					if perp.dot(pound_kerb_dir) < 0.0:
						perp = -perp
					if pound_return_sidesteps > 0:
						perp = -perp
					pound_return_dodge = wpos + perp * 1.3
					pound_return_dodge_t = 0.9
					pound_return_sidesteps += 1
					pound_return_still_t = 0.0
					print("POUND RETURN FAILSAFE: sidestep #", pound_return_sidesteps, " at ", wpos, " toward ", pound_return_dodge)
					target = pound_return_dodge
			if _pound_move_worker(target, POUND_RETURN_SPEED, delta) and target == door:
				# Back at the van: in he gets, net and all, and
				# the patrol resumes — he'll be round again.
				pound_worker.visible = false
				pound_worker.set("active", false)
				pound_worker.call("set_net_visible", true)
				pound_worker.call("set_expression", "neutral")
				pound_state = "patrol"
				pound_engage_cd = 6.0
				pound_heading_home = true # v1.0.21: after an encounter the round ends at the depot — he drives home to the garage (see the patrol arm)
				_pound_reset_return_watch()
		"depot_in", "depot", "depot_out":
			_update_pound_depot(delta) # v1.0.21: the garage legs
		"away":
			pass # he is the captor: cutscene, room and pursuit own him until the pursuit drains (see _process)
	_update_pound_van_bar() # v1.0.21: keep the van meter's visibility honest in every state (full through the pull-over, hidden once he is out)

func _pound_drive_path(delta: float, speed: float, snap_end: bool = true) -> bool:
	# v1.0.21: drive an explicit waypoint list (the depot legs) with
	# the SAME driving state as the patrol route — pound_van_yaw
	# tracked exponentially toward the target, speed eased by the
	# turn gap and accelerated/decelerated through pound_van_speed
	# exactly as _pound_drive_route does — so the van handles
	# identically everywhere it drives. Returns true on arrival at
	# the final waypoint (snapping exactly onto it when asked: the
	# garage park spot must be precise).
	if pound_path_idx >= pound_path.size():
		return true
	var target: Vector3 = pound_path[pound_path_idx]
	var to: Vector3 = target - pound_van.position
	to.y = 0.0
	var dist: float = to.length()
	var is_last: bool = pound_path_idx == pound_path.size() - 1
	var arrive_r: float = (0.6 if snap_end else 2.5) if is_last else 2.5
	if dist <= arrive_r:
		if is_last:
			if snap_end:
				var prev: Vector3 = pound_path[pound_path_idx - 1] if pound_path_idx > 0 else pound_van.position - _pound_forward()
				pound_van.position = target
				pound_van_yaw = atan2(-(target.z - prev.z), target.x - prev.x)
				pound_van.rotation.y = pound_van_yaw
				pound_van_speed = 0.0
			return true
		pound_path_idx += 1
		return false
	var want_yaw: float = atan2(-to.z, to.x)
	pound_van_yaw = lerp_angle(pound_van_yaw, want_yaw, minf(1.0, 1.15 * delta))
	var turn_gap: float = absf(angle_difference(pound_van_yaw, want_yaw))
	var spd: float = speed * clampf(1.15 - turn_gap, 0.45, 1.0)
	pound_van_speed = move_toward(pound_van_speed, spd, (7.0 if spd < pound_van_speed else 3.5) * delta)
	pound_van.position += _pound_forward() * pound_van_speed * delta
	pound_van.rotation.y = pound_van_yaw
	return false

func _update_pound_depot(delta: float) -> void:
	# v1.0.21: the garage legs, shared by play and the title screens
	# (the town stays alive behind the title). The worker rides
	# throughout — pinned in the van, invisible, exactly as on
	# patrol — and no notice builds here: he is off duty at home.
	match pound_state:
		"depot_in":
			if _pound_drive_path(delta, 4.5):
				pound_state = "depot"
				pound_depot_t = POUND_DEPOT_DWELL
				pound_van.position = POUND_HOME_POS
				pound_van_yaw = POUND_HOME_YAW
				pound_van.rotation.y = POUND_HOME_YAW
				pound_van_speed = 0.0
			_pound_pin_worker()
		"depot":
			pound_depot_t -= delta
			_pound_pin_worker()
			if pound_depot_t <= 0.0:
				pound_state = "depot_out"
				pound_backing_out = true
				pound_path = [Vector3(-104, 0, 16.7)] # back onto the z=15 lane, eastbound
				pound_path_idx = 0
		"depot_out":
			if pound_backing_out:
				# Reverse straight out of the bay, the way a van
				# leaves a garage — yaw locked on the park heading.
				pound_van_yaw = POUND_HOME_YAW
				pound_van.rotation.y = POUND_HOME_YAW
				pound_van_speed = 0.0
				pound_van.position -= _pound_forward() * 2.0 * delta
				if pound_van.position.z >= 6.5:
					pound_backing_out = false
			elif _pound_drive_path(delta, POUND_VAN_SPEED, false):
				pound_state = "patrol"
				pound_route_idx = 1 # resume the rounds on the east leg
			_pound_pin_worker()

# ---------------------------------------------------------------- score
func _update_score_label() -> void:
	if score_label:
		score_label.text = "⭐ %d   🐾 Pets %d   🍪 Treats %d" % [score, pets_count, treats_count]

# v1.0.26: a town cat answers Zander's meow — the same recorded
# meow the player cat uses, pitch-shifted per cat so each of the
# eight has its own voice.
func play_cat_meow(pitch: float) -> void:
	if meow_players.is_empty():
		return
	var mp: AudioStreamPlayer = meow_players[meow_index % meow_players.size()]
	meow_index += 1
	mp.pitch_scale = pitch
	mp.play()
	cat_meow_count += 1

# v1.0.26: a COMPLETED play session with a town cat scores +3
# (between pet +1 and treat +5 on Michael's scale — adjustable),
# once per cat per run; the cat flags itself played and only
# calls this on its first completed session. The "+3" pop is
# the town sibling of the shelter breakout pop.
func on_town_cat_play(tc: Node) -> void:
	score += 3
	cat_play_count += 1
	_update_score_label()
	show_message("🐱 You played with %s! +3" % str(tc.get("display_name")), 2.4)
	var pop := _label3d(self, "+3", (tc as Node3D).global_position + Vector3(0, 1.15, 0), 64, Color(1.0, 0.85, 0.3))
	town_pops.append({"node": pop, "t": 0.0, "y0": pop.position.y})

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
const STREET_NAMES_H: Dictionary = {-55.0: "Elm Drive", -11.0: "Maple Street", 15.0: "Oak Avenue", 55.0: "Willow Crescent"}
const STREET_NAMES_V: Dictionary = {-70.0: "Pine Street", -20.0: "Cedar Street", 24.0: "Birch Lane", 72.0: "Riverside Drive", 128.0: "Harbour Street", 176.0: "Summit Avenue", 224.0: "Quarry Lane", 272.0: "Meadow Drive", 320.0: "Sunset Drive"}

func street_name_at(pos: Vector3) -> String:
	# v1.0.22: the street a world position belongs to, for the
	# intake card. The nearer of the closest horizontal / vertical
	# road centreline wins; beyond the roads entirely, the nearest
	# house's street speaks for the spot.
	var best_h := ""
	var bd_h := 1e9
	for rz in STREET_NAMES_H.keys():
		var d: float = absf(pos.z - float(rz))
		if d < bd_h:
			bd_h = d
			best_h = str(STREET_NAMES_H[rz])
	var best_v := ""
	var bd_v := 1e9
	for rx in STREET_NAMES_V.keys():
		if LEGACY_TOWN_ONLY and float(rx) > 100.0:
			continue
		var d2: float = absf(pos.x - float(rx))
		if d2 < bd_v:
			bd_v = d2
			best_v = str(STREET_NAMES_V[rx])
	if minf(bd_h, bd_v) <= 17.0:
		return best_h if bd_h <= bd_v else best_v
	var best_house := ""
	var bd_house := 1e9
	for h in houses:
		var hp: Vector3 = h["pos"]
		var dh: float = Vector2(pos.x - hp.x, pos.z - hp.z).length()
		if dh < bd_house:
			bd_house = dh
			best_house = str(h["address"])
	if best_house != "":
		var sp: int = best_house.find(" ")
		if sp > 0:
			return best_house.substr(sp + 1)
		return best_house
	return best_h if bd_h <= bd_v else best_v

func _refresh_intake_card() -> void:
	# v1.0.22: the intake card on Zander's cage names the street he
	# was picked up on. It is a physical card in the ward — the
	# player learns the street only by walking up and reading it;
	# nothing anywhere else ever shows it.
	if intake_card_label == null:
		return
	if pickup_street == "":
		intake_card_label.text = "INTAKE\nCat — orange tabby\nFound on —"
	else:
		intake_card_label.text = "INTAKE\nCat — orange tabby\nFound on " + pickup_street

func on_cat_taken(npc: Node) -> void:
	if state != "play":
		return
	var lost_pts: int = apply_capture_penalty()
	if lost_pts > 0:
		show_message("⭐ Taken! You lost %d points (20%% of your score)." % lost_pts, 2.5)
	captor = npc
	capture_return_pos = player.global_position
	pursuers.erase(npc)
	if npc == pound_worker:
		# v1.0.22: remember where he was picked up — the intake
		# card on his cage in the ward will say this street.
		pickup_street = street_name_at(player.global_position)
		_refresh_intake_card()
		# POUND VAN: he is the captor now — the cutscene, the room
		# ("back at the pound") and his pursuit own him until the
		# pursuit drains, which hands him back to the van (below).
		pound_state = "away"
		pound_worker.call("set_net_visible", false) # he puts the net down to carry the cat
	# v1.3 CAPTURE CUTSCENE — THE SCOOP (rebuilt, see _process_cutscene):
	# she steps in, kneels, both hands come down at his sides and slide
	# under him; he rises in one eased arc into a cradle at her chest,
	# startles, settles; she turns and walks home holding him. Fades
	# into her escape room (~5.2s, skippable after 1s).
	state = "cutscene"
	cutscene_t = 0.0
	cutscene_from = player.global_position
	cutscene_cat_yaw0 = player.rotation.y
	cutscene_npc_yaw0 = npc.rotation.y
	cutscene_npc_from = npc.global_position
	cutscene_held_started = false
	var to_cat: Vector3 = player.global_position - npc.global_position
	to_cat.y = 0.0
	cutscene_face_yaw = atan2(to_cat.x, to_cat.z) if to_cat.length() > 0.05 else cutscene_npc_yaw0
	# The way home is back the way she came: opposite her facing.
	var f: Vector3 = -npc.global_transform.basis.z
	f.y = 0.0
	cutscene_dir = f.normalized() if f.length() > 0.05 else Vector3(0, 0, 1)
	if player: player.set("frozen", true)
	sfx_notice.play()
	show_message("💛 " + str(npc.get("display_name")) + " scooped you up! \"Come home with me, kitty!\"  (tap to skip)", 3.0)

func _held_pos(npc: Node) -> Vector3:
	# v1.3: cradled against her CHEST — in front of her facing, belly
	# to her, head up by her chin. The old formula used -basis.z,
	# which is BEHIND her (her face/front is +basis.z): he rode at
	# her back, half inside her skirt, and the follow camera — which
	# tracks HIM — spent the carry staring at her legs with the cat
	# out of frame. Scaled by her mscale so a kid captor holds him
	# at kid-chest height too.
	var f: Vector3 = npc.global_transform.basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.05 else Vector3(0, 0, 1)
	var ms: float = 1.0
	if npc.get("mscale") != null:
		ms = float(npc.get("mscale"))
	return npc.global_position + f * (0.42 * ms) + Vector3(0, 1.03 * ms, 0)

func _ease_out_cubic(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)

func _ease_in_out_cubic(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	if c < 0.5:
		return 4.0 * c * c * c
	return 1.0 - pow(-2.0 * c + 2.0, 3.0) * 0.5

func _bezier2(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return a * (u * u) + b * (2.0 * u * t) + c * (t * t)

func _scoop_step_in(npc3: Node3D, k: float) -> void:
	# During the bend she closes the last of the gap so her hands can
	# actually reach him (grab range is 1.2m; arms are 0.68m): ease
	# her to a spot 0.66m from the cat along the line she stands on,
	# and square her facing onto him. Absolute lerps from the
	# captured anchors — no per-frame compounding.
	var dest: Vector3 = cutscene_npc_from
	var to_cat: Vector3 = cutscene_from - cutscene_npc_from
	to_cat.y = 0.0
	if to_cat.length() > 0.66:
		dest = cutscene_from - to_cat.normalized() * 0.66
		dest.y = cutscene_npc_from.y
	npc3.global_position = cutscene_npc_from.lerp(dest, k)
	npc3.rotation.y = lerp_angle(cutscene_npc_yaw0, cutscene_face_yaw, k)

func _process_cutscene(delta: float) -> void:
	cutscene_t += delta
	var npc = captor
	if npc == null:
		_enter_escape()
		return
	var npc3 := npc as Node3D
	player.velocity = Vector3.ZERO
	if cutscene_t < 1.15:
		# BEAT 1 — BEND & REACH: she steps in close, kneels down to
		# his level (person.gd's kneel, cutscene-driven) and both
		# hands come down at his sides. He stays on the ground.
		var k: float = _ease_out_cubic(cutscene_t / 1.15)
		_scoop_step_in(npc3, k)
		npc.call("set_carry_pose", k, 0.0, k, 0.0)
	elif cutscene_t < 2.35:
		# BEAT 2 — THE SCOOP: her hands slide under him (reach aims
		# them at his flanks, lift_k walks them underneath) and he
		# rises along ONE eased arc into her chest, turning to face
		# her as he leaves the ground. The old code lerped position
		# by a growing per-frame weight — creep, then a final snap.
		# Here the path is a pure function of the beat clock: a
		# quadratic bezier (ground -> raised midpoint -> chest) run
		# on a cubic ease-in-out, so velocity is smooth throughout.
		if not cutscene_held_started:
			cutscene_held_started = true
			if player.has_method("start_held"):
				player.call("start_held") # startle, then settle (cat.gd)
		var lk: float = clampf((cutscene_t - 1.15) / 1.2, 0.0, 1.0)
		var e: float = _ease_in_out_cubic(lk)
		var cradle: float = clampf((lk - 0.55) / 0.45, 0.0, 1.0)
		cradle = cradle * cradle * (3.0 - 2.0 * cradle)
		var reach: float = 1.0 - clampf((lk - 0.78) / 0.22, 0.0, 1.0)
		# She stays knelt until he's gathered, then stands WITH him:
		# the kneel release trails the lift instead of racing it.
		var kneel_now: float = 1.0 - _ease_in_out_cubic(clampf((lk - 0.15) / 0.85, 0.0, 1.0))
		npc.call("set_carry_pose", reach, cradle, kneel_now, lk)
		var target: Vector3 = _held_pos(npc)
		var ctrl: Vector3 = cutscene_from.lerp(target, 0.45) + Vector3(0, 0.30, 0)
		var p: Vector3 = _bezier2(cutscene_from, ctrl, target, e)
		# anticipation: a whisker of dip as her hands slide under him
		p.y -= 0.03 * sin(clampf(lk / 0.22, 0.0, 1.0) * PI) * (1.0 - lk)
		player.global_position = p
		player.rotation.y = lerp_angle(cutscene_cat_yaw0, npc3.rotation.y + PI, e)
	elif cutscene_t < 3.05:
		# BEAT 3 — SETTLE & TURN: she's upright, he's cradled at her
		# chest (his held pose completes in cat.gd); she turns to
		# head home while he settles with a soft decaying double-bob.
		var sk: float = clampf((cutscene_t - 2.35) / 0.7, 0.0, 1.0)
		npc.call("set_carry_pose", 0.0, 1.0, 0.0, 1.0)
		var away_yaw: float = atan2(cutscene_dir.x, cutscene_dir.z)
		npc3.rotation.y = lerp_angle(cutscene_face_yaw, away_yaw, _ease_in_out_cubic(sk))
		var bob: float = 0.028 * sin(sk * PI * 2.0) * (1.0 - sk)
		player.global_position = _held_pos(npc) + Vector3(0, bob, 0)
		player.rotation.y = npc3.rotation.y + PI
	else:
		# BEAT 4 — CARRY HOME: she walks off FACING her walk (the old
		# code walked her backwards), him cradled in front with a
		# gentle walking bob; her arms stay folded under him because
		# person.gd's cradle pose outranks the walk swing. The camera
		# follows him, and now he's actually in front of her — in
		# frame the whole way. Fade into her house as before.
		npc.call("set_carry_pose", 0.0, 1.0, 0.0, 1.0)
		npc.set("velocity", cutscene_dir * 2.2)
		npc.call("move_and_slide")
		npc.call("_animate", delta, 2.2)
		var bob2: float = sin(cutscene_t * 8.8) * 0.012
		player.global_position = _held_pos(npc) + Vector3(0, bob2, 0)
		player.rotation.y = npc3.rotation.y + PI
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
# like the same arbitrary checklist every time. Since v1.1 the
# working is the escape PANEL combo (prompt -> panel -> the rolled
# A/B combination -> the visible escape); see the panel section
# below.
# v1.4 (Michael's v1.0.6 playtest): the pool is now ONE entry for
# every captor — the BACK DOOR and its sliding bolt. His rule: the
# cat carrier is TRANSPORT ONLY (it's how he may be brought in; it
# is never the puzzle), and the escape game belongs to the DOOR —
# walk to the door, PAW, work the bolt in the panel, the door
# swings open, walk out. One clear, learnable rule instead of a
# per-capture draw between window / pet door / bolt / carrier.
# The window and pet door remain in the room as dressing (blocked,
# as a real house's other exits would be); the carrier remains as
# a prop by the wall. Neither is ever selected again.
func _variant_pool(ctype: String) -> Array:
	return [["bolt"]]

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
	# activate the puzzle; the prompt says so too).
	# v1.0.15 HUD fix: the old texts ALSO repeated the distraction
	# clause ("— knock something over first, the captor's watching!")
	# in every step, which pushed the line off the screen's right
	# edge. That half of the instruction hasn't gone anywhere: the
	# entry message's second beat says it, and the distract label
	# directly under this line carries it the whole time the captor
	# is in the room.
	match kind:
		"carrier": return "You're shut in a CARRIER! Press PAW by it to wriggle the door!"
		"latch": return "Find the WINDOW! Press PAW by it to work the brass latch!"
		"winpush": return "The latch is open! Press PAW by the window to push it up!"
		"petdoor": return "Find the PET DOOR! Press PAW by it to work the flap!"
		"bolt": return "Find the BACK DOOR! Press PAW by it to slide the bolt!"
	return ""

func _update_escape_label() -> void:
	if _cat_caged():
		# Caged at the pound: the header waits — the cage prompt is
		# the only instruction until the gate opens (the story module
		# calls this again when it does).
		escape_label.text = ""
		return
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
	_panel_press_owner.clear() # v1.0.24
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
	_reset_ward_cages() # SHELTER WARD: cages closed, animals home
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
			"poundworker": room_title_label.text = "🚐 The pound — find the back door!"
			_: room_title_label.text = "💛 A cozy cat-lover's home — find a way out!"

# --- v1.0.19: captor references for player-facing text. Every
# escape-room line that mentions the captor builds the reference
# from the captor's OWN pronoun definition (person.gd _apply_type)
# — never a hardcoded she/her. (The v1.0.17 text was written for
# the young woman and applied to everyone: the pound called the
# officer "she", and one screen mixed her/him for one captor.)
# With no captor set, the neutral they-forms are used — they can
# never misgender anyone.
func _captor_ref() -> String: # "She" / "He" / "The Excited Kid"
	if captor and captor.has_method("p_ref"):
		return str(captor.call("p_ref"))
	return "They"

func _captor_ref_lower() -> String: # "she" / "he" / "the Excited Kid"
	if captor and captor.has_method("p_ref_lower"):
		return str(captor.call("p_ref_lower"))
	return "they"

func _captor_obj() -> String: # "her" / "him" / "the Excited Kid"
	if captor and captor.has_method("p_ref_obj"):
		return str(captor.call("p_ref_obj"))
	return "them"

func _captor_poss() -> String: # "her" / "his" / "the Excited Kid's"
	if captor and captor.has_method("p_ref_poss"):
		return str(captor.call("p_ref_poss"))
	return "their"

func _captor_is() -> String: # "She's" / "He's" / "The Excited Kid is"
	if captor and captor.has_method("p_is"):
		return str(captor.call("p_is"))
	return "They're"

func _enter_escape() -> void:
	state = "escape"
	fade_in_t = 0.6 # fade back in from the capture cutscene
	if pursuit_label:
		pursuit_label.text = "" # v1.2 hygiene: a caught-mid-pursuit cat shouldn't carry the town pursuit banner into the room
	if captor:
		var cm = captor.get("model")
		if cm:
			cm.rotation.x = 0.0
		# v1.3: release the scoop poses — the captor's arms are
		# their own again in the room, and the cat is back on his
		# own four paws.
		if captor.has_method("set_carry_pose"):
			captor.call("set_carry_pose", 0.0, 0.0, 0.0, 0.0)
	if player and player.has_method("stop_held"):
		player.call("stop_held")
	var ctype := "woman"
	if captor and captor.get("npc_type") != null:
		ctype = str(captor.get("npc_type"))
	# v1.0.17 DESTINATION SPLIT: the pound is ONLY for the
	# animal-control officer — a regular townsperson's capture goes
	# to a HOUSE interior. Swap the active room before anything
	# resets or themes it.
	_activate_escape_room(captor != pound_worker)
	escape_steps = _pick_escape_variant(ctype)
	escape_step = 0
	escape_prog = 0.0
	_reset_escape_props()
	_apply_escape_theme(ctype)
	# v1.4: the cat always starts on the rug — never inside the
	# carrier (the carrier is transport dressing, not a puzzle).
	player.global_position = escape_origin + Vector3(0, 0.3, 6)
	if player: player.set("frozen", false)
	# v1.0.20: start the room on the indoor camera — the pitch goes
	# to the indoor default and the camera starts behind the cat.
	# This mirrors the handoff _complete_escape performs on the way
	# out (it restores the town pitch/yaw there); the 0.6 s fade
	# above covers the swing, and the escape-state pitch floor in
	# _update_camera holds the framing from there.
	look_pitch_deg = CAM_ESCAPE_PITCH
	if player:
		look_yaw = wrapf(player.rotation.y + PI, -PI, PI)
	# v1.2: the captor is IN THE ROOM with the cat (Michael's design) —
	# settling him in, tidying up. The captor ambles between the room
	# anchors (see _update_captor_room); their town chase state is
	# cleared so they read as a calm host, never angry.
	if captor:
		captor.set("mode", "wander")
		captor.set("notice", 0.0)
		captor.set("grab_progress", 0.0)
		(captor as Node3D).global_position = escape_origin + Vector3(-3.5, 0.25, 1.8)
		captor_anchor_idx = 0
		captor_room_state = "idle"
		captor_room_wait = 2.0
		_room_face(player.global_position, 1.0)
		if captor == pound_worker:
			captor.call("show_bubble", "There we are — safe and sound! 💛", 2.6)
		else:
			captor.call("show_bubble", "There we are — home sweet home! 💛", 2.6)
		captor.call("set_expression", "happy") # v1.4: the warm welcome face
		captor.set("expr_timer", 4.0)
	_update_escape_label()
	# HUD fix (v1.0.15, Michael's v1.0.14 play): the entry message is
	# TWO queued beats, not one long line — as a single string it ran
	# off both edges of the band and he couldn't read it. Beat 1 is
	# the situation, beat 2 the instruction; the queue plays them in
	# order, one at a time, exactly like any other messages.
	var entry_beat_1: String
	var entry_beat_2: String
	if captor == pound_worker:
		# POUND VAN: his capture lands the cat back at the pound —
		# the same bolt-door escape, exactly as Michael described.
		# v1.0.19: the pronouns come from the captor's own
		# definition (his, here) — never hardcoded.
		entry_beat_1 = "You're in the POUND — and so is %s!" % _captor_ref_lower()
		entry_beat_2 = "Knock something over to distract %s, then work the back door." % _captor_obj()
	else:
		entry_beat_1 = "You're in %s home — and so is %s!" % [_captor_poss(), _captor_ref_lower()]
		entry_beat_2 = "Knock something over to distract %s, then work the way out." % _captor_obj()
	# STORY PART 1: when this entry is the OPENING's capture, the cat
	# lands in the pound CAGE — the room instructions are held back
	# until the cage gate opens (the story module releases them via
	# release_held_escape_message). A mid-game capture has no cage:
	# the message shows at once, as it always has.
	if story != null and bool(story.get("pound_entry_pending")):
		held_escape_message = entry_beat_1
		held_escape_seconds = 2.4
		held_escape_message_2 = entry_beat_2
		held_escape_seconds_2 = 3.4
	else:
		show_message(entry_beat_1, 2.4)
		show_message(entry_beat_2, 3.4)

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
	# STORY PART 1: a PAW at the pound cage gate belongs to the
	# opening module — it consumes the paw only while the cat is
	# caged at the gate; every other paw falls through to here.
	if story and story.call("handle_escape_paw"):
		return
	if escape_step >= escape_steps.size() or escape_anim_t >= 0.0 or exit_open:
		return
	if player:
		player.call("do_paw_swipe")
	if _escape_at_mechanism():
		_open_escape_panel()
	elif _free_cage_at_cat():
		pass # SHELTER WARD: the breakout pop + message say it all
	elif topple_prop_at_cat():
		pass # the crash + message in topple_prop say it all
	else:
		# Caged at the pound: no fallback hint — while he's in the
		# cage, the cage prompt is the only instruction.
		if not _cat_caged():
			show_message("Paw the way out to work it — or knock something over to distract %s! 🐾" % _captor_obj(), 1.8)

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

func _roll_escape_combo() -> void:
	# v1.0.21: a fresh A/B combination for THIS start of the puzzle —
	# five presses, each an even coin flip (Michael's example was
	# "A B B A A"). Rolled on every panel opening, so an interrupted
	# try (the captor notices, the panel closes) restarts against a
	# NEW sequence, never the memorised old one.
	escape_combo.clear()
	for i in range(ESCAPE_COMBO_LEN):
		escape_combo.append("A" if rng.randi_range(0, 1) == 0 else "B")
	if escape_panel:
		escape_panel.set_combo_seq(escape_combo)

func _open_escape_panel() -> void:
	var kind: String = escape_steps[escape_step]["kind"]
	_panel_press_owner.clear() # v1.0.24: no press can be mid-hold as the panel opens
	combo_index = 0
	_roll_escape_combo() # v1.0.21: every start of the puzzle rolls a fresh A/B combo
	escape_prog = 0.0
	notice_t = 0.0 # v1.2: the notice clock starts as the panel opens
	# (notice_cooldown is NOT cleared: right after an interruption the
	# captor is still suspicious and the grace is halved — see
	# _update_escape_room.)
	_update_mechanism_visuals(kind)
	if escape_panel:
		escape_panel.open_for(kind)
	if player:
		player.set("frozen", true) # the cat stays put while you work the panel
	if escape_prompt_btn:
		escape_prompt_btn.visible = false

func _close_escape_panel() -> void:
	_panel_press_owner.clear() # v1.0.24: a finger still down as the panel closes must not leave a stale owner behind
	if escape_panel:
		escape_panel.hide_panel()
	if player and escape_anim_t < 0.0:
		player.set("frozen", false)

# One entry point for ALL panel inputs (the game's on-screen A / B
# buttons via the raw-touch claim in _input, the PC hop / paw keys,
# and the automated tests). v1.0.21: inputs
# are "A" / "B" presses against the rolled escape_combo.
func escape_panel_input(inp: String) -> void:
	if escape_panel == null or not escape_panel.visible:
		return
	if state != "escape" or escape_step >= escape_steps.size() or escape_anim_t >= 0.0:
		return
	if escape_combo.size() != ESCAPE_COMBO_LEN:
		_roll_escape_combo() # belt and braces: a panel never runs without a rolled combo
	var kind: String = escape_steps[escape_step]["kind"]
	var expected: String = str(escape_combo[combo_index])
	if inp == expected:
		combo_index += 1
		escape_prog = float(combo_index) / float(ESCAPE_COMBO_LEN)
		_update_mechanism_visuals(kind)
		if kind == "carrier":
			carrier_shake = 0.25 # the carrier rattles as you wriggle its door
		escape_panel.set_combo(combo_index)
		if combo_index >= ESCAPE_COMBO_LEN:
			_panel_combo_success()
	else:
		# Gentle reset — and forgiving: a press matching the combo's
		# FIRST step counts as the first step of the new try.
		combo_index = 1 if inp == str(escape_combo[0]) else 0
		escape_prog = float(combo_index) / float(ESCAPE_COMBO_LEN)
		_update_mechanism_visuals(kind)
		escape_panel.set_combo(combo_index)
		escape_panel.show_slip("Oops — it slipped back! Start again: " + " ".join(escape_combo) + " 🐾")

func _panel_combo_success() -> void:
	var kind: String = escape_steps[escape_step]["kind"]
	_panel_press_owner.clear() # v1.0.24: the completing press may still be held as the panel hides
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
# The combo is done: the mechanism finishes opening for real (the
# back door swung wide — v1.4: the door is the one and only exit)
# and CONTROL RETURNS TO THE PLAYER. The opening stays open — no
# timer, nothing to re-do — so the cat can never be soft-locked
# inside.
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
		# v1.4: no "carrier" arm any more — the carrier is never the
		# mechanism, so there is no second-stage pet-door exit.
	if escape_label:
		escape_label.text = "🚪 The way is OPEN — walk out!"
	if captor and not captor_distracted():
		captor.call("show_bubble", "Oh my — how did you…? 😮", 2.2)

# The escape completes when the cat actually crosses the threshold —
# that's when the +3 and the 30 s pursuit begin (unchanged contract).
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
	# v1.5: the cue scales to the object — a cushion must not crash
	# like a vase. crash = the original low thud; clatter = brighter
	# and shorter; thud = softer still for soft things.
	var cue: String = str(p.get("cue", "crash"))
	if sfx_crash:
		sfx_crash.pitch_scale = 1.4 if cue == "clatter" else (0.55 if cue == "thud" else 0.5)
		sfx_crash.volume_db = -9.0 if cue == "thud" else -4.0
		sfx_crash.play()
	var cue_text: String = "💥 CRASH!" if cue == "crash" else ("🔔 Clatter!" if cue == "clatter" else "💨 Thud!")
	var lbl := _label3d(self, cue_text, (p["base"] as Vector3) + Vector3(0, 1.7, 0), 72, Color(1.0, 0.8, 0.3))
	crash_labels.append({"node": lbl, "t": 0.0, "y0": lbl.position.y})
	if captor:
		captor.call("show_bubble", str(p["bubble"]), 2.2)
		captor.call("set_expression", "worried") # v1.4: the crash worries the captor
		captor.set("expr_timer", 2.5)
		if captor_room_state == "idle" or captor_room_state == "walk" or captor_room_state == "return" or captor_room_state == "shoo":
			captor_prop = p
			captor_trip_t = 0.0
			captor_room_state = "to_prop"
		else:
			distract_queue.append(p) # the captor is already busy — this one queues
	show_message("💥 You knocked over %s! %s distracted — quick, work the way out! 🐾" % [str(p["name"]), _captor_is()], 2.8)

func _on_prop_prompt_pressed() -> void:
	if state == "escape":
		topple_prop_at_cat()

# The captor noticed the cat at the door: the panel closes, the
# combo is lost, and the cat is kindly shooed off with a little
# hop. NO fail state, no score loss — the only cost is the combo
# and the captor being extra watchful (halved grace) for a few
# seconds after.
func _interrupt_escape() -> void:
	if escape_step >= escape_steps.size():
		return
	if captor:
		captor.call("set_expression", "worried") # v1.4: the captor spotted him at the latch
		captor.set("expr_timer", 2.0)
	var kind: String = escape_steps[escape_step]["kind"]
	_panel_press_owner.clear() # v1.0.24: watched-close — a held press must not leak into the next opening
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
	show_message("👀 %s spotted you at the door! Knock something over to distract %s first! 🐾" % [_captor_ref(), _captor_obj()], 3.0)

# Per-frame room life: shoo hop, topple falls, crash cues, the
# captor's routine, the notice clock, prompts and the HUD.
func _update_escape_room(delta: float) -> void:
	_update_ward(delta) # SHELTER WARD: gates, animals, score pops
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
				escape_panel.set_status("💥 %s busy with %s — %.0fs!" % [_captor_is(), what, ceil(left)], clampf(left / 12.0, 0.0, 1.0), false)
			else:
				escape_panel.set_status("👀 %s watching — %s will notice you!" % [_captor_is(), _captor_ref_lower()], clampf(notice_t / grace, 0.0, 1.0), true)
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
	# Caged at the pound (opening): hidden — the cage prompt is the
	# only instruction until the gate opens.
	var show: bool = state == "escape" and not panel_open and escape_anim_t < 0.0 and not _cat_caged()
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
		distract_label.text = "💥 %s busy with %s — %.0fs to work the way out!" % [_captor_is(), what, ceil(left)]
		distract_bar_bg.visible = true
		distract_bar_fill.visible = true
		distract_bar_fill.color = Color(0.45, 0.9, 0.45, 0.95)
		distract_bar_fill.position = Vector2(2, 2)
		distract_bar_fill.size = Vector2(516.0 * clampf(left / 12.0, 0.0, 1.0), 8)
	else:
		distract_label.text = "👀 %s in the room with you — knock something over to distract %s! 🐾" % [_captor_is(), _captor_obj()]
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
	# v1.4 CAMERA HANDOFF (Michael's v1.0.6 playtest: "When I escaped
	# I was high up in the air and super small. And it didn't return
	# to normal."). Diagnosis (tests/EscapeFlowProbe.tscn): FOV,
	# orbit distance and the look anchor are STATE-driven — they
	# restore themselves the frame the state flips back to "play".
	# But look_pitch_deg and look_yaw are PLAYER variables that
	# persist across every state, and nothing ever reset them:
	# whatever the player dragged them to while hunting around the
	# escape room (pitch wound up high is the natural way to scan a
	# room) followed him back to town — camera ~6 m up, cat at 0.03
	# of the frame through the whole pursuit, and STILL pitched
	# down at him after it ended. Restore the shipped town framing
	# here, at the one funnel every escape completion passes
	# through; the 0.6 s fade-in below covers the swing.
	look_pitch_deg = CAM_TOWN_PITCH
	if player:
		look_yaw = wrapf(player.rotation.y + PI, -PI, PI) # behind the cat again
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
	_panel_press_owner.clear() # v1.0.24
	if escape_panel:
		escape_panel.hide_panel()
	if player:
		player.set("frozen", false)
	player.global_position = capture_return_pos + Vector3(2.5, 0.3, 1.5)
	if captor:
		captor.global_position = capture_return_pos + Vector3(-4, 0.3, -2)
		if pursuers.size() < 2:
			pursuers[captor] = PURSUIT_DURATION
			if captor == pound_worker:
				# v1.0.17 POUND PURSUIT FIX (Michael's v1.0.15
				# report: after escaping the pound the officer
				# just walked in place and never came after
				# him). A person's brain is gated by its
				# `active` flag, and for the worker only the
				# van state machine ever sets it — while he is
				# the captor that machine sits in "away"
				# (hands-off), and on the opening's capture
				# path he was never switched on at all. So the
				# pursuit below set his mode to "pursue" while
				# his physics returned early every frame and
				# his body never moved. Switch him on as the
				# pursuit begins, exactly as his chase states
				# do; when the pursuit timer drains, the
				# existing drain hands him back to "return"
				# and then the patrol.
				pound_worker.set("active", true)
			captor.call("start_pursuit")
	show_message("You escaped! +3 points 💛 They'll look for you for 30 seconds — hide in bushes or behind cars!", 4.0)

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
	# v1.0.10: title stable for ~2 s = boot succeeded. Complete the
	# crash marker. (v1.0.14: the readout that used to flash "Ready"
	# here is gone; the marker + log writes are unchanged.)
	if _title_stable_t >= 0.0 and state == "title":
		_title_stable_t += delta
		if _title_stable_t >= 2.0:
			_title_stable_t = -1.0
			_boot_write_marker("complete")
			_boot_log("Ready (title stable)")
	_apply_joystick()
	_process_traffic(delta)
	_update_pound(delta) # POUND VAN: patrol / pull-over / return-to-van (engagement only in "play")
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
			# The band frees up: the next queued message takes its
			# turn; only when nothing is waiting does the band clear.
			if message_queue.size() > 0:
				var nxt: Dictionary = message_queue.pop_front()
				message_label.text = str(nxt["text"])
				message_timer = float(nxt["seconds"])
			else:
				message_label.text = ""
	if meow_cooldown > 0.0: meow_cooldown -= delta
	# v1.0.26: town "+3" pops rise and fade (the ward pops have
	# their own ticker in _update_ward; these live in _process).
	for i in range(town_pops.size() - 1, -1, -1):
		var tp: Dictionary = town_pops[i]
		tp["t"] = float(tp["t"]) + delta
		var tpt: float = float(tp["t"])
		var tnode := tp["node"] as Label3D
		if tnode == null or not is_instance_valid(tnode):
			town_pops.remove_at(i)
			continue
		tnode.position.y = float(tp["y0"]) + tpt * 0.55
		tnode.modulate.a = clampf(1.3 - tpt / 1.6, 0.0, 1.0)
		if tpt > 1.6:
			tnode.queue_free()
			town_pops.remove_at(i)
	if bark_msg_cooldown > 0.0: bark_msg_cooldown -= delta
	if latch_cooldown > 0.0: latch_cooldown -= delta
	# PURR (v0.6): town gameplay only — cat still ~3s, nobody chasing.
	# Starts at the 3s mark, stops the moment he moves / is chased /
	# is captured. The cat model adds the visual tell (see cat.gd).
	var any_chase := false
	for n in npcs:
		if str(n.get("mode")) == "chase" or str(n.get("mode")) == "pursue" or str(n.get("mode")) == "tell":
			any_chase = true
	if pound_worker != null: # POUND VAN: his chase counts for stamina/purr exactly like a neighbour's
		var pwm: String = str(pound_worker.get("mode"))
		if pwm == "chase" or pwm == "pursue" or pwm == "tell":
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
			stamina_label.visible = any_chase and gameplay_hud_on # v1.0.16: never behind splash/title
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
				if pound_worker != null and (str(pound_worker.get("mode")) == "chase" or str(pound_worker.get("mode")) == "tell"):
					pound_worker.call("end_chase_via_spot") # POUND VAN: a cat gap ends his chase too — he heads back to the van
				show_message("🐾 You slipped through the cat gap — they can't follow!", 2.5)
				break
	var want_purr: bool = state == "play" and player != null and not bool(player.get("frozen")) and (float(player.get("idle_time")) >= 3.0 or bool(player.call("is_being_petted"))) and not any_chase # v0.9: he purrs while being petted, too
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
		player.set("idle_allowed", state == "play")
	# Fade back in after the cutscene hands over to the escape room.
	if fade_in_t >= 0.0:
		fade_in_t -= delta
		if fade_rect:
			fade_rect.color.a = clampf(fade_in_t / 0.6, 0.0, 1.0)
		if fade_in_t <= 0.0:
			fade_in_t = -1.0
	# STORY PART 1: the opening cutscene module ticks here — after
	# the joystick pass (it drives the cat through touch_dir during
	# the street beats) and before the state dispatch, so a pound
	# entry is caged before the room's first idle frame.
	if story:
		story.call("tick", delta)
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
			if npc == pound_worker:
				pound_state = "return" # POUND VAN: his lookout is over — back to the van, back on patrol
				pound_worker.set("active", false) # main drives the walk back; his brain must not wander him off it
				pound_notice = 0.0 # v1.0.21: the meter starts empty on the walk back
				pound_worker.set("notice", 0.0)
				_pound_clear_label()
				_pound_reset_return_watch()
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
				# v1.0.21 panel on PC: the combination is entered with
				# the HOP and PAW keys themselves — Space (hop) is the
				# A press, E (paw) is the B press. Esc steps away.
				if k == KEY_SPACE:
					escape_panel_input("A")
				elif k == KEY_E:
					escape_panel_input("B")
				elif k == KEY_ESCAPE:
					_close_escape_panel()
			elif k == KEY_E:
				_on_interact()
			elif k == KEY_M:
				_on_meow()
			elif k == KEY_SPACE:
				if player: player.try_hop()
