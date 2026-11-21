extends Control
## HOMEWARD v1.1 — the ESCAPE PANEL (Michael's design, 2026-11-16).
## A dialogue-style overlay that appears when the captured cat works
## an exit mechanism: a big close-up picture of the mechanism (window
## latch / window push / pet-door flap / back-door bolt / carrier
## door) and the combination shown as chips. v1.0.21 (Michael's
## direction, replacing the v1.1 swipe combo): the combination is a
## sequence of the A and B buttons (A = the game's HOP button,
## B = PAW), FIVE presses, RANDOMLY ROLLED by main every time the
## puzzle starts. v1.0.22 (Michael's direction): the combination is
## entered on the game's OWN on-screen A / B buttons — the duplicate
## on-panel A / B buttons v1.0.21 added here are GONE; main claims
## presses on the HUD buttons' rects on the raw touch channel while
## the panel is open and routes them in (the PC hop / paw keys are
## routed by main too). Correct inputs light the chips
## and work the pictured mechanism a notch; a wrong input gently
## slips the sequence back — no punishment. v1.2: the captor is in
## the room (main3d.gd) — the status strip across the picture shows
## the captor's distraction window, or the "watching" warning:
## undistracted, the captor notices and closes the panel within
## about a second. (v1.0.19: the status STRINGS are built by main
## from the captor's own pronoun definition — see person.gd.)
## All game logic lives in main3d.gd; this is the view + input surface.
## main wires: on_input("A"|"B"), on_close(). main rolls the combo
## (see _roll_escape_combo there) and hands it over via set_combo_seq
## before open_for; the chips below draw THIS sequence.

var mechanism: String = "latch" # latch | winpush | petdoor | bolt | carrier
var combo_index: int = 0
var combo: Array = ["A", "B", "A", "B", "A"] # placeholder until main hands over the rolled one
var on_input: Callable = Callable()
var on_close: Callable = Callable()

# v1.2: the distraction status strip (set by main each frame while the
# panel is open): either the countdown of the distraction window
# (green) or the "watching" warning filling up (red).
var status_text: String = ""
var status_frac: float = -1.0 # <0 = no bar
var status_warn: bool = false

func set_status(text: String, frac: float, warn: bool) -> void:
	status_text = text
	status_frac = frac
	status_warn = warn
	queue_redraw()

var _font: Font = null
var _slip_t: float = 0.0
var _nudge_t: float = 0.0 # brief carrier rattle after a correct input

var _title_label: Label = null
var _hint_label: Label = null
var _slip_label: Label = null
var _close_btn: Button = null

const BOX_W := 880.0
const BOX_H := 570.0
const BRASS := Color(0.85, 0.65, 0.28)
const BRASS_DARK := Color(0.5, 0.4, 0.2)
const CREAM := Color(0.96, 0.94, 0.9)
const WOOD := Color(0.62, 0.45, 0.28)
const SKY := Color(0.45, 0.68, 0.95)
const HOLE := Color(0.05, 0.05, 0.09)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75))
	add_child(_title_label)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_hint_label.text = "Tap the combination on the A and B buttons — it's a new one every time!"
	add_child(_hint_label)
	_slip_label = Label.new()
	_slip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slip_label.add_theme_font_size_override("font_size", 24)
	_slip_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	_slip_label.visible = false
	add_child(_slip_label)
	# v1.0.22: NO A / B buttons on the panel — the combo is entered
	# on the game's own HUD A (HOP) / B (PAW) buttons (see header).
	_close_btn = Button.new()
	_close_btn.focus_mode = Control.FOCUS_NONE # v1.0.22: no focus square on any touch button
	_close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_close_btn.text = "✕"
	_close_btn.add_theme_font_size_override("font_size", 22)
	var close_col := Color(0.55, 0.3, 0.28, 0.9)
	_close_btn.add_theme_stylebox_override("normal", _round_style(close_col, 44))
	_close_btn.add_theme_stylebox_override("pressed", _round_style(close_col.lightened(0.25), 44))
	_close_btn.add_theme_stylebox_override("hover", _round_style(close_col, 44))
	_close_btn.pressed.connect(func() -> void:
		if on_close.is_valid():
			on_close.call())
	add_child(_close_btn)
	_layout()

