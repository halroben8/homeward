extends Node
## HOMEWARD v0.9 screenshot staging, pass B: identical comparison
## staging to v0.8 (sharpness pair, streets, cat close-ups) plus
## PROFILE views of the pet/treat sequences (pass A's head-on
## camera hid the kneeling NPC behind the cat). Direct
## react_to_attention calls keep the staging deterministic.

const OUT := "/home/hatch/workspace/homeward/screenshots_v09"
var main: Node = null
var player: Node = null

func wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("SHOT: ", name)

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

func set_joy(vec: Vector2) -> void:
	main.set("joy_mouse", true)
	main.set("joy_origin", Vector2(200, 400))
	main.set("joy_current", Vector2(200, 400) + vec)

func clear_joy() -> void:
	main.set("joy_mouse", false)
	main.set("joy_id", -999)

func npc_of(type: String) -> Node:
	for n in main.get("npcs"):
		if str(n.get("npc_type")) == type:
			return n
	return null

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 864))
	await wait_sec(0.5)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	main = scene.instantiate()
	add_child(main)
	await wait_sec(1.2)
	player = main.get("player")
	park_npcs_far()
	main.call("dismiss_splash")
	main.call("start_game")
	await wait_sec(0.5)
	player.set("idle_next_in", 999.0)
	var hint: Label = main.get("hint_label")
	if hint != null:
		hint.visible = false

	# PETTING, PROFILE VIEW: camera looks from the south-east so the
	# kneeling woman is BESIDE the cat in frame, not behind him.
	var woman: Node = npc_of("woman")
	stage(Vector3(10, 0, 6), 118.0, 9.0)
	(woman as Node3D).global_position = Vector3(11.8, 0.2, 4.6)
	woman.set("velocity", Vector3.ZERO)
	woman.set("interact_cooldown", 0.0)
	woman.set("joy_shown", false)
	await wait_sec(0.3)
	woman.call("react_to_attention")
	woman.set("interact_kind", "pet")
	await wait_sec(1.15)
	await snap("pet_kneel.png")
	await wait_sec(1.25)
	await snap("pet_stroking.png")
	await wait_sec(1.05)
	await snap("pet_hearts.png")

	# TREAT, PROFILE VIEW: direct trigger on the shopkeeper.
	var shop: Node = npc_of("shopkeeper")
	(woman as Node3D).global_position = Vector3(40, 0.2, 40)
	stage(Vector3(10, 0, 6), 118.0, 9.0)
	(shop as Node3D).global_position = Vector3(11.8, 0.2, 4.6)
	shop.set("velocity", Vector3.ZERO)
	shop.set("interact_cooldown", 0.0)
	shop.set("joy_shown", false)
	await wait_sec(0.3)
	shop.call("react_to_attention")
	shop.set("interact_kind", "treat")
	await wait_sec(1.7)
	await snap("treat_offer.png")
	await wait_sec(1.6)
	await snap("treat_eating.png")

	print("SHOTS B DONE")
	get_tree().quit(0)
