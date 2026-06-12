extends Node3D
class_name HitscanWeapon
## CS 1.6 风格 hitscan 武器（挂在 Player/Head/Camera3D/Weapon）。
## 射击循环在固定步长 _physics_process（与移动同 tick，射速 tick 对齐）。
##
## 弹道 = 累计 spray pattern（决定命中点，1.6 压枪的对象）
##      + 随机扩散锥（站/蹲/移动/空中分态）
## 视角 punch 只是视觉上抬并回落，不参与命中计算（1.6 同）。

signal fired(shot_index: int)
signal hit_target(damage: float, is_head: bool, target: Node)
signal ammo_changed(mag: int, reserve: int)
signal reload_state_changed(reloading: bool)

@export var params: WeaponParams
@export var player_path: NodePath = ^"../../.."
@export var camera_path: NodePath = ^".."

var mag := 0
var reserve := 0
var reloading := false
## 最近一发命中点（测试/调试用）
var last_hit_point := Vector3.ZERO

var _time := 0.0
var _next_fire := 0.0
var _reload_done := 0.0
var _shot_index := 0
var _last_shot := -100.0
var _punch := 0.0

@onready var _player: PlayerController = get_node(player_path)
@onready var _camera: Camera3D = get_node(camera_path)
## 瞄准基（Head）：punch 只叠在 Camera3D 上做视觉，弹道用 Head 的真实瞄准角。
## 1.6 行为：压枪压的是 spray pattern（v_angle），不是视觉 punch。
@onready var _aim: Node3D = _camera.get_parent()
@onready var _muzzle: Node3D = get_node_or_null("Muzzle")
var _audio: AudioStreamPlayer


func _ready() -> void:
	add_to_group("weapon")
	if params == null:
		params = load("res://resources/weapons/ak47.tres")
	mag = params.magazine_size
	reserve = params.reserve_ammo
	_audio = AudioStreamPlayer.new()
	_audio.stream = _make_shot_sound()
	_audio.volume_db = -8.0
	add_child(_audio)


func _physics_process(delta: float) -> void:
	_time += delta

	# 视角 punch 指数回落（纯视觉，叠在 Camera3D 上，不动 Head 的瞄准 pitch）
	_punch *= exp(-params.view_punch_recovery * delta)
	_camera.rotation.x = deg_to_rad(_punch)

	# 停火超过记忆窗口 → 弹道索引复位
	if _shot_index > 0 and _time - _last_shot >= params.pattern_recovery_time:
		_shot_index = 0

	if reloading:
		if _time >= _reload_done:
			_finish_reload()
		return

	if Input.is_action_just_pressed("reload") and mag < params.magazine_size and reserve > 0:
		_start_reload()
		return

	# 1.6：打空自动换弹
	if mag == 0 and reserve > 0:
		_start_reload()
		return

	var want_fire := Input.is_action_pressed("fire") if params.auto_fire \
			else Input.is_action_just_pressed("fire")
	if want_fire and mag > 0 and _time >= _next_fire:
		_fire()


## 当前随机扩散半角（度）——HUD 动态准星也读这个
func current_spread_deg() -> float:
	if _player == null:
		return params.spread_stand
	var s := params.spread_stand
	if not _player.grounded:
		s = params.spread_air
	elif _player.horizontal_speed() > params.move_spread_speed_threshold:
		s = params.spread_move
	if _player.ducked:
		s *= params.spread_duck_multiplier
	return s


func view_punch_deg() -> float:
	return _punch


func _fire() -> void:
	mag -= 1
	_next_fire = _time + params.fire_interval
	_last_shot = _time
	var pat := params.pattern_offset(_shot_index)
	_shot_index += 1

	# 随机扩散：圆盘均匀采样
	var spread := current_spread_deg()
	var ang := randf() * TAU
	var r := sqrt(randf()) * spread
	var pitch_off := deg_to_rad(pat.y + sin(ang) * r)   # + = 上
	var yaw_off := deg_to_rad(pat.x + cos(ang) * r)     # + = 右

	var b := _aim.global_transform.basis
	var dir := (-b.z).rotated(b.x, pitch_off).rotated(b.y, -yaw_off).normalized()

	var from := _aim.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * params.max_range)
	q.exclude = [_player.get_rid()]
	var res := get_world_3d().direct_space_state.intersect_ray(q)

	_punch = minf(_punch + params.view_punch_per_shot, 12.0)
	_audio.play()
	fired.emit(_shot_index)
	ammo_changed.emit(mag, reserve)

	var muzzle_pos := _muzzle.global_position if _muzzle else from
	if res.is_empty():
		last_hit_point = from + dir * params.max_range
		_spawn_tracer(muzzle_pos, last_hit_point)
		return

	last_hit_point = res.position
	_spawn_tracer(muzzle_pos, res.position)
	_spawn_impact(res.position, res.normal)

	# CS 1.6 距离衰减：damage × range_modifier^(dist/512)
	var dmg: float = params.damage * pow(params.range_modifier, from.distance_to(res.position) / 512.0)
	var col: Object = res.get("collider")
	if col != null and col.has_method("take_hit"):
		var is_head: bool = col.is_head_shape(res.shape) if col.has_method("is_head_shape") else false
		if is_head:
			dmg *= params.headshot_multiplier
		col.take_hit(dmg, is_head)
		hit_target.emit(dmg, is_head, col)


func _start_reload() -> void:
	reloading = true
	_reload_done = _time + params.reload_time
	reload_state_changed.emit(true)


func _finish_reload() -> void:
	reloading = false
	var need := params.magazine_size - mag
	var take := mini(need, reserve)
	mag += take
	reserve -= take
	ammo_changed.emit(mag, reserve)
	reload_state_changed.emit(false)


## —— 占位视觉/听觉反馈 ——

func _fx_parent() -> Node:
	return _player.get_parent() if _player and _player.get_parent() else self


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_fx_parent().add_child(mi)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.2
	sphere.height = 2.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	sphere.material = mat
	mi.mesh = sphere
	_fx_parent().add_child(mi)
	mi.global_position = pos + normal * 0.5
	get_tree().create_timer(4.0).timeout.connect(mi.queue_free)


## 程序生成占位枪声（白噪声爆发 + 指数衰减），不引入任何外部音频资产
func _make_shot_sound() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.09
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 55.0)
		var s := (rng.randf() * 2.0 - 1.0) * 0.85 * env
		s += sin(t * TAU * 140.0) * 0.35 * exp(-t * 30.0)  # 低频"砰"
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
