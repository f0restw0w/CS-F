extends SceneTree
## 诊断用：加载主场景渲染 ~1.5s 后截图保存（需带渲染运行，不能 --headless）。
##   godot --path . --script res://tests/screenshot.gd

func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/dust2.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 90:
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png("F:/Project/github/CS-F/.godot/diag_shot.png")
	print("screenshot saved")
	quit(0)
