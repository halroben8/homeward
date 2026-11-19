extends Node
## HOMEWARD splash stills — Zander's Run title art (preview only).
## Stages the REAL game world (dusk lighting, sculpted cat, pound
## worker + net, real fences) with ALL HUD hidden and the action
## frozen mid-leap, then snaps 1280x720 stills for the title screen.
## NOT part of the suite; wires nothing into the game.
##
## Two compositions:
##   HERO (net profile) — side profile, cat at full run / mid-leap
##     across the frame (+X, left to right) on Maple Street, the
##     pound worker behind him with the catch net swooping in,
##     almost catching him. Camera low, south side of the road.
##   FENCE (alternate) — cat mid-hop over the Maple front fence,
##     fence horizontal across the frame, house behind, sky above.
## Run under Xvfb:
##   xvfb-run -a godot --path . tests/ShotRunnerSplash.tscn -- hero
##   xvfb-run -a godot --path . tests/ShotRunnerSplash.tscn -- fence
##   xvfb-run -a godot --path . tests/ShotRunnerSplash.tscn -- all
## Output: ~/workspace/homeward/screenshots_splash/

const OUT := "/home/hatch/workspace/homeward/screenshots_splash"
const OUT_STILLS := "/home/hatch/workspace/homeward/splash_stills"
const EmojiFont := preload("res://tests/emoji_font.gd")

var main: Node = null
var player: Node = null
var worker: Node = null
var cam: Camera3D = null
var what := "all"

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func frac(p: Vector3) -> String:
	if cam.is_position_behind(p):
		return "BEHIND"
	var s: Vector2 = cam.unproject_position(p)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return "(%.2f, %.2f)" % [s.x / vp.x, s.y / vp.y]

func set_cam(pos: Vector3, target: Vector3, fov: float = 55.0) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)

func snap_cam(name: String, pos: Vector3, target: Vector3, fov: float = 55.0) -> void:
	set_cam(pos, target, fov)
	await get_tree().process_frame
	print("CAM ", name, " cat=", frac((player as Node3D).global_position + Vector3(0, 0.3, 0)),
		" worker=", frac((worker as Node3D).global_position + Vector3(0, 1.2, 0)))
	await snap(name)

# --- posing (physics OFF on both actors; these are raw model poses) ---

func pose_cat_leap(y: float, nose_pitch: float, fl: float, fr: float, bl: float, br: float, tail_x: float, stretch_z: float = 1.08) -> void:
	var m: Node3D = player.get("model")
	var legs: Array = player.get("leg_pivots")
	var tails: Array = player.get("tail_pivots")
	m.rotation.x = nose_pitch
	m.scale = Vector3(1.0, 1.03, stretch_z)
	legs[0].rotation.x = fl # FL
	legs[1].rotation.x = fr # FR
	legs[2].rotation.x = bl # BL
	legs[3].rotation.x = br # BR
	for t in tails:
		(t as Node3D).rotation.x = tail_x
	(player as Node3D).global_position.y = y

func pose_worker_run(lean: float, leg_f: float, leg_b: float, arm_back: float, aim_target: Vector3) -> void:
	var m: Node3D = worker.get("model")
	m.rotation.x = lean
	(worker.get("leg_l") as Node3D).rotation.x = leg_f
	(worker.get("leg_r") as Node3D).rotation.x = leg_b
	(worker.get("arm_l") as Node3D).rotation.x = arm_back
	worker.call("set_net_visible", true)
	worker.call("_aim_arm", worker.get("arm_r"), aim_target)

func scene_hero() -> void:
	# Cat mid-leap on the Maple road centreline (z=-11), running
	# +X; worker ~1.85 m behind him, net aimed just behind the
	# tail — close enough to read as a near miss, not a catch.
	# Action shifted east (x=48) so the cat flies against the
	# dark gable / tree line instead of the house sign.
	(player as Node3D).global_position = Vector3(48.0, 0.2, -11.0)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X
	pose_cat_leap(0.88, -0.08, -1.05, -0.85, 1.05, 0.90, 0.50)
	(worker as Node3D).global_position = Vector3(46.15, 0.15, -11.35)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	pose_worker_run(0.14, -0.90, 0.75, 0.60, Vector3(47.15, 1.12, -11.0))
	await wait_frames(2)
	await snap_cam("hero_v1.png", Vector3(48.0, 0.62, -8.0), Vector3(47.9, 0.85, -11.0))
	await snap_cam("hero_v2.png", Vector3(48.2, 0.55, -8.8), Vector3(47.9, 0.80, -11.0))
	await snap_cam("hero_v3.png", Vector3(48.0, 0.80, -6.2), Vector3(47.8, 0.80, -11.0))

