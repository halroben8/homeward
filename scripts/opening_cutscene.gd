extends Node
## =====================================================================
## HOMEWARD — STORY PART 1: THE OPENING CUTSCENE + THE POUND START
## (scripts/opening_cutscene.gd)
##
## Michael's settled opening (directed 2026-11-17, built 2026-11-18):
## the cat happily leaves his house and strolls down the street; his
## collar slips off and he doesn't notice; the pound van pulls up and
## the kind worker gets out, says he'll help the kitty find his way
## home, and gently scoops him up; the van takes him to the pound,
## where the run proper begins — the cat is in a little cage, and the
## player escapes the pound (the ordinary back-door bolt escape),
## out into the town, collarless.
##
## This module ORCHESTRATES the existing actors (the cat, the pound
## worker, the patrol van) through their existing APIs — it owns no
## gameplay of its own beyond the cage in the escape room. main3d.gd
## only: creates it in _ready, calls begin_opening() from
## start_game(), ticks it from _process, and lets it consume a PAW
## at the cage gate in _escape_interact(). The pickup itself is the
## game's ordinary capture (on_cat_taken -> scoop cutscene -> escape
## room); poses, timings and the escape flow are untouched. A tap
## during the street beats skips straight to the pound room.
## =====================================================================

# The kind worker's line (two short lines — the speech bubble is a
# single billboard label, so the lines stay bubble-sized).
const WORKER_LINE := "No collar? You must be lost, kitty —\nI'll help you find your way home 💛"
# The legacy town's horizontal road centrelines (TRAFFIC_ROADS_H in
# main3d.gd). The opening stages on the home street; if the full
# town is restored with homes fronting other streets, revisit this.
const ROAD_CENTRELINES: Array = [-55.0, -11.0, 15.0, 55.0]
const GATE_OPEN_YAW := 1.85 # the cage gate swings out toward the room

var main: Node = null # the Main (main3d.gd) instance
var player: Node = null # the cat (cat.gd) — resolved in begin_opening
var worker: Node = null # the pound worker (person.gd)
var van: Node3D = null # the pound van

var active: bool = false # the street beats are running (state "opening")
var finished: bool = false # the scoop has been triggered
var phase: String = "" # leave | stroll | wait_van | line
var phase_t: float = 0.0
var line_step: int = 0
var line_t: float = 0.0

# --- staging (computed once, in begin_opening) ---
var facing: float = 1.0 # the home's facing (+1 = fronts the +z street)
var walk_dir_x: float = 1.0 # the stroll direction along the street
var street_point := Vector3.ZERO # door -> the sidewalk by his street
var stroll_end := Vector3.ZERO # the kerb spot where he waits
var van_start := Vector3.ZERO
var van_stop := Vector3.ZERO
var van_yaw: float = 0.0
var van_parked: bool = false
var worker_spot := Vector3.ZERO # where the worker stands for his line
var collar_dropped: bool = false
var dropped_collar: Node3D = null
var dropped_label: Label3D = null

# --- the pound cage ---
var pound_entry_pending: bool = false # the opening's scoop is inbound
var cage_built: bool = false
var cage_centre := Vector3.ZERO
var cage_gate_pivot: Node3D = null
var cage_blocker: CollisionShape3D = null
var cage_closed: bool = false
var gate_anim_t: float = -1.0 # >= 0 while the gate swings open
var cage_prompt_btn: Button = null
var gate_opened: bool = false # the cage gate has been opened (once)
var opening_hint_shown: bool = false # the controls hint has had its turn


