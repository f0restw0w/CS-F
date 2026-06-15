extends SceneTree
## 射线覆盖率：对 demo 每个走点从上方垂直下探，命中面高度应≈demo 实测脚高。
## 这是几何正确性的硬核验证（不受玩家胶囊体落地伪影影响）。

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var world: Node = (load("res://scenes/regions/dust2_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	# trimesh 碰撞默认按绕序单面：开 backface 让射线两面都命中（仅测试用）
	var cs := world.get_node("Collision") as CollisionShape3D
	(cs.shape as ConcavePolygonShape3D).backface_collision = true
	for i in 8:
		await physics_frame
	var space := root.world_3d.direct_space_state

	# 探针自检：A 点已知脚高 96
	var aq := PhysicsRayQueryParameters3D.create(Vector3(1072, 200, -2520), Vector3(1072, -50, -2520))
	aq.hit_from_inside = true
	var ar := space.intersect_ray(aq)
	print("A 点自检射线：", "命中 y=%.1f" % ar.position.y if not ar.is_empty() else "没命中(!)")

	var f := FileAccess.open("res://.godot/demo_trace.csv", FileAccess.READ)
	f.get_line()
	var pts: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var c := line.split(",")
		if c.size() < 8 or c[2] != "cd":
			continue
		pts.append([c[3].to_float(), c[4].to_float(), c[5].to_float()])

	var n := 400
	var step := int(pts.size() / n)
	var hit_ok := 0
	var hit_any := 0
	var miss := 0
	var worst := []
	for i in n:
		var p: Array = pts[i * step]
		var foot: float = p[2] - 36.0
		var gx: float = p[0]
		var gz: float = -p[1]
		var from := Vector3(gx, foot + 80.0, gz)
		var to := Vector3(gx, foot - 60.0, gz)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.hit_from_inside = true
		var r := space.intersect_ray(q)
		if r.is_empty():
			miss += 1
			if worst.size() < 8:
				worst.append("MISS @(%.0f,%.0f,%.0f) demo脚%.0f" % [p[0], p[1], p[2], foot])
		else:
			hit_any += 1
			var dy: float = absf(r.position.y - foot)
			if dy < 18.0:
				hit_ok += 1
			elif worst.size() < 8:
				worst.append("低%.0f @(%.0f,%.0f) demo脚%.0f→命中%.1f" % [dy, p[0], p[1], foot, r.position.y])

	print("射线探针 %d：命中且高度吻合(±18)=%d  命中但偏高低=%d  完全没命中=%d" %
			[n, hit_ok, hit_any - hit_ok, miss])
	print("覆盖率(吻合) = %.1f%%" % (100.0 * hit_ok / n))
	for w in worst:
		print("  " + w)
	quit(0)
