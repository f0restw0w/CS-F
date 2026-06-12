# ASSET_CREDITS.md — 外部资产登记

> 按 `docs/ART_DUST2.md` 约定：每个外部美术/音频资产登记来源与授权，作为"资产干净"的凭证。
> 任何无法登记清楚来源/授权的资产，不准进项目。

## 纹理（PBR，1K JPG：Color / NormalGL / Roughness）

| 资产 | 类型 | 用途 | 来源 | 授权 | 链接 |
|------|------|------|------|------|------|
| Bricks084 | PBR 纹理 | 砂岩砖墙（mat_wall：建筑外墙/通道墙面） | ambientCG | CC0 1.0 | https://ambientcg.com/view?id=Bricks084 |
| Ground054 | PBR 纹理 | 沙土地面（mat_floor：户外开阔地/道路） | ambientCG | CC0 1.0 | https://ambientcg.com/view?id=Ground054 |
| Planks037A | PBR 纹理 | 木箱（mat_crate：各处掩体箱子） | ambientCG | CC0 1.0 | https://ambientcg.com/view?id=Planks037A |
| Concrete034 | PBR 纹理 | 混凝土（mat_raised：猫道/平台/台阶） | ambientCG | CC0 1.0 | https://ambientcg.com/view?id=Concrete034 |

ambientCG 全站素材为 CC0（Creative Commons Zero）：可商用、可修改、免署名。
下载方式：官方下载接口 `https://ambientcg.com/get?file=<ID>_1K-JPG.zip`（2026-06-12 获取）。

## HDRI

| 资产 | 类型 | 用途 | 来源 | 作者 | 授权 | 链接 |
|------|------|------|------|------|------|------|
| syferfontein_1d_clear_2k.hdr | HDRI 全景 | dust2 天空与环境光（晴天强日照） | Poly Haven | Greg Zaal | CC0 | https://polyhaven.com/a/syferfontein_1d_clear |

## 程序生成（非外部资产，登记备查）

| 资产 | 说明 |
|------|------|
| 占位枪声 | 代码运行时生成（白噪声+低频衰减，`hitscan_weapon.gd::_make_shot_sound`），无外部来源 |
| 灰盒几何/程序噪声材质 | Godot 原生几何与 FastNoiseLite，无外部来源 |

## 自检声明

- 本项目**不含**任何 Valve 资产（无 .bsp/贴图/模型/音效的提取、转换或临摹）。
- 所有纹理来自上表所列通用纹理库，与原版 dust2 贴图并排对比均为明显不同的独立作品。
- 引入新资产前必须在本文件登记；来源拿不准的记 `DECISIONS_FOR_REVIEW.md` 待负责人判断，不先用。
