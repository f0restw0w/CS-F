extends SceneTree
## 集成冒烟测试：加载灰盒 dust2，模拟输入，验证控制器在真实场景里的行为。
##
## 运行方式（无头）：
##   godot --headless --path . --script res://tests/test_integration.gd
##
## 覆盖：落地着陆 / 直线跑到 sv_maxspeed / 跳跃初速 / air strafe 空中转向加速。

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
	var scene: Node = (load("res://scenes/dust2.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame

	var player := scene.get_node("Player") as PlayerController
	check("场景含 PlayerController", player != null)
	if player == null:
		_finish()
		return

	# 1) 出生后稳定落地
	for i in 50:
		await physics_frame
	check("出生后落地（grounded）", player.grounded)
	check("落点贴地（y ≈ 0）", absf(player.global_position.y) < 4.0)

	# 2) 直线跑加速到 sv_maxspeed=320
	#    只跑 0.8 秒（约 230 单位）——再远会撞上中路 Xbox 箱（正面 clip 会把速度归零）
	Input.action_press("move_forward")
	for i in 80:
		await physics_frame
	var run_speed := player.horizontal_speed()
	Input.action_release("move_forward")
	check("直线跑稳定在 max_speed（实测 %.1f ≈ 320）" % run_speed,
			run_speed > 315.0 and run_speed < 321.0)

	# 3) 跳跃初速 ≈ sqrt(2*800*45) ≈ 268（读数时已扣 2 tick 重力 16）
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	var vy := player.vertical_speed()
	Input.action_release("jump")
	check("跳跃初速 ≈ 268（实测 %.1f）" % vy, vy > 245.0 and vy < 270.0)

	# 4) air strafe：传送到开阔 A 点，助跑起跳后松前进、按住 A + 每 tick 左转，
	#    速率应明显超过起跳时速率（air strafe 转向加速的标志）
	for i in 60:
		await physics_frame  # 等落地稳定
	player.global_position = Vector3(700, 2, -640)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 10:
		await physics_frame
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame  # 助跑到接近 320
	var pre_strafe := player.horizontal_speed()
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	Input.action_release("move_forward")
	Input.action_press("move_right")
	var airborne_ticks := 0
	for i in 50:
		if not player.grounded:
			player.rotate_y(-0.035)  # 模拟鼠标匀速右转（约 2°/tick），右侧开阔无箱
			airborne_ticks += 1
		await physics_frame
	Input.action_release("move_right")
	var post_strafe := player.horizontal_speed()
	check("air strafe 空中加速生效（%.1f → %.1f，空中 %d tick）" % [pre_strafe, post_strafe, airborne_ticks],
			post_strafe > pre_strafe + 5.0 and pre_strafe > 250.0)

	# 5) 全程没有掉出地图
	check("未掉出地图（y > -200）", player.global_position.y > -200.0)

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
