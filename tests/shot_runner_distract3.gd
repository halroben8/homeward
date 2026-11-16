extends Node
## HOMEWARD v1.2 — one restaged proof shot: the behind gameplay view
## with a nearby person and a partially-filled notice bar. The kid is
## re-placed in the same instant as the snap so his wander AI cannot
## drift him out of frame.

const OUT := "/home/hatch/workspace/homeward/screenshots_distract/"

var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	for n in main.get("npcs"):
		(n as Node3D).global_position = Vector3(-110, 0.2, 80)
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	var grabber: Node = null
	for n in main.get("npcs"):
		if str(n.get("role")) == "grabber":
			grabber = n
			break
	(player as Node3D).global_position = Vector3(30, 0.2, 30)
	player.set("velocity", Vector3.ZERO)
	(grabber as Node3D).global_position = Vector3(30, 0.2, 25.0)
	grabber.set("notice", 0.55)
	grabber.set("mode", "wander")
	main.set("look_yaw", 0.0)
	main.set("look_pitch_deg", 6.0)
	await wait_sec(0.25)
	# Re-place + re-set in the snap's own moment: he is 5 m ahead of
	# the cat, half-noticed, name + 👀 bar over his head.
	(grabber as Node3D).global_position = Vector3(30, 0.2, 25.0)
	grabber.set("notice", 0.55)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "view_behind_notice.png")
	print("saved view_behind_notice.png")
	get_tree().quit(0)
