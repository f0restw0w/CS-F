extends CharacterBody3D
class_name PlayerController
## GoldSrc 风格玩家控制器。改动前必读 docs/MOVEMENT_SPEC.md。
##
## 主循环完全按 MOVEMENT_SPEC.md「主循环」伪代码：固定步长，地面/空中分支，
## move_and_collide + 手动 clip_velocity（绝不用 move_and_slide）。
##
## Phase 4 重构：物理步进抽成确定性 simulate(input, delta)——
## 本地预测、服务器权威模拟、回滚重放走同一条代码路径，保证联机手感不变形。
## 鼠标视角只产生 input.yaw，不直接进物理。

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
## 空中蹲时脚部抬升 = (站立 hull 72 − 蹲 hull 36)/2 = 18（duck-jump 本体）
const DUCK_FEET_LIFT := 18.0

## 本 tick 模拟完成（联机层用来取输入发服务器）
signal input_simulated(inp: PlayerInput)
signal health_changed(health: float)
signal died

@export var params: MovementParams

## true = 本地玩家（每 tick 自采输入并预测模拟）；
## false = 服务器端镜像/远端傀儡（由外部调 simulate() 或直接摆位置）
var is_local := true

var grounded := false
var bhop_preserved := false
var ducked := false
## 联机生命值（单机不消耗）
var health := 100.0

var _was_grounded := false
var _spawn_transform: Transform3D
var _duck_timer := 0.0
var _step_offset := 0.0
var _stand_check_shape: BoxShape3D
var _input_seq := 0

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
	# 多实例（联机）时各自实例化 hull shape，避免共享资源互相改尺寸
	_hull_shape = _hull_shape.duplicate()
	_shape_node.shape = _hull_shape


func _physics_process(delta: float) -> void:
	if not is_local:
		return  # 服务器镜像由 NetworkManager 喂输入；远端傀儡走快照插值
	var inp := gather_local_input()
	simulate(inp, delta)
	input_simulated.emit(inp)


## 从 Input 单例采集本 tick 输入（仅本地玩家）
func gather_local_input() -> PlayerInput:
	_input_seq += 1
	var inp := PlayerInput.new()
	inp.seq = _input_seq
	inp.yaw = rotation.y
	inp.wish = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	inp.jump = Input.is_action_pressed("jump")
	inp.duck = Input.is_action_pressed("duck")
	return inp


## 确定性物理步进：本地预测 / 服务器权威 / 回滚重放共用。
## 除 input 与当前物理空间外不读任何外部状态。
func simulate(inp: PlayerInput, delta: float) -> void:
	rotation.y = inp.yaw

	_categorize_position()
	_update_duck(inp.duck, delta)

	var wishdir := _wishdir_from(inp)
	var wishspeed: float = params.max_speed  # sv_maxspeed
	if ducked:
		# PLAYER_DUCKING_MULTIPLIER：完全蹲下时限速（HL SDK PM_CheckParamters）
		wishspeed *= params.duck_speed_multiplier

	# 跳跃在摩擦之前处理：落地帧按住跳 → 跳过摩擦帧 = 连跳保速（spec §5）
	if grounded and inp.jump:
		bhop_preserved = not _was_grounded
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


## 由 input 的 yaw + wish 计算水平 wishdir（不读节点朝向以外的任何输入态）
func _wishdir_from(inp: PlayerInput) -> Vector3:
	if inp.wish == Vector2.ZERO:
		return Vector3.ZERO
	var b := global_transform.basis
	var dir := b.x * inp.wish.x + b.z * inp.wish.y
	dir.y = 0.0
	return dir.normalized()


## —— 回滚/同步用状态快照 ——

func capture_state() -> Dictionary:
	return {
		"pos": global_position,
		"vel": velocity,
		"yaw": rotation.y,
		"ducked": ducked,
		"duck_timer": _duck_timer,
		"grounded": grounded,
		"was_grounded": _was_grounded,
	}


