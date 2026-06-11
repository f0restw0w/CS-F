class_name GoldSrcMovement
## GoldSrc 移动数学，纯静态函数，严格按 docs/MOVEMENT_SPEC.md 的伪代码还原
## （对应 pm_shared.c 的 PM_Accelerate / PM_AirAccelerate / PM_Friction / PM_ClipVelocity）。
##
## 全部为无副作用的纯函数：输入速度 → 返回新速度，方便单元测试与对照 spec 审查。
## 任何改动必须先读 docs/MOVEMENT_SPEC.md，commit 带 [FEEL]。


## PM_Accelerate — 地面加速。
## accel 对应 sv_accelerate（默认 5.0），wishspeed 上限为 sv_maxspeed（默认 320）。
static func accelerate(velocity: Vector3, wishdir: Vector3, wishspeed: float, accel: float, delta: float) -> Vector3:
	var current_speed: float = velocity.dot(wishdir)
	var add_speed: float = wishspeed - current_speed
	if add_speed <= 0.0:
		return velocity
	var accel_speed: float = accel * delta * wishspeed
	accel_speed = minf(accel_speed, add_speed)
	return velocity + accel_speed * wishdir


## PM_AirAccelerate — 空气加速，air strafe 的核心。
## airaccel 对应 sv_airaccelerate（默认 10.0）。
##
## ⚠️ 关键不对称（GoldSrc 原始行为，绝不要"修正"）：
##   - add_speed 的判定用裁剪后的 wishspd（裁到 wish_speed_cap ≈ 30）
##   - accel_speed 的计算用未裁剪的原始 wishspeed
## 这就是"空中沿当前方向无法直线加速、但偏离当前速度方向的 wishdir 能瞬间吃满
## 加速"的原因——air strafe 靠转向加速的数学本质。
static func air_accelerate(velocity: Vector3, wishdir: Vector3, wishspeed: float, airaccel: float, wish_speed_cap: float, delta: float) -> Vector3:
	var wishspd: float = minf(wishspeed, wish_speed_cap)
	var current_speed: float = velocity.dot(wishdir)
	var add_speed: float = wishspd - current_speed
	if add_speed <= 0.0:
		return velocity
	var accel_speed: float = airaccel * wishspeed * delta
	accel_speed = minf(accel_speed, add_speed)
	return velocity + accel_speed * wishdir


## PM_Friction — 地面摩擦。只在地面调用，空中无摩擦（连跳保速的前提）。
## friction 对应 sv_friction（默认 4.0），stop_speed 对应 sv_stopspeed（默认 75.0）。
## stop_speed 让低速时摩擦按 stopspeed 计算 → 急停干脆。
static func apply_friction(velocity: Vector3, friction: float, stop_speed: float, delta: float) -> Vector3:
	var speed: float = velocity.length()
	if speed < 0.1:
		return velocity
	var control: float = maxf(speed, stop_speed)
	var drop: float = control * friction * delta
	var new_speed: float = maxf(speed - drop, 0.0) / speed
	return velocity * new_speed


## PM_ClipVelocity — 撞墙/贴面削速：移除法向分量，保留切向分量。
## overbounce 通常 1.0。这是贴墙滑行与 surf 的基础。
static func clip_velocity(velocity: Vector3, normal: Vector3, overbounce: float = 1.0) -> Vector3:
	var backoff: float = velocity.dot(normal) * overbounce
	return velocity - normal * backoff
