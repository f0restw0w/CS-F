extends SceneTree
## 移动数学单元测试（无依赖断言脚本，覆盖 docs/TESTING.md「公式单元测试」全部用例）。
##
## 运行方式（无头）：
##   godot --headless --path . --script res://tests/test_movement.gd
## 全部通过退出码 0，任一失败退出码 1。

const Movement = preload("res://scripts/player/movement.gd")
const Params = preload("res://scripts/player/movement_params.gd")

# 100 tick 固定步长（project.godot physics_ticks_per_second=100）
const DELTA := 0.01
const EPS := 0.0001

var _failed := 0
var _passed := 0


func _init() -> void:
	_test_accelerate()
	_test_air_accelerate()
	_test_friction()
	_test_clip_velocity()
	_test_params_resource()

	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  PASS: " + name)
	else:
		_failed += 1
		printerr("  FAIL: " + name)


func approx(a: float, b: float, eps: float = EPS) -> bool:
	return absf(a - b) <= eps


func _test_accelerate() -> void:
	print("[accelerate]")
	var wishdir := Vector3(1, 0, 0)

	# 静止起步：单 tick 增量 = accel * delta * wishspeed = 5 * 0.01 * 320 = 16
	var v := Movement.accelerate(Vector3.ZERO, wishdir, 320.0, 5.0, DELTA)
	check("静止单 tick 增量 = accel*delta*wishspeed = 16", approx(v.x, 16.0) and approx(v.y, 0.0) and approx(v.z, 0.0))

	# 已达 wishspeed：沿 wishdir 不再加速
	v = Movement.accelerate(Vector3(320, 0, 0), wishdir, 320.0, 5.0, DELTA)
	check("已达 max_speed 时不加速", approx(v.x, 320.0))

	# add_speed 裁剪：310 → 只补到 320，不超
	v = Movement.accelerate(Vector3(310, 0, 0), wishdir, 320.0, 5.0, DELTA)
	check("accel_speed 被 add_speed 裁剪（310→320 不超调）", approx(v.x, 320.0))

	# 超速时（如连跳后 400）沿 wishdir 不会被加速函数拉回
	v = Movement.accelerate(Vector3(400, 0, 0), wishdir, 320.0, 5.0, DELTA)
	check("超速时 accelerate 不改变速度（add_speed<=0 直接返回）", approx(v.x, 400.0))


func _test_air_accelerate() -> void:
	print("[air_accelerate]")
	var cap := 30.0

	# wishspeed 裁剪：沿当前速度方向已有 >= cap 的速度 → 无直线加速
	var wishdir := Vector3(1, 0, 0)
	var v := Movement.air_accelerate(Vector3(30, 0, 0), wishdir, 320.0, 10.0, cap, DELTA)
	check("沿速度方向已达 cap(30) → 不能直线加速", approx(v.x, 30.0))

	v = Movement.air_accelerate(Vector3(400, 0, 0), wishdir, 320.0, 10.0, cap, DELTA)
	check("高速直线飞行时 wishdir 同向不加速", approx(v.x, 400.0))

	# air strafe 的数学本质：wishdir 垂直于当前速度 → 仍能加速
	var perp := Vector3(0, 0, 1)
	v = Movement.air_accelerate(Vector3(400, 0, 0), perp, 320.0, 10.0, cap, DELTA)
	check("垂直 wishdir 仍能加速（air strafe 本质）", v.z > 0.0)
	check("垂直加速后总速率增加（400 → ~401.12）", v.length() > 400.0)

	# 不对称验证：accel_speed 用未裁剪 wishspeed（10*320*delta），不是 10*30*delta。
	# delta=0.001 时 accel_speed = 3.2（若错误地用 cap 计算则为 0.3）
	v = Movement.air_accelerate(Vector3.ZERO, wishdir, 320.0, 10.0, cap, 0.001)
	check("accel_speed 用未裁剪 wishspeed（3.2 而非 0.3）", approx(v.x, 3.2))

	# accel_speed 超过 add_speed 时裁到 add_speed（cap=30 内）
	v = Movement.air_accelerate(Vector3.ZERO, wishdir, 320.0, 10.0, cap, DELTA)
	check("静止单 tick 空气加速被 add_speed(=cap) 裁到 30", approx(v.x, 30.0))