func setup(main_ref: Node) -> void:
	main = main_ref
	# The cage-gate prompt: a twin of the escape prompt, on the same
	# layer (they can never show at once — the cat can't be at the
	# cage gate and at the door mechanism at the same time).
	cage_prompt_btn = Button.new()
	cage_prompt_btn.text = "🐾 PAW the cage gate!"
	cage_prompt_btn.anchor_left = 0.5
	cage_prompt_btn.anchor_right = 0.5
	cage_prompt_btn.anchor_top = 1.0
	cage_prompt_btn.anchor_bottom = 1.0
	cage_prompt_btn.offset_left = -340.0
	cage_prompt_btn.offset_right = 340.0
	cage_prompt_btn.offset_top = -196.0
	cage_prompt_btn.offset_bottom = -120.0
	cage_prompt_btn.pivot_offset = Vector2(340, 38)
	cage_prompt_btn.add_theme_font_size_override("font_size", 31)
	cage_prompt_btn.add_theme_color_override("font_color", Color(0.25, 0.16, 0.08))
	cage_prompt_btn.add_theme_color_override("font_hover_color", Color(0.25, 0.16, 0.08))
	cage_prompt_btn.add_theme_color_override("font_pressed_color", Color(0.25, 0.16, 0.08))
	var prompt_col := Color(1.0, 0.85, 0.45, 0.97)
	cage_prompt_btn.add_theme_stylebox_override("normal", main.call("_prompt_style", prompt_col))
	cage_prompt_btn.add_theme_stylebox_override("pressed", main.call("_prompt_style", prompt_col.lightened(0.12)))
	cage_prompt_btn.add_theme_stylebox_override("hover", main.call("_prompt_style", prompt_col))
	cage_prompt_btn.pressed.connect(_on_cage_prompt_pressed)
	cage_prompt_btn.visible = false
	(main.get("escape_ui_layer") as CanvasLayer).add_child(cage_prompt_btn)


# ---------------------------------------------------------------------
# THE OPENING — staged at this run's generated home
# ---------------------------------------------------------------------

func begin_opening() -> void:
	player = main.get("player")
	worker = main.get("pound_worker")
	van = main.get("pound_van")
	# The truth from the very start of the run: he has no collar on
	# him for long, and once it drops he is collarless — the pound
	# van's collar gate (player_collared) must say so.
	main.set("player_collared", false)
	main.set("state", "opening")
	var houses_arr: Array = main.get("houses")
	var home: Dictionary = houses_arr[int(main.get("home_index"))]
	var door: Vector3 = home["door"]
	facing = float(home["facing"])
	# The road in front of his house: the nearest centreline lying
	# beyond the front door, in the direction the house faces.
	var probe_z: float = door.z + facing * 10.0
	var road_z: float = float(ROAD_CENTRELINES[0])
	var best: float = 1.0e9
	for c in ROAD_CENTRELINES:
		var d: float = absf(float(c) - probe_z)
		if d < best:
			best = d
			road_z = float(c)
	# The stroll line runs down the MIDDLE of the sidewalk band
	# (the band spans ~3.9–4.8 out from the centreline): clear of
	# the traffic lanes, the front hedges (5.6) and the mailbox
	# posts that stand at the band's outer edge.
	var sidewalk_z: float = road_z - facing * 4.3
	street_point = Vector3(door.x, 0, sidewalk_z)
	walk_dir_x = 1.0 if door.x < 40.0 else -1.0
	stroll_end = Vector3(door.x + walk_dir_x * 15.0, 0, sidewalk_z)
	var lane_z: float = road_z - facing * 1.8
	van_stop = Vector3(stroll_end.x + walk_dir_x * 3.0, 0, lane_z)
	van_start = Vector3(stroll_end.x - walk_dir_x * 38.0, 0, lane_z)
	van_yaw = 0.0 if walk_dir_x > 0.0 else PI
	# The worker stands between the cat and the van for his line —
	# so the capture's carry beat walks the cat back toward the van.
	worker_spot = stroll_end + Vector3(walk_dir_x * 1.15, 0, -facing * 0.5)
	# Stage the cat at his own front door. Out he comes.
	(player as Node3D).global_position = door + Vector3(0, 0.25, 0)
	player.set("velocity", Vector3.ZERO)
	(player as Node3D).rotation.y = 0.0 if facing > 0.0 else PI
	player.set("frozen", false)
	player.set("touch_dir", Vector2.ZERO)
	# Stage the van up the street, worker aboard, ready to roll.
	van.global_position = van_start
	van.rotation.y = van_yaw
	van_parked = false
	main.set("pound_van_yaw", van_yaw)
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "patrol")
	main.set("pound_kerb_dir", Vector3(0, 0, -facing))
	# Camera: settle in behind him, town framing.
	main.set("look_yaw", (player as Node3D).rotation.y + PI)
	main.set("look_pitch_deg", 4.0)
	active = true
	finished = false
	phase = "leave"
	phase_t = 0.0


