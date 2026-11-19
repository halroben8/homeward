extends Node
## HOMEWARD street-clutter audit probe (kept, like StreetsProbe).
## Run: godot --headless --path . tests/ClutterProbe.tscn
## Boots the real Main scene and audits EVERY static town prop it
## can structurally identify against the asphalt rectangles:
## benches, fences (posts AND rails — a rail's AABB spans its whole
## run, so a run crossing a road is caught segment-wide), mailboxes,
## hedges, street signs, lamps, bins, flowerbeds and ground flowers,
## plus a catch-all for any other untextured, non-decal mesh.
## Mailboxes are also counted PER HOUSE (mailbox units inside each
## house's subtree) and strays outside any house are listed.
## Prints one line per offender plus per-category summaries.

const ROAD_ZS: Array = [-55.0, -11.0, 15.0, 55.0]
const ROAD_XS: Array = [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0] # MAP DOUBLING: + the five east cross streets
const ASPHALT_HALF := 3.6 # asphalt is 7.2 wide (sidewalk band is 9.6)

var main: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func xz_rect(mi: MeshInstance3D) -> Rect2:
	var a: AABB = mi.global_transform * mi.get_aabb()
	return Rect2(a.position.x, a.position.z, a.size.x, a.size.z)

func on_asphalt(r: Rect2) -> String:
	for rz in ROAD_ZS:
		if r.intersects(Rect2(-126.0, rz - ASPHALT_HALF, 504.0, ASPHALT_HALF * 2.0)):
			return "z-road %s" % str(rz)
	for rx in ROAD_XS:
		if r.intersects(Rect2(rx - ASPHALT_HALF, -96.0, ASPHALT_HALF * 2.0, 192.0)):
			return "x-road %s" % str(rx)
	return ""

func approx(a: float, b: float, tol: float = 0.06) -> bool:
	return absf(a - b) <= tol

func col_of(mi: MeshInstance3D) -> Color:
	var m := mi.material_override as StandardMaterial3D
	if m == null:
		return Color(-1, -1, -1)
	return m.albedo_color

func has_texture(mi: MeshInstance3D) -> bool:
	var m := mi.material_override as StandardMaterial3D
	return m != null and m.albedo_texture != null

func col_approx(c: Color, r: float, g: float, b: float, tol: float = 0.03) -> bool:
	return absf(c.r - r) <= tol and absf(c.g - g) <= tol and absf(c.b - b) <= tol

func ancestor_named(n: Node, nm: String) -> bool:
	var p: Node = n
	while p != null:
		if p.name == nm:
			return true
		p = p.get_parent()
	return false

func in_subtree_of(n: Node, root: Node) -> bool:
	var p: Node = n
	while p != null:
		if p == root:
			return true
		p = p.get_parent()
	return false

# Classify one mesh into a prop category ("" = not an audited prop).
func classify(mi: MeshInstance3D) -> String:
	if ancestor_named(mi, "Mailbox"):
		return "mailbox"
	var c: Color = col_of(mi)
	if mi.mesh is BoxMesh:
		var s: Vector3 = (mi.mesh as BoxMesh).size
		# street sign board (before fence: its slab matches post dims).
		# Boards overhang road corners at 3.75m like real signs — the
		# POLE is the audited part; boards are tracked separately.
		if approx(s.x, 5.4) and approx(s.y, 1.06) and approx(s.z, 0.14):
			return "sign_board"
		# mailbox boxes (pre-grouping builds)
		if approx(s.x, 0.7) and approx(s.y, 0.45) and approx(s.z, 0.5):
			return "mailbox"
		if approx(s.x, 0.6) and approx(s.y, 0.42) and approx(s.z, 0.22):
			return "mailbox"
		if approx(s.x, 0.42) and approx(s.y, 0.3) and approx(s.z, 0.3):
			return "mailbox"
		# bench seats: park/fill (2.2), house yard (1.7), bus stop (3.4)
		if approx(s.y, 0.12, 0.03) and approx(s.z, 0.55) and approx(s.x, 2.2):
			return "bench"
		if approx(s.y, 0.1, 0.03) and approx(s.z, 0.5) and (approx(s.x, 1.7) or approx(s.x, 3.4)):
			return "bench"
		# house front hedge
		if approx(s.x, 3.2) and approx(s.y, 0.7) and approx(s.z, 0.5):
			return "hedge"
		# flowerbed soil / garden plot (plain brown, low, wide)
		if col_approx(c, 0.4, 0.3, 0.2) and s.y <= 0.3 and s.x >= 3.0:
			return "flowerbed"
		# fence posts/pickets: upright, thin square section
		if s.y >= 0.85 and s.y <= 1.15 and minf(s.x, s.z) <= 0.2 and maxf(s.x, s.z) <= 0.35:
			return "fence"
		# fence rails: long, thin in both other dims
		if s.y <= 0.13 and minf(s.x, s.z) <= 0.13 and maxf(s.x, s.z) >= 1.9:
			return "fence"
		return ""
	if mi.mesh is CylinderMesh:
		var cm := mi.mesh as CylinderMesh
		if approx(cm.height, 4.4) and cm.bottom_radius <= 0.1:
			return "lamp"
		if approx(cm.height, 3.8) and cm.bottom_radius <=  0.1:
			return "sign"
		if approx(cm.height, 0.9) and approx(cm.top_radius, 0.26):
			return "bin"
		if cm.height >= 0.85 and cm.height <= 1.05 and cm.bottom_radius <= 0.055:
			return "mailbox" # mailbox post (pre-grouping builds)
		if col_approx(c, 0.4, 0.3, 0.2) and cm.height <= 0.32 and cm.bottom_radius >= 1.5:
			return "flowerbed" # round park bed
		return ""
	if mi.mesh is SphereMesh:
		var d: Vector3 = mi.scale # _sphere: diameter == scale
		if d.x <= 0.15 and mi.global_position.y >= 3.0:
			return "sign_board" # sign board bolt (overhangs with the board)
		if approx(d.x, 0.5) and col_approx(c, 1.0, 0.9, 0.6):
			return "lamp"
		if d.x <= 0.24 and mi.global_position.y <= 0.32:
			return "flower"
		return ""
	return ""

