extends Node
## HOMEWARD island proof screenshots + shore-clamp probe.
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerIsland.tscn
##   island_east   from the east border looking out: apron, beach, sea
##   island_south  over the south pines: beach + sea past the forest
##   island_west   over the west rooftops: sea beyond the city edge
##   island_bay    low and close at the west bay: the wandering
##                 waterline, wet-sand band and shallows up close
##   town_inside   an ordinary street view — the town is unchanged
## Plus ISLANDPROBE lines: a cat-sized sphere swept from the beach
## toward the sea at four points of the compass — east (a POINT,
## the widest beach), west (a BAY, the narrowest), north, south.
## The expected waterline is measured from the game's own
## island_waterline_pts polyline; the sphere's face must stop
## ~2 m short of it (PASS band: gap 1.2..3.2 m).
## Output: ~/workspace/homeward/screenshots_island/

const OUT := "/home/hatch/workspace/homeward/screenshots_island"
var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap_with_cam(name: String, pos: Vector3, target: Vector3) -> void:
	main.set_process(false)
	await get_tree().process_frame
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())
	main.set_process(true)

func ray_waterline_dist(origin: Vector2, dir: Vector2, pts: Array) -> float:
	# Nearest positive distance from origin along dir to the
	# closed waterline polyline, or -1 if the ray never meets it.
	var best: float = -1.0
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var e: Vector2 = b - a
		var den: float = dir.x * e.y - dir.y * e.x
		if absf(den) < 1e-9:
			continue
		var ao: Vector2 = a - origin
		var t: float = (ao.x * e.y - ao.y * e.x) / den
		var u: float = (ao.x * dir.y - ao.y * dir.x) / den
		if t > 0.0 and u >= 0.0 and u <= 1.0 and (best < 0.0 or t < best):
			best = t
	return best

func probe_shore(space: PhysicsDirectSpaceState3D, label: String, origin: Vector3, dir: Vector3, pts: Array) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.transform = Transform3D(Basis(), origin)
	q.motion = dir * 40.0
	var res: PackedFloat32Array = space.cast_motion(q)
	var travel: float = 40.0 * res[0] if res.size() > 0 else -1.0
	var wl: float = ray_waterline_dist(Vector2(origin.x, origin.z), Vector2(dir.x, dir.z), pts)
	var gap: float = wl - (travel + 0.35) if travel >= 0.0 and wl > 0.0 else -999.0
	var ok: bool = gap >= 1.2 and gap <= 3.2
	print("ISLANDPROBE ", label, ": travel=", snappedf(travel, 0.01), " waterline_dist=", snappedf(wl, 0.01), " face_gap=", snappedf(gap, 0.01), " ", "PASS" if ok else "FAIL")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var _bw: int = 0
	while not bool(main.get("build_complete")) and _bw < 21600:
		await get_tree().process_frame
		_bw += 1
	await wait_sec(0.5)
	player = main.get("player")
	cam = main.get("cam")
	var world: Node = main.get_node_or_null("World")
	for nm in ["IslandTop", "IslandBeach", "IslandWater", "IslandShore"]:
		var nd: Node = world.get_node_or_null(nm) if world else null
		print("ISLANDNODE: ", nm, " present=", nd != null)
	# ---- shore clamp probe: swept cat-sized sphere ---------------
	var wl_pts: Array = main.get("island_waterline_pts")
	print("ISLANDPROBE: waterline points=", wl_pts.size())
	var space := (player as Node3D).get_world_3d().direct_space_state
	probe_shore(space, "east-point", Vector3(158, 0.36, 0), Vector3(1, 0, 0), wl_pts)
	probe_shore(space, "west-bay", Vector3(-158, 0.36, 0), Vector3(-1, 0, 0), wl_pts)
	probe_shore(space, "north", Vector3(0, 0.36, 128), Vector3(0, 0, 1), wl_pts)
	probe_shore(space, "south", Vector3(0, 0.36, -128), Vector3(0, 0, -1), wl_pts)
	# ---- frames ----------------------------------------------------
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	await snap_with_cam("island_east.png", Vector3(124, 4.2, 0), Vector3(195, -1.0, 0))
	await snap_with_cam("island_south.png", Vector3(0, 10.0, 104), Vector3(0, -1.5, 190))
	await snap_with_cam("island_west.png", Vector3(-124, 15.0, 0), Vector3(-200, -1.0, 0))
	await snap_with_cam("island_bay.png", Vector3(-146, 1.8, 10), Vector3(-166, -0.7, -4))
	await snap_with_cam("town_inside.png", Vector3(46, 1.7, 16), Vector3(28, 1.2, -20))
	print("DONE")
	get_tree().quit(0)