func scene_dkc() -> void:
	# DKC COVER composition (Michael's pick, 2026-11-18): DEPTH is
	# the point. Zander HUGE in the foreground, mid-leap, angled
	# three-quarter TOWARD/past the camera (face visible, body
	# stretched — not a flat side profile, not a gameplay view).
	# The worker smaller in the mid-ground behind him, leaning in,
	# the (rebuilt, real-mesh) net bag close behind Zander's tail.
	# Maple Street at dusk recedes behind them as the third layer.
	# Cat runs +X along the road centreline but cheats his facing
	# toward the camera like box art does.
	(player as Node3D).global_position = Vector3(48.6, 0.80, -10.6)
	(player as Node3D).rotation = Vector3(0, 1.05, 0) # 3/4 toward camera
	# NOTE: model pitch sign — positive rotation.x tips the nose
	# DOWN into a stretched horizontal leap; negative rears him
	# upright like a meerkat (round 2's mistake).
	pose_cat_leap(0.80, 0.22, -1.30, -1.05, 1.30, 1.05, 0.30, 1.16)
	((player as Node).get("model") as Node3D).rotation.z = 0.04
	(worker as Node3D).global_position = Vector3(45.70, 0.15, -12.40)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	# Aim the net just behind the tail — a near miss, not a catch.
	pose_worker_run(0.30, -1.05, 0.90, 0.70, Vector3(47.55, 0.95, -11.05))
	await wait_frames(2)
	# A: the hero framing — cat ~2.4 m from the lens, worker
	# ~6 m: the cat reads roughly twice the worker's size.
	await snap_cam("dkc_a.png", Vector3(50.05, 0.52, -8.55), Vector3(47.95, 0.88, -10.95), 50.0)
	# B: closer + wider lens — more in-your-face perspective.
	await snap_cam("dkc_b.png", Vector3(49.75, 0.40, -9.05), Vector3(48.05, 0.85, -10.85), 60.0)
	# C: lowest angle, cat a touch higher in his leap.
	(player as Node3D).global_position.y = 0.95
	await wait_frames(1)
	await snap_cam("dkc_c.png", Vector3(50.45, 0.30, -8.35), Vector3(47.85, 0.95, -11.05), 54.0)

func snap2(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT_STILLS + "/" + name)
	print("SHOT2: ", name, " ", img.get_size())

func snap_cam2(name: String, pos: Vector3, target: Vector3, fov: float = 55.0) -> void:
	set_cam(pos, target, fov)
	await get_tree().process_frame
	print("CAM2 ", name, " cat=", frac((player as Node3D).global_position + Vector3(0, 0.3, 0)),
		" worker=", frac((worker as Node3D).global_position + Vector3(0, 1.2, 0)))
	await snap2(name)

func scene_dkc2() -> void:
	# DKC COVER round 2 (Michael, 2026-11-18): Zander must
	# DOMINATE — on the DKC box, DK's body spans ~half the frame
	# width in the near foreground. Round 2a staged the camera
	# UNDER the cat (belly view, head out of frame) almost on
	# the net's aim line (hoop face-on = dark web disc). Round
	# 2b: camera at the cat's own height ~1 m south of him,
	# looking level; cat lower in his leap so his head stays
	# clear of the title band; worker west-northwest so the
	# pole axis sits ~35 degrees off the view axis and the hoop
	# reads as an ELLIPSE with the draped bag behind it.
	# Round 2d: keep the PROVEN dkc composition (cat rot 1.05
	# = face 3/4 to camera, worker behind him to the NW, net
	# at his tail) and simply move the camera along the same
	# view axis from 2.51 m to ~1.0 m. Grounded measurements:
	# dkc_a's cat spans 17.9% of frame width at 2.51 m / fov
	# 50, so ~1.0 m lands at ~45-50% — DK's share. (Profile
	# staging at 1.0 m measured 61% but cropped his head and
	# hid his face; off-centre targets clipped him twice.)
	(player as Node3D).global_position = Vector3(48.6, 0.70, -10.60)
	(player as Node3D).rotation = Vector3(0, 1.05, 0) # 3/4 toward camera
	pose_cat_leap(0.70, 0.22, -1.30, -1.05, 1.30, 1.05, 0.30, 1.16)
	((player as Node).get("model") as Node3D).rotation.z = 0.04
	(worker as Node3D).global_position = Vector3(45.70, 0.15, -12.40)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	pose_worker_run(0.30, -1.05, 0.90, 0.70, Vector3(47.55, 0.95, -11.05))
	await wait_frames(2)
	# A: ~1.05 m from the cat, fov 50.
	await snap_cam2("dkc2_a.png", Vector3(49.21, 0.72, -9.74), Vector3(48.58, 0.94, -10.58), 50.0)
	# B: ~0.95 m, fov 52 — the biggest safe framing.
	await snap_cam2("dkc2_b.png", Vector3(49.15, 0.70, -9.83), Vector3(48.58, 0.94, -10.58), 52.0)
	# C: ~1.15 m, fov 47 — a touch safer, still huge.
	await snap_cam2("dkc2_c.png", Vector3(49.27, 0.74, -9.66), Vector3(48.58, 0.94, -10.58), 47.0)

