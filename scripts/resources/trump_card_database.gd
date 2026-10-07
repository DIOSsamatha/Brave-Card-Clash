## 王牌数据库
## 定义全部26张王牌数据 + 2张基础攻防牌
class_name TrumpCardDatabase
extends RefCounted

static var all_cards: Array[TrumpCardData] = []
static var basic_attack: TrumpCardData = null   # 基础攻击牌（单例引用）
static var basic_defense: TrumpCardData = null  # 基础防御牌（单例引用）

static func initialize() -> void:
	if not all_cards.is_empty():
		return

	# === 基础攻防牌（每角色开局各3张，循环使用）===

	basic_attack = TrumpCardData.create(
		"攻击牌", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.OPERATION,
		"本局造成的伤害+25%", 999, "初始自带",
		"提升本局输出，适合进攻姿态", 0.25
	)
	all_cards.append(basic_attack)

	basic_defense = TrumpCardData.create(
		"防御牌", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.DEFENSE,
		"本局受到的伤害-25%", 999, "初始自带",
		"降低本局受伤，适合防守姿态", 0.25
	)
	all_cards.append(basic_defense)

	# === 信息类（6张）===

	all_cards.append(TrumpCardData.create(
		"窥视水晶", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.INFO,
		"查看敌方本局姿态", 1, "初始自带",
		"预判对手攻防倾向，选择对应姿态 counter"
	))
	all_cards.append(TrumpCardData.create(
		"命运之眼", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.INFO,
		"查看牌堆顶3张牌", 1, "第一章妖精幻境掉落",
		"规划要牌节奏，避免爆牌"
	))
	all_cards.append(TrumpCardData.create(
		"全知宝珠", TrumpCardData.Rarity.RARE, TrumpCardData.Category.INFO,
		"查看敌方全部手牌", 1, "第二章水晶幻境奖励",
		"完全掌握对方点数，精准决策"
	))
	all_cards.append(TrumpCardData.create(
		"时间沙漏", TrumpCardData.Rarity.EPIC, TrumpCardData.Category.INFO,
		"查看牌堆顶5张牌，可将其中1张置于牌堆底", 1, "第四章暗影幻境隐藏宝箱",
		"操控牌序，稳定凑出21点"
	))

	# === 操作类（7张）===

	all_cards.append(TrumpCardData.create(
		"换牌魔杖", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.OPERATION,
		"将自己1张手牌与牌堆顶1张交换", 1, "初始自带",
		"换掉手牌中的大牌，避免爆牌"
	))
	all_cards.append(TrumpCardData.create(
		"诅咒之书", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.OPERATION,
		"强制敌方多抽1张牌", 1, "第一章妖精幻境掉落",
		"敌方点数接近21时使用，逼其爆牌"
	))
	all_cards.append(TrumpCardData.create(
		"窃牌之手", TrumpCardData.Rarity.RARE, TrumpCardData.Category.OPERATION,
		"随机与敌方交换1张手牌", 1, "第三章火焰幻境奖励",
		"己方小牌、敌方大牌时使用，拉平点数差"
	))
	all_cards.append(TrumpCardData.create(
		"点数操控", TrumpCardData.Rarity.RARE, TrumpCardData.Category.OPERATION,
		"将手中1张A强制设为1点或11点", 1, "商店购买",
		"解决A牌点数冲突，精准控点"
	))
	all_cards.append(TrumpCardData.create(
		"弃牌重抽", TrumpCardData.Rarity.RARE, TrumpCardData.Category.OPERATION,
		"弃掉1张手牌，重新从牌堆抽取1张", 1, "第二章水晶幻境掉落",
		"弃掉爆牌风险高的大牌，重抽补点"
	))
	all_cards.append(TrumpCardData.create(
		"顶牌置换", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.OPERATION,
		"将手牌中1张与牌堆顶交换（手动选牌）", 1, "初始自带",
		"换掉手牌中的大牌，避免爆牌"
	))
	all_cards.append(TrumpCardData.create(
		"置换魔方", TrumpCardData.Rarity.RARE, TrumpCardData.Category.OPERATION,
		"弃掉1张手牌，从牌堆重抽1张（手动选牌）", 1, "第三章火焰幻境奖励",
		"稳定换掉风险牌，重新规划点数"
	))
	all_cards.append(TrumpCardData.create(
		"命运重构", TrumpCardData.Rarity.EPIC, TrumpCardData.Category.OPERATION,
		"自动将手牌中点数最高的1张与牌堆顶交换", 1, "第六章魔王城掉落",
		"无需操作，自动优化最高风险牌"
	))
	all_cards.append(TrumpCardData.create(
		"三张十", TrumpCardData.Rarity.EPIC, TrumpCardData.Category.OPERATION,
		"向牌堆洗入3张10点牌，位置随机", 1, "成就奖励",
		"配合诅咒之书，大幅提升敌方爆牌率"
	))

	# === 防御类（4张）===

	all_cards.append(TrumpCardData.create(
		"治疗药水", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.DEFENSE,
		"恢复12点生命值", 1, "初始自带",
		"前期容错，抵消小额伤害"
	))
	all_cards.append(TrumpCardData.create(
		"魔法护盾", TrumpCardData.Rarity.RARE, TrumpCardData.Category.DEFENSE,
		"本局受到的所有伤害减半", 1, "第二章水晶幻境奖励",
		"高赌注局使用，大幅降低受伤"
	))
	all_cards.append(TrumpCardData.create(
		"净化卷轴", TrumpCardData.Rarity.RARE, TrumpCardData.Category.DEFENSE,
		"免疫本局所有负面状态", 1, "商店购买",
		"应对敌方控制类技能，避免debuff影响"
	))
	all_cards.append(TrumpCardData.create(
		"复活羽毛", TrumpCardData.Rarity.EPIC, TrumpCardData.Category.DEFENSE,
		"死亡时恢复50%生命值，摧毁敌方所有手牌（限1次/冒险）", 1, "第五章魔王城前庭掉落",
		"绝境翻盘，相当于额外生命"
	))

	# === 特殊类（9张）===

	all_cards.append(TrumpCardData.create(
		"生命结晶", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.SPECIAL,
		"局间使用，恢复18点生命值", 2, "场景散落拾取",
		"局间回血，提升长线续航"
	))
	all_cards.append(TrumpCardData.create(
		"沉默咒语", TrumpCardData.Rarity.NORMAL, TrumpCardData.Category.SPECIAL,
		"敌方下回合无法使用任何技能", 1, "第一章妖精幻境奖励",
		"针对高难度对手，废掉对方关键技能"
	))
	all_cards.append(TrumpCardData.create(
		"同归于尽", TrumpCardData.Rarity.RARE, TrumpCardData.Category.SPECIAL,
		"双方均爆牌时，直接判定敌方输", 1, "第三章火焰幻境隐藏",
		"激进爆牌流核心，强行换血不亏"
	))
	all_cards.append(TrumpCardData.create(
		"吸血宝石", TrumpCardData.Rarity.RARE, TrumpCardData.Category.SPECIAL,
		"本局胜利时，额外恢复6点生命值", 1, "第四章暗影幻境掉落",
		"优势局滚雪球，越赢血量越多"
	))
	all_cards.append(TrumpCardData.create(
		"技能封印", TrumpCardData.Rarity.EPIC, TrumpCardData.Category.SPECIAL,
		"结算后作废敌方本局已使用的1个技能效果", 1, "真结局路线奖励",
		"针对BOSS级对手，抵消其核心技能"
	))
	all_cards.append(TrumpCardData.create(
		"平局重开", TrumpCardData.Rarity.EPIC, TrumpCardData.Category.SPECIAL,
		"直接结束当前小局，双方均不受伤害，重新发牌", 1, "隐藏成就奖励",
		"规避必败局，重新获取机会"
	))
	all_cards.append(TrumpCardData.create(
		"幸运四叶草", TrumpCardData.Rarity.LEGENDARY, TrumpCardData.Category.SPECIAL,
		"下一张要牌必定为10点", 1, "全图鉴收集奖励",
		"精准凑点，稳定组成20/21点"
	))
	all_cards.append(TrumpCardData.create(
		"黑杰克契约", TrumpCardData.Rarity.LEGENDARY, TrumpCardData.Category.SPECIAL,
		"下两张牌必定组成A+10点的黑杰克，黑杰克伤害翻倍", 1, "地狱难度通关奖励",
		"直接锁定黑杰克，最大化输出"
	))
	all_cards.append(TrumpCardData.create(
		"命运改写", TrumpCardData.Rarity.LEGENDARY, TrumpCardData.Category.SPECIAL,
		"本局重新发牌并重选姿态（限1次/局）", 1, "30级满级奖励",
		"完全重置本局，扭转劣势"
	))
	all_cards.append(TrumpCardData.create(
		"公主祝福", TrumpCardData.Rarity.LEGENDARY, TrumpCardData.Category.SPECIAL,
		"整场战斗中，受到的所有伤害减半", 1, "真结局通关奖励",
		"全程减伤，大幅提升生存能力"
	))

