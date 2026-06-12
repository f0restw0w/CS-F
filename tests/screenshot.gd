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

	# 机位 2：中路坡底回望 T 大坡
	player.global_position = Vector3(-410, 2, -300)
	player.rotation = Vector3(0, PI, 0)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/diag_shot2.png")

	# 机位 3：下隧道内部（封顶，望向台阶）
	player.global_position = Vector3(-1000, 2, -605)
	player.rotation = Vector3(0, PI * 0.5, 0)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/diag_shot3.png")

	# 机位 4：长A直道北望（A 大坡与大坑方向）
	player.global_position = Vector3(1555, 34, -800)
	player.rotation = Vector3.ZERO
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/diag_shot4.png")

	# 机位 5：A 点环视（A 平台/大箱/双层箱）
	player.global_position = Vector3(1600, 194, -2650)
	player.rotation = Vector3(0, PI * 0.75, 0)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/diag_shot5.png")

	print("screenshots saved")
	quit(0)
