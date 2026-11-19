extends Node
## PET/TREAT PROBE — diagnosis harness for Michael's two reports:
## (1) pets only SOMETIMES count while he's visibly being petted;
## (2) treats NEVER happen (HUD Treats stuck at 0).
## Drives the REAL player path: boot the real Main scene, play the
## opening out into town (the suite's own proven route), then run
## N friendly encounters exactly as a player makes them — the cat
## stands in the open, the friendly NPC is nearby, the player PAWs
## (main._paw_action). NOTHING is forced: interact_kind is whatever
## react_to_attention rolls. Per encounter we log the rolled kind,
## the states traversed, the hand-to-back distance through the pet
## (min + the value at every sample), pet_contact_frames, and the
## score/pets/treats deltas — so the award gate can be seen failing
## (or passing) with numbers.
##   godot --headless --path . tests/PetTreatProbe.tscn
## Prints ENCOUNTER lines + a SUMMARY block.

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		n.set("wander_target", (n as Node3D).global_position)
		n.set("wander_wait", 5.0)
		i += 1

# --- boot-to-play helpers copied from test_runner.gd (proven) ---
func distract_captor() -> void:
	var props: Array = main.get("distract_props")
	var base: Vector3 = props[0]["base"]
	(player as Node3D).global_position = base + Vector3(0.9, 0.3, 0.9)
	main.call("topple_prop_at_cat")
	var guard: int = 0
	while not bool(main.call("captor_distracted")) and guard < 40:
		main.call("_process_escape", 0.25)
		guard += 1

func drive_escape_panel() -> void:
	main.call("_on_escape_prompt_pressed")
	for inp in ["down", "up", "down", "up", "paw"]:
		main.call("escape_panel_input", inp)

func walk_cat_out() -> void:
	var kind: String = str(main.get("exit_open_kind"))
	var o: Vector3 = main.get("escape_origin")
	match kind:
		"latch", "winpush":
			(player as Node3D).global_position = o + Vector3(0, 0.3, -11.2)
		"petdoor", "carrier":
			(player as Node3D).global_position = o + Vector3(6, 0.3, -11.2)
		"bolt":
			(player as Node3D).global_position = o + Vector3(15.2, 0.3, 3.4)
	for i in range(8):
		if str(main.get("state")) != "escape":
			break
		main.call("_process_escape", 0.25)

func boot_to_play() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(1.0)
	player = main.get("player")
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.4)
	var story_mod: Node = main.get("story")
	story_mod.call("skip_opening")
	await wait_sec(0.4)
	var gate_p: Vector3 = story_mod.call("cage_gate_pos")
	(player as Node3D).global_position = gate_p + Vector3(0, 0.3, 0.8)
	main.call("_on_interact")
	await wait_sec(0.3)
	distract_captor()
	(player as Node3D).global_position = Vector3(573.4, 0.3, 3.4)
	drive_escape_panel()
	walk_cat_out()
	await wait_sec(0.3)
	var worker: Node = main.get("pound_worker")
	worker.call("stop_pursuit")
	(main.get("pursuers") as Dictionary).erase(worker)
	main.set("pound_engage_cd", 99999.0)
	main.set("pound_state", "patrol")
	worker.set("active", false)
	(worker as Node3D).visible = false
	print("BOOT: state=", str(main.get("state")))