func pose_pedestrian(n: Node, pos: Vector3, rot_y: float, swing: float) -> void:
	# A parked NPC re-posed mid-stride on a sidewalk: physics
	# stays OFF, so this is a frozen walking pose — at cover
	# distance it reads as a pedestrian going about their day.
	var nd := n as Node3D
	nd.global_position = pos
	nd.rotation = Vector3(0, rot_y, 0)
	((n as Node).get("model") as Node3D).rotation.x = 0.06
	((n as Node).get("leg_l") as Node3D).rotation.x = swing
	((n as Node).get("leg_r") as Node3D).rotation.x = -swing * 0.8
	((n as Node).get("arm_l") as Node3D).rotation.x = -swing * 0.6
	((n as Node).get("arm_r") as Node3D).rotation.x = swing * 0.6

func add_bg_cat(tint: Color, pos: Vector3, rot_y: float) -> Node3D:
	# A background town cat: a duplicate of the player's MODEL
	# subtree only (no scripts, no physics), coat-tinted via
	# duplicated materials. MUST be called before the player is
	# posed, while the model still stands neutral. Any floating
	# labels in the subtree are hidden.
	var src: Node3D = (player as Node).get("model")
	var dup: Node3D = src.duplicate() as Node3D
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation = Vector3(0, rot_y, 0)
	main.add_child(holder)
	holder.add_child(dup)
	dup.position = src.position
	dup.rotation = src.rotation
	dup.scale = src.scale
	var stack: Array = [dup]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Label3D or nd is Sprite3D:
			(nd as Node3D).visible = false
		if nd is MeshInstance3D:
			var mi := nd as MeshInstance3D
			var m := mi.material_override
			if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				m = mi.mesh.surface_get_material(0)
			if m is StandardMaterial3D:
				var dm: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				dm.albedo_color = Color(dm.albedo_color.r * tint.r, dm.albedo_color.g * tint.g, dm.albedo_color.b * tint.b, dm.albedo_color.a)
				mi.material_override = dm
		for ch in nd.get_children():
			stack.append(ch)
	return holder

func scene_dkc3() -> void:
	# DKC COVER round 3 (Michael, live call 2026-11-18): push
	# Zander to the TOP of the size range (~55% of frame width)
	# with a foreshortened leap angled partly TOWARD the camera
	# — jumping out of the box — and BUSY the background up for
	# depth: pedestrians on the sidewalks plus two tinted
	# background cats at mid-distance. Zander stays the
	# unmissable foreground subject.
	# Background cats FIRST, while Zander's model stands neutral.
	var cat_grey := add_bg_cat(Color(0.50, 0.49, 0.47), Vector3(54.5, 0.12, -14.4), -1.2)
	var cat_dark := add_bg_cat(Color(0.30, 0.28, 0.27), Vector3(57.5, 0.12, -13.0), 2.6)
	print("DKC3 bg cats placed; model local pos=", str(((player as Node).get("model") as Node3D).position),
		" scale=", str(((player as Node).get("model") as Node3D).scale))
	# Zander: rot 0.88 turns his leap partly toward the lens —
	# head/front foreshortened big, tail streaming behind.
	(player as Node3D).global_position = Vector3(48.6, 0.70, -10.60)
	(player as Node3D).rotation = Vector3(0, 0.88, 0)
	pose_cat_leap(0.70, 0.22, -1.30, -1.05, 1.30, 1.05, 0.30, 1.16)
	((player as Node).get("model") as Node3D).rotation.z = 0.04
	(worker as Node3D).global_position = Vector3(45.70, 0.15, -12.40)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	pose_worker_run(0.30, -1.05, 0.90, 0.70, Vector3(47.55, 0.95, -11.05))
	# Pedestrians: far sidewalk + Birch Lane, small in frame.
	var npcs: Array = main.get("npcs")
	if npcs.size() >= 7:
		pose_pedestrian(npcs[0], Vector3(40.5, 0.15, -14.6), PI * 0.5, 0.50)
		pose_pedestrian(npcs[1], Vector3(52.5, 0.15, -14.6), -PI * 0.5, -0.40)
		pose_pedestrian(npcs[2], Vector3(58.5, 0.15, -14.7), PI * 0.5, 0.35)
		pose_pedestrian(npcs[3], Vector3(33.5, 0.15, -13.5), PI, 0.45)
		pose_pedestrian(npcs[4], Vector3(33.0, 0.15, -16.5), 0.0, -0.50)
		pose_pedestrian(npcs[5], Vector3(63.0, 0.15, -14.6), -PI * 0.5, 0.40)
		pose_pedestrian(npcs[6], Vector3(44.0, 0.15, -14.65), PI * 0.5, -0.30)
	await wait_frames(2)
	# A: ~0.92 m from the cat, fov 50 — full busy scene.
	await snap_cam2("dkc2_a.png", Vector3(49.12, 0.70, -9.88), Vector3(48.62, 0.92, -10.55), 50.0)
	# B: ~0.85 m, fov 54 — closest, most foreshortened.
	await snap_cam2("dkc2_b.png", Vector3(49.05, 0.68, -9.95), Vector3(48.62, 0.92, -10.55), 54.0)
	# C: A's framing with the background cats hidden — the
	# pedestrians-only fallback if the cats read wrong.
	cat_grey.visible = false
	cat_dark.visible = false
	await wait_frames(1)
	await snap_cam2("dkc2_c.png", Vector3(49.12, 0.70, -9.88), Vector3(48.62, 0.92, -10.55), 50.0)

