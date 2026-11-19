extends Node
## BEND PROBE — renders the two bend motions at their DEEPEST point
## for Michael's "folding in half" complaint: (1) the friendly
## petting kneel (bend_a = 1, mid-"pet"), (2) the capture scoop at
## the end of beat 1 (cutscene_t ~= 1.1, kneel envelope = 1).
## Side profile + three-quarter stills with a free camera, plus a
## telemetry line of the pose values at the snap moment, so
## before/after runs are directly comparable.
##   xvfb-run -a godot --path . tests/BendProbe.tscn -- before
##   xvfb-run -a godot --path . tests/BendProbe.tscn -- after
## Output: ~/workspace/homeward/screenshots_bend/<arg>/

const BASE := "/home/hatch/workspace/homeward/screenshots_bend"
var OUT := BASE + "/before"
var main: Node = null
var player: Node = null
var cam: Camera3D = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name)

func place_cam(subject: Node3D, side_sign: float, dist: float, height: float, front_mix: float) -> void:
	# Side profile (front_mix = 0) or three-quarter (front_mix ~0.8):
	# stand off the subject's side, slightly toward its front.
	var b: Basis = subject.global_transform.basis
	var pos: Vector3 = subject.global_position + b.x * (side_sign * dist) + b.z * (front_mix * dist) + Vector3(0, height, 0)
	cam.global_position = pos
	cam.look_at(subject.global_position + Vector3(0, 0.82, 0), Vector3.UP)

func pose_line(tag: String, npc: Node) -> void:
	var m: Node3D = npc.get("model")
	var ll: Node3D = npc.get("leg_l")
	var lr: Node3D = npc.get("leg_r")
	var sl: Node3D = npc.get("shin_l")
	var sr: Node3D = npc.get("shin_r")
	var hd: Node3D = npc.get("head_node")
	print("POSE ", tag,
		" model_pitch=", snappedf(m.rotation.x, 0.001),
		" model_pos=", m.position,
		" leg_l=", snappedf(ll.rotation.x, 0.001), " shin_l=", snappedf(sl.rotation.x, 0.001),
		" leg_r=", snappedf(lr.rotation.x, 0.001), " shin_r=", snappedf(sr.rotation.x, 0.001),
		" head=", snappedf(hd.rotation.x, 0.001),
		" bend_a=", snappedf(float(npc.get("bend_a")), 0.001),
		" scoop_kneel=", snappedf(float(npc.get("scoop_kneel_a")), 0.001),
		" scoop_reach=", snappedf(float(npc.get("scoop_reach_a")), 0.001))

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func npc_by_type_role(want_type: String, want_role: String) -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == want_type and str(n.get("role")) == want_role:
			return n
	return null

