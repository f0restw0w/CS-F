extends SceneTree
## 从 demo 找各区代表性可走点（取站立稳定、各区分散的点），用作出生点候选。
func _init() -> void:
	var f := FileAccess.open("res://.godot/demo_trace.csv", FileAccess.READ)
	f.get_line()
	var pts: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var c := line.split(",")
		if c.size() < 8 or c[2] != "cd":
			continue
		pts.append([c[3].to_float(), c[4].to_float(), c[5].to_float()])
	# 输出 X/Y 极值区的代表点（T家=Y最大区，CT=Y最小区附近）
	pts.sort_custom(func(a, b): return a[1] > b[1])  # 按 gs y 降序
	print("最北(T家方向)几点 [gs x,y,foot → Godot x,y,z]:")
	for i in 5:
		var p: Array = pts[i * 200]
		print("  gs(%.0f,%.0f) foot %.0f → Godot(%.0f, %.0f, %.0f)" %
				[p[0], p[1], p[2] - 36, p[0], p[2] - 36, -p[1]])
	print("最南(CT家方向)几点:")
	for i in 5:
		var p: Array = pts[pts.size() - 1 - i * 200]
		print("  gs(%.0f,%.0f) foot %.0f → Godot(%.0f, %.0f, %.0f)" %
				[p[0], p[1], p[2] - 36, p[0], p[2] - 36, -p[1]])
	quit(0)
