## 局外永久成长系统
## 管理角色等级、星尘货币、全局升级、存档
## 30级精确经验表 + 里程碑奖励（难度/卡槽/技能等级）
class_name ProgressionSystem
extends RefCounted

# ============================================================
#  30级精确数据表（来自策划案）
# ============================================================

## 累积经验表：LEVEL_XP_TABLE[lv] = 达到lv所需总经验
## 索引0 unused, 索引1~30 对应等级1~30
const LEVEL_XP_TABLE: Array[int] = [
	0,      # Lv1  (初始)
	0,      # Lv1
	300,    # Lv2
	600,    # Lv3
	1000,   # Lv4
	1500,   # Lv5
	2000,   # Lv6
	2600,   # Lv7
	3300,   # Lv8
	4100,   # Lv9
	5000,   # Lv10
	6000,   # Lv11
	7100,   # Lv12
	8300,   # Lv13
	9600,   # Lv14
	11000,  # Lv15
	12500,  # Lv16
	14100,  # Lv17
	15800,  # Lv18
	17600,  # Lv19
	19500,  # Lv20
	21500,  # Lv21
	23600,  # Lv22
	25800,  # Lv23
	28100,  # Lv24
	30500,  # Lv25
	33000,  # Lv26
	35600,  # Lv27
	38300,  # Lv28
	41100,  # Lv29
	44000,  # Lv30 (满级)
]

## 每级最大生命值：LEVEL_MAX_HP[lv] = 该等级的基础HP上限
const LEVEL_MAX_HP: Array[int] = [
	0,   # unused
	45,  # Lv1
	48,  # Lv2
	51,  # Lv3
	54,  # Lv4
	57,  # Lv5
	60,  # Lv6
	63,  # Lv7
	66,  # Lv8
	69,  # Lv9
	72,  # Lv10
	75,  # Lv11
	78,  # Lv12
	81,  # Lv13
	84,  # Lv14
	87,  # Lv15
	90,  # Lv16
	93,  # Lv17
	96,  # Lv18
	99,  # Lv19
	102,  # Lv20
	105,  # Lv21
	108,  # Lv22
	111,  # Lv23
	114,  # Lv24
	117,  # Lv25
	120,  # Lv26
	123,  # Lv27
	126,  # Lv28
	129,  # Lv29
	132,  # Lv30
]

## 里程碑奖励类型
enum Milestone {
	NONE = 0,
	UNLOCK_NORMAL_DIFFICULTY,     # Lv5: 解锁普通难度
	UNLOCK_SHOP_BASIC,            # Lv5: 商店基础商品
	UNLOCK_HARD_DIFFICULTY,       # Lv10: 解锁困难难度
	UNLOCK_TRUMP_SLOT_2,          # Lv10: 第2王牌槽
	SKILL_UPGRADE_LV2,            # Lv10: 技能升级至Lv.2
	UNLOCK_EQUIPMENT,             # Lv15: 解锁装备系统
	UNLOCK_SHOP_RARE,             # Lv15: 商店稀有商品
	UNLOCK_NIGHTMARE_DIFFICULTY,  # Lv20: 解锁噩梦难度
	UNLOCK_TRUMP_SLOT_3,          # Lv20: 第3王牌槽
	SKILL_UPGRADE_LV3,            # Lv20: 技能升级至Lv.3
	UNLOCK_HELL_DIFFICULTY,       # Lv25: 解锁地狱难度
	UNLOCK_SHOP_EPIC,             # Lv25: 商店史诗商品
	MAX_LEVEL,                    # Lv30: 满级成就
}

## 里程碑奖励表：KEY = 等级, VALUE = 奖励列表 Array[Milestone]
const LEVEL_MILESTONES: Dictionary = {
	5:  [Milestone.UNLOCK_NORMAL_DIFFICULTY, Milestone.UNLOCK_SHOP_BASIC],
	10: [Milestone.UNLOCK_HARD_DIFFICULTY, Milestone.UNLOCK_TRUMP_SLOT_2, Milestone.SKILL_UPGRADE_LV2],
	15: [Milestone.UNLOCK_EQUIPMENT, Milestone.UNLOCK_SHOP_RARE],
	20: [Milestone.UNLOCK_NIGHTMARE_DIFFICULTY, Milestone.UNLOCK_TRUMP_SLOT_3, Milestone.SKILL_UPGRADE_LV3],
	25: [Milestone.UNLOCK_HELL_DIFFICULTY, Milestone.UNLOCK_SHOP_EPIC],
	30: [Milestone.MAX_LEVEL],
}

