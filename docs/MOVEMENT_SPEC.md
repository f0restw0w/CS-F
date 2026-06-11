# MOVEMENT_SPEC.md — CS 1.6 移动物理规范

> 这是项目最重要的技术文档。`scripts/player/` 里的所有移动代码都必须以本文档为准。
> 数值来自 GoldSrc 引擎默认 cvar。实现时每个常量都要在注释里标回这里。

## 设计目标

复刻 CS 1.6（GoldSrc）的移动手感，关键是这几个相互独立的子系统：

1. 地面加速 / 摩擦（走路、急停的手感）
2. **空气加速（air acceleration）** — bunnyhop 和 air strafe 的根基，CS2 削的就是这个
3. 跳跃与连跳（bunnyhop）
4. 空中转身加速（air strafe，靠鼠标+方向键在空中加速）

CS2 手感"不对"的根因：Source 2 改了空气加速度模型和 subtick 处理，削弱了 air strafe 收益、加了隐性的连跳惩罚。我们要回到 GoldSrc 的原始模型。

## 核心常量（GoldSrc 默认值）

| 常量 | GoldSrc cvar | 默认值 | 说明 |
|------|-------------|--------|------|
| 地面加速 | `sv_accelerate` | 5.0 | 地面加速系数 |
| **空气加速** | `sv_airaccelerate` | **10.0** | 空气加速系数（关键！） |
| 摩擦 | `sv_friction` | 4.0 | 地面摩擦系数 |
| 停止速度 | `sv_stopspeed` | 75.0 | 低于此速度时摩擦增强，影响急停手感 |
| 最大速度 | `sv_maxspeed` | 320.0 | 玩家移动速度上限（单位/秒） |
| 重力 | `sv_gravity` | 800.0 | 单位/秒² |
| 跳跃初速 | — | ~268 | `sqrt(2 * gravity * 45)`，跳跃高度约 45 单位 |

> **关键细节：** GoldSrc 的 `airaccelerate` 配合空气加速公式里的速度上限裁剪（`wishspeed` 在空气中被裁到 ~30），产生了"只能靠转向加速、不能直线加速"的经典 air strafe 行为。**这个裁剪是 air strafe 的灵魂，必须实现。**

## 单位换算说明

GoldSrc 用的是 Quake 单位（英寸）。1 单位 ≈ 1 英寸 ≈ 0.0254 米。
在 Godot 里你可以选择：
- **方案 A（推荐原型用）**：直接用 GoldSrc 数值，把 1 Godot 单位当作 1 Quake 单位，世界按这个比例搭。手感公式零换算，最不容易错。
- **方案 B**：换算到米。所有常量乘 0.0254。容易引入浮点误差，不推荐原型期用。

**原型阶段一律用方案 A。** 先保证手感对，单位美观以后再说。

## 核心算法（伪代码，按 GoldSrc PM_ 函数还原）

### 1. Accelerate（地面加速）

```
func accelerate(wishdir, wishspeed, accel, delta):
    current_speed = velocity.dot(wishdir)
    add_speed = wishspeed - current_speed
    if add_speed <= 0:
        return
    accel_speed = accel * delta * wishspeed
    accel_speed = min(accel_speed, add_speed)
    velocity += accel_speed * wishdir
```

### 2. AirAccelerate（空气加速 —— air strafe 的核心）

```
func air_accelerate(wishdir, wishspeed, airaccel, delta):
    # 关键：空气中 wishspeed 被裁到一个很小的上限（GoldSrc 约 30）
    wishspd = min(wishspeed, AIR_WISH_SPEED_CAP)   # AIR_WISH_SPEED_CAP ≈ 30
    current_speed = velocity.dot(wishdir)
    add_speed = wishspd - current_speed
    if add_speed <= 0:
        return
    accel_speed = airaccel * wishspeed * delta   # 注意这里用未裁剪的 wishspeed
    accel_speed = min(accel_speed, add_speed)
    velocity += accel_speed * wishdir
```

> ⚠️ 注意第 1 行裁剪用 `wishspd`，第 6 行计算 `accel_speed` 用原始 `wishspeed`。这个不对称是 GoldSrc 的真实行为，**不要"修正"它**，它就是 air strafe 能加速的原因。实现完务必对照手感清单逐项验证。

### 3. Friction（地面摩擦）

```
func apply_friction(delta):
    speed = velocity.length()
    if speed < 0.1:
        return
    # stopspeed 让低速时摩擦更强 → 急停干脆
    control = max(speed, STOP_SPEED)
    drop = control * FRICTION * delta
    new_speed = max(speed - drop, 0) / speed
    velocity *= new_speed
```

> 摩擦只在**地面**施加。空中不施加摩擦（这是连跳能保速的原因之一）。

### 4. 主循环（每个 physics tick）

```
func _physics_process(delta):
    wishdir = 从输入计算的水平移动方向（已归一化）
    wishspeed = MAX_SPEED

    if on_ground:
        if 刚落地 and 没在按跳:
            apply_friction(delta)        # 落地施加摩擦
        accelerate(wishdir, wishspeed, ACCELERATE, delta)
        velocity.y = 0 或处理跳跃
    else:
        air_accelerate(wishdir, wishspeed, AIR_ACCELERATE, delta)
        velocity.y -= GRAVITY * delta    # 重力

    move_and_collide(velocity * delta)   # 用 collide 不是 slide，自己处理滑墙
```

### 5. Bunnyhop（连跳）

- 落地瞬间如果跳跃键仍按住 → **不施加落地摩擦**，立即重新起跳，保留水平速度。
- 这是连跳保速的关键：正常落地会被摩擦吃掉速度，连跳跳过摩擦帧。
- GoldSrc 后期版本加过连跳速度上限（防止无限加速），原型阶段可先**不加**上限，先把基础手感做出来，让负责人决定要不要还原后期的上限。

## 实现注意事项

- **用 `move_and_collide` + 手动滑墙**，不要用 `move_and_slide`。Godot 的 slide 会改变速度向量，破坏 air strafe 数学。撞墙后要把速度投影到墙面（clip velocity），保留切向分量。
- **Clip velocity（撞墙削速）公式**（GoldSrc PM_ClipVelocity）：
  ```
  backoff = velocity.dot(normal) * overbounce   # overbounce 通常 1.0
  velocity -= normal * backoff
  ```
  这个保留沿墙滑行的速度，是 surf 和贴墙加速的基础。
- **固定 tick rate。** 在 `project.godot` 里设 `physics/common/physics_ticks_per_second`。GoldSrc 常见 100 tick（`fps_max 100`/`cl_cmdrate`）。原型先用 **100**，因为 1.6 手感与高 tick 强相关。
- **鼠标视角**只决定 `wishdir` 的朝向，不直接改速度。air strafe 的加速完全来自 air_accelerate 里速度方向与 wishdir 的夹角关系。

## 待负责人决策的手感参数

这些没有"标准答案"，需要前职业选手实际试玩定夺，做成可实时调的 `@export`：

- 连跳是否加速度上限（还原后期 1.6 还是经典无限连跳）
- tick rate 最终值（100 / 128 / 其他）
- `AIR_WISH_SPEED_CAP` 精确值（30 是常见值，但不同版本有出入）
- 跳跃高度微调

## 参考来源

- GoldSrc / Quake `PM_` 移动函数（`pm_shared.c` 的 PM_Accelerate / PM_AirAccelerate / PM_Friction / PM_ClipVelocity）
- 实现完成后，按 `docs/TESTING.md` 的手感清单逐项验证，**以负责人主观判断为最终标准**。