func apply_state(s: Dictionary) -> void:
	global_position = s.pos
	velocity = s.vel
	rotation.y = s.yaw
	_duck_timer = s.duck_timer
	grounded = s.grounded
	_was_grounded = s.was_grounded
	if s.ducked != ducked:
		if s.ducked:
			_set_ducked_hull()
		else:
			_set_standing_hull()


## GoldSrc PM_CatagorizePosition 的简化：向下 trace 2 单位找可站立面。
func _categorize_position() -> void:
	if velocity.y > LEAVE_GROUND_VY:
		grounded = false
		return
	var coll := move_and_collide(Vector3(0, -GROUND_TRACE_DIST, 0), true)
	grounded = coll != null and coll.get_normal().y >= GROUND_NORMAL_MIN_Y


## —— 蹲（HL SDK PM_Duck / PM_UnDuck）——

func _update_duck(held: bool, delta: float) -> void:
	if held:
		if ducked:
			return
		if grounded:
			_duck_timer += delta
			if _duck_timer >= params.time_to_duck:
				_set_ducked_hull()
		else:
			# 空中蹲瞬时完成：hull 收 36 + 脚抬 18（duck-jump）
			_set_ducked_hull()
			global_position.y += DUCK_FEET_LIFT
	else:
		_duck_timer = 0.0
		if ducked:
			_try_unduck()


func _try_unduck() -> void:
	if grounded:
		if _can_stand(global_position):
			_set_standing_hull()
	else:
		var target := global_position + Vector3(0, -DUCK_FEET_LIFT, 0)
		if _can_stand(target):
			_set_standing_hull()
			global_position = target
		elif _can_stand(global_position):
			_set_standing_hull()
	# 两处都不行 → 保持蹲（低顶卡蹲）


func _set_ducked_hull() -> void:
	ducked = true
	_duck_timer = 0.0
	_hull_shape.size.y = params.duck_hull_height
	_shape_node.position.y = params.duck_hull_height * 0.5


func _set_standing_hull() -> void:
	ducked = false
	_hull_shape.size.y = params.stand_hull_height
	_shape_node.position.y = params.stand_hull_height * 0.5


func _can_stand(feet: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _stand_check_shape
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0, params.stand_hull_height * 0.5, 0))
	q.exclude = [get_rid()]
	q.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## —— 移动 ——

## PM_FlyMove：移动 + 撞面后 clip_velocity 投影，最多迭代 4 个面。
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


## PM_WalkMove：地面移动 + 台阶攀爬（两种走法取优）。
func _walk_move(delta: float) -> void:
	var start_pos := global_position
	var start_vel := velocity

	_fly_move(delta)
	var normal_pos := global_position
	var normal_vel := velocity

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
		velocity.y = normal_vel.y

	# 贴地：下坡/下台阶时在 step 高度内吸附
	if velocity.y <= 0.0:
		var snap := move_and_collide(Vector3(0, -STEP_HEIGHT, 0), true)
		if snap and snap.get_normal().y >= GROUND_NORMAL_MIN_Y:
			move_and_collide(Vector3(0, -STEP_HEIGHT, 0))

	# 台阶视角平滑（HL V_CalcRefdef stair smoothing）
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
		eye = lerpf(params.stand_eye_height, params.duck_eye_height,
				clampf(_duck_timer / params.time_to_duck, 0.0, 1.0))
	else:
		eye = params.stand_eye_height
	_head.position.y = eye + _step_offset


## —— 联机伤害（服务器端调用；单机不触发）——

## 命中点高于脚上 56 算头（盒型 hull 近似，待正式 hitbox 替换）
func is_hit_head(hit_y: float) -> bool:
	return hit_y > global_position.y + 56.0


func take_hit(damage: float, _is_head: bool) -> void:
	if health <= 0.0:
		return
	health -= damage
	health_changed.emit(health)
	if health <= 0.0:
		died.emit()
		respawn()
		health = 100.0
		health_changed.emit(health)


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
