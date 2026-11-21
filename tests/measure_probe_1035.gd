extends Node
# v1.0.35 measurement probe (ad-hoc): dump per-mesh global AABB
# tops for the unique pair vs control NPCs (woman/kid/officer),
# to tell a real scale problem from a loose-AABB artifact.
#   godot --headless --path . tests/MeasureProbe1035.tscn

func dump_npc(label: String, n: Node) -> void:
	if n == null:
		print("MEASURE ", label, ": MISSING")
		return
	var n3 := n as Node3D
	print("MEASURE ", label, " npc_type=", str(n.get("npc_type")), " body_h=", n.get("body_h"), " mscale=", n.get("mscale"), " base_y=", n3.global_position.y)
	var stack: Array = [n]
	var worst_top: float = -1e9
	var worst_name := ""
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var ab: AABB = mi.global_transform * mi.get_aabb()
			var top: float = ab.position.y + ab.size.y
			if top > worst_top:
				worst_top = top
				worst_name = mi.name
			print("  mesh ", mi.name, " vis=", mi.visible, " aabb_size=", ab.size, " top=", top, " bottom=", ab.position.y)
		for ch in cur.get_children():
			stack.push_back(ch)
	print("MEASURE ", label, " WORST top=", worst_top, " (", worst_name, ") height=", worst_top - n3.global_position.y)

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = ps.instantiate()
	add_child(main)
	var t := 0.0
	while not bool(main.get("build_complete")) and t < 180.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("MEASURE build_complete=", main.get("build_complete"))
	await get_tree().create_timer(1.0).timeout
	dump_npc("danielle", main.get("danielle_npc"))
	dump_npc("noah", main.get("noah_npc"))
	dump_npc("officer", main.get("pound_worker"))
	for n in main.get("npcs"):
		var ty: String = str(n.get("npc_type"))
		if ty == "woman" or ty == "kid":
			dump_npc(ty, n)
			if ty == "kid":
				break
	print("MEASURE DONE")
	get_tree().quit()
