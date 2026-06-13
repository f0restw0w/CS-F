extends SceneTree
## 高度网格：把 demo 轨迹按网格取「该格观测到的最高脚高」。
## 玩家跳上箱子/楼梯/平台 → 该格记录箱顶高度 → 还原可站立面 footprint。
## 用法：godot --headless --script res://tools/demo_heightmap.gd -- x0 y0 x1 y1 [cell] [png]
## 坐标为 GoldSrc 原生（x 东, y 北, z 上；脚高 = origin.z - 36）。

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var x0 := a[0].to_float()
	var y0 := a[1].to_float()
	var x1 := a[2].to_float()
	var y1 := a[3].to_float()
	var cell: float = a[4].to_float() if a.size() > 4 else 32.0
	var out: String = a[5] if a.size() > 5 else "F:/Project/github/CS-F/.godot/demo_height.png"

	var f := FileAccess.open("F:/Project/github/CS-F/.godot/demo_trace.csv", FileAccess.READ)
	f.get_line()
	var nx := int(ceil((x1 - x0) / cell))
	var ny := int(ceil((y1 - y0) / cell))
	var hmax := {}  # "cx,cy" -> max foot
	var hmin := {}  # min foot (找地面/坑底)
	var hcnt := {}
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var c := line.split(",")
		if c.size() < 8 or c[2] != "cd":
			continue
		var px := c[3].to_float()
		var py := c[4].to_float()
		if px < x0 or px >= x1 or py < y0 or py >= y1:
			continue
		var foot := c[5].to_float() - 36.0
		var cx := int((px - x0) / cell)
		var cy := int((py - y0) / cell)
		var k := "%d,%d" % [cx, cy]
		if not hmax.has(k) or foot > hmax[k]:
			hmax[k] = foot
		if not hmin.has(k) or foot < hmin[k]:
			hmin[k] = foot
		hcnt[k] = hcnt.get(k, 0) + 1

	# 文本网格（北在上）：每格输出 max 脚高 / 16，便于读箱层
	print("网格 %dx%d cell=%.0f  原点(x0=%.0f,y0=%.0f)  [格值=该格最高脚高]" % [nx, ny, cell, x0, y0])
	print("行=北→南(y1→y0)，列=西→东(x0→x1)。'.'=无数据")
	for cy in range(ny - 1, -1, -1):
		var row := "y%5.0f " % (y0 + cy * cell)
		for cx in nx:
			var k := "%d,%d" % [cx, cy]
			if hmax.has(k):
				row += "%4d" % int(round(hmax[k]))
			else:
				row += "   ."
		print(row)

	# 图：颜色=max 脚高
	var size := 1400
	var span := maxf(x1 - x0, y1 - y0)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.06, 0.06, 0.08))
	for k in hmax:
		var parts: PackedStringArray = k.split(",")
		var cx := int(parts[0])
		var cy := int(parts[1])
		var wx := x0 + (cx + 0.5) * cell
		var wy := y0 + (cy + 0.5) * cell
		var px := int((wx - x0) / span * size)
		var py := size - 1 - int((wy - y0) / span * size)
		var t := clampf((hmax[k] + 64.0) / 320.0, 0.0, 1.0)
		var col := Color.from_hsv(0.66 - 0.66 * t, 0.85, 1.0)
		var r := int(cell / span * size / 2) + 1
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var qx := px + dx
				var qy := py + dy
				if qx >= 0 and qx < size and qy >= 0 and qy < size:
					img.set_pixel(qx, qy, col)
	img.save_png(out)
	print("\n高度图 → %s" % out)
	quit(0)
