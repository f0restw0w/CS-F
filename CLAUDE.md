# CLAUDE.md

> 本文件是 Claude Code 的项目级指令。每次会话自动加载。改动前先读 `docs/` 下相关文档。

## 项目一句话

用 Godot 4 重建一款 **第一人称射击游戏**，核心目标是**精确复刻 CS 1.6 的移动手感与身法**（bunnyhop、air strafe、surf 等），同时使用现代画质（PBR 材质、现代光照）。

**判定项目成败的唯一硬标准：移动手感是否"对"。** 项目负责人是前 WCG CS 1.6 全国前八选手，对手感有专业级判断力。手感不对 = 失败，画面再好也没用。

## 当前阶段

**Phase 0 已验收；Phase 1-4 + dust2 几何细化 + 合法美术（CC0）已完成，等负责人一次性验收。** 进度见 `PROGRESS.md`，待复核决策见 `DECISIONS_FOR_REVIEW.md`，外部资产登记见 `ASSET_CREDITS.md`。**待负责人**：手感参数锁定、dust2 几何记忆校准后打 `dust2-geometry-v1` tag。验收通过前不开新功能。

## 绝对原则（NON-NEGOTIABLE）

1. **手感优先于一切。** 任何改动如果可能影响移动手感，必须在 commit message 里标注 `[FEEL]` 并说明对物理的影响。
2. **物理公式必须可溯源。** 每个移动相关常量（`sv_accelerate`、`sv_airaccelerate`、`sv_friction`、`sv_maxspeed` 等）都要在代码注释里写明它对应 GoldSrc 的哪个 cvar 及默认值。见 `docs/MOVEMENT_SPEC.md`。
3. **物理与帧率解耦。** 移动逻辑全部放在 `_physics_process`（固定步长），**绝不**放在 `_process`。1.6 的手感对 tick 敏感，必须用固定步长模拟。
4. **不要"优化"成 Godot 默认的 CharacterBody3D 行为。** Godot 自带的 `move_and_slide` 加速/摩擦模型与 GoldSrc **不同**。我们要的是手动实现 GoldSrc 的 accelerate/airaccelerate，不是用引擎默认值凑合。
5. **可调参数全部暴露。** 所有物理常量做成 `@export` 变量或资源文件，方便负责人实时调试找手感。
6. **自主模式下遇到不确定一律记录不卡住。** 拿不准的决策记入 `DECISIONS_FOR_REVIEW.md`，选有依据的默认值继续推进。

## 技术栈

- **引擎**: Godot 4.x（最新稳定版）
- **语言**: GDScript 起步（原型阶段优先开发速度）；如遇性能瓶颈再考虑 C# 重写热点
- **物理**: 自定义 `CharacterBody3D` 控制器，手动实现 GoldSrc 移动数学，**不依赖** Godot 内置加速度模型
- **版本控制**: Git

## 仓库结构

```
cs16-revival/
├── CLAUDE.md                  # 本文件
├── README.md                  # 人类看的项目说明
├── docs/
│   ├── VISION.md             # 产品愿景：要复刻 1.6 的哪些体验（统领）
│   ├── MOVEMENT_SPEC.md       # 1.6 移动物理规范（最重要的技术文档）
│   ├── MOVEMENT_PHASE1.md    # Phase 1 移动手感规格（蹲/surf/台阶）
│   ├── MAP_DUST2.md           # de_dust2 灰盒重建布局规格（几何还原）
│   ├── ART_DUST2.md          # de_dust2 美术方向（合法纹理与视觉氛围）
│   ├── BUILD_PLAN.md          # 自主模式分步开工指令（先读这个）
│   ├── FUTURE_PHASES.md      # 后续 Phase 预规划（武器/音效/联机要点）
│   ├── GLOSSARY.md           # 1.6 名词与数值速查
│   ├── ARCHITECTURE.md        # 代码架构与目录约定
│   ├── ROADMAP.md             # 分阶段路线图
│   └── TESTING.md             # 手感验证清单与测试方法
├── project.godot              # Godot 项目文件（由 Godot 生成）
├── scenes/                    # .tscn 场景
│   ├── dust2.tscn             # 灰盒 dust2 总装场景
│   └── regions/               # 各分区独立场景（mid/long_a/...）
├── scripts/                   # .gd 脚本
│   └── player/                # 玩家控制器、移动状态机
├── resources/                 # 可调参数资源（.tres）
└── assets/                    # 美术/音频（原型阶段用占位资源）
```

## 工作流约定

- **当前为自主（bypass permission）模式。** 按 `docs/BUILD_PLAN.md` 自主推进 Phase 0，不要中途停下来问权限或确认。负责人做完后统一验收。
- **小步提交。** 每个 commit 只做一件事，尤其移动相关改动要可单独回滚。
- **改物理前先看 spec。** 动 `scripts/player/` 里任何东西前，先读 `docs/MOVEMENT_SPEC.md`。
- **拿不准时不要卡住。** 涉及手感参数取值、dust2 尺寸、公式歧义等主观/不确定问题：选一个有依据的默认值继续做，并记录到 `DECISIONS_FOR_REVIEW.md` 供负责人验收时复核。绝不停下来等回复。
- **占位资源够用就行。** 原型阶段不要在美术上花时间，灰盒（greybox）关卡 + 胶囊体玩家即可。
- **地图照 MAP_DUST2.md 搭。** 灰盒 dust2 只复刻几何，绝不导入 Valve 资产（地图文件/贴图/模型/音效），私下玩也算侵权。尺寸是近似起点，留给负责人按记忆校准。

## Claude Code 能做 / 不能做

**能做：** 移动控制器、移动状态机、物理数学、武器系统逻辑、命中判定、网络同步逻辑、UI、调试工具、单元测试。

**不能做（需要负责人外部提供）：** 3D 建模、贴图、音效、关卡美术资产。这些用占位资源顶着，后期替换。

## 启动指令

本项目运行在自主（bypass permission）模式。开工时直接执行 `docs/BUILD_PLAN.md` 的 Phase 0 全部步骤，无需逐步征求许可：先读 `CLAUDE.md` → `docs/BUILD_PLAN.md` → `docs/MOVEMENT_SPEC.md` → `docs/MAP_DUST2.md`，然后按 BUILD_PLAN 的 Step 1→7 自主推进。全程把不确定的决策记入 `DECISIONS_FOR_REVIEW.md`，进度写入 `PROGRESS.md`。Phase 0 完成即停，等负责人验收。
