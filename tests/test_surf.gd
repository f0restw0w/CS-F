extends SceneTree
## surf 物理验证（Phase 1）：60° 斜面（法线 y=0.5）必须表现为：
##   1. 不被判定为地面（grounded 恒 false）→ 不吃地面摩擦
##   2. 重力被 clip_velocity 投影到斜面 → 沿坡持续加速（贴斜面加速 = surf 雏形）
##   3. 按住朝坡方向键保持贴面滑行不弹开
##
## 运行方式（无头）：
##   godot --headless --path . --script res://tests/test_surf.gd

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
	var scene: Node = (load("res://scenes/test_surf.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame

	var player := scene.get_node("Player") as PlayerController
	check("场景含 PlayerController", player != null)
	if player == null:
		_finish()
		return

	# —— 测试 A：无输入自由滑 ——
	# 斜面不算地面 → 无摩擦；重力被 clip 投影沿面 → 持续加速（surf 物理本体）
	# 斜面：60°，面法线 n = (-0.866, 0.5, 0)，面上点(z=800)约 (62, 392, 800)
	player.global_position = Vector3(58, 394, 800)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await physics_frame
	var grounded_ticks := 0
	for i in 60:
		if player.grounded:
			grounded_ticks += 1
		await physics_frame
	check("自由滑 0.6s 沿坡加速 > 250（实测 %.1f，g·sin60° 投影）" % player.velocity.length(),
			player.velocity.length() > 250.0)
	check("自由滑全程不判定为地面（grounded_ticks=%d ≤ 1，首帧落面容差）" % grounded_ticks,
			grounded_ticks <= 1)

	# —— 测试 B：压坡骑面（按住 D = +x 朝坡）——
	# 空气加速沿面投影为上坡分量（~15/tick）> 重力沿坡分量（~7/tick），
	# 真实 surf 行为：压坡可以骑面爬升而不是滑落。验证贴面不弹开、速度不被吃掉。
	player.global_position = Vector3(58, 394, 800)
	player.velocity = Vector3(0, 0, -100)
	await physics_frame
	Input.action_press("move_right")
	grounded_ticks = 0
	var start_y := player.global_position.y
	for i in 90:
		if player.grounded:
			grounded_ticks += 1
		await physics_frame
	Input.action_release("move_right")

	var v := player.velocity
	check("压坡全程贴面不落地（grounded_ticks=%d ≤ 2）" % grounded_ticks, grounded_ticks <= 2)
	check("仍贴在斜面上（x 在面范围内，实测 %.1f）" % player.global_position.x,
			player.global_position.x > -160.0 and player.global_position.x < 110.0)
	check("压坡骑面爬升或缓降（Δy=%.1f，未滑脱坠落）" % (player.global_position.y - start_y),
			player.global_position.y - start_y > -250.0)
	check("保留 -z 向滑行分量（实测 vz=%.1f，切向不被吃）" % v.z, v.z < -50.0)
	check("速度未被异常杀死（实测 %.1f ≥ 90）" % v.length(), v.length() >= 90.0)

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
