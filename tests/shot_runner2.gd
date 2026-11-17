extends Node
## Supplementary v0.7 shots: full-canopy tree. (The collar shot was
## dropped in v1.0.8 with the collar check itself.)
##   xvfb-run -a godot --resolution 1920x864 --path . tests/ShotRunner2.tscn

const OUT := "/home/hatch/workspace/homeward/screenshots_v07"
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

func _ready() -> void:
	EmojiFont.apply() # render-only emoji fallback — before Main is instanced
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	var i: int = 0
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110 + float(i) * 2.0, 0.2, 80)
		i += 1
	main.call("dismiss_splash")
	await wait_sec(0.3)
	main.call("start_game")
	await wait_sec(0.5)
	# TREE: stand well back so the whole layered canopy fits the frame
	(player as Node3D).global_position = Vector3(-2, 0, -27.0)
	player.set("velocity", Vector3.ZERO)
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", 10.0)
	await wait_sec(1.0)
	await snap("tree_a.png")
	# (v1.0.8: the old collar shot is gone — the collar check itself
	# was removed from the game.)
	print("SHOTS2 DONE")
	get_tree().quit(0)
