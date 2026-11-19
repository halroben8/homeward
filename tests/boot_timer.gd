extends Node
## HOMEWARD v1.0.9 boot-timing harness (run under Xvfb, NOT headless):
##   xvfb-run -a godot --path . tests/BootTimer.tscn
## Measures (a) launch -> first PRESENTED frame and (b) launch ->
## world build complete, on the real renderer. Works pre- and
## post-fix: post-fix it waits on Main.build_complete; pre-fix
## (no such property) it falls back to "spawns all present".

var t0: int = 0
var first_frame_ms: int = -1
var first_process_ms: int = -1
var main: Node = null

func _process(_delta: float) -> void:
	if first_process_ms < 0:
		first_process_ms = Time.get_ticks_msec() - t0

func _ready() -> void:
	t0 = Time.get_ticks_msec()
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var has_flag: bool = false
	for p in main.get_property_list():
		if str(p["name"]) == "build_complete":
			has_flag = true
	var guard: int = 0
	while guard < 60 * 300: # up to ~5 min of frames — never hang CI
		if has_flag:
			if bool(main.get("build_complete")):
				break
		else:
			if main.get("player") != null and (main.get("npcs") as Array).size() == 48 and main.get("pound_van") != null:
				break
		await get_tree().process_frame
		guard += 1
	var done_ms: int = Time.get_ticks_msec() - t0
	await get_tree().create_timer(0.5).timeout
	print("BOOT_TIMER first_frame_ms=", first_frame_ms)
	print("BOOT_TIMER first_process_ms=", first_process_ms)
	print("BOOT_TIMER build_done_ms=", done_ms)
	print("BOOT_TIMER state=", str(main.get("state")), " npcs=", (main.get("npcs") as Array).size(), " houses=", (main.get("houses") as Array).size())
	get_tree().quit()

func _on_frame_post_draw() -> void:
	if first_frame_ms < 0:
		first_frame_ms = Time.get_ticks_msec() - t0
		print("BOOT_TIMER first frame presented at ", first_frame_ms, " ms")