func _round_style(color: Color, diameter: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	var r: int = diameter / 2
	s.corner_radius_top_left = r; s.corner_radius_top_right = r
	s.corner_radius_bottom_left = r; s.corner_radius_bottom_right = r
	s.border_color = Color(1, 1, 1, 0.7)
	s.set_border_width_all(2)
	return s

func _box_rect() -> Rect2:
	# The panel fills the screen at the origin, so the viewport size
	# IS the panel's size — read it directly rather than trusting the
	# control rect (which anchor timing can leave at 0).
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(BOX_W, vp.x - 24.0)
	var h: float = minf(BOX_H, vp.y - 24.0)
	return Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)

func _pic_rect() -> Rect2:
	var b := _box_rect()
	return Rect2(b.position.x + 40.0, b.position.y + 96.0, b.size.x - 80.0, 288.0)

func _layout() -> void:
	if _title_label == null:
		return # a RESIZED notification can beat _ready's child setup
	var b := _box_rect()
	_title_label.position = Vector2(b.position.x + 20.0, b.position.y + 16.0)
	_title_label.size = Vector2(b.size.x - 40.0, 56.0)
	_hint_label.position = Vector2(b.position.x + 36.0, b.position.y + b.size.y - 54.0)
	_hint_label.size = Vector2(b.size.x - 72.0, 40.0)
	_slip_label.position = Vector2(b.position.x + 20.0, b.position.y + 478.0)
	_slip_label.size = Vector2(b.size.x - 40.0, 34.0)
	_close_btn.position = Vector2(b.position.x + b.size.x - 58.0, b.position.y + 12.0)
	_close_btn.size = Vector2(44.0, 44.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout()
		queue_redraw()

# ------------------------------------------------------------------ API
func open_for(mech: String) -> void:
	mechanism = mech
	combo_index = 0
	_slip_t = 0.0
	_nudge_t = 0.0
	_slip_label.visible = false
	match mech:
		"latch": _title_label.text = "🪟 The Window Latch"
		"winpush": _title_label.text = "🪟 Push the Window Open!"
		"petdoor": _title_label.text = "🐾 The Pet Door"
		"bolt": _title_label.text = "🔓 The Back-Door Bolt"
		"carrier": _title_label.text = "🐱 The Carrier Door"
		_: _title_label.text = "🚪 The Way Out"
	_layout()
	visible = true
	queue_redraw()

func hide_panel() -> void:
	visible = false
	status_text = ""
	status_frac = -1.0
	status_warn = false

func set_combo_seq(seq: Array) -> void:
	# v1.0.21: main's freshly rolled A/B combination for this start
	# of the puzzle — the chips draw exactly this sequence.
	combo = seq.duplicate()
	combo_index = 0
	queue_redraw()

func set_combo(i: int) -> void:
	combo_index = i
	_slip_t = 0.0
	_slip_label.visible = false
	if mechanism == "carrier":
		_nudge_t = 0.25
	queue_redraw()

func show_slip(msg: String) -> void:
	_slip_label.text = msg
	_slip_label.visible = true
	_slip_t = 1.6
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	if _slip_t > 0.0:
		_slip_t -= delta
		if _slip_t <= 0.0:
			_slip_label.visible = false
	if _nudge_t > 0.0:
		_nudge_t -= delta
	queue_redraw() # chip pulse + shake/rattle animation

# ---------------------------------------------------------------- input
# The picture takes NO input (the swipe combo is gone) — the
# combination is entered on the game's own A / B buttons (main
# claims those presses before they reach the GUI) and the PC
# hop/paw keys, which main routes. Presses on the panel itself are
# simply swallowed so nothing leaks to the room behind.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if _font == null:
		_font = get_theme_default_font()
	var vp: Rect2 = get_viewport_rect()
	# Dim the room behind, then the dialogue box (with a little shake
	# while a "slipped back" message is up).
	draw_rect(vp, Color(0.02, 0.03, 0.06, 0.55))
	var b := _box_rect()
	if _slip_t > 0.0:
		b.position.x += sin(float(Time.get_ticks_msec()) * 0.07) * 5.0 * clampf(_slip_t, 0.0, 1.0)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.10, 0.13, 0.20, 0.97)
	box_style.border_color = Color(1.0, 0.85, 0.5)
	box_style.set_border_width_all(3)
	box_style.corner_radius_top_left = 18; box_style.corner_radius_top_right = 18
	box_style.corner_radius_bottom_left = 18; box_style.corner_radius_bottom_right = 18
	box_style.draw(get_canvas_item(), b)
	var pic := _pic_rect()
	pic.position.x = b.position.x + 40.0
	pic.position.y = b.position.y + 96.0
	var prog: float = float(combo_index) / float(maxi(combo.size(), 1))
	match mechanism:
		"latch": _draw_window(pic, prog, false)
		"winpush": _draw_window(pic, prog, true)
		"petdoor": _draw_petdoor(pic, prog)
		"bolt": _draw_bolt(pic, prog)
		"carrier": _draw_carrier(pic, prog)
	_draw_status(pic)
	_draw_chips(b)

