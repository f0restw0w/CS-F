extends SceneTree
## 区域精析：裁取轨迹子区，输出 X/Y 墙线峰值（贴墙距离 16）与高度聚类 + 放大图。
## 用法：godot --headless --script res://tools/demo_region.gd -- x0 y0 x1 y1 [输出png]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var x0 := a[0].to_float()
	var y0 := a[1].to_float()
	var x1 := a[2].to_float()
	var y1 := a[3].to_float()
	var out: String = a[4] if a.size() > 4 else "F:/Project/github/CS-F/.godot/demo_region.png"

	var f := FileAccess.open("F:/Project/github/CS-F/.godot/demo_trace.csv", FileAccess.READ)
	f.get_line()
	var pts: Array = []
	var prev := Vector3.INF
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var c := line.split(",")
		if c.size() < 8 or c[2] != "cd":
			continue
		var p := Vector3(c[3].to_float(), c[4].to_float(), c[5].to_float())
		if p.x < x0 or p.x > x1 or p.y < y0 or p.y > y1:
			prev = Vector3.INF
			continue
		pts.append([p, prev])
		prev = p

	print("区域样本=%d" % pts.size())

	# 墙线峰值：沿 y 匀速移动（|dx|<0.5 且 |dy|>1）时记录 x；反之记录 y。4 单位桶。
	var xh := {}
	var yh := {}
	for e in pts:
		var p: Vector3 = e[0]
		var q = e[1]
		if q == Vector3.INF:
			continue
		var dx: float = absf(p.x - q.x)
		var dy: float = absf(p.y - q.y)
		if dx < 0.5 and dy > 1.0:
			var b := int(round(p.x / 4.0)) * 4
			xh[b] = xh.get(b, 0) + 1
		elif dy < 0.5 and dx > 1.0:
			var b2 := int(round(p.y / 4.0)) * 4
			yh[b2] = yh.get(b2, 0) + 1

	print("\n竖直墙候选（玩家X峰值；墙=值±16）:")
	_peaks(xh)
	print("\n水平墙候选（玩家Y峰值；墙=值±16）:")
	_peaks(yh)

	# 高度聚类
	var zh := {}
	for e in pts:
		var b3 := int(floor((e[0].z - 36.0) / 4.0)) * 4
		zh[b3] = zh.get(b3, 0) + 1
	var zk := zh.keys()
	zk.sort_custom(func(u, v): return zh[u] > zh[v])
	print("\n脚高聚类 Top10:")
	for i in mini(10, zk.size()):
		print("  脚≈%d  x%d" % [zk[i], zh[zk[i]]])

	# 放大图（网格 64）
	var size := 1600
	var spanx := x1 - x0
	var spany := y1 - y0
	var span := maxf(spanx, spany)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.07, 0.07, 0.09))
	var g := 64
	var gx := ceili(x0 / g) * g
	while gx < x0 + span:
		var px := int((gx - x0) / span * size)
		if px >= 0 and px < size:
			var c2 := Color(0.16, 0.16, 0.2) if gx % 256 != 0 else Color(0.3, 0.3, 0.36)
			for yy in size:
				img.set_pixel(px, yy, c2)
		gx += g
	var gy := ceili(y0 / g) * g
	while gy < y0 + span:
		var py := size - 1 - int((gy - y0) / span * size)
		if py >= 0 and py < size:
			var c3 := Color(0.16, 0.16, 0.2) if gy % 256 != 0 else Color(0.3, 0.3, 0.36)
			for xx in size:
				img.set_pixel(xx, py, c3)
		gy += g
	for e in pts:
		var p4: Vector3 = e[0]
		var px2 := int((p4.x - x0) / span * size)
		var py2 := size - 1 - int((p4.y - y0) / span * size)
		if px2 < 1 or px2 >= size - 1 or py2 < 1 or py2 >= size - 1:
			continue
		var t := clampf((p4.z - 36.0 + 64.0) / 320.0, 0.0, 1.0)
		var col := Color.from_hsv(0.66 - 0.66 * t, 0.9, 1.0)
		for dx2 in range(-1, 2):
			for dy2 in range(-1, 2):
				img.set_pixel(px2 + dx2, py2 + dy2, col)
	img.save_png(out)
	print("\n放大图 → %s（细网格64/粗网格256，原点对齐 0）" % out)
	quit(0)


func _peaks(h: Dictionary) -> void:
	var ks := h.keys()
	ks.sort()
	# 合并相邻桶为峰
	var peaks: Array = []
	var cur := []
	for k in ks:
		if h[k] < 25:
			continue
		if cur.is_empty() or k - cur[-1][0] <= 8:
			cur.append([k, h[k]])
		else:
			peaks.append(cur)
			cur = [[k, h[k]]]
	if not cur.is_empty():
		peaks.append(cur)
	for pk in peaks:
		var tot := 0
		var wsum := 0.0
		for kv in pk:
			tot += kv[1]
			wsum += kv[0] * kv[1]
		print("  ≈%.0f  (样本 %d)" % [wsum / tot, tot])
