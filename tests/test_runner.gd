extends Node
## HOMEWARD v0.9 automated test suite (v0.8 set + v0.9 sections).
## Run: godot --headless --path . tests/TestRunner.tscn
## Boots the real Main scene and exercises the v0.8 behaviours:
## houses clear of road corridors + numbers in order (items 1+2),
## paw swipe always resets (item 4), notice bar ONLY for the grabber
## + friendly bend-down pet/treat on paw/meow only (item 5), plus the
## retained v0.7 set: no minimap, roles (population step: 9 of 34 seek the cat — 25% of everyone, rounded up),
## flat sign text, camera far plane, RUN-hold sprint + winded drop (v1.0.14),
## RUN hold driven through the REAL two-finger touch path (v1.0.18),
## per-captor pronoun consistency across all generated escape text (v1.0.19),
## the v1.0.20 indoor camera (room profile: entry pitch, orbit/FOV,
## cat share bounds mid-room and in a corner, the pull-in lift),
## the v1.0.23 set: a full house-parts audit (no detached or
## floating house parts anywhere in town), the grass blades as
## outward-normal cones (the black-spike fix), the park with the
## Meshy playground (grounded, kid-scale, solid) with the old
## equipment removed and park-dweller kids playing there, and
## the frosted title panel (medallion instead of the collar tag,
## gradient START, no address),
## the v1.0.21 set: HOP while sprinting through the real
## three-finger touch path (momentum preserved, lands running),
## the escape combination as a randomly rolled A/B sequence
## (5 steps, re-rolled per start, wrong press resets), the
## officer's grabber notice meter from the van AND on foot, the
## patrol route audit (the van's body never inside a house lot),
## and the depot cycle (the van parks INSIDE its garage),
## collar check removed (v1.0.8: button/zoom gone, tag print kept),
## single-mechanism escapes (v1.4: the back
## door for EVERY capture — the carrier is transport only),
## exactly-30s pursuit, traffic, solid fences + open cat gaps,
## purr, the v1.3 camera framing (person + notice bar and sign
## boards inside the frustum at interaction distance, cat share
## floor), the v1.4 camera handoff (an escape restores the
## town framing — pitch/yaw/FOV/distance — for the pursuit),
## and the v1.0.13 far-pursuer pursuit framing (a pursuer tens
## of metres behind cannot drag the camera off the cat).

var main: Node = null
var player: Node = null
var passed: int = 0
var failed: int = 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: ", name)
	else:
		failed += 1
		print("FAIL: ", name, " -- ", detail)

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func set_joy(vec: Vector2) -> void:
	# Drive the REAL floating joystick (main._apply_joystick reads it).
	main.set("joy_mouse", true)
	main.set("joy_origin", Vector2(200, 400))
	main.set("joy_current", Vector2(200, 400) + vec)

func clear_joy() -> void:
	main.set("joy_mouse", false)
	main.set("joy_id", -999)

func count_meshes(n: Node) -> int:
	var c: int = 0
	if n is MeshInstance3D:
		c += 1
	for ch in n.get_children():
		c += count_meshes(ch)
	return c

func _subtree_vehicle_path(n: Node) -> String:
	# v1.0.21: the assets/models GLB a subtree was instantiated
	# from ("" if none) — how the suite recognises a Meshy vehicle.
	if n.scene_file_path.begins_with("res://assets/models/") and n.scene_file_path.ends_with(".glb"):
		return n.scene_file_path
	for ch in n.get_children():
		var r: String = _subtree_vehicle_path(ch)
		if r != "":
			return r
	return ""

func npc_by_role(role: String) -> Node:
	for n in main.get("npcs"):
		if str(n.get("role")) == role:
			return n
	return null

func wait_leg_stable(leg: Node3D, min_wait: float) -> Vector3:
	# Wait until the leg's rotation stops changing (pose converged),
	# so before/after paw samples compare settled states even if the
	# headless engine's physics rate wobbles under load.
	await wait_sec(min_wait)
	var prev: Vector3 = leg.rotation
	for i in range(16):
		await wait_sec(0.3)
		var cur: Vector3 = leg.rotation
		if cur.distance_to(prev) < 0.004:
			return cur
		prev = cur
	return leg.rotation

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

# v1.1 escape driving: the REAL flow — prompt -> panel -> the
# combination. v1.2: a finished combo OPENS the way (no scripted
# exit); the escape completes when the cat crosses the threshold,
# so the harness walks him out (walk_cat_out) — and the intended
# path now starts with a DISTRACTION (distract_captor):
# undistracted, she interrupts the panel in ~1.2 s of room time.
# v1.0.21: the combination is a RANDOMLY ROLLED A/B sequence (main's
# escape_combo, 5 presses) — the harness reads the current roll and
# presses exactly it.
func drive_escape_panel() -> void:
	main.call("_on_escape_prompt_pressed")
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))

func distract_captor() -> void:
	# The intended path: stand by the plant, paw it over, and let a
	# little room time pass so she is on her way to it (distracted).
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1

func walk_cat_out() -> void:
	# Player-driven exit: the cat is placed just beyond the opened
	# threshold and _process_escape completes the escape there —
	# exactly what walking out does in real play.
	var kind: String = str(main.get("exit_open_kind"))
	var o: Vector3 = main.get("escape_origin")
	match kind:
		"latch", "winpush":
			(player as Node3D).global_position = o + Vector3(0, 0.3, -11.2)
		"petdoor", "carrier":
			(player as Node3D).global_position = o + Vector3(6, 0.3, -11.2)
		"bolt":
			(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)

func band_texts() -> Array:
	# Everything currently on the message band: the showing message
	# plus the queued ones, in order.
	var out: Array = []
	var lab = main.get("message_label")
	if lab and str(lab.text) != "":
		out.append(str(lab.text))
	for q in main.get("message_queue"):
		out.append(str(q["text"]))
	return out

func npc_by_type(t: String) -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == t:
			return n
	return null

