extends SceneTree
## 天气截图：加载 dust2，等雨起来，强制触发一次闪电，抓正常+闪电两张。
func _init() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/dust2.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("Player") as PlayerController
	for i in 10:
		await physics_frame
	player.global_position = Vector3(1200, 134, -3050)
	player.rotation = Vector3(0, PI, 0)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/weather_rain.png")

	# 强制触发闪电
	var w := scene.get_node("Weather") as WeatherSystem
	if w:
		w._flash(1.0)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/weather_flash.png")
	print("天气截图完成")
	quit(0)
