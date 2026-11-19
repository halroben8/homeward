extends Node
## TEMPORARY v1.0.9 post-splash crash probe (rendered, Xvfb):
##   xvfb-run -a godot --path . tests/RevealProbe.tscn
## Boots Main on the real renderer and STREAMS one RP: line per
## frame with the WALL-CLOCK gap since the previous _process call
## (engine deltas are clamped to 8 physics steps and hide real
## frame cost). Covers the moment build_complete flips (the world
## reveal) plus the following title/splash frames — the exact
## window where Michael's S26 dies.

var main: Node = null
var frame_no: int = 0
var flipped: bool = false
var after: int = 0
var last_ms: int = 0
var t0_ms: int = 0
var max_after: float = 0.0

func _ready() -> void:
	t0_ms = Time.get_ticks_msec()
	last_ms = t0_ms
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)

func _process(_delta: float) -> void:
	if main == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	var gap: float = (now_ms - last_ms) / 1000.0
	last_ms = now_ms
	frame_no += 1
	if not flipped:
		if frame_no % 5 == 0 or gap > 0.5:
			print("RP: pre-flip frame ", frame_no, " wall_gap=%.3f" % gap, " t=", (now_ms - t0_ms) / 1000.0)
		if bool(main.get("build_complete")):
			flipped = true
			print("RP: FLIP at frame ", frame_no, " wall_gap_into_flip=%.3f" % gap, " state=", str(main.get("state")), " rss=", OS.get_static_memory_usage())
	else:
		after += 1
		if gap > max_after:
			max_after = gap
		print("RP: post-flip frame ", after, " wall_gap=%.3f" % gap, " max=%.3f" % max_after, " state=", str(main.get("state")))
		if after >= 15:
			print("RP: DONE max_post_flip_wall=%.3f" % max_after, " rss=", OS.get_static_memory_usage())
			get_tree().quit()
