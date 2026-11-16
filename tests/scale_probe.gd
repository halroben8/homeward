extends Node3D
## SCALE PROBE — measures the player cat's BUILT dimensions from
## real global AABBs (not code intentions), plus a 1.7m person's,
## for the proportion fix. Headless-safe (no rendering needed):
##   godot --headless --path . tests/ScaleProbe.tscn
## Prints SCALE| lines the runner greps.

func _aabb_of(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				var a: AABB = mi.global_transform * mi.get_aabb()
				if first:
					out = a
					first = false
				else:
					out = out.merge(a)
		for ch in cur.get_children():
			stack.append(ch)
	return out

func _ready() -> void:
	# --- the cat, standalone, rest pose (same posing as SilhouetteCat) ---
	var CatScript: GDScript = load("res://scripts/cat.gd")
	var cat: Node = CatScript.new()
	add_child(cat)
	cat.set_physics_process(false)
	cat.set("velocity", Vector3.ZERO)
	(cat as Node3D).global_position = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame
	var model: Node3D = cat.get("model")
	model.rotation = Vector3.ZERO
	var body: Node3D = cat.get("body_node")
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	var head: Node3D = cat.get("head_node")
	head.rotation = Vector3.ZERO
	head.position = cat.get("head_base_pos")
	for lp in cat.get("leg_pivots"):
		(lp as Node3D).rotation = Vector3.ZERO
	var ti := 0
	for tp in cat.get("tail_pivots"):
		(tp as Node3D).rotation = Vector3(-0.33 + float(ti) * 0.06, 0, 0)
		ti += 1
	(cat.get("ear_l") as Node3D).rotation = Vector3(0, 0, 0.12)
	(cat.get("ear_r") as Node3D).rotation = Vector3(0, 0, -0.12)
	await get_tree().process_frame

	var all := _aabb_of(model)
	var body_a := _aabb_of(body.get_child(0)) # the lofted body mesh only
	var head_a := _aabb_of(head.get_child(0)) # the sculpted head mesh only
	var ear_a := _aabb_of(cat.get("ear_l")).merge(_aabb_of(cat.get("ear_r")))
	var leg_a := AABB()
	var first_leg := true
	for lp in cat.get("leg_pivots"):
		var la := _aabb_of(lp)
		leg_a = la if first_leg else leg_a.merge(la)
		first_leg = false
	# nose-to-rump: head front (max z of head mesh) to body rear (min z of body mesh)
	var nose_z: float = head_a.position.z + head_a.size.z
	var rump_z: float = body_a.position.z
	print("SCALE| cat overall AABB size=", all.size, " min=", all.position)
	print("SCALE| cat back/shoulder height (body mesh top)=", body_a.position.y + body_a.size.y)
	print("SCALE| cat belly bottom (body mesh min y)=", body_a.position.y)
	print("SCALE| cat torso length (body mesh z)=", body_a.size.z, " width=", body_a.size.x, " depth=", body_a.size.y)
	print("SCALE| cat head width=", head_a.size.x, " height=", head_a.size.y, " depth=", head_a.size.z)
	print("SCALE| cat head top (no ears)=", head_a.position.y + head_a.size.y)
	print("SCALE| cat ear-tip height=", ear_a.position.y + ear_a.size.y)
	print("SCALE| cat nose-to-rump (head front to body rear)=", nose_z - rump_z)
	print("SCALE| cat leg span: hip pivot y=", (cat.get("leg_pivots")[0] as Node3D).position.y, " paw bottom y=", leg_a.position.y, " leg AABB height=", leg_a.size.y)
	var cs: CollisionShape3D = null
	for ch in cat.get_children():
		if ch is CollisionShape3D:
			cs = ch
	if cs and cs.shape is CapsuleShape3D:
		var cap := cs.shape as CapsuleShape3D
		print("SCALE| cat collision capsule radius=", cap.radius, " height=", cap.height, " centre=", cs.position)

	# --- a person, standalone (woman: body_h 1.7) ---
	var PersonScript: GDScript = load("res://scripts/person.gd")
	var person: Node = PersonScript.new()
	person.set("npc_type", "woman")
	add_child(person)
	person.set_physics_process(false)
	(person as Node3D).global_position = Vector3(5, 0, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var pmodel: Node3D = person.get("model")
	if pmodel:
		pmodel.rotation = Vector3.ZERO
		pmodel.position = Vector3.ZERO
		pmodel.scale = Vector3.ONE
	await get_tree().process_frame
	var pa := _aabb_of(person.get("model"))
	print("SCALE| person (woman) AABB size=", pa.size, " height=", pa.position.y + pa.size.y)
	print("SCALE| person body_h=", person.get("body_h"))
	print("SCALE DONE")
	get_tree().quit(0)
