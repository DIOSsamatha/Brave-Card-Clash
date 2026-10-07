## 角色技能执行器
## 管理技能冷却、效果触发，对接BattleManager的Hook系统
class_name SkillExecutor
extends RefCounted

var char_data: CharacterData
var skill_level: CharacterData.SkillLevel = CharacterData.SkillLevel.LV1
var skill1_current_cooldown: int = 0
var skill2_current_cooldown: int = 0
var active_buffs: Array[SkillResult] = []
var passive_counter: int = 0  # 被动触发计数器（如每3局）

func _init(p_char_data: CharacterData, p_level: int) -> void:
	char_data = p_char_data
	skill_level = CharacterData.level_to_skill_level(p_level)

## 使用技能1（返回null表示冷却中）
func use_skill1() -> SkillResult:
	if skill1_current_cooldown > 0:
		return null
	skill1_current_cooldown = char_data.skill1_cooldown
	return _get_skill1_effect()

## 使用技能2（返回null表示冷却中）
func use_skill2() -> SkillResult:
	if skill2_current_cooldown > 0:
		return null
	skill2_current_cooldown = char_data.skill2_cooldown
	return _get_skill2_effect()

## 小局结束后减少冷却
func tick_cooldowns() -> void:
	if skill1_current_cooldown > 0:
		skill1_current_cooldown -= 1
	if skill2_current_cooldown > 0:
		skill2_current_cooldown -= 1
	passive_counter += 1

	# 清除过期buff
	var remaining: Array[SkillResult] = []
	for buff in active_buffs:
		buff.duration -= 1
		if buff.duration > 0:
			remaining.append(buff)
	active_buffs = remaining

## 重置所有冷却（新战斗开始时调用）
func reset_cooldowns() -> void:
	skill1_current_cooldown = 0
	skill2_current_cooldown = 0
	passive_counter = 0
	active_buffs.clear()

## 触发被动效果（根据passive_trigger类型在对应时机调用）
## 返回SkillResult数组（可能同时触发多个效果）
func trigger_passive(context: String) -> Array[SkillResult]:
	var results: Array[SkillResult] = []
	match char_data.passive_trigger:
		"battle_start":
			if context == "battle_start":
				results.append(_get_passive_effect())
		"every_3_rounds":
			if context == "round_end" and passive_counter > 0 and (passive_counter % 3) == 0:
				results.append(_get_passive_effect())
		"each_round":
			if context == "round_start":
				results.append(_get_passive_effect())
		"on_win":
			if context == "round_win":
				results.append(_get_passive_effect())
	return results

## 获取被动描述
func get_passive_description() -> String:
	return char_data.passive_desc

## 获取技能描述
func get_skill1_description() -> String:
	return char_data.get_skill1_desc(skill_level)

func get_skill2_description() -> String:
	return char_data.get_skill2_desc(skill_level)

# === 技能效果分发 ===

func _get_skill1_effect() -> SkillResult:
	match char_data.class_type:
		CharacterData.ClassType.SWORDSMAN:
			return _swordsman_skill1()
		CharacterData.ClassType.MAGE:
			return _mage_skill1()
		CharacterData.ClassType.THIEF:
			return _thief_skill1()
		CharacterData.ClassType.PRIEST:
			return _priest_skill1()
	return SkillResult.new("none", 0.0)

func _get_skill2_effect() -> SkillResult:
	match char_data.class_type:
		CharacterData.ClassType.SWORDSMAN:
			return _swordsman_skill2()
		CharacterData.ClassType.MAGE:
			return _mage_skill2()
		CharacterData.ClassType.THIEF:
			return _thief_skill2()
		CharacterData.ClassType.PRIEST:
			return _priest_skill2()
	return SkillResult.new("none", 0.0)

func _get_passive_effect() -> SkillResult:
	match char_data.class_type:
		CharacterData.ClassType.SWORDSMAN:
			return _swordsman_passive()
		CharacterData.ClassType.MAGE:
			return _mage_passive()
		CharacterData.ClassType.THIEF:
			return _thief_passive()
		CharacterData.ClassType.PRIEST:
			return _priest_passive()
	return SkillResult.new("none", 0.0)

# ============================================================
# 剑士·雷恩（平衡型）HP:40
# 被动「钢铁意志」：每场战斗开始获得2点护盾
# 技能1「斩击预判」：查看敌方1张暗牌（冷却2回合）
# 技能2「剑气护体」：本局失败时减免2点伤害（冷却3回合）
# ============================================================

