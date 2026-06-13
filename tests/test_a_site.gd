extends SceneTree
## A 区 v3 落点验证：把玩家丢到各实测面上，确认落地且高度=实测值。
## godot --headless --script res://tests/test_a_site.gd

var _failed := 0
var _passed := 0


func _init() -> void:
	_run()


func check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  PASS: " + name)
	else:
		_failed += 1
		printerr("  FAIL: " + name)


func _run() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/test_a_site.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node("Player") as PlayerController
	check("含玩家", player != null)
	if player == null:
		_finish()
		return

	# 每个面：[名称, drop 位置(Godot), 期望站立 y]
	var probes: Array = [
		["site 主地面 96", Vector3(1072, 140, -2520), 96.0],
		["后平台 128", Vector3(1108, 170, -2346), 128.0],
		["后平台 spine 128", Vector3(1256, 170, -2520), 128.0],
		["长A进场 0", Vector3(1312, 60, -1950), 0.0],
		["东坡中段 ~96", Vector3(1552, 160, -2584), 96.0],
		["东 60 ledge", Vector3(1744, 110, -2040), 60.0],
		["坑底 -24", Vector3(976, 40, -2216), -24.0],
		["跳箱顶 160", Vector3(1112, 220, -2424), 160.0],
	]
	for p in probes:
		player.global_position = p[1]
		player.velocity = Vector3.ZERO
		for i in 40:
			await physics_frame
		check("%s（落 y=%.1f ≈ %.0f）" % [p[0], player.global_position.y, p[2]],
				player.grounded and absf(player.global_position.y - p[2]) < 8.0)

	# 长A进场跑上 site（过渡坡 0→96）
	player.global_position = Vector3(1312, 4, -2050)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	Input.action_press("move_forward")
	var air := 0
	for i in 120:
		if not player.grounded:
			air += 1
		await physics_frame
	Input.action_release("move_forward")
	check("长A进场跑上 site（贴坡 air=%d≤8，终 y=%.0f≥90）" % [air, player.global_position.y],
			air <= 8 and player.global_position.y >= 90.0)

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
