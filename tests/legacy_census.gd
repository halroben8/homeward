extends Node
## HOMEWARD v1.0.12 BISECT verification driver (rendered, Xvfb):
##   xvfb-run -a godot --path . tests/LegacyCensus.tscn
## Boots Main with LEGACY_TOWN_ONLY on, waits for the staged build,
## then prints the legacy census: houses, NPCs / grabbers, the
## pound van, the World child count, the max NPC spawn x and the
## traffic vertical-road list — the comparison numbers for the
## bisect. Starts play briefly, then quits.

var main: Node = null
var play_t: float = 0.0
var done: bool = false

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)

func _process(delta: float) -> void:
	if main == null or done:
		return
	if not bool(main.get("build_complete")):
		return
	if play_t == 0.0:
		var houses_arr: Array = main.get("houses")
		var npcs: Array = main.get("npcs")
		var g: int = 0
		var max_x: float = -1e9
		for n in npcs:
			if str(n.get("role")) == "grabber":
				g += 1
			max_x = maxf(max_x, (n as Node3D).global_position.x)
		var world: Node = main.get_node_or_null("World")
		print("CENSUS: legacy=", str(main.get("LEGACY_TOWN_ONLY") if main.get("LEGACY_TOWN_ONLY") != null else "?"))
		print("CENSUS: houses=", houses_arr.size())
		print("CENSUS: npcs=", npcs.size(), " grabbers=", g)
		print("CENSUS: max_npc_x=", snappedf(max_x, 0.1))
		print("CENSUS: pound_van=", str(main.get("pound_van") != null))
		print("CENSUS: pound_route=", str(main.get("pound_route")))
		print("CENSUS: traffic_roads_v=", str(main.call("_traffic_roads_v")))
		print("CENSUS: world_children=", world.get_child_count() if world else -1)
		print("CENSUS: home_address=", str(main.get("home_address")))
		main.call("dismiss_splash")
		main.call("start_game")
	play_t += delta
	if play_t > 3.0:
		print("CENSUS: play OK state=", str(main.get("state")))
		done = true
		get_tree().quit()
