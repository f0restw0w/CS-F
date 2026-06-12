extends SceneTree
## 武器系统测试（Phase 2）：靶场实测射击/伤害/爆头/射速/换弹/扩散态/弹道爬升。
##
## 运行方式（无头）：
##   godot --headless --path . --script res://tests/test_weapon.gd

var _failed := 0
var _passed := 0
var _hit_events: Array = []  # [damage, is_head]


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
	var scene: Node = (load("res://scenes/test_range.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame

	var player := scene.get_node("Player") as PlayerController
	var weapon := player.get_node("Head/Camera3D/Weapon") as HitscanWeapon
	var head := player.get_node("Head") as Node3D
	var target := scene.get_node("Target_256") as ShootingTarget
	check("场景含武器与靶子", weapon != null and target != null)
	if weapon == null:
		_finish()
		return
	weapon.hit_target.connect(func(d: float, h: bool, _t: Node) -> void: _hit_events.append([d, h]))

	for i in 30:
		await physics_frame  # 落地稳定

	# 1) 直射爆头：眼高 66 对正前方靶头区(56..68)，距离 256
	#    伤害 = 36 × 0.98^(256/512) × 4 ≈ 142.6 → 一发击杀(100hp)
	_hit_events.clear()
	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	for i in 10:
		await physics_frame
	check("开火消耗弹药（mag 30→29）", weapon.mag == 29)
	check("命中事件触发", _hit_events.size() == 1)
	if _hit_events.size() == 1:
		check("直射判定为爆头", _hit_events[0][1] == true)
		check("爆头伤害 ≈ 142.6（实测 %.1f）" % _hit_events[0][0],
				absf(_hit_events[0][0] - 142.6) < 3.0)
	check("100hp 靶被一发爆头击杀", target.times_killed == 1)

	# 2) 压枪打身体：下压 3.4°，256 距离落点低 ~15 → 身体区
	for i in 180:
		await physics_frame  # 等靶子重生（1.5s=150 tick）+ pattern 复位
	head.rotation.x = -0.06
	_hit_events.clear()
	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	for i in 10:
		await physics_frame
	check("身体命中（非爆头）", _hit_events.size() == 1 and _hit_events[0][1] == false)
	if _hit_events.size() == 1:
		check("身体伤害 ≈ 35.6（实测 %.1f）" % _hit_events[0][0],
				absf(_hit_events[0][0] - 35.6) < 2.0)
	head.rotation.x = 0.0

	# 3) 射速：满匣按住 1.05s → 间隔 0.1s 应打出 11 发（t=0,0.1,...,1.0）
	weapon.mag = weapon.params.magazine_size
	weapon.reserve = weapon.params.reserve_ammo
	for i in 60:
		await physics_frame
	var mag_before := weapon.mag
	Input.action_press("fire")
	for i in 105:
		await physics_frame
	Input.action_release("fire")
	var shots := mag_before - weapon.mag
	check("射速 0.1s/发（1.05s 实测 %d 发，期望 11）" % shots, shots >= 10 and shots <= 12)

	# 4) 弹道爬升：刚才连射 11 发，落点应随 pattern 上爬
	#    （比较连射期间 last_hit_point 不可行——已结束；改为重新连射采样）
	for i in 80:
		await physics_frame  # pattern 复位
	var first_y := 0.0
	var last_y := 0.0
	Input.action_press("fire")
	for i in 100:
		if i == 2:
			first_y = weapon.last_hit_point.y
		await physics_frame
	Input.action_release("fire")
	last_y = weapon.last_hit_point.y
	check("连射弹道上爬（首发落点 y=%.1f → 第10发 y=%.1f）" % [first_y, last_y],
			last_y > first_y + 30.0)

	# 5) 手动换弹
	var before_reserve := weapon.reserve
	Input.action_press("reload")
	await physics_frame
	Input.action_release("reload")
	await physics_frame
	check("换弹开始", weapon.reloading)
	for i in 260:
		await physics_frame  # 2.6s > 2.45s
	check("换弹完成：弹匣补满", weapon.mag == weapon.params.magazine_size)
	check("换弹消耗备弹", weapon.reserve < before_reserve)

	# 6) 扩散分态
	var s_stand := weapon.current_spread_deg()
	check("站立扩散 0.08（实测 %.3f）" % s_stand, absf(s_stand - 0.08) < 0.001)
	Input.action_press("duck")
	for i in 50:
		await physics_frame
	var s_duck := weapon.current_spread_deg()
	check("蹲下扩散 ×0.6 = 0.048（实测 %.3f）" % s_duck, absf(s_duck - 0.048) < 0.001)
	Input.action_release("duck")
	for i in 30:
		await physics_frame
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
	var s_move := weapon.current_spread_deg()
	Input.action_release("move_forward")
	check("移动扩散 1.6（实测 %.3f）" % s_move, absf(s_move - 1.6) < 0.001)

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
