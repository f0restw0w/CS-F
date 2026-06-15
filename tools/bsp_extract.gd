extends SceneTree
## GoldSrc BSP v30 几何提取器（净室重建）。
##
## 授权范围（负责人 2026-06-13 明确批准）：**只读世界 brush 的几何坐标**
## （顶点/边/面/平面），用于提取不受版权保护的空间布局。
## **绝不**提取或输出：贴图像素、模型、音效、实体布置、光照。
## texinfo/textures 仅用于读纹理「名字」做过滤（剔除 sky/trigger/clip），不碰像素。
## 源 .bsp 不进仓库（.gitignore 拦截）；产物是我们自己生成的灰盒坐标。
##
## 坐标映射 GoldSrc→Godot：x=gs.x, y(up)=gs.z, z=-gs.y（1:1，无缩放）。
##
## 用法：godot --headless --script res://tools/bsp_extract.gd -- <bsp路径>

const LUMP_ENTITIES := 0
const LUMP_PLANES := 1
const LUMP_TEXTURES := 2
const LUMP_VERTEXES := 3
const LUMP_TEXINFO := 6
const LUMP_FACES := 7
const LUMP_EDGES := 12
const LUMP_SURFEDGES := 13
const LUMP_MODELS := 14

# brush 实体里「非实体/不该当固体墙」的 classname（跳过其模型）。
# 门类按「开着」处理（留空过道）——更贴合可玩空间。
const NONSOLID_CLASS := [
	"trigger", "illusionary", "ladder", "buyzone", "door", "hostage_entity",
	"weaponbox", "func_tank", "ladder", "rendering", "bomb_target",
]

var _f: FileAccess
var _lumps := []  # [offset, length] x15

