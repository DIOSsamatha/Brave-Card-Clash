# 《勇者牌战》全局数值平衡重做

## 目标
将数值体系对标市场同类 Roguelike（如杀戮尖塔），解决"玩家输出不随等级成长 + 怪血/Boss过高"导致的数值泥潭，使难度随层数、节点数、角色成长合理缩放。

## 核心病根
- 玩家 `base_damage=2.0` 写死，等级伤害公式 `level/10*0.1 + level*0.02` 增长几乎为零（Lv30 仅 +0.9）→ 每胜只造成 ~3.4 伤害
- 怪血 18~70、Boss 30~70 需十几回合磨死；怪每局打 5~7 点，玩家 40 血几下就死

## 改动（8 处，均已落地）

| 系统 | 文件 | 调整 |
|------|------|------|
| 角色基础伤害 | `resources/characters/*.tres` | 剑士5.0 / 法师6.0 / 盗贼5.0 / 牧师4.0（原 2.0） |
| 等级伤害公式 | `scripts/resources/character_data.gd` | `get_damage_bonus` = `float(level)*0.22`（Lv30 法师≈12.6） |
| 等级HP曲线 | `scripts/core/progression_system.gd` + `character_data.gd` | Lv1=45 → +3/级 → Lv30=132；以 `.tres` 基础血为种子保留职业差异 |
| 怪物/Boss曲线 | `scripts/resources/enemy_database.gd` | 普通 18→40、精英 38→72、Boss 40→120（按层0~5平滑递增） |
| 节点深度缩放 | `scripts/autoload/game_state.gd` | `setup_enemy_from_data` 按 `map_visited.size()` 最多 +50%（`duplicate()` 防污染共享库） |
| 敌人机制 | `scripts/core/enemy_mechanics.gd` | 恶魔猎犬加成封顶+4；棱镜术士陷阱概率 0.4→0.25；馆长之魂每局封顶+4 |
| 王牌治疗 | `trump_card_database.gd` + `battle_scene.gd` | **修复治疗药水bug**（DEFENSE类回血误写在SPECIAL分支从不触发→移到DEFENSE分支）+ 5→12；吸血宝石 3→6；生命结晶文本 10→18 |
| 星尘经济 | `scenes/battle/battle_scene.gd` | 胜利 `maxi(10, round*5+10)`、战败 `maxi(4, round*3+4)`；F6 fallback `setup_player(45,5)` |

## 平衡验证（目标回合模型）
- 剑士 Lv1 平衡胜 vs 层1精英(40血) ≈ 5 胜
- 法师 Lv10 激进胜 vs 层2精英(50血) ≈ 2 胜
- 牧师 Lv30 平衡胜 vs 终boss黑桃魔王(120血) ≈ 7 胜；激进姿态受击 ×1.5 换速杀 = 风险/收益合理

## 已知后续（未做，避免范围蔓延）
- **生命结晶**（局间恢复）实际效果尚未接入战斗/地图流程（文本已更新，逻辑待接）
- 王牌逐张接入战斗效果、Boss `boss_custom_rule` 接入 `dealer_play` 仍为既有 TODO
- 伤害公式 0.18 倍率未动（当前数值已自洽，无需调整）
