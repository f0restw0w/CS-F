extends CharacterBody3D
class_name PlayerController
## GoldSrc 风格玩家控制器。改动前必读 docs/MOVEMENT_SPEC.md。
##
## 主循环完全按 MOVEMENT_SPEC.md「主循环」伪代码：固定步长 _physics_process，
## 地面/空中分支，move_and_collide + 手动 clip_velocity（绝不用 move_and_slide，
## Godot 的 slide 会改速度向量，破坏 air strafe 数学）。

## GoldSrc 玩家可跨台阶高度 18（docs/MAP_DUST2.md 玩家参照尺寸）
const STEP_HEIGHT := 18.0
## GoldSrc 可站立面法线 y 阈值 0.7（约 45° 以内算地面，更陡算墙/surf 面）
const GROUND_NORMAL_MIN_Y := 0.7
## GoldSrc：垂直速度 > 180 视为离地（pm_shared PM_CatagorizePosition）
const LEAVE_GROUND_VY := 180.0
## GoldSrc 地面判定向下 trace 距离 2 单位
const GROUND_TRACE_DIST := 2.0
## PM_FlyMove 单 tick 最多处理的裁剪面数
const MAX_CLIP_PLANES := 4

@export var params: MovementParams

## 是否在地面（手动判定，不用 is_on_floor —— 那是 move_and_slide 的配套）
var grounded := false
## 本次起跳是否为落地帧立即重跳（连跳保速），供调试 HUD 显示
var bhop_preserved := false

var _was_grounded := false
var _spawn_transform: Transform3D


func _ready() -> void:
	add_to_group("player")
	if params == null:
		params = load("res://resources/movement_params.tres")
	_spawn_transform = global_transform


func _physics_process(delta: float) -> void:
	_categorize_position()

	var wishdir := _get_wishdir()
	var wishspeed: float = params.max_speed  # sv_maxspeed

	# 跳跃在摩擦之前处理：落地帧按住跳 → 本 tick 直接走空中分支，
	# 跳过落地摩擦帧 —— 连跳保速的核心（MOVEMENT_SPEC.md §5 Bunnyhop）
	if grounded and Input.is_action_pressed("jump"):
		bhop_preserved = not _was_grounded  # 落地瞬间重跳 = 连跳；原地起跳不算
		velocity.y = params.jump_velocity()
		grounded = false

	if grounded:
		bhop_preserved = false
		velocity.y = 0.0
		velocity = GoldSrcMovement.apply_friction(velocity, params.friction, params.stop_speed, delta)
		velocity = GoldSrcMovement.accelerate(velocity, wishdir, wishspeed, params.accelerate, delta)
		_walk_move(delta)
	else:
		velocity = GoldSrcMovement.air_accelerate(velocity, wishdir, wishspeed, params.air_accelerate, params.air_wish_speed_cap, delta)
		velocity.y -= params.gravity * delta  # sv_gravity
		_fly_move(delta)

	_was_grounded = grounded

	# 调试便利：掉出地图自动回出生点
	if global_position.y < -1000.0:
		respawn()


## 从输入 + 玩家朝向（yaw）计算水平 wishdir。鼠标只决定朝向，不直接改速度。
func _get_wishdir() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var dir := global_transform.basis.x * input.x + global_transform.basis.z * input.y
	dir.y = 0.0
	return dir.normalized()


## GoldSrc PM_CatagorizePosition 的简化：向下 trace 2 单位找可站立面。
func _categorize_position() -> void:
	if velocity.y > LEAVE_GROUND_VY:
		grounded = false
		return
	var coll := move_and_collide(Vector3(0, -GROUND_TRACE_DIST, 0), true)
	grounded = coll != null and coll.get_normal().y >= GROUND_NORMAL_MIN_Y


## PM_FlyMove：移动 + 撞面后用 clip_velocity 投影，最多迭代 4 个面。
func _fly_move(delta: float) -> void:
	var motion := velocity * delta
	for i in MAX_CLIP_PLANES:
		var coll := move_and_collide(motion)
		if coll == null:
			return
		var normal := coll.get_normal()
		velocity = GoldSrcMovement.clip_velocity(velocity, normal)
		motion = GoldSrcMovement.clip_velocity(coll.get_remainder(), normal)
		if motion.length_squared() < 1e-8:
			return


## PM_WalkMove：地面移动 + 台阶攀爬。
## 先普通 fly_move，再尝试「抬 18 → 平移 → 落回」，取水平走得更远的结果。
func _walk_move(delta: float) -> void:
	var start_pos := global_position
	var start_vel := velocity

	_fly_move(delta)
	var normal_pos := global_position
	var normal_vel := velocity

	# 尝试 step（GoldSrc 标准做法：两种走法取优）
	global_position = start_pos
	velocity = start_vel
	move_and_collide(Vector3(0, STEP_HEIGHT, 0))
	_fly_move(delta)
	move_and_collide(Vector3(0, -(STEP_HEIGHT + GROUND_TRACE_DIST), 0))

	var step_landing := move_and_collide(Vector3(0, -GROUND_TRACE_DIST, 0), true)
	var step_ok := step_landing != null and step_landing.get_normal().y >= GROUND_NORMAL_MIN_Y

	var d_normal := Vector2(normal_pos.x - start_pos.x, normal_pos.z - start_pos.z).length_squared()
	var d_step := Vector2(global_position.x - start_pos.x, global_position.z - start_pos.z).length_squared()

	if not step_ok or d_normal > d_step:
		global_position = normal_pos
		velocity = normal_vel
	else:
		# step 成功时保留普通走法的垂直速度（GoldSrc 行为）
		velocity.y = normal_vel.y

	# 贴地：下坡/下台阶时在 step 高度内吸附，避免每 tick 误判为空中
	if velocity.y <= 0.0:
		var snap := move_and_collide(Vector3(0, -STEP_HEIGHT, 0), true)
		if snap and snap.get_normal().y >= GROUND_NORMAL_MIN_Y:
			move_and_collide(Vector3(0, -STEP_HEIGHT, 0))


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO


## —— 调试 HUD 读数 ——

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func vertical_speed() -> float:
	return velocity.y
