extends Node
## MOTION PACING PROBE (v1.0 step 3 diagnostic — not part of the game).
## Run: godot --headless --path . tests/MotionProbe.tscn
## Boots the real Main scene, caps the harness render rate at 120 fps
## (Engine.max_fps — simulating the 120 Hz phone panel; the GAME itself
## keeps max_fps = 0), sprints the cat down the test suite's clear lane
## and samples, once per RENDERED frame: frame delta, cat position,
## camera position. The diagnostic that matters: while sprinting at a
## constant speed, how often is the position presented to the renderer
## UNCHANGED from the previous frame (a "stale" frame — the renderer is
## showing a physics position that is one or more ticks old), and how
## uneven are the per-frame position steps. Stale/uneven steps at a
## 120 Hz presentation rate are exactly the judder/double-image
## mechanism: the world is drawn fresh every frame, but the cat (and
## the camera target) only move on physics ticks.

var main: Node = null
var player: Node = null
var sampling := false
var samples: Array = [] # each: [delta, cat_pos, cam_pos, speed2d]
var phys_start: int = 0
var phys_end: int = 0

func _ready() -> void:
	Engine.max_fps = 120 # harness only: stand-in for the 120 Hz panel
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout
	main.call("dismiss_splash")
	await get_tree().create_timer(0.3).timeout
	main.call("start_game")
	await get_tree().create_timer(0.3).timeout
	player = main.get("player")
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1
	(player as Node3D).global_position = Vector3(30, 0.2, 64)
	await get_tree().create_timer(0.5).timeout
	# Full-push joystick sprint, same drive as the test suite.
	main.set("joy_mouse", true)
	main.set("joy_origin", Vector2(200, 400))
	main.set("joy_current", Vector2(200, 300)) # offset (0,-100) = full push
	await get_tree().create_timer(0.8).timeout # reach top speed
	phys_start = Engine.get_physics_frames()
	sampling = true
	await get_tree().create_timer(2.5).timeout
	sampling = false
	phys_end = Engine.get_physics_frames()
	_report()
	get_tree().quit()

func _process(_delta: float) -> void:
	if sampling and player != null and main != null:
		var cp: Vector3 = (player as Node3D).global_position
		var cam: Camera3D = main.get("cam")
		var camp: Vector3 = cam.global_position if cam != null else Vector3.ZERO
		var v: Vector3 = (player as CharacterBody3D).velocity
		samples.append([_delta, cp, camp, Vector2(v.x, v.z).length()])

func _stats(vals: Array) -> Dictionary:
	var n: int = vals.size()
	if n == 0:
		return {"n": 0}
	var mean: float = 0.0
	for v in vals:
		mean += float(v)
	mean /= n
	var var_sum: float = 0.0
	for v in vals:
		var_sum += (float(v) - mean) * (float(v) - mean)
	var sd: float = sqrt(var_sum / n)
	var sorted: Array = vals.duplicate()
	sorted.sort()
	return {
		"n": n, "mean": mean, "sd": sd,
		"p95": float(sorted[int(0.95 * float(n - 1))]),
		"max": float(sorted[n - 1]),
	}

func _report() -> void:
	var deltas: Array = []
	var cat_steps: Array = []
	var cam_steps: Array = []
	var speeds: Array = []
	var cat_stale: int = 0
	var cam_stale: int = 0
	for i in range(samples.size()):
		deltas.append(float(samples[i][0]))
		speeds.append(float(samples[i][3]))
		if i > 0:
			var cs: float = Vector2(samples[i][1].x - samples[i - 1][1].x, samples[i][1].z - samples[i - 1][1].z).length()
			var ms: float = Vector2(samples[i][2].x - samples[i - 1][2].x, samples[i][2].z - samples[i - 1][2].z).length()
			cat_steps.append(cs)
			cam_steps.append(ms)
			if cs < 0.001:
				cat_stale += 1
			if ms < 0.001:
				cam_stale += 1
	var d: Dictionary = _stats(deltas)
	var cs: Dictionary = _stats(cat_steps)
	var ms: Dictionary = _stats(cam_steps)
	var sp: Dictionary = _stats(speeds)
	var dur: float = 0.0
	for v in deltas:
		dur += float(v)
	print("=== MOTION PROBE ===")
	print("physics_ticks_per_second = ", Engine.physics_ticks_per_second)
	print("rendered frames sampled = ", samples.size(), " over ", snappedf(dur, 0.01), "s (", snappedf(float(samples.size()) / maxf(dur, 0.001), 1.0), " fps presented)")
	print("physics frames during sampling = ", phys_end - phys_start)
	print("cat speed mean = ", snappedf(float(sp.get("mean", 0.0)), 0.01), " (sprint target 11.5)")
	print("frame delta: mean ", snappedf(float(d.get("mean", 0.0)) * 1000.0, 0.01), "ms sd ", snappedf(float(d.get("sd", 0.0)) * 1000.0, 0.01), "ms p95 ", snappedf(float(d.get("p95", 0.0)) * 1000.0, 0.01), "ms max ", snappedf(float(d.get("max", 0.0)) * 1000.0, 0.01), "ms")
	print("CAT per-frame step: mean ", snappedf(float(cs.get("mean", 0.0)), 0.0001), " sd ", snappedf(float(cs.get("sd", 0.0)), 0.0001), " max ", snappedf(float(cs.get("max", 0.0)), 0.0001), " | STALE frames ", cat_stale, "/", cat_steps.size(), " (", snappedf(100.0 * float(cat_stale) / maxf(1.0, float(cat_steps.size())), 1.0), "%)")
	print("CAM per-frame step: mean ", snappedf(float(ms.get("mean", 0.0)), 0.0001), " sd ", snappedf(float(ms.get("sd", 0.0)), 0.0001), " max ", snappedf(float(ms.get("max", 0.0)), 0.0001), " | STALE frames ", cam_stale, "/", cam_steps.size(), " (", snappedf(100.0 * float(cam_stale) / maxf(1.0, float(cam_steps.size())), 1.0), "%)")
	print("=== END PROBE ===")
