extends Node
## Diagnostic: why do the park/building solidity audits fail on
## this tree? Boots the real game, reports district band states
## and the park point-query from several player positions.
## Run: xvfb-run -a godot --path . tests/DistrictProbe.tscn

var main: Node = null
var player: Node3D = null

func bands_str() -> String:
	var out := ""
	for band in main.get("districts"):
		out += "[" + str(int(band["x0"])) + ".." + str(int(band["x1"])) + " on=" + str(bool(band["on"])) + "] "
	return out

func park_hit() -> String:
	var pq := PhysicsPointQueryParameters3D.new()
	pq.position = Vector3(86, 1.0, 30)
	var hit: Array = main.get_world_3d().direct_space_state.intersect_point(pq)
	if hit.is_empty():
		return "EMPTY"
	return "HIT " + str((hit[0]["collider"] as Node).get_parent().name)

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var guard: int = 0
	while not bool(main.get("build_complete")) and guard < 60 * 240:
		await get_tree().process_frame
		guard += 1
	player = main.get("player")
	print("DISTDUMP districts_built=", bool(main.get("districts_built")), " bands: ", bands_str())
	print("DISTDUMP at boot (player ", player.global_position, "): park=", park_hit())
	main.call("dismiss_splash")
	main.call("start_game")
	await get_tree().create_timer(1.0).timeout
	print("DISTDUMP after start (player ", player.global_position, "): park=", park_hit(), " bands: ", bands_str())
	# Stand at the park itself.
	player.global_position = Vector3(80, 0.3, 30)
	for i in range(6):
		main.call("_update_districts", 0.3)
		await get_tree().process_frame
	print("DISTDUMP at park (player ", player.global_position, "): park=", park_hit(), " bands: ", bands_str())
	# Stand where the v1.0.24 touch tests leave the cat.
	player.global_position = Vector3(110, 0.2, 84)
	for i in range(6):
		main.call("_update_districts", 0.3)
		await get_tree().process_frame
	print("DISTDUMP at (110,84): park=", park_hit(), " bands: ", bands_str())
	# Content points near the empty-audit cell (18, 44).
	var cps: Array = main.get("content_points")
	var near: Array = []
	for cp in cps:
		var d: float = Vector2(18.0 - (cp as Vector3).x, 44.0 - (cp as Vector3).z).length()
		near.append([d, cp])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	print("DISTDUMP cell (18,44): total content_points=", cps.size())
	for i in range(mini(6, near.size())):
		print("DISTDUMP   nearest ", i, ": d=", snappedf(float(near[i][0]), 0.01), " at ", near[i][1])
	print("DISTDUMP DONE")
	get_tree().quit()
