extends Node3D
## 鼠标视角控制（挂在 Player/Head 上，眼高 64 由场景节点位置决定）。
## 按 docs/ARCHITECTURE.md：_input 只收集鼠标增量，_physics_process 统一应用。
## 鼠标只改变朝向（决定 wishdir），绝不直接改速度（MOVEMENT_SPEC.md 实现注意事项）。

## GoldSrc m_yaw / m_pitch 默认值：每个鼠标 count 转 0.022°
const DEG_PER_COUNT := 0.022
## GoldSrc 俯仰限制 ±89°
const PITCH_LIMIT_DEG := 89.0

## 类比 1.6 的 sensitivity cvar（实际角度 = 像素 × 0.022° × sensitivity）
@export var sensitivity := 2.0

var _mouse_delta := Vector2.ZERO

@onready var _player: CharacterBody3D = get_parent()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative
	elif event.is_action_pressed("ui_cancel"):
		# Esc 释放/捕获鼠标切换
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	if _mouse_delta == Vector2.ZERO:
		return
	var step := DEG_PER_COUNT * sensitivity
	# yaw 转玩家身体（决定 wishdir 基），pitch 只转头
	_player.rotate_y(-deg_to_rad(_mouse_delta.x * step))
	rotation.x = clampf(
		rotation.x - deg_to_rad(_mouse_delta.y * step),
		-deg_to_rad(PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG)
	)
	_mouse_delta = Vector2.ZERO
