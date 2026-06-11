# CS 1.6 Revival （暂定名）

用 Godot 4 重建 CS 1.6 的移动手感，配现代画质。

## 这是什么

一款第一人称射击游戏，目标不是"又一个 CS 克隆"，而是**精确复刻 CS 1.6 的身法与移动手感**（bunnyhop、air strafe、surf），同时用现代渲染解决 1.6 画质老旧的问题。CS2 改了 Source 2 的空气加速度模型，削弱了身法手感——本项目要回到 GoldSrc 的原始物理。

## 为什么能做对手感

主创是前 WCG CS 1.6 选手（全国前八），对移动手感有专业级判断力。很多复刻项目失败在做的人感觉不出哪里不对——这里不会。

## 现状

Phase 0：移动控制器原型。目标是先做出一个被主创认可的 1.6 手感，再扩展武器、联机等。详见 `docs/ROADMAP.md`。

## 给开发者 / Claude Code

- 项目指令见 `CLAUDE.md`
- 移动物理规范见 `docs/MOVEMENT_SPEC.md`（最重要）
- 架构见 `docs/ARCHITECTURE.md`
- 路线图见 `docs/ROADMAP.md`
- 手感验证见 `docs/TESTING.md`

## 技术栈

Godot 4 · GDScript · 自定义 GoldSrc 风格移动控制器（不使用引擎默认加速度模型）

## 许可

待定。注意：不使用任何 Valve 的美术/音频/代码资产，所有资产为原创或授权。
