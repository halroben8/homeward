extends Node
## HOMEWARD v1.0.10 verification driver (rendered, Xvfb):
##   xvfb-run -a godot --path . tests/BootStageDriver.tscn [-- --plant-marker]
## Normal mode: boots Main, records boot-stage progression from the
## crash-marker file, counts visible World children per frame to
## prove the staged reveal has intermediate states, snaps 2
## intermediate reveal frames, dismisses the splash, waits for the
## title-stable marker completion, starts play, plays briefly, quits.
## --plant-marker: first writes an INCOMPLETE boot marker, then boots
## and verifies safe mode engaged (sun shadow off), still reaches
## title/play, and completes the marker.
## v1.0.14: the on-screen boot readout / "Loading the town…" note /
## safe-mode note no longer exist — the driver also asserts that no
## narration text is on screen and the old label vars are gone.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1010"
var main: Node = null
var phase: String = "boot"
var last_stage: String = ""
var stage_seq: Array = []
var vis_counts: Array = []
var last_vis: int = -1
var snaps: int = 0
var title_t: float = 0.0
var play_t: float = 0.0
var plant: bool = false
var done: bool = false
var marker_poll_t: float = 0.0

func narration_label_count() -> int:
	# v1.0.14: count VISIBLE labels anywhere under Main carrying
	# loading narration — boot stages ("Placing houses 55% — …"),
	# the old splash loading note, or the old safe-mode note.
	# Must always be 0 now.
	var n := 0
	var stack: Array = [main]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		var lab := node as Label
		if lab and lab.visible:
			var t := lab.text
			if t.contains("Safe mode") or t.contains("Loading the town") or t.contains("Boot:") or t.contains("% —") or t.contains("Showing the town"):
				n += 1
	return n

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	plant = args.has("--plant-marker")
	if plant:
		var f := FileAccess.open("user://boot_marker.txt", FileAccess.WRITE)
		if f:
			f.store_string("Showing the town 2/4 86%")
			f.close()
		print("BSD: planted incomplete marker")
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("BSD: snapped ", name)

func _process(delta: float) -> void:
	if main == null or done:
		return
	# v1.0.14: stages are tracked via the crash-marker file now (the
	# on-screen readout it used to mirror is removed). Poll ~4x/s.
	marker_poll_t += delta
	if marker_poll_t >= 0.25:
		marker_poll_t = 0.0
		var mf2 := FileAccess.open("user://boot_marker.txt", FileAccess.READ)
		if mf2:
			var mt := mf2.get_as_text().strip_edges()
			mf2.close()
			if mt != last_stage and mt != "" and mt != "starting" and mt != "title" and mt != "complete":
				last_stage = mt
				stage_seq.append(mt)
				print("BSD: stage -> ", mt)
	var world: Node = main.get_node_or_null("World")
	if world:
		var vc := 0
		for c in world.get_children():
			if (c as Node3D) and (c as Node3D).visible:
				vc += 1
		if vc != last_vis:
			last_vis = vc
			vis_counts.append(vc)
			print("BSD: world visible children = ", vc, " / ", world.get_child_count())
			if vc > 0 and vc < world.get_child_count() and snaps < 2 and phase == "boot":
				snaps += 1
				# Hide the (opaque) splash in the DRIVER ONLY so the
				# frame actually shows the partially revealed town.
				(main.get("splash_panel") as Control).visible = false
				snap("reveal_mid_%d.png" % snaps)
	match phase:
		"boot":
			if bool(main.get("build_complete")):
				print("BSD: build_complete; stages=", stage_seq, " narration_labels_on_splash=", narration_label_count())
				print("BSD: vis_count_sequence=", vis_counts)
				snap("after_reveal.png")
				main.call("dismiss_splash")
				phase = "title"
		"title":
			title_t += delta
			var mf := FileAccess.open("user://boot_marker.txt", FileAccess.READ)
			var mtxt := ""
			if mf:
				mtxt = mf.get_as_text().strip_edges()
				mf.close()
			if mtxt == "complete":
				print("BSD: marker complete after title stable (t=", snappedf(title_t, 0.1), ") safe_mode=", str(main.get("boot_safe_mode")), " sun_shadow=", str((main.get("sun_light") as DirectionalLight3D).shadow_enabled), " narration_labels=", narration_label_count(), " readout_vars_null=", str(main.get("boot_stage_label") == null and main.get("safe_note_label") == null and main.get("splash_loading_label") == null))
				snap("title.png")
				main.call("start_game")
				phase = "play"
			elif title_t > 30.0:
				print("BSD: FAIL marker never completed, marker='", mtxt, "'")
				done = true
				get_tree().quit(1)
		"play":
			play_t += delta
			if play_t > 3.0:
				print("BSD: play OK state=", str(main.get("state")), " stages=", stage_seq.size())
				snap("play.png")
				done = true
				get_tree().quit()
