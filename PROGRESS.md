# PROGRESS.md — Phase 0 进度日志

> 自主模式执行 `docs/BUILD_PLAN.md` Phase 0。已全部完成，等负责人验收。
> 决策复核清单见 `DECISIONS_FOR_REVIEW.md`。

## Step 1 — 项目骨架 ✅ `e7b096b`
- `project.godot`：`physics_ticks_per_second = 100`（固定步长，1.6 手感对 tick 敏感），WASD+空格输入映射，主场景指向 `scenes/dust2.tscn`。
- 目录：`scenes/regions`、`scripts/player`、`scripts/debug`、`resources`、`assets`、`tests`。
- 文档按 CLAUDE.md 约定移入 `docs/`；`.gitignore` 取自脚手架。

## Step 2 — MovementParams 资源 ✅ `15b8ade`
- `scripts/player/movement_params.gd` + `resources/movement_params.tres`。
- 全部 GoldSrc 默认值：maxspeed 320 / accelerate 5 / airaccelerate 10 / friction 4 / stopspeed 75 / gravity 800 / 跳高 45 / air cap 30 / bhop 上限关。
- 所有参数 `@export`，Inspector 实时可调。

## Step 3 — 移动数学核心 + 单元测试 ✅ `0a95dbe`
- `scripts/player/movement.gd` 纯静态函数：`accelerate` / `air_accelerate` / `apply_friction` / `clip_velocity`，严格按 `docs/MOVEMENT_SPEC.md` 伪代码。
- air_accelerate 的 wishspeed 裁剪不对称（cap 30 判定 / 未裁剪值算加速）**原样保留**。
- `tests/test_movement.gd`：30 条断言，覆盖 TESTING.md 全部公式用例，**30/30 通过**。

## Step 4 — 玩家控制器 ✅ `a3f71d0`
- `scenes/player.tscn`：盒型碰撞 32×32×72（GoldSrc hull）、眼高 64、FOV 73.74。
- `scripts/player/player_controller.gd`：固定步长主循环；`move_and_collide` + 手动 `clip_velocity`（4 面裁剪迭代）；台阶攀爬（18，两种走法取优）；**跳跃在摩擦前处理 → 落地按住跳跳过摩擦帧 = 连跳保速**；离地 vy>180 / 地面法线 ≥0.7 / 向下 trace 2，均按 GoldSrc。
- `scripts/player/camera_controller.gd`：`_input` 收集 / `_physics_process` 应用，0.022°/count，pitch ±89°，Esc 切换鼠标捕获。

## Step 5 — 调试速度 HUD ✅ `d3365ca`
- `scripts/debug/speed_hud.gd`：水平速度 / 垂直速度 / 峰值速度（站定自动清零）/ 地面状态 / 连跳保速标记 / tick rate。

## Step 6 — 灰盒 dust2 ✅ `24ce883`..`f9a9a24`
- 9 个分区独立场景（`scenes/regions/`）：t_spawn / ct_spawn / mid / long_a / short_a / a_site / b_tunnels / b_site / arch，全 CSGBox3D + 灰度材质，世界坐标统一，`dust2.tscn` 总装。
- 关键测试点已放 Marker3D 标注（Xbox 一跳上箱 / 猫道跳下保速 / 箱堆逐级 / 隧道拐弯贴墙 / 拱门贴框 / Pit 逃生）。
- 坐标网格全表与所有尺寸取舍见 `DECISIONS_FOR_REVIEW.md`。
- `tests/test_integration.gd`：无头加载 dust2 实测——落地 / 直线跑 320.0 / 跳跃初速 / air strafe 320→362（转向加速、突破 maxspeed），**7/7 通过**。

## Step 7 — 自检与收尾 ✅（本 commit）
- 单元测试 30/30、集成测试 7/7、游戏本体无头跑 300 帧无报错。
- 本文件 + `DECISIONS_FOR_REVIEW.md` 补全。

---

# 验收指引（给负责人）

## 启动
1. 装 Godot 4.x（开发用的是 **4.6.3-stable**，已放在 `F:\Project\tools\godot\Godot_v4.6.3-stable_win64.exe`）。
2. 用 Godot 打开本仓库（双击 `project.godot` 或拖进 Project Manager）。
3. 直接 F5 运行——主场景就是灰盒 dust2，出生在 T 家面向中路。

## 操作
- WASD 移动，空格跳（**按住空格 = 自动连跳**），鼠标视角，Esc 释放/恢复鼠标。
- 掉出地图会自动回出生点。

## 重点试什么（对照 docs/TESTING.md 清单）
1. **直线跑**：HUD 速度应稳定 320。急停是否干脆（stopspeed 手感）。
2. **长A**：从 Long Doors 一路 air strafe 连跳到 A 口，看 HUD 峰值能否明显破 320（无头实测 0.5 秒转向即 362）。
3. **中路**：穿双门贴框是否削速但不卡死；Xbox 一跳上箱、上箱接连跳。
4. **B 隧道**：拐弯贴墙跑，切向速度是否保留；台阶（16 高）上下是否平滑无顿挫。
5. **A 点箱堆**：48→64→96→128 逐级跳。
6. **猫道**：台阶跑上去、跳下 A 点落地接跳是否保速。
7. **盲测**：闭眼连跳两轮，凭手感判断"像不像 1.6"。

## 调参
- 全部物理常量在 `resources/movement_params.tres`，Inspector 里改完直接生效（运行中也能热改）。
- 哪里不对 → 对照 `DECISIONS_FOR_REVIEW.md` 逐条决策（尤其：自动连跳 vs 重触发、贴地吸附 18、Xbox 高度 60、FOV）。
- 复跑测试：
  ```
  godot --headless --path . --script res://tests/test_movement.gd
  godot --headless --path . --script res://tests/test_integration.gd
  ```

## 已知与原版的差异（待你定夺）
见 `DECISIONS_FOR_REVIEW.md`，核心三条：自动连跳、整步重力、灰盒若干尺寸简化。

**Phase 0 到此为止，未动武器/联机/UI/美术。**
