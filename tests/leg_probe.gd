extends Node3D
## LEG PROBE (legs-fix diagnosis, 2026-11-18): instances the real
## player cat on a neutral stage, drives cat._animate by hand the
## same way meshy_snap.gd does, and measures how much rotation
## ACTUALLY reaches the Meshy leg bones vs their rest pose, at
## walk and at sprint speed. Numeric only — no screenshots.
## Run: xvfb-run -a godot --path . tests/LegProbe.tscn

const CatScript: GDScript = preload("res://scripts/cat.gd")
var cat: Node

func bone_dev(skel: Skeleton3D, rest: Dictionary, bi: int) -> float:
	# Angle (rad) between the bone's current global basis and rest.
	var cur: Basis = skel.get_bone_global_pose(bi).basis.orthonormalized()
	var rst: Basis = (rest[bi] as Transform3D).basis.orthonormalized()
	var rel: Basis = rst.inverse() * cur
	return rel.get_euler().length()

func drive_and_measure(sec: float, speed: float, label: String) -> void:
	var skel: Skeleton3D = cat.get("meshy_skel")
	var rest: Dictionary = cat.get("meshy_rest")
	var bones: Dictionary = cat.get("meshy_bone")
	var names := ["fl", "fr", "bl", "br"]
	var lonames := ["fl_lo", "fr_lo", "bl_lo", "br_lo"]
	var maxdev := [0.0, 0.0, 0.0, 0.0]
	var maxlo := [0.0, 0.0, 0.0, 0.0]
	var maxswing := 0.0
	var steps := int(sec * 120.0)
	for i in range(steps):
		cat.call("_animate", 1.0 / 120.0, speed)
		await get_tree().process_frame
		for k in range(4):
			var bi: int = int(bones[names[k]])
			maxdev[k] = maxf(maxdev[k], bone_dev(skel, rest, bi))
			var li: int = int(bones.get(lonames[k], -1))
			if li >= 0:
				maxlo[k] = maxf(maxlo[k], bone_dev(skel, rest, li))
		var lp: Array = cat.get("leg_pivots")
		maxswing = maxf(maxswing, absf((lp[0] as Node3D).rotation.x))
	print("PROBE ", label, ": sculpt FL swing max=", snappedf(maxswing, 0.001),
		" | Meshy UPPER-leg max dev (rad): fl=", snappedf(maxdev[0], 0.001),
		" fr=", snappedf(maxdev[1], 0.001), " bl=", snappedf(maxdev[2], 0.001),
		" br=", snappedf(maxdev[3], 0.001),
		" | LOWER-leg max dev: fl=", snappedf(maxlo[0], 0.001),
		" fr=", snappedf(maxlo[1], 0.001), " bl=", snappedf(maxlo[2], 0.001),
		" br=", snappedf(maxlo[3], 0.001))

func _ready() -> void:
	cat = CharacterBody3D.new()
	cat.set_script(CatScript)
	add_child(cat)
	cat.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROBE skel ok=", cat.get("meshy_skel") != null)
	await drive_and_measure(2.5, 5.6, "WALK 5.6")
	cat.set("is_sprinting", true)
	await drive_and_measure(2.5, 11.5, "SPRINT 11.5")
	cat.set("is_sprinting", false)
	print("PROBE DONE")
	get_tree().quit()
