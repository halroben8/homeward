extends Node3D
## Diagnostic #2: which runtime mechanism actually makes emoji render?
##   xvfb-run -a godot --path . tests/FontProbe2.tscn -- <mode>
## Modes: none | themedb | window | windowonly
## Frame contains: plain Label, direct-font Label, plain Label3D,
## direct-font Label3D — all showing the same emoji string.

const PATH := "/home/hatch/workspace/homeward/render-fonts/NotoEmoji-Regular.ttf"
const TXT := "🐾🍪👀"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var args := OS.get_cmdline_user_args()
	var mode := "none"
	if args.size() > 0:
		mode = args[0]
	print("PROBE2 mode=", mode)
	var ff := FontFile.new()
	ff.load_dynamic_font(PATH)
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	var fb: Array[Font] = [ff]
	variation.fallbacks = fb
	if mode == "themedb" or mode == "window":
		ThemeDB.fallback_font = variation
	if mode == "defaulttheme":
		print("PROBE2 ThemeDB has get_default_theme: ", ThemeDB.has_method("get_default_theme"))
		var dt = ThemeDB.call("get_default_theme")
		print("PROBE2 default theme: ", dt)
		if dt != null:
			dt.set("default_font", variation)
			print("PROBE2 default theme font now: ", dt.get("default_font"))
	if mode == "window" or mode == "windowonly":
		var theme := Theme.new()
		theme.default_font = variation
		get_window().theme = theme
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 6)
	add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var l1 := Label.new()
	l1.text = "PLAIN-LABEL " + TXT
	l1.position = Vector2(40, 30)
	l1.add_theme_font_size_override("font_size", 44)
	layer.add_child(l1)
	var l2 := Label.new()
	l2.text = "DIRECT-LABEL " + TXT
	l2.position = Vector2(40, 100)
	l2.add_theme_font_size_override("font_size", 44)
	l2.add_theme_font_override("font", variation)
	layer.add_child(l2)
	var l3 := Label3D.new()
	l3.text = "PLAIN-3D " + TXT
	l3.position = Vector3(0, 0.9, 0)
	l3.font_size = 96
	l3.pixel_size = 0.008
	add_child(l3)
	var l4 := Label3D.new()
	l4.text = "DIRECT-3D " + TXT
	l4.position = Vector3(0, -0.9, 0)
	l4.font_size = 96
	l4.pixel_size = 0.008
	l4.font = variation
	add_child(l4)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("/tmp/fontprobe2_" + mode + ".png")
	print("PROBE2 snapped ", mode)
	get_tree().quit(0)
