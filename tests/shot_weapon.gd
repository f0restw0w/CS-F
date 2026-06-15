extends SceneTree
## 武器特写：贴墙看 AK 模型造型。
func _init() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/test_range.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("Player") as Node3D
	for i in 40:
		await process_frame
	player.global_position = Vector3(0, 2, 600)
	player.rotation = Vector3(0, PI, 0)
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/weapon_view.png")
	print("武器特写完成")
	quit(0)