## 里程碑显示名
static func get_milestone_name(m: Milestone) -> String:
	match m:
		Milestone.UNLOCK_NORMAL_DIFFICULTY: return "解锁普通难度"
		Milestone.UNLOCK_SHOP_BASIC: return "商店基础商品解锁"
		Milestone.UNLOCK_HARD_DIFFICULTY: return "解锁困难难度"
		Milestone.UNLOCK_TRUMP_SLOT_2: return "第2王牌槽解锁"
		Milestone.SKILL_UPGRADE_LV2: return "技能升级至Lv.2"
		Milestone.UNLOCK_EQUIPMENT: return "解锁装备系统"
		Milestone.UNLOCK_SHOP_RARE: return "商店稀有商品解锁"
		Milestone.UNLOCK_NIGHTMARE_DIFFICULTY: return "解锁噩梦难度"
		Milestone.UNLOCK_TRUMP_SLOT_3: return "第3王牌槽解锁"
		Milestone.SKILL_UPGRADE_LV3: return "技能升级至Lv.3"
		Milestone.UNLOCK_HELL_DIFFICULTY: return "解锁地狱难度"
		Milestone.UNLOCK_SHOP_EPIC: return "商店史诗商品解锁"
		Milestone.MAX_LEVEL: return "★ 满级达成！解锁全局终极成就 ★"
		_: return ""

const MAX_LEVEL: int = 30

## 全局升级ID枚举
enum UpgradeID {
	START_GOLD,         # 初始金币增加
	REST_HEAL_BONUS,    # 休息恢复提升
	SHOP_DISCOUNT,      # 商店折扣
	START_CARD_SLOTS,   # 初始王牌选择数+1
	START_ITEM_SLOTS,   # 初始道具携带数+1
	START_HP_BONUS,     # 英雄初始生命上限
	START_DAMAGE_BONUS, # 英雄初始基础伤害
	MAX_TRUMP_BAG,      # 王牌背包上限
	MAX_ITEM_BAG,       # 道具袋上限
	FLASK_CAPACITY,     # 血瓶携带上限（最多5瓶）
}

## 单个升级条目
class UpgradeEntry:
	var id: UpgradeID
	var name: String
	var description: String
	var max_level: int
	var cost_per_level: Array[int] = []  # 每级所需星尘
	var current_level: int = 0
	var effect_per_level: Array[float] = []  # 每级效果值

## 角色存档
class CharacterSave:
	var class_type: CharacterData.ClassType
	var level: int = 1
	var experience: int = 0
	var unlocked: bool = false
	var milestones_unlocked: Array[int] = []  # 已解锁的里程碑 Milestone 值

	## 距离下一级还需多少经验
	func exp_to_next() -> int:
		if level >= MAX_LEVEL:
			return 0
		return LEVEL_XP_TABLE[level + 1] - experience

	## 当前等级总经验进度（用于显示百分比）
	func exp_progress_ratio() -> float:
		if level >= MAX_LEVEL:
			return 1.0
		var prev_xp := LEVEL_XP_TABLE[level]
		var next_xp := LEVEL_XP_TABLE[level + 1]
		if next_xp <= prev_xp:
			return 1.0
		return float(experience - prev_xp) / float(next_xp - prev_xp)

	## 获取该等级对应的最大HP
	func get_max_hp() -> int:
		if level >= LEVEL_MAX_HP.size():
			return LEVEL_MAX_HP[LEVEL_MAX_HP.size() - 1]
		return LEVEL_MAX_HP[level]

	## 获取该等级对应的技能等级
	func get_skill_level() -> CharacterData.SkillLevel:
		return CharacterData.level_to_skill_level(level)

	## 检查某里程碑是否已解锁
	func has_milestone(m: Milestone) -> bool:
		return milestones_unlocked.has(int(m))

