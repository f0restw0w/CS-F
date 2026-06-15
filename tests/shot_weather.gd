extends SceneTree
## 天气截图：低头看地面（湿地/积水/飞溅），抓 雨景 + 闪电照亮 两张。
func _init() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/dust2.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("Player") as PlayerController
	var head := player.get_node("Head") as Node3D
	for i in 10:
		await physics_frame
	# 站 A 点开阔地，低头 35° 看地面
	player.global_position = Vector3(1072, 100, -2520)
	player.rotation = Vector3(0, 0.6, 0)
	head.rotation.x = deg_to_rad(-35)
	player.velocity = Vector3.ZERO
	for i in 80:
		await physics_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/weather_wet.png")

	# 闪电照亮（积水反射最明显）
	var w := scene.get_node("Weather") as WeatherSystem
	if w:
		w._flash(1.0)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/weather_wet_flash.png")
	print("天气地面截图完成")
	quit(0)
