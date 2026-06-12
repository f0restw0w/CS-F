# PROGRESS.md — 进度日志

> Phase 0 已验收。Phase 1-4 按负责人指示连续自主完成，**一次性等验收**。
> 决策复核清单见 `DECISIONS_FOR_REVIEW.md`。测试总计 82 断言全过。

---

# Phase 2 — 武器系统（2026-06-12）

- **WeaponParams + AK-47**（`resources/weapons/ak47.tres`）：1.6 原值（36 伤/0.98 衰减/爆头×4/30+90/2.45s 换弹），射速 0.1s tick 对齐；30 发弹道模式近似形状全部可调。
- **HitscanWeapon**：固定步长射击循环、自动连发、打空自动换弹；弹道 = spray pattern + 分态扩散锥（站 0.08°/蹲×0.6/移动 1.6°/空中 3°）；视角 punch 仅视觉、弹道用真实瞄准角（压枪压 pattern——1.6 行为）。
- **占位反馈**：盒子枪模、tracer、弹孔、程序生成枪声（零外部资产）。
- **靶场** `scenes/test_range.tscn`：256/512/1024/2048 四距离人形靶（身/头区、血量、重生）。
- **武器 HUD**：动态准星（间隙=扩散+punch）、弹药、伤害日志。
- 测试 16 断言：爆头 142.6/身体 35.6/射速/弹道爬升/换弹/扩散分态。

# Phase 3 — 画质（引擎内，2026-06-12）

- dust2 环境：**SDFGI 全局光照** + SSAO + ACES tonemap + 轻雾 + 沙漠色 ProceduralSky + 暖阳多级阴影。
- 材质：程序噪声 triplanar 反照率+法线（灰盒无 UV 也有表面细节），灰度区分约定不变。
- **零外部资产**。真 PBR 替换等负责人提供素材。SDFGI 嫌重可在 WorldEnvironment 一键关。

# Phase 4 — 联机（2026-06-12）

- **确定性重构**：`PlayerInput` + `simulate(input, delta)`，本地预测/服务器权威/回滚重放同一条物理代码路径（手感不变形的根基），重构后 40 断言逐 tick 等价回归。
- **服务器权威移动**：客户端每 tick 发输入(seq)并本地预测；服务器按序权威模拟回 ack；误差>1 才回滚重放。**局域网实测：回滚 0 次、误差 0.000**。
- **远端玩家**：50Hz 快照 + 100ms 双帧插值（位置/yaw/蹲 hull）。
- **联机射击**：本地出弹保手感 + 服务器射线校验结算（衰减/爆头/生命/重生）。无 lag compensation（记入 DECISIONS 待定）。
- **入口**：`dust2_mp.tscn` 大厅 UI（主机/加入）；专服 `-- --server`；自动连 `-- --connect ip`。
- 测试：双客户端端到端 12 断言（连接/预测/收敛/傀儡同步）。

## Phase 2-4 验收指引

1. **靶场**（编辑器打开 `scenes/test_range.tscn` 按 F6）：单点首发准度、压枪 30 发弹道形状（重点校准 `ak47.tres` 的 spray_pattern）、移动/跳跃扩散惩罚、蹲射收益、换弹节奏。
2. **dust2 单机**（F5）：新光照观感与帧率（SDFGI 重可关）；边跑图边射击试 tracer/弹孔。
3. **联机**（`scenes/dust2_mp.tscn` F6）：本机开两个实例——一个点"做主机"，另一个"加入 127.0.0.1"。重点：**联机下连跳/air strafe 手感是否与单机零差别**（预测同路径，理论上无差别）；第二人画面移动是否平滑；互射掉血重生。
4. 专服压力：`godot --headless res://scenes/dust2_mp.tscn -- --server`，多客户端连入。
5. 已知留白（DECISIONS 有细节）：无 lag compensation、无正式 hitbox 分区、防作弊最低限度、参数锁定等你执行。

---

---

# Phase 1 — 移动手感打磨（2026-06-12）

## P1-1 蹲参数 + duck 输入 ✅
- `MovementParams` 新增蹲组参数（全部 HL SDK 常量，注释标明出处）+ `duck` 键（Ctrl）。

## P1-2 duck + duck-jump ✅ [FEEL]
- 地面蹲 0.4s 过渡（眼高随进度下移，结束切 hull 72→36）；空中蹲**瞬时 + 脚抬 18** = duck-jump（脚部顶点 45→61.7，可上 64 箱）。
- 站起空间检测（低顶卡蹲、每 tick 重试）；完全蹲下 wishspeed×0.333。
- HUD 加 [蹲] 标记。

## P1-3 台阶视角平滑 ✅ [FEEL]
- 上/下台阶的垂直跳变转为相机偏移，150 u/s 衰减（HL V_CalcRefdef），纯视角层不碰物理。

## P1-4 surf 验证 ✅ [FEEL]
- **结论：Phase 0 物理天然支持 surf，零代码改动。**自由滑 0.6s 加速到 415.7；压坡骑面可爬升。
- 新增 `scenes/test_surf.tscn`（60° 坡练习图）+ `tests/test_surf.gd`（8 断言）。

## P1-5 回归与文档 ✅（本 commit）
- 单元 30 + 集成 16 + surf 8 = **54 断言全过**，游戏无头跑 300 帧无报错。

## Phase 1 验收指引（增量）
1. **蹲**：Ctrl 蹲走（HUD 应 ~106.6）、蹲下急停、蹲眼高是否对（30）。
2. **duck-jump**：A 点箱堆跳 64 箱（起跳后空中按 Ctrl）；时机窗口手感。
3. **卡蹲**：蹲进低处（自建或测试图）松 Ctrl 不应弹起穿模。
4. **楼梯**：B 隧道台阶、猫道台阶、B plat 楼梯连续上下——镜头应平滑不顿挫（不对就调 `step_smooth_speed`）。
5. **surf**：运行 `scenes/test_surf.tscn`（编辑器里打开该场景按 F6，或临时改主场景）：平台左侧下坡，按 D 压坡，鼠标顺坡转向。自由滑应持续加速，压坡能骑面。
6. 参数全在 `movement_params.tres`，满意后由你**锁定**（建议打 tag `movement-params-v1`）。

> 未做（按约定）：Shift 走路键、连跳上限逻辑、参数锁定。Phase 2 未动。

---

# Phase 0 进度日志（已验收）

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
