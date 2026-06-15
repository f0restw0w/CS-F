extends SceneTree
## 探几个候选出生点：射线下探看命中高度，找站得住的实地。
func _init() -> void:
	await process_frame
	var world: Node = (load("res://scenes/regions/dust2_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var cs := world.get_node("Collision") as CollisionShape3D
	(cs.shape as ConcavePolygonShape3D).backface_collision = true
	for i in 8:
		await physics_frame
	var space := root.world_3d.direct_space_state
	# 候选（Godot x,z）来自 demo T 家点 + CT 家点
	var cands := [
		Vector3(1200, 0, -3050), Vector3(1183, 0, -3056), Vector3(1295, 0, -3047),
		Vector3(1114, 0, -3034), Vector3(1103, 0, -2993),
		Vector3(-500, 0, 1008), Vector3(-650, 0, 1008), Vector3(-785, 0, 1008),
		Vector3(-460, 0, 1008),
	]
	for c in cands:
		var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, 400, c.z), Vector3(c.x, -200, c.z))
		q.hit_from_inside = true
		var r := space.intersect_ray(q)
		if r.is_empty():
			print("(%.0f,%.0f) 没命中" % [c.x, c.z])
		else:
			print("(%.0f,%.0f) 地面 y=%.1f" % [c.x, c.z, r.position.y])
	quit(0)
