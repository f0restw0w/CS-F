extends SceneTree
## GoldSrc .dem 轨迹提取器：解析负责人在 1.6 里录的 demo，导出逐帧玩家坐标。
## 只提取坐标/视角等数字事实（几何测量），不读取任何 Valve 资产内容。
##
## 用法：godot --headless --script res://tools/demo_extract.gd -- <demo路径> [输出csv]
## 输出列：time,frame,src,x,y,z,pitch,yaw   （GoldSrc 坐标：z 为竖直轴）
## 帧类型参考：社区公开的 HLDEMO 格式文档（hlviewer 等开源实现）。

var _rows := PackedStringArray()
var _count := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "F:/SteamLibrary/steamapps/common/Half-Life/cstrike/amap.dem"
	var out: String = args[1] if args.size() > 1 else "F:/Project/github/CS-F/.godot/demo_trace.csv"

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("无法打开 demo: " + path)
		quit(1)
		return

	var magic := f.get_buffer(8).get_string_from_ascii()
	var demo_proto := f.get_32()
	var net_proto := f.get_32()
	var map_name := f.get_buffer(260).get_string_from_ascii()
	var game_dir := f.get_buffer(260).get_string_from_ascii()
	f.get_32()  # map crc
	var dir_offset := f.get_32()
	print("magic=%s demo_proto=%d net_proto=%d map=%s gamedir=%s dir@%d filesize=%d" %
			[magic, demo_proto, net_proto, map_name, game_dir, dir_offset, f.get_length()])
	if not magic.begins_with("HLDEMO"):
		printerr("不是 HLDEMO 文件")
		quit(1)
		return

	_rows.append("time,frame,src,x,y,z,pitch,yaw")

	# 目录
	f.seek(dir_offset)
	var n := f.get_32()
	print("目录条目数=%d" % n)
	var entries: Array = []
	for i in n:
		var etype := f.get_32()
		var desc := f.get_buffer(64).get_string_from_ascii()
		f.get_32()  # flags
		f.get_32()  # cd track
		f.get_float()  # track time
		var frames := f.get_32()
		var offset := f.get_32()
		var length := f.get_32()
		print("  entry[%d] type=%d desc=%s frames=%d offset=%d len=%d" % [i, etype, desc, frames, offset, length])
		entries.append(offset)

	for off in entries:
		_parse_frames(f, off)

	var fo := FileAccess.open(out, FileAccess.WRITE)
	fo.store_string("\n".join(_rows))
	fo = null
	print("样本数=%d → %s" % [_count, out])
	quit(0)


func _parse_frames(f: FileAccess, start_offset: int) -> void:
	f.seek(start_offset)
	while f.get_position() < f.get_length() - 9:
		var ftype := f.get_8()
		var time := f.get_float()
		var frame := f.get_32()
		match ftype:
			5:  # 段结束
				return
			2:  # 段开始，无数据
				pass
			3:  # 控制台命令 char[64]
				f.seek(f.get_position() + 64)
			4:  # ClientData: origin 3f, viewangles 3f(pitch,yaw,roll), weaponbits i, fov f
				var ox := f.get_float()
				var oy := f.get_float()
				var oz := f.get_float()
				var pitch := f.get_float()
				var yaw := f.get_float()
				f.get_float()  # roll
				f.get_32()  # weapon bits
				f.get_float()  # fov
				_rows.append("%.4f,%d,cd,%.2f,%.2f,%.2f,%.2f,%.2f" % [time, frame, ox, oy, oz, pitch, yaw])
				_count += 1
			6:  # Event: flags i, index i, delay f + event args(72)
				f.seek(f.get_position() + 84)
			7:  # WeaponAnim: anim i, body i
				f.seek(f.get_position() + 8)
			8:  # Sound: channel i, sample(len+bytes), atten f, vol f, flags i, pitch i
				f.get_32()
				var slen := f.get_32()
				if slen < 0 or slen > 4096:
					printerr("异常 sound 长度 %d @%d" % [slen, f.get_position()])
					return
				f.seek(f.get_position() + slen + 16)
			9:  # DemoBuffer: len + data
				var blen := f.get_32()
				if blen < 0 or blen > 10000000:
					printerr("异常 buffer 长度 %d @%d" % [blen, f.get_position()])
					return
				f.seek(f.get_position() + blen)
			0, 1:  # NetMsg：定长 demoinfo(464) + msglen + data；从 RefParams 取 simorg
				var s := f.get_position()
				# refparams 内偏移：vieworg12+viewangles12+forward12+right12+up12=60,
				# frametime/time=8 → 68, 5 个 int=20 → 88, simvel12 → 100 = simorg
				f.seek(s + 4 + 100)
				var sx := f.get_float()
				var sy := f.get_float()
				var sz := f.get_float()
				# cl_viewangles 在 refparams 偏移 128（viewheight12+idealpitch4 后）
				f.seek(s + 4 + 128)
				var vp := f.get_float()
				var vy := f.get_float()
				f.seek(s + 464)
				var msglen := f.get_32()
				if msglen < 0 or msglen > 1000000:
					printerr("异常 msglen %d @frame %d pos %d —— 布局假设可能不对" % [msglen, frame, s])
					return
				f.seek(f.get_position() + msglen)
				_rows.append("%.4f,%d,nm,%.2f,%.2f,%.2f,%.2f,%.2f" % [time, frame, sx, sy, sz, vp, vy])
				_count += 1
			_:
				printerr("未知帧类型 %d @%d（解析中止该段）" % [ftype, f.get_position() - 9])
				return
