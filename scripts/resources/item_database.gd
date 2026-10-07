## 战斗道具数据库
## 消耗性战斗道具：独立于王牌，冒险中获取，每场战斗选3个带入
class_name ItemDatabase
extends RefCounted

static var all_items: Array[BattleItemData] = []

static func initialize() -> void:
	if not all_items.is_empty():
		return

	# === 回复类 ===
	all_items.append(BattleItemData.create("治疗药水", BattleItemData.ItemType.HEAL, BattleItemData.Rarity.COMMON, "恢复5点生命", "heal", 5.0))
	all_items.append(BattleItemData.create("强效治疗药剂", BattleItemData.ItemType.HEAL, BattleItemData.Rarity.RARE, "恢复12点生命", "heal", 12.0))

	# === 防御类 ===
	all_items.append(BattleItemData.create("魔法护盾卷轴", BattleItemData.ItemType.DEFENSE, BattleItemData.Rarity.COMMON, "获得6点护盾，持续2小局", "shield", 6.0, 2))
	all_items.append(BattleItemData.create("铁壁药水", BattleItemData.ItemType.DEFENSE, BattleItemData.Rarity.RARE, "本小局受到伤害-4", "damage_reduce", 4.0))
	all_items.append(BattleItemData.create("净化卷轴", BattleItemData.ItemType.DEFENSE, BattleItemData.Rarity.COMMON, "移除自身所有负面状态", "purge", 0.0))

	# === 攻击类 ===
	all_items.append(BattleItemData.create("力量药水", BattleItemData.ItemType.DAMAGE, BattleItemData.Rarity.RARE, "本小局基础伤害+3", "damage_buff", 3.0))
	all_items.append(BattleItemData.create("燃烧瓶", BattleItemData.ItemType.DAMAGE, BattleItemData.Rarity.EPIC, "造成4点强扣火焰伤害+灼烧2局", "fire_damage_burn", 4.0, 2))
	all_items.append(BattleItemData.create("冰冻手雷", BattleItemData.ItemType.DAMAGE, BattleItemData.Rarity.EPIC, "附加冻伤1局（禁用技能，姿态强制防御）", "freeze", 1.0, 1))

	# === 功能类 ===
	all_items.append(BattleItemData.create("偷窥眼镜", BattleItemData.ItemType.UTILITY, BattleItemData.Rarity.COMMON, "查看敌方本局姿态", "peek_stance", 0.0))
	all_items.append(BattleItemData.create("幸运硬币", BattleItemData.ItemType.UTILITY, BattleItemData.Rarity.RARE, "本小局要牌若会爆牌则自动停牌", "auto_stand_bust", 0.0))
	all_items.append(BattleItemData.create("肾上腺素", BattleItemData.ItemType.UTILITY, BattleItemData.Rarity.RARE, "本小局可再次“加倍”", "re_double", 0.0))
	all_items.append(BattleItemData.create("回生羽毛", BattleItemData.ItemType.UTILITY, BattleItemData.Rarity.LEGENDARY, "死亡时恢复30%生命并清负面（一次）", "revive", 0.3))

	# === 换牌类（拼点牌置换）===
	all_items.append(BattleItemData.create("置换卷轴", BattleItemData.ItemType.UTILITY, BattleItemData.Rarity.COMMON, "弃掉1张手牌，从牌堆重抽1张（手动选牌）", "redraw_card", 0.0))
	all_items.append(BattleItemData.create("顶牌置换符", BattleItemData.ItemType.UTILITY, BattleItemData.Rarity.RARE, "自动将手牌中点数最高的1张与牌堆顶交换", "redraw_card_auto", 0.0))

static func get_random_item() -> BattleItemData:
	initialize()
	return _pick_by_rarity(0.45, 0.80, 0.95)

## 根据层数获取随机道具（高层出高稀有度）
static func get_random_item_by_tier(tier_idx: int) -> BattleItemData:
	initialize()
	var n_weight: float = clampf(0.50 - tier_idx * 0.08, 0.10, 0.50)
	var r_weight: float = clampf(0.30 + tier_idx * 0.02, 0.20, 0.40)
	var e_weight: float = clampf(0.12 + tier_idx * 0.04, 0.10, 0.35)
	return _pick_by_rarity(n_weight, n_weight + r_weight, n_weight + r_weight + e_weight)

static func _pick_by_rarity(n_threshold: float, r_threshold: float, e_threshold: float) -> BattleItemData:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randf()
	var target_rarity: BattleItemData.Rarity
	if roll < n_threshold:
		target_rarity = BattleItemData.Rarity.COMMON
	elif roll < r_threshold:
		target_rarity = BattleItemData.Rarity.RARE
	elif roll < e_threshold:
		target_rarity = BattleItemData.Rarity.EPIC
	else:
		target_rarity = BattleItemData.Rarity.LEGENDARY

	var candidates: Array[BattleItemData] = []
	for item in all_items:
		if item.rarity == target_rarity:
			candidates.append(item)
	if candidates.is_empty():
		return all_items[0]
	return candidates[rng.randi_range(0, candidates.size() - 1)]
