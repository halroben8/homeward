extends Node
## HOMEWARD v1.0.8 proof staging (run under Xvfb, NOT headless):
##   xvfb-run -a godot --path . tests/ShotRunnerV108.tscn
## Step 1 proof: the play HUD with the COLLAR and LOOK buttons gone.
## Step 2 proof: the same frames re-rendered with the emoji fallback
## font wired in (tests/emoji_font.gd) — glyphs instead of hex boxes.

const OUT := "/home/hatch/workspace/homeward/screenshots_v108"
const EmojiFont := preload("res://tests/emoji_font.gd")
var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name, " ", img.get_size())

func park_npcs_far() -> void:
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1

func stage(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	(player as Node3D).global_position = pos
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", deg_to_rad(yaw_deg))
	main.set("look_pitch_deg", pitch_deg)

func _ready() -> void:
	EmojiFont.apply() # render-only emoji fallback — before Main is instanced
	DisplayServer.window_set_size(Vector2i(1920, 864))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	park_npcs_far()
	main.call("dismiss_splash")
	await wait_sec(0.4)
	await snap("title.png")
	main.call("start_game")
	await wait_sec(0.5)
	# lively scoreboard for the HUD shot
	main.set("score", 12)
	main.set("pets_count", 2)
	main.set("treats_count", 1)
	main.call("_update_score_label")
	stage(Vector3(4, 0, 6), -15.0, 16.0)
	await wait_sec(0.9)
	await snap("hud_play.png")
	# a world Label3D carrying an emoji: the signed cat gap by the park
	stage(Vector3(-37, 0, 27), 0.0, 0.0)
	await wait_sec(0.9)
	await snap("world_label.png")
	print("SHOTS DONE")
	get_tree().quit(0)
