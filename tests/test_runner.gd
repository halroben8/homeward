extends Node
## HOMEWARD v0.9 automated test suite (v0.8 set + v0.9 sections).
## Run: godot --headless --path . tests/TestRunner.tscn
## Boots the real Main scene and exercises the v0.8 behaviours:
## houses clear of road corridors + numbers in order (items 1+2),
## paw swipe always resets (item 4), notice bar ONLY for the grabber
## + friendly bend-down pet/treat on paw/meow only (item 5), plus the
## retained v0.7 set: no minimap / no Sprint button, roles (v1.0: 6 of 22 seek the cat — 25% of everyone),
## flat sign text, camera far plane, joystick sprint + winded drop,
## collar camera zoom, single-mechanism escapes, exactly-60s
## pursuit, traffic, solid fences + open cat gaps, purr.

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
# down/up/down/up/PAW combo. v1.2: a finished combo OPENS the way
# (no scripted exit); the escape completes when the cat crosses the
# threshold, so the harness walks him out (walk_cat_out) — and the
# intended path now starts with a DISTRACTION (distract_captor):
# undistracted, she interrupts the panel in ~1.2 s of room time.
func drive_escape_panel() -> void:
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)

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
	check("PAW/HOP/MEOW/COLLAR buttons present", texts.any(func(t): return "PAW" in t) and texts.any(func(t): return "HOP" in t) and texts.any(func(t): return "MEOW" in t) and texts.any(func(t): return "COLLAR" in t), str(texts))
	# roles (item 14)
	var g: int = 0
	var f: int = 0
	var ig: int = 0
	for n in main.get("npcs"):
		match str(n.get("role")):
			"grabber": g += 1
			"friendly": f += 1
			"ignore": ig += 1
	check("roles: exactly 6 grabbers of 22 (25% of everyone, v1.0)", g == 6 and main.get("npcs").size() == 22, "g=%d total=%d" % [g, main.get("npcs").size()])
	check("roles: 8 friendly / 8 ignore", f == 8 and ig == 8, "f=%d ig=%d" % [f, ig])
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
	check("houses: 41 after the fill rows (v0.8 was 29)", (main.get("houses") as Array).size() == 41, str((main.get("houses") as Array).size()))
	# street signs: text flat ON the board (item 3)
	var sign_texts: Array = []
	for s in main.get("street_signs"):
		sign_texts.append(str(s["text"]))
	check("16 street signs registered (8 streets x 2)", sign_texts.size() == 16, str(sign_texts.size()))
	var labels: Array = []
	collect_label3d(main, labels)
	var sign_labels: Array = []
	var billboard_sign_labels: int = 0
	for l in labels:
		if sign_texts.has((l as Label3D).text):
			sign_labels.append(l)
			if (l as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
				billboard_sign_labels += 1
	check("sign text on both faces (32 flat labels)", sign_labels.size() == 32, str(sign_labels.size()))
	check("sign text is NOT billboard (readable only face-on)", billboard_sign_labels == 0, str(billboard_sign_labels))
	# scoreboard (item 9)
	check("scoreboard font is big (30)", int((main.get("score_label") as Label).label_settings.font_size) == 30)
	# splash / title anchoring (item 8)
	var sp: Control = main.get("splash_panel")
	check("splash panel full-rect anchors", sp.anchor_right == 1.0 and sp.anchor_bottom == 1.0, "%s/%s" % [sp.anchor_right, sp.anchor_bottom])
	var tp: Control = main.get("title_panel")
	check("title panel centred anchors", tp.anchor_left == 0.5 and tp.anchor_top == 0.5, "%s/%s" % [tp.anchor_left, tp.anchor_top])
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
	# escape variant pools: single-mechanism only (item 6)
	var families: Array = [["latch", "winpush"], ["petdoor"], ["bolt"], ["carrier"]]
	var pools_ok: bool = true
	var pool_detail: String = ""
	for ctype in ["woman", "kid", "dogwalker", "shopkeeper", "pedestrian"]:
		var pool: Array = main.call("_variant_pool", ctype)
		if pool.size() < 2:
			pools_ok = false
			pool_detail = ctype + " pool too small"
		for variant in pool:
			var fam_ok: bool = false
			for fam in families:
				var all_in: bool = true
				for kind in variant:
					if not fam.has(kind):
						all_in = false
				if all_in:
					fam_ok = true
			if not fam_ok:
				pools_ok = false
				pool_detail = ctype + " variant " + str(variant) + " mixes mechanisms"
	check("escapes: every variant is ONE mechanism (no book/vase/sofa chains)", pools_ok, pool_detail)

	# ---------- enter play ----------
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	check("game starts in play state", str(main.get("state")) == "play", str(main.get("state")))

	# ---------- houses: placement audit + numbering (v0.8 items 1+2) ----------
	var road_zs: Array = [-55.0, -11.0, 15.0, 55.0]
	var road_xs: Array = [-70.0, -20.0, 24.0, 72.0]
	var houses_arr: Array = main.get("houses")
	var aabb_ok: bool = true
	var vista_ok: bool = true
	for h in houses_arr:
		var hp: Vector3 = h["pos"]
		var face: float = float(h["facing"])
		var zmin: float = hp.z + minf(face * 5.2, -face * 3.9)
		var rect := Rect2(hp.x - 5.8, zmin, 11.6, 9.1) # footprint incl. fences/porch
		for rz in road_zs:
			if rect.intersects(Rect2(-200.0, rz - 4.35, 400.0, 8.7)): # road rect + 0.75 margin
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
	for gx in range(-114, 115, 11):
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
	# v0.9 REAL PETTING SEQUENCE: force the pet kind (the treat kind
	# is forced in the meow section below) and watch the whole act.
	friendly.set("interact_kind", "pet")
	check("pet sequence: starts on paw (approach)", str(friendly.get("interact_state")) == "approach", str(friendly.get("interact_state")))
	await wait_sec(0.4)
	check("pet sequence: NO points on the trigger itself", int(main.get("score")) == score_before_paw, str(main.get("score")))
	var seq_states: Array = []
	var min_hand: float = 999.0
	var max_bend: float = 0.0
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
	var grabber: Node = npc_by_role("grabber")
	(friendly as Node3D).global_position = (player as Node3D).global_position + Vector3(30, 0, 0) # move the friendly out of paw range first
	(grabber as Node3D).global_position = (player as Node3D).global_position + Vector3(-2.0, 0, 0)
	grabber.set("notice", 0.0)
	grabber.set("mode", "wander")
	main.call("_paw_action")
	check("paw near grabber: instant RUN tell", str(grabber.get("mode")) == "tell", str(grabber.get("mode")))
	grabber.call("_end_chase")
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

	# ---------- sprint: full push only + winded drop (item 2) ----------
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
	check("full push: sprinting", bool(player.get("is_sprinting")))
	check("full push: stamina draining", float(player.get("stamina")) < 99.0, str(player.get("stamina")))
	var sprint_speed: float = Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()
	check("sprint speed is near 11.5 (>> walk 5.6)", sprint_speed > 9.5, str(sprint_speed))
	player.set("stamina", 0.4) # nearly empty: winded drop must follow
	await wait_sec(0.4)
	check("empty pool: winded (sprint locked out)", bool(player.get("winded")))
	var winded_speed: float = Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()
	check("winded: speed visibly back at walk (<= 5.7)", winded_speed <= 5.7 and not bool(player.get("is_sprinting")), str(winded_speed))
	player.set("stamina", 60.0)
	await wait_sec(0.3)
	check("stamina recovered: sprint available again", bool(player.get("is_sprinting")))
	clear_joy()
	await wait_sec(0.3)

	# ---------- collar zoom (item 12) ----------
	check("no 2D collar panel any more", main.get("collar_panel") == null)
	main.call("_toggle_collar")
	check("collar opens while stopped", bool(main.get("collar_open")))
	await wait_sec(1.2)
	check("collar zoom eases in (zoom_t > 0.9)", float(main.get("collar_zoom_t")) > 0.9, str(main.get("collar_zoom_t")))
	var tag_pos: Vector3 = player.call("get_tag_global_pos")
	var cam_dist: float = (main.get("cam") as Camera3D).global_position.distance_to(tag_pos)
	check("camera is CLOSE to the real tag (< 1.9 units)", cam_dist < 1.9, str(cam_dist))
	var caption: Label3D = main.get("collar_caption")
	check("in-scene caption shows the home address", caption != null and caption.visible and str(main.get("home_address")) in caption.text, caption.text if caption else "none")
	main.set("collar_timer", 0.05)
	await wait_sec(0.3)
	check("collar auto-closes after a few seconds", not bool(main.get("collar_open")))
	await wait_sec(0.8)
	check("camera eases back out (zoom_t < 0.2)", float(main.get("collar_zoom_t")) < 0.2, str(main.get("collar_zoom_t")))
	# refused while moving
	set_joy(Vector2(0, -60))
	await wait_sec(0.4)
	main.call("_toggle_collar")
	check("collar refused while moving", not bool(main.get("collar_open")))
	clear_joy()
	await wait_sec(0.3)

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
	# -- FROZEN (collar view) --
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
		car.position.x = 126.0 * signf(car_vel.x) # just inside the edge it is driving TOWARD
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

	# ---------- escape: one mechanism + exactly 60s pursuit (items 6 + retained) ----------
	var woman: Node = null
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == "woman":
			woman = n
			break
	main.set("captor", woman)
	main.call("_enter_escape")
	check("escape state entered", str(main.get("state")) == "escape", str(main.get("state")))
	var kinds: Array = main.call("current_escape_kinds")
	var one_mech: bool = false
	for fam in families:
		var all_in: bool = true
		for kind in kinds:
			if not fam.has(kind):
				all_in = false
		if all_in:
			one_mech = true
	check("this capture's escape is a single mechanism", one_mech, str(kinds))
	# drive the WINDOW mechanism end-to-end regardless of the draw,
	# through the panel: prompt -> panel -> combo, twice (latch, then
	# the push). v1.2: the intended path starts with a DISTRACTION
	# (she is in the room now), and the finished combo OPENS the
	# window — the cat then walks out himself (walk_cat_out).
	main.set("escape_steps", [{"kind": "latch"}, {"kind": "winpush"}])
	main.set("escape_step", 0)
	main.set("escape_prog", 0.0)
	distract_captor()
	check("v1.2: toppling a prop distracts the captor", bool(main.call("captor_distracted")), str(main.get("captor_room_state")))
	(player as Node3D).global_position = Vector3(200, 0.3, -8)
	var score_before: int = int(main.get("score"))
	check("escape prompt is offered at the mechanism", bool(main.call("_escape_at_mechanism")))
	main.call("_on_escape_prompt_pressed")
	check("escape panel opens from the prompt", bool((main.get("escape_panel") as Control).visible))
	main.call("escape_panel_input", "down")
	main.call("escape_panel_input", "down") # wrong (up expected): the combo slips back, forgivingly keeping the leading down
	check("wrong swipe gently resets the combo", int(main.get("combo_index")) == 1, str(main.get("combo_index")))
	for inp in ["up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
	check("window latch worked via the panel combo", int(main.get("escape_step")) == 1, str(main.get("escape_step")))
	drive_escape_panel()
	check("v1.2: a finished combo OPENS the way (no teleport out)", bool(main.get("exit_open")) and str(main.get("state")) == "escape", str(main.get("state")))
	walk_cat_out()
	check("escape completes back into play", str(main.get("state")) == "play", str(main.get("state")))
	check("escape bonus +3", int(main.get("score")) == score_before + 3, "%d -> %d" % [score_before, int(main.get("score"))])
	var purs: Dictionary = main.get("pursuers")
	check("post-escape pursuit starts at exactly 60.0s", purs.has(woman) and float(purs[woman]) == 60.0, str(purs))
	main.call("_process", 59.95)
	check("pursuit still running at 59.95s", (main.get("pursuers") as Dictionary).has(woman))
	main.call("_process", 0.1)
	check("pursuit over at 60.0s (captor back to wander)", not (main.get("pursuers") as Dictionary).has(woman) and str(woman.get("mode")) == "wander", str(woman.get("mode")))

	# ---------- v1.2 DISTRACTIONS + PAW ACTIVATION (Michael's playtest fixes) ----------
	# The captor is in the room; PAW (not a prompt tap) opens the
	# panel from a generous radius; undistracted she interrupts fast;
	# distracted, a slow combo still works.
	main.set("captor", woman)
	main.call("_enter_escape")
	check("v1.2: the captor is in the room with the cat", (woman as Node3D).global_position.distance_to(main.get("escape_origin")) < 18.0, str((woman as Node3D).global_position))
	check("v1.2: three knock-over props in the room", (main.get("distract_props") as Array).size() == 3, str((main.get("distract_props") as Array).size()))
	main.set("escape_steps", [{"kind": "latch"}, {"kind": "winpush"}])
	main.set("escape_step", 0)
	main.set("escape_prog", 0.0)
	# PAW activation, player-style: the cat stands ~2.7 m from the
	# window exit point (NOT dead-centre of the old rect zone) and the
	# PAW button's own callback is what fires.
	(player as Node3D).global_position = Vector3(201.8, 0.3, -7.5)
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
	# The intended path: distract, then work the latch SLOWLY (room
	# time passing between inputs) — no interruption while she's busy.
	distract_captor()
	(player as Node3D).global_position = Vector3(200, 0.3, -8)
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)
		main.call("_process_escape", 0.4)
	check("v1.2: distracted, a slow combo still works the latch", int(main.get("escape_step")) == 1, str(main.get("escape_step")))
	(player as Node3D).global_position = Vector3(200, 0.3, -8) # the player pads back to the window after the shoo
	drive_escape_panel()
	check("v1.2: second combo opens the window", bool(main.get("exit_open")))
	walk_cat_out()
	check("v1.2: the cat walks out and the escape completes", str(main.get("state")) == "play", str(main.get("state")))
	main.call("_process", 60.1) # drain the pursuit before the e2e section

	# ---------- v0.9 CAPTURE END-TO-END (the grabber really takes him home) ----------
	# Michael reported an NPC who "couldn't take me home" — so drive
	# the REAL path, nothing mocked: paw provokes the tell, the chase
	# runs, the kid catches and HOLDS the cat, the cutscene fires,
	# the escape room opens, and the 60s pursuit follows the escape.
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
	main.set("escape_steps", [{"kind": "latch"}, {"kind": "winpush"}])
	main.set("escape_step", 0)
	main.set("escape_prog", 0.0)
	# v1.2 intended path: the captor is in the room — distract him
	# with a toppled prop first, then work the two combos, then the
	# cat walks out of the opened window himself.
	distract_captor()
	check("capture e2e: the captor is distracted by the toppled prop", bool(main.call("captor_distracted")), str(main.get("captor_room_state")))
	(player as Node3D).global_position = Vector3(200, 0.3, -8)
	drive_escape_panel()
	drive_escape_panel()
	check("capture e2e: the finished combo opens the way out", bool(main.get("exit_open")))
	walk_cat_out()
	check("capture e2e: escape returns to play, grabber pursuing", str(main.get("state")) == "play" and (main.get("pursuers") as Dictionary).has(cap_grabber), str(main.get("state")))
	main.call("_process", 60.1)
	check("capture e2e: pursuit ends at 60s", not (main.get("pursuers") as Dictionary).has(cap_grabber))

	# ---------- idle purr retained (v0.6) ----------
	park_npcs_far()
	(player as Node3D).global_position = Vector3(110, 0.2, 84)
	await wait_sec(3.6)
	check("idle purr starts after ~3s still", bool(main.get("purr_active")))

	print("TESTS: %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)
