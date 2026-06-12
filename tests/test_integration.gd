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
	check("落点贴 T 家高地（y ≈ 128）", absf(player.global_position.y - 128.0) < 4.0)

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
	player.global_position = Vector3(700, 162, -640)
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

	# —— Phase 1：蹲 / duck-jump ——

	# 6) 地面蹲：0.4s 过渡后 hull 切换、眼高 30、蹲速 ≈ 320*0.333 ≈ 106.6
	player.global_position = Vector3(0, 130, 1300)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	Input.action_press("duck")
	for i in 50:
		await physics_frame  # 0.5s > TIME_TO_DUCK
	check("地面蹲 0.4s 后完全蹲下", player.ducked)
	check("蹲下眼高 ≈ 30（实测 %.1f）" % player.get_node("Head").position.y,
			absf(player.get_node("Head").position.y - 30.0) < 1.0)
	Input.action_press("move_forward")
	for i in 150:
		await physics_frame
	var duck_speed := player.horizontal_speed()
	Input.action_release("move_forward")
	check("蹲走限速 ≈ 106.6（实测 %.1f）" % duck_speed,
			duck_speed > 100.0 and duck_speed < 112.0)

	# 7) 站起恢复
	Input.action_release("duck")
	for i in 20:
		await physics_frame
	check("松开蹲后站起", not player.ducked)
	check("站立眼高恢复 64（实测 %.1f）" % player.get_node("Head").position.y,
			absf(player.get_node("Head").position.y - 64.0) < 1.0)

	# 8) duck-jump：空中蹲脚抬 18，脚部顶点 ≈ 45+18 = 63（普通跳 ≈ 45）
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	var ground_y := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	for i in 5:
		await physics_frame
	Input.action_press("duck")
	var apex := 0.0
	for i in 80:
		apex = maxf(apex, player.global_position.y - ground_y)
		await physics_frame
	Input.action_release("duck")
	for i in 20:
		await physics_frame
	check("duck-jump 脚部顶点 ≈ 63（实测 %.1f，普通跳 ≈ 45）" % apex,
			apex > 55.0 and apex < 72.0)

	# 9) 低顶卡蹲：头顶放障碍（占 feet+46..62），松蹲不能站起；移除后自动站起
	Input.action_press("duck")
	for i in 50:
		await physics_frame
	check("低顶测试前提：已蹲下", player.ducked)
	var ceiling := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 16, 200)
	cs.shape = bs
	ceiling.add_child(cs)
	root.add_child(ceiling)
	ceiling.global_position = player.global_position + Vector3(0, 54, 0)
	for i in 5:
		await physics_frame
	Input.action_release("duck")
	for i in 20:
		await physics_frame
	check("低顶下松蹲仍保持蹲（卡蹲）", player.ducked)
	ceiling.queue_free()
	for i in 20:
		await physics_frame
	check("移除低顶后自动站起", not player.ducked)

	# 10) B 隧道（含 S 弯）全程路点通行：每个路点落地且高度正确，防墙体堵路
	var waypoints: Array = [
		["上隧道(64)", Vector3(-900, 66, 1096), 64.0],
		["S1 上段(64)", Vector3(-1004, 66, 700), 64.0],
		["S1 下段(0)", Vector3(-1004, 2, 232), 0.0],
		["肘部拐弯(0)", Vector3(-1052, 2, 100), 0.0],
		["S2 段(0)", Vector3(-1100, 2, -228), 0.0],
		["B 点入口(0)", Vector3(-1100, 2, -610), 0.0],
	]
	for wp in waypoints:
		player.global_position = wp[1]
		player.velocity = Vector3.ZERO
		for i in 20:
			await physics_frame
		check("隧道路点[%s]落地且高度对（y=%.1f≈%.0f）" % [wp[0], player.global_position.y, wp[2]],
				player.grounded and absf(player.global_position.y - wp[2]) < 6.0)

	# 11) 标高坡道：T 家走下中路大坡（128→0），全程贴地不弹跳
	player.global_position = Vector3(0, 130, 1000)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	Input.action_press("move_forward")
	var air_ticks := 0
	for i in 150:
		if not player.grounded:
			air_ticks += 1
		await physics_frame
	Input.action_release("move_forward")
	check("走下中路大坡贴地（空中 tick=%d ≤ 5）" % air_ticks, air_ticks <= 5)
	check("到达中路平面（y=%.1f ≈ 0）" % player.global_position.y,
			absf(player.global_position.y) < 6.0)

	# 12) 长 A 大坡：直道(64)跑上 A 点(160)
	player.global_position = Vector3(1078, 66, -200)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	Input.action_press("move_forward")
	for i in 140:
		await physics_frame
	Input.action_release("move_forward")
	check("跑上长A大坡抵达 A 点（y=%.1f ≈ 160）" % player.global_position.y,
			absf(player.global_position.y - 160.0) < 6.0)

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