## 全局进度数据
var star_dust: int = 0           # 星尘货币
var characters: Array[CharacterSave] = []
var upgrades: Dictionary = {}    # UpgradeID -> UpgradeEntry
var trump_card_unlock: Dictionary = {}  # card_name -> bool
var difficulty_unlocked: Array[String] = []
var total_runs: int = 0
var total_wins: int = 0
var best_stage: int = 0          # 到达过的最高层数
var best_score: int = 0

func _init() -> void:
	_init_upgrades()
	_init_characters()

func _init_characters() -> void:
	characters.clear()
	for class_type in range(4):
		var save := CharacterSave.new()
		save.class_type = class_type as CharacterData.ClassType
		save.level = 1
		save.experience = 0
		save.unlocked = (class_type == 0)  # 剑士初始解锁
		characters.append(save)

	# 剑士默认解锁
	if characters.size() > 0:
		characters[0].unlocked = true

func _init_upgrades() -> void:
	upgrades.clear()

	upgrades[UpgradeID.START_GOLD] = _create_upgrade(
		UpgradeID.START_GOLD, "初始金币", "冒险开始时获得更多金币", 5,
		[20, 40, 80, 150, 300],
		[5.0, 10.0, 15.0, 20.0, 30.0]
	)

	upgrades[UpgradeID.REST_HEAL_BONUS] = _create_upgrade(
		UpgradeID.REST_HEAL_BONUS, "休息强化", "休息点回血提升", 5,
		[30, 60, 100, 150, 250],
		[0.05, 0.10, 0.15, 0.20, 0.30]
	)

	upgrades[UpgradeID.SHOP_DISCOUNT] = _create_upgrade(
		UpgradeID.SHOP_DISCOUNT, "商店折扣", "商店商品价格降低", 5,
		[25, 50, 100, 200, 400],
		[0.05, 0.10, 0.15, 0.20, 0.30]
	)

	upgrades[UpgradeID.START_CARD_SLOTS] = _create_upgrade(
		UpgradeID.START_CARD_SLOTS, "王牌格+1", "初始王牌选择数+1", 2,
		[100, 300],
		[1.0, 1.0]
	)

	upgrades[UpgradeID.START_ITEM_SLOTS] = _create_upgrade(
		UpgradeID.START_ITEM_SLOTS, "道具格+1", "初始道具携带数+1", 2,
		[80, 250],
		[1.0, 1.0]
	)

	upgrades[UpgradeID.START_HP_BONUS] = _create_upgrade(
		UpgradeID.START_HP_BONUS, "生命强化", "英雄初始生命上限+2", 5,
		[30, 60, 120, 200, 350],
		[2.0, 2.0, 2.0, 2.0, 2.0]
	)

	upgrades[UpgradeID.START_DAMAGE_BONUS] = _create_upgrade(
		UpgradeID.START_DAMAGE_BONUS, "攻击强化", "英雄初始基础伤害+0.2", 5,
		[40, 80, 150, 280, 500],
		[0.2, 0.2, 0.2, 0.2, 0.2]
	)

	upgrades[UpgradeID.MAX_TRUMP_BAG] = _create_upgrade(
		UpgradeID.MAX_TRUMP_BAG, "王牌背包+", "王牌背包上限+2", 5,
		[20, 50, 100, 200, 400],
		[2.0, 2.0, 2.0, 2.0, 2.0]
	)

	upgrades[UpgradeID.MAX_ITEM_BAG] = _create_upgrade(
		UpgradeID.MAX_ITEM_BAG, "道具袋+", "道具袋上限+2", 5,
		[15, 40, 90, 180, 350],
		[2.0, 2.0, 2.0, 2.0, 2.0]
	)

	upgrades[UpgradeID.FLASK_CAPACITY] = _create_upgrade(
		UpgradeID.FLASK_CAPACITY, "血瓶容量", "血瓶携带上限+1（最多5瓶）", 4,
		[50, 100, 200, 400],
		[1.0, 1.0, 1.0, 1.0]
	)