func run_pet(friendly: Node) -> void:
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	player.set("velocity", Vector3.ZERO)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X
	# Approach from the WEST: the bench east of this lawn spot can
	# block the trot in and stall the approach (seen in one run).
	(friendly as Node3D).global_position = (player as Node3D).global_position + Vector3(-2.0, 0, 0)
	friendly.set("notice", 0.0)
	friendly.set("joy_shown", false)
	friendly.set("interact_cooldown", 0.0)
	await wait_sec(0.3)
	main.call("_paw_action")
	friendly.set("interact_kind", "pet")
	# Poll for the deepest point: state "pet" with the kneel full.
	var guard: float = 0.0
	var min_hand: float = 999.0
	while guard < 10.0:
		await wait_sec(0.05)
		guard += 0.05
		if str(friendly.get("interact_state")) == "pet":
			min_hand = minf(min_hand, float(friendly.get("last_hand_dist")))
		if str(friendly.get("interact_state")) == "pet" and float(friendly.get("bend_a")) >= 0.985:
			break
	print("pet deepest reached: state=", str(friendly.get("interact_state")), " bend_a=", str(friendly.get("bend_a")), " min_hand=", str(min_hand))
	if str(friendly.get("interact_state")) != "pet":
		# The trot-in flaked (she can stall en route): stage the
		# pet directly at the canonical stop distance so the pose
		# and the hand measurement still happen, identically in
		# every run.
		print("approach stalled -- direct-staging the pet")
		var cp: Vector3 = (player as Node3D).global_position
		(friendly as Node3D).global_position = cp + Vector3(-0.85, 0, 0)
		(friendly as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X, at the cat
		friendly.set("velocity", Vector3.ZERO)
		friendly.set("interact_kind", "pet")
		friendly.set("interact_t", 0.0)
		friendly.set("pet_contact_frames", 0)
		friendly.set("interact_state", "pet")
		player.call("start_pet_reaction", 2.9)
		guard = 0.0
		while guard < 6.0:
			await wait_sec(0.05)
			guard += 0.05
			if str(friendly.get("interact_state")) == "pet":
				min_hand = minf(min_hand, float(friendly.get("last_hand_dist")))
			if float(friendly.get("bend_a")) >= 0.985:
				break
		print("direct-staged deepest: bend_a=", str(friendly.get("bend_a")), " min_hand=", str(min_hand))
	pose_line("PET", friendly)
	place_cam(friendly as Node3D, 1.0, 2.3, 1.0, 0.0)
	await snap("pet_side.png")
	place_cam(friendly as Node3D, 1.0, 2.3, 1.05, 0.85)
	await snap("pet_threequarter.png")
	print("PET min_hand_dist during approach-to-deepest: ", min_hand)
	# Keep sampling to the end of the interaction: the suite's
	# hand-contact number is the min over the WHOLE pet.
	var full_min: float = min_hand
	var guard2: float = 0.0
	while guard2 < 8.0:
		await wait_sec(0.05)
		guard2 += 0.05
		if str(friendly.get("interact_state")) == "pet":
			full_min = minf(full_min, float(friendly.get("last_hand_dist")))
		if str(friendly.get("interact_state")) == "":
			break
	print("PET FULL-PET min_hand_dist: ", full_min, " contact_frames: ", int(friendly.get("pet_contact_frames")))

func run_scoop(woman: Node) -> void:
	(player as Node3D).global_position = Vector3(60, 0.2, 84)
	player.set("velocity", Vector3.ZERO)
	(player as Node3D).rotation = Vector3(0, PI * 0.5, 0) # face +X
	player.set("frozen", false)
	(woman as Node3D).global_position = Vector3(61.05, 0.2, 84)
	(woman as Node3D).rotation = Vector3(0, -PI * 0.5, 0) # face -X, at the cat
	woman.set("velocity", Vector3.ZERO)
	woman.set("mode", "wander")
	woman.set("notice", 0.0)
	woman.set("notice_cooldown", 0.0)
	woman.set("grab_progress", 0.0)
	await wait_sec(0.35)
	main.call("on_cat_taken", woman)
	# Poll the real cutscene clock to the end of beat 1 (kneel = 1).
	var guard: float = 0.0
	while guard < 9.0:
		await wait_sec(0.03)
		guard += 0.03
		if str(main.get("state")) == "cutscene" and float(main.get("cutscene_t")) >= 1.08:
			break
	print("scoop deepest reached: cutscene_t=", str(main.get("cutscene_t")), " state=", str(main.get("state")))
	pose_line("SCOOP", woman)
	place_cam(woman as Node3D, 1.0, 2.4, 1.0, 0.0)
	await snap("scoop_side.png")
	place_cam(woman as Node3D, 1.0, 2.4, 1.05, 0.85)
	await snap("scoop_threequarter.png")
	# Let the cutscene finish and reset to play.
	guard = 0.0
	while str(main.get("state")) == "cutscene" and guard < 8.0:
		await wait_sec(0.25)
		guard += 0.25
	if str(main.get("state")) == "escape":
		main.call("_complete_escape")
		(main.get("pursuers") as Dictionary).clear()
		woman.call("stop_pursuit")
	await wait_sec(0.3)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		OUT = BASE + "/" + args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	cam = Camera3D.new()
	cam.far = 800.0
	add_child(cam)
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var _bw: int = 0
	while not bool(main.get("build_complete")) and _bw < 21600:
		await get_tree().process_frame
		_bw += 1
	await wait_sec(1.2)
	player = main.get("player")
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	cam.current = true
	var friendly: Node = npc_by_type_role("woman", "friendly")
	if friendly == null:
		for n in main.get("npcs"):
			if str(n.get("role")) == "friendly":
				friendly = n
				break
	print("friendly: ", str(friendly.get("npc_type")), " / ", str(friendly.get("display_name")))
	await run_pet(friendly)
	park_npcs_far()
	await wait_sec(0.4)
	var woman: Node = npc_by_type_role("woman", "grabber")
	if woman == null:
		for n in main.get("npcs"):
			if str(n.get("role")) == "grabber":
				woman = n
				break
	print("captor: ", str(woman.get("npc_type")), " / ", str(woman.get("display_name")))
	await run_scoop(woman)
	print("DONE")
	get_tree().quit(0)
