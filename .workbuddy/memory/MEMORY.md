# 《勇者牌战》项目笔记

## 项目概况
- Godot 4 日式卡通Roguelike卡牌博弈RPG
- 核心玩法：基于21点的攻防倍率对战
- 开发状态：全部核心系统+UI流程完成（地图v3分支路线图）

## 文件清单
```
scripts/core/      card_data.gd, deck.gd, hand_evaluator.gd, stance_data.gd,
                   battle_manager.gd, roguelike_map.gd, progression_system.gd,
                   combat_status.gd, enemy_mechanics.gd, save_system.gd
scripts/autoload/  event_bus.gd, game_state.gd
scripts/resources/ character_data.gd, skill_executor.gd, enemy_data.gd,
                   enemy_database.gd, trump_card_data.gd, trump_card_database.gd,
                   battle_item_data.gd, item_database.gd
scenes/main/      main_menu.gd, main_menu.tscn
scenes/ui/        character_select.gd/.tscn, character_cultivate.gd/.tscn
scenes/battle/     battle_scene.gd, battle_scene.tscn
scenes/map/        map_scene.gd, map_scene.tscn
resources/characters/ swordsman_rein.tres, mage_lilia.tres, thief_sid.tres, priest_erin.tres
```

## 核心架构
- 逻辑层: RefCounted 类（可单独测试）
- 服务层: Autoload 信号总线 + 游戏状态 + 存档系统
- 数据层: Resource 资源文件（Godot编辑器可编辑）
- UI层: Control 场景 + 信号驱动
- 流程: 主菜单 → 角色选择 → 角色养成 → 地图(分支路线v3, DAG) → 战斗 → 地图(下一层) → 循环

## 角色设计（已实现）
| 角色 | 类型 | HP | 被动 | 技能1(CD) | 技能2(CD) |
|------|------|-----|------|-----------|-----------|
| 剑士·雷恩 | 平衡 | 40 | 钢铁意志(开战+2盾) | 斩击预判(2)看暗牌 | 剑气护体(3)失败减伤 |
| 法师·莉莉娅 | 进攻 | 35 | 魔力涌动(3局小火球) | 火焰置换(2)换牌 | 诅咒爆牌(3)强抽 |
| 盗贼·希德 | 技巧 | 35 | 敏锐直觉(每局看顶牌) | 顺手牵羊(4)偷牌 | 烟雾弹(3)沉默 |
| 牧师·艾琳 | 防御 | 45 | 神圣祝福(赢局回血) | 治愈之光(4)回血 | 圣光庇护(5)免疫 |

## 已知限制
- 分牌(SPLIT)功能仅预留接口，未实现
- ~~地图UI~~ ✅ v3 分支路线图（2026-07-28，杀戮尖塔风格DAG，6种节点类型）
- 商店UI、休息点UI需完善（基础逻辑已有）
- 王牌的实际对战集成效果需要逐张实现
- 多结局条件检测未实现
- Boss的boss_custom_rule（软17变种等）未接入dealer_play
- 战斗场景中技能按钮为动态创建，需测试验证
- 地图→战斗的敌人数据传递链路需端到端测试
- 地图路线生成算法可能产生交叉线（视觉上可接受）

## 战斗参数（2026-07-28更新）
- MAX_PLAYER_CARDS = 5（初始2张+最多要3张）
- MAX_DEALER_CARDS = 5
- 基础伤害 = 6.0
- 庄家停牌线 = 16
- 点数差伤害倍率 = 0.18
- 王牌手牌上限 = 3张（总携带6张）
- 开局黑杰克不速通（进入正常回合）
- 战败返回主菜单 + 经验/星尘结算
- 胜利掉落：道具70% + 王牌50%

## GDScript 2.0 类型安全规则（必须遵守）
1. `min/max/abs/clamp/lerp` 必须用类型化版本: `minf/mini/maxf/maxi/absf/absi/clampf/clampi/lerpf`
2. `pop_back/pop_front` 返回Variant，必须显式类型: `var x: T = arr.pop_back()`
3. 三元表达式 `:=` 推断Variant，必须显式类型: `var x: String = a if b else c`
4. 绝对不要用Object内置方法名定义函数: `get_name/get_path/to_string/_init`等
5. 未使用参数加 `_` 前缀消除警告
6. 从未类型化Array取元素必须 `as Type` + 显式类型声明

## 下一优先级
1. ~~实现地图UI~~ ✅ v1 (2026-07-27)
2. ~~地图节点选择~~ ✅ v2 三选一 → **v3 分支路线图**（2026-07-28）
3. 商店/休息点UI完善（节点功能实现）
4. 王牌逐张接入战斗效果（目前仅基础攻防牌生效）
5. Boss特殊规则接入dealer_play
6. 存档/读档文件I/O实现
7. 多结局条件检测