func tick(delta: float) -> void:
	if main == null:
		return
	# The gate swing plays out in any state.
	if gate_anim_t >= 0.0 and cage_gate_pivot:
		gate_anim_t += delta
		var k: float = clampf(gate_anim_t / 0.7, 0.0, 1.0)
		cage_gate_pivot.rotation.y = GATE_OPEN_YAW * (1.0 - pow(1.0 - k, 2.0))
		if k >= 1.0:
			gate_anim_t = -1.0
	var st: String = str(main.get("state"))
	if st == "escape":
		if pound_entry_pending:
			_on_pound_entry()
		_update_cage_prompt()
	# The controls hint belongs to FREE PLAY, not to the pound
	# entry: it fires once, at the first calm moment in town after
	# the pound escape (no pursuit banner up — the two never share
	# the top band).
	if gate_opened and not opening_hint_shown and st == "play":
		var pursuers: Dictionary = main.get("pursuers")
		if pursuers == null or pursuers.is_empty():
			opening_hint_shown = true
			var hint: Object = main.get("hint_label")
			if hint:
				(hint as Control).visible = true
			main.set("hint_timer", 7.0)
	if st != "opening" or not active:
		return
	phase_t += delta
	match phase:
		"leave":
			_tick_leave(delta)
		"stroll":
			_tick_stroll(delta)
		"wait_van":
			_tick_wait_van(delta)
		"line":
			_tick_line(delta)
	_ease_camera(delta)


func _tick_leave(delta: float) -> void:
	_drive_van(delta)
	if _drive_cat(street_point, 0.62) or phase_t > 7.0:
		if phase_t > 7.0:
			(player as Node3D).global_position = Vector3(street_point.x, 0.25, street_point.z)
		phase = "stroll"
		phase_t = 0.0


func _tick_stroll(delta: float) -> void:
	_drive_van(delta)
	# The beat: mid-stroll, the collar slips off. He doesn't notice.
	if not collar_dropped and phase_t >= 1.5:
		_drop_collar((player as Node3D).global_position)
	if _drive_cat(stroll_end, 0.62) or phase_t > 6.5:
		if phase_t > 6.5:
			(player as Node3D).global_position = Vector3(stroll_end.x, 0.25, stroll_end.z)
		player.set("touch_dir", Vector2.ZERO)
		phase = "wait_van"
		phase_t = 0.0


func _tick_wait_van(delta: float) -> void:
	player.set("touch_dir", Vector2.ZERO)
	if _drive_van(delta) or phase_t > 8.0:
		if not van_parked:
			van.global_position = van_stop
			van.rotation.y = van_yaw
			van_parked = true
		phase = "line"
		phase_t = 0.0
		line_step = 0
		line_t = 0.0
		main.call("_pound_worker_out")


func _tick_line(delta: float) -> void:
	if line_step == 0:
		var arrived: bool = bool(main.call("_pound_move_worker", worker_spot, 4.2, delta))
		if arrived or phase_t > 6.0:
			(worker as Node3D).global_position = worker_spot
			var to_cat: Vector3 = (player as Node3D).global_position - worker_spot
			(worker as Node3D).rotation.y = atan2(to_cat.x, to_cat.z)
			worker.call("set_expression", "happy")
			worker.call("show_bubble", WORKER_LINE, 5.2)
			line_step = 1
			line_t = 0.0
	else:
		line_t += delta
		if line_t >= 3.8:
			_trigger_scoop()


# Steer the cat through his own touch input (the module ticks after
# main's joystick pass, so this wins during the beats). Returns true
# on arrival. The magnitude is a gentle happy walk, never a sprint.
func _drive_cat(target: Vector3, mag: float) -> bool:
	var to: Vector3 = target - (player as Node3D).global_position
	to.y = 0.0
	if to.length() < 0.35:
		player.set("touch_dir", Vector2.ZERO)
		return true
	var cam_yaw: float = float(main.get("look_yaw"))
	var local: Vector3 = Basis(Vector3.UP, -cam_yaw) * to.normalized()
	player.set("touch_dir", Vector2(local.x, local.z) * mag)
	return false


