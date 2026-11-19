extends Node
## v1.0.14 verification (rendered, Xvfb): the splash must carry NO
## loading/process text — no boot-stage readout, no "Loading the
## town…" note, no safe-mode note.
##   xvfb-run -a godot --path . tests/SplashSnap.tscn
## Boots Main, snaps the splash WHILE the town is still streaming in
## (the moment the readout used to sit over the Tap to Start button),
## taps START early (the tap must queue, not start into a half-built
## town), waits for the build to land and the queued tap to open the
## title, snaps the title, then starts the game and confirms the
## opening cutscene begins. Any narration label found = failure.

const OUT := "/home/hatch/workspace/homeward/screenshots_v1014"
var main: Node = null
var phase: int = 0
var t: float = 0.0
var failures: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)

func narration_label_count() -> int:
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

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SS: snapped ", name)

func expect_clean(when: String) -> void:
	var n := narration_label_count()
	print("SS: narration_labels ", when, " = ", n)
	if n != 0:
		failures += 1
		print("SS: FAIL narration text visible ", when)

func _process(delta: float) -> void:
	if main == null:
		return
	t += delta
	match phase:
		0: # splash up, build streaming in behind it
			if t > 1.5:
				t = 0.0
				print("SS: mid-build state=", str(main.get("state")), " build_complete=", str(main.get("build_complete")), " splash_visible=", str((main.get("splash_panel") as Control).visible))
				expect_clean("during build (splash)")
				snap("splash_during_build.png")
				# Michael's flow: hit START before the town is ready —
				# the tap must queue and fire when the build lands.
				main.call("dismiss_splash")
				print("SS: early START tap; state after tap=", str(main.get("state")), " (must still be splash)")
				if str(main.get("state")) != "splash":
					failures += 1
					print("SS: FAIL early tap did not queue")
				phase = 1
		1: # build lands -> queued tap opens the title on its own
			if str(main.get("state")) == "title":
				t = 0.0
				print("SS: queued tap opened title; build_complete=", str(main.get("build_complete")))
				expect_clean("on title")
				snap("title.png")
				phase = 2
			elif t > 600.0:
				failures += 1
				print("SS: FAIL title never opened after build")
				get_tree().quit(1)
		2: # start the game -> the opening cutscene must begin
			if t > 1.0:
				main.call("start_game")
				phase = 3
				t = 0.0
		3:
			if t > 1.5:
				var st := str(main.get("state"))
				var story: Node = main.get("story")
				print("SS: after START state=", st, " story_active=", str(story.get("active") if story else "no-story"))
				if st != "opening":
					failures += 1
					print("SS: FAIL opening did not begin")
				expect_clean("in opening")
				snap("opening_start.png")
				print("SS: done, failures=", failures)
				get_tree().quit(1 if failures > 0 else 0)
