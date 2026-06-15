extends SceneTree
## 自由相机俯视 T 家开阔地（明亮），确认地面实心沙地、不透背景。
func _init() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/dust2.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 40:
		await physics_frame
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 12000.0
	root.add_child(cam)
	cam.global_position = Vector3(1200, 420, -2780)
	cam.rotation = Vector3(deg_to_rad(-50), 0, 0)
	cam.current = true
	for i in 50:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/weather_ground.png")
	print("自由相机俯视完成")
	quit(0)
