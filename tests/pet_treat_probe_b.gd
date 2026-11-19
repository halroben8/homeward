extends Node
## PET/TREAT PROBE B — the MEOW path from distance. In real play a
## meow makes every friendly NPC within 8 m react and TROT OVER.
## The approach state gives up if it takes > 4.5 s — from 6-8 m at
## trot speed that budget is marginal. This probe meows with one
## friendly NPC staged 6.0 m away (cat standing still, as a player
## waiting to be petted) and records whether the interaction ever
## completes, the rolled kind, and the award deltas.
##   godot --headless --path . tests/PetTreatProbeB.tscn

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

func run_meow_encounter(idx: int, npc: Node, dist_m: float, bearing_deg: float) -> Dictionary:
	var arena := Vector3(100, 0.2, 80)
	(player as Node3D).global_position = arena
	(player as Node3D).rotation = Vector3.ZERO
	player.set("velocity", Vector3.ZERO)
	player.set("idle_next_in", 999.0)
	var b: float = deg_to_rad(bearing_deg)
	(npc as Node3D).global_position = arena + Vector3(sin(b), 0, cos(b)) * dist_m
	npc.set("velocity", Vector3.ZERO)
	npc.set("mode", "wander")
	npc.set("notice", 0.0)
	npc.set("joy_shown", false)
	npc.set("interact_cooldown", 0.0)
	npc.set("interact_state", "")
	npc.set("wander_target", (npc as Node3D).global_position)
	npc.set("wander_wait", 5.0)
	await wait_sec(0.35)
	(player as Node3D).global_position = arena
	player.set("velocity", Vector3.ZERO)
	var score0: int = int(main.get("score"))
	var pets0: int = int(main.get("pets_count"))
	var treats0: int = int(main.get("treats_count"))
	main.set("meow_cooldown", 0.0)
	main.call("_on_meow")
	var kind: String = ""
	var states: Array = []
	var saw_any: bool = false
	var min_hand: float = 999.0
	var elapsed: float = 0.0
	while elapsed < 16.0:
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
				min_hand = minf(min_hand, float(npc.get("last_hand_dist")))
		elif saw_any:
			break
	var res: Dictionary = {
		"idx": idx, "npc": str(npc.get("display_name")), "dist": dist_m,
		"kind": kind, "states": states,
		"min_hand": (snappedf(min_hand, 0.0001) if min_hand < 900.0 else -1),
		"pets_d": int(main.get("pets_count")) - pets0,
		"treats_d": int(main.get("treats_count")) - treats0,
		"score_d": int(main.get("score")) - score0,
	}
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
	var done: int = 0
	var awarded: int = 0
	for i in range(8):
		var npc: Node = friendlies[i % friendlies.size()]
		var r: Dictionary = await run_meow_encounter(i, npc, 6.0, float(i) * 45.0)
		if (r["states"] as Array).has("pet") or (r["states"] as Array).has("treat"):
			done += 1
		if int(r["score_d"]) > 0:
			awarded += 1
		print("MEOW_ENCOUNTER ", r["idx"], ": npc=", r["npc"], " dist=", r["dist"],
			" kind=", r["kind"], " states=", r["states"], " min_hand=", r["min_hand"],
			" pets_d=", r["pets_d"], " treats_d=", r["treats_d"], " score_d=", r["score_d"])
	print("MEOW_SUMMARY: ran=8 completed=", done, " awarded=", awarded)
	print("PROBE B DONE")
	get_tree().quit(0)
