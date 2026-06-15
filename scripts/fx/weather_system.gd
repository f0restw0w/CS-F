extends Node3D
class_name WeatherSystem
## 暴雨天气：跟随玩家的 GPU 雨粒子 + 闪电（瞬时强光 + 全屏白闪 + 多次闪烁）
## + 程序合成雷声（按距离延迟）+ 雨声循环 + 暴风压暗环境。
## 全部资产程序生成，零外部文件。所有参数 @export 可调，enabled 可一键关。

@export var enabled := true
## 雨粒子数量
@export var rain_amount := 3000
## 雨落速度（单位/秒）
@export var rain_speed := 1500.0
## 雨覆盖半径（在玩家上方的箱形发射区半宽）
@export var rain_radius := 900.0
## 闪电间隔随机区间（秒）
@export var strike_interval := Vector2(5.0, 16.0)
## 暴风压暗环境（找 WorldEnvironment 调低曝光/环境光）
@export var storm_darken := true

var _rain: GPUParticles3D
var _flash_light: DirectionalLight3D
var _flash_rect: ColorRect
var _thunder: AudioStreamPlayer
var _rain_loop: AudioStreamPlayer
var _player: Node3D
var _env: Environment
var _orig_exposure := 1.0
var _orig_ambient := 1.0


func _ready() -> void:
	if not enabled:
		return
	_build_rain()
	_build_flash()
	_build_audio()
	if storm_darken:
		_apply_storm_mood()
	_storm_loop()


func _process(_delta: float) -> void:
	# 雨发射器跟随玩家正上方（粒子世界坐标，移动不拖影）
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(_player) and is_instance_valid(_rain):
		_rain.global_position = _player.global_position + Vector3(0, 700, 0)


## —— 雨 ——

func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = rain_amount
	_rain.lifetime = 1.0
	_rain.local_coords = false  # 世界坐标：发射器移动时已落下的雨不跟着平移
	_rain.fixed_fps = 0
	_rain.visibility_aabb = AABB(Vector3(-rain_radius, -800, -rain_radius), Vector3(rain_radius * 2, 1000, rain_radius * 2))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(rain_radius, 20, rain_radius)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 0.0
	pm.initial_velocity_min = rain_speed
	pm.initial_velocity_max = rain_speed * 1.15
	pm.gravity = Vector3(0, -400, 0)
	# 轻微斜风
	pm.linear_accel_min = 0.0
	pm.linear_accel_max = 0.0
	_rain.process_material = pm

	# 雨丝：细长竖条，Y 轴朝向相机
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 16.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.62, 0.7, 0.85, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	quad.material = mat
	_rain.draw_pass_1 = quad
	add_child(_rain)
	_rain.emitting = true


## —— 闪电（光 + 全屏闪） ——

func _build_flash() -> void:
	# 3D 补光：平时关，闪电时瞬间拉满，照亮整张图
	_flash_light = DirectionalLight3D.new()
	_flash_light.rotation = Vector3(deg_to_rad(-70), deg_to_rad(40), 0)
	_flash_light.light_color = Color(0.85, 0.9, 1.0)
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	add_child(_flash_light)

	# 全屏白闪
	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(0.9, 0.93, 1.0, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_flash_rect)


func _flash(strength: float) -> void:
	_flash_light.light_energy = 3.5 * strength
	_flash_rect.color.a = 0.55 * strength
	var tw := create_tween()
	tw.tween_property(_flash_light, "light_energy", 0.0, 0.18)
	var tw2 := create_tween()
	tw2.tween_property(_flash_rect, "color:a", 0.0, 0.22)


## —— 风暴主循环 ——

func _storm_loop() -> void:
	# 起始先等几秒，避免一进场就炸
	await get_tree().create_timer(3.0).timeout
	while is_inside_tree() and enabled:
		var wait := randf_range(strike_interval.x, strike_interval.y)
		await get_tree().create_timer(wait).timeout
		if not (is_inside_tree() and enabled):
			return
		await _do_strike()


## 一次闪电：1~3 次明暗闪烁 + 延迟雷声（声速 < 光速，按"距离"延迟）
func _do_strike() -> void:
	var flickers := randi_range(1, 3)
	for i in flickers:
		_flash(randf_range(0.6, 1.0))
		await get_tree().create_timer(randf_range(0.05, 0.13)).timeout
	# 雷声延迟：近雷 0.3s，远雷 2.5s
	var dist := randf_range(0.3, 2.5)
	await get_tree().create_timer(dist).timeout
	if is_instance_valid(_thunder):
		_thunder.volume_db = lerpf(-2.0, -16.0, dist / 2.5)  # 远雷更轻
		_thunder.pitch_scale = randf_range(0.85, 1.15)
		_thunder.play()


## —— 暴风氛围（压暗 + 冷色）——

func _apply_storm_mood() -> void:
	var we := _find_world_env()
	if we == null:
		return
	_env = we.environment
	_orig_exposure = _env.tonemap_exposure
	_orig_ambient = _env.ambient_light_energy
	_env.tonemap_exposure = _orig_exposure * 0.45
	_env.ambient_light_energy = _orig_ambient * 0.5


func _find_world_env() -> WorldEnvironment:
	for n in get_tree().get_nodes_in_group("__none__"):
		pass
	var root := get_tree().current_scene
	if root == null:
		return null
	for c in root.get_children():
		if c is WorldEnvironment:
			return c
	return null


func _exit_tree() -> void:
	# 还原环境（防止切场景后影响别处）
	if _env != null:
		_env.tonemap_exposure = _orig_exposure
		_env.ambient_light_energy = _orig_ambient


## —— 程序合成音频（零外部资产）——

func _build_audio() -> void:
	_thunder = AudioStreamPlayer.new()
	_thunder.stream = _make_thunder()
	add_child(_thunder)
	_rain_loop = AudioStreamPlayer.new()
	_rain_loop.stream = _make_rain_loop()
	_rain_loop.volume_db = -14.0
	add_child(_rain_loop)
	_rain_loop.play()


## 雷声：低频隆隆（布朗噪声）+ 中段炸裂 + 长尾衰减
func _make_thunder() -> AudioStreamWAV:
	var rate := 22050
	var dur := 2.6
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var brown := 0.0
	for i in n:
		var t := float(i) / rate
		var white := rng.randf() * 2.0 - 1.0
		brown += white * 0.06
		brown = clampf(brown, -1.0, 1.0)
		brown *= 0.995  # 缓慢回中
		# 包络：开头一记炸裂 + 整体长衰减 + 中段二次轰鸣
		var crack := exp(-t * 9.0)
		var roll := exp(-t * 1.4) * (0.6 + 0.4 * sin(t * 5.0))
		var env := crack * 0.6 + roll * 0.7
		var s := brown * env
		s = clampf(s, -1.0, 1.0)
		s = s - (s * s * s) / 3.0  # 柔和饱和
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


## 雨声：高频白噪声沙沙（带通），可无缝循环
func _make_rain_loop() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.5
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var white := rng.randf() * 2.0 - 1.0
		# 高通（去低频），留沙沙感
		hp = white - prev
		prev = white
		var s := hp * 0.4
		# 头尾交叉淡入淡出做无缝循环
		var t := float(i) / n
		var fade := 1.0
		if t < 0.05:
			fade = t / 0.05
		elif t > 0.95:
			fade = (1.0 - t) / 0.05
		s *= (0.7 + 0.3 * fade)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 20000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n - 1
	wav.data = data
	return wav