func _ready() -> void:
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
	await wait_sec(1.5)
	var world: Node = main.get_node("World")
	var houses_arr: Array = main.get("houses")
	# House groups: World children whose position matches a house pos.
	var house_groups: Dictionary = {} # group node -> address
	for ch in world.get_children():
		if ch is Node3D:
			for h in houses_arr:
				if (ch as Node3D).position.distance_to(h["pos"]) < 0.01:
					house_groups[ch] = str(h["address"])
	# Collect every MeshInstance3D under World except Traffic + cars.
	var meshes: Array = []
	var stack: Array = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == "Traffic":
			continue
		if n.name == "Car":
			continue
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D:
			meshes.append(n)
	var totals: Dictionary = {}
	var onroad: Dictionary = {}
	var other_offenders: Array = []
	for mi in meshes:
		# Border dressing (river/west fences, east construction, far
		# bank, south hedge) sits BEYOND the border fences where the
		# roads end — out of audit scope.
		var mp: Vector3 = (mi as MeshInstance3D).global_position
		if mp.x < -117.0 or mp.x > 369.0 or absf(mp.z) > 91.0: # MAP DOUBLING: east audit bound moved with the border
			continue
		var cat: String = classify(mi)
		var r: Rect2 = xz_rect(mi)
		var road: String = on_asphalt(r)
		if cat != "":
			totals[cat] = int(totals.get(cat, 0)) + 1
			if road != "":
				onroad[cat] = int(onroad.get(cat, 0)) + 1
				print("ONROAD [", cat, "] pos=", (mi as MeshInstance3D).global_position, " road=", road)
		else:
			# catch-all: untextured, non-decal (thicker than paint),
			# not part of a car/traffic (already skipped).
			if has_texture(mi):
				continue
			var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if a.size.y <= 0.06:
				continue # ground paint: dashes, crosswalks, pads
			if road != "":
				other_offenders.append(mi)
				print("ONROAD [other] pos=", (mi as MeshInstance3D).global_position, " aabb=", a, " road=", road)
	for cat in ["bench", "fence", "mailbox", "hedge", "sign", "sign_board", "lamp", "bin", "flowerbed", "flower"]:
		print("SUMMARY ", cat, ": total=", int(totals.get(cat, 0)), " on_asphalt=", int(onroad.get(cat, 0)))
	print("SUMMARY other: on_asphalt=", other_offenders.size())
	# ---- mailboxes per house ----
	var dist: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
	var total_units := 0
	for g in house_groups.keys():
		var units := 0
		var gstack: Array = [g]
		while not gstack.is_empty():
			var gn: Node = gstack.pop_back()
			for gch in gn.get_children():
				gstack.append(gch)
			if gn.name == "Mailbox" and gn.get_parent() != null and not ancestor_named(gn.get_parent(), "Mailbox"):
				units += 1 # grouped build: one named group == one mailbox
			elif gn is MeshInstance3D and classify(gn) == "mailbox" and (gn as MeshInstance3D).mesh is BoxMesh and not ancestor_named(gn, "Mailbox"):
				units += 1 # loose build: one box == one mailbox (not a grouped one's part)
		total_units += units
		var bucket: int = mini(units, 3)
		dist[bucket] = int(dist.get(bucket, 0)) + 1
		if units != 1:
			print("MAILBOX house '", house_groups[g], "' has ", units)
	print("MAILBOX per-house: houses=", house_groups.size(), " with0=", dist[0], " with1=", dist[1], " with2=", dist[2], " with3+=", dist[3], " total_units=", total_units)
	# stray mailbox units: mailbox meshes not inside any house group
	var strays := 0
	var stray_pos: Array = []
	for mi in meshes:
		if classify(mi) == "mailbox":
			var inside := false
			for g in house_groups.keys():
				if in_subtree_of(mi, g):
					inside = true
					break
			if not inside:
				strays += 1
				stray_pos.append((mi as MeshInstance3D).global_position)
	print("MAILBOX strays (meshes outside houses): ", strays, " at ", stray_pos.slice(0, 12))
	get_tree().quit(0)