func scene_dkc4() -> void:
	# DKC COVER round 4 — merge: round 2d's proven face
	# geometry (rot ~1.0, camera on the dkc axis) pushed to
	# ~55% by closing to ~0.92 m, a MILD toward-camera cheat
	# (rot 0.98, not 0.88 — 0.88 tipped him over the lens and
	# his face left the top of frame), camera at head height.
	# Background life re-placed with frac() verification
	# printed from the actual camera before the snap.
	# Verified corridor (frac prints, round 4a): the camera
	# sees the far sidewalk only for world x ~37-48 at
	# z ~-14.5 — everything east of that is behind the view
	# plane. Both bg cats and all pedestrians live there.
	# Zander sits LOWER this round (root 0.58, target 1.06)
	# so his ear tips clear the title band.
	var cat_grey := add_bg_cat(Color(0.50, 0.49, 0.47), Vector3(37.8, 0.12, -14.4), 0.9)
	var cat_dark := add_bg_cat(Color(0.30, 0.28, 0.27), Vector3(41.5, 0.12, -14.3), 2.6)
	(player as Node3D).global_position = Vector3(48.6, 0.55, -10.60)
	(player as Node3D).rotation = Vector3(0, 0.98, 0)
	pose_cat_leap(0.55, 0.22, -1.30, -1.05, 1.30, 1.05, 0.30, 1.16)
	((player as Node).get("model") as Node3D).rotation.z = 0.04
	(worker as Node3D).global_position = Vector3(45.70, 0.15, -12.40)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	pose_worker_run(0.30, -1.05, 0.90, 0.70, Vector3(47.55, 0.95, -11.05))
	var npcs: Array = main.get("npcs")
	var ped_nodes: Array = []
	if npcs.size() >= 4:
		pose_pedestrian(npcs[0], Vector3(39.0, 0.15, -14.6), PI * 0.5, 0.50)
		pose_pedestrian(npcs[1], Vector3(45.2, 0.15, -14.7), -PI * 0.5, -0.40)
		pose_pedestrian(npcs[2], Vector3(36.8, 0.15, -13.8), PI, 0.35)
		pose_pedestrian(npcs[3], Vector3(43.5, 0.15, -14.65), -PI * 0.5, -0.50)
		ped_nodes = [npcs[0], npcs[1], npcs[2], npcs[3]]
	await wait_frames(2)
	# A: ~0.92 m from the cat, fov 50. Set the camera, verify
	# every placed actor's frame position, then snap.
	set_cam(Vector3(49.13, 0.82, -9.85), Vector3(48.60, 1.10, -10.57), 50.0)
	await get_tree().process_frame
	print("DKC4 A cat=", frac((player as Node3D).global_position + Vector3(0, 0.3, 0)),
		" worker=", frac((worker as Node3D).global_position + Vector3(0, 1.2, 0)),
		" grey=", frac(cat_grey.global_position + Vector3(0, 0.3, 0)),
		" dark=", frac(cat_dark.global_position + Vector3(0, 0.3, 0)))
	for i in range(ped_nodes.size()):
		print("DKC4 A ped", i, "=", frac((ped_nodes[i] as Node3D).global_position + Vector3(0, 0.9, 0)))
	await snap2("dkc2_a.png")
	# B: ~0.86 m, fov 54 — closest variant.
	await snap_cam2("dkc2_b.png", Vector3(49.08, 0.80, -9.92), Vector3(48.60, 1.08, -10.57), 54.0)
	# C: A's framing, background cats hidden (fallback).
	cat_grey.visible = false
	cat_dark.visible = false
	await wait_frames(1)
	set_cam(Vector3(49.13, 0.82, -9.85), Vector3(48.60, 1.10, -10.57), 50.0)
	await snap2("dkc2_c.png")