# Roll the van along its lane toward the kerb stop. Returns true
# once parked. (During the opening _update_pound is gated off, so
# the module drives; the patrol brain takes over again afterwards.)
func _drive_van(delta: float) -> bool:
	if van_parked:
		return true
	var cur: Vector3 = van.global_position
	var dist: float = absf(van_stop.x - cur.x)
	if dist < 0.3:
		van.global_position = van_stop
		van_parked = true
		return true
	var max_spd: float = 8.0 if phase == "wait_van" else 6.0
	var spd: float = clampf(dist * 0.55, 0.6, max_spd)
	var nx: float = move_toward(cur.x, van_stop.x, spd * delta)
	van.global_position = Vector3(nx, 0, van_stop.z)
	return false


func _ease_camera(delta: float) -> void:
	var target_yaw: float
	if phase == "line":
		# Frame the pair with the van beyond them.
		var dv: Vector3 = van.global_position - (player as Node3D).global_position
		dv.y = 0.0
		if dv.length() < 0.01:
			dv = Vector3(walk_dir_x, 0, 0)
		dv = dv.normalized()
		target_yaw = atan2(-dv.x, -dv.z)
	else:
		target_yaw = (player as Node3D).rotation.y + PI
	var cur: float = float(main.get("look_yaw"))
	main.set("look_yaw", lerp_angle(cur, target_yaw, minf(1.0, 2.5 * delta)))


# ---------------------------------------------------------------------
# THE COLLAR DROP
# ---------------------------------------------------------------------

func _drop_collar(at: Vector3) -> void:
	collar_dropped = true
	player.call("set_collar_visible", false)
	var root := Node3D.new()
	root.name = "DroppedCollar"
	# The sidewalk slab's top surface is y=0.06 (the cat's physics
	# floor is y=0, so a collar lying at floor height would be
	# buried under the slab and invisible) — rest it ON the slab.
	root.position = Vector3(at.x, 0.075, at.z)
	# Lay the tag's print toward the follow camera (behind the cat,
	# back down the street he came from).
	root.rotation.y = walk_dir_x * PI * 0.5
	# The slipped-off collar, rebuilt to match the worn one
	# (Michael, 2026-11-18): a FLAT STRAP loop lying on the slab —
	# not the old round torus "little tire" — with its buckle, its
	# D-ring, and the SAME 2.5 cm tag resting with it, face up.
	# Local slab top is y = -0.015 (root sits at 0.075, slab 0.06).
	var metal := _mat(Color(0.78, 0.80, 0.84), 0.35, 0.5)
	var strap_mat := _mat(Color(0.055, 0.055, 0.07), 0.88, 0.0)
	strap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var band := MeshInstance3D.new()
	band.mesh = _flat_strap_mesh(0.088, 0.013, 0.0038)
	band.position = Vector3(0, -0.0085, 0)
	band.material_override = strap_mat
	root.add_child(band)
	# The buckle, lying on the strap's top face around the loop.
	var buckle := Node3D.new()
	var ba := 2.3
	buckle.position = Vector3(0.088 * sin(ba), -0.0008, 0.088 * cos(ba))
	buckle.rotation.y = ba
	root.add_child(buckle)
	_box(buckle, Vector3(0.0084, 0, 0), Vector3(0.0032, 0.0035, 0.017), metal)
	_box(buckle, Vector3(-0.0084, 0, 0), Vector3(0.0032, 0.0035, 0.017), metal)
	_box(buckle, Vector3(0, 0, 0.0069), Vector3(0.020, 0.0035, 0.0032), metal)
	_box(buckle, Vector3(0, 0, -0.0069), Vector3(0.020, 0.0035, 0.0032), metal)
	_box(buckle, Vector3(0, 0, 0), Vector3(0.0168, 0.003, 0.0024), metal)
	# The D-ring at the loop's front edge, bridging strap and tag
	# the way it does on his neck.
	var dring := MeshInstance3D.new()
	var dtm := TorusMesh.new()
	dtm.inner_radius = 0.0055
	dtm.outer_radius = 0.0085
	dtm.rings = 16
	dtm.ring_segments = 8
	dring.mesh = dtm
	dring.position = Vector3(0, -0.012, 0.0895)
	dring.material_override = metal
	root.add_child(dring)
	# The tag: the same tag he wears — 2.5 cm across — resting on
	# the slab just ahead of the loop, face up. Paler and far less
	# metallic than a mirror finish: a shiny disc mirrors the
	# dusk-blue sky and swallows the print.
	var tag := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.0125
	disc.bottom_radius = 0.0125
	disc.height = 0.0024
	disc.radial_segments = 24
	tag.mesh = disc
	tag.position = Vector3(0, -0.0138, 0.1075)
	tag.material_override = _mat(Color(0.82, 0.83, 0.86), 0.35, 0.15)
	root.add_child(tag)
	# The name printed ON the dropped tag — the very text the worn
	# tag carries (cat.gd set_tag_name printed it at spawn: his
	# name, "Zander" — Michael, 2026-11-18: the tag does NOT show
	# the home address; the address lives on the title screen).
	# Same two-line split and fit-to-width maths as the worn tag,
	# fitted across the disc.
	var tag_text: String = "Zander"
	if player.has_method("get_tag_label"):
		var worn_label: Object = player.call("get_tag_label")
		if worn_label != null:
			tag_text = str((worn_label as Label3D).text)
	var line1: String = tag_text
	var line2: String = ""
	var ci: int = tag_text.find(", ")
	if ci > 0:
		line1 = tag_text.substr(0, ci)
		line2 = tag_text.substr(ci + 2)
	else:
		var sp: int = tag_text.rfind(" ")
		if sp > 0:
			line1 = tag_text.substr(0, sp)
			line2 = tag_text.substr(sp + 1)
	dropped_label = Label3D.new()
	dropped_label.text = line1 + "\n" + line2 if line2 != "" else line1
	dropped_label.font_size = 200
	dropped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dropped_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var widest: float = 0.05
	var font: Font = ThemeDB.fallback_font
	for line in [line1, line2]:
		if line != "":
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x)
	dropped_label.pixel_size = 0.0195 / widest # the name spans the tag's face
	dropped_label.modulate = Color(0.12, 0.12, 0.16)
	dropped_label.position = Vector3(0, -0.0112, 0.1075)
	# Flat, face up, and turned so the print reads upright from
	# the follow camera (which trails behind the cat, up-street):
	# the text's top points down-street, away from that viewer.
	dropped_label.rotation_degrees = Vector3(-90, 0, 180)
	root.add_child(dropped_label)
	main.add_child(root)
	dropped_collar = root
	main.call("show_message", "🐾 His collar slipped off — its tag says: " + tag_text, 4.0)


