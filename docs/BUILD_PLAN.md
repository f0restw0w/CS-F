# BUILD_PLAN.md — Claude Code 自主开工指令

> 本文件供 Claude Code 在 **bypass permission（自主）模式**下执行。负责人不会中途介入，做完后统一验收。
> 总纲：严格按 Phase 0 推进，照 `MOVEMENT_SPEC.md` 和 `MAP_DUST2.md` 实现。**手感优先于一切。**

## 自主模式总原则

1. **不要停下来问权限或确认**，按本计划自主推进到 Phase 0 全部完成。
2. **遇到拿不准的决策**（手感参数取值、dust2 某尺寸不确定、公式细节有歧义）：选一个有依据的默认值继续做下去，**并记录到 `DECISIONS_FOR_REVIEW.md`**（见下），不要卡住。
3. **小步提交**，每步一个清晰 commit。移动相关改动 commit message 带 `[FEEL]`。
4. **每完成一个 Step 就更新 `PROGRESS.md`**，写明做了什么、留了什么待验收。
5. 不碰 Phase 0 范围外的东西（武器/联机/UI/美术/网络一律不做）。
6. 绝不导入任何 Valve 资产，灰盒全部用 Godot 原生几何体搭。

## 待验收记录机制

在仓库根目录维护两个文件，供负责人验收时快速定位：

- **`PROGRESS.md`** — 进度日志。每个 Step 完成后追加：做了什么、对应哪个文档、commit 哈希。
- **`DECISIONS_FOR_REVIEW.md`** — 所有"我自己拍板、需要负责人复核"的决策。格式：
  ```
  ## [区域/主题] 决策点
  - 情况：哪里不确定
  - 我选的默认值：xxx，依据：xxx
  - 负责人需确认：xxx（尤其手感/尺寸类）
  ```
  手感参数、dust2 尺寸校准点，全部记这里——这是负责人验收的核对清单。

## 分步计划（Phase 0）

### Step 1 — 项目骨架
- 建 Godot 4 项目，`project.godot` 设 `physics/common/physics_ticks_per_second = 100`。
- 建目录：`scenes/`、`scenes/regions/`、`scripts/player/`、`scripts/debug/`、`resources/`。
- commit: `chore: scaffold Godot 4 project`

### Step 2 — 移动参数资源
- 按 `ARCHITECTURE.md` 实现 `MovementParams`（`scripts/player/movement_params.gd`）。
- 存一份默认值 `resources/movement_params.tres`，数值取 `MOVEMENT_SPEC.md` 的 GoldSrc 默认值。
- commit: `feat: add MovementParams resource [FEEL]`

### Step 3 — 移动数学核心
- 实现 `scripts/player/movement.gd`（纯函数）：`accelerate` / `air_accelerate` / `apply_friction` / `clip_velocity`，**严格照 `MOVEMENT_SPEC.md` 的伪代码**。
- 特别注意 air_accelerate 里 wishspeed 裁剪与 accel_speed 用未裁剪值的不对称——照实现，不要"修正"。
- 同步写单元测试（GUT 或断言脚本），覆盖 `TESTING.md` 列的公式用例。
- commit: `feat: implement GoldSrc movement math + tests [FEEL]`

### Step 4 — 玩家控制器
- `scenes/player.tscn`：CharacterBody3D + 碰撞体（32×32×72）+ 相机（眼高 64）。
- `scripts/player/player_controller.gd`：固定步长 `_physics_process` 主循环、地面/空中分支、跳跃、bunnyhop（落地按跳跳过摩擦）。用 `move_and_collide` + 手动 clip，**不用 move_and_slide**。
- `scripts/player/camera_controller.gd`：鼠标视角 + 捕获鼠标。
- commit: `feat: player controller with bhop + air strafe [FEEL]`

### Step 5 — 调试 HUD
- `scripts/debug/speed_hud.gd`：实时显示水平速度、垂直速度、是否在地面、是否连跳保速。
- commit: `feat: debug speed HUD`

### Step 6 — 灰盒 dust2（照 MAP_DUST2.md）
- 每个分区一个独立场景放 `scenes/regions/`（mid / long_a / short_a / a_site / b_tunnels / b_site / ct_spawn / t_spawn / arch）。
- 用 CSGBox3D 或 BoxMesh+StaticBody3D 搭，按文档灰度区分地面/墙/可跳箱。
- `scenes/dust2.tscn` 总装所有分区 + 玩家 + HUD + 基础环境光（够看清灰盒即可）。
- 出生点用 Marker3D。所有不确定的尺寸记进 `DECISIONS_FOR_REVIEW.md`。
- commit（可拆多个）: `feat: greybox dust2 - <region>`

### Step 7 — 自检与收尾
- 跑一遍单元测试，确保通过。
- 确认游戏能启动、能进 dust2 灰盒、能跑跳。
- 补全 `PROGRESS.md` 和 `DECISIONS_FOR_REVIEW.md`。
- 在 `PROGRESS.md` 末尾写一份"验收指引"：负责人该怎么启动、该重点试哪些手感（指向 `TESTING.md` 清单）。
- commit: `docs: phase 0 progress + review notes`

## 完成定义（Phase 0）

- 游戏能在 Godot 4 里运行，进入灰盒 dust2。
- 玩家能跑、跳、连跳、air strafe、贴墙削速。
- 调试 HUD 显示速度等信息。
- 单元测试通过。
- `PROGRESS.md` 和 `DECISIONS_FOR_REVIEW.md` 完整，负责人可据此验收和校准。

做完即停，等负责人验收，**不要**擅自进入 Phase 1。