static var all_items: Array[TrumpCardData] = []

## 获取随机王牌（按稀有度权重）
static func get_random_card() -> TrumpCardData:
	initialize()
	return _pick_by_rarity_weights(0.45, 0.75, 0.92)

## 根据层数获取随机王牌（高层出高稀有度）
static func get_random_card_by_tier(tier_idx: int) -> TrumpCardData:
	initialize()
	# 层数越高，高稀有度概率越大
	var n_weight: float = clampf(0.50 - tier_idx * 0.08, 0.10, 0.50)
	var r_weight: float = clampf(0.30 + tier_idx * 0.02, 0.20, 0.40)
	var e_weight: float = clampf(0.12 + tier_idx * 0.04, 0.10, 0.35)
	# 传说权重 = 1 - 前面累计
	return _pick_by_rarity_weights(n_weight, n_weight + r_weight, n_weight + r_weight + e_weight)

static func _pick_by_rarity_weights(n_threshold: float, r_threshold: float, e_threshold: float) -> TrumpCardData:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randf()
	var target_rarity: TrumpCardData.Rarity
	if roll < n_threshold:
		target_rarity = TrumpCardData.Rarity.NORMAL
	elif roll < r_threshold:
		target_rarity = TrumpCardData.Rarity.RARE
	elif roll < e_threshold:
		target_rarity = TrumpCardData.Rarity.EPIC
	else:
		target_rarity = TrumpCardData.Rarity.LEGENDARY

	var candidates: Array[TrumpCardData] = []
	for card in all_cards:
		if card.rarity == target_rarity:
			candidates.append(card)
	if candidates.is_empty():
		return all_cards[0]
	return candidates[rng.randi_range(0, candidates.size() - 1)]

## 获取起始王牌组（2攻击+1防御，共3张）
static func get_starter_cards() -> Array[TrumpCardData]:
	initialize()
	var starter: Array[TrumpCardData] = []
	starter.append(basic_attack)
	starter.append(basic_attack)
	starter.append(basic_defense)
	return starter

## 按分类获取全部卡牌
static func get_cards_by_category(cat: TrumpCardData.Category) -> Array[TrumpCardData]:
	initialize()
	var result: Array[TrumpCardData] = []
	for card in all_cards:
		if card.category == cat:
			result.append(card)
	return result