# ---------------------------------------------------------------------
# THE SCOOP — the game's ordinary capture, staged
# ---------------------------------------------------------------------

func _trigger_scoop() -> void:
	active = false
	finished = true
	pound_entry_pending = true
	# on_cat_taken only runs from "play" — step through it for the
	# one synchronous call; it sets the "cutscene" state itself.
	main.set("state", "play")
	main.call("on_cat_taken", worker)
	# The fiction: he is taken to the POUND, not let out back on
	# this street — so the escape's exit (and the pursuit after it)
	# deposit beside the van's pound parking spot, at the start of
	# its patrol route.
	var route: Array = main.get("pound_route")
	if route.size() >= 1:
		var spot: Vector3 = route[0]
		main.set("capture_return_pos", Vector3(spot.x + 3.0, 0, spot.z - 4.3))
	main.call("show_message", "🚐 The pound — he'll help you find your way home. First: the little cage…", 4.5)


# A tap during the street beats: land every beat instantly, exactly
# where the played-out version leaves things, then ride the
# ordinary capture straight into the pound room.
func skip_opening() -> void:
	if main == null or finished:
		return
	if str(main.get("state")) != "opening":
		return
	player.set("touch_dir", Vector2.ZERO)
	(player as Node3D).global_position = Vector3(stroll_end.x, 0.25, stroll_end.z)
	(player as Node3D).rotation.y = atan2(walk_dir_x, 0.0)
	if not collar_dropped:
		_drop_collar(stroll_end - Vector3(walk_dir_x * 6.0, 0, 0))
	van.global_position = van_stop
	van.rotation.y = van_yaw
	van_parked = true
	main.set("pound_van_yaw", van_yaw)
	main.call("_pound_worker_out")
	(worker as Node3D).global_position = worker_spot
	var to_cat: Vector3 = (player as Node3D).global_position - worker_spot
	(worker as Node3D).rotation.y = atan2(to_cat.x, to_cat.z)
	_trigger_scoop()
	main.call("skip_cutscene")


