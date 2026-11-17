extends RefCounted
## Screenshot-render ONLY emoji fallback (v1.0.8, step 2).
##
## The VM's only system emoji font is a CBDT bitmap font Godot can't
## use, so renders showed Godot's missing-glyph hex boxes for every
## emoji (the 🐾 box literally reads 01F/43E). The monochrome outline
## font staged OUTSIDE the project at
##   /home/hatch/workspace/homeward/render-fonts/NotoEmoji-Regular.ttf
## fixes renders when wired as a fallback — and ONLY renders: this
## helper is called exclusively by shot-runner harnesses under
## tests/, the font file never enters the project, project.godot
## never references it, and the shipped game (which renders emoji
## via the phone's own fonts) is completely unaffected.
##
## Usage from a shot runner, BEFORE the Main scene is instanced:
##   const EmojiFont := preload("res://tests/emoji_font.gd")
##   EmojiFont.apply()

const FONT_PATH := "/home/hatch/workspace/homeward/render-fonts/NotoEmoji-Regular.ttf"

static func apply() -> void:
	if not FileAccess.file_exists(FONT_PATH):
		print("EMOJI FONT: not found at ", FONT_PATH, " — renders keep the hex boxes")
		return
	var ff := FontFile.new()
	var err := ff.load_dynamic_font(FONT_PATH)
	if err != OK:
		print("EMOJI FONT: load_dynamic_font failed, err=", err)
		return
	# Wrap the current default font so text rendering falls back to
	# Noto Emoji only for glyphs the default font lacks (the emoji).
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	var fb: Array[Font] = [ff]
	variation.fallbacks = fb
	ThemeDB.fallback_font = variation
	# The mechanism that actually reaches the game's text (verified
	# with tests/font_probe2.gd): both Control labels and Label3D
	# resolve their font through the DEFAULT THEME's default font —
	# the ThemeDB.fallback_font assignment alone changes neither at
	# runtime in 4.2.2, and neither does a Window theme. Swapping the
	# default theme's font here, inside the runner process only,
	# fixes every label in the run. The shipped game never runs this.
	var dt: Theme = ThemeDB.get_default_theme()
	if dt != null:
		dt.default_font = variation
	print("EMOJI FONT: Noto Emoji wired via default-theme font (render-run only)")
