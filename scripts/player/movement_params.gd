extends Resource
class_name MovementParams
## 所有 GoldSrc 移动相关 cvar 的集中可调参数。
## 每个值的出处见 docs/MOVEMENT_SPEC.md「核心常量」表。
## 负责人可在 Inspector 里实时拖动数值找手感（运行时热改生效）。

## sv_maxspeed = 320.0 — 玩家移动速度上限（单位/秒）
@export var max_speed: float = 320.0

## sv_accelerate = 5.0 — 地面加速系数
@export var accelerate: float = 5.0

## sv_airaccelerate = 10.0 — 空气加速系数（air strafe / bhop 的根基）
@export var air_accelerate: float = 10.0

## sv_friction = 4.0 — 地面摩擦系数
@export var friction: float = 4.0

## sv_stopspeed = 75.0 — 低于此速度时摩擦增强（急停干脆的来源）
@export var stop_speed: float = 75.0

## sv_gravity = 800.0 — 重力（单位/秒²）
@export var gravity: float = 800.0

## 跳跃高度约 45 单位 → 起跳初速 sqrt(2 * gravity * 45) ≈ 268
@export var jump_height: float = 45.0

## GoldSrc 空气加速里 wishspeed 的裁剪上限（≈30）。
## 这个裁剪是 air strafe 的灵魂——见 MOVEMENT_SPEC.md AirAccelerate 节。
@export var air_wish_speed_cap: float = 30.0

## 是否启用连跳速度上限（GoldSrc 后期版本行为）。
## 原型阶段默认关闭（经典无限连跳），由负责人试玩后决定——见 MOVEMENT_SPEC.md。
@export var bhop_speed_cap_enabled: bool = false

@export_group("蹲（duck）")

## PLAYER_DUCKING_MULTIPLIER = 0.333（HL SDK pm_shared.c）：
## 完全蹲下时 wishspeed 倍率（地面与空中都生效，320 → ~106.6）
@export var duck_speed_multiplier: float = 0.333

## TIME_TO_DUCK = 0.4s（HL SDK pm_shared.c）：地面蹲下过渡时长。
## 空中蹲为瞬时完成（GoldSrc 行为，duck-jump 的前提）。
@export var time_to_duck: float = 0.4

## VEC_HULL（HL SDK）：站立碰撞体高 72
@export var stand_hull_height: float = 72.0

## VEC_DUCK_HULL（HL SDK）：蹲下碰撞体高 36
@export var duck_hull_height: float = 36.0

## 站立眼高 64（GoldSrc origin+VEC_VIEW 28，origin 在脚上 36）
@export var stand_eye_height: float = 64.0

## 蹲下眼高 30（GoldSrc VEC_DUCK_VIEW 12 + 蹲 hull 半高 18）
@export var duck_eye_height: float = 30.0

@export_group("视角平滑")

## 台阶视角平滑速度（HL V_CalcRefdef 平滑爬升 150 u/s），偏移上限 = step 高 18
@export var step_smooth_speed: float = 150.0


## 起跳垂直初速：v = sqrt(2 * g * h)（GoldSrc 跳跃高度 ~45 → ~268 单位/秒）
func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_height)
