extends Node3D
## 把 demo 轨迹点云画成发光小球叠在场景里（对照底图）：
## 看重刻的灰盒几何是否贴合负责人实际走过的轨迹。
## 坐标映射 GoldSrc→Godot：x=x, y(up)=z-36(脚高)+2, z=-y。只取 A 区范围。

@export var csv_path := "res://.godot/demo_trace.csv"
@export var x0 := -2600.0
@export var x1 := 1950.0
@export var y0 := -1100.0
@export var y1 := 3100.0
@export var stride := 4  # 每 N 个样本画一个，控制密度


func _ready() -> void:
	var f := FileAccess.open(csv_path, FileAccess.READ)
	if f == null:
		push_warning("demo_overlay: 找不到 " + csv_path)
		return
	f.get_line()
	var mm := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mm.surface_begin(Mesh.PRIMITIVE_POINTS, mat)
	var i := 0
	var n := 0
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var c := line.split(",")
		if c.size() < 8 or c[2] != "cd":
			continue
		i += 1
		if i % stride != 0:
			continue
		var gx := c[3].to_float()
		var gy := c[4].to_float()
		var gz := c[5].to_float()
		if gx < x0 or gx > x1 or gy < y0 or gy > y1:
			continue
		var foot := gz - 36.0
		var t: float = clampf((foot + 64.0) / 320.0, 0.0, 1.0)
		mm.surface_set_color(Color.from_hsv(0.66 - 0.66 * t, 0.9, 1.0))
		mm.surface_add_vertex(Vector3(gx, foot + 3.0, -gy))
		n += 1
	mm.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mm
	add_child(mi)
	print("demo_overlay: 画了 %d 个轨迹点（A 区）" % n)
