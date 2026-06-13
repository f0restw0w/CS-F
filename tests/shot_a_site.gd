extends SceneTree
## A 区 v3 多机位截图：俯瞰 + 长A进场 + 跳箱 + 东坡，看灰盒与 demo 点云贴合度。

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/test_a_site.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("Player") as Node3D
	# 关掉玩家相机用顶视相机俯瞰
	var topcam := Camera3D.new()
	topcam.projection = Camera3D.PROJECTION_ORTHOGONAL
	topcam.size = 1200.0
	topcam.far = 6000.0
	root.add_child(topcam)
	topcam.global_position = Vector3(1200, 1200, -2400)
	topcam.rotation = Vector3(-PI / 2, 0, 0)
	topcam.current = true
	for i in 80:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/A_top.png")

	# 第一人称：长A进场口朝北看 site
	topcam.current = false
	var cam := player.get_node("Head/Camera3D") as Camera3D
	cam.current = true
	player.global_position = Vector3(1312, 4, -1980)
	player.rotation = Vector3.ZERO
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/A_fp1.png")

	# 站 site 中心看跳箱与平台
	player.global_position = Vector3(1080, 100, -2500)
	player.rotation = Vector3(0, -0.6, 0)
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/A_fp2.png")
	print("A 区截图完成")
	quit(0)
