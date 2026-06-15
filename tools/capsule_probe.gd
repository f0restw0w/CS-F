extends SceneTree
## 用真实玩家胶囊体逐个测 T 家候选点：落地后停在哪、站没站住。
func _init() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/dust2.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("Player") as PlayerController
	for i in 20:
		await physics_frame
	var cands := [
		Vector3(1200, 134, -3050), Vector3(1183, 134, -3030), Vector3(1250, 134, -3000),
		Vector3(1150, 134, -2980), Vector3(1300, 134, -3020), Vector3(1220, 134, -2960),
	]
	for c in cands:
		player.global_position = c
		player.velocity = Vector3.ZERO
		for i in 50:
			await physics_frame
		print("候选(%.0f,%.0f) → 停 y=%.1f grounded=%s" %
				[c.x, c.z, player.global_position.y, str(player.grounded)])
	quit(0)