func _create_upgrade(id: UpgradeID, name: String, desc: String, max_lv: int, costs: Array[int], effects: Array[float]) -> UpgradeEntry:
	var entry := UpgradeEntry.new()
	entry.id = id
	entry.name = name
	entry.description = desc
	entry.max_level = max_lv
	entry.cost_per_level = costs
	entry.effect_per_level = effects
	entry.current_level = 0
	return entry

## 获取角色存档
func get_character_save(class_type: CharacterData.ClassType) -> CharacterSave:
	for char in characters:
		if char.class_type == class_type:
			return char
	return characters[0]

## 增加角色经验（返回升级信息 Array：[新等级, 解锁的里程碑列表]）
## 返回值: [levels_gained: int, new_milestones: Array[String]]
func add_exp(class_type: CharacterData.ClassType, amount: int) -> Array:
	var save := get_character_save(class_type)
	save.experience += amount
	var levels_gained := 0
	var new_milestones: Array[String] = []

	# 循环升级（支持一次加大量经验连升多级）
	while save.level < MAX_LEVEL:
		var needed_xp := LEVEL_XP_TABLE[save.level + 1]
		if save.experience >= needed_xp:
			save.experience -= needed_xp
			save.level += 1
			levels_gained += 1

			# 检查里程碑奖励
			if LEVEL_MILESTONES.has(save.level):
				for m in (LEVEL_MILESTONES[save.level] as Array):
					var milestone_int := int(m as Milestone)
					if not save.milestones_unlocked.has(milestone_int):
						save.milestones_unlocked.append(milestone_int)
						var name_str := get_milestone_name(m as Milestone)
						if name_str != "":
							new_milestones.append("Lv%d: %s" % [save.level, name_str])
		else:
			break

	return [levels_gained, new_milestones]

## 获取某等级到达所需总经验
static func get_xp_for_level(lv: int) -> int:
	if lv <= 0:
		return 0
	if lv >= LEVEL_XP_TABLE.size():
		return LEVEL_XP_TABLE[LEVEL_XP_TABLE.size() - 1]
	return LEVEL_XP_TABLE[lv]

## 获取某等级对应的最大HP
static func get_hp_for_level(lv: int) -> int:
	if lv <= 0:
		return LEVEL_MAX_HP[1]
	if lv >= LEVEL_MAX_HP.size():
		return LEVEL_MAX_HP[LEVEL_MAX_HP.size() - 1]
	return LEVEL_MAX_HP[lv]

## 增加星尘
func add_star_dust(amount: int) -> void:
	star_dust += amount

## 购买升级
func buy_upgrade(upgrade_id: UpgradeID) -> bool:
	if not upgrades.has(upgrade_id):
		return false

	var entry := upgrades[upgrade_id] as UpgradeEntry
	if entry.current_level >= entry.max_level:
		return false

	var cost := entry.cost_per_level[entry.current_level]
	if star_dust < cost:
		return false

	star_dust -= cost
	entry.current_level += 1
	return true

## 获取升级当前效果值
func get_upgrade_effect(upgrade_id: UpgradeID) -> float:
	if not upgrades.has(upgrade_id):
		return 0.0

	var entry := upgrades[upgrade_id] as UpgradeEntry
	if entry.current_level <= 0:
		return 0.0
	return entry.effect_per_level[entry.current_level - 1]

## 获取升级当前等级
func get_upgrade_level(upgrade_id: UpgradeID) -> int:
	if not upgrades.has(upgrade_id):
		return 0
	return (upgrades[upgrade_id] as UpgradeEntry).current_level

## 获取通用全局等级（最低角色等级决定）
func get_global_level() -> int:
	var min_lv := MAX_LEVEL
	for char in characters:
		if char.unlocked and char.level < min_lv:
			min_lv = char.level
	return min_lv

## 获取指定角色的当前存档（带安全检查）
func get_character_save_safe(class_type: CharacterData.ClassType) -> CharacterSave:
	for char in characters:
		if char.class_type == class_type:
			return char as CharacterSave
	# 兜底返回第一个
	if characters.size() > 0:
		return characters[0] as CharacterSave
	var fallback := CharacterSave.new()
	fallback.class_type = class_type
	return fallback
