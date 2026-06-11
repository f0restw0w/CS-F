# ARCHITECTURE.md — 代码架构

> 原型阶段保持简单。架构服务于"快速迭代手感"，不过度设计。

## 目录约定

```
scenes/
├── test_map.tscn          # 灰盒测试关卡（Phase 0）
└── player.tscn            # 玩家场景（CharacterBody3D + 相机 + 碰撞体）

scripts/
├── player/
│   ├── player_controller.gd    # 主控制器，挂在 CharacterBody3D 上
│   ├── movement.gd             # 纯移动数学（accelerate/airaccelerate/friction/clip）
│   └── camera_controller.gd    # 鼠标视角
└── debug/
    └── speed_hud.gd            # 实时显示速度/状态的调试 HUD

resources/
└── movement_params.tres        # 所有可调物理常量（MovementParams 资源）
```

## 关键设计：移动数学与控制器分离

把纯物理数学（`movement.gd`）从控制器（`player_controller.gd`）里抽出来，理由：

1. **可单独测试。** 移动数学是纯函数，可以写单元测试验证公式正确性，不用进游戏。
2. **可对照 spec 审查。** 数学集中在一处，方便对照 `MOVEMENT_SPEC.md` 检查。
3. **手感调试隔离。** 调参时只动 `movement_params.tres`，不碰逻辑。

## MovementParams 资源

把所有 GoldSrc 常量做成一个 `Resource`，`@export` 出来，存成 `.tres`：

```gdscript
# scripts/player/movement_params.gd
extends Resource
class_name MovementParams

@export var max_speed: float = 320.0          # sv_maxspeed
@export var accelerate: float = 5.0           # sv_accelerate
@export var air_accelerate: float = 10.0      # sv_airaccelerate
@export var friction: float = 4.0             # sv_friction
@export var stop_speed: float = 75.0          # sv_stopspeed
@export var gravity: float = 800.0            # sv_gravity
@export var jump_height: float = 45.0         # 跳跃高度（单位）
@export var air_wish_speed_cap: float = 30.0  # 空气 wishspeed 裁剪上限
@export var bhop_speed_cap_enabled: bool = false  # 是否启用连跳速度上限
```

这样负责人可以在 Godot Inspector 里实时拖动数值找手感，甚至运行时热改。

## 物理循环位置

- 所有移动逻辑在 `player_controller.gd` 的 `_physics_process(delta)`。
- 视角（鼠标）在 `_input` 收集，在 `_physics_process` 应用，避免相机抖动。
- **绝不**把移动放进 `_process`。

## 状态

原型阶段移动状态很简单，用枚举即可，不需要正式状态机：
- `GROUND` / `AIR`
- 落地帧是否按住跳跃键（决定 bhop）

等加入蹲、surf 等再考虑引入显式状态机。**不要提前抽象。**

## 调试 HUD（Phase 0 必须有）

实时显示，方便负责人判断手感：
- 当前水平速度（最重要）
- 是否在地面
- 垂直速度
- 是否处于连跳保速状态

速度数字是验证手感的客观参照——职业选手知道直线跑应该是 320，连跳后应该能突破多少。