# 过滤掉的纹理名（小写）：天空盒/触发器/裁剪/工具纹理 —— 这些不是实体墙
const SKIP_TEX := {
	"aaatrigger": true, "origin": true, "clip": true, "null": true,
	"hint": true, "skip": true, "trigger": true, "noclip": true,
	"sky": true, "translucent": true,
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "F:/SteamLibrary/steamapps/common/Half-Life/cstrike/maps/de_dust2.bsp"
	_f = FileAccess.open(path, FileAccess.READ)
	if _f == null:
		printerr("打不开 bsp: " + path)
		quit(1)
		return

	var version := _f.get_32()
	print("BSP version=%d  size=%d" % [version, _f.get_length()])
	if version != 30:
		printerr("不是 GoldSrc BSP v30")
		quit(1)
		return
	for i in 15:
		_lumps.append([_f.get_32(), _f.get_32()])

	var verts := _read_vertices()
	var edges := _read_edges()
	var surfedges := _read_surfedges()
	var planes := _read_planes()
	var tex_names := _read_texture_names()
	var texinfo_miptex := _read_texinfo_miptex()
	print("verts=%d edges=%d surfedges=%d planes=%d textures=%d texinfo=%d" %
			[verts.size(), edges.size(), surfedges.size(), planes.size(), tex_names.size(), texinfo_miptex.size()])

	# 读 brush 实体的 model→origin/classname（仅用于几何摆放与实/虚判断，
	# 不提取出生点/武器/设计布置）。世界 model0 永远固体、origin=0。
	var ents := _read_entities()
	var model_origin := {}   # 模型号 N → 世界偏移
	var model_skip := {}     # 模型号 N → 跳过（非固体）
	for ent in ents:
		var m: String = ent.get("model", "")
		if not m.begins_with("*"):
			continue
		var idx := int(m.substr(1))
		var org := Vector3.ZERO
		if ent.has("origin"):
			var p: PackedStringArray = (ent["origin"] as String).split(" ", false)
			if p.size() >= 3:
				org = Vector3(p[0].to_float(), p[1].to_float(), p[2].to_float())
		model_origin[idx] = org
		var cn: String = ent.get("classname", "")
		for bad in NONSOLID_CLASS:
			if cn.find(bad) != -1:
				model_skip[idx] = true
				break

	var models := _read_models()
	print("brush 模型=%d  其中实体偏移=%d  跳过(门/触发/装饰)=%d" %
			[models.size(), model_origin.size(), model_skip.size()])

	# 按法线方向分三类灰盒：地面 / 墙 / 斜面
	var tri_floor := PackedVector3Array()
	var tri_wall := PackedVector3Array()
	var tri_ramp := PackedVector3Array()
	var nrm_floor := PackedVector3Array()
	var nrm_wall := PackedVector3Array()
	var nrm_ramp := PackedVector3Array()
	var all_tris := PackedVector3Array()  # 碰撞（不分类）

	var fo: int = _lumps[LUMP_FACES][0]
	var skipped := 0
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := -mn
	# 逐模型处理，施加各自 origin 偏移（箱子/栏杆/平台归位）
	for mi in models.size():
		if model_skip.has(mi):
			continue
		var offset: Vector3 = model_origin.get(mi, Vector3.ZERO)
		var md: Array = models[mi]
		var first_face: int = md[0]
		var num_faces: int = md[1]
		for fi in range(first_face, first_face + num_faces):
			_f.seek(fo + fi * 20)
			var planenum := _f.get_16()
			var side := _f.get_16()
			var firstedge := _read_i32()
			var numedges := _f.get_16()
			var texinfo := _f.get_16()

			var miptex := texinfo_miptex[texinfo] if texinfo < texinfo_miptex.size() else -1
			var tname := ""
			if miptex >= 0 and miptex < tex_names.size():
				tname = tex_names[miptex]
			if SKIP_TEX.has(tname) or tname.begins_with("sky"):
				skipped += 1
				continue

			var poly := []
			for e in range(firstedge, firstedge + numedges):
				var se: int = surfedges[e]
				var vidx: int = edges[se][0] if se >= 0 else edges[-se][1]
				poly.append((verts[vidx] as Vector3) + offset)
			if poly.size() < 3:
				continue

			var pl: Array = planes[planenum]
			var gn: Vector3 = pl[0]
			if side != 0:
				gn = -gn
			var godot_n := Vector3(gn.x, gn.z, -gn.y).normalized()

			var target_t: PackedVector3Array
			var target_n: PackedVector3Array
			if godot_n.y > 0.7:
				target_t = tri_floor
				target_n = nrm_floor
			elif absf(godot_n.y) < 0.3:
				target_t = tri_wall
				target_n = nrm_wall
			else:
				target_t = tri_ramp
				target_n = nrm_ramp

			var g0 := _to_godot(poly[0])
			for i in range(1, poly.size() - 1):
				var g1 := _to_godot(poly[i])
				var g2 := _to_godot(poly[i + 1])
				for v in [g0, g2, g1]:  # 反绕匹配 y→-z 镜像
					target_t.append(v)
					target_n.append(godot_n)
					all_tris.append(v)
					mn = mn.min(v)
					mx = mx.max(v)

	print("跳过(sky/trigger/clip)面=%d" % skipped)
	print("三角：地面=%d 墙=%d 斜面=%d  合计 collision tris=%d" %
			[tri_floor.size() / 3, tri_wall.size() / 3, tri_ramp.size() / 3, all_tris.size() / 3])
	print("包围盒(Godot): min=%v max=%v" % [mn, mx])

	# 组装 ArrayMesh（3 surface，灰盒材质）
	var mesh := ArrayMesh.new()
	_add_surface(mesh, tri_floor, nrm_floor, "res://resources/materials/mat_floor.tres")
	_add_surface(mesh, tri_wall, nrm_wall, "res://resources/materials/mat_wall.tres")
	_add_surface(mesh, tri_ramp, nrm_ramp, "res://resources/materials/mat_raised.tres")

	DirAccess.make_dir_recursive_absolute("res://assets/dust2")
	var mesh_path := "res://assets/dust2/world_geo.mesh"
	var col_path := "res://assets/dust2/world_col.res"
	var e1 := ResourceSaver.save(mesh, mesh_path)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(all_tris)
	shape.backface_collision = true  # trimesh 双面：子弹 hitscan/射线两面都命中，不穿墙
	var e2 := ResourceSaver.save(shape, col_path)
	print("保存 mesh(%s)=%d  collision(%s)=%d" % [mesh_path, e1, col_path, e2])
	quit(0)


func _to_godot(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)


func _read_i32() -> int:
	var u := _f.get_32()
	return u - 0x100000000 if u >= 0x80000000 else u


## 解析 entities lump：只取每块的 key/value（我们只用 model/origin/classname）。
func _read_entities() -> Array:
	var off: int = _lumps[LUMP_ENTITIES][0]
	var ln: int = _lumps[LUMP_ENTITIES][1]
	_f.seek(off)
	var text := _f.get_buffer(ln).get_string_from_ascii()
	var out: Array = []
	var re := RegEx.new()
	re.compile('"([^"]*)"\\s*"([^"]*)"')
	for block in text.split("}"):
		if block.find("{") == -1:
			continue
		var d := {}
		for m in re.search_all(block):
			d[m.get_string(1)] = m.get_string(2)
		if not d.is_empty():
			out.append(d)
	return out


## 读 MODELS lump → 每个模型 [firstface, numfaces, origin]
func _read_models() -> Array:
	var out: Array = []
	var off: int = _lumps[LUMP_MODELS][0]
	var n: int = _lumps[LUMP_MODELS][1] / 64
	for i in n:
		_f.seek(off + i * 64 + 24)  # 跳过 mins[3]+maxs[3]=24 → origin[3]
		var ox := _f.get_float()
		var oy := _f.get_float()
		var oz := _f.get_float()
		# headnode[4]=16 + visleafs[1]=4 → firstface
		_f.seek(off + i * 64 + 56)
		var ff := _read_i32()
		var nf := _read_i32()
		out.append([ff, nf, Vector3(ox, oy, oz)])
	return out


func _read_vertices() -> PackedVector3Array:
	var out := PackedVector3Array()
	var off: int = _lumps[LUMP_VERTEXES][0]
	var n: int = _lumps[LUMP_VERTEXES][1] / 12
	_f.seek(off)
	for i in n:
		out.append(Vector3(_f.get_float(), _f.get_float(), _f.get_float()))
	return out


func _read_edges() -> Array:
	var out := []
	var off: int = _lumps[LUMP_EDGES][0]
	var n: int = _lumps[LUMP_EDGES][1] / 4
	_f.seek(off)
	for i in n:
		out.append([_f.get_16(), _f.get_16()])
	return out


func _read_surfedges() -> PackedInt32Array:
	var out := PackedInt32Array()
	var off: int = _lumps[LUMP_SURFEDGES][0]
	var n: int = _lumps[LUMP_SURFEDGES][1] / 4
	_f.seek(off)
	for i in n:
		out.append(_read_i32())
	return out


func _read_planes() -> Array:
	var out := []
	var off: int = _lumps[LUMP_PLANES][0]
	var n: int = _lumps[LUMP_PLANES][1] / 20
	_f.seek(off)
	for i in n:
		var nx := _f.get_float()
		var ny := _f.get_float()
		var nz := _f.get_float()
		_f.get_float()  # dist
		_f.get_32()  # type
		out.append([Vector3(nx, ny, nz)])
	return out


func _read_texture_names() -> PackedStringArray:
	var out := PackedStringArray()
	var base: int = _lumps[LUMP_TEXTURES][0]
	_f.seek(base)
	var count := _read_i32()
	var offsets := []
	for i in count:
		offsets.append(_read_i32())
	for o in offsets:
		if o < 0:
			out.append("")
			continue
		_f.seek(base + o)
		var name := _f.get_buffer(16).get_string_from_ascii().to_lower()
		out.append(name)
	return out


func _read_texinfo_miptex() -> PackedInt32Array:
	var out := PackedInt32Array()
	var off: int = _lumps[LUMP_TEXINFO][0]
	var n: int = _lumps[LUMP_TEXINFO][1] / 40
	_f.seek(off)
	for i in n:
		_f.seek(off + i * 40 + 32)  # 跳过 vecs[2][4]=32
		out.append(_read_i32())  # miptex index
	return out


func _add_surface(mesh: ArrayMesh, tris: PackedVector3Array, nrms: PackedVector3Array, mat_path: String) -> void:
	if tris.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = tris
	arr[Mesh.ARRAY_NORMAL] = nrms
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := load(mat_path)
	if mat:
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