# v1.2: the status strip across the top of the picture — is she busy
# with a toppled prop (green countdown), or watching you (red fill)?
func _draw_status(pic: Rect2) -> void:
	if status_text == "":
		return
	var strip := Rect2(pic.position, Vector2(pic.size.x, 38.0))
	draw_rect(strip, Color(0.04, 0.05, 0.1, 0.85))
	var tw: float = _font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x
	draw_string(_font, pic.position + Vector2((pic.size.x - tw) * 0.5, 27.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1.0, 0.97, 0.9))
	if status_frac >= 0.0:
		var col := Color(0.95, 0.45, 0.3) if status_warn else Color(0.45, 0.9, 0.45)
		draw_rect(Rect2(pic.position + Vector2(0, 38.0), Vector2(pic.size.x * clampf(status_frac, 0.0, 1.0), 5.0)), col)

func _draw_chips(b: Rect2) -> void:
	# v1.0.21: the chips spell THIS start's rolled A/B combination.
	var chip := Vector2(62.0, 62.0)
	var gap := 16.0
	var n: int = maxi(combo.size(), 1)
	var total: float = float(n) * chip.x + float(n - 1) * gap
	var x: float = b.position.x + (b.size.x - total) * 0.5
	var y: float = b.position.y + 404.0
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008)
	for i in range(combo.size()):
		var r := Rect2(x, y, chip.x, chip.y)
		var st := StyleBoxFlat.new()
		st.corner_radius_top_left = 14; st.corner_radius_top_right = 14
		st.corner_radius_bottom_left = 14; st.corner_radius_bottom_right = 14
		st.set_border_width_all(3)
		if i < combo_index:
			st.bg_color = Color(0.35, 0.75, 0.35, 0.95) # done: lit green
			st.border_color = Color(0.8, 1.0, 0.8)
		elif i == combo_index:
			st.bg_color = Color(0.95, 0.75, 0.25, 0.55 + 0.4 * pulse) # next: pulsing gold
			st.border_color = Color(1.0, 0.9, 0.5)
		else:
			st.bg_color = Color(0.16, 0.19, 0.26, 0.9)
			st.border_color = Color(0.45, 0.5, 0.6)
		st.draw(get_canvas_item(), r)
		var col := Color.WHITE if i <= combo_index else Color(0.6, 0.65, 0.75)
		draw_string(_font, Vector2(r.position.x, r.position.y + 44.0), str(combo[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, col)
		x += chip.x + gap

func _draw_window(pic: Rect2, prog: float, push_step: bool) -> void:
	# Sky + sun behind the glass.
	draw_rect(pic, SKY)
	draw_circle(pic.position + Vector2(pic.size.x * 0.78, pic.size.y * 0.3), 26.0, Color(1.0, 0.93, 0.55))
	draw_circle(pic.position + Vector2(pic.size.x * 0.2, pic.size.y * 0.26), 17.0, Color(1, 1, 1, 0.9))
	draw_circle(pic.position + Vector2(pic.size.x * 0.3, pic.size.y * 0.3), 13.0, Color(1, 1, 1, 0.9))
	# Lower sash slides UP as you work (a budge on the latch step, a
	# real opening on the push step).
	var slide: float = prog * (120.0 if push_step else 12.0)
	var sash := Rect2(pic.position + Vector2(26.0, pic.size.y * 0.52 - slide), Vector2(pic.size.x - 52.0, pic.size.y * 0.44))
	draw_rect(sash, Color(0.85, 0.93, 1.0, 0.35))
	draw_rect(Rect2(sash.position, Vector2(sash.size.x, 10.0)), CREAM)
	draw_rect(Rect2(sash.position + Vector2(0, sash.size.y - 10.0), Vector2(sash.size.x, 10.0)), CREAM)
	draw_rect(Rect2(sash.position + Vector2(sash.size.x * 0.5 - 4.0, 0), Vector2(8.0, sash.size.y)), CREAM)
	# Frame + upper sash + muntins.
	draw_rect(Rect2(pic.position, Vector2(pic.size.x, 12.0)), CREAM)
	draw_rect(Rect2(pic.position + Vector2(0, pic.size.y - 12.0), Vector2(pic.size.x, 12.0)), CREAM)
	draw_rect(Rect2(pic.position, Vector2(12.0, pic.size.y)), CREAM)
	draw_rect(Rect2(pic.position + Vector2(pic.size.x - 12.0, 0), Vector2(12.0, pic.size.y)), CREAM)
	draw_rect(Rect2(pic.position + Vector2(0, pic.size.y * 0.5), Vector2(pic.size.x, 9.0)), CREAM)
	draw_rect(Rect2(pic.position + Vector2(pic.size.x * 0.5 - 4.0, 0), Vector2(8.0, pic.size.y * 0.5)), CREAM)
	# THE LATCH on the meeting rail, right of centre.
	var pivot := pic.position + Vector2(pic.size.x * 0.62, pic.size.y * 0.5 + 4.0)
	draw_rect(Rect2(pivot - Vector2(30.0, 15.0), Vector2(60.0, 30.0)), BRASS_DARK)
	var start_vec := Vector2(-86.0, 10.0)
	var end_vec := Vector2(-15.0, -88.0)
	var ang: float = start_vec.angle_to(end_vec) * (1.0 if push_step else prog)
	var lever_vec: Vector2 = start_vec.rotated(ang)
	draw_line(pivot, pivot + lever_vec, BRASS, 15.0)
	draw_circle(pivot + lever_vec, 12.0, BRASS.lightened(0.15))
	draw_circle(pivot, 8.0, Color(0.35, 0.28, 0.14))

func _draw_petdoor(pic: Rect2, prog: float) -> void:
	draw_rect(pic, Color(0.92, 0.88, 0.8)) # wall panel
	var frame := Rect2(pic.position + Vector2(pic.size.x * 0.5 - 130.0, 24.0), Vector2(260.0, pic.size.y - 48.0))
	draw_rect(frame, HOLE) # the dark opening
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, 14.0)), CREAM)
	draw_rect(Rect2(frame.position + Vector2(0, frame.size.y - 14.0), Vector2(frame.size.x, 14.0)), CREAM)
	draw_rect(Rect2(frame.position, Vector2(14.0, frame.size.y)), CREAM)
	draw_rect(Rect2(frame.position + Vector2(frame.size.x - 14.0, 0), Vector2(14.0, frame.size.y)), CREAM)
	# The flap, hinged at the top, swinging up/out as you shove it.
	var lift: float = prog * frame.size.y * 0.52
	var flap := PackedVector2Array([
		frame.position + Vector2(16.0, 16.0),
		frame.position + Vector2(frame.size.x - 16.0, 16.0),
		frame.position + Vector2(frame.size.x - 16.0, frame.size.y - 16.0 - lift),
		frame.position + Vector2(16.0, frame.size.y - 16.0 - lift),
	])
	draw_polygon(flap, PackedColorArray([Color(0.35, 0.85, 0.55, 0.75)]))
	draw_line(flap[0], flap[1], Color(0.85, 0.83, 0.78), 8.0) # hinge bar
	draw_circle(pic.position + Vector2(pic.size.x * 0.5, pic.size.y - 30.0 - lift * 0.4), 7.0, Color(1, 1, 1, 0.35))

