extends Resource
class_name WeaponParams
## 武器可调参数。数值来源 CS 1.6（HL SDK / CS 武器脚本），近似值标注"待校准"。
## 弹道模式（spray pattern）是手感的一部分 —— 负责人按 1.6 记忆校准。

@export var weapon_name := "AK-47"

## CS 1.6 AK 基础伤害 36（枪口处，随距离衰减）
@export var damage: float = 36.0

## 射击间隔（秒）。1.6 AK 周期 ≈0.0955s；100 tick 固定步长下对齐为 0.1（整 10 tick）。
## 待校准：负责人若觉得射速慢 4.5%，可改 0.09（9 tick）。
@export var fire_interval: float = 0.1

@export var magazine_size: int = 30
@export var reserve_ammo: int = 90

## 1.6 AK 换弹 ≈2.45s
@export var reload_time: float = 2.45

## CS 1.6 距离衰减：伤害 ×= range_modifier^(距离/512)。AK = 0.98
@export var range_modifier: float = 0.98
@export var max_range: float = 8192.0

## CS 1.6 爆头倍率 4.0（无护甲）
@export var headshot_multiplier: float = 4.0

@export var auto_fire := true

@export_group("扩散（度，近似待校准）")

## 站立静止首发扩散（半角，度）
@export var spread_stand: float = 0.08
## 蹲下扩散倍率
@export var spread_duck_multiplier: float = 0.6
## 移动（速度 > 阈值）扩散
@export var spread_move: float = 1.6
## 空中扩散
@export var spread_air: float = 3.0
## 移动扩散惩罚的速度阈值（1.6 约为 maxspeed 的零头，取 140 待校准）
@export var move_spread_speed_threshold: float = 140.0

@export_group("后坐力 / 弹道模式")

## 每发视角上抬（度）。视觉 punch，会回落；弹道偏移由 spray_pattern 决定
@export var view_punch_per_shot: float = 0.9
## punch 指数回落系数（越大回落越快）
@export var view_punch_recovery: float = 8.0
## 停火多久后弹道索引复位（1.6 连发记忆窗口，近似）
@export var pattern_recovery_time: float = 0.55
## 30 发累计弹道偏移（度）：x=水平（+右），y=垂直（+上）。
## 形状按 1.6 AK：前 4 发小、7-8 发内爬升到 ~8°、后段左右大幅摆动。近似，待校准。
@export var spray_pattern: Array[Vector2] = []


## 第 i 发的累计弹道偏移（超出表长用最后一项）
func pattern_offset(shot_index: int) -> Vector2:
	if spray_pattern.is_empty():
		return Vector2.ZERO
	return spray_pattern[mini(shot_index, spray_pattern.size() - 1)]
