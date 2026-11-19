extends Node3D

const CatScript: GDScript = preload("res://scripts/cat.gd")

func dump(skel: Skeleton3D, tag: String) -> void:
	for bi in [1, 12, 13, 15, 18, 2, 41]:
		var p: Transform3D = skel.get_bone_global_pose(bi)
		var r: Transform3D = skel.get_bone_global_rest(bi)
		print(tag, "| ", skel.get_bone_name(bi), " pose_o=", p.origin, " pose_by=", p.basis.y, " rest_by=", r.basis.y)

func _ready() -> void:
	var cat := CharacterBody3D.new()
	cat.set_script(CatScript)
	add_child(cat)
	cat.set_physics_process(false)
	await get_tree().process_frame
	var skel: Skeleton3D = cat.get("meshy_skel")
	print("PARENTS| spine2 parent=", skel.get_bone_parent(13), " name12=", skel.get_bone_name(12), " parent12=", skel.get_bone_parent(12))
	dump(skel, "REST0")
	cat.set("frozen", false)
	cat.set("idle_allowed", true)
	cat.call("debug_set_idle_action", "sit")
	for i in range(150):
		cat.call("_animate", 1.0 / 60.0, 0.0)
	print("SIT| sit_a=", cat.get("sit_a"), " bodyrot=", cat.get("body_node").rotation, " leg0=", (cat.get("leg_pivots") as Array)[0].rotation, " leg2=", (cat.get("leg_pivots") as Array)[2].rotation, " headrot=", cat.get("head_node").rotation)
	await get_tree().process_frame
	await get_tree().process_frame
	dump(skel, "SIT")
	get_tree().quit()
