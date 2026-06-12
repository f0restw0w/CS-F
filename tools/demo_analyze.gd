extends SceneTree
## demo 轨迹分析：俯视图渲染 + 高度聚类 + 包围盒统计。
## 用法：godot --headless --script res://tools/demo_analyze.gd -- [csv路径]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "F:/Project/github/CS-F/.godot/demo_trace.csv"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("无法打开 " + path)
		quit(1)
		return

	var pts: Array = []  # [x, y, z]（GoldSrc：z 竖直）
	f.get_line()  # header
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var c := line.split(",")
		if c.size() < 8 or c[2] != "cd":
			continue
		pts.append(Vector3(c[3].to_float(), c[4].to_float(), c[5].to_float()))

	if pts.is_empty():
		printerr("无 cd 样本")
		quit(1)
		return

	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	print("样本=%d" % pts.size())
	print("X 范围: %.0f .. %.0f （宽 %.0f）" % [mn.x, mx.x, mx.x - mn.x])
	print("Y 范围: %.0f .. %.0f （深 %.0f）" % [mn.y, mx.y, mx.y - mn.y])
	print("Z 范围: %.0f .. %.0f （高差 %.0f；origin 在身体中心，站立脚=Z-36）" % [mn.z, mx.z, mx.z - mn.z])

	# 高度直方图（8 单位桶，找楼层）
	var hist := {}
	for p in pts:
		var b := int(floor(p.z / 8.0)) * 8
		hist[b] = hist.get(b, 0) + 1
	var keys := hist.keys()
	keys.sort_custom(func(a, b): return hist[a] > hist[b])
	print("\n高度聚类 Top12（origin.z 桶, 样本数, 推算脚高=桶-36）:")
	for i in mini(12, keys.size()):
		var k: int = keys[i]
		print("  z≈%d  x%d  → 脚 ≈ %d" % [k, hist[k], k - 36])

	# 俯视图：x→右，y→上（北）。2048px
	var size := 2048
	var span: float = maxf(mx.x - mn.x, mx.y - mn.y) * 1.05
	var ox: float = (mn.x + mx.x) * 0.5 - span * 0.5
	var oy: float = (mn.y + mx.y) * 0.5 - span * 0.5
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.08, 0.1))
	# 网格 256
	var grid := Color(0.18, 0.18, 0.22)
	var gx := ceili(ox / 256.0) * 256
	while gx < ox + span:
		var px := int((gx - ox) / span * size)
		for yy in size:
			img.set_pixel(clampi(px, 0, size - 1), yy, grid)
		gx += 256
	var gy := ceili(oy / 256.0) * 256
	while gy < oy + span:
		var py := size - 1 - int((gy - oy) / span * size)
		for xx in size:
			img.set_pixel(xx, clampi(py, 0, size - 1), grid)
		gy += 256
	# 按高度着色（脚高 -64..256 映射 蓝→绿→黄→红）
	for p in pts:
		var px := int((p.x - ox) / span * size)
		var py := size - 1 - int((p.y - oy) / span * size)
		if px < 1 or px >= size - 1 or py < 1 or py >= size - 1:
			continue
		var t := clampf((p.z - 36.0 + 64.0) / 320.0, 0.0, 1.0)
		var col := Color.from_hsv(0.66 - 0.66 * t, 0.9, 1.0)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				img.set_pixel(px + dx, py + dy, col)
	img.save_png("F:/Project/github/CS-F/.godot/demo_topdown.png")
	print("\n俯视图 → .godot/demo_topdown.png（横轴=X 东，纵轴=Y 北，网格 256，颜色=高度 蓝低红高）")
	quit(0)