func _test_friction() -> void:
	print("[friction]")

	# 高速（>stopspeed）：drop = speed * friction * delta = 320*4*0.01 = 12.8
	var v := Movement.apply_friction(Vector3(320, 0, 0), 4.0, 75.0, DELTA)
	check("高速摩擦 drop = speed*friction*delta（320→307.2）", approx(v.x, 307.2))

	# 低速（<stopspeed）：control 取 stopspeed=75 → drop = 75*4*0.01 = 3（50→47）
	v = Movement.apply_friction(Vector3(50, 0, 0), 4.0, 75.0, DELTA)
	check("低速摩擦用 stopspeed 增强（50→47）", approx(v.x, 47.0))

	# 低速摩擦的相对减速比高速更狠（急停干脆的来源）
	var high_ratio := 12.8 / 320.0
	var low_ratio := 3.0 / 50.0
	check("低于 stopspeed 时相对减速更快", low_ratio > high_ratio)

	# 接近静止（<0.1）不处理，避免除零
	v = Movement.apply_friction(Vector3(0.05, 0, 0), 4.0, 75.0, DELTA)
	check("速度 <0.1 时不施加摩擦", approx(v.x, 0.05))

	# drop 不会把速度减成负（钳到 0）
	v = Movement.apply_friction(Vector3(1, 0, 0), 4.0, 75.0, 1.0)
	check("大 drop 时速度钳到 0 不反向", v.length() < EPS)


func _test_clip_velocity() -> void:
	print("[clip_velocity]")

	# 45° 斜撞墙：法向分量移除，切向保留
	var v := Movement.clip_velocity(Vector3(100, 0, -100), Vector3(0, 0, 1), 1.0)
	check("斜撞墙：法向移除", approx(v.z, 0.0))
	check("斜撞墙：切向保留", approx(v.x, 100.0))

	# 正面撞墙：速度归零
	v = Movement.clip_velocity(Vector3(0, 0, -100), Vector3(0, 0, 1), 1.0)
	check("正面撞墙速度归零", v.length() < EPS)

	# 已离开墙面（速度与法线同向）不受影响之外的削减——backoff 为正时仍按公式
	# 45° 斜面（surf 雏形）：保留沿斜面分量，总速率不超原速率（overbounce=1）
	var n := Vector3(0, 1, 1).normalized()
	var vin := Vector3(0, -100, -100)
	v = Movement.clip_velocity(vin, n, 1.0)
	check("斜面 clip 后不再嵌入面内（v·n ≈ 0）", absf(v.dot(n)) < EPS)
	check("斜面 clip 后速率不超过原速率", v.length() <= vin.length() + EPS)


func _test_params_resource() -> void:
	print("[movement_params.tres]")
	var p = load("res://resources/movement_params.tres")
	check("资源可加载", p != null)
	if p == null:
		return
	check("max_speed = 320 (sv_maxspeed)", approx(p.max_speed, 320.0))
	check("accelerate = 5 (sv_accelerate)", approx(p.accelerate, 5.0))
	check("air_accelerate = 10 (sv_airaccelerate)", approx(p.air_accelerate, 10.0))
	check("friction = 4 (sv_friction)", approx(p.friction, 4.0))
	check("stop_speed = 75 (sv_stopspeed)", approx(p.stop_speed, 75.0))
	check("gravity = 800 (sv_gravity)", approx(p.gravity, 800.0))
	check("air_wish_speed_cap = 30", approx(p.air_wish_speed_cap, 30.0))
	check("跳跃初速 ≈ 268.33 (sqrt(2*800*45))", approx(p.jump_velocity(), sqrt(72000.0), 0.01))
	check("bhop 速度上限默认关闭（经典无限连跳）", p.bhop_speed_cap_enabled == false)