func _draw_bolt(pic: Rect2, prog: float) -> void:
	# Door slab (right) + frame post (left).
	var post := Rect2(pic.position + Vector2(pic.size.x * 0.16, 10.0), Vector2(54.0, pic.size.y - 20.0))
	var door := Rect2(pic.position + Vector2(pic.size.x * 0.42, 10.0), Vector2(pic.size.x * 0.52, pic.size.y - 20.0))
	draw_rect(door, WOOD)
	draw_rect(Rect2(door.position + Vector2(18.0, 26.0), door.size - Vector2(36.0, 52.0)), WOOD.darkened(0.18))
	draw_rect(post, Color(0.92, 0.9, 0.84))
	var mid_y: float = pic.position.y + pic.size.y * 0.5
	# v1.0.34 BOLT REMODEL (Michael: the old bolt "looks really
	# chintzy" — a thin brass strip that never even reached its
	# keeper). Now a heavy iron bolt whose parts actually meet: a
	# keeper housing with a dark slot on the post, a screwed-down
	# mounting plate and two guide brackets on the door, a chunky
	# steel bar that shoots into the keeper, and a big brass grip
	# hanging below the bar — the handle the cat works. As prog
	# advances the bar retracts out of the keeper, as before.
	var steel := Color(0.52, 0.54, 0.58)
	var steel_dark := Color(0.27, 0.27, 0.3)
	var steel_light := Color(0.72, 0.74, 0.78)
	# Keeper housing on the post, with the slot the bar shoots into.
	var keeper := Rect2(post.position + Vector2(-10.0, mid_y - post.position.y - 34.0), Vector2(74.0, 68.0))
	draw_rect(keeper, steel_dark)
	draw_rect(Rect2(keeper.position + Vector2(6.0, 6.0), keeper.size - Vector2(12.0, 12.0)), Color(0.38, 0.39, 0.43))
	draw_rect(Rect2(keeper.position + Vector2(58.0, 20.0), Vector2(16.0, 28.0)), Color(0.07, 0.07, 0.08)) # the slot
	draw_circle(keeper.position + Vector2(16.0, 14.0), 4.5, steel_dark)
	draw_circle(keeper.position + Vector2(16.0, 54.0), 4.5, steel_dark)
	# Mounting plate on the door, screwed at the corners.
	var plate := Rect2(door.position + Vector2(24.0, mid_y - door.position.y - 48.0), Vector2(door.size.x - 70.0, 96.0))
	draw_rect(plate, steel_dark)
	draw_rect(Rect2(plate.position + Vector2(5.0, 5.0), plate.size - Vector2(10.0, 10.0)), Color(0.4, 0.41, 0.45))
	for sx in [14.0, plate.size.x - 14.0]:
		for sy in [14.0, plate.size.y - 14.0]:
			draw_circle(plate.position + Vector2(sx, sy), 5.0, steel_dark)
			draw_circle(plate.position + Vector2(sx, sy), 2.2, steel_light)
	# The bar: its left end starts inside the keeper and retracts
	# to the right as the combo is worked.
	var bar_right: float = door.position.x + 330.0
	var bar_left: float = post.position.x + 30.0 + prog * 165.0
	var bar := Rect2(Vector2(bar_left, mid_y - 17.0), Vector2(bar_right - bar_left, 34.0))
	draw_rect(bar, steel)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x, 9.0)), steel_light) # top highlight
	draw_rect(Rect2(bar.position + Vector2(0, bar.size.y - 9.0), Vector2(bar.size.x, 9.0)), steel_dark.lightened(0.25)) # bottom shade
	draw_circle(bar.position + Vector2(0, 17.0), 17.0, steel) # rounded nose
	# Guide brackets: collars standing proud of the plate, the bar
	# sliding through them.
	for bx in [door.position.x + 105.0, door.position.x + 245.0]:
		draw_rect(Rect2(Vector2(bx, mid_y - 29.0), Vector2(28.0, 58.0)), steel_dark)
		draw_rect(Rect2(Vector2(bx + 4.0, mid_y - 25.0), Vector2(20.0, 50.0)), Color(0.42, 0.44, 0.48))
		draw_rect(Rect2(Vector2(bx, mid_y - 17.0), Vector2(28.0, 34.0)), steel_dark) # collar over the bar
	# The grip: a post dropping from the bar to a big brass knob —
	# the handle the cat visibly works. It rides with the bar.
	var grip_x: float = bar_right - 78.0
	draw_rect(Rect2(Vector2(grip_x, mid_y + 17.0), Vector2(15.0, 36.0)), steel_dark)
	draw_circle(Vector2(grip_x + 7.5, mid_y + 68.0), 17.0, BRASS)
	draw_circle(Vector2(grip_x + 7.5, mid_y + 68.0), 10.0, BRASS.lightened(0.25))
	draw_circle(Vector2(grip_x + 3.5, mid_y + 63.0), 3.5, BRASS.lightened(0.55))

