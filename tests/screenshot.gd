extends SceneTree
## 诊断用：加载主场景渲染 ~1.5s 后截图保存（需带渲染运行，不能 --headless）。
##   godot --path . --script res://tests/screenshot.gd

func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/dust2.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("Player") as Node3D
	for i in 90:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/diag_shot.png")

	# 机位 2：中路坡底回望 T 家大坡
	player.global_position = Vector3(0, 2, 200)
	player.rotation = Vector3(0, PI, 0)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/diag_shot2.png")

	# 机位 3：B 下隧道内部（封顶）
	player.global_position = Vector3(-1100, 2, -100)
	player.rotation = Vector3(0, PI, 0)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/diag_shot3.png")

	print("screenshots saved")
	quit(0)
