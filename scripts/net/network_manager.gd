extends Node
class_name NetworkManager
## 移动网络同步（Phase 4）：服务器权威 + 客户端预测/回滚重放 + 远端快照插值。
##
## 架构（docs/ROADMAP.md Phase 4）：
## - 客户端每 physics tick 采输入 → 本地立即 simulate（预测）→ 输入(带 seq)发服务器
## - 服务器收输入按序权威 simulate（同一份 simulate 代码！）→ 回 ack(seq+状态)
## - 客户端比对 ack 与当 tick 预测：误差超阈值 → 回滚到服务器状态、重放后续输入
## - 其他玩家：服务器 50Hz 广播快照，客户端延迟 100ms 双帧插值
## - 射击：客户端本地出弹（手感零延迟）+ 射线上报服务器做权威命中校验
##
## 1.6 手感的关键：预测与权威用同一 simulate()，误差只来自丢包/时序，
## 正常网络下回滚率应接近 0。

const DEFAULT_PORT := 27015
const PLAYER_SCENE := preload("res://scenes/player.tscn")
## 快照广播间隔（tick）：2 = 50Hz
const SNAPSHOT_INTERVAL := 2
## 远端插值延迟（秒）
const INTERP_DELAY := 0.1
## 服务器单 tick 最多消化的积压输入（追帧上限）
const MAX_INPUTS_PER_TICK := 3
## 预测位置误差阈值（单位），超过即回滚重放
const CORRECTION_EPS := 1.0
## 输入历史上限
const HISTORY_MAX := 256

@export var players_container: NodePath = ^"../Players"
## 出生点轮转（T 家 + CT 家混排，死斗式）
# 真实 bsp 坐标：T 家（北, gs y~3050, 脚高 128）/ CT 家（南, gs y~-1008, 脚高 ~150）
@export var spawn_points: Array[Vector3] = [
	Vector3(1200, 132, -3050), Vector3(1100, 132, -3000), Vector3(1300, 132, -3000),
	Vector3(-500, 152, 1008), Vector3(-650, 152, 1008), Vector3(-785, 158, 1008),
]

var is_server := false
var local_player: PlayerController
## —— 调试/测试读数 ——
var acks_received := 0
var corrections := 0
var last_correction_error := 0.0

var _tick_delta := 0.01
var _spawn_idx := 0

# 服务器侧
var _server_players := {}  # peer_id -> PlayerController
var _input_queues := {}    # peer_id -> Array[PlayerInput]
var _tick := 0
var _weapon_params: WeaponParams

# 客户端侧
var _history: Array = []   # {seq, inp, state}
var _puppets := {}         # peer_id -> PlayerController
var _snap_buffers := {}    # peer_id -> Array[[local_time, pos, yaw, ducked]]
var _local_time := 0.0


func _ready() -> void:
	_tick_delta = 1.0 / float(Engine.physics_ticks_per_second)
	_weapon_params = load("res://resources/weapons/ak47.tres")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# 命令行：--server [port] / --connect ip[:port]（无头专服/自动化测试用）
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--server":
			var port := DEFAULT_PORT
			if i + 1 < args.size() and args[i + 1].is_valid_int():
				port = int(args[i + 1])
			host(port)
		elif args[i] == "--connect" and i + 1 < args.size():
			var parts: PackedStringArray = args[i + 1].split(":")
			join(parts[0], int(parts[1]) if parts.size() > 1 else DEFAULT_PORT)
			i += 1
		i += 1


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 16)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_server = true
	# 带画面的主机 = listen server，给自己也生成玩家；无头 = 纯专服
	if DisplayServer.get_name() != "headless":
		_server_spawn(1)
	print("[net] server listening on %d" % port)
	return OK