func run_encounter(idx: int, npc: Node, bearing_deg: float, cat_facing_deg: float) -> Dictionary:
	var arena := Vector3(100, 0.2, 80)
	# Stage the cat: still, facing a fixed way, no idle antics.
	(player as Node3D).global_position = arena
	(player as Node3D).rotation = Vector3(0, deg_to_rad(cat_facing_deg), 0)
	player.set("velocity", Vector3.ZERO)
	player.set("idle_next_in", 999.0)
	# Stage the NPC 2.0 m away at the bearing (paw range is 3.2).
	var b: float = deg_to_rad(bearing_deg)
	(npc as Node3D).global_position = arena + Vector3(sin(b), 0, cos(b)) * 2.0 + Vector3(0, 0.0, 0)
	npc.set("velocity", Vector3.ZERO)
	npc.set("mode", "wander")
	npc.set("notice", 0.0)
	npc.set("joy_shown", false)
	npc.set("interact_cooldown", 0.0)
	npc.set("interact_state", "")
	npc.set("wander_target", (npc as Node3D).global_position)
	npc.set("wander_wait", 5.0)
	await wait_sec(0.35)
	# Re-pin the cat (physics may have nudged him).
	(player as Node3D).global_position = arena
	(player as Node3D).rotation = Vector3(0, deg_to_rad(cat_facing_deg), 0)
	player.set("velocity", Vector3.ZERO)
	var score0: int = int(main.get("score"))
	var pets0: int = int(main.get("pets_count"))
	var treats0: int = int(main.get("treats_count"))
	# THE REAL PLAYER ACTION.
	main.call("_paw_action")
	var kind: String = ""
	var states: Array = []
	var min_hand: float = 999.0
	var hand_samples: Array = []
	var max_contact: int = 0
	var saw_any: bool = false
	var elapsed: float = 0.0
	while elapsed < 14.0:
		await wait_sec(0.15)
		elapsed += 0.15
		var st: String = str(npc.get("interact_state"))
		if st != "":
			saw_any = true
			if kind == "":
				kind = str(npc.get("interact_kind"))
			if not states.has(st):
				states.append(st)
			if st == "pet":
				var hd: float = float(npc.get("last_hand_dist"))
				min_hand = minf(min_hand, hd)
				hand_samples.append(snappedf(hd, 0.001))
				max_contact = maxi(max_contact, int(npc.get("pet_contact_frames")))
		elif saw_any:
			break
	var res: Dictionary = {
		"idx": idx, "npc": str(npc.get("display_name")), "type": str(npc.get("npc_type")),
		"mscale": float(npc.get("mscale")), "bearing": bearing_deg, "facing": cat_facing_deg,
		"kind": kind, "states": states, "min_hand": min_hand,
		"contact_frames": max_contact, "hand_samples": hand_samples,
		"pets_d": int(main.get("pets_count")) - pets0,
		"treats_d": int(main.get("treats_count")) - treats0,
		"score_d": int(main.get("score")) - score0,
		"award_fired": bool(npc.get("award_fired")),
	}
	# Park the NPC away again.
	(npc as Node3D).global_position = Vector3(-110 + float(idx) * 2.0, 0.2, 80)
	npc.set("wander_target", (npc as Node3D).global_position)
	npc.set("wander_wait", 5.0)
	await wait_sec(0.3)
	return res

func _ready() -> void:
	await wait_sec(0.5)
	await boot_to_play()
	park_npcs_far()
	await wait_sec(0.5)
	var friendlies: Array = []
	for n in main.get("npcs"):
		if str(n.get("role")) == "friendly":
			friendlies.append(n)
	print("FRIENDLIES: ", friendlies.size())
	var results: Array = []
	var n_enc: int = 12
	for i in range(n_enc):
		var npc: Node = friendlies[i % friendlies.size()]
		var bearing: float = float(i) * 30.0
		var facing: float = float(i % 4) * 90.0
		var r: Dictionary = await run_encounter(i, npc, bearing, facing)
		results.append(r)
		print("ENCOUNTER ", r["idx"], ": npc=", r["npc"], " type=", r["type"],
			" mscale=", snappedf(float(r["mscale"]), 0.001),
			" bearing=", r["bearing"], " cat_facing=", r["facing"],
			" kind=", r["kind"], " states=", r["states"],
			" min_hand=", (snappedf(float(r["min_hand"]), 0.0001) if float(r["min_hand"]) < 900.0 else -1),
			" contact_frames=", r["contact_frames"],
			" award_fired=", r["award_fired"],
			" pets_d=", r["pets_d"], " treats_d=", r["treats_d"], " score_d=", r["score_d"])
		print("  hand_samples=", r["hand_samples"])
	# Summary
	var pet_enc: int = 0
	var pet_ok: int = 0
	var treat_enc: int = 0
	var treat_ok: int = 0
	for r in results:
		if str(r["kind"]) == "pet":
			pet_enc += 1
			if int(r["pets_d"]) > 0:
				pet_ok += 1
		elif str(r["kind"]) == "treat":
			treat_enc += 1
			if int(r["treats_d"]) > 0:
				treat_ok += 1
	print("SUMMARY: encounters=", results.size(),
		" pet_kind=", pet_enc, " pets_awarded=", pet_ok,
		" treat_kind=", treat_enc, " treats_awarded=", treat_ok)
	print("PROBE DONE")
	get_tree().quit(0)
