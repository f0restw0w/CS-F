extends SceneTree
## 联机端到端测试（Phase 4）：连接无头专服 → 出生 → 预测移动 → 校验收敛。
##
## 运行方式（需先后台启动专服）：
##   godot --headless res://scenes/dust2_mp.tscn -- --server 27123   （进程 A）
##   godot --headless --script res://tests/test_multiplayer.gd       （进程 B，本脚本）
##
## 断言：连接成功、双端玩家生成、预测移动生效、ack 流回包、回滚误差收敛。

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
	var scene: Node = (load("res://scenes/dust2_mp.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame

	var manager := scene.get_node("NetworkManager") as NetworkManager
	check("场景含 NetworkManager", manager != null)
	if manager == null:
		_finish()
		return

	var err := manager.join("127.0.0.1", 27123)
	check("发起连接", err == OK)

	# 等待连接 + 本地玩家生成（最多 8s）
	var waited := 0
	while manager.local_player == null and waited < 800:
		await physics_frame
		waited += 1
	check("本地玩家已生成（等待 %d tick）" % waited, manager.local_player != null)
	if manager.local_player == null:
		_finish()
		return
	var player: PlayerController = manager.local_player

	for i in 50:
		await physics_frame  # 落地稳定
	check("出生落地", player.grounded)

	# 预测移动：按住 W 1.5s
	var z0 := player.global_position.z
	Input.action_press("move_forward")
	for i in 150:
		await physics_frame
	Input.action_release("move_forward")
	var moved := z0 - player.global_position.z
	check("预测移动生效（前进 %.0f 单位）" % moved, moved > 250.0)
	check("收到服务器 ack（%d 个）" % manager.acks_received, manager.acks_received > 20)
	check("预测误差收敛（最近误差 %.3f < 2.0）" % manager.last_correction_error,
			manager.last_correction_error < 2.0)
	print("  [info] 回滚次数: %d" % manager.corrections)

	# 联机 bhop 冒烟：跳+前进 1s，不应出现状态爆炸
	Input.action_press("jump")
	Input.action_press("move_forward")
	for i in 100:
		await physics_frame
	Input.action_release("jump")
	Input.action_release("move_forward")
	for i in 30:
		await physics_frame
	var speed := player.horizontal_speed()
	check("联机连跳后速度合理（实测 %.1f ≤ 450）" % speed, speed <= 450.0 and is_finite(speed))
	check("位置未发散（|y| < 400，T 家高地 128 基准）", absf(player.global_position.y) < 400.0)
	check("回滚后误差仍收敛（%.3f < 2.0）" % manager.last_correction_error,
			manager.last_correction_error < 2.0)

	# 远端傀儡：等第二个客户端（由测试编排外部启动）出现并被插值摆位
	waited = 0
	while manager._puppets.is_empty() and waited < 1000:
		await physics_frame
		waited += 1
	check("远端玩家傀儡已生成（%d 个，等待 %d tick）" % [manager._puppets.size(), waited],
			not manager._puppets.is_empty())
	if not manager._puppets.is_empty():
		var puppet: PlayerController = manager._puppets.values()[0]
		for i in 50:
			await physics_frame  # 让快照插值跑起来
		check("傀儡位置有效（|pos|=%.0f < 5000）" % puppet.global_position.length(),
				puppet.global_position.length() < 5000.0)

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