func join(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	print("[net] connecting to %s:%d" % [ip, port])
	return OK


func _container() -> Node:
	return get_node(players_container)


func _next_spawn() -> Vector3:
	var p := spawn_points[_spawn_idx % spawn_points.size()]
	_spawn_idx += 1
	return p


## —— 玩家节点装配 ——

func _make_player(id: int, pos: Vector3, local: bool) -> PlayerController:
	var p := PLAYER_SCENE.instantiate() as PlayerController
	p.name = str(id)
	p.is_local = local
	_container().add_child(p)
	p.global_position = pos
	if not local:
		# 镜像/傀儡：关相机、关鼠标视角采集、关武器自主开火
		var cam := p.get_node("Head/Camera3D") as Camera3D
		cam.current = false
		var head := p.get_node("Head")
		head.set_process_input(false)
		head.set_physics_process(false)
		p.get_node("Head/Camera3D/Weapon").set_physics_process(false)
	return p


## —— 服务器逻辑 ——

func _on_peer_connected(id: int) -> void:
	if not is_server:
		return
	# 把已有玩家名册发给新客户端
	for existing_id in _server_players:
		spawn_player.rpc_id(id, existing_id, _server_players[existing_id].global_position)
	_server_spawn(id)


func _on_peer_disconnected(id: int) -> void:
	if is_server:
		if _server_players.has(id):
			_server_players[id].queue_free()
			_server_players.erase(id)
			_input_queues.erase(id)
		despawn_player.rpc(id)
	else:
		# 服务器关闭等：清场
		if id == 1:
			for pid in _puppets:
				_puppets[pid].queue_free()
			_puppets.clear()


func _server_spawn(id: int) -> void:
	var pos := _next_spawn()
	var local := id == 1 and multiplayer.get_unique_id() == 1 and DisplayServer.get_name() != "headless"
	var p := _make_player(id, pos, local)
	_server_players[id] = p
	_input_queues[id] = []
	if local:
		local_player = p
		p.get_node("Head/Camera3D/Weapon").fired_ray.connect(
				func(f: Vector3, d: Vector3) -> void: _server_process_shot(1, f, d))
	# 通知所有客户端生成该玩家（含其本人）
	spawn_player.rpc(id, pos)


func _physics_process(_delta: float) -> void:
	_local_time += _delta
	if is_server:
		_server_tick()
	else:
		_interpolate_puppets()


func _server_tick() -> void:
	_tick += 1
	for id in _server_players:
		var p: PlayerController = _server_players[id]
		if p.is_local:
			continue  # listen server 主机自己走本地路径
		var q: Array = _input_queues[id]
		# 队列空 = 输入未到 → 本 tick 等待（不外推！外推会模拟客户端从未预测
		# 的 tick，破坏 seq↔状态对齐，导致全程无谓回滚）。代价只是快照滞后。
		if q.is_empty():
			continue
		var inp: PlayerInput = null
		var n: int = mini(q.size(), MAX_INPUTS_PER_TICK)
		for j in n:
			inp = q.pop_front()
			p.simulate(inp, _tick_delta)
		# 只对真正消化过的输入回 ack
		state_ack.rpc_id(id, inp.seq, p.global_position, p.velocity,
				p.ducked, p._duck_timer, p.grounded, p._was_grounded)

	if _tick % SNAPSHOT_INTERVAL == 0:
		var data := {}
		for id in _server_players:
			var p: PlayerController = _server_players[id]
			data[id] = [p.global_position, p.rotation.y, p.ducked]
		snapshot.rpc(data)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(arr: Array) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if _input_queues.has(id):
		_input_queues[id].append(PlayerInput.from_array(arr))


@rpc("any_peer", "call_remote", "reliable")
func submit_shot(from: Vector3, dir: Vector3) -> void:
	if not is_server:
		return
	_server_process_shot(multiplayer.get_remote_sender_id(), from, dir)


## 服务器权威命中：校验射线起点贴近射手头部，对其他玩家结算伤害
func _server_process_shot(shooter_id: int, from: Vector3, dir: Vector3) -> void:
	var shooter: PlayerController = _server_players.get(shooter_id)
	if shooter == null:
		return
	var eye := shooter.global_position + Vector3(0, 64, 0)
	if from.distance_to(eye) > 80.0:
		return  # 起点离谱，丢弃（防作弊的最低限度校验）
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * _weapon_params.max_range)
	q.exclude = [shooter.get_rid()]
	var res := shooter.get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return
	var col: Object = res.collider
	if col is PlayerController:
		var victim := col as PlayerController
		var dmg: float = _weapon_params.damage * pow(_weapon_params.range_modifier,
				from.distance_to(res.position) / 512.0)
		var is_head := victim.is_hit_head(res.position.y)
		if is_head:
			dmg *= _weapon_params.headshot_multiplier
		victim.take_hit(dmg, is_head)
		var victim_id := int(String(victim.name))
		if victim_id != 1:
			health_update.rpc_id(victim_id, victim.health)


