## 角色数据资源
## 定义勇者的属性、被动、主动技能和进化路线
class_name CharacterData
extends Resource

## 技能等级
enum SkillLevel { LV1 = 1, LV2 = 2, LV3 = 3 }

## 角色职业类型
enum ClassType {
	SWORDSMAN,  # 剑士 — 平衡型
	MAGE,       # 法师 — 进攻型
	THIEF,      # 盗贼 — 技巧型
	PRIEST,     # 牧师 — 防御型
}

## 角色基本信息
@export var char_name: String = ""
@export var class_type: ClassType = ClassType.SWORDSMAN
@export var portrait: String = ""  # 头像路径
@export var description: String = ""
@export var max_health: float = 40.0
@export var base_damage: float = 2.0

## 被动技能描述（战斗开始/每局/每赢局等自动触发）
@export var passive_name: String = ""
@export var passive_desc: String = ""
@export var passive_trigger: String = "battle_start"  # battle_start / every_3_rounds / each_round / on_win

## 主动技能1
@export var skill1_name: String = ""
@export var skill1_cooldown: int = 3  # 冷却小局数
@export var skill1_desc_lv1: String = ""
@export var skill1_desc_lv2: String = ""
@export var skill1_desc_lv3: String = ""

## 主动技能2
@export var skill2_name: String = ""
@export var skill2_cooldown: int = 5
@export var skill2_desc_lv1: String = ""
@export var skill2_desc_lv2: String = ""
@export var skill2_desc_lv3: String = ""

## 进化描述（Lv10/Lv20/Lv30质变）
@export var evolution_desc_lv10: String = ""
@export var evolution_desc_lv20: String = ""
@export var evolution_desc_lv30: String = ""

## 获取指定等级的技能描述
func get_skill1_desc(level: SkillLevel) -> String:
	match level:
		SkillLevel.LV1: return skill1_desc_lv1
		SkillLevel.LV2: return skill1_desc_lv2
		SkillLevel.LV3: return skill1_desc_lv3
	return ""

func get_skill2_desc(level: SkillLevel) -> String:
	match level:
		SkillLevel.LV1: return skill2_desc_lv1
		SkillLevel.LV2: return skill2_desc_lv2
		SkillLevel.LV3: return skill2_desc_lv3
	return ""

## 获取角色等级对应的技能等级
static func level_to_skill_level(level: int) -> SkillLevel:
	if level >= 20:
		return SkillLevel.LV3
	elif level >= 10:
		return SkillLevel.LV2
	return SkillLevel.LV1

## 获取角色等级对应的生命加成（改用ProgressionSystem精确查表）
static func get_health_bonus(level: int) -> float:
	return float(ProgressionSystem.get_hp_for_level(level)) - 40.0

## 获取角色等级对应的基础伤害加成
static func get_damage_bonus(level: int) -> float:
	# 线性成长：每级+0.12基础伤害（Lv30约+3.6，控制后期输出膨胀）
	return float(level) * 0.12

## 获取该角色的总生命值（含等级加成，查表）
## 以角色 .tres 基础生命为种子，叠加等级成长曲线（保留职业差异）
func get_total_health(char_level: int) -> float:
	return max_health + (float(ProgressionSystem.get_hp_for_level(char_level)) - 40.0)

## 获取该角色的总基础伤害（含等级加成）
func get_total_damage(char_level: int) -> float:
	return base_damage + get_damage_bonus(char_level)
