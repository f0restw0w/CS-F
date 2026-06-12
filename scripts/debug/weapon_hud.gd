extends CanvasLayer
## 武器 HUD：1.6 风格动态准星（间隙随扩散态变化）+ 弹药计数 + 伤害日志。

var _weapon: HitscanWeapon
var _cross: Control
var _ammo: Label
var _log: Label
var _log_entries: Array = []  # [ [text, expire_time], ... ]


func _ready() -> void:
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_crosshair)
	add_child(_cross)

	_ammo = Label.new()
	_ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo.position = Vector2(-220, -64)
	_ammo.add_theme_font_size_override("font_size", 28)
	_ammo.add_theme_color_override("font_outline_color", Color.BLACK)
	_ammo.add_theme_constant_override("outline_size", 6)
	add_child(_ammo)

	_log = Label.new()
	_log.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_log.position = Vector2(-260, 16)
	_log.add_theme_font_size_override("font_size", 18)
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	_log.add_theme_constant_override("outline_size", 5)
	add_child(_log)


func _process(_delta: float) -> void:
	if not is_instance_valid(_weapon):
		# 联机时只取本地玩家的武器
		for w in get_tree().get_nodes_in_group("weapon"):
			if w is HitscanWeapon and is_instance_valid(w._player) and w._player.is_local:
				_weapon = w
				break
		if _weapon == null:
			return
		_weapon.hit_target.connect(_on_hit)

	_ammo.text = "%s\n%d / %d%s" % [
		_weapon.params.weapon_name, _weapon.mag, _weapon.reserve,
		"   换弹中…" if _weapon.reloading else "",
	]

	var now := Time.get_ticks_msec() / 1000.0
	_log_entries = _log_entries.filter(func(e: Array) -> bool: return e[1] > now)
	var lines := PackedStringArray()
	for e in _log_entries:
		lines.append(e[0])
	_log.text = "\n".join(lines)

	_cross.queue_redraw()


func _on_hit(damage: float, is_head: bool, _target: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var txt := "-%.0f  %s" % [damage, "爆头!" if is_head else "命中"]
	_log_entries.push_front([txt, now + 2.0])
	if _log_entries.size() > 5:
		_log_entries.resize(5)


func _draw_crosshair() -> void:
	var center := _cross.size * 0.5
	var col := Color(0.2, 1.0, 0.2, 0.9)
	var gap := 5.0
	var length := 9.0
	if is_instance_valid(_weapon):
		# 间隙 ≈ 扩散锥半角在屏幕上的像素数（73.74° 垂直 FOV 下 ~9.8 px/°）+ punch
		var px_per_deg := _cross.size.y / 73.74
		gap = 4.0 + _weapon.current_spread_deg() * px_per_deg * 2.0 + _weapon.view_punch_deg() * 1.5
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_cross.draw_line(center + d * gap, center + d * (gap + length), col, 2.0)