## —— 客户端逻辑 ——

@rpc("authority", "call_remote", "reliable")
func spawn_player(id: int, pos: Vector3) -> void:
	if id == multiplayer.get_unique_id():
		local_player = _make_player(id, pos, true)
		local_player.input_simulated.connect(_on_local_input)
		local_player.get_node("Head/Camera3D/Weapon").fired_ray.connect(
				func(f: Vector3, d: Vector3) -> void: submit_shot.rpc_id(1, f, d))
	else:
		if _puppets.has(id):
			return
		_puppets[id] = _make_player(id, pos, false)
		_snap_buffers[id] = []


@rpc("authority", "call_remote", "reliable")
func despawn_player(id: int) -> void:
	if _puppets.has(id):
		_puppets[id].queue_free()
		_puppets.erase(id)
		_snap_buffers.erase(id)


func _on_local_input(inp: PlayerInput) -> void:
	_history.append({"seq": inp.seq, "inp": inp, "state": local_player.capture_state()})
	if _history.size() > HISTORY_MAX:
		_history.pop_front()
	submit_input.rpc_id(1, inp.to_array())


@rpc("authority", "call_remote", "unreliable_ordered")
func state_ack(seq: int, pos: Vector3, vel: Vector3, srv_ducked: bool,
		srv_duck_timer: float, srv_grounded: bool, srv_was_grounded: bool) -> void:
	acks_received += 1
	var idx := -1
	for i in _history.size():
		if _history[i].seq == seq:
			idx = i
			break
	if idx == -1:
		return  # 太老，已被裁剪
	var predicted: Dictionary = _history[idx].state
	last_correction_error = (predicted.pos as Vector3).distance_to(pos)
	if last_correction_error > CORRECTION_EPS or predicted.ducked != srv_ducked:
		corrections += 1
		# 回滚到服务器权威状态，重放其后所有未确认输入（同一 simulate 代码）
		local_player.apply_state({
			"pos": pos, "vel": vel, "yaw": (_history[idx].inp as PlayerInput).yaw,
			"ducked": srv_ducked, "duck_timer": srv_duck_timer,
			"grounded": srv_grounded, "was_grounded": srv_was_grounded,
		})
		for j in range(idx + 1, _history.size()):
			local_player.simulate(_history[j].inp, _tick_delta)
			_history[j].state = local_player.capture_state()
	_history = _history.slice(idx + 1)


@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(data: Dictionary) -> void:
	var my_id := multiplayer.get_unique_id()
	for id in data:
		if id == my_id or not _puppets.has(id):
			continue
		var buf: Array = _snap_buffers[id]
		var d: Array = data[id]
		buf.append([_local_time, d[0], d[1], d[2]])
		while buf.size() > 60:
			buf.pop_front()


@rpc("authority", "call_remote", "reliable")
func health_update(hp: float) -> void:
	if local_player:
		local_player.health = hp
		local_player.health_changed.emit(hp)


## 远端傀儡插值：渲染时间 = 本地时间 − 100ms，双帧线性插值
func _interpolate_puppets() -> void:
	var render_time := _local_time - INTERP_DELAY
	for id in _puppets:
		var p: PlayerController = _puppets[id]
		var buf: Array = _snap_buffers[id]
		if buf.is_empty():
			continue
		var a: Array = buf[0]
		var b: Array = buf[buf.size() - 1]
		for i in range(buf.size() - 1):
			if buf[i][0] <= render_time and buf[i + 1][0] >= render_time:
				a = buf[i]
				b = buf[i + 1]
				break
		var t := 0.0
		if b[0] > a[0]:
			t = clampf((render_time - a[0]) / (b[0] - a[0]), 0.0, 1.0)
		p.global_position = (a[1] as Vector3).lerp(b[1], t)
		p.rotation.y = lerp_angle(a[2], b[2], t)
		var ducked_now: bool = b[3]
		if ducked_now != p.ducked:
			if ducked_now:
				p._set_ducked_hull()
			else:
				p._set_standing_hull()
