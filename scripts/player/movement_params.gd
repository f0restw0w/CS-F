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


## 起跳垂直初速：v = sqrt(2 * g * h)（GoldSrc 跳跃高度 ~45 → ~268 单位/秒）
func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_height)
