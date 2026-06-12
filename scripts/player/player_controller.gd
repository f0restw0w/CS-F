extends CharacterBody3D
class_name PlayerController
## GoldSrc 风格玩家控制器。改动前必读 docs/MOVEMENT_SPEC.md。
##
## 主循环完全按 MOVEMENT_SPEC.md「主循环」伪代码：固定步长 _physics_process，
## 地面/空中分支，move_and_collide + 手动 clip_velocity（绝不用 move_and_slide，
## Godot 的 slide 会改速度向量，破坏 air strafe 数学）。
##
## Phase 1 新增：蹲/duck-jump（HL SDK PM_Duck/PM_UnDuck 行为）、台阶视角平滑。

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
## 空中蹲时脚部抬升 = (站立 hull 72 − 蹲 hull 36)/2 = 18。
## GoldSrc origin 在 hull 中心、空中收 hull 时 origin 不动 → 等效脚抬 18，
## 这正是 duck-jump 能跨上更高箱子的原因。
const DUCK_FEET_LIFT := 18.0

@export var params: MovementParams

## 是否在地面（手动判定，不用 is_on_floor —— 那是 move_and_slide 的配套）
var grounded := false
## 本次起跳是否为落地帧立即重跳（连跳保速），供调试 HUD 显示
var bhop_preserved := false
## 是否完全蹲下（hull 已切换为 36）
var ducked := false

var _was_grounded := false
var _spawn_transform: Transform3D
## 地面蹲下过渡计时（TIME_TO_DUCK；空中蹲瞬时完成不走计时）
var _duck_timer := 0.0
## 台阶视角平滑偏移（上台阶为负=镜头滞后在下方，按 step_smooth_speed 衰减回 0）
var _step_offset := 0.0
## 站起空间检测用 shape（站立 hull 略缩，避免贴墙/贴地误判）
var _stand_check_shape: BoxShape3D

@onready var _shape_node: CollisionShape3D = $CollisionShape3D
@onready var _hull_shape: BoxShape3D = _shape_node.shape
@onready var _head: Node3D = $Head


func _ready() -> void:
	add_to_group("player")
	if params == null:
		params = load("res://resources/movement_params.tres")
	_spawn_transform = global_transform
	_stand_check_shape = BoxShape3D.new()
	_stand_check_shape.size = Vector3(30, params.stand_hull_height - 2.0, 30)


func _physics_process(delta: float) -> void:
	_categorize_position()
	_update_duck(delta)

	var wishdir := _get_wishdir()
	var wishspeed: float = params.max_speed  # sv_maxspeed
	if ducked:
		# PLAYER_DUCKING_MULTIPLIER：完全蹲下时限速（地面/空中都生效，HL SDK PM_CheckParamters）
		wishspeed *= params.duck_speed_multiplier

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
	_update_eye(delta)

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


## —— 蹲（HL SDK PM_Duck / PM_UnDuck）——

func _update_duck(delta: float) -> void:
	var held := Input.is_action_pressed("duck")
	if held:
		if ducked:
			return
		if grounded:
			# 地面蹲：TIME_TO_DUCK 过渡，时间到才切 hull（眼高在 _update_eye 里随进度下移）
			_duck_timer += delta
			if _duck_timer >= params.time_to_duck:
				_set_ducked_hull()
		else:
			# 空中蹲瞬时完成：hull 收到 36 且脚抬 18（duck-jump 本体）。
			# 新 hull 完全包含在旧 hull 内，无需空间检测。
			_set_ducked_hull()
			global_position.y += DUCK_FEET_LIFT
	else:
		_duck_timer = 0.0
		if ducked:
			_try_unduck()


func _try_unduck() -> void:
	if grounded:
		# 地面站起：脚不动，头上要有空间
		if _can_stand(global_position):
			_set_standing_hull()
	else:
		# 空中站起：脚放回 18（对应空中蹲的抬升；GoldSrc origin 不动 → 脚下落 18）
		var target := global_position + Vector3(0, -DUCK_FEET_LIFT, 0)
		if _can_stand(target):
			_set_standing_hull()
			global_position = target
		elif _can_stand(global_position):
			# 脚下没空间（贴近地面等）则原地站起
			_set_standing_hull()
	# 两处都不行 → 保持蹲（低顶通道内卡蹲，GoldSrc 同）


func _set_ducked_hull() -> void:
	ducked = true
	_duck_timer = 0.0
	_hull_shape.size.y = params.duck_hull_height
	_shape_node.position.y = params.duck_hull_height * 0.5


func _set_standing_hull() -> void:
	ducked = false
	_hull_shape.size.y = params.stand_hull_height
	_shape_node.position.y = params.stand_hull_height * 0.5


## 站立 hull（略缩 1 单位余量）在 feet 位置是否无碰撞
func _can_stand(feet: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _stand_check_shape
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0, params.stand_hull_height * 0.5, 0))
	q.exclude = [get_rid()]
	q.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## —— 移动 ——

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

	# 台阶视角平滑：地面位移的垂直跳变记入偏移，由 _update_eye 按 150 u/s 衰减
	# （HL V_CalcRefdef 的 stair smoothing）
	var dy := global_position.y - start_pos.y
	if absf(dy) > 0.01:
		_step_offset = clampf(_step_offset - dy, -STEP_HEIGHT, STEP_HEIGHT)


## —— 视角高度（眼高 + 台阶平滑）——

func _update_eye(delta: float) -> void:
	_step_offset = move_toward(_step_offset, 0.0, params.step_smooth_speed * delta)
	var eye: float
	if ducked:
		eye = params.duck_eye_height
	elif _duck_timer > 0.0:
		# 地面蹲下过渡：眼高随 TIME_TO_DUCK 进度下移（hull 在过渡结束才切换）
		eye = lerpf(params.stand_eye_height, params.duck_eye_height,
				clampf(_duck_timer / params.time_to_duck, 0.0, 1.0))
	else:
		eye = params.stand_eye_height
	_head.position.y = eye + _step_offset


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_set_standing_hull()
	_duck_timer = 0.0
	_step_offset = 0.0


## —— 调试 HUD 读数 ——

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func vertical_speed() -> float:
	return velocity.y