func collect_captor_texts(cap: Node) -> Array:
	# v1.0.19: enter the escape room with `cap` as captor and gather
	# every captor-referring line the game generates for them: the
	# two entry beats, the distract HUD (idle + busy), the escape
	# panel's status strip (watching + busy), the topple message
	# and the spotted-at-the-door message. The pronoun checks read
	# the whole set at once — Michael's bug was two lines on ONE
	# screen disagreeing about the same captor.
	var texts: Array = []
	main.call("clear_message_band")
	main.set("captor", cap)
	main.call("_enter_escape")
	texts.append_array(band_texts())
	if str(main.get("held_escape_message")) != "":
		texts.append(str(main.get("held_escape_message")))
		texts.append(str(main.get("held_escape_message_2")))
	# distract HUD, captor undistracted
	main.call("_update_distract_hud")
	var dl = main.get("distract_label")
	if dl:
		texts.append(str(dl.text))
	# panel status, undistracted: the "watching" line
	var o: Vector3 = main.get("escape_origin")
	(player as Node3D).global_position = o + Vector3(13.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	main.call("_process_escape", 0.05)
	var panel = main.get("escape_panel")
	if panel:
		texts.append(str(panel.get("status_text")))
	main.call("_close_escape_panel")
	# topple a prop: the crash message, and the captor is distracted
	main.call("clear_message_band")
	var props: Array = main.get("distract_props")
	(player as Node3D).global_position = (props[0]["base"] as Vector3) + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	texts.append_array(band_texts())
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1
	# distract HUD, captor busy
	main.call("_update_distract_hud")
	if dl:
		texts.append(str(dl.text))
	# panel status, distracted: the "busy" line
	(player as Node3D).global_position = o + Vector3(13.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	main.call("_process_escape", 0.05)
	if panel:
		texts.append(str(panel.get("status_text")))
	main.call("_close_escape_panel")
	# spotted at the door: the interrupt message
	main.call("clear_message_band")
	main.call("_interrupt_escape")
	texts.append_array(band_texts())
	return texts

func find_buttons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		find_buttons(c, out)

func collect_label3d(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Label3D:
			out.append(c)
		collect_label3d(c, out)

func _ready() -> void:
	await run_tests()

func run_tests() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	# v1.0.9 harness plumbing: Main now builds its world across frames
	# behind the splash — wait for build_complete before driving it,
	# exactly as the title flow does. No assertion is changed.
	var _bw109: int = 0
	while not bool(main.get("build_complete")) and _bw109 < 21600:
		await get_tree().process_frame
		_bw109 += 1
	await wait_sec(0.6)
	player = main.get("player")

	# ---------- static / build-time checks ----------
	check("boot: starts on splash", str(main.get("state")) == "splash", str(main.get("state")))
	var prop_names: Array = []
	for p in main.get_property_list():
		prop_names.append(str(p["name"]))
	check("minimap removed (no minimap/map_on state)", not prop_names.has("minimap") and not prop_names.has("map_on"))
	check("camera far plane explicit >= 400", float((main.get("cam") as Camera3D).far) >= 400.0, str((main.get("cam") as Camera3D).far))
	var buttons: Array = []
	find_buttons(main.get("touch_layer"), buttons)
	var texts: Array = []
	for b in buttons:
		texts.append((b as Button).text)
	check("no SPRINT button", not texts.any(func(t): return "SPRINT" in t), str(texts))
	check("no MAP button", not texts.any(func(t): return t == "MAP"), str(texts))
	check("PAW/HOP/MEOW buttons present, COLLAR + LOOK buttons absent (v1.0.8)", texts.any(func(t): return "PAW" in t) and texts.any(func(t): return "HOP" in t) and texts.any(func(t): return "MEOW" in t) and not texts.any(func(t): return "COLLAR" in t) and not texts.any(func(t): return "LOOK" in t), str(texts))
	# roles (item 14)
	var g: int = 0
	var f: int = 0
	var ig: int = 0
	for n in main.get("npcs"):
		match str(n.get("role")):
			"grabber": g += 1
			"friendly": f += 1
			"ignore": ig += 1
	check("roles: exactly 12 grabbers of 48 (map doubling: 25% of 48)", g == 12 and main.get("npcs").size() == 48, "g=%d total=%d" % [g, main.get("npcs").size()])
	check("roles: grabbers are ~25% of everyone (Michael's rule)", absf(float(g) / float(maxi(1, main.get("npcs").size())) - 0.25) <= 0.02, "share=%.3f" % (float(g) / float(maxi(1, main.get("npcs").size()))))
	check("roles: 19 friendly / 17 ignore (friendly >= ignore)", f == 19 and ig == 17, "f=%d ig=%d" % [f, ig])
	# v0.9 structural art: mesh counts must be OBVIOUSLY above v0.8
	# (cat 103, woman 43) — a texture-only pass cannot pass this.
	# v12 SCULPT: the cat's ~45 primitive chunks (stacked spheres,
	# torus stripes, cone ears) were replaced by single sculpted
	# meshes (lofted body/legs/tail, parametric head, shaped ears,
	# dome eye stacks), so the NODE count drops to 87 while vertex
	# counts and surface detail rise sharply. The floor now guards
	# the full part list staying present, not primitive volume.
	check("cat model: sculpted part list intact (>=80 meshes, sculpt build is 87)", count_meshes(player) >= 80, str(count_meshes(player)))
	var woman0: Node = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman":
			woman0 = n
			break
	check("npc model: structural geometry jump (>=55 meshes, v0.8 was 43)", woman0 != null and count_meshes(woman0) >= 55, str(count_meshes(woman0)) if woman0 else "none")
	check("houses: 131 after the map doubling (was 41)", (main.get("houses") as Array).size() == 131, str((main.get("houses") as Array).size()))
	# street signs: text flat ON the board (item 3)
	var sign_texts: Array = []
	for s in main.get("street_signs"):
		sign_texts.append(str(s["text"]))
	check("26 street signs registered (13 streets x 2)", sign_texts.size() == 26, str(sign_texts.size()))
	var labels: Array = []
	collect_label3d(main, labels)
	var sign_labels: Array = []
	var billboard_sign_labels: int = 0
	for l in labels:
		if sign_texts.has((l as Label3D).text):
			sign_labels.append(l)
			if (l as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
				billboard_sign_labels += 1
	check("sign text on both faces (52 flat labels)", sign_labels.size() == 52, str(sign_labels.size()))
	check("sign text is NOT billboard (readable only face-on)", billboard_sign_labels == 0, str(billboard_sign_labels))
	# scoreboard (item 9)
	check("scoreboard font is big (30)", int((main.get("score_label") as Label).label_settings.font_size) == 30)
	# splash / title anchoring (item 8)
	var sp: Control = main.get("splash_panel")
	check("splash panel full-rect anchors", sp.anchor_right == 1.0 and sp.anchor_bottom == 1.0, "%s/%s" % [sp.anchor_right, sp.anchor_bottom])
	var tp: Control = main.get("title_panel")
	check("title panel centred anchors", tp.anchor_left == 0.5 and tp.anchor_top == 0.5, "%s/%s" % [tp.anchor_left, tp.anchor_top])
	# v1.0.17 (Michael's direction): the title panel must NOT show
	# the home address — no label carrying the address text and no
	# "collar tag says" line. The address still exists internally.
	var tp_addr_shown: bool = false
	var tp_stack: Array = [tp]
	while not tp_stack.is_empty():
		var tn: Node = tp_stack.pop_back()
		for tc in tn.get_children():
			tp_stack.append(tc)
		var tlab := tn as Label
		if tlab and (tlab.text == str(main.get("home_address")) or tlab.text.contains("collar tag says")):
			tp_addr_shown = true
	check("v1.0.17: title panel does NOT show the home address (still generated internally)", not tp_addr_shown and str(main.get("home_address")) != "", "addr='" + str(main.get("home_address")) + "' shown=" + str(tp_addr_shown))
	# score values (v0.6 rules retained)
	main.set("score", 100)
	main.call("on_pet", null)
	check("pet = +1", int(main.get("score")) == 101, str(main.get("score")))
	main.call("on_treat", null)
	check("treat = +5", int(main.get("score")) == 106, str(main.get("score")))
	var lost: int = int(main.call("apply_capture_penalty"))
	check("capture penalty = -20%", lost == 21 and int(main.get("score")) == 85, "lost=%d score=%d" % [lost, int(main.get("score"))])
	# sprint top speed beats every chaser (item 2a)
	var max_chase: float = 0.0
	for n in main.get("npcs"):
		max_chase = maxf(max_chase, float(n.get("chase_speed")))
	check("cat sprint (11.5) clearly outruns fastest chaser", float(player.get("speed_sprint")) >= max_chase + 2.0, "sprint=%s chase=%s" % [player.get("speed_sprint"), max_chase])
	# escape variant pools (item 6, v1.4): ONE way out for EVERY
	# capture — the BACK DOOR (the "bolt" mechanism). Michael's
	# rule: the cat carrier is transport only and must never be
	# the puzzle; the window and pet door are never selected
	# either. One clear, learnable rule: the door is how you
	# get out.
	var pools_ok: bool = true
	var pool_detail: String = ""
	for ctype in ["woman", "kid", "dogwalker", "shopkeeper", "pedestrian"]:
		var pool: Array = main.call("_variant_pool", ctype)
		if pool.size() != 1 or (pool[0] as Array) != ["bolt"]:
			pools_ok = false
			pool_detail = ctype + " pool " + str(pool)
	check("escapes: EVERY capture's way out is the back door (carrier = transport only, never the puzzle)", pools_ok, pool_detail)

	# ---------- enter play ----------
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	# STORY PART 1 (2026-11-18): START no longer drops the cat
	# straight into town — the opening cutscene plays first (he
	# leaves his house, loses his collar, the pound van takes him
	# in) and the run begins with the pound escape. Drive the
	# whole flow here, through the module's own skip path.
	check("STORY: START begins the opening cutscene, not town play", str(main.get("state")) == "opening", str(main.get("state")))
	var story_mod: Node = main.get("story")
	check("STORY: the opening module is live", story_mod != null)
	var home_h: Dictionary = (main.get("houses") as Array)[int(main.get("home_index"))]
	check("STORY: the cat is staged at his own front door", (player as Node3D).global_position.distance_to(home_h["door"]) < 2.5, str((player as Node3D).global_position))
	check("STORY: the run starts collarless (player_collared false — the van's gate tells the truth)", not bool(main.get("player_collared")))
	check("STORY: he still wears the collar at the start (it drops mid-stroll)", bool(player.call("is_collar_visible")))
	story_mod.call("skip_opening")
	check("STORY: the skip lands in the pound escape room", str(main.get("state")) == "escape", str(main.get("state")))
	check("STORY: the skip's captor is the pound worker", main.get("captor") == main.get("pound_worker"))
	check("v1.0.17: the officer's capture lands in the SHELTER (not the house)", not bool(main.get("escape_room_is_house")) and (main.get("ward_cages") as Array).size() >= 10, "is_house=" + str(main.get("escape_room_is_house")) + " ward=" + str((main.get("ward_cages") as Array).size()))
	await wait_sec(0.4)
	check("STORY: pound start = the cat is in the little cage", bool(story_mod.get("cage_closed")) and bool(story_mod.call("cat_in_cage")))
	check("STORY: the collar is off, lying where it fell, its tag printed with his name (Zander — not the address)", not bool(player.call("is_collar_visible")) and story_mod.get("dropped_collar") != null and str(story_mod.call("dropped_tag_text")) == "Zander", str(story_mod.call("dropped_tag_text")))
	check("STORY: the dropped collar rests ON the sidewalk slab (y >= 0.06 — visible, not buried under it)", story_mod.get("dropped_collar") != null and (story_mod.get("dropped_collar") as Node3D).global_position.y >= 0.06, str((story_mod.get("dropped_collar") as Node3D).global_position.y) if story_mod.get("dropped_collar") != null else "none")
	check("STORY: still collarless in the pound (he stays van-eligible)", not bool(main.get("player_collared")))
	# Out of the cage: PAW at the gate, through the real interact path.
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	check("STORY: PAW at the cage gate opens it", not bool(story_mod.get("cage_closed")))
	# The pound escape itself: the ordinary bolt-door flow.
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	walk_cat_out()
	check("STORY: the pound escape leads out to town, the worker pursuing", str(main.get("state")) == "play" and (main.get("pursuers") as Dictionary).has(main.get("pound_worker")), str(main.get("state")))
	# Tidy up: end his pursuit so the sections below run
	# undisturbed, and park him back on patrol (held off below).
	var story_worker: Node = main.get("pound_worker")
	# v1.0.17 FIX 2 PROOF: the pursuit must MOVE him — on the old
	# code his brain was never switched on for the opening's
	# capture (active stayed false), so he ran in place forever.
	# Give him open ground and sample him on the real clock.
	var sw0: Vector3 = (story_worker as Node3D).global_position
	(player as Node3D).global_position = sw0 + Vector3(11.0, 0.3, 0.0)
	var sd0: float = sw0.distance_to((player as Node3D).global_position)
	await wait_sec(1.2)
	var sw1: Vector3 = (story_worker as Node3D).global_position
	var sd1: float = sw1.distance_to((player as Node3D).global_position)
	check("v1.0.17: after a pound escape the officer MOVES in pursuit (displaced, closing)", sw0.distance_to(sw1) > 1.5 and sd1 < sd0 - 1.0, "disp=" + str(sw0.distance_to(sw1)) + " dist " + str(sd0) + "->" + str(sd1))
	check("v1.0.17: the pursuing officer's brain is on (active)", bool(story_worker.get("active")))
	story_worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(story_worker)
	main.set("pound_engage_cd", 99999.0) # set BEFORE patrol resumes: the deposit spot is inside his spot radius
	main.set("pound_state", "patrol")
	story_worker.set("active", false)
	(story_worker as Node3D).visible = false
	story_worker.call("set_net_visible", true) # as his return-to-van does: net back in hand
	story_worker.call("set_expression", "neutral")
	# POUND VAN: the patrol van is live in the world from here on,
	# but his engagements would make the sections below racy (the
	# cat legitimately crosses his roads) — hold him off with the
	# engagement cooldown until his own section re-arms him.
	main.set("pound_engage_cd", 99999.0)

	# ---------- houses: placement audit + numbering (v0.8 items 1+2) ----------
	var road_zs: Array = [-55.0, -11.0, 15.0, 55.0]
	var road_xs: Array = [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0] # MAP DOUBLING: + the five east cross streets
	var houses_arr: Array = main.get("houses")
	var aabb_ok: bool = true
	var vista_ok: bool = true
	for h in houses_arr:
		var hp: Vector3 = h["pos"]
		var face: float = float(h["facing"])
		var zmin: float = hp.z + minf(face * 5.2, -face * 3.9)
		var rect := Rect2(hp.x - 5.8, zmin, 11.6, 9.1) # footprint incl. fences/porch
		for rz in road_zs:
			if rect.intersects(Rect2(-320.0, rz - 4.35, 760.0, 8.7)): # road rect + 0.75 margin (MAP DOUBLING: spans the whole doubled map)
				aabb_ok = false
		for rx in road_xs:
			if rect.intersects(Rect2(rx - 4.35, -200.0, 8.7, 400.0)):
				aabb_ok = false
			if absf(hp.x - rx) <= 10.0:
				vista_ok = false
	check("houses: no footprint intrudes into any road corridor (+0.75 margin)", aabb_ok)
	check("houses: no house blocks a cross-street vista (centre >10 from vertical centrelines)", vista_ok)
	var streets: Dictionary = {}
	for h in houses_arr:
		var addr: String = str(h["address"])
		var num: int = int(addr.split(" ")[0])
		var street: String = addr.trim_prefix(addr.split(" ")[0] + " ").split(",")[0]
		var key: String = street + (" N" if float(h["facing"]) > 0.0 else " S")
		if not streets.has(key):
			streets[key] = []
		streets[key].append([float(h["pos"].x), num])
	var order_ok: bool = true
	var parity_ok: bool = true
	var seen_nums: Array = []
	for key in streets:
		var row: Array = streets[key]
		row.sort_custom(func(a, b): return a[0] < b[0])
		for i in range(row.size()):
			# v0.9: uniqueness is per STREET (number+street is the
			# address) — real streets reuse numbers across streets;
			# the v0.9 fill rows interleave like real ones do.
			var skey: String = key + "#" + str(int(row[i][1]))
			if seen_nums.has(skey):
				order_ok = false
			seen_nums.append(skey)
			if i > 0 and int(row[i][1]) <= int(row[i - 1][1]):
				order_ok = false
			if (int(row[i][1]) % 2 == 1) != key.ends_with(" N"):
				parity_ok = false
	check("house numbers strictly increase west->east per street/side, no duplicates", order_ok)
	check("house numbers: odd on the north side, even on the south", parity_ok)

	# ---------- v0.9 empty-area audit (item 1) ----------
	var cps: Array = main.get("content_points")
	check("world content points plentiful (>= 170)", cps.size() >= 170, str(cps.size()))
	var bad_cells: Array = []
	for gx in range(-114, 368, 11): # MAP DOUBLING: audit grid covers the east district too
		for gz in range(-88, 89, 11):
			var cx: float = float(gx)
			var cz: float = float(gz)
			var on_road: bool = false
			for rz2 in road_zs:
				if absf(cz - rz2) < 5.6: on_road = true
			for rx2 in road_xs:
				if absf(cx - rx2) < 5.6: on_road = true
			if on_road:
				continue
			var best: float = 1e9
			for cp in cps:
				var dd: float = Vector2(cx - (cp as Vector3).x, cz - (cp as Vector3).z).length()
				if dd < best:
					best = dd
			if best > 12.5:
				bad_cells.append(Vector2(cx, cz))
	check("no large empty areas (every land cell has content within 12.5)", bad_cells.is_empty(), str(bad_cells.slice(0, 6)) + " n=" + str(bad_cells.size()))

	# ---------- streets audit (Michael, 2026-11-16): parked cars in
	# driveways, NEVER on a roadway; every car a proper car ----------
	# Static cars are found STRUCTURALLY: _build_car names every car
	# root "Car" but Godot renames duplicates on add_child (@Node3D@N),
	# so the reliable marker is the "hide ⛺" Label3D only statics
	# carry (traffic cars live under traffic_group, label-free).
	var asphalt_rects: Array = []
	for rz3 in road_zs:
		asphalt_rects.append(Rect2(-126.0, rz3 - 3.6, 504.0, 7.2)) # MAP DOUBLING: roads span the doubled map
	for rx3 in road_xs:
		asphalt_rects.append(Rect2(rx3 - 3.6, -96.0, 7.2, 192.0))
	var static_cars: Array = []
	for ch3 in main.get_node("World").get_children():
		if not (ch3 is Node3D):
			continue
		for sub3 in ch3.get_children():
			if sub3 is Label3D and (sub3 as Label3D).text.contains("hide"):
				static_cars.append(ch3)
	check("streets: all static cars present (16 driveways + 6 lot cars)", static_cars.size() == 22, str(static_cars.size()))
	var cars_on_road := 0
	var cars_boxy := 0
	for c3 in static_cars:
		var crect := Rect2()
		var cfirst := true
		var cmeshes := 0
		var cstack: Array = [c3]
		while not cstack.is_empty():
			var cn: Node = cstack.pop_back()
			for cch in cn.get_children():
				cstack.append(cch)
			if cn is MeshInstance3D:
				cmeshes += 1
				var ca: AABB = (cn as MeshInstance3D).global_transform * (cn as MeshInstance3D).get_aabb()
				var cr := Rect2(ca.position.x, ca.position.z, ca.size.x, ca.size.z)
				crect = cr if cfirst else crect.merge(cr)
				cfirst = false
		for ar in asphalt_rects:
			if crect.intersects(ar):
				cars_on_road += 1
		# v1.0.21: a "proper car" is a Meshy model now (Michael's
		# all-Meshy rule) — the old >=20-meshes/>=8-cylinders test
		# described the code-built box cars, which are gone. A
		# proper car = a vehicle GLB instance under the Car root
		# (never the Animal Control van — that one is the pound's)
		# with a car-sized footprint.
		var cmodel: String = _subtree_vehicle_path(c3)
		var clen: float = maxf(crect.size.x, crect.size.y)
		var cwid: float = minf(crect.size.x, crect.size.y)
		if cmodel == "" or cmodel.ends_with("van_animal_control.glb") or clen < 3.4 or clen > 5.4 or cwid < 1.6 or cwid > 2.6:
			cars_boxy += 1
	check("streets: ZERO static cars on any roadway", cars_on_road == 0, str(cars_on_road))
	check("streets: every static car is a proper car (a Meshy vehicle model, car-sized)", cars_boxy == 0, str(cars_boxy))

	# ---------- clutter audit (Michael, 2026-11-17): NOTHING but
	# moving traffic belongs on a roadway — benches, fences,
	# mailboxes, hedges, lamps, bins, flowerbeds, flowers — and
	# every house has EXACTLY ONE mailbox (he found benches
	# centred on Cedar/Birch, fence runs crossing four streets,
	# a lamp in Cedar, Willow Hall's wall in Birch Lane, and
	# THREE-mailbox clusters). Same structural classification as
	# the kept probe (tests/ClutterProbe.tscn). Sign BOARDS may
	# overhang a corner at 3.75m like real signs; their POLES are
	# audited. Border dressing beyond the fences, where the roads
	# end, is out of scope. ----------
	var house_groups: Dictionary = {}
	for ch4 in main.get_node("World").get_children():
		if ch4 is Node3D:
			for h4 in houses_arr:
				if (ch4 as Node3D).position.distance_to(h4["pos"]) < 0.01:
					house_groups[ch4] = str(h4["address"])
	var clutter_totals: Dictionary = {}
	var clutter_onroad: Dictionary = {}
	var clutter_other_onroad := 0
	var stray_mailbox_meshes := 0
	var cstack: Array = [main.get_node("World")]
	while not cstack.is_empty():
		var cn4: Node = cstack.pop_back()
		if cn4.name == "Traffic" or cn4.name == "Car":
			continue
		for cch4 in cn4.get_children():
			cstack.append(cch4)
		if not (cn4 is MeshInstance3D):
			continue
		var mi4 := cn4 as MeshInstance3D
		var mp4: Vector3 = mi4.global_position
		if mp4.x < -117.0 or mp4.x > 369.0 or absf(mp4.z) > 91.0: # MAP DOUBLING: east audit bound moved with the border
			continue # border dressing beyond the fences
		# --- classify (mirrors tests/clutter_probe.gd) ---
		var cat4 := ""
		var in_mailbox_group := false
		var anc4: Node = mi4
		while anc4 != null:
			if anc4.name == "Mailbox":
				in_mailbox_group = true
			anc4 = anc4.get_parent()
		var cm4 := mi4.material_override as StandardMaterial3D
		var ccol: Color = cm4.albedo_color if cm4 != null else Color(-1, -1, -1)
		if in_mailbox_group:
			cat4 = "mailbox"
		elif mi4.mesh is BoxMesh:
			var s4: Vector3 = (mi4.mesh as BoxMesh).size
			if absf(s4.x - 5.4) < 0.06 and absf(s4.y - 1.06) < 0.06 and absf(s4.z - 0.14) < 0.06:
				cat4 = "sign_board"
			elif (absf(s4.x - 0.7) < 0.06 and absf(s4.y - 0.45) < 0.06 and absf(s4.z - 0.5) < 0.06) or (absf(s4.x - 0.6) < 0.06 and absf(s4.y - 0.42) < 0.06 and absf(s4.z - 0.22) < 0.06) or (absf(s4.x - 0.42) < 0.06 and absf(s4.y - 0.3) < 0.06 and absf(s4.z - 0.3) < 0.06):
				cat4 = "mailbox"
			elif (absf(s4.y - 0.12) < 0.03 and absf(s4.z - 0.55) < 0.06 and absf(s4.x - 2.2) < 0.06) or (absf(s4.y - 0.1) < 0.03 and absf(s4.z - 0.5) < 0.06 and (absf(s4.x - 1.7) < 0.06 or absf(s4.x - 3.4) < 0.06)):
				cat4 = "bench"
			elif absf(s4.x - 3.2) < 0.06 and absf(s4.y - 0.7) < 0.06 and absf(s4.z - 0.5) < 0.06:
				cat4 = "hedge"
			elif absf(ccol.r - 0.4) < 0.03 and absf(ccol.g - 0.3) < 0.03 and absf(ccol.b - 0.2) < 0.03 and s4.y <= 0.3 and s4.x >= 3.0:
				cat4 = "flowerbed"
			elif s4.y >= 0.85 and s4.y <= 1.15 and minf(s4.x, s4.z) <= 0.2 and maxf(s4.x, s4.z) <= 0.35:
				cat4 = "fence"
			elif s4.y <= 0.13 and minf(s4.x, s4.z) <= 0.13 and maxf(s4.x, s4.z) >= 1.9:
				cat4 = "fence"
		elif mi4.mesh is CylinderMesh:
			var cmsh := mi4.mesh as CylinderMesh
			if absf(cmsh.height - 4.4) < 0.06 and cmsh.bottom_radius <= 0.1:
				cat4 = "lamp"
			elif absf(cmsh.height - 3.8) < 0.06 and cmsh.bottom_radius <= 0.1:
				cat4 = "sign"
			elif absf(cmsh.height - 0.9) < 0.06 and absf(cmsh.top_radius - 0.26) < 0.06:
				cat4 = "bin"
			elif cmsh.height >= 0.85 and cmsh.height <= 1.05 and cmsh.bottom_radius <= 0.055:
				cat4 = "mailbox"
			elif absf(ccol.r - 0.4) < 0.03 and absf(ccol.g - 0.3) < 0.03 and absf(ccol.b - 0.2) < 0.03 and cmsh.height <= 0.32 and cmsh.bottom_radius >= 1.5:
				cat4 = "flowerbed"
		elif mi4.mesh is SphereMesh:
			var d4: Vector3 = mi4.scale
			if d4.x <= 0.15 and mp4.y >= 3.0:
				cat4 = "sign_board"
			elif absf(d4.x - 0.5) < 0.06 and absf(ccol.r - 1.0) < 0.03 and absf(ccol.g - 0.9) < 0.03 and absf(ccol.b - 0.6) < 0.03:
				cat4 = "lamp"
			elif d4.x <= 0.24 and mp4.y <= 0.32:
				cat4 = "flower"
		# --- test against the asphalt ---
		var ca4: AABB = mi4.global_transform * mi4.get_aabb()
		var crect4 := Rect2(ca4.position.x, ca4.position.z, ca4.size.x, ca4.size.z)
		var on4 := false
		for ar4 in asphalt_rects:
			if crect4.intersects(ar4):
				on4 = true
		if cat4 != "":
			clutter_totals[cat4] = int(clutter_totals.get(cat4, 0)) + 1
			if on4:
				clutter_onroad[cat4] = int(clutter_onroad.get(cat4, 0)) + 1
			if cat4 == "mailbox":
				var in_house := false
				for g4 in house_groups.keys():
					var p4: Node = mi4
					while p4 != null:
						if p4 == g4:
							in_house = true
							break
						p4 = p4.get_parent()
					if in_house:
						break
				if not in_house:
					stray_mailbox_meshes += 1
		elif on4:
			# catch-all: untextured, thicker than ground paint
			if cm4 != null and cm4.albedo_texture == null and ca4.size.y > 0.06:
				clutter_other_onroad += 1
	check("clutter: benches present and ZERO on any roadway", int(clutter_totals.get("bench", 0)) > 0 and int(clutter_onroad.get("bench", 0)) == 0, "on=" + str(clutter_onroad.get("bench", 0)))
	check("clutter: ZERO fence posts/rails on any roadway (runs stop at road edges)", int(clutter_onroad.get("fence", 0)) == 0, str(clutter_onroad.get("fence", 0)))
	check("clutter: ZERO mailboxes on any roadway", int(clutter_onroad.get("mailbox", 0)) == 0, str(clutter_onroad.get("mailbox", 0)))
	check("clutter: ZERO hedges/lamps/bins/flowerbeds/flowers on any roadway", int(clutter_onroad.get("hedge", 0)) + int(clutter_onroad.get("lamp", 0)) + int(clutter_onroad.get("bin", 0)) + int(clutter_onroad.get("flowerbed", 0)) + int(clutter_onroad.get("flower", 0)) == 0, str(clutter_onroad))
	check("clutter: sign POLES zero on any roadway (boards may overhang)", int(clutter_onroad.get("sign", 0)) == 0, str(clutter_onroad.get("sign", 0)))
	check("clutter: no other prop mesh on any roadway (catch-all)", clutter_other_onroad == 0, str(clutter_other_onroad))
	check("clutter: no stray mailboxes outside houses", stray_mailbox_meshes == 0, str(stray_mailbox_meshes))
	# mailboxes per house: exactly one each
	var houses_wrong_mb := 0
	var total_mb_units := 0
	for g5 in house_groups.keys():
		var units5 := 0
		var gstack5: Array = [g5]
		while not gstack5.is_empty():
			var gn5: Node = gstack5.pop_back()
			for gch5 in gn5.get_children():
				gstack5.append(gch5)
			if gn5.name == "Mailbox" and gn5.get_parent() != null:
				var under_mb := false
				var pp5: Node = gn5.get_parent()
				while pp5 != null and pp5 != g5:
					if pp5.name == "Mailbox":
						under_mb = true
					pp5 = pp5.get_parent()
				if not under_mb:
					units5 += 1
		total_mb_units += units5
		if units5 != 1:
			houses_wrong_mb += 1
	check("clutter: EVERY house has exactly ONE mailbox (131 houses)", houses_wrong_mb == 0 and total_mb_units == house_groups.size(), "wrong=" + str(houses_wrong_mb) + " units=" + str(total_mb_units) + " houses=" + str(house_groups.size()))

	# ---------- v1.3 CAMERA FRAMING (Michael's v1.0.5 playtest) ----------
	# Measured BEFORE (tests/CamProbe.tscn, viewport fractions, y 0 =
	# top edge): at the old camera (orbit 1.45, anchor 0.38, FOV 62,
	# pitch 18) a person 1.2m from the cat had her face at y=-0.13
	# and the notice bar at y=-0.85 — off-screen; the bar stayed
	# off-screen at 5m, and the 3.75m sign boards were off-screen
	# even at max look-up from 3m. These checks project the REAL
	# points with the REAL camera and require them INSIDE the
	# viewport, plus the cat still a healthy share of the frame
	# (Michael, same call: not tiny either).
	park_npcs_far()
	var cam3d: Camera3D = main.get("cam")
	var shipped_pitch: float = float(main.get("look_pitch_deg"))
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var in_frame = func(p: Vector3) -> bool:
		if cam3d.is_position_behind(p):
			return false
		var s: Vector2 = cam3d.unproject_position(p)
		return s.x >= 0.0 and s.x <= vp_size.x and s.y >= 0.0 and s.y <= vp_size.y
	var gwoman: Node = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman" and str(n.get("role")) == "grabber":
			gwoman = n
			break
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	main.set("look_yaw", -PI * 0.5)
	main.set("look_pitch_deg", shipped_pitch)
	(gwoman as Node3D).global_position = Vector3(62, 0.2, 84) # 2.0m gap
	(gwoman as Node3D).rotation = Vector3(0, -PI * 0.5, 0)
	await wait_sec(0.4) # her physics shows her model at this range
	gwoman.set_physics_process(false) # hold her exactly here
	(gwoman as Node3D).global_position = Vector3(62, 0.2, 84)
	await wait_sec(1.2) # camera settle
	var notice_pos: Vector3 = (gwoman.get("notice_label") as Node3D).global_position
	check("camera framing: notice bar IN FRAME at 2m (was off-screen at 5m)", in_frame.call(notice_pos), str(cam3d.unproject_position(notice_pos) / vp_size))
	(gwoman as Node3D).global_position = Vector3(61.2, 0.2, 84) # 1.2m gap
	await wait_sec(1.2)
	notice_pos = (gwoman.get("notice_label") as Node3D).global_position
	var gface: Vector3 = (gwoman as Node3D).global_position + Vector3(0, 1.52, 0)
	check("camera framing: notice bar IN FRAME face-to-face at 1.2m", in_frame.call(notice_pos), str(cam3d.unproject_position(notice_pos) / vp_size))
	check("camera framing: person's FACE in frame face-to-face at 1.2m", in_frame.call(gface), str(cam3d.unproject_position(gface) / vp_size))
	# the cat himself: still a healthy share of the ordinary view
	var cat_a := AABB()
	var cat_first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		cat_a = ga if cat_first else cat_a.merge(ga)
		cat_first = false
	var cat_base: Vector3 = (player as Node3D).global_position
	var cs_bot: Vector2 = cam3d.unproject_position(Vector3(cat_base.x, cat_a.position.y, cat_base.z))
	var cs_top: Vector2 = cam3d.unproject_position(Vector3(cat_base.x, cat_a.position.y + cat_a.size.y, cat_base.z))
	var cat_share: float = absf(cs_bot.y - cs_top.y) / vp_size.y
	check("camera framing: cat still >= 0.18 of frame height (not tiny)", cat_share >= 0.18, str(cat_share))
	# chase: the pursuer's overhead bar fits too
	(gwoman as Node3D).global_position = Vector3(55, 0.2, 84)
	(gwoman as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	gwoman.set("mode", "chase")
	await wait_sec(1.2)
	notice_pos = (gwoman.get("notice_label") as Node3D).global_position
	check("camera framing: chase cam keeps the pursuer's bar in frame", bool(main.get("chase_cam_active")) and in_frame.call(notice_pos), str(cam3d.unproject_position(notice_pos) / vp_size))
	gwoman.set("mode", "wander")
	gwoman.set_physics_process(true)
	# sign: whole board in frame at max look-up, cat 3m away
	(gwoman as Node3D).global_position = Vector3(-110, 0.2, 80)
	(player as Node3D).global_position = Vector3(58, 0.2, 23)
	(player as Node3D).rotation = Vector3(0, PI, 0)
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", shipped_pitch)
	await wait_sec(0.5)
	main.call("apply_look_drag", Vector2(0, -100000)) # real input path -> max look-up
	await wait_sec(1.2)
	check("camera framing: whole street-sign board in frame at max look-up (3m)", in_frame.call(Vector3(58, 3.75, 20)) and in_frame.call(Vector3(58, 4.28, 20)) and in_frame.call(Vector3(58, 3.22, 20)), "centre=" + str(cam3d.unproject_position(Vector3(58, 3.75, 20)) / vp_size))
	# cleanup: restore the shipped view + park everyone
	main.set("look_pitch_deg", shipped_pitch)
	main.set("look_yaw", 0.0)
	park_npcs_far()

	# ---------- paw / meow instant attention (items 13+15, v0.8 item 5) ----------
	park_npcs_far()
	(player as Node3D).global_position = Vector3(100, 0.2, 80)
	await wait_sec(0.3)
	main.call("_paw_action")
	check("paw: swipe animation triggers", bool(player.call("is_paw_swiping")))
	var friendly: Node = npc_by_role("friendly")
	(friendly as Node3D).global_position = (player as Node3D).global_position + Vector3(2.0, 0, 0)
	friendly.set("notice", 0.0)
	friendly.set("joy_shown", false)
	friendly.set("interact_cooldown", 0.0)
	var score_before_paw: int = int(main.get("score"))
	main.call("_paw_action")
	check("paw near friendly: NO notice for friendly (bar is grabber-only now)", float(friendly.get("notice")) == 0.0, str(friendly.get("notice")))
	check("paw near friendly: joy reaction", bool(friendly.get("joy_shown")) and str(friendly.get("expression")) == "joy", str(friendly.get("expression")))
	# v1.4 NPC LOOK: the expression system — mouths swap, and a full
	# reset leaves no stuck face behind.
	var fmouths: Dictionary = friendly.get("mouths")
	check("v1.4 faces: five mouth groups built (smile/grin/frown/flat/small)", fmouths.size() >= 5, str(fmouths.size()))
	check("v1.4 faces: joy shows the open grin", (fmouths["grin"] as Node3D).visible and not (fmouths["flat"] as Node3D).visible)
	friendly.call("set_expression", "sad")
	check("v1.4 faces: sad swaps grin for the frown", (fmouths["frown"] as Node3D).visible and not (fmouths["grin"] as Node3D).visible)
	friendly.call("set_expression", "neutral")
	check("v1.4 faces: neutral restores flat mouth + base brows/eyes (no stuck face)", (fmouths["flat"] as Node3D).visible and absf((friendly.get("brow_l") as Node3D).rotation.z) < 0.01 and absf((friendly.get("eye_l_mi") as Node3D).scale.y - (friendly.get("eye_base_scale") as Vector3).y) < 0.001)
	friendly.call("set_expression", "joy")
	# v0.9 REAL PETTING SEQUENCE: force the pet kind (the treat kind
	# is forced in the meow section below) and watch the whole act.
	friendly.set("interact_kind", "pet")
	check("pet sequence: starts on paw (approach)", str(friendly.get("interact_state")) == "approach", str(friendly.get("interact_state")))
	await wait_sec(0.4)
	check("pet sequence: NO points on the trigger itself", int(main.get("score")) == score_before_paw, str(main.get("score")))
	var seq_states: Array = []
	var min_hand: float = 999.0
	var max_bend: float = 0.0
	var kneel_max_pitch: float = 0.0 # v1.4: sampled through the pet
	var kneel_max_shin: float = 0.0
	var kneel_min_y: float = 999.0
	var saw_cat_react: bool = false
	var saw_hearts: bool = false
	var gain_at: float = -1.0
	var elapsed: float = 0.4
	while elapsed < 8.0:
		await wait_sec(0.2)
		elapsed += 0.2
		var st: String = str(friendly.get("interact_state"))
		if st != "" and not seq_states.has(st):
			seq_states.append(st)
		if st == "pet":
			min_hand = minf(min_hand, float(friendly.get("last_hand_dist")))
			if bool(player.call("is_being_petted")):
				saw_cat_react = true
			if (friendly.get("hearts") as Array).size() > 0:
				saw_hearts = true
		max_bend = maxf(max_bend, float(friendly.get("bend_a")))
		var fmodel: Node3D = friendly.get("model")
		kneel_max_pitch = maxf(kneel_max_pitch, absf(fmodel.rotation.x))
		kneel_min_y = minf(kneel_min_y, fmodel.position.y)
		kneel_max_shin = maxf(kneel_max_shin, absf((friendly.get("shin_r") as Node3D).rotation.x))
		if int(main.get("score")) != score_before_paw and gain_at < 0.0:
			gain_at = elapsed
		if st == "" and gain_at > 0.0:
			break
	check("pet sequence: passed through bend + pet phases", seq_states.has("bend") and seq_states.has("pet"), str(seq_states))
	check("pet sequence: kneels right down (bend_a > 0.7)", max_bend > 0.7, str(max_bend))
	check("pet sequence: hand CONTACTS the cat (min hand dist < 0.34)", min_hand < 0.34, str(min_hand))
	check("pet sequence: contact sustained (>= 8 frames)", int(friendly.get("pet_contact_frames")) >= 8, str(friendly.get("pet_contact_frames")))
	check("pet sequence: cat reacts (lean/tail/purr pose)", saw_cat_react)
	check("pet sequence: hearts float up", saw_hearts)
	var paw_gain: int = int(main.get("score")) - score_before_paw
	check("pet sequence: +1 lands DURING petting, not on trigger", paw_gain == 1 and gain_at > 1.2, "gain=%d at=%.1f" % [paw_gain, gain_at])
	check("pet sequence: completes and stands back up", str(friendly.get("interact_state")) == "", str(friendly.get("interact_state")))
	# v1.4 KNEEL (Michael: "bend at the knee, not fold in half"):
	# through the whole pet, the torso pitch must stay modest while
	# the body still gets right down — via hip drop + shin fold.
	check("v1.4 kneel: torso pitch stays modest (< 0.2 rad, no fold in half)", kneel_max_pitch < 0.2, str(kneel_max_pitch))
	check("v1.4 kneel: descent comes from the hips/knees (model drop > 0.3 m)", -kneel_min_y > 0.3, str(kneel_min_y))
	check("v1.4 kneel: the shin folds at the knee (> 0.6 rad)", kneel_max_shin > 0.6, str(kneel_max_shin))
	var grabber: Node = npc_by_role("grabber")
	(friendly as Node3D).global_position = (player as Node3D).global_position + Vector3(30, 0, 0) # move the friendly out of paw range first
	(grabber as Node3D).global_position = (player as Node3D).global_position + Vector3(-2.0, 0, 0)
	grabber.set("notice", 0.0)
	grabber.set("mode", "wander")
	main.call("_paw_action")
	check("paw near grabber: instant RUN tell", str(grabber.get("mode")) == "tell", str(grabber.get("mode")))
	check("v1.4: the RUN tell wears the EXCITED face", str(grabber.get("expression")) == "excited", str(grabber.get("expression")))
	grabber.call("_end_chase")
	grabber.set("expr_timer", 0.05)
	await wait_sec(0.4)
	check("v1.4: lost-chase sad face resets to neutral on its timer", str(grabber.get("expression")) == "neutral", str(grabber.get("expression")))
	# meow: friendly at 5 units (outside paw range, inside earshot).
	# (Grabber parked out of earshot first — in v0.9 a meow this
	# close would provoke his tell and he'd capture the cat during
	# the long treat sequence below.)
	(grabber as Node3D).global_position = (player as Node3D).global_position + Vector3(-40, 0, 0)
	grabber.set("mode", "wander")
	grabber.set("notice", 0.0)
	var friendly2: Node = null
	for n in main.get("npcs"):
		if str(n.get("role")) == "friendly" and n != friendly:
			friendly2 = n
			break
	(friendly2 as Node3D).global_position = (player as Node3D).global_position + Vector3(5.0, 0, 0)
	friendly2.set("notice", 0.0)
	friendly2.set("joy_shown", false)
	friendly2.set("interact_cooldown", 0.0)
	main.set("meow_cooldown", 0.0)
	main.call("_on_meow")
	check("meow near friendly: still NO notice (grabber-only bar)", float(friendly2.get("notice")) == 0.0, str(friendly2.get("notice")))
	check("meow near friendly: joy reaction", bool(friendly2.get("joy_shown")))
	check("meow near friendly: interaction sequence starts", str(friendly2.get("interact_state")) != "", str(friendly2.get("interact_state")))
	# v0.9 TREAT SEQUENCE: force the treat kind and watch it play —
	# she walks over, kneels, holds out a VISIBLE treat, the cat
	# dips his head and eats it, THEN +5 lands and the treat is gone.
	friendly2.set("interact_kind", "treat")
	var treat_score0: int = int(main.get("score"))
	var saw_treat_vis: bool = false
	var treat_elapsed: float = 0.0
	var head_max_off: float = 0.0 # v0.9 regression: the eating dip must never slide the head off the body
	var head_node: Node3D = player.get("head_node")
	var head_base: Vector3 = player.get("head_base_pos")
	while treat_elapsed < 9.0:
		await wait_sec(0.2)
		treat_elapsed += 0.2
		if bool((friendly2.get("treat_mi") as MeshInstance3D).visible):
			saw_treat_vis = true
		head_max_off = maxf(head_max_off, head_node.position.distance_to(head_base))
		if int(main.get("score")) != treat_score0:
			break
	check("treat sequence: the cat's head stays on his body while eating", head_max_off < 0.3, str(head_max_off))
	check("treat sequence: a visible treat is offered from the hand", saw_treat_vis)
	check("treat sequence: +5 after the cat eats from the hand", int(main.get("score")) - treat_score0 == 5, str(int(main.get("score")) - treat_score0))
	await wait_sec(1.2)
	check("treat sequence: the treat is eaten (gone afterwards)", not bool((friendly2.get("treat_mi") as MeshInstance3D).visible))
	(grabber as Node3D).global_position = (player as Node3D).global_position + Vector3(-5.0, 0, 0)
	grabber.set("notice", 0.0)
	grabber.set("mode", "wander")
	main.set("meow_cooldown", 0.0)
	main.call("_on_meow")
	check("meow near grabber: instant RUN tell", str(grabber.get("mode")) == "tell", str(grabber.get("mode")))
	grabber.call("_end_chase")
	# v0.8 (item 5): proximity alone does NOTHING for a friendly NPC —
	# stand right next to one for 5s: no bar, no joy, no points.
	# (Everyone else parked far first so the wandering grabber can't
	# wander in and capture the stationary cat mid-test.)
	park_npcs_far()
	(friendly2 as Node3D).global_position = (player as Node3D).global_position + Vector3(2.5, 0, 0)
	friendly2.set("notice", 0.0)
	friendly2.set("joy_shown", false)
	friendly2.call("set_expression", "neutral")
	# v0.9 hygiene: kill any in-flight interaction from the meow
	# sections — proximity ALONE must be what this section measures.
	friendly2.set("interact_state", "")
	friendly2.set("award_pending", false)
	friendly2.set("pending_award", "")
	(friendly2.get("treat_mi") as MeshInstance3D).visible = false
	await wait_sec(1.0)
	var score_before_prox: int = int(main.get("score"))
	await wait_sec(5.0)
	check("friendly proximity 5s: notice stays 0", float(friendly2.get("notice")) == 0.0, str(friendly2.get("notice")))
	check("friendly proximity 5s: no 👀 bar shown", str((friendly2.get("notice_label") as Label3D).text) == "", str((friendly2.get("notice_label") as Label3D).text))
	check("friendly proximity 5s: no joy, no interaction, no points", not bool(friendly2.get("joy_shown")) and int(main.get("score")) == score_before_prox and str(friendly2.get("interact_state")) == "", "score=%d joy=%s state=%s" % [int(main.get("score")), friendly2.get("joy_shown"), friendly2.get("interact_state")])
	# ...while the GRABBER's proximity bar still builds as in v0.7
	park_npcs_far()
	(player as Node3D).global_position = Vector3(0, 0.2, 40)
	(grabber as Node3D).global_position = Vector3(4.0, 0.2, 40)
	grabber.set("notice", 0.0)
	grabber.set("notice_cooldown", 0.0)
	grabber.set("mode", "wander")
	await wait_sec(1.2)
	check("grabber proximity: notice bar builds", float(grabber.get("notice")) > 0.03, str(grabber.get("notice")))
	check("grabber proximity: 👀 bar visible", "👀" in str((grabber.get("notice_label") as Label3D).text), str((grabber.get("notice_label") as Label3D).text))
	grabber.set("notice", 0.0)
	(grabber as Node3D).global_position = Vector3(-100, 0.2, 80)

	# ---------- sprint: RUN hold only + winded drop (v1.0.14) ----------
	# Michael's direction: the joystick NEVER sprints on its own now
	# (a full push "rocketed off") — sprint is the RUN button's
	# press-and-HOLD (momentary: v1.0.13's press-to-toggle was
	# reversed by Michael after he played it). The press/release
	# below go through the button's real button_down/button_up
	# signals. Stamina/winded rules unchanged.
	park_npcs_far()
	(player as Node3D).global_position = Vector3(30, 0.2, 40) # v0.8: clear lane (x=0 now has 28 Oak Ave's lot in the row ahead)
	player.set("stamina", 100.0)
	player.set("winded", false)
	await wait_sec(0.2)
	set_joy(Vector2(0, -40)) # partial push (~0.47)
	await wait_sec(0.5)
	check("partial push: walking, NOT sprinting", not bool(player.get("is_sprinting")))
	check("partial push: stamina untouched", float(player.get("stamina")) >= 99.9, str(player.get("stamina")))
	set_joy(Vector2(0, -100)) # full push
	await wait_sec(0.5)
	check("full push alone: still walking, NOT sprinting (RUN is a button now)", not bool(player.get("is_sprinting")))
	check("full push alone: stamina untouched", float(player.get("stamina")) >= 99.9, str(player.get("stamina")))
	check("RUN button exists beside MEOW", main.get("run_btn") != null)
	check("RUN starts off: button shows plain RUN", str((main.get("run_btn") as Button).text) == "RUN", str((main.get("run_btn") as Button).text))
	(main.get("run_btn") as Button).button_down.emit() # press & HOLD
	check("RUN held: touch_sprint set", bool(player.get("touch_sprint")))
	check("RUN held: main's held state set", bool(main.get("run_on")))
	check("RUN held: button text stays plain RUN", str((main.get("run_btn") as Button).text) == "RUN", str((main.get("run_btn") as Button).text))
	var run_on_style := (main.get("run_btn") as Button).get_theme_stylebox("normal") as StyleBoxFlat
	check("RUN held: button fill turns green", run_on_style != null and run_on_style.bg_color == Color(0.22, 0.72, 0.28, 0.95), str(run_on_style.bg_color) if run_on_style != null else "no normal style")
	await wait_sec(0.5)
	check("RUN held + moving: sprinting", bool(player.get("is_sprinting")))
	check("RUN held: stamina draining", float(player.get("stamina")) < 99.0, str(player.get("stamina")))
	var sprint_speed: float = Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()
	check("sprint speed is near 11.5 (>> walk 5.6)", sprint_speed > 9.5, str(sprint_speed))
	player.set("stamina", 0.4) # nearly empty: winded drop must follow
	await wait_sec(0.4)
	check("empty pool: winded (sprint locked out)", bool(player.get("winded")))
	var winded_speed: float = Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()
	check("winded: speed visibly back at walk (<= 5.7)", winded_speed <= 5.7 and not bool(player.get("is_sprinting")), str(winded_speed))
	check("winded: RUN hold itself stays on (still held)", bool(player.get("touch_sprint")))
	player.set("stamina", 60.0)
	await wait_sec(0.3)
	check("stamina recovered: sprint resumes (still holding)", bool(player.get("is_sprinting")))
	(main.get("run_btn") as Button).button_up.emit() # RELEASE
	await wait_sec(0.3)
	check("RUN released: back to walking", not bool(player.get("is_sprinting")) and not bool(player.get("touch_sprint")))
	check("RUN released: main's held state cleared", not bool(main.get("run_on")))
	check("RUN off: button shows plain RUN again", str((main.get("run_btn") as Button).text) == "RUN", str((main.get("run_btn") as Button).text))
	var run_off_style := (main.get("run_btn") as Button).get_theme_stylebox("normal") as StyleBoxFlat
	check("RUN off: button fill returns to grey", run_off_style != null and run_off_style.bg_color == Color(0.35, 0.38, 0.42, 0.85), str(run_off_style.bg_color) if run_off_style != null else "no normal style")
	clear_joy()
	await wait_sec(0.3)

	# ---------- v1.0.18: RUN hold through the REAL touch path ----------
	# Michael's S26 report on v1.0.16: "the run button isn't working"
	# — with the joystick thumb down, the RUN thumb never engaged, so
	# every chase ended in an instant capture. Root cause: the hold
	# was wired ONLY to the Button's button_down/button_up signals,
	# which ride the touch->mouse emulation channel — a
	# single-pointer channel. A raw InputEventScreenTouch landing
	# square on a Button fires nothing (verified headless); only an
	# (emulated) mouse press fires it, and emulation can only be one
	# finger at a time. The section above cannot see this: it emits
	# the button's signals directly. THIS section drives the real
	# viewport input pipeline with two simultaneous touch indices —
	# joystick finger first, RUN as the second finger — exactly the
	# failing play pattern. (Input.parse_input_event events are
	# dropped by the headless display server, so the events go
	# through Viewport.push_input, which runs the same _input ->
	# GUI -> _unhandled_input pipeline the OS events take.)
	park_npcs_far()
	(player as Node3D).global_position = Vector3(30, 0.2, 40)
	player.set("stamina", 100.0)
	player.set("winded", false)
	await wait_sec(0.2)
	var vp18: Vector2 = get_viewport().get_visible_rect().size
	var joy_pos18 := Vector2(vp18.x * 0.15, vp18.y * 0.55)
	var run_pos18: Vector2 = (main.get("run_btn") as Button).get_global_rect().get_center()
	var tev := InputEventScreenTouch.new()
	tev.index = 0
	tev.pressed = true
	tev.position = joy_pos18
	get_viewport().push_input(tev, true)
	await wait_sec(0.15)
	var dev := InputEventScreenDrag.new()
	dev.index = 0
	dev.position = joy_pos18 + Vector2(0, -100)
	dev.relative = Vector2(0, -100)
	get_viewport().push_input(dev, true)
	await wait_sec(0.4)
	check("v1.0.18 touch path: joystick finger claims the stick (real events)", int(main.get("joy_id")) == 0, str(main.get("joy_id")))
	check("v1.0.18 touch path: full push alone walks at 5.6 (joystick never sprints — v1.0.14)", not bool(player.get("is_sprinting")) and Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length() > 5.0, str(Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()))
	var tev2 := InputEventScreenTouch.new()
	tev2.index = 1
	tev2.pressed = true
	tev2.position = run_pos18
	get_viewport().push_input(tev2, true)
	await wait_sec(0.15)
	check("v1.0.18 touch path: second finger on RUN engages the hold (run_on)", bool(main.get("run_on")))
	check("v1.0.18 touch path: RUN hold reaches the cat (touch_sprint)", bool(player.get("touch_sprint")))
	await wait_sec(0.5)
	check("v1.0.18 touch path: joystick + RUN held = sprinting", bool(player.get("is_sprinting")))
	var spd18: float = Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()
	check("v1.0.18 touch path: sprint speed through real events (> 9.5)", spd18 > 9.5, str(spd18))
	check("v1.0.18 touch path: stamina draining while sprinting", float(player.get("stamina")) < 99.0, str(player.get("stamina")))
	var tev3 := InputEventScreenTouch.new()
	tev3.index = 1
	tev3.pressed = false
	tev3.position = run_pos18
	get_viewport().push_input(tev3, true)
	await wait_sec(0.3)
	check("v1.0.18 touch path: RUN finger lifts -> hold clears, back to walk", not bool(main.get("run_on")) and not bool(player.get("is_sprinting")) and Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length() <= 5.7, str(Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()))
	check("v1.0.18 touch path: joystick still owned by finger 0 after RUN release", int(main.get("joy_id")) == 0, str(main.get("joy_id")))
	var tev4 := InputEventScreenTouch.new()
	tev4.index = 0
	tev4.pressed = false
	tev4.position = joy_pos18 + Vector2(0, -100)
	get_viewport().push_input(tev4, true)
	await wait_sec(0.2)
	# Single-finger parity: RUN as the ONLY finger must also engage
	# through the touch channel (it never could through the Button).
	player.set("stamina", 100.0)
	var tev5 := InputEventScreenTouch.new()
	tev5.index = 0
	tev5.pressed = true
	tev5.position = run_pos18
	get_viewport().push_input(tev5, true)
	await wait_sec(0.15)
	check("v1.0.18 touch path: RUN as the only finger also engages", bool(main.get("run_on")) and bool(player.get("touch_sprint")))
	var tev6 := InputEventScreenTouch.new()
	tev6.index = 0
	tev6.pressed = false
	tev6.position = run_pos18
	get_viewport().push_input(tev6, true)
	await wait_sec(0.2)
	check("v1.0.18 touch path: solo RUN release clears the hold", not bool(main.get("run_on")) and not bool(player.get("touch_sprint")))

	# ---------- v1.0.21: HOP while sprinting, through the REAL touch path ----------
	# Michael's v1.0.20 report: "you can't jump while running — you
	# have to stop, then jump, then press forward." Same disease as
	# v1.0.18's RUN: HOP was wired only to its Button's pressed
	# signal (the single-pointer emulated-mouse channel), so with
	# the joystick thumb down the press never arrived. The cat's
	# physics was never the block (its velocity is driven from the
	# input every physics frame, airborne included). Drive it
	# exactly like play: joystick finger down at full push, RUN held
	# with a second finger, then a THIRD finger taps A (HOP) — the
	# cat must leave the ground with its sprint speed intact and
	# land still running.
	park_npcs_far()
	(player as Node3D).global_position = Vector3(30, 0.2, 40)
	player.set("stamina", 100.0)
	player.set("winded", false)
	await wait_sec(0.2)
	var vp21: Vector2 = get_viewport().get_visible_rect().size
	var joy_pos21 := Vector2(vp21.x * 0.15, vp21.y * 0.55)
	var run_pos21: Vector2 = (main.get("run_btn") as Button).get_global_rect().get_center()
	var hop_pos21: Vector2 = (main.get("hop_btn") as Button).get_global_rect().get_center()
	var hj := InputEventScreenTouch.new()
	hj.index = 0
	hj.pressed = true
	hj.position = joy_pos21
	get_viewport().push_input(hj, true)
	await wait_sec(0.15)
	var hd := InputEventScreenDrag.new()
	hd.index = 0
	hd.position = joy_pos21 + Vector2(0, -100)
	hd.relative = Vector2(0, -100)
	get_viewport().push_input(hd, true)
	var hr := InputEventScreenTouch.new()
	hr.index = 1
	hr.pressed = true
	hr.position = run_pos21
	get_viewport().push_input(hr, true)
	await wait_sec(0.5)
	check("v1.0.21 hop: sprinting before the hop (setup)", bool(player.get("is_sprinting")) and Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length() > 9.5, str(Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()))
	var hh := InputEventScreenTouch.new()
	hh.index = 2
	hh.pressed = true
	hh.position = hop_pos21
	get_viewport().push_input(hh, true)
	var air_seen: bool = false
	var air_speed_ok: bool = false
	var landed_running: bool = false
	var hop_guard: float = 0.0
	while hop_guard < 2.0:
		await wait_sec(0.05)
		hop_guard += 0.05
		var vy21: float = (player as CharacterBody3D).velocity.y
		var hs21: float = Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()
		if not (player as CharacterBody3D).is_on_floor() and vy21 > 1.0:
			air_seen = true
			if hs21 > 9.5:
				air_speed_ok = true
		if air_seen and (player as CharacterBody3D).is_on_floor() and hs21 > 9.5:
			landed_running = true
			break
	check("v1.0.21 hop: HOP with the joystick + RUN held launches the cat (airborne, rising)", air_seen)
	check("v1.0.21 hop: horizontal sprint speed is preserved in the air", air_speed_ok)
	check("v1.0.21 hop: lands back into the run (nothing was released)", landed_running)
	var hrel := InputEventScreenTouch.new()
	hrel.index = 2
	hrel.pressed = false
	hrel.position = hop_pos21
	get_viewport().push_input(hrel, true)
	var rrel := InputEventScreenTouch.new()
	rrel.index = 1
	rrel.pressed = false
	rrel.position = run_pos21
	get_viewport().push_input(rrel, true)
	var jrel := InputEventScreenTouch.new()
	jrel.index = 0
	jrel.pressed = false
	jrel.position = joy_pos21 + Vector2(0, -100)
	get_viewport().push_input(jrel, true)
	await wait_sec(0.2)

	# ---------- collar (v1.0.8: the in-play collar check is REMOVED) ----------
	# Michael's direction: under the new story the collar falls off
	# before the pound, so the COLLAR button, the C key and the
	# camera zoom are gone entirely — nothing to re-check mid-run.
	# What stays: the address printed ON the 3D tag (kept for the
	# homecoming ending). These checks assert the removal and keep
	# guarding the tag print.
	check("no 2D collar panel any more", main.get("collar_panel") == null)
	check("collar button removed (no collar_btn)", main.get("collar_btn") == null)
	check("collar zoom action removed (no _toggle_collar)", not main.has_method("_toggle_collar"))
	var collar_props: Array = []
	for p in main.get_property_list():
		collar_props.append(str(p["name"]))
	check("collar zoom state removed (no collar_open)", not collar_props.has("collar_open"))
	(player as Node3D).global_position = Vector3(4, 0.2, 6) # open ground: the play camera settles at full orbit distance
	player.set("velocity", Vector3.ZERO)
	await wait_sec(1.6)
	var tag_pos: Vector3 = player.call("get_tag_global_pos")
	var cam_dist: float = (main.get("cam") as Camera3D).global_position.distance_to(tag_pos)
	check("camera stays at play distance from the tag (> 1.9 units)", cam_dist > 1.9, str(cam_dist))
	# v1.5 (Michael, 2026-11-17): a print ON the tag — no floating
	# billboard caption. Since 2026-11-18 the print is his NAME
	# ("Zander", Michael named him), not the home address.
	check("floating collar caption is gone", main.get("collar_caption") == null)
	var tag_label: Label3D = player.call("get_tag_label")
	check("tag carries a printed name label", tag_label != null)
	if tag_label != null:
		var printed: String = tag_label.text.replace("\n", " ").replace(", ", " ")
		check("tag print is the cat's name (Zander), not the address", printed == "Zander", "'" + printed + "'")
		var tag_node: Node = player.get("collar_tag")
		check("tag label is parented to the tag (moves with it)", tag_node != null and tag_node.is_ancestor_of(tag_label))
		check("tag label is fixed to the face (no billboard)", tag_label.billboard == BaseMaterial3D.BILLBOARD_DISABLED)
	check("no collar zoom: FOV stays at the town FOV (70)", absf((main.get("cam") as Camera3D).fov - 70.0) < 1.0, str((main.get("cam") as Camera3D).fov))
	check("collar close action removed (no _close_collar)", not main.has_method("_close_collar"))
	await wait_sec(0.3)
	check("collar zoom timers removed (no collar_timer / collar_zoom_t)", not collar_props.has("collar_timer") and not collar_props.has("collar_zoom_t"))
	await wait_sec(0.8)
	check("cat is not frozen by any collar view", not bool(player.get("frozen")))

	# ---------- paw swipe ALWAYS resets (v0.8 item 4) ----------
	# For each state: settle, record the no-swipe base rotation of the
	# front-right leg, swipe, wait until 0.2s after the swipe ends,
	# and require the leg to be back at that exact base (< 0.01 rad).
	park_npcs_far()
	(player as Node3D).global_position = Vector3(100, 0.2, 80)
	player.set("frozen", false)
	player.set("idle_next_in", 999.0) # no random idle actions during sampling
	var leg1: Node3D = (player.get("leg_pivots") as Array)[1]
	# -- still --
	player.set("idle_action", "")
	var base_still: Vector3 = await wait_leg_stable(leg1, 1.0)
	player.call("do_paw_swipe")
	await wait_sec(0.15)
	check("paw mid-swipe: leg visibly lifted", absf(leg1.rotation.x - base_still.x) > 0.5, "x=%s base=%s" % [leg1.rotation.x, base_still.x])
	var after_still: Vector3 = await wait_leg_stable(leg1, 0.45) # swipe (0.35s) long ended
	check("paw reset: STILL state leg back at base", after_still.distance_to(base_still) < 0.01, "rot=%s base=%s" % [after_still, base_still])
	# -- idle SIT --
	player.call("debug_set_idle_action", "sit")
	var base_sit: Vector3 = await wait_leg_stable(leg1, 1.8)
	player.call("do_paw_swipe")
	var after_sit: Vector3 = await wait_leg_stable(leg1, 0.6)
	check("paw reset: SIT state leg back at base", after_sit.distance_to(base_sit) < 0.01, "rot=%s base=%s" % [after_sit, base_sit])
	# -- idle GROOM (drives the SAME leg in v0.7 — the conflict case) --
	player.call("debug_set_idle_action", "groom")
	var base_groom: Vector3 = await wait_leg_stable(leg1, 1.8)
	player.call("do_paw_swipe")
	var after_groom: Vector3 = await wait_leg_stable(leg1, 0.6)
	check("paw reset: GROOM state leg back at base", after_groom.distance_to(base_groom) < 0.01, "rot=%s base=%s" % [after_groom, base_groom])
	player.set("idle_action", "")
	player.set("idle_next_in", 999.0)
	await wait_sec(0.9) # sit/groom envelopes drain back to standing
	# -- FROZEN --
	player.set("frozen", true)
	var base_frozen: Vector3 = await wait_leg_stable(leg1, 0.8)
	player.call("do_paw_swipe")
	var after_frozen: Vector3 = await wait_leg_stable(leg1, 0.6)
	check("paw reset: FROZEN state leg back at base", after_frozen.distance_to(base_frozen) < 0.01, "rot=%s base=%s" % [after_frozen, base_frozen])
	player.set("frozen", false)
	# -- WALKING: z must be exactly base (0) again and x inside the
	# pure walk-swing range (a stuck leg would sit outside it) --
	set_joy(Vector2(0, -40))
	await wait_sec(0.5)
	player.call("do_paw_swipe")
	await wait_sec(0.6)
	check("paw reset: WALK state z back to 0, x within walk swing", absf(leg1.rotation.z) < 0.01 and absf(leg1.rotation.x) <= 0.64, "rot=%s" % leg1.rotation)
	clear_joy()
	await wait_sec(0.3)

	# ---------- collision: fences solid, cat gap open (item 1) ----------
	park_npcs_far()
	(player as Node3D).global_position = Vector3(-47, 0.2, 22.5)
	await wait_sec(0.2)
	set_joy(Vector2(0, -60)) # walk north into the park fence run
	await wait_sec(1.2)
	var z_after_fence: float = (player as Node3D).global_position.z
	check("park fence is SOLID (cat stopped north of z=20.6 rail)", z_after_fence > 20.8, "z=%s" % z_after_fence)
	clear_joy()
	(player as Node3D).global_position = Vector3(-37, 0.2, 22.5) # the signed cat gap
	await wait_sec(0.2)
	set_joy(Vector2(0, -60))
	await wait_sec(1.2)
	var z_after_gap: float = (player as Node3D).global_position.z
	check("cat gap stays PASSABLE (cat slipped through)", z_after_gap < 19.5, "z=%s" % z_after_gap)
	clear_joy()
	# no fence posts stand in any roadway (item 5): the old spots are clear
	check("ender spots are off the roads", (main.get("ender_points") as Array).all(func(p): return absf((p as Vector3).z - 15.0) > 3.6 and absf((p as Vector3).x + 70.0) > 3.6), str(main.get("ender_points")))

	# ---------- traffic (item 7) ----------
	var car: Node3D = main.call("spawn_traffic_car")
	check("traffic car spawns", car != null and (main.get("traffic_cars") as Array).size() >= 1)
	var car_pos_before: Vector3 = car.position
	main.call("_process_traffic", 1.0)
	check("traffic car drives", car.position.distance_to(car_pos_before) > 5.0, str(car.position.distance_to(car_pos_before)))
	var car_vel: Vector3 = Vector3.ZERO
	for tc in main.get("traffic_cars"):
		if tc["node"] == car:
			car_vel = tc["vel"]
	if absf(car_vel.x) > 0.0:
		car.position.x = 382.0 if car_vel.x > 0.0 else -130.0 # just inside the (doubled) edge it is driving TOWARD — one 0.5s step at minimum speed (3.5) still crosses the despawn line
	else:
		car.position.z = 91.0 * signf(car_vel.z)
	main.call("_process_traffic", 0.5)
	var still_tracked: bool = false
	for tc in main.get("traffic_cars"):
		if tc["node"] == car:
			still_tracked = true
	check("traffic car despawns at the far edge", not still_tracked)
	# hit = points only
	park_npcs_far()
	(player as Node3D).global_position = Vector3(0, 0.2, -9.2)
	player.set("stamina", 100.0)
	main.set("score", 20)
	main.set("traffic_hit_cd", 0.0)
	var hit_car: Node3D = main.call("_build_car", main.get("traffic_group"), Vector3(-6, 0, -9.2), Color(0.8, 0.25, 0.22), true, "sedan", true)
	(main.get("traffic_cars") as Array).append({"node": hit_car, "vel": Vector3(8, 0, 0)})
	main.call("_process_traffic", 0.5)
	check("car hit: -5 points", int(main.get("score")) == 15, str(main.get("score")))
	check("car hit: comic bounce/stun, cat unharmed", float(player.get("stun_t")) > 0.0, str(player.get("stun_t")))
	main.set("score", 3)
	main.call("apply_traffic_hit", Vector3(1, 0, 0))
	check("car hit: score floors at 0", int(main.get("score")) == 0, str(main.get("score")))
	(main.get("traffic_cars") as Array).clear()

	# ---------- escape: one mechanism + exactly 30s pursuit (items 6 + retained) ----------
	var woman: Node = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman":
			woman = n
			break
	main.set("captor", woman)
	main.call("_enter_escape")
	check("escape state entered", str(main.get("state")) == "escape", str(main.get("state")))
	# v1.0.17 DESTINATION SPLIT: a regular townsperson's capture is
	# a HOUSE escape — the house room is the active one, there are
	# no ward cages in it, and its knock-overs are the house ones.
	check("v1.0.17: a regular capture lands in the HOUSE (not the pound)", bool(main.get("escape_room_is_house")) and (main.get("ward_cages") as Array).is_empty(), "is_house=" + str(main.get("escape_room_is_house")) + " ward=" + str((main.get("ward_cages") as Array).size()))
	var house_names: Array = []
	for hp in main.get("distract_props"):
		house_names.append(str(hp["name"]))
	check("v1.0.17: the house knock-overs are the plant, the book and the vase", house_names.has("the plant") and house_names.has("the book") and house_names.has("the vase"), str(house_names.slice(0, 3)))
	var kinds: Array = main.call("current_escape_kinds")
	check("v1.4: this capture's escape is the BACK DOOR only", kinds == ["bolt"], str(kinds))
	# drive the DOOR mechanism end-to-end, exactly as picked (no
	# override): prompt -> panel -> combo. v1.2: the intended path
	# starts with a DISTRACTION (she is in the room now), and the
	# finished combo swings the DOOR open — the cat then walks out
	# himself (walk_cat_out).
	distract_captor()
	check("v1.2: toppling a prop distracts the captor", bool(main.call("captor_distracted")), str(main.get("captor_room_state")))
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4) # at the back door (escape_origin + (13.4, *, 3.4))
	var score_before: int = int(main.get("score"))
	check("escape prompt is offered at the mechanism", bool(main.call("_escape_at_mechanism")))
	main.call("_on_escape_prompt_pressed")
	check("escape panel opens from the prompt", bool((main.get("escape_panel") as Control).visible))
	# v1.0.21 THE COMBINATION (Michael's direction): the swipe
	# pattern is gone — every start of the puzzle rolls a fresh
	# sequence of A / B button presses, 5 long.
	var combo0: Array = main.get("escape_combo")
	var combo_ok: bool = combo0.size() == 5
	for s0 in combo0:
		if str(s0) != "A" and str(s0) != "B":
			combo_ok = false
	check("v1.0.21: starting the puzzle rolls a 5-step A/B combination", combo_ok, str(combo0))
	var rolls: Dictionary = {}
	rolls[" ".join(PackedStringArray(combo0))] = true
	for r in range(11):
		main.call("_close_escape_panel")
		main.call("_on_escape_prompt_pressed")
		var rc: Array = main.get("escape_combo")
		if rc.size() == 5:
			rolls[" ".join(PackedStringArray(rc))] = true
	check("v1.0.21: a fresh start re-rolls the combination", rolls.size() > 1, str(rolls.keys()))
	var combo: Array = main.get("escape_combo")
	main.call("escape_panel_input", str(combo[0]))
	check("v1.0.21: a correct press lights the first step", int(main.get("combo_index")) == 1, str(main.get("combo_index")))
	var wrong_press: String = "B" if str(combo[1]) == "A" else "A"
	main.call("escape_panel_input", wrong_press) # wrong: the combo slips back — forgivingly keeping the press if it matches the first step
	var want_idx: int = 1 if wrong_press == str(combo[0]) else 0
	check("v1.0.21: a wrong press resets the combination progress", int(main.get("combo_index")) == want_idx, str(main.get("combo_index")))
	for i in range(want_idx, combo.size()):
		main.call("escape_panel_input", str(combo[i]))
	check("v1.4: a finished combo swings the DOOR open (no teleport out)", bool(main.get("exit_open")) and str(main.get("exit_open_kind")) == "bolt" and str(main.get("state")) == "escape", str(main.get("state")))
	# v1.4 CAMERA HANDOFF: wind the look controls up the way a
	# player hunting around the room does — the escape completion
	# must hand back the shipped town framing, not these values.
	main.set("look_pitch_deg", 45.0)
	main.set("look_yaw", 2.2)
	walk_cat_out()
	check("escape completes back into play", str(main.get("state")) == "play", str(main.get("state")))
	check("v1.4: escape completion restores the town pitch (room look drags don't leak)", float(main.get("look_pitch_deg")) == 4.0, str(main.get("look_pitch_deg")))
	check("escape bonus +3", int(main.get("score")) == score_before + 3, "%d -> %d" % [score_before, int(main.get("score"))])
	var purs: Dictionary = main.get("pursuers")
	check("post-escape pursuit starts at exactly 30.0s", purs.has(woman) and float(purs[woman]) == 30.0, str(purs))
	main.call("_process", 29.95)
	check("pursuit still running at 29.95s", (main.get("pursuers") as Dictionary).has(woman))
	main.call("_process", 0.1)
	check("pursuit over at 30.0s (captor back to wander)", not (main.get("pursuers") as Dictionary).has(woman) and str(woman.get("mode")) == "wander", str(woman.get("mode")))

	# ---------- v1.2 DISTRACTIONS + PAW ACTIVATION (Michael's playtest fixes) ----------
	# The captor is in the room; PAW (not a prompt tap) opens the
	# panel from a generous radius; undistracted she interrupts fast;
	# distracted, a slow combo still works.
	main.set("captor", woman)
	main.call("_enter_escape")
	check("v1.2: the captor is in the room with the cat", (woman as Node3D).global_position.distance_to(main.get("escape_origin")) < 18.0, str((woman as Node3D).global_position))
	check("v1.5: seventeen knock-over props in the room (almost everything loose)", (main.get("distract_props") as Array).size() == 17, str((main.get("distract_props") as Array).size()))
	# PAW activation, player-style: the cat stands ~1.4 m from the
	# back-door exit point (NOT dead-centre of the old rect zone)
	# and the PAW button's own callback is what fires.
	(player as Node3D).global_position = Vector3(572.0, 0.3, 3.4)
	check("v1.2: the mechanism radius reaches a real player's spot", bool(main.call("_escape_at_mechanism")))
	main.call("_on_interact")
	check("v1.2: PAW opens the panel at the mechanism", bool((main.get("escape_panel") as Control).visible))
	main.call("_close_escape_panel")
	# Undistracted: she notices within ~1.2 s of room time.
	main.call("_on_escape_prompt_pressed")
	for i in range(4):
		main.call("_process_escape", 0.4)
	check("v1.2: undistracted, she interrupts the panel fast", not (main.get("escape_panel") as Control).visible)
	check("v1.2: the interruption costs the combo, nothing else", int(main.get("combo_index")) == 0 and str(main.get("state")) == "escape", str(main.get("state")))
	check("v1.2: she comes to shoo the cat from the door", ["shoo", "return"].has(str(main.get("captor_room_state"))), str(main.get("captor_room_state")))
	check("v1.2: right after an interruption she is extra watchful", float(main.get("notice_cooldown")) > 0.0, str(main.get("notice_cooldown")))
	# The intended path: distract, then work the bolt SLOWLY (room
	# time passing between inputs) — no interruption while she's
	# busy. v1.4: the bolt is the ONLY step, so the finished combo
	# opens the door itself.
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))
		main.call("_process_escape", 0.4)
	check("v1.2: distracted, a slow combo still works the bolt", bool(main.get("exit_open")) and str(main.get("exit_open_kind")) == "bolt", str(main.get("exit_open_kind")))
	walk_cat_out()
	check("v1.2: the cat walks out and the escape completes", str(main.get("state")) == "play", str(main.get("state")))
	main.call("_process", 30.1) # drain the pursuit before the e2e section

	# ---------- v1.5 KNOCK OVER ALMOST EVERYTHING (Michael, 2026-11-17) ----------
	# The distraction system now covers nearly every loose object in
	# the room, not just plant/book/vase. PAW topples NEW props (the
	# floor lamp, the mug, the coat stand) through the real PAW path;
	# she rights them one at a time (the others queue); a righted
	# prop can be knocked over again; the door escape still works
	# after the chaos.
	main.set("captor", woman)
	main.call("_enter_escape")
	var props_by_id: Dictionary = {}
	for p in main.get("distract_props"):
		props_by_id[str(p["id"])] = p
	var new_ids_ok: bool = true
	for want_id in ["floorlamp", "tablelamp", "mug", "cushion", "fruitbowl", "shoes", "picture", "bookstack", "yarn", "sillplant", "wastebasket", "coatstand", "stool", "wateringcan"]:
		if not props_by_id.has(want_id):
			new_ids_ok = false
	check("v1.5: all fourteen new knock-over props are registered", new_ids_ok, str(props_by_id.keys()))
	(player as Node3D).global_position = Vector3(571.9, 0.3, -7.6) # beside the floor lamp
	main.call("_on_interact")
	check("v1.5: PAW topples the floor lamp", bool(props_by_id["floorlamp"]["toppled"]))
	(player as Node3D).global_position = Vector3(560.7, 0.3, 2.2) # at the coffee table
	main.call("_on_interact")
	check("v1.5: PAW topples the mug", bool(props_by_id["mug"]["toppled"]))
	(player as Node3D).global_position = Vector3(572.0, 0.3, 8.0) # by the coat stand
	main.call("_on_interact")
	check("v1.5: PAW topples the coat stand", bool(props_by_id["coatstand"]["toppled"]))
	check("v1.5: she works on the first while the rest queue", str(main.get("captor_prop").get("id", "")) == "floorlamp" and (main.get("distract_queue") as Array).size() == 2, "queue=" + str((main.get("distract_queue") as Array).size()))
	check("v1.5: she is distracted by the new props", bool(main.call("captor_distracted")), str(main.get("captor_room_state")))
	var guard2: int = 0
	while guard2 < 480:
		var any_down: bool = false
		for p in main.get("distract_props"):
			if bool(p["toppled"]):
				any_down = true
		if not any_down:
			break
		main.call("_process_escape", 0.25)
		guard2 += 1
	check("v1.5: she rights every toppled prop, one at a time", not bool(props_by_id["floorlamp"]["toppled"]) and not bool(props_by_id["mug"]["toppled"]) and not bool(props_by_id["coatstand"]["toppled"]), "guard=" + str(guard2))
	check("v1.5: a righted prop is back at its home rotation", ((props_by_id["floorlamp"]["pivot"] as Node3D).rotation).distance_to(props_by_id["floorlamp"]["home_rot"]) < 0.01)
	main.call("topple_prop", props_by_id["mug"])
	check("v1.5: a righted prop can be knocked over again", bool(props_by_id["mug"]["toppled"]))
	guard2 = 0
	while bool(props_by_id["mug"]["toppled"]) and guard2 < 200:
		main.call("_process_escape", 0.25)
		guard2 += 1
	check("v1.5: she rights the re-toppled mug too", not bool(props_by_id["mug"]["toppled"]))
	# Leave the room the intended way so later sections start clean.
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))
		main.call("_process_escape", 0.4)
	check("v1.5: after the chaos, the door escape still works", bool(main.get("exit_open")) and str(main.get("exit_open_kind")) == "bolt", str(main.get("exit_open_kind")))
	walk_cat_out()
	check("v1.5: the cat walks out after the knock-over spree", str(main.get("state")) == "play", str(main.get("state")))
	main.call("_process", 30.1) # drain the pursuit before the e2e section

	# ---------- SHELTER WARD: animals in cages + the BREAKOUT ----------
	# Every freeable cage starts with its animal home and visible;
	# a PAW at a gate opens it (+5, once per cage), the animal RUNS
	# out and is gone; re-entering the room resets the whole ward.
	# v1.0.17: the ward is the POUND's — this section now enters as
	# the officer's capture (a regular capture goes to a house,
	# where there are no cages to free; breakout stays shelter-only).
	main.set("captor", main.get("pound_worker"))
	main.call("_enter_escape")
	var ward: Array = main.get("ward_cages")
	check("ward: the freeable cages are registered (runs + stacked bank)", ward.size() >= 10, str(ward.size()))
	var all_home: bool = true
	for cg0 in ward:
		var an0 := cg0["animal"] as Node3D
		if not an0.visible or str(cg0["animal_state"]) != "in" or bool(cg0["freed"]):
			all_home = false
	check("ward: every cage starts with its animal home and visible", all_home)
	var biscuit: Dictionary = ward[0]
	var willow: Dictionary = {}
	for cg1 in ward:
		if str(cg1["name"]) == "WILLOW":
			willow = cg1
	check("ward: the stacked cage over Biscuit is registered", not willow.is_empty())
	var score_ward0: int = int(main.get("score"))
	(player as Node3D).global_position = (biscuit["gate_pos"] as Vector3) + Vector3(0, 0.3, -1.3)
	main.call("_on_interact")
	check("ward: a PAW at the gate frees Biscuit", bool(biscuit["freed"]))
	check("ward: freeing pays +5", int(main.get("score")) == score_ward0 + 5, str(main.get("score")))
	main.call("_on_interact")
	check("ward: the next PAW frees the stacked cage over him (WILLOW)", bool(willow["freed"]))
	check("ward: the second free pays +5 more", int(main.get("score")) == score_ward0 + 10, str(main.get("score")))
	main.call("_on_interact")
	check("ward: no third free from the same spot — each cage pays once", int(main.get("score")) == score_ward0 + 10, str(main.get("score")))
	var run_guard: int = 0
	while run_guard < 200 and (str(biscuit["animal_state"]) != "gone" or str(willow["animal_state"]) != "gone"):
		main.call("_process_escape", 0.25)
		run_guard += 1
	check("ward: freed animals RUN out and are gone", str(biscuit["animal_state"]) == "gone" and str(willow["animal_state"]) == "gone", "guard=" + str(run_guard))
	check("ward: freed animals end hidden", not (biscuit["animal"] as Node3D).visible)
	main.call("_enter_escape")
	check("ward: the next visit resets the cages", not bool(biscuit["freed"]) and str(biscuit["animal_state"]) == "in" and (biscuit["animal"] as Node3D).visible)
	# Leave the room the intended way so later sections start clean.
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	for inp in main.get("escape_combo"):
		main.call("escape_panel_input", str(inp))
		main.call("_process_escape", 0.4)
	walk_cat_out()
	main.call("_process", 30.1) # drain the pursuit

	# ---------- v1.0.19 PRONOUNS (Michael's v1.0.17 play report) ----------
	# Every character has ONE pronoun set (person.gd _apply_type) and
	# all captor-referring text must use it: the pound called the
	# officer "she", and one house screen said "distract her" at the
	# top and "distract him" at the bottom for the same captor.
	# Collect each captor's full generated text set and read it whole.
	var rx_fem := RegEx.new()
	rx_fem.compile("(?i)\\b(she|her|hers)\\b")
	var rx_masc := RegEx.new()
	rx_masc.compile("(?i)\\b(he|him|his)\\b")
	# (1) the officer: he/him in his text, and NO she/her anywhere
	var officer_texts: Array = collect_captor_texts(main.get("pound_worker"))
	var officer_joined: String = "\n".join(PackedStringArray(officer_texts))
	check("v1.0.19: the officer's escape text uses he/him", officer_joined.contains("so is he") and officer_joined.contains("distract him"), officer_joined)
	check("v1.0.19: the officer's escape text has NO she/her", rx_fem.search(officer_joined) == null, officer_joined)
	# (2) the young woman: she/her in her text, and NO he/him mixed in
	var woman19: Node = npc_by_type("woman")
	var woman_texts: Array = collect_captor_texts(woman19)
	var woman_joined: String = "\n".join(PackedStringArray(woman_texts))
	check("v1.0.19: the woman's escape text uses she/her", woman_joined.contains("so is she") and woman_joined.contains("distract her"), woman_joined)
	check("v1.0.19: the woman's escape text has NO he/him", rx_masc.search(woman_joined) == null, woman_joined)
	# (3) every other captor the suite can instantiate: the
	# shopkeeper is he/him (moustache); the kid and the dog walker
	# have NO established gender, so their
	# text must carry no gendered pronoun at all and use the name.
	var keeper_texts: Array = collect_captor_texts(npc_by_type("shopkeeper"))
	var keeper_joined: String = "\n".join(PackedStringArray(keeper_texts))
	check("v1.0.19: the shopkeeper's escape text uses he/him with NO she/her", keeper_joined.contains("distract him") and rx_fem.search(keeper_joined) == null, keeper_joined)
	# v1.0.22: "pedestrian" is GONE from the town (the generic
	# code-built neighbour was the last non-Meshy person; Michael's
	# all-Meshy rule removed the type entirely) — the name-only
	# coverage stays with the kid and the dog walker, and the NEW
	# cast's pronoun sets are checked below instead.
	for t19 in ["kid", "dogwalker"]:
		var cap19: Node = npc_by_type(t19)
		var n_texts: Array = collect_captor_texts(cap19)
		var n_joined: String = "\n".join(PackedStringArray(n_texts))
		check("v1.0.19: the " + t19 + " (no established gender) gets NO gendered pronouns", rx_fem.search(n_joined) == null and rx_masc.search(n_joined) == null, n_joined)
		check("v1.0.19: the " + t19 + "'s text refers by name instead", n_joined.contains(str(cap19.get("display_name"))), n_joined)
	# (4) v1.0.22: a NEW cast member's pronouns — the baker is
	# she/her (her reference sheet), in her text with NO he/him.
	var baker_texts: Array = collect_captor_texts(npc_by_type("baker"))
	var baker_joined: String = "\n".join(PackedStringArray(baker_texts))
	check("v1.0.22: the baker's escape text uses she/her with NO he/him", baker_joined.contains("distract her") and rx_masc.search(baker_joined) == null, baker_joined)
	# Leave the room the intended way so later sections start clean.
	main.set("captor", woman19)
	main.call("_enter_escape")
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	walk_cat_out()
	main.call("_process", 30.1) # drain the pursuit

	# ---------- v1.0.20 INDOOR CAMERA (Michael's v1.0.17 play screenshot) ----------
	# Indoors the follow camera inherited the town profile (pitch 4,
	# orbit 5.0, FOV 62): it rode at ~0.7 m — furniture height — and
	# the collision pull-in squeezed it in behind the cat; his
	# screenshot has the cat at half the screen against a bare wall
	# corner, the room and the captor out of view. The room now has
	# its own profile: entering sets the indoor pitch (26), the
	# escape camera never rides below it, the orbit is 3.0 at FOV
	# 70, and a pull that would pin the camera closer than 2.0 m to
	# the cat lifts it instead (aim raised with the lift, so a
	# captor across the room stays in frame). Measured with the
	# REAL camera, the way the v1.3 section measures the town.
	main.set("captor", woman19)
	main.call("_enter_escape")
	check("v1.0.20: entering a room sets the indoor pitch (26)", absf(float(main.get("look_pitch_deg")) - 26.0) < 0.01, str(main.get("look_pitch_deg")))
	(player as Node3D).global_position = Vector3(562, 0.3, -2) # mid-room
	main.set("look_yaw", -PI * 0.75)
	await wait_sec(1.2) # camera settle
	var icam: Camera3D = main.get("cam")
	var ivp: Vector2 = get_viewport().get_visible_rect().size
	check("v1.0.20: the room runs the indoor profile (orbit 3.0, FOV 70)", absf(float(main.get("current_cam_dist")) - 3.0) < 0.01 and absf(icam.fov - 70.0) < 0.01, "dist=" + str(main.get("current_cam_dist")) + " fov=" + str(icam.fov))
	var cat_share_now = func() -> float:
		var a := AABB()
		var fst := true
		for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
			var ga: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			a = ga if fst else a.merge(ga)
			fst = false
		var b: Vector3 = (player as Node3D).global_position
		return absf(icam.unproject_position(Vector3(b.x, a.position.y, b.z)).y - icam.unproject_position(Vector3(b.x, a.position.y + a.size.y, b.z)).y) / ivp.y
	var mid_share: float = cat_share_now.call()
	check("v1.0.20: mid-room the cat is readable but not filling the screen (share 0.10-0.35)", mid_share >= 0.10 and mid_share <= 0.35, str(mid_share))
	(woman19 as Node3D).global_position = Vector3(565.5, 0.25, 1.5) # across the room, in the view direction
	await wait_sec(0.35)
	var whead: Vector3 = (woman19 as Node3D).global_position + Vector3(0, 1.55, 0)
	var whead_in: bool = not icam.is_position_behind(whead) and Rect2(Vector2.ZERO, ivp).has_point(icam.unproject_position(whead))
	check("v1.0.20: the captor across the room is in frame", whead_in, str(icam.unproject_position(whead) / ivp))
	# The corner case from the screenshot: the cat backed into the
	# south-west corner, the camera pushed into the corner behind
	# him. The pull-in must lift the camera, never pin it to him.
	(player as Node3D).global_position = Vector3(547.6, 0.3, 8.4)
	main.set("look_yaw", -PI * 0.25)
	await wait_sec(1.2) # camera settle
	var corner_gap: float = icam.global_position.distance_to((player as Node3D).global_position + Vector3(0, 0.38, 0))
	check("v1.0.20: backed into a corner the camera lifts instead of pinning to the cat (>= 1.9m from him)", corner_gap >= 1.9, str(corner_gap))
	var corner_share: float = cat_share_now.call()
	check("v1.0.20: in the corner the cat still does not fill the screen (share <= 0.35)", corner_share <= 0.35, str(corner_share))
	# Leave the room the intended way so later sections start clean.
	main.set("captor", woman19)
	main.call("_enter_escape")
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	walk_cat_out()
	main.call("_process", 30.1) # drain the pursuit

	# ---------- v0.9 CAPTURE END-TO-END (the grabber really takes him home) ----------
	# Michael reported an NPC who "couldn't take me home" — so drive
	# the REAL path, nothing mocked: paw provokes the tell, the chase
	# runs, the kid catches and HOLDS the cat, the cutscene fires,
	# the escape room opens, and the 30s pursuit follows the escape.
	park_npcs_far()
	clear_joy()
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	player.set("frozen", false)
	player.set("stamina", 100.0)
	var cap_grabber: Node = npc_by_role("grabber")
	(cap_grabber as Node3D).global_position = Vector3(61.5, 0.2, 84)
	cap_grabber.set("notice", 0.0)
	cap_grabber.set("notice_cooldown", 0.0)
	cap_grabber.set("mode", "wander")
	await wait_sec(0.3)
	main.call("_paw_action")
	check("capture e2e: paw provokes the grabber's tell", str(cap_grabber.get("mode")) == "tell", str(cap_grabber.get("mode")))
	var cap_elapsed: float = 0.0
	while cap_elapsed < 12.0 and str(main.get("state")) == "play":
		await wait_sec(0.25)
		cap_elapsed += 0.25
	check("capture e2e: chase ends in a real capture (cutscene)", str(main.get("state")) == "cutscene", str(main.get("state")) + " after " + str(cap_elapsed) + "s mode=" + str(cap_grabber.get("mode")))
	check("capture e2e: the captor is the grabber", main.get("captor") == cap_grabber)
	main.call("skip_cutscene")
	check("capture e2e: escape room opens after the cutscene", str(main.get("state")) == "escape", str(main.get("state")))
	check("capture e2e: the escape he is given is the back door", main.call("current_escape_kinds") == ["bolt"], str(main.call("current_escape_kinds")))
	# v1.2 intended path: the captor is in the room — distract him
	# with a toppled prop first, then work the door's combo, then
	# the cat walks out of the opened doorway himself (v1.4: the
	# door is every capture's way out — no override needed).
	distract_captor()
	check("capture e2e: the captor is distracted by the toppled prop", bool(main.call("captor_distracted")), str(main.get("captor_room_state")))
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	check("capture e2e: the finished combo opens the way out", bool(main.get("exit_open")))
	# v1.4: drag the look around the room first (the reported bug:
	# these values used to follow him back to town for good).
	main.set("look_pitch_deg", 45.0)
	main.set("look_yaw", 2.2)
	walk_cat_out()
	check("capture e2e: escape returns to play, grabber pursuing", str(main.get("state")) == "play" and (main.get("pursuers") as Dictionary).has(cap_grabber), str(main.get("state")))
	# v1.4 CAMERA HANDOFF, measured with the real camera during the
	# pursuit: town FOV, town chase distance, and the cat back at a
	# normal share of the frame (probe on the old code: pitch stuck
	# at 45, camera ~6 m up, cat at 0.03 — after the fix: pitch 4,
	# camera ~1.8 m up, cat 0.09-0.12).
	await wait_sec(0.35)
	var ecam: Camera3D = main.get("cam")
	check("v1.4: pursuit runs at town camera values (FOV 70, chase dist 6.4)", absf(ecam.fov - 70.0) < 0.01 and absf(float(main.get("current_cam_dist")) - 6.4) < 0.01, "fov=" + str(ecam.fov) + " dist=" + str(main.get("current_cam_dist")))
	var e_aabb := AABB()
	var e_first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga2: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		e_aabb = ga2 if e_first else e_aabb.merge(ga2)
		e_first = false
	var e_base: Vector3 = (player as Node3D).global_position
	var e_vp: Vector2 = get_viewport().get_visible_rect().size
	var e_share: float = absf(ecam.unproject_position(Vector3(e_base.x, e_aabb.position.y, e_base.z)).y - ecam.unproject_position(Vector3(e_base.x, e_aabb.position.y + e_aabb.size.y, e_base.z)).y) / e_vp.y
	check("v1.4: the cat is a normal size again during the pursuit (not tiny from above)", e_share >= 0.05, str(e_share))
	# v1.0.13 PURSUIT CAMERA: the far-pursuer geometry real play
	# always reaches and the v1.4 staging never did — sprinting
	# away, she falls tens of metres behind while her mode stays
	# "pursue" for the full timer. On the old code the chase cam's
	# aim lerp dragged the aim point gap x 0.28 m off the cat and
	# he measured 0.03 of the frame at a 30 m gap, recovering only
	# when the timer ended (tests/PursuitCamProbe.tscn). Freeze
	# her 30 m away mid-pursuit: the framing must fall back to
	# the town distance and the cat to his normal share.
	cap_grabber.set_physics_process(false)
	var f_pos: Vector3 = (player as Node3D).global_position + Vector3(-30, 0, 0)
	f_pos.y = 0.2
	(cap_grabber as Node3D).global_position = f_pos
	await wait_sec(1.2) # camera settle
	var f_aabb := AABB()
	var f_first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga4: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		f_aabb = ga4 if f_first else f_aabb.merge(ga4)
		f_first = false
	var f_base: Vector3 = (player as Node3D).global_position
	var f_share: float = absf(ecam.unproject_position(Vector3(f_base.x, f_aabb.position.y, f_base.z)).y - ecam.unproject_position(Vector3(f_base.x, f_aabb.position.y + f_aabb.size.y, f_base.z)).y) / e_vp.y
	check("v1.0.13: a far pursuer (30m) cannot drag the pursuit camera out (orbit back to 2.0)", absf(float(main.get("current_cam_dist")) - 2.0) < 0.01, "dist=" + str(main.get("current_cam_dist")))
	check("v1.0.13: the cat stays a normal size mid-pursuit with a far pursuer (share >= 0.18)", f_share >= 0.18, str(f_share))
	cap_grabber.set_physics_process(true)
	main.call("_process", 30.1)
	check("capture e2e: pursuit ends at 30s", not (main.get("pursuers") as Dictionary).has(cap_grabber))
	# ...and once the pursuit is over the framing is the plain town
	# view again: orbit 2.0 and the cat at his usual >= 0.18 share.
	park_npcs_far()
	await wait_sec(1.2)
	# (measure against the cat's CURRENT spot — he may have idled)
	var t_base: Vector3 = (player as Node3D).global_position
	var t_aabb := AABB()
	var t_first := true
	for mi in (player as Node3D).find_children("*", "MeshInstance3D", true, false):
		var ga3: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		t_aabb = ga3 if t_first else t_aabb.merge(ga3)
		t_first = false
	var t_share: float = absf(ecam.unproject_position(Vector3(t_base.x, t_aabb.position.y, t_base.z)).y - ecam.unproject_position(Vector3(t_base.x, t_aabb.position.y + t_aabb.size.y, t_base.z)).y) / e_vp.y
	check("v1.4: after the pursuit the town framing is fully back (orbit 2.0, cat >= 0.18 of frame)", absf(float(main.get("current_cam_dist")) - 2.0) < 0.01 and t_share >= 0.18, "dist=" + str(main.get("current_cam_dist")) + " share=" + str(t_share))

	# ---------- v1.3 SCOOP: the pickup is one continuous motion -----
	# Michael: the old pickup was "janky and weird" — a per-frame lerp
	# that crept then snapped, into a rigid standing pose at her BACK
	# (the follow camera lost him entirely). Drive a REAL capture via
	# the same on_cat_taken the chase uses and sample his transform
	# on the real clock: no step may exceed a smooth-motion bound, he
	# must END in front of her chest in his held pose, and both poses
	# must release cleanly into the escape room.
	park_npcs_far()
	clear_joy()
	(player as Node3D).global_position = Vector3(30, 0.2, 60)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	player.set("frozen", false)
	var scoop_npc: Node = npc_by_role("grabber")
	(scoop_npc as Node3D).global_position = Vector3(31.05, 0.2, 60)
	(scoop_npc as Node3D).rotation = Vector3(0, -PI * 0.5, 0)
	scoop_npc.set("mode", "wander")
	scoop_npc.set("notice", 0.0)
	scoop_npc.set("notice_cooldown", 5.0)
	scoop_npc.set("grab_progress", 0.0)
	await wait_sec(0.1)
	main.call("on_cat_taken", scoop_npc)
	check("scoop: capture enters the cutscene", str(main.get("state")) == "cutscene", str(main.get("state")))
	var prev_pos: Vector3 = (player as Node3D).global_position
	var max_step: float = 0.0
	var scoop_t: float = 0.0
	var front_dot: float = -1.0
	var held_seen: bool = false
	while scoop_t < 3.4 and str(main.get("state")) == "cutscene":
		await wait_sec(0.1)
		scoop_t += 0.1
		var pp: Vector3 = (player as Node3D).global_position
		max_step = maxf(max_step, pp.distance_to(prev_pos))
		prev_pos = pp
		if scoop_t >= 2.6:
			var fwd: Vector3 = (scoop_npc as Node3D).global_transform.basis.z
			fwd.y = 0.0
			var to_cat_v: Vector3 = pp - (scoop_npc as Node3D).global_position
			to_cat_v.y = 0.0
			if to_cat_v.length() > 0.05 and fwd.length() > 0.05:
				front_dot = fwd.normalized().dot(to_cat_v.normalized())
			if bool(player.call("is_held")):
				held_seen = true
	check("scoop: the lift is continuous (no snap/teleport steps)", max_step < 0.6, "max step " + str(max_step))
	check("scoop: he ends cradled IN FRONT of her chest", front_dot > 0.55, "dot " + str(front_dot))
	check("scoop: the cat settles into his held pose", held_seen)
	main.call("skip_cutscene")
	check("scoop: poses release into the escape room", str(main.get("state")) == "escape" and float(scoop_npc.get("scoop_cradle_a")) == 0.0 and float(player.get("held_target")) == 0.0, str(main.get("state")))
	# Clean up the intended way, exactly like the e2e above (v1.4:
	# the picked escape is the back door — one combo, walk out).
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	walk_cat_out()
	main.call("_process", 30.1)
	check("scoop: cleanup returns to play", str(main.get("state")) == "play", str(main.get("state")))

	# ---------- POUND VAN (Michael, 2026-11-17) ----------
	# ONE white ANIMAL CONTROL van patrols the town forever.
	# v1.0.21: coming near the van (or the worker on foot) no longer
	# triggers him instantly — the being-noticed meter builds like
	# any grabber's (over the van while he rides, over his head on
	# foot), and only a FULL meter pulls the van over to the kerb;
	# the worker (white uniform, net in hand) gets out and comes
	# after the collarless cat; his catch is the ORDINARY capture
	# flow — back at the pound means the back-door bolt room — then
	# his pursuit; lose him (or outlast the pursuit) and he walks
	# back to the van, gets in, and the round ends at the DEPOT: the
	# van drives into its GARAGE and parks inside before pulling out
	# onto patrol again. He is NOT one of the 48 town NPCs, and
	# the collar flag (player_collared) switches him off entirely.
	park_npcs_far()
	for n in main.get("npcs"):
		n.set("notice_cooldown", 99999.0) # nobody else may start a chase in this section
	clear_joy()
	main.set("pound_engage_cd", 0.0) # re-arm him (held off since "enter play")
	var pvan: Node3D = main.get("pound_van")
	var pworker: Node = main.get("pound_worker")
	check("pound van: the patrol van and its worker exist", pvan != null and pworker != null)
	var van_count := 0
	var vstack: Array = [main]
	while not vstack.is_empty():
		var vn: Node = vstack.pop_back()
		for vch in vn.get_children():
			vstack.append(vch)
		if vn.name == "PoundVan":
			van_count += 1
	check("pound van: exactly ONE patrol van in the world", van_count == 1, str(van_count))
	check("pound van: the worker is NOT one of the 48 town NPCs (population + 25% split untouched)", not (main.get("npcs") as Array).has(pworker) and (main.get("npcs") as Array).size() == 48)
	var van_labels: Array = []
	collect_label3d(pvan, van_labels)
	var vt: Array = []
	for l in van_labels:
		vt.append(str((l as Label3D).text))
	check("pound van: POUND / ANIMAL CONTROL lettering printed on the body (both flanks)", vt.count("POUND") == 2 and vt.count("ANIMAL CONTROL") == 2, str(vt))
	check("pound van: the worker carries his net (pole + hoop + bag on the arm)", pworker.get("net_root") != null and (pworker.get("net_root") as Node3D).get_child_count() >= 3)
	# ---------- v1.0.21: Meshy vehicles + the light bar ----------
	check("v1.0.21 vehicles: the pound van IS the Meshy Animal Control van", _subtree_vehicle_path(pvan) == "res://assets/models/van_animal_control.glb", _subtree_vehicle_path(pvan))
	var tcar_v: Node3D = main.call("spawn_traffic_car")
	check("v1.0.21 vehicles: traffic cars are Meshy models too", _subtree_vehicle_path(tcar_v) != "", _subtree_vehicle_path(tcar_v))
	var tcars_arr: Array = main.get("traffic_cars")
	for te in tcars_arr.duplicate():
		if te["node"] == tcar_v:
			tcars_arr.erase(te)
	tcar_v.queue_free()
	# the light bar (Michael's order: meter fills -> LIGHTS ON ->
	# van stops -> he gets out): dark on patrol; in an encounter
	# the two lamps alternate, never both, never neither.
	var lamp_l: MeshInstance3D = main.get("pound_light_lamp_l")
	var lamp_r: MeshInstance3D = main.get("pound_light_lamp_r")
	check("v1.0.21 lights: the van carries the flashing light rig", lamp_l != null and lamp_r != null)
	main.set("pound_state", "patrol")
	main.set("pound_notice", 0.0) # v1.0.22: an empty meter is part of "on patrol" now (a building meter lights the bar)
	main.call("_pound_update_lights", 0.1)
	check("v1.0.21 lights: DARK on patrol", not lamp_l.visible and not lamp_r.visible)
	main.set("pound_state", "chase")
	main.call("_pound_update_lights", 0.1)
	var one_lit: bool = lamp_l.visible != lamp_r.visible
	var first_lamp_l: bool = lamp_l.visible
	main.call("_pound_update_lights", 0.3)
	var swapped: bool = lamp_l.visible != first_lamp_l and lamp_l.visible != lamp_r.visible
	check("v1.0.21 lights: in an encounter exactly one lamp is lit, alternating", one_lit and swapped, str(lamp_l.visible) + "/" + str(lamp_r.visible))
	main.set("pound_state", "patrol")
	main.call("_pound_update_lights", 0.1)
	check("v1.0.21 lights: dark again when the patrol resumes", not lamp_l.visible and not lamp_r.visible)
	# ---------- v1.0.22: cars drive NOSE-FIRST ----------
	# The gap that shipped v1.0.21's backwards cars: no check ever
	# compared a car's facing with its motion. Sample the REAL
	# spawner (seeded, so the sample is stable): every car it
	# makes must point its nose along its velocity.
	(main.get("rng") as RandomNumberGenerator).seed = 20261119
	var nose_bad := 0
	var nose_dirs := {}
	for si in range(14):
		var sc: Node3D = main.call("spawn_traffic_car")
		if sc == null:
			continue
		await get_tree().process_frame
		var sarr: Array = main.get("traffic_cars")
		var svel: Vector3 = Vector3.ZERO
		for te2 in sarr:
			if te2["node"] == sc:
				svel = te2["vel"]
		var nd: Vector3 = main.call("_car_nose_dir", sc)
		if svel.length() < 0.5 or nd.dot(svel.normalized()) < 0.9:
			nose_bad += 1
		nose_dirs[str(svel.normalized())] = true
		for te3 in sarr.duplicate():
			if te3["node"] == sc:
				sarr.erase(te3)
		sc.queue_free()
	check("v1.0.22: every spawned traffic car points its nose along its travel direction", nose_bad == 0, "bad=" + str(nose_bad))
	check("v1.0.22: the nose sample covered several travel directions", nose_dirs.size() >= 3, str(nose_dirs.keys()))
	# ---------- v1.0.22: lights start WITH the meter + the siren ----------
	# Michael: the bar lights as soon as the meter starts building
	# (proximity), not only once it fills — and a soft two-tone
	# whoop sounds while the bar is live, stopping with it.
	main.set("pound_state", "patrol")
	main.set("pound_notice", 0.3) # building, nowhere near full
	main.call("_pound_update_lights", 0.1)
	check("v1.0.22 lights: lit while the notice meter is still BUILDING (patrol, notice 0.3)", lamp_l.visible != lamp_r.visible, str(lamp_l.visible) + "/" + str(lamp_r.visible))
	var siren: AudioStreamPlayer = main.get("sfx_siren")
	check("v1.0.22 siren: the van has its siren player", siren != null and siren.stream != null)
	check("v1.0.22 siren: playing while the lights are active", siren != null and siren.playing)
	main.set("pound_notice", 0.0)
	main.set("pound_state", "patrol")
	main.call("_pound_update_lights", 0.1)
	check("v1.0.22 lights: dark again once the meter empties on patrol", not lamp_l.visible and not lamp_r.visible)
	check("v1.0.22 siren: stopped when the lights go out", siren != null and not siren.playing)
	# patrol: he drives the loop, on the lanes, worker riding inside
	main.set("pound_state", "patrol")
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	(player as Node3D).global_position = Vector3(-100, 0.2, 80) # far off his roads: no engagement
	var ppos0: Vector3 = pvan.position
	for i in range(10):
		main.call("_update_pound", 0.5)
	check("pound van: the patrol drives on (moved > 15m over 5s of patrol)", pvan.position.distance_to(ppos0) > 15.0, str(pvan.position.distance_to(ppos0)))
	var patrol_disp: Vector3 = pvan.position - ppos0
	patrol_disp.y = 0.0
	check("v1.0.22: the patrolling pound van drives NOSE-first (nose along its motion)", patrol_disp.length() > 1.0 and (main.call("_car_nose_dir", pvan) as Vector3).dot(patrol_disp.normalized()) > 0.9, "nose=" + str(main.call("_car_nose_dir", pvan)) + " disp=" + str(patrol_disp))
	check("pound van: the patrol stays on the road lane", absf(pvan.position.z - 16.8) < 1.5, str(pvan.position))
	check("pound van: the worker rides inside (invisible, travelling with the van)", not pworker.visible and (pworker as Node3D).global_position.distance_to(pvan.position) < 1.0)
	# v1.0.21 ROUTE AUDIT: three full patrol loops, stepped
	# synchronously — the van's BODY (an oriented box, half extents
	# 2.05 x 1.0) must never enter a house lot envelope or the
	# depot's solid walls. (The old route END was the one bad leg:
	# a coin-flip U-turn at the west waypoint that swung through
	# the Oak Avenue front yards — the depot legs replace it, and
	# the depot cycle below audits those too.)
	var audit_rects: Array = []
	for h in main.get("houses"):
		var hp: Vector3 = h["pos"]
		audit_rects.append(Rect2(hp.x - 5.8, hp.z - 5.2, 11.6, 10.4))
	for sr in main.get("pound_depot_solids"):
		audit_rects.append(sr)
	var audit_bad := 0
	var audit_steps := 0
	while audit_steps < 21600: # 3 loops ≈ 3 x ~120 s of driving at 1/60 steps
		main.call("_pound_drive_route", 1.0 / 60.0, 8.5)
		audit_steps += 1
		var vyaw: float = float(main.get("pound_van_yaw"))
		var vf := Vector2(cos(vyaw), -sin(vyaw))
		var vs := Vector2(sin(vyaw), cos(vyaw))
		var vc := Vector2(pvan.position.x, pvan.position.z)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner: Vector2 = vc + vf * (2.05 * sx) + vs * (1.0 * sz)
				for r in audit_rects:
					if (r as Rect2).has_point(corner):
						audit_bad += 1
	check("v1.0.21: three patrol loops never put the van's body inside a house lot or the depot walls", audit_bad == 0, "violations=" + str(audit_bad) + " steps=" + str(audit_steps))
	check("v1.0.21: the depot (garage + office) is built and its solids registered", main.get_node_or_null("World/PoundDepot") != null and (main.get("pound_depot_solids") as Array).size() == 4)
	# engagement: the cat steps onto his road, just ahead of the van
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	main.set("pound_route_idx", 1)
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "patrol")
	(player as Node3D).global_position = pvan.position + Vector3(11.0, 0.2, 0.0)
	player.set("velocity", Vector3.ZERO)
	# v1.0.21: proximity to the VAN builds the notice meter first
	# (the van stops for the cat in its road, ~5m short, and the
	# meter fills over the van) — nothing is instant any more.
	var guard_p: float = 0.0
	while float(main.get("pound_notice")) < 0.15 and guard_p < 6.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("v1.0.21: proximity to the van builds the officer's notice meter", float(main.get("pound_notice")) >= 0.15, "notice=" + str(main.get("pound_notice")) + " after " + str(guard_p) + "s")
	check("v1.0.21: the meter shows over the VAN while he rides in it", bool((main.get("pound_bar_root") as Node3D).visible))
	guard_p = 0.0
	while str(main.get("pound_state")) != "exit" and guard_p < 12.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("pound van: a FULL meter -> the van pulls over and the worker gets out", str(main.get("pound_state")) == "exit", str(main.get("pound_state")) + " after " + str(guard_p) + "s")
	check("pound van: pulled over at the KERB, not blocking the road centre (offset >= 2.4 from the z=15 centreline)", absf(pvan.position.z - 15.0) >= 2.4, str(pvan.position))
	check("pound van: the worker is out on foot beside the van, net in hand", pworker.visible and (pworker as Node3D).global_position.distance_to(pvan.position) > 1.0 and bool((pworker.get("net_root") as Node3D).visible), "vis=" + str(pworker.visible) + " dist=" + str((pworker as Node3D).global_position.distance_to(pvan.position)) + " netvis=" + str(bool((pworker.get("net_root") as Node3D).visible)))
	guard_p = 0.0
	while str(pworker.get("mode")) != "chase" and guard_p < 8.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("pound van: the worker chases — the game's own chase, determined (never angry) face", str(pworker.get("mode")) == "chase" and str(pworker.get("expression")) == "determined", str(pworker.get("mode")) + "/" + str(pworker.get("expression")))
	check("pound van: his chase engages the chase camera like any chaser", bool(main.get("chase_cam_active")))
	# capture: the still cat is caught and held -> the ordinary flow
	guard_p = 0.0
	while str(main.get("state")) == "play" and guard_p < 14.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("pound van: his catch routes into the ordinary capture (scoop cutscene, he is the captor)", str(main.get("state")) == "cutscene" and main.get("captor") == pworker, str(main.get("state")))
	check("pound van: while he is the captor the van waits (pound state 'away')", str(main.get("pound_state")) == "away", str(main.get("pound_state")))
	main.call("skip_cutscene")
	check("pound van: back at the pound = the back-door bolt escape room", str(main.get("state")) == "escape" and main.call("current_escape_kinds") == ["bolt"], str(main.get("state")))
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	walk_cat_out()
	check("pound van: the escape completes and HE is the pursuer", str(main.get("state")) == "play" and (main.get("pursuers") as Dictionary).has(pworker), str(main.get("state")))
	check("v1.0.17: the pursuing officer's brain is on (active) after a pound escape", bool(pworker.get("active")))
	main.call("_process", 30.1) # drain his pursuit
	check("pound van: pursuit over -> he heads back to the van", str(main.get("pound_state")) == "return", str(main.get("pound_state")))
	(player as Node3D).global_position = Vector3(-100, 0.2, 80) # the player runs off home-free; he just goes back to work
	guard_p = 0.0
	while str(main.get("pound_state")) != "patrol" and guard_p < 30.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("pound van: he gets back in and the patrol resumes", str(main.get("pound_state")) == "patrol" and not pworker.visible, str(main.get("pound_state")) + " after " + str(guard_p) + "s")
	# lose him WITHOUT a capture: a chase that fails sends him back too
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	main.set("pound_route_idx", 1)
	main.set("pound_state", "patrol")
	main.set("pound_engage_cd", 0.0)
	(player as Node3D).global_position = pvan.position + Vector3(11.0, 0.2, 0.0)
	player.set("velocity", Vector3.ZERO)
	guard_p = 0.0
	while str(pworker.get("mode")) != "chase" and guard_p < 12.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("pound van: next time round he gets out and chases again", str(pworker.get("mode")) == "chase", str(pworker.get("mode")) + " after " + str(guard_p) + "s")
	(player as Node3D).global_position = Vector3(-100, 0.2, 80) # the cat bolts far away: the chase is lost on distance
	guard_p = 0.0
	while str(main.get("pound_state")) != "patrol" and guard_p < 30.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("pound van: chase lost -> he walks back to the van and the patrol resumes", str(main.get("pound_state")) == "patrol" and not pworker.visible, str(main.get("pound_state")) + " after " + str(guard_p) + "s")
	# THE COLLAR FLAG: while the cat has a collar on, he never engages
	main.set("player_collared", true)
	main.set("pound_engage_cd", 0.0)
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	main.set("pound_route_idx", 1)
	main.set("pound_state", "patrol")
	(player as Node3D).global_position = pvan.position + Vector3(11.0, 0.2, 0.0)
	player.set("velocity", Vector3.ZERO)
	await wait_sec(3.0)
	check("pound van: with a collar on (flag set) he never engages — no pull-over, no chase", str(main.get("pound_state")) == "patrol" and not pworker.visible and str(pworker.get("mode")) == "wander", str(main.get("pound_state")) + "/" + str(pworker.get("mode")))
	main.set("player_collared", false)
	(player as Node3D).global_position = Vector3(-100, 0.2, 80) # leave him to his rounds

	# ---------- v1.0.21: the officer on FOOT notices too ----------
	# He is walking back to the van (state "return", brain off,
	# main driving) with the van parked well away down the road.
	# The cat steps into his view ahead of him: the meter must
	# build over HIS head (his own bar rig, mirrored by main), and
	# a full meter turns him around into the chase — the van never
	# moves.
	pvan.position = Vector3(-60, 0, 16.8)
	main.set("pound_van_yaw", 0.0)
	main.set("pound_van_speed", 0.0)
	pworker.set("active", false)
	pworker.visible = true
	pworker.set("notice_cooldown", 0.0)
	pworker.set("notice", 0.0)
	(pworker as Node3D).global_position = Vector3(-30, 0.2, 16.8)
	main.set("pound_notice", 0.0)
	main.set("pound_engage_cd", 0.0)
	main.set("pound_state", "return")
	main.call("_pound_reset_return_watch")
	guard_p = 0.0
	var foot_notice_seen: float = 0.0
	var foot_bar_seen: bool = false
	while str(main.get("pound_state")) != "chase" and guard_p < 14.0:
		(player as Node3D).global_position = (pworker as Node3D).global_position + Vector3(-6.0, 0.0, 0.0) # stay 6m ahead of him, in plain view on the road
		player.set("velocity", Vector3.ZERO)
		await wait_sec(0.25)
		guard_p += 0.25
		foot_notice_seen = maxf(foot_notice_seen, float(main.get("pound_notice")))
		if (pworker.get("bar_root") as Node3D).visible:
			foot_bar_seen = true
	check("v1.0.21: proximity to the OFFICER on foot builds the notice meter", foot_notice_seen > 0.15, "peak notice=" + str(foot_notice_seen))
	check("v1.0.21: the meter shows over HIS head while he is on foot", foot_bar_seen)
	# He turns with the RUN tell first (that IS the grabber flow);
	# give the tell its beat and confirm the chase proper follows.
	var tell_guard: float = 0.0
	while str(pworker.get("mode")) != "chase" and tell_guard < 4.0:
		await wait_sec(0.25)
		tell_guard += 0.25
	check("v1.0.21: a full meter on foot turns him around — RUN tell, then the chase (van never involved)", str(main.get("pound_state")) == "chase" and str(pworker.get("mode")) == "chase", str(main.get("pound_state")) + "/" + str(pworker.get("mode")))
	(player as Node3D).global_position = Vector3(-100, 0.2, 80) # the cat bolts: the chase is lost on distance
	guard_p = 0.0
	while str(main.get("pound_state")) != "patrol" and guard_p < 30.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("v1.0.21: after the on-foot chase he walks back, gets in, patrol resumes", str(main.get("pound_state")) == "patrol" and not pworker.visible, str(main.get("pound_state")) + " after " + str(guard_p) + "s")

	# ---------- v1.0.21: the DEPOT cycle (the garage) ----------
	# After an encounter he drives home: stage the van on the
	# final westbound leg with heading_home set (the flag the
	# get-in sets), the cat far away, engagement held off — the
	# van must turn in, park INSIDE the bay, dwell, reverse out
	# and resume patrol on the road.
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_heading_home", true)
	pvan.position = Vector3(-71.8, 0, 16.8)
	main.set("pound_van_yaw", PI)
	main.set("pound_route_idx", 0)
	main.set("pound_van_speed", 0.0)
	main.set("pound_state", "patrol")
	(player as Node3D).global_position = Vector3(-100, 0.2, 80)
	guard_p = 0.0
	while str(main.get("pound_state")) != "depot" and guard_p < 45.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("v1.0.21: heading home, the van drives into the GARAGE and stops inside", str(main.get("pound_state")) == "depot", str(main.get("pound_state")) + " after " + str(guard_p) + "s at " + str(pvan.position))
	check("v1.0.21: parked at the depot home spot, inside the bay walls", pvan.position.distance_to(Vector3(-112, 0, -1.9)) < 1.5 and pvan.position.x > -114.6 and pvan.position.x < -109.4 and pvan.position.z > -5.4 and pvan.position.z < 1.6, str(pvan.position))
	check("v1.0.22: parked in the bay NOSE-in (facing north, into the garage — he reverses OUT, not in)", (main.call("_car_nose_dir", pvan) as Vector3).dot(Vector3(0, 0, -1)) > 0.9, "nose=" + str(main.call("_car_nose_dir", pvan)))
	check("v1.0.21: parked still (no creeping in the bay)", float(main.get("pound_van_speed")) == 0.0, str(main.get("pound_van_speed")))
	guard_p = 0.0
	while str(main.get("pound_state")) != "patrol" and guard_p < 45.0:
		await wait_sec(0.25)
		guard_p += 0.25
	check("v1.0.21: after the dwell he reverses out and resumes patrol on the road", str(main.get("pound_state")) == "patrol" and pvan.position.z > 10.0, str(main.get("pound_state")) + " at " + str(pvan.position) + " after " + str(guard_p) + "s")
	main.set("pound_engage_cd", 0.0)
	main.set("pound_heading_home", false)

	# ---------- v1.0.22: the new cast, town cats, intake card, panel ----------
	var type_seen: Dictionary = {}
	var npcs_all_meshy := true
	for n in main.get("npcs"):
		type_seen[str(n.get("npc_type"))] = true
		if _subtree_vehicle_path(n) == "":
			npcs_all_meshy = false
	check("v1.0.22 cast: every street inhabitant renders a Meshy model (no code-built people left)", npcs_all_meshy)
	var new_types_ok := true
	for t in ["mailcarrier", "gardener", "skateboarder", "baker", "construction", "coffeeowner", "jogger", "musician"]:
		if not type_seen.has(t):
			new_types_ok = false
	check("v1.0.22 cast: all 8 new Meshy townsfolk types are in town", new_types_ok, str(type_seen.keys()))
	check("v1.0.22 cast: the pound worker is Meshy too", _subtree_vehicle_path(main.get("pound_worker")) == "res://assets/models/officer.glb", _subtree_vehicle_path(main.get("pound_worker")))
	var tcats: Array = main.get("town_cats")
	var cats_ok: bool = tcats.size() == 8
	var cat_paths: Dictionary = {}
	for c in tcats:
		var cp: String = _subtree_vehicle_path(c)
		if cp == "":
			cats_ok = false
		cat_paths[cp] = true
		if (c.get("_legs") as Array).size() != 4:
			cats_ok = false
	check("v1.0.22 town cats: 8 Meshy cats wander, each with 4 classified legs for the trot", cats_ok, str(cat_paths.keys()))
	check("v1.0.22 town cats: 8 distinct cat models", cat_paths.size() == 8, str(cat_paths.size()))
	var card_label: Label3D = main.get_node_or_null("EscapeRoom/IntakeCardText") as Label3D
	check("v1.0.22 intake card: a card hangs on Zander's cage front in the ward", card_label != null)
	check("v1.0.22 intake card: street lookup names the road a spot is on", str(main.call("street_name_at", Vector3(0, 0, -11))) == "Maple Street" and str(main.call("street_name_at", Vector3(-70, 0, 20))) == "Pine Street", str(main.call("street_name_at", Vector3(0, 0, -11))) + "/" + str(main.call("street_name_at", Vector3(-70, 0, 20))))
	main.set("pickup_street", "Maple Street")
	main.call("_refresh_intake_card")
	check("v1.0.22 intake card: the card names the street he was picked up on", card_label != null and "Maple Street" in card_label.text, card_label.text if card_label != null else "none")
	var panel: Control = main.get("escape_panel")
	var panel_ab := false
	for ch in panel.get_children():
		if ch is Button and ((ch as Button).text == "A" or (ch as Button).text == "B"):
			panel_ab = true
	check("v1.0.22 panel: NO duplicate A/B buttons on the escape panel (combo rides the game's own buttons)", not panel_ab)
	var hop_b: Button = main.get("hop_btn")
	var paw_b: Button = main.get("paw_btn")
	check("v1.0.22 buttons: B (PAW) sits LEFT of A (HOP) in the cluster, as it was", paw_b.get_global_rect().position.x < hop_b.get_global_rect().position.x, str(paw_b.get_global_rect().position) + " vs " + str(hop_b.get_global_rect().position))
	check("v1.0.22 buttons: no focus square — every touch button is FOCUS_NONE", hop_b.focus_mode == Control.FOCUS_NONE and paw_b.focus_mode == Control.FOCUS_NONE and (main.get("meow_btn") as Button).focus_mode == Control.FOCUS_NONE and (main.get("run_btn") as Button).focus_mode == Control.FOCUS_NONE)

	# ---------- v1.0.23: house-parts audit (nothing detached/floating) ----------
	# Michael's v1.0.21 screenshot showed what looked like a house
	# with its porch/stairs broken apart. The audit below is the
	# standing proof for EVERY house: each part's centre stays
	# inside the lot envelope, and each part is either grounded
	# (bottom near the lawn) or physically touching another part
	# (roof on walls, porch roof on posts, bay on the wall...).
	var world_node: Node = main.get_node("World")
	var v23_audit_houses := 0
	var v23_audit_parts := 0
	var v23_audit_bad: Array = []
	for h in main.get("houses"):
		var hpos: Vector3 = h["pos"]
		var grp: Node3D = null
		var v23_grp_meshes := -1
		for ch in world_node.get_children():
			if ch is Node3D and not (ch is MultiMeshInstance3D) and (ch as Node3D).position.distance_to(hpos) < 0.6:
				var cnt := count_meshes(ch)
				if cnt > v23_grp_meshes:
					v23_grp_meshes = cnt
					grp = ch as Node3D
		if grp == null or v23_grp_meshes < 20:
			v23_audit_bad.append(str(h["address"]) + ": group not found")
			continue
		v23_audit_houses += 1
		var boxes: Array = []
		var stack2: Array = [grp]
		while not stack2.is_empty():
			var cur2: Node = stack2.pop_back()
			for ch2 in cur2.get_children():
				stack2.append(ch2)
			if cur2 is MeshInstance3D:
				boxes.append((cur2 as MeshInstance3D).global_transform * (cur2 as MeshInstance3D).get_aabb())
		for bi in range(boxes.size()):
			var ab: AABB = boxes[bi]
			v23_audit_parts += 1
			var ctr: Vector3 = ab.get_center()
			if absf(ctr.x - hpos.x) > 8.2 or absf(ctr.z - hpos.z) > 8.2:
				v23_audit_bad.append(str(h["address"]) + ": part outside lot at " + str(ctr))
				continue
			if ab.position.y <= 0.42:
				continue # grounded
			var supported := false
			for bj in range(boxes.size()):
				if bj != bi and ab.grow(0.28).intersects(boxes[bj]):
					supported = true
					break
			if not supported:
				v23_audit_bad.append(str(h["address"]) + ": floating part at " + str(ctr) + " size " + str(ab.size))
	check("v1.0.23 house audit: every house group found and audited", v23_audit_houses == (main.get("houses") as Array).size(), str(v23_audit_houses))
	check("v1.0.23 house audit: NO detached or floating house parts in town", v23_audit_bad.is_empty(), str(v23_audit_bad.slice(0, 4)))
	check("v1.0.23 house audit: the audit covered the whole town's parts", v23_audit_parts > 1500, str(v23_audit_parts))

	# ---------- v1.0.23: grass blades are cones, not backface quads ----------
	# The black spikes were the blade quads' back faces (flipped
	# normals under the dusk sky). The blade mesh is now a cone
	# with outward normals — assert no blade-cell mesh is the old
	# all-normals-up quad (every normal at |y| ~ 1).
	var blade_normals_ok := false
	var blade_cells := 0
	for ch in world_node.get_children():
		if ch is MultiMeshInstance3D:
			var mmi := ch as MultiMeshInstance3D
			if mmi.multimesh != null and mmi.multimesh.instance_count > 100 and mmi.multimesh.mesh is ArrayMesh:
				blade_cells += 1
				var arrs: Array = (mmi.multimesh.mesh as ArrayMesh).surface_get_arrays(0)
				var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
				var has_outward := false
				for nv in ns:
					if absf(nv.y) < 0.9:
						has_outward = true
						break
				if has_outward:
					blade_normals_ok = true
	check("v1.0.23 blades: blade cells exist and use outward-normal cone geometry (no black-spike quads)", blade_cells > 0 and blade_normals_ok, "cells=" + str(blade_cells))

	# ---------- v1.0.23: the park + Meshy playground + kids playing ----------
	var v23_pgm: Node3D = main.get("playground_model")
	check("v1.0.23 park: the Meshy playground structure is in the world", v23_pgm != null and v23_pgm.scene_file_path == "res://assets/models/playground.glb", v23_pgm.scene_file_path if v23_pgm != null else "none")
	var pg_aabb := AABB()
	var pg_first := true
	if v23_pgm != null:
		var pstack: Array = [v23_pgm]
		while not pstack.is_empty():
			var pc: Node = pstack.pop_back()
			for pch in pc.get_children():
				pstack.append(pch)
			if pc is MeshInstance3D:
				var pab: AABB = (pc as MeshInstance3D).global_transform * (pc as MeshInstance3D).get_aabb()
				if pg_first:
					pg_aabb = pab
					pg_first = false
				else:
					pg_aabb = pg_aabb.merge(pab)
	check("v1.0.23 park: the playground sits ON the ground (base within 15cm)", v23_pgm != null and pg_aabb.position.y > -0.05 and pg_aabb.position.y < 0.15, "base y=" + str(pg_aabb.position.y))
	check("v1.0.23 park: the playground is kid-scale (2.2-3.2m tall, 4-6m wide)", v23_pgm != null and pg_aabb.size.y > 2.2 and pg_aabb.size.y < 3.2 and pg_aabb.size.x > 4.0 and pg_aabb.size.x < 6.0, "size=" + str(pg_aabb.size))
	var pq := PhysicsPointQueryParameters3D.new()
	pq.position = Vector3(86, 1.0, 30)
	var v23_phit: Array = main.get_world_3d().direct_space_state.intersect_point(pq)
	check("v1.0.23 park: the playground is SOLID to walk into (collision at its centre)", not v23_phit.is_empty() and v23_pgm != null and (v23_phit[0]["collider"] as Node).get_parent() == v23_pgm.get_parent())
	# The old code-built equipment is gone: nothing may sit at the
	# old slide chute / seesaw / swing bar / climbing frame spots.
	var old_spots: Array = [Vector3(103.8, 1.05, 33.9), Vector3(104, 0.85, 26.5), Vector3(92.5, 2.25, 23.5), Vector3(102, 2.35, 24.5)]
	var old_left := 0
	var ostack: Array = [world_node]
	while not ostack.is_empty():
		var oc: Node = ostack.pop_back()
		for och in oc.get_children():
			ostack.append(och)
		if oc is MeshInstance3D:
			var oab: AABB = (oc as MeshInstance3D).global_transform * (oc as MeshInstance3D).get_aabb()
			var oc2: Vector3 = oab.get_center()
			for os in old_spots:
				if oc2.distance_to(os) < 0.75:
					old_left += 1
	check("v1.0.23 park: the OLD playground equipment is fully removed", old_left == 0, "left=" + str(old_left))
	# Park v23_dwellers: the kids at the park spend their time there.
	var v23_dwellers: Array = []
	for n in main.get("npcs"):
		if bool(n.get("park_dweller")):
			v23_dwellers.append(n)
	check("v1.0.23 park: at least 3 park dwellers (2 kids + the skateboarder)", v23_dwellers.size() >= 3, str(v23_dwellers.size()))
	var v23_dwell_ok := v23_dwellers.size() > 0
	for n in v23_dwellers:
		if (n.get("park_spots") as Array).size() < 5:
			v23_dwell_ok = false
	check("v1.0.23 park: every dweller has the park's play spots", v23_dwell_ok)
	if v23_dwellers.size() > 0:
		seed(7)
		var d0: Node = v23_dwellers[0]
		var v23_spots0: Array = d0.get("park_spots")
		var hits := 0
		var v23_long_wait := false
		for k in range(20):
			d0.call("_pick_wander_target")
			if v23_spots0.has(d0.get("wander_target")):
				hits += 1
				if float(d0.get("wander_wait")) >= 4.0:
					v23_long_wait = true
		check("v1.0.23 park: a dweller's wander picks are mostly play spots (playing, not street-wandering)", hits >= 12, "hits=" + str(hits) + "/20")
		check("v1.0.23 park: a dweller LINGERS at a play spot (wait >= 4s)", v23_long_wait)

	# ---------- v1.0.23: title panel restyle ----------
	var v23_tpanel: Control = main.get("title_panel")
	var v23_tp_sb: StyleBox = v23_tpanel.get_theme_stylebox("panel") if v23_tpanel != null else null
	check("v1.0.23 title: the panel is frosted glass (translucent, strongly rounded)", v23_tp_sb is StyleBoxFlat and (v23_tp_sb as StyleBoxFlat).bg_color.a < 0.85 and (v23_tp_sb as StyleBoxFlat).corner_radius_top_left >= 30, str((v23_tp_sb as StyleBoxFlat).bg_color) if v23_tp_sb is StyleBoxFlat else "no stylebox")
	var v23_tex_paths: Array = []
	var v23_start_ok := false
	var v23_ver_ok := false
	var v23_addr_leak := false
	if v23_tpanel != null:
		var tstack: Array = [v23_tpanel]
		while not tstack.is_empty():
			var tc: Node = tstack.pop_back()
			for tch in tc.get_children():
				tstack.append(tch)
			if tc is TextureRect and (tc as TextureRect).texture != null:
				v23_tex_paths.append((tc as TextureRect).texture.resource_path)
			if tc is Button and (tc as Button).text.contains("START"):
				# v1.0.23: the pill is a layered TextureRect under an
				# invisible button (a StyleBoxTexture's margins would
				# inflate the button); the texture path scan below
				# covers it — here just confirm the button exists.
				v23_start_ok = true
			if tc is Label:
				var lt: String = (tc as Label).text
				if lt == "v1.0.24":
					v23_ver_ok = true
				if lt.contains("Crescent") or lt.contains("Avenue") or lt.contains("Street") or lt.contains("Drive"):
					v23_addr_leak = true
	var v23_has_tag := false
	var v23_has_medallion := false
	var v23_has_art := false
	var v23_paw_count := 0
	for p in v23_tex_paths:
		var ps: String = str(p)
		if ps.ends_with("collar_tag.png"):
			v23_has_tag = true
		if ps.ends_with("paw_medallion.png"):
			v23_has_medallion = true
		if ps.ends_with("title_art.png"):
			v23_has_art = true
		if ps.ends_with("paw_print.png"):
			v23_paw_count += 1
	check("v1.0.23 title: the collar tag is GONE, replaced by the paw medallion", not v23_has_tag and v23_has_medallion, str(v23_tex_paths))
	check("v1.0.23 title: the art is in its rounded frame and paw prints flank the title", v23_has_art and v23_paw_count >= 2, str(v23_tex_paths))
	var v23_has_pill := false
	for p in v23_tex_paths:
		if str(p).ends_with("start_btn.png"):
			v23_has_pill = true
	check("v1.0.23 title: START wears the gradient pill", v23_start_ok and v23_has_pill, str(v23_tex_paths))
	check("v1.0.23 title: version tag reads v1.0.24 and NO address is shown", v23_ver_ok and not v23_addr_leak)

	# ---------- v1.0.24: ONE TAP = ONE COMBO STEP (Michael's v1.0.22 play report) ----------
	# "I hit B once and multiple Bs were hit… then when I hit A it
	# wouldn't work." Diagnosis: with the panel open, main's _input
	# claimed the press from BOTH event generations — the raw
	# InputEventScreenTouch AND the InputEventMouseButton the engine
	# synthesizes from the same tap (emulate_mouse_from_touch) — each
	# as its own _input call, with NO dedupe on that path, so one tap
	# registered two steps. The v1.0.21-era suite missed it because
	# it called escape_panel_input directly. THIS section drives the
	# real event sequence through _input: touch press, emulated
	# mouse press (twice, paranoid), a second finger on the same
	# button while the first is held, then the releases — and asserts
	# exactly one step per tap. (The HUD Buttons' pressed signals are
	# not part of the sequence with the panel open: the panel is a
	# full-screen MOUSE_FILTER_STOP Control that accepts every GUI
	# event, so they never fire — verified by the diagnosis read of
	# escape_panel._gui_input.)
	# Closed path first (state: play): the same double path exists
	# there (raw claim + the Button's pressed echo, delivered on
	# release). v1.0.24's latch is state-based: even a SLOW tap's
	# echo stands down (the old 150 ms timer let it through).
	park_npcs_far()
	(player as Node3D).global_position = Vector3(110, 0.2, 84)
	await wait_sec(0.2)
	var paw_pos24: Vector2 = (main.get("paw_btn") as Button).get_global_rect().get_center()
	player.set("paw_t", 0.0)
	var tp24 := InputEventScreenTouch.new()
	tp24.index = 7
	tp24.pressed = true
	tp24.position = paw_pos24
	main.call("_input", tp24)
	check("v1.0.24 closed path: a raw tap on PAW fires the swipe at once", float(player.get("paw_t")) > 0.0, str(player.get("paw_t")))
	check("v1.0.24 closed path: the tap latches PAW for its Button echo", bool((main.get("_action_echo_latch") as Dictionary).get("paw", false)))
	await wait_sec(0.35) # a SLOW tap: the old 150 ms timer would have expired by now
	player.set("paw_t", 0.0)
	(main.get("paw_btn") as Button).pressed.emit()
	check("v1.0.24 closed path: the Button echo of the same tap stands down (no second swipe), however slow the tap", float(player.get("paw_t")) == 0.0, str(player.get("paw_t")))
	player.set("paw_t", 0.0)
	(main.get("paw_btn") as Button).pressed.emit()
	check("v1.0.24 closed path: a press with no raw claim behind it (a genuine click) still fires", float(player.get("paw_t")) > 0.0, str(player.get("paw_t")))
	# Panel path: enter the house escape and open the bolt panel.
	main.set("captor", woman)
	main.call("_enter_escape")
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	main.call("_on_escape_prompt_pressed")
	check("v1.0.24 panel: the escape panel is open (setup)", bool((main.get("escape_panel") as Control).visible))
	main.set("escape_combo", ["B", "B", "A", "B", "A"]) # a known roll: repeats up front, like Michael's B B B A
	(main.get("escape_panel") as Control).call("set_combo_seq", ["B", "B", "A", "B", "A"])
	main.set("combo_index", 0)
	var hop_pos24: Vector2 = (main.get("hop_btn") as Button).get_global_rect().get_center()
	var mk_touch24 := func(idx: int, pr: bool, pos: Vector2) -> InputEventScreenTouch:
		var e := InputEventScreenTouch.new()
		e.index = idx
		e.pressed = pr
		e.position = pos
		return e
	var mk_mouse24 := func(pr: bool, pos: Vector2) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pr
		e.position = pos
		return e
	# TAP 1 on B — the full event storm of one physical tap.
	main.call("_input", mk_touch24.call(7, true, paw_pos24))
	check("v1.0.24 panel: tap 1 (B) — the raw touch registers step 1", int(main.get("combo_index")) == 1, str(main.get("combo_index")))
	main.call("_input", mk_mouse24.call(true, paw_pos24))
	check("v1.0.24 panel: tap 1 — the emulated-mouse echo registers NOTHING (was: a second step)", int(main.get("combo_index")) == 1, str(main.get("combo_index")))
	main.call("_input", mk_mouse24.call(true, paw_pos24))
	main.call("_input", mk_touch24.call(8, true, paw_pos24))
	check("v1.0.24 panel: tap 1 — a repeated echo and a second finger on the held button still register nothing", int(main.get("combo_index")) == 1, str(main.get("combo_index")))
	main.call("_input", mk_touch24.call(8, false, paw_pos24))
	main.call("_input", mk_touch24.call(7, false, paw_pos24))
	main.call("_input", mk_mouse24.call(false, paw_pos24))
	check("v1.0.24 panel: tap 1 — the releases register nothing and re-arm the button", int(main.get("combo_index")) == 1 and (main.get("_panel_press_owner") as Dictionary).is_empty(), str(main.get("combo_index")) + " " + str(main.get("_panel_press_owner")))
	# TAP 2 on B (after a real release, the next step must register).
	main.call("_input", mk_touch24.call(7, true, paw_pos24))
	main.call("_input", mk_mouse24.call(true, paw_pos24))
	main.call("_input", mk_touch24.call(7, false, paw_pos24))
	main.call("_input", mk_mouse24.call(false, paw_pos24))
	check("v1.0.24 panel: tap 2 (B) registers step 2 — exactly one step per tap", int(main.get("combo_index")) == 2, str(main.get("combo_index")))
	# TAP 3 on A.
	main.call("_input", mk_touch24.call(7, true, hop_pos24))
	main.call("_input", mk_mouse24.call(true, hop_pos24))
	main.call("_input", mk_touch24.call(7, false, hop_pos24))
	main.call("_input", mk_mouse24.call(false, hop_pos24))
	check("v1.0.24 panel: tap 3 (A) registers step 3", int(main.get("combo_index")) == 3, str(main.get("combo_index")))
	# STEP 4 by keyboard: a held key's ECHO must not register; the
	# real press must (E = B, the combo's fourth step).
	var ke_echo := InputEventKey.new()
	ke_echo.keycode = KEY_E
	ke_echo.pressed = true
	ke_echo.echo = true
	main.call("_unhandled_input", ke_echo)
	check("v1.0.24 panel: a key-echo (held-key repeat) registers nothing", int(main.get("combo_index")) == 3, str(main.get("combo_index")))
	var ke_real := InputEventKey.new()
	ke_real.keycode = KEY_E
	ke_real.pressed = true
	ke_real.echo = false
	main.call("_unhandled_input", ke_real)
	check("v1.0.24 panel: one real E press registers step 4 (B)", int(main.get("combo_index")) == 4, str(main.get("combo_index")))
	# TAP 5 on A completes the known combo.
	main.call("_input", mk_touch24.call(7, true, hop_pos24))
	main.call("_input", mk_mouse24.call(true, hop_pos24))
	check("v1.0.24 panel: the full known combo, tapped tap-by-tap with echoes, is ACCEPTED (door opens)", bool(main.get("exit_open")) and not bool((main.get("escape_panel") as Control).visible), "exit_open=" + str(main.get("exit_open")))
	main.call("_input", mk_touch24.call(7, false, hop_pos24))
	main.call("_input", mk_mouse24.call(false, hop_pos24))
	walk_cat_out()
	check("v1.0.24 panel: the escape still completes back into play", str(main.get("state")) == "play", str(main.get("state")))
	# Run the post-escape pursuit out (the v1.4 section's pattern)
	# so the idle-purr section below starts with no chase active.
	main.call("_process", 29.95)
	main.call("_process", 0.1)
	check("v1.0.24 panel: the post-escape pursuit is run out (cleanup for the next section)", not (main.get("pursuers") as Dictionary).has(woman), str(main.get("pursuers")))

	# ---------- idle purr retained (v0.6) ----------
	park_npcs_far()
	(player as Node3D).global_position = Vector3(110, 0.2, 84)
	await wait_sec(3.6)
	check("idle purr starts after ~3s still", bool(main.get("purr_active")))

	print("TESTS: %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)