func _input(event: InputEvent) -> void:
	if main == null or finished:
		return
	if str(main.get("state")) != "opening":
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip_opening()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		skip_opening()


func _unhandled_input(event: InputEvent) -> void:
	if main == null or finished:
		return
	if str(main.get("state")) != "opening":
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		skip_opening()


# ---------------------------------------------------------------------
# THE POUND START — a little cage in the escape room
# ---------------------------------------------------------------------

func cage_active() -> bool:
	# True from the moment the opening's capture is inbound until
	# the cage gate opens. main reads this to keep every other
	# instruction (escape header, distraction line, room message)
	# off the screen while the cat is caged — the cage prompt is
	# the only instruction then.
	return cage_closed or pound_entry_pending


# First tick inside the escape room after the opening's scoop: the
# cat wakes in the cage, and the van (unseen from inside) is back
# at the pound kerb, ready for the patrol to resume later.
func _on_pound_entry() -> void:
	pound_entry_pending = false
	_ensure_cage()
	(player as Node3D).global_position = cage_centre + Vector3(0, 0.3, 0.15)
	player.set("velocity", Vector3.ZERO)
	cage_closed = true
	if cage_gate_pivot:
		cage_gate_pivot.rotation.y = 0.0
	if cage_blocker:
		cage_blocker.disabled = false
	var route: Array = main.get("pound_route")
	if route.size() >= 2:
		var spot: Vector3 = route[0]
		var nxt: Vector3 = route[1]
		van.global_position = spot
		var d: Vector3 = nxt - spot
		var yaw: float = atan2(-d.z, d.x)
		van.rotation.y = yaw
		main.set("pound_van_yaw", yaw)
		main.set("pound_route_idx", 1)
		main.set("pound_kerb_dir", Vector3(0, 0, -1))
	van_parked = true
	# The ride-over line ("🚐 The pound — …First: the little cage…")
	# has had the whole cutscene; its turn ends at the cage door so
	# it can't slide under the cage prompt banner.
	main.call("clear_message_band")
	# MESSAGE DISCIPLINE (2026-11-18): nothing else is said here.
	# The old module line ("A little cage at the pound! PAW the
	# gate… then find the back door!") duplicated the cage prompt
	# button AND the escape header, and it rendered underneath the
	# prompt banner; the escape-room instructions are held by main
	# until the gate opens; and the controls hint does not fire at
	# the pound entry at all — it belongs to free play (see tick()).


