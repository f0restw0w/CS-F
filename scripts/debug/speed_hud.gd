extends CanvasLayer
## 调试速度 HUD（Phase 0 必备，见 docs/ARCHITECTURE.md）。
## 给负责人提供客观参照：直线跑 ≈ 320，完美 air strafe 连跳后应明显超 320
## （docs/TESTING.md「客观参照」）。

var _label: Label
var _player: PlayerController
var _peak_speed := 0.0


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if _player == null:
			return

	var hspeed := _player.horizontal_speed()
	_peak_speed = maxf(_peak_speed, hspeed)
	# 站定时归零峰值，方便每轮身法单独计数
	if _player.grounded and hspeed < 1.0:
		_peak_speed = 0.0

	_label.text = "速度  %6.1f\n垂直  %+6.1f\n峰值  %6.1f\n%s%s%s\ntick %d" % [
		hspeed,
		_player.vertical_speed(),
		_peak_speed,
		"地面" if _player.grounded else "空中",
		"  [蹲]" if _player.ducked else "",
		"  [连跳保速]" if _player.bhop_preserved else "",
		Engine.physics_ticks_per_second,
	]
