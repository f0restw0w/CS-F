class_name PlayerInput
extends RefCounted
## 一个 physics tick 的玩家输入快照（Phase 4 网络同步的最小单元）。
## 本地采集 → 立即预测模拟 + 发给服务器；服务器按相同结构权威模拟；
## 回滚重放时按 seq 顺序重新喂给 simulate()。

var seq: int = 0
## 朝向 yaw（弧度）。鼠标只决定朝向——网络层只传角度不传鼠标增量
var yaw: float = 0.0
## 原始移动输入（x=左右, y=前后），与 Input.get_vector 一致
var wish: Vector2 = Vector2.ZERO
var jump: bool = false
var duck: bool = false


func to_array() -> Array:
	return [seq, yaw, wish.x, wish.y, jump, duck]


static func from_array(a: Array) -> PlayerInput:
	var inp := PlayerInput.new()
	inp.seq = a[0]
	inp.yaw = a[1]
	inp.wish = Vector2(a[2], a[3])
	inp.jump = a[4]
	inp.duck = a[5]
	return inp