func _ensure_cage() -> void:
	if cage_built:
		return
	cage_built = true
	var o: Vector3 = main.get("escape_origin")
	# SHELTER REDESIGN (2026-11-18): the cage now stands IN the
	# south-wall kennel row (see _build_escape_room's kennel ward),
	# centred in the row — his is
	# one kennel among many, and still the only one that opens.
	# Everything cage-relative (gate pos, prompt ranges, the
	# in-cage check) is unchanged; only the anchor moved.
	cage_centre = Vector3(o.x, 0, o.z + 8.55)
	var c: Vector3 = cage_centre
	var root := Node3D.new()
	root.name = "PoundCage"
	main.add_child(root)
	var steel := _mat(Color(0.55, 0.58, 0.62), 0.45, 0.6)
	# Floor slab, and a blanket folded in the corner — somebody
	# made it cosy for him.
	_box(root, c + Vector3(0, 0.03, 0), Vector3(2.7, 0.06, 2.3), _mat(Color(0.42, 0.46, 0.52), 0.8, 0.1))
	_box(root, c + Vector3(-0.8, 0.075, 0.6), Vector3(0.9, 0.03, 0.8), _mat(Color(0.55, 0.3, 0.3), 0.95, 0.0))
	# SHELTER WARD: CHAIN-LINK around the perimeter, like every
	# other front in the ward (the bars are gone); the north side
	# leaves the gate gap. Collision shapes below are unchanged.
	_mesh(root, Vector3(c.x, 0.59, c.z + 1.1), Vector2(2.6, 1.1)) # south
	_mesh(root, Vector3(c.x - 0.89, 0.59, c.z - 1.1), Vector2(0.82, 1.1)) # north, west of the gate
	_mesh(root, Vector3(c.x + 0.89, 0.59, c.z - 1.1), Vector2(0.82, 1.1)) # north, east of the gate
	var side_l := _mesh(root, Vector3(c.x - 1.3, 0.59, c.z), Vector2(2.2, 1.1))
	side_l.rotation_degrees = Vector3(0, 90, 0)
	var side_r := _mesh(root, Vector3(c.x + 1.3, 0.59, c.z), Vector2(2.2, 1.1))
	side_r.rotation_degrees = Vector3(0, 90, 0)
	for px3 in [-1.3, 1.3]:
		for pz3 in [-1.1, 1.1]:
			_box(root, c + Vector3(px3, 0.58, pz3), Vector3(0.06, 1.16, 0.06), steel) # corner posts
	# Top frame.
	_box(root, c + Vector3(0, 1.16, 1.1), Vector3(2.7, 0.05, 0.07), steel)
	_box(root, c + Vector3(0, 1.16, -1.1), Vector3(2.7, 0.05, 0.07), steel)
	_box(root, c + Vector3(-1.3, 1.16, 0), Vector3(0.07, 0.05, 2.3), steel)
	_box(root, c + Vector3(1.3, 1.16, 0), Vector3(0.07, 0.05, 2.3), steel)
	# The gate: a framed bar panel on a pivot at its west jamb.
	cage_gate_pivot = Node3D.new()
	cage_gate_pivot.name = "CageGate"
	cage_gate_pivot.position = Vector3(c.x - 0.48, 0, c.z - 1.1)
	root.add_child(cage_gate_pivot)
	_box(cage_gate_pivot, Vector3(0.48, 1.16, 0), Vector3(0.96, 0.05, 0.06), steel)
	_box(cage_gate_pivot, Vector3(0.48, 0.06, 0), Vector3(0.96, 0.05, 0.06), steel)
	_box(cage_gate_pivot, Vector3(0.02, 0.6, 0), Vector3(0.05, 1.15, 0.06), steel)
	_box(cage_gate_pivot, Vector3(0.94, 0.6, 0), Vector3(0.05, 1.15, 0.06), steel)
	_mesh(cage_gate_pivot, Vector3(0.48, 0.59, 0), Vector2(0.86, 1.04)) # the gate is mesh too
	# A little POUND sign over the gate, facing the room.
	var sign_label := Label3D.new()
	sign_label.text = "POUND"
	sign_label.font_size = 100
	sign_label.pixel_size = 0.0035
	sign_label.modulate = Color(1.0, 0.95, 0.8)
	sign_label.position = c + Vector3(0, 1.38, -1.14)
	sign_label.rotation_degrees = Vector3(0, 180, 0)
	root.add_child(sign_label)
	# Collision: one static body for the walls; the gate span gets
	# its own shape, disabled while the gate stands open.
	var body := StaticBody3D.new()
	body.name = "PoundCageBody"
	root.add_child(body)
	_shape(body, c + Vector3(0, 0.6, 1.1), Vector3(2.7, 1.2, 0.1))
	_shape(body, c + Vector3(-1.3, 0.6, 0), Vector3(0.1, 1.2, 2.3))
	_shape(body, c + Vector3(1.3, 0.6, 0), Vector3(0.1, 1.2, 2.3))
	_shape(body, c + Vector3(-0.91, 0.6, -1.1), Vector3(0.82, 1.2, 0.1))
	_shape(body, c + Vector3(0.91, 0.6, -1.1), Vector3(0.82, 1.2, 0.1))
	cage_blocker = CollisionShape3D.new()
	var gs := BoxShape3D.new()
	gs.size = Vector3(0.96, 1.2, 0.1)
	cage_blocker.shape = gs
	cage_blocker.position = c + Vector3(0, 0.6, -1.1)
	cage_blocker.disabled = true # open until a pound entry closes it
	body.add_child(cage_blocker)


# Called from main's _escape_interact BEFORE its own logic: a PAW
# at the cage gate is the module's. Returns true only when the paw
# was spent on the gate; every other paw falls through untouched.
func handle_escape_paw() -> bool:
	if main == null or not cage_closed:
		return false
	if str(main.get("state")) != "escape":
		return false
	var pp: Vector3 = (player as Node3D).global_position
	var gp: Vector3 = cage_gate_pos()
	if Vector2(pp.x - gp.x, pp.z - gp.z).length() > 1.6:
		return false
	player.call("do_paw_swipe")
	_open_gate()
	return true


