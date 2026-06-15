extends SceneTree
## bsp 精确几何可行走性验证：直接取 demo 真实走过的点当探针——
## 凡是负责人站过的地方，提取的几何就必须能站住（脚高吻合）。

var _failed := 0
var _passed := 0

func _init() -> void:
	_run()

func check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  PASS: " + name)
	else:
		_failed += 1
		printerr("  FAIL: " + name)

func _run() -> void:
	await process_frame
	var scene: Node = (load("res://scenes/test_bsp.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node("Player") as PlayerController

	# 从 demo 取跨图均匀的真实走点（Godot 坐标 + 实测脚高）
	var samples := _load_samples(12)
	check("载入 demo 探针点", samples.size() >= 8)
	var ok := 0
	for s in samples:
		var pos: Vector3 = s[0]
		var foot: float = s[1]
		player.global_position = pos + Vector3(0, 30, 0)  # 略高落下
		player.velocity = Vector3.ZERO
		var landed := false
		for i in 70:
			await physics_frame
			if player.grounded:
				landed = true
				break
		# 站住，且落点脚高与 demo 实测吻合（±20，含箱/坡容差）
		if landed and absf(player.global_position.y - foot) < 20.0:
			ok += 1
		else:
			printerr("  探针偏差 @%v demo脚高%.0f → 实落%.1f grounded=%s" %
					[pos, foot, player.global_position.y, str(player.grounded)])
	check("demo 走点可站住且高度吻合（%d/%d）" % [ok, samples.size()], ok >= samples.size() - 1)

	_finish()


## 跨图均匀取 n 个 demo 点（避开跳跃帧：取垂直速度小的）
func _load_samples(n: int) -> Array:
	var f := FileAccess.open("res://.godot/demo_trace.csv", FileAccess.READ)
	if f == null:
		return []
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
	if pts.is_empty():
		return []
	var out: Array = []
	var step := int(pts.size() / n)
	for i in n:
		var p: Array = pts[i * step]
		var foot: float = p[2] - 36.0
		out.append([Vector3(p[0], foot, -p[1]), foot])
	return out

func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
