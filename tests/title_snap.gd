extends Node
## v1.0.10 title still (rendered, Xvfb): boots Main, dismisses the
## splash, waits for the title to settle, captures the title panel
## (version tag lives here), quits.
## v1.0.14: also prints a narration scan — the boot readout, the
## "Loading the town…" note and the safe-mode note must NOT exist.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1010"
var main: Node = null
var phase: int = 0
var t: float = 0.0

func narration_label_count() -> int:
	# v1.0.14: count VISIBLE labels anywhere under Main carrying
	# loading narration — boot stages, the old splash loading note,
	# or the old safe-mode note. Must always be 0 now.
	var n := 0
	var stack: Array = [main]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		var lab := node as Label
		if lab and lab.visible:
			var tx := lab.text
			if tx.contains("Safe mode") or tx.contains("Loading the town") or tx.contains("Boot:") or tx.contains("% —") or tx.contains("Showing the town"):
				n += 1
	return n

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)

func _process(delta: float) -> void:
	if main == null:
		return
	if phase == 0 and bool(main.get("build_complete")):
		main.call("dismiss_splash")
		phase = 1
	elif phase == 1:
		t += delta
		if t > 1.0:
			phase = 2
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(OUT + "/title_panel.png")
			print("TS: snapped title, safe_mode=", str(main.get("boot_safe_mode")), " narration_labels=", narration_label_count(), " readout_vars_null=", str(main.get("boot_stage_label") == null and main.get("safe_note_label") == null and main.get("splash_loading_label") == null))
			get_tree().quit()
