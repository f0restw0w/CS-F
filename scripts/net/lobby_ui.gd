extends CanvasLayer
## 联机大厅：主机/加入。连接成功后隐藏；Esc 由 camera_controller 管鼠标。

@export var manager_path: NodePath = ^"../NetworkManager"

@onready var _manager: NetworkManager = get_node(manager_path)
@onready var _ip: LineEdit = $Panel/VBox/IP
@onready var _status: Label = $Panel/VBox/Status


func _ready() -> void:
	$Panel/VBox/HostBtn.pressed.connect(_on_host)
	$Panel/VBox/JoinBtn.pressed.connect(_on_join)
	multiplayer.connected_to_server.connect(func() -> void: visible = false)
	multiplayer.connection_failed.connect(func() -> void: _status.text = "连接失败")
	multiplayer.server_disconnected.connect(func() -> void:
		visible = true
		_status.text = "服务器已断开")
	# 命令行模式（--server/--connect）下不显示大厅
	var args := OS.get_cmdline_user_args()
	if args.has("--server") or args.has("--connect"):
		visible = false


func _on_host() -> void:
	var err := _manager.host()
	if err == OK:
		visible = false
	else:
		_status.text = "开服失败: %s" % error_string(err)


func _on_join() -> void:
	var ip := _ip.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err := _manager.join(ip)
	if err == OK:
		_status.text = "连接中…"
	else:
		_status.text = "加入失败: %s" % error_string(err)
