extends SceneTree
## bsp 几何核对截图：全图顶视（含 demo 点云）+ A 点第一人称。

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/test_bsp.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("Player") as Node3D
	for i in 30:
		await process_frame
	check_grounded(player)

	# 顶视全图
	var top := Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = 4800.0
	top.far = 12000.0
	root.add_child(top)
	top.global_position = Vector3(-300, 2000, -1100)
	top.rotation = Vector3(-PI / 2, 0, 0)
	top.current = true
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/bsp_top.png")

	# A 点第一人称
	top.current = false
	var cam := player.get_node("Head/Camera3D") as Camera3D
	cam.current = true
	player.global_position = Vector3(1072, 140, -2520)
	player.rotation = Vector3(0, 2.4, 0)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/bsp_a.png")
	print("bsp 截图完成")
	quit(0)

func check_grounded(p: Node) -> void:
	var pc := p as CharacterBody3D
	print("A 点出生 y=%.1f grounded=%s" % [pc.global_position.y, str((pc as Object).get("grounded"))])