func _swordsman_passive() -> SkillResult:
	return SkillResult.new("shield", 2.0, 0, "钢铁意志：获得2点护盾")

func _swordsman_skill1() -> SkillResult:
	# 查看敌方暗牌 — 返回peek类型，BattleManager处理亮牌逻辑
	return SkillResult.new("peek_enemy_card", 1.0, 0, "斩击预判：查看敌方1张暗牌")

func _swordsman_skill2() -> SkillResult:
	var reduce := 2.0
	match skill_level:
		CharacterData.SkillLevel.LV2: reduce = 3.0
		CharacterData.SkillLevel.LV3: reduce = 4.0
	return SkillResult.new("fail_damage_reduce", reduce, 1, "剑气护体：本局失败时减免%d点伤害" % int(reduce))

# ============================================================
# 法师·莉莉娅（进攻型）HP:35
# 被动「魔力涌动」：每3局获得1张"小火球"魔法卡（造成2点强制伤害）
# 技能1「火焰置换」：自己1张手牌与牌堆顶交换（冷却2回合）
# 技能2「诅咒爆牌」：强制庄家多抽1张（冷却3回合）
# ============================================================

func _mage_passive() -> SkillResult:
	# 每3局获得小火球卡
	var dmg := 2.0
	match skill_level:
		CharacterData.SkillLevel.LV2: dmg = 3.0
		CharacterData.SkillLevel.LV3: dmg = 4.0
	return SkillResult.new("fireball_card", dmg, 0, "魔力涌动：获得小火球卡（%d点强制伤害）" % int(dmg))

func _mage_skill1() -> SkillResult:
	# 与牌堆顶交换一张手牌
	return SkillResult.new("swap_deck_top", 1.0, 0, "火焰置换：选择1张手牌与牌堆顶交换")

func _mage_skill2() -> SkillResult:
	var extra_draw := 1
	match skill_level:
		CharacterData.SkillLevel.LV2: extra_draw = 2
		CharacterData.SkillLevel.LV3: extra_draw = 2
	return SkillResult.new("force_dealer_draw", float(extra_draw), 0, "诅咒爆牌：强制庄家多抽%d张" % extra_draw)

# ============================================================
# 盗贼·希德（技巧型）HP:35
# 被动「敏锐直觉」：每局看到牌堆顶部1张牌
# 技能1「顺手牵羊」：随机偷取庄家1张手牌（冷却4回合）
# 技能2「烟雾弹」：庄家下回合无法使用技能（冷却3回合）
# ============================================================

func _thief_passive() -> SkillResult:
	return SkillResult.new("peek_deck_top", 1.0, 0, "敏锐直觉：看到牌堆顶1张牌")

func _thief_skill1() -> SkillResult:
	return SkillResult.new("steal_dealer_card", 1.0, 0, "顺手牵羊：偷取庄家1张手牌")

func _thief_skill2() -> SkillResult:
	var dur := 1
	match skill_level:
		CharacterData.SkillLevel.LV2: dur = 2
		CharacterData.SkillLevel.LV3: dur = 2
	return SkillResult.new("silence_enemy", 1.0, dur, "烟雾弹：庄家%d回合无法使用技能" % dur)

# ============================================================
# 牧师·艾琳（防御型）HP:45
# 被动「神圣祝福」：每赢1局恢复1点生命值
# 技能1「治愈之光」：恢复4点生命值（冷却4回合）
# 技能2「圣光庇护」：免疫本局所有伤害与负面效果（冷却5回合）
# ============================================================

func _priest_passive() -> SkillResult:
	var heal := 1.0
	match skill_level:
		CharacterData.SkillLevel.LV2: heal = 2.0
		CharacterData.SkillLevel.LV3: heal = 2.0
	return SkillResult.new("heal_on_win", heal, 0, "神圣祝福：恢复%d点生命" % int(heal))

func _priest_skill1() -> SkillResult:
	var heal := 4.0
	match skill_level:
		CharacterData.SkillLevel.LV2: heal = 6.0
		CharacterData.SkillLevel.LV3: heal = 8.0
	return SkillResult.new("heal", heal, 0, "治愈之光：恢复%d点生命" % int(heal))

func _priest_skill2() -> SkillResult:
	var dur := 1
	match skill_level:
		CharacterData.SkillLevel.LV2: dur = 1
		CharacterData.SkillLevel.LV3: dur = 1
	return SkillResult.new("invincible", 1.0, dur, "圣光庇护：免疫本局所有伤害与负面")
