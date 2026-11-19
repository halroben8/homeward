extends Node
## HOMEWARD streets audit probe (kept, like PerfProbe/ScaleProbe).
## Run: godot --headless --path . tests/StreetsProbe.tscn
## Boots the real Main scene and audits EVERY static (non-traffic)
## car in the town: world XZ AABB vs the asphalt rectangles, mesh /
## cylinder counts (a "box car" would have ~1 mesh and 0 wheels).
## Prints one line per car plus a summary the step report can quote.

const ROAD_ZS: Array = [-55.0, -11.0, 15.0, 55.0]
const ROAD_XS: Array = [-70.0, -20.0, 24.0, 72.0, 128.0, 176.0, 224.0, 272.0, 320.0] # MAP DOUBLING: + the five east cross streets
const ASPHALT_HALF := 3.6 # asphalt is 7.2 wide (sidewalk band is 9.6)

var main: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func car_xz_rect(car: Node3D) -> Rect2:
	var acc := Rect2()
	var first := true
	var stack: Array = [car]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D:
			var a: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			var r := Rect2(a.position.x, a.position.z, a.size.x, a.size.z)
			if first:
				acc = r
				first = false
			else:
				acc = acc.merge(r)
	return acc

func count_parts(car: Node3D) -> Array:
	var meshes := 0
	var cyls := 0
	var stack: Array = [car]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D:
			meshes += 1
			if (n as MeshInstance3D).mesh is CylinderMesh:
				cyls += 1
	return [meshes, cyls]

func on_asphalt(r: Rect2) -> String:
	for rz in ROAD_ZS:
		if r.intersects(Rect2(-126.0, rz - ASPHALT_HALF, 504.0, ASPHALT_HALF * 2.0)):
			return "z-road %s" % str(rz)
	for rx in ROAD_XS:
		if r.intersects(Rect2(rx - ASPHALT_HALF, -96.0, ASPHALT_HALF * 2.0, 192.0)):
			return "x-road %s" % str(rx)
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
	# Static cars are identified STRUCTURALLY: _build_car names every
	# car root "Car", but Godot renames duplicates on add_child
	# (@Node3D@N), so only the first keeps the name. The reliable
	# marker is the "hide ⛺" Label3D that only static (non-traffic)
	# cars carry. Traffic cars live under traffic_group, label-free.
	var statics: Array = []
	for ch in main.get_node("World").get_children():
		if not (ch is Node3D):
			continue
		for sub in ch.get_children():
			if sub is Label3D and (sub as Label3D).text.contains("hide"):
				statics.append(ch)
	var on_road := 0
	var boxy := 0
	print("STATIC CARS: ", statics.size())
	for c in statics:
		var cd := c as Node3D
		var r := car_xz_rect(cd)
		var parts := count_parts(cd)
		var road := on_asphalt(r)
		if road != "":
			on_road += 1
		if int(parts[0]) < 20 or int(parts[1]) < 8:
			boxy += 1
		print("CAR pos=", cd.global_position, " meshes=", parts[0], " cyls=", parts[1], " on_asphalt=", road if road != "" else "no")
	print("SUMMARY: static=", statics.size(), " on_asphalt=", on_road, " boxy_lt20mesh_or_lt8cyl=", boxy)
	get_tree().quit(0)
