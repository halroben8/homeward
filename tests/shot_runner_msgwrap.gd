extends Node
## MESSAGE WRAP runner (v1.0.15 HUD fix verification, 2026-11-18).
## Michael played v1.0.14: the bottom message band ran as ONE long
## line off both screen edges ("You are inside the POUND — and so
## is he! Knock something over…") and the ESCAPE header overflowed
## the same way. This runner boots the real game, plays the opening
## into the pound cage, opens the gate the real way (PAW), and
## photographs the band as each queued beat of the split entry
## message appears. It then measures the wrapped line count of the
## longest stock messages on the REAL message_label (1280x720) —
## anything over 2 lines would clip against max_lines_visible.
## Usage:  godot --path . tests/ShotRunnerMsgWrap.tscn
## Output: ~/workspace/homeward/screenshots_msgwrap/NN_name.png
## Not part of the suite.

const OUT := "/home/hatch/workspace/homeward/screenshots_msgwrap"
const EmojiFont := preload("res://tests/emoji_font.gd")

const BEAT_1 := "You're in the POUND — and so is he!"
const BEAT_2 := "Knock something over to distract him, then work the back door."

var main: Node = null
var story: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func wait_for_main(key: String, want: String, max_frames: int) -> bool:
	for i in range(max_frames):
		if str(main.get(key)) == want:
			return true
		await get_tree().process_frame
	print("RUNNER WAIT TIMEOUT: ", key, " != ", want)
	return false

func wait_for_message(want: String, max_sec: float) -> bool:
	var waited: float = 0.0
	while waited < max_sec:
		var lbl: Label = main.get("message_label")
		if lbl != null and lbl.text == want:
			return true
		await wait_sec(0.1)
		waited += 0.1
	print("RUNNER WAIT TIMEOUT: message != ", want, " (now: ", str((main.get("message_label") as Label).text), ")")
	return false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	EmojiFont.apply()
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	var bw: int = 0
	while not bool(main.get("build_complete")) and bw < 21600:
		await get_tree().process_frame
		bw += 1
	await wait_sec(1.2)
	story = main.get("story")
	main.call("dismiss_splash")
	main.call("start_game")
	for i in range(10):
		await get_tree().process_frame
		story.call("skip_opening")
	await wait_for_main("state", "escape", 3000)
	var guard: int = 0
	while not bool(story.get("cage_closed")) and guard < 600:
		await get_tree().process_frame
		guard += 1
	await wait_sec(1.0)

	# Out of the cage the real way (PAW at the gate): the story shows
	# its gate line, then releases the two held entry beats.
	main.call("_on_interact")
	await wait_sec(0.9)
	print("gate opened: ", not bool(story.get("cage_closed")))

	# Beat 1 on the band.
	if await wait_for_message(BEAT_1, 12.0):
		var ml: Label = main.get("message_label")
		print("BEAT1 lines=", ml.get_line_count(), " escape_label lines=", (main.get("escape_label") as Label).get_line_count(), " escape text=", str((main.get("escape_label") as Label).text))
		await snap("01_beat1.png")
	# Beat 2 on the band.
	if await wait_for_message(BEAT_2, 12.0):
		var ml2: Label = main.get("message_label")
		print("BEAT2 lines=", ml2.get_line_count())
		await snap("02_beat2.png")

	# The longest town message, shown through the real show_message.
	main.call("clear_message_band")
	main.call("show_message", "You escaped! +3 points 💛 They'll look for you for 30 seconds — hide in bushes or behind cars!", 4.0)
	await wait_sec(0.3)
	await snap("03_long_message.png")

	# Battery: wrapped line counts of the longest stock strings on
	# the real label (band cleared; text set directly to measure).
	main.call("clear_message_band")
	var battery: Array = [
		"You are inside the POUND — and so is he! Knock something over to distract him, then work the way out! 🐾",
		"You escaped! +3 points 💛 They'll look for you for 30 seconds — hide in bushes or behind cars!",
		"💛 The Cat-Loving Young Woman scooped you up! \"Come home with me, kitty!\"  (tap to skip)",
		"🏃 CHASE! The Cat-Loving Young Woman is after you — SPRINT, jink, hide, break away!",
		"🚐 The pound worker spotted you: \"There you are! Let's get you home!\" — RUN!",
		"🚗 Whoa! A car startled you — -5 points! (You're fine, just bounced.)",
		"👀 She spotted you at the door! Knock something over to distract her first! 🐾",
		"💥 You knocked over the stack of steel bowls! She's distracted — quick, work the way out! 🐾",
		"Find home: the address from your collar tag. Avoid lingering near people!",
		"🐾 His collar slipped off — its tag says: 123 Maple Street, Apt 3B",
		"Paw the way out to work it — or knock something over to distract her! 🐾",
	]
	var mlb: Label = main.get("message_label")
	for s in battery:
		mlb.text = s
		await get_tree().process_frame
		await get_tree().process_frame
		print("LINES ", mlb.get_line_count(), " <- ", s)
	mlb.text = ""
	var el: Label = main.get("escape_label")
	print("ESCAPE LABEL lines=", el.get_line_count(), " text=", el.text)
	var dl: Label = main.get("distract_label")
	print("DISTRACT LABEL lines=", dl.get_line_count(), " text=", dl.text)
	print("MSGWRAP RUNNER DONE")
	get_tree().quit(0)