func scene_dkc6() -> void:
	# DKC COVER round 6 — final dkc3 staging. Round 5 failed
	# two ways: the leap's vertical span (tail up + front paws
	# down) still cropped his paws at ~47% width, and the
	# worker at z=-11.3 loomed as large as the cat. Fixes:
	# compact the leap (tail streamed BACK not up, front legs
	# tucked, flatter pitch, higher root), worker back to the
	# NW spot 4.5 m from the lens with the follow-through aim
	# (net ellipse NW of the tail), lens narrowed to fov 46
	# to hold ~48% width at the safer distance.
	var cat_grey := add_bg_cat(Color(0.50, 0.49, 0.47), Vector3(37.8, 0.12, -14.4), 0.9)
	var cat_dark := add_bg_cat(Color(0.30, 0.28, 0.27), Vector3(41.5, 0.12, -14.3), 2.6)
	(player as Node3D).global_position = Vector3(48.46, 0.68, -10.60)
	(player as Node3D).rotation = Vector3(0, 0.98, 0)
	pose_cat_leap(0.68, 0.12, -1.05, -0.90, 1.10, 0.95, 0.70, 1.16)
	((player as Node).get("model") as Node3D).rotation.z = 0.04
	(worker as Node3D).global_position = Vector3(45.70, 0.15, -12.40)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	pose_worker_run(0.30, -1.05, 0.90, 0.70, Vector3(47.60, 1.00, -11.90))
	var npcs: Array = main.get("npcs")
	if npcs.size() >= 4:
		pose_pedestrian(npcs[0], Vector3(39.0, 0.15, -14.6), PI * 0.5, 0.50)
		pose_pedestrian(npcs[1], Vector3(45.2, 0.15, -14.7), -PI * 0.5, -0.40)
		pose_pedestrian(npcs[2], Vector3(36.8, 0.15, -13.8), PI, 0.35)
		pose_pedestrian(npcs[3], Vector3(43.5, 0.15, -14.65), -PI * 0.5, -0.50)
	await wait_frames(2)
	# A: ~1.16 m from the cat, fov 46 — whole body, ~48%.
	await snap_cam2("dkc3_a.png", Vector3(49.13, 0.88, -9.65), Vector3(48.46, 1.04, -10.57), 46.0)
	# B: ~1.11 m, fov 48 — a touch bigger.
	await snap_cam2("dkc3_b.png", Vector3(49.08, 0.87, -9.70), Vector3(48.46, 1.04, -10.57), 48.0)

func scene_dkc7() -> void:
	# DKC COVER round 7 — dkc3 final. Round 6 fit the whole
	# body (bbox 47.7% wide, inside all sides) but Zander's
	# splayed forelegs descend into the bottom-centre band
	# where the tagline + button stack lives. Turn him a
	# touch more profile (rot 1.12) so the forelegs stack on
	# the right, clear of the centre band, and tuck them
	# slightly. Everything else from round 6 stands.
	var cat_grey := add_bg_cat(Color(0.50, 0.49, 0.47), Vector3(37.8, 0.12, -14.4), 0.9)
	var cat_dark := add_bg_cat(Color(0.30, 0.28, 0.27), Vector3(41.5, 0.12, -14.3), 2.6)
	(player as Node3D).global_position = Vector3(48.46, 0.71, -10.60)
	(player as Node3D).rotation = Vector3(0, 1.12, 0)
	pose_cat_leap(0.71, 0.06, -1.15, -1.05, 1.10, 0.95, 0.70, 1.16)
	((player as Node).get("model") as Node3D).rotation.z = 0.04
	(worker as Node3D).global_position = Vector3(45.70, 0.15, -12.40)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	# Aim so the (new, longer) net's frame lands WEST of the
	# cat's silhouette with a visible gap — at the old aim it
	# hid behind his rump.
	pose_worker_run(0.30, -1.05, 0.90, 0.70, Vector3(47.53, 0.84, -11.33))
	var npcs: Array = main.get("npcs")
	if npcs.size() >= 4:
		pose_pedestrian(npcs[0], Vector3(39.0, 0.15, -14.6), PI * 0.5, 0.50)
		pose_pedestrian(npcs[1], Vector3(45.2, 0.15, -14.7), -PI * 0.5, -0.40)
		pose_pedestrian(npcs[2], Vector3(36.8, 0.15, -13.8), PI, 0.35)
		pose_pedestrian(npcs[3], Vector3(43.5, 0.15, -14.65), -PI * 0.5, -0.50)
	await wait_frames(2)
	# A: ~1.16 m from the cat, fov 46 — the hero framing.
	await snap_cam2("dkc3_a.png", Vector3(49.13, 0.88, -9.65), Vector3(48.46, 1.04, -10.57), 46.0)
	# B: ~1.11 m, fov 48 — a touch bigger.
	await snap_cam2("dkc3_b.png", Vector3(49.08, 0.87, -9.70), Vector3(48.46, 1.04, -10.57), 48.0)


# Screen-space bbox of the whole cat model (all mesh AABBs
# projected), as [min, max] viewport fractions. Used to fit
# the WHOLE cat in frame at the biggest safe scale.
func cat_bbox() -> Array:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	var model: Node = (player as Node).get("model")
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.visible:
				var ga: AABB = mi.global_transform * mi.get_aabb()
				for cx in [ga.position.x, ga.position.x + ga.size.x]:
					for cy in [ga.position.y, ga.position.y + ga.size.y]:
						for cz in [ga.position.z, ga.position.z + ga.size.z]:
							var p := Vector3(cx, cy, cz)
							if cam.is_position_behind(p):
								mn = Vector2(-9, -9)
								mx = Vector2(9, 9)
							else:
								var s: Vector2 = cam.unproject_position(p)
								var f := Vector2(s.x / vp.x, s.y / vp.y)
								mn.x = minf(mn.x, f.x)
								mn.y = minf(mn.y, f.y)
								mx.x = maxf(mx.x, f.x)
								mx.y = maxf(mx.y, f.y)
		for ch in n.get_children():
			stack.append(ch)
	return [mn, mx]

