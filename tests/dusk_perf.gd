extends Node
## HOMEWARD dusk-step mini perf sampler (diagnostic — not part of
## the game). The full PerfProbe's micro-benchmarks take many
## minutes on this VM; this sampler measures only what the dusk
## pass can affect: steady-state draw calls / prims / objects at
## the standard spawn viewpoint, same staging hygiene as
## PerfProbe (notice cooldowns pinned so nothing chases).
##   xvfb-run -a godot --path . tests/DuskPerf.tscn

var main: Node = null
var sampling := false
var acc := {}

func _process(_delta: float) -> void:
	if not sampling:
		return
	acc["frames"] += 1
	acc["draws"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	acc["prims"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	acc["objs"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var ps: PackedScene = load("res://scenes/Main.tscn")
	main = ps.instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout
	main.call("dismiss_splash")
	await get_tree().create_timer(0.3).timeout
	main.call("start_game")
	await get_tree().create_timer(0.5).timeout
	for n in main.get("npcs"):
		n.set("notice_cooldown", 99999.0)
	acc = {"frames": 0, "draws": 0.0, "prims": 0.0, "objs": 0.0}
	sampling = true
	await get_tree().create_timer(8.0).timeout
	sampling = false
	var f: float = maxf(1.0, float(acc["frames"]))
	print("DUSKPERF frames=", int(f),
		" draw_calls=", int(acc["draws"] / f),
		" prims=", int(acc["prims"] / f),
		" objects=", int(acc["objs"] / f))
	# Attribution phase: same viewpoint, sun shadows OFF. The
	# difference isolates the shadow pass cost at this sun angle.
	var suns: Array = []
	_find_all(main, "DirectionalLight3D", suns)
	for s in suns:
		(s as DirectionalLight3D).shadow_enabled = false
	acc = {"frames": 0, "draws": 0.0, "prims": 0.0, "objs": 0.0}
	sampling = true
	await get_tree().create_timer(6.0).timeout
	sampling = false
	f = maxf(1.0, float(acc["frames"]))
	print("DUSKPERF_NOSHADOW frames=", int(f),
		" draw_calls=", int(acc["draws"] / f),
		" prims=", int(acc["prims"] / f),
		" objects=", int(acc["objs"] / f))
	get_tree().quit()

func _find_all(n: Node, type_name: String, out: Array) -> void:
	if n.is_class(type_name):
		out.append(n)
	for ch in n.get_children():
		_find_all(ch, type_name, out)
