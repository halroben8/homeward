extends Node
## v1.0.26 DOOR PROBE (diagnostic): boot the real game, cast the
## suite's pet-door ray, and identify exactly what it hits.

func _ready() -> void:
	await run()

func run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)
	var bw := 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await get_tree().create_timer(0.5).timeout
	var o: Vector3 = main.get("escape_origin")
	var space := (main as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(o + Vector3(6, 0.7, -6), o + Vector3(6, 0.7, -46))
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		print("DOORPROBE: no hit")
	else:
		var col: Object = hit["collider"]
		print("DOORPROBE: hit pos=", str(hit["position"]))
		if col is Node:
			var n: Node = col as Node
			var path := str(n.get_path())
			print("DOORPROBE: collider=", path, " name=", n.name, " class=", n.get_class())
			var p: Node = n.get_parent()
			while p != null and p != main:
				print("DOORPROBE:   parent: ", p.name, " (", p.get_class(), ")")
				p = p.get_parent()
			if n is CollisionObject3D:
				print("DOORPROBE:   layer=", str((n as CollisionObject3D).collision_layer), " mask=", str((n as CollisionObject3D).collision_mask))
			if n is Node3D:
				print("DOORPROBE:   global_pos=", str((n as Node3D).global_position))
	print("DOORPROBE DONE")
	get_tree().quit()