func pole_angle() -> float:
	# Angle between the net's pole axis and the camera view
	# axis: 0 = end-on (the dish trap), 90 = full side-on.
	var arm_r: Node3D = (worker as Node).get("arm_r")
	var pole_dir: Vector3 = (arm_r.global_transform.basis * Vector3(0, -1, 0)).normalized()
	var fwd: Vector3 = -cam.global_transform.basis.z
	return rad_to_deg(acos(clampf(absf(pole_dir.dot(fwd)), 0.0, 1.0)))

func stage_dkc5() -> void:
	# Round-7 staging (the composition Michael's notes built
	# to): Zander turned a touch more profile (rot 1.12) so the
	# forelegs stack on the right, clear of the bottom-centre
	# tagline/button band; compact leap — tail streamed BACK,
	# forelegs tucked, higher root. Background cats + peds from
	# the dkc4 corridor. Worker NW, net aimed to land WEST of
	# the cat's silhouette with a visible gap.
	var cat_grey := add_bg_cat(Color(0.50, 0.49, 0.47), Vector3(37.8, 0.12, -14.4), 0.9)
	var cat_dark := add_bg_cat(Color(0.30, 0.28, 0.27), Vector3(41.5, 0.12, -14.3), 2.6)
	(player as Node3D).global_position = Vector3(48.46, 0.71, -10.60)
	(player as Node3D).rotation = Vector3(0, 1.12, 0)
	pose_cat_leap(0.71, 0.10, -1.30, 0.50, 1.30, -0.55, 0.70, 1.16) # GALLOP: FL reaching, FR tucked under, BL extended behind, BR driving forward — no mirrored rocking-horse legs (Michael, 2026-11-18)
	((player as Node).get("model") as Node3D).rotation.z = 0.04
	(worker as Node3D).global_position = Vector3(45.70, 0.15, -12.40)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	var npcs: Array = main.get("npcs")
	if npcs.size() >= 4:
		pose_pedestrian(npcs[0], Vector3(39.0, 0.15, -14.6), PI * 0.5, 0.50)
		pose_pedestrian(npcs[1], Vector3(45.2, 0.15, -14.7), -PI * 0.5, -0.40)
		pose_pedestrian(npcs[2], Vector3(36.8, 0.15, -13.8), PI, 0.35)
		pose_pedestrian(npcs[3], Vector3(43.5, 0.15, -14.65), -PI * 0.5, -0.50)

func aim_net(target: Vector3) -> void:
	pose_worker_run(0.30, -1.05, 0.90, 0.70, target)
	(worker as Node).call("update_net_grip")

func scene_dkc5x() -> void:
	# Exploration for the FINAL spec (Michael): dkc2-level
	# presence, pulled back ONLY the minimum so the whole body
	# fits. Sweep distances at fov 48 for three net aims;
	# print the cat bbox + pole angle for every combo.
	stage_dkc5()
	await wait_frames(2)
	var t := Vector3(48.46, 1.04, -10.57)
	var c0 := Vector3(49.08, 0.87, -9.70)
	var d0 := c0.distance_to(t)
	var aims: Array = [Vector3(47.53, 0.84, -11.33), Vector3(47.15, 0.90, -12.20), Vector3(47.85, 1.00, -11.75)]
	var dists: Array = [1.02, 1.10, 1.18, 1.26]
	for ai in range(aims.size()):
		aim_net(aims[ai])
		await wait_frames(2)
		for di in range(dists.size()):
			var d: float = dists[di]
			set_cam(t + (c0 - t) * (d / d0), t, 48.0)
			await get_tree().process_frame
			var bb: Array = cat_bbox()
			print("DKC5X aim", ai, " dist", d, " bbox=", str(bb[0]), " -> ", str(bb[1]),
				" w=", snappedf(bb[1].x - bb[0].x, 0.001), " poleang=", snappedf(pole_angle(), 0.1))
			await snap("dkc5x_a%d_d%d.png" % [ai, di])


func scene_dkc5y() -> void:
	# Exploration 2: NET PLACEMENT. Round 1's aims all buried
	# the frame behind/under the cat. These combos swing the
	# worker and the aim so the frame lands in open space SW
	# of the cat, three-quarter to the lens, pole + both hands
	# visible. All at dist 1.18 (whole cat fits, big presence).
	stage_dkc5()
	await wait_frames(2)
	var t := Vector3(48.46, 1.04, -10.57)
	var c0 := Vector3(49.08, 0.87, -9.70)
	var d0 := c0.distance_to(t)
	set_cam(t + (c0 - t) * (1.18 / d0), t, 48.0)
	var combos: Array = [
		[Vector3(45.30, 0.15, -11.55), Vector3(47.45, 1.00, -11.45)],
		[Vector3(45.90, 0.15, -11.05), Vector3(47.70, 0.95, -11.15)],
		[Vector3(45.70, 0.15, -12.40), Vector3(47.30, 1.05, -11.60)],
	]
	for ci in range(combos.size()):
		(worker as Node3D).global_position = combos[ci][0]
		aim_net(combos[ci][1])
		await wait_frames(2)
		await get_tree().process_frame
		print("DKC5Y combo", ci, " poleang=", snappedf(pole_angle(), 0.1))
		await snap("dkc5y_c%d.png" % ci)

