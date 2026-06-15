extends SceneTree
## 主场景 dust2.tscn 落地校验 + T 家视角截图。
func _init() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/dust2.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("Player") as PlayerController
	# 重置到出生点（消除无头首帧碰撞未就绪的自由落体伪影，等同真实加载）
	for i in 10:
		await physics_frame
	player.global_position = Vector3(1200, 134, -3050)
	player.velocity = Vector3.ZERO
	for i in 60:
		await physics_frame
	print("T 家出生 y=%.1f grounded=%s" % [player.global_position.y, str(player.grounded)])
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/main_tspawn.png")
	print("主场景截图完成")
	quit(0)
