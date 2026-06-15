extends SceneTree
## 纯净顶视：只看 bsp 几何 + demo 点云是否重合（无天空/阳光/glow）。

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var root3d := Node3D.new()
	root.add_child(root3d)

	var world: Node = (load("res://scenes/regions/dust2_world.tscn") as PackedScene).instantiate()
	root3d.add_child(world)
	# 几何用平白材质，避免纹理干扰看轮廓
	var flat := StandardMaterial3D.new()
	flat.albedo_color = Color(0.30, 0.32, 0.36)
	var mi := world.get_node("Mesh") as MeshInstance3D
	mi.material_override = flat

	var overlay := Node3D.new()
	overlay.set_script(load("res://scripts/debug/demo_overlay.gd"))
	root3d.add_child(overlay)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)

	var top := Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = 5400.0
	top.far = 12000.0
	root3d.add_child(top)
	top.global_position = Vector3(-300, 1500, -1100)
	top.rotation = Vector3(-PI / 2, 0, 0)
	top.current = true
	for i in 80:
		await process_frame
	root.get_texture().get_image().save_png("F:/Project/github/CS-F/.godot/bsp_flat_top.png")
	print("纯净顶视完成")
	quit(0)