func scene_dkc5() -> void:
	# FINALS — Michael's pinned spec: dkc2-level presence,
	# whole body in frame, worker stepped noticeably BACK so
	# the full net reads as its own shape in the depth layer,
	# gallop stride, and PLATE renders (cat hidden) so the
	# composite can lay the title UNDER the cat.
	stage_dkc5()
	(worker as Node3D).global_position = Vector3(40.8, 0.15, -14.0) # DEEP layer by the far houses (Michael: full body + full net visible, not crowding the cat)
	var nr: Node = (worker as Node).get("net_root")
	if nr:
		(nr as Node3D).scale = Vector3.ONE * 1.3 # net up a touch so it reads at that range
	await wait_frames(2)
	aim_net(DKC5_AIM)
	await wait_frames(2)
	var t := Vector3(48.46, 1.04, -10.57)
	var c0 := Vector3(49.08, 0.87, -9.70)
	var d0 := c0.distance_to(t)
	set_cam(t + (c0 - t) * (DKC5_DIST_A / d0), t, 48.0)
	await get_tree().process_frame
	var bb: Array = cat_bbox()
	print("DKC5 A bbox=", str(bb[0]), " -> ", str(bb[1]), " poleang=", snappedf(pole_angle(), 0.1))
	await snap2("dkc3_a.png")
	(player as Node3D).visible = false
	await wait_frames(2)
	set_cam(t + (c0 - t) * (DKC5_DIST_A / d0), t, 48.0)
	await snap("dkc3_plate_a.png")
	(player as Node3D).visible = true
	await wait_frames(1)
	set_cam(t + (c0 - t) * (DKC5_DIST_B / d0), t, 48.0)
	await get_tree().process_frame
	bb = cat_bbox()
	print("DKC5 B bbox=", str(bb[0]), " -> ", str(bb[1]), " poleang=", snappedf(pole_angle(), 0.1))
	await snap2("dkc3_b.png")
	(player as Node3D).visible = false
	await wait_frames(2)
	set_cam(t + (c0 - t) * (DKC5_DIST_B / d0), t, 48.0)
	await snap("dkc3_plate_b.png")
	(player as Node3D).visible = true
	await wait_frames(1)
	# Face close-up for the eye / lid / whisker check.
	var head_pos: Vector3 = ((player as Node).get("head_node") as Node3D).global_position
	var face_dir := (cam.global_position - head_pos).normalized()
	set_cam(head_pos + face_dir * 0.42 + Vector3(0, 0.03, 0), head_pos, 50.0)
	await snap("dkc5_face.png")

const DKC5_AIM := Vector3(47.8, 1.10, -11.20)
const DKC5_DIST_A := 1.18
const DKC5_DIST_B := 1.26

func scene_dkc8() -> void:
	# DKC COVER round 8 — Michael's live-call fixes on the
	# approved dkc3_a framing (cat scale/position/camera
	# UNCHANGED):
	# 1) Real mid-gallop legs — four different angles, no
	#    mirrored pairs. A: near front leg reaches forward/
	#    down, far front folded under the chest, one hind
	#    driving extended, the other bent coming through.
	#    B: the front-leg roles swapped (far leg reaches).
	# 2) Worker WAY back at the houses' depth plane (z=-14.2,
	#    ~7.8 m from the lens): whole figure + full pole +
	#    whole net inside the frame, two-handed grip via the
	#    game's own update_net_grip (aim_net helper), pole
	#    reaching toward the cat.
	var cat_grey := add_bg_cat(Color(0.50, 0.49, 0.47), Vector3(37.8, 0.12, -14.4), 0.9)
	var cat_dark := add_bg_cat(Color(0.30, 0.28, 0.27), Vector3(40.2, 0.12, -14.35), 2.6)
	(player as Node3D).global_position = Vector3(48.46, 0.71, -10.60)
	(player as Node3D).rotation = Vector3(0, 1.12, 0)
	((player as Node).get("model") as Node3D).rotation.z = 0.04
	(worker as Node3D).global_position = Vector3(43.8, 0.15, -14.2)
	(worker as Node3D).rotation = Vector3(0, PI * 0.5, 0)
	# Net cocked up over his shoulder (the at-the-cat aim
	# hid the frame behind Zander's back). A: manual
	# two-handed grip — left hand aimed at a point ON the
	# pole (t=1.15), the same call update_net_grip makes
	# when its tolerance search succeeds. B: the game's
	# own update_net_grip at the same aim, for comparison.
	pose_worker_run(0.30, -1.05, 0.90, 0.70, Vector3(42.2, 2.05, -14.9))
	var ws: float = float(worker.get("mscale"))
	var wmodel: Node3D = worker.get("model")
	var arm_r_n: Node3D = worker.get("arm_r")
	var pole_pt: Vector3 = wmodel.to_global(arm_r_n.transform * Vector3(0, -1.15 * ws, 0.01))
	worker.call("_aim_arm", worker.get("arm_l"), pole_pt)
	var npcs: Array = main.get("npcs")
	if npcs.size() >= 4:
		pose_pedestrian(npcs[0], Vector3(39.0, 0.15, -14.6), PI * 0.5, 0.50)
		pose_pedestrian(npcs[1], Vector3(46.8, 0.15, -14.55), -PI * 0.5, -0.40)
		pose_pedestrian(npcs[2], Vector3(36.8, 0.15, -13.8), PI, 0.35)
		pose_pedestrian(npcs[3], Vector3(40.8, 0.15, -14.7), -PI * 0.5, -0.50)
	# Variant A: FL reaches, FR folded; BL extended, BR through.
	pose_cat_leap(0.71, 0.06, -0.80, 0.60, 1.30, 0.45, 0.70, 1.16)
	await wait_frames(2)
	await snap_cam2("dkc3_a.png", Vector3(49.13, 0.88, -9.65), Vector3(48.46, 1.04, -10.57), 46.0)
	# Variant B: same cat pose; worker grip via the game's
	# own update_net_grip (aim_net) at the same aim point.
	aim_net(Vector3(42.2, 2.05, -14.9))
	await wait_frames(2)
	await snap_cam2("dkc3_b.png", Vector3(49.13, 0.88, -9.65), Vector3(48.46, 1.04, -10.57), 46.0)