func _draw_carrier(pic: Rect2, prog: float) -> void:
	var shake := Vector2.ZERO
	if _nudge_t > 0.0:
		shake = Vector2(sin(float(Time.get_ticks_msec()) * 0.09) * 4.0 * _nudge_t * 4.0, 0)
	var body := Rect2(pic.position + Vector2(pic.size.x * 0.5 - 210.0, 30.0) + shake, Vector2(420.0, pic.size.y - 60.0))
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(0.72, 0.78, 0.88)
	body_style.border_color = Color(0.4, 0.44, 0.52)
	body_style.set_border_width_all(3)
	body_style.corner_radius_top_left = 26; body_style.corner_radius_top_right = 26
	body_style.corner_radius_bottom_left = 26; body_style.corner_radius_bottom_right = 26
	body_style.draw(get_canvas_item(), body)
	# Handle + vents.
	draw_rect(Rect2(body.position + Vector2(155.0, -16.0), Vector2(110.0, 18.0)), Color(0.35, 0.38, 0.45))
	for vx in [-60.0, 0.0, 60.0]:
		draw_rect(Rect2(body.position + Vector2(210.0 + vx - 22.0, 18.0), Vector2(44.0, 10.0)), Color(0.4, 0.44, 0.52))
	# The door: dark interior revealed on the right as it swings open
	# (hinge on the left), grid bars drawn over the opening.
	var door_r := Rect2(body.position + Vector2(45.0, 48.0), Vector2(330.0, body.size.y - 84.0))
	draw_rect(door_r, HOLE)
	var open_px: float = prog * 120.0
	var grid := PackedVector2Array([
		door_r.position,
		door_r.position + Vector2(door_r.size.x - open_px, 6.0 + prog * 10.0),
		door_r.position + Vector2(door_r.size.x - open_px, door_r.size.y - 6.0 - prog * 4.0),
		door_r.position + Vector2(0, door_r.size.y),
	])
	draw_polygon(grid, PackedColorArray([Color(0.3, 0.32, 0.38, 0.55)]))
	var bar_col := Color(0.3, 0.32, 0.38)
	for i in range(4):
		var fx: float = float(i) / 3.0
		var top_p: Vector2 = grid[0].lerp(grid[1], fx)
		var bot_p: Vector2 = grid[3].lerp(grid[2], fx)
		draw_line(top_p, bot_p, bar_col, 7.0)
	for j in range(3):
		var fy: float = float(j) / 2.0
		draw_line(grid[0].lerp(grid[3], fy), grid[1].lerp(grid[2], fy), bar_col, 7.0)
	# Door clip (gold) rides the free edge.
	var clip_pos: Vector2 = grid[1].lerp(grid[2], 0.55)
	draw_rect(Rect2(clip_pos - Vector2(4.0, 16.0), Vector2(16.0, 32.0)), Color(0.85, 0.6, 0.2))
