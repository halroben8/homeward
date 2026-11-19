extends Node3D

const CatScript: GDScript = preload("res://scripts/cat.gd")

func _ready() -> void:
	var cat := CharacterBody3D.new()
	cat.set_script(CatScript)
	add_child(cat)
	cat.set_physics_process(false)
	await get_tree().process_frame
	var skel: Skeleton3D = cat.get("meshy_skel")
	var rest41: Transform3D = skel.get_bone_global_rest(41)
	# walk drive
	for i in range(66):
		cat.call("_animate", 1.0 / 60.0, 5.6)
	print("WALK| phase=", cat.get("walk_phase"), " leg0rot=", (cat.get("leg_pivots") as Array)[0].rotation, " leg1rot=", (cat.get("leg_pivots") as Array)[1].rotation)
	print("WALK| bodyrot=", cat.get("body_node").rotation, " headrot=", cat.get("head_node").rotation)
	await get_tree().process_frame
	await get_tree().process_frame
	var pose41: Transform3D = skel.get_bone_global_pose(41)
	print("WALK| clavL rest origin=", rest41.origin, " pose origin=", pose41.origin)
	print("WALK| clavL rest basis x=", rest41.basis.x, " pose basis x=", pose41.basis.x)
	var pose18: Transform3D = skel.get_bone_global_pose(18)
	print("WALK| head pose origin=", pose18.origin, " rest=", skel.get_bone_global_rest(18).origin)
	# sit drive
	cat.set("idle_allowed", true)
	cat.call("debug_set_idle_action", "sit")
	for i in range(150):
		cat.call("_animate", 1.0 / 60.0, 0.0)
	print("SIT| sit_a=", cat.get("sit_a"), " bodyrot=", cat.get("body_node").rotation, " leg0rot=", (cat.get("leg_pivots") as Array)[0].rotation, " leg2rot=", (cat.get("leg_pivots") as Array)[2].rotation)
	await get_tree().process_frame
	await get_tree().process_frame
	var pose13: Transform3D = skel.get_bone_global_pose(13)
	print("SIT| spine2 pose basis y=", pose13.basis.y, " rest basis y=", skel.get_bone_global_rest(13).basis.y)
	get_tree().quit()
