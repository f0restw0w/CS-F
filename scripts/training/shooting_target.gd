extends StaticBody3D
class_name ShootingTarget
## 占位射击靶：身体/头部两个碰撞区（爆头判定），有血量、命中闪红、死亡重生。
## Phase 2 单机训练用；Phase 4 联机的玩家伤害走同一 take_hit 接口。

signal damaged(amount: float, is_head: bool, health_left: float)
signal died

@export var max_health := 100.0
@export var respawn_time := 1.5

var health := 100.0
## 累计承受伤害（测试用）
var total_damage_taken := 0.0
## 被击杀次数（测试用）
var times_killed := 0

@onready var _meshes: Array[MeshInstance3D] = [$BodyMesh, $HeadMesh]
@onready var _shapes: Array[CollisionShape3D] = [$BodyShape, $HeadShape]

var _flash_until := 0.0


func _ready() -> void:
	add_to_group("targets")
	health = max_health


## 武器用 ray 结果的 shape 索引判断是否打中头部区
func is_head_shape(shape_idx: int) -> bool:
	var owner_id := shape_find_owner(shape_idx)
	var node := shape_owner_get_owner(owner_id)
	return node != null and String(node.name).begins_with("Head")


func take_hit(damage: float, is_head: bool) -> void:
	if health <= 0.0:
		return
	health -= damage
	total_damage_taken += damage
	damaged.emit(damage, is_head, health)
	_flash()
	if health <= 0.0:
		_die()


func _flash() -> void:
	for m in _meshes:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.15, 0.15)
		m.material_override = mat
	_flash_until = Time.get_ticks_msec() / 1000.0 + 0.08


func _process(_delta: float) -> void:
	if _flash_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _flash_until:
		_flash_until = 0.0
		for m in _meshes:
			m.material_override = null


func _die() -> void:
	times_killed += 1
	died.emit()
	visible = false
	for s in _shapes:
		s.set_deferred("disabled", true)
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)


func _respawn() -> void:
	health = max_health
	visible = true
	for s in _shapes:
		s.set_deferred("disabled", false)