func hide_hint_labels() -> void:
	# Gameplay hint labels floating in the world ("hide ⛺",
	# "🐾 cat gap") are UI, not scenery — a splash still must
	# not carry them. Street/house signs stay.
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label3D:
			var t: String = (n as Label3D).text
			if t.contains("hide") or t.contains("cat gap"):
				(n as Label3D).visible = false
		for ch in n.get_children():
			stack.append(ch)

func scene_fence() -> void:
	(worker as Node3D).global_position = Vector3(-110, 0.15, 80)
	# PARK fence, camera on the park side (z>20.6) looking
	# south: grass foreground, fence horizontal mid-frame,
	# Oak Avenue + houses behind. Cat at x=-33 (clear of the
	# bench at x~-25 and the pine at x~-30), low over the top
	# rail, face +Z toward the camera, leaping toward it.
	(player as Node3D).global_position = Vector3(-33.0, 0.80, 20.6)
	(player as Node3D).rotation = Vector3(0, 0, 0) # face +Z (toward camera)
	pose_cat_leap(0.80, 0.14, -0.60, -0.50, 0.90, 0.80, 0.55)
	await wait_frames(2)
	await snap_cam("fence_park_v1.png", Vector3(-33.0, 0.78, 25.4), Vector3(-33.0, 0.88, 20.6))
	await snap_cam("fence_park_v2.png", Vector3(-33.0, 0.70, 24.2), Vector3(-33.0, 0.85, 20.6))

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		what = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(OUT_STILLS)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	EmojiFont.apply() # render-only emoji fallback — before Main is instanced
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(1.2)
	player = main.get("player")
	worker = main.get("pound_worker")
	cam = main.get("cam")
	print("SPLASH build done, state=", str(main.get("state")),
		" worker=", str(worker != null))
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_frames(10)
	# Freeze the world: main drives camera/traffic/van in _process,
	# the actors animate in _physics_process. The opening cutscene
	# module never advances without main's _process.
	main.set_process(false)
	# Hide every HUD layer (splash lives on hud_layer too).
	for layer_name in ["hud_layer", "touch_layer", "escape_ui_layer"]:
		var layer: CanvasLayer = main.get(layer_name)
		if layer:
			layer.visible = false
	# Park NPCs far away and stop their brains.
	var i: int = 0
	for n in main.get("npcs"):
		var nd := n as Node3D
		nd.global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		(n as Node).set_physics_process(false)
		i += 1
	# Van out of frame (it patrols the legacy network).
	var van: Node3D = main.get("pound_van")
	if van:
		van.global_position = Vector3(500, 0, 500)
	# Actors: physics off, worker visible.
	(player as Node).set_physics_process(false)
	(player as Node).set_process(false) # its camera rig would lerp the staged camera away between snaps
	(worker as Node).set_physics_process(false)
	worker.visible = true
	hide_hint_labels()
	worker.call("set_expression", "determined")
	print("SPLASH staged, worker visible=", str(worker.visible),
		" net=", str(worker.get("net_root") != null))
	if what == "hero" or what == "all":
		await scene_hero()
	if what == "fence" or what == "all":
		await scene_fence()
	if what == "dkc":
		await scene_dkc()
	if what == "dkc2":
		await scene_dkc2()
	if what == "dkc3":
		await scene_dkc3()
	if what == "dkc4":
		await scene_dkc4()
	if what == "dkc5x":
		await scene_dkc5x()
	if what == "dkc5":
		await scene_dkc5()
	if what == "dkc5y":
		await scene_dkc5y()
	if what == "dkc6":
		await scene_dkc6()
	if what == "dkc7":
		await scene_dkc7()
	if what == "dkc8":
		await scene_dkc8()
	print("SPLASH SHOTS DONE")
	get_tree().quit(0)