func _open_gate() -> void:
	cage_closed = false
	gate_opened = true
	if cage_blocker:
		cage_blocker.disabled = true
	gate_anim_t = 0.0
	if cage_prompt_btn:
		cage_prompt_btn.visible = false
	main.call("show_message", "The cage gate swings open! Now — the back door! 🐾", 3.5)
	# The gate is open, so the instructions that waited while he
	# was caged take their turn now: the escape header comes back,
	# and the held room message queues behind the gate's own line.
	main.call("_update_escape_label")
	main.call("release_held_escape_message")


func _on_cage_prompt_pressed() -> void:
	handle_escape_paw()


func _update_cage_prompt() -> void:
	if cage_prompt_btn == null:
		return
	var show: bool = false
	if cage_closed and player:
		var pp: Vector3 = (player as Node3D).global_position
		var gp: Vector3 = cage_gate_pos()
		show = Vector2(pp.x - gp.x, pp.z - gp.z).length() < 2.3
	cage_prompt_btn.visible = show
	if show:
		var s: float = 1.0 + 0.045 * sin(Time.get_ticks_msec() / 150.0)
		cage_prompt_btn.scale = Vector2(s, s)


# ---------------------------------------------------------------------
# Small builders + suite-facing helpers
# ---------------------------------------------------------------------

func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


# A flat STRAP loop lying in the X-Z plane: a rectangular
# cross-section (height = the strap's width, thin radially)
# swept around a circle — the dropped collar's band, matching
# the worn strap's build in cat.gd (the old TorusMesh read as a
# little tire). Four crisp faces with flat normals.
func _flat_strap_mesh(radius: float, height: float, thick: float, segs: int = 40) -> ArrayMesh:
	var hh := height * 0.5
	var ro := radius + thick * 0.5
	var ri := radius - thick * 0.5
	# Per station: corners 0 outer/top, 1 outer/bottom,
	# 2 inner/top, 3 inner/bottom, plus the radial normal.
	var stations: Array = []
	for i in range(segs + 1):
		var th := TAU * float(i) / float(segs)
		var co := cos(th)
		var si := sin(th)
		stations.append([
			Vector3(ro * co, hh, ro * si), Vector3(ro * co, -hh, ro * si),
			Vector3(ri * co, hh, ri * si), Vector3(ri * co, -hh, ri * si),
			Vector3(co, 0, si)])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	var surfaces := [
		[1, 0, 0], # outer wall — radial normal
		[0, 2, 1], # top rim (+Y)
		[2, 3, 2], # inner wall — inward normal
		[3, 1, 3], # bottom rim (-Y)
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
				nrm = Vector3(0, 1, 0)
			elif kind == 2:
				nrm = -st[4]
			elif kind == 3:
				nrm = Vector3(0, -1, 0)
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


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _bar(parent: Node, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.018
	cm.height = 1.12
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


var _cl_tex: Texture2D = null


# The ward's chain-link: a generated diamond-weave texture (the
# same weave main3d uses), alpha-scissored so it reads as real
# mesh from both sides.
func _chainlink_tex() -> Texture2D:
	if _cl_tex:
		return _cl_tex
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wire := Color(0.72, 0.75, 0.8, 1.0)
	for i in range(96):
		for k in range(3):
			img.set_pixel(i, (i + k * 32) % 96, wire)
			img.set_pixel(i, (k * 32 - i + 96) % 96, wire)
	_cl_tex = ImageTexture.create_from_image(img)
	return _cl_tex


func _mesh(parent: Node, pos: Vector3, size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_texture = _chainlink_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.45
	m.roughness = 0.45
	m.uv1_scale = Vector3(size.x / 0.44, size.y / 0.44, 1)
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _shape(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)


func cage_gate_pos() -> Vector3:
	return Vector3(cage_centre.x, 0, cage_centre.z - 1.1)


func cat_in_cage() -> bool:
	if not cage_closed or player == null:
		return false
	var pp: Vector3 = (player as Node3D).global_position
	return absf(pp.x - cage_centre.x) < 1.2 and absf(pp.z - cage_centre.z) < 1.0


func dropped_tag_text() -> String:
	return dropped_label.text if dropped_label != null else ""
