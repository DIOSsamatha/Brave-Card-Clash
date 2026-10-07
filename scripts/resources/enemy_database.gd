## 敌人数库
## 定义策划案给出的25个小怪（每层5个）+ 6个Boss
class_name EnemyDatabase
extends RefCounted

## 所有敌人数据
static var enemies: Dictionary = {}
static var bosses: Dictionary = {}

## 初始化数据
static func initialize() -> void:
	if not enemies.is_empty():
		return
	_setup_layer1()
	_setup_layer2()
	_setup_layer3()
	_setup_layer4()
	_setup_layer5()
	_setup_bosses()

# === 第1层：妖精幻境 ===
static func _setup_layer1() -> void:
	enemies["sprout_fairy"] = create_enemy("嫩芽妖精", EnemyData.EnemyType.NORMAL, EnemyData.Tier.FAIRY, 30.0, 2.0, "每局未受伤则回复3点生命值。", EnemyData.MechanicID.SPROUT_HEAL, preload("res://resources/enemies/sprout_fairy.png"))
	enemies["thorn_vine"] = create_enemy("荆棘藤蔓", EnemyData.EnemyType.NORMAL, EnemyData.Tier.FAIRY, 32.0, 2.0, "给玩家附加「荆棘」：要牌时有20%几率点数额外+1。", EnemyData.MechanicID.THORN_VINE, preload("res://resources/enemies/thorn_vine.png"))
	enemies["mischief_sprite"] = create_enemy("恶作剧花精", EnemyData.EnemyType.NORMAL, EnemyData.Tier.FAIRY, 26.0, 3.0, "隐藏玩家一张手牌的点数显示。", EnemyData.MechanicID.MISCHIEF_SPRITE, preload("res://resources/enemies/mischief_sprite.png"))
	enemies["ancient_guard"] = create_enemy("古树守卫", EnemyData.EnemyType.ELITE, EnemyData.Tier.FAIRY, 60.0, 3.0, "玩家爆牌时额外强扣2点；拥有1次单次减伤5点。", EnemyData.MechanicID.ANCIENT_GUARD, preload("res://resources/enemies/ancient_guard.png"))
	enemies["phantom_unicorn"] = create_enemy("幻光独角仙", EnemyData.EnemyType.ELITE, EnemyData.Tier.FAIRY, 66.0, 2.0, "胜利时50%附加「致盲」；被黑杰克命中受双倍伤害。", EnemyData.MechanicID.PHANTOM_UNICORN, preload("res://resources/enemies/phantom_unicorn.png"))

# === 第2层：水晶幻境 ===
static func _setup_layer2() -> void:
	enemies["crystal_spider"] = create_enemy("晶簇蜘蛛", EnemyData.EnemyType.NORMAL, EnemyData.Tier.CRYSTAL, 36.0, 2.0, "玩家停牌后，强制其额外再抽一张牌。", EnemyData.MechanicID.CRYSTAL_SPIDER, preload("res://resources/enemies/crystal_spider.png"))
	enemies["echo_bat"] = create_enemy("回声蝙蝠", EnemyData.EnemyType.NORMAL, EnemyData.Tier.CRYSTAL, 33.0, 3.0, "玩家点数≥18时，反震1点伤害给玩家。", EnemyData.MechanicID.ECHO_BAT, preload("res://resources/enemies/echo_bat.png"))
	enemies["crystal_miner"] = create_enemy("掘晶矿工", EnemyData.EnemyType.NORMAL, EnemyData.Tier.CRYSTAL, 39.0, 2.0, "开场自带4点护盾，护盾存在时受伤-1。", EnemyData.MechanicID.CRYSTAL_MINER, preload("res://resources/enemies/crystal_miner.png"))
	enemies["crystal_golem"] = create_enemy("水晶魔像", EnemyData.EnemyType.ELITE, EnemyData.Tier.CRYSTAL, 75.0, 3.0, "每3局免疫一次爆牌；死亡时强扣玩家5点生命。", EnemyData.MechanicID.CRYSTAL_GOLEM, preload("res://resources/enemies/crystal_golem.png"))
	enemies["prism_mage"] = create_enemy("棱镜术士", EnemyData.EnemyType.ELITE, EnemyData.Tier.CRYSTAL, 69.0, 4.0, "向牌堆洗入「分身」陷阱，玩家抽到即爆牌并受3点伤害。", EnemyData.MechanicID.PRISM_MAGE, preload("res://resources/enemies/prism_mage.png"))

# === 第3层：火焰幻境 ===
static func _setup_layer3() -> void:
	enemies["torch_warrior"] = create_enemy("火把战士", EnemyData.EnemyType.NORMAL, EnemyData.Tier.FLAME, 42.0, 3.0, "玩家选「全力进攻」时，自身基础伤害+2。", EnemyData.MechanicID.TORCH_WARRIOR, preload("res://resources/enemies/torch_warrior.png"))
	enemies["flame_wizard"] = create_enemy("烈焰巫师", EnemyData.EnemyType.NORMAL, EnemyData.Tier.FLAME, 39.0, 3.0, "附加「灼烧」2局：玩家每抽数字牌损失1点生命。", EnemyData.MechanicID.FLAME_WIZARD, preload("res://resources/enemies/flame_wizard.png"))
	enemies["lava_hound"] = create_enemy("熔岩猎犬", EnemyData.EnemyType.NORMAL, EnemyData.Tier.FLAME, 45.0, 2.0, "玩家爆牌后，下一局强制全力进攻且自身伤害+3。", EnemyData.MechanicID.LAVA_HOUND, preload("res://resources/enemies/lava_hound.png"))
	enemies["fire_wing_knight"] = create_enemy("火翼骑士", EnemyData.EnemyType.ELITE, EnemyData.Tier.FLAME, 84.0, 4.0, "每局结束玩家血量>50%则强扣2点；自身低血回血+攻击。", EnemyData.MechanicID.FIRE_WING_KNIGHT, preload("res://resources/enemies/fire_wing_knight.png"))
	enemies["pain_warlock"] = create_enemy("痛苦术士", EnemyData.EnemyType.ELITE, EnemyData.Tier.FLAME, 78.0, 3.0, "自身受伤时玩家同步损失1点；小局胜利回血量=玩家受伤害。", EnemyData.MechanicID.PAIN_WARLOCK, preload("res://resources/enemies/pain_warlock.png"))

# === 第4层：暗影幻境 ===
static func _setup_layer4() -> void:
	enemies["shadow_book"] = create_enemy("暗影书精", EnemyData.EnemyType.NORMAL, EnemyData.Tier.SHADOW, 45.0, 2.0, "小局胜利时随机弃掉玩家一张已装备王牌。", EnemyData.MechanicID.SHADOW_BOOK, preload("res://resources/enemies/shadow_book.png"))
	enemies["silence_mask"] = create_enemy("沉默面具", EnemyData.EnemyType.NORMAL, EnemyData.Tier.SHADOW, 48.0, 2.0, "附加「沉默」1局：禁用玩家所有主动技能。", EnemyData.MechanicID.SILENCE_MASK, preload("res://resources/enemies/silence_mask.png"))
	enemies["void_shadow"] = create_enemy("虚无之影", EnemyData.EnemyType.NORMAL, EnemyData.Tier.SHADOW, 51.0, 4.0, "开局随机与玩家交换一张手牌。", EnemyData.MechanicID.VOID_SHADOW, preload("res://resources/enemies/void_shadow.png"))
	enemies["curator_soul"] = create_enemy("馆长之魂", EnemyData.EnemyType.ELITE, EnemyData.Tier.SHADOW, 90.0, 3.0, "每3局封印玩家技能；玩家用王牌越多自身伤害越高。", EnemyData.MechanicID.CURATOR_SOUL, preload("res://resources/enemies/curator_soul.png"))
	enemies["shadow_aggregate"] = create_enemy("暗影聚合体", EnemyData.EnemyType.ELITE, EnemyData.Tier.SHADOW, 99.0, 4.0, "击破玩家护盾额外强扣等量生命；玩家单局未造成伤害则自身回8。", EnemyData.MechanicID.SHADOW_AGGREGATE, preload("res://resources/enemies/shadow_aggregate.png"))

# === 第5层：魔王城前庭 ===
static func _setup_layer5() -> void:
	enemies["heavy_guard"] = create_enemy("重甲魔卫", EnemyData.EnemyType.NORMAL, EnemyData.Tier.COURTYARD, 54.0, 2.0, "开场自带5点护盾，护盾存在时免疫所有负面状态。", EnemyData.MechanicID.HEAVY_GUARD, preload("res://resources/enemies/heavy_guard.png"))
	enemies["curse_mage"] = create_enemy("咒术师", EnemyData.EnemyType.NORMAL, EnemyData.Tier.COURTYARD, 57.0, 3.0, "强制玩家下一张要牌变为10点。", EnemyData.MechanicID.CURSE_MAGE, preload("res://resources/enemies/curse_mage.png"))
	enemies["demon_hound"] = create_enemy("恶魔猎犬", EnemyData.EnemyType.NORMAL, EnemyData.Tier.COURTYARD, 60.0, 4.0, "玩家每损失10点生命，自身基础伤害+1（最高+4）。", EnemyData.MechanicID.DEMON_HOUND, preload("res://resources/enemies/demon_hound.png"))
	enemies["guard_knight"] = create_enemy("近卫骑士", EnemyData.EnemyType.ELITE, EnemyData.Tier.COURTYARD, 108.0, 4.0, "胜利时30%追加3点神圣伤害；每局自动回1点生命。", EnemyData.MechanicID.GUARD_KNIGHT, preload("res://resources/enemies/guard_knight.png"))

# === Boss ===
static func _setup_bosses() -> void:
	bosses["clover_spirit"] = create_boss("梅花精灵 ♣", EnemyData.Tier.FAIRY, 60.0, 3.0, "妖精幻境守护者，掌握梅花封印之力。", "梅花印记", "每小局胜者从败者牌堆偷取一张最高点数的牌", "soft_17_must_hit=true", preload("res://resources/enemies/clover_spirit.png"))
	bosses["diamond_giant"] = create_boss("方块巨人 ♦", EnemyData.Tier.CRYSTAL, 78.0, 4.0, "最纯粹水晶能量构成的泰坦巨人。", "水晶镜像", "初次爆牌后回到21点（每场一次）", "hit_until_hard_17=true", preload("res://resources/enemies/diamond_giant.png"))
	bosses["heart_knight"] = create_boss("红桃骑士 ♥", EnemyData.Tier.FLAME, 102.0, 5.0, "燃烧无尽激情的不灭骑士。", "红莲斩", "造成伤害时追加目标生命上限10%的灼烧伤害", "always_use_aggressive_stance=true", preload("res://resources/enemies/heart_knight.png"))
	bosses["spade_mage"] = create_boss("黑桃法师 ♠", EnemyData.Tier.SHADOW, 126.0, 5.5, "掌握黑暗魔法的强大法师。", "暗能献祭", "每2小局牺牲自己3点生命换玩家5点生命", "hit_soft_18=true", preload("res://resources/enemies/spade_mage.png"))
	bosses["captain_guard"] = create_boss("近卫队长", EnemyData.Tier.COURTYARD, 156.0, 6.0, "魔王最信赖的战士，以生命守护王座。", "铁壁守卫", "每小局开始获得等于本小局编号的护盾", "hit_until_19=true", preload("res://resources/enemies/captain_guard.png"))
	bosses["spade_king"] = create_boss("黑桃魔王 ♠", EnemyData.Tier.THRONE, 180.0, 7.0, "封印红心公主的魔界之巅，最终Boss。", "绝望领域", "第5小局起每小局对玩家造成3点固定伤害", "hit_until_20=true;immune_to_bj=true", preload("res://resources/enemies/spade_king.png"))

# === 工厂方法 ===
static func create_enemy(name: String, type: EnemyData.EnemyType, t: EnemyData.Tier, hp: float, dmg: float, desc: String, mechanic_id: int = EnemyData.MechanicID.NONE, portrait: Texture2D = null) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = name
	e.enemy_type = type
	e.tier = t
	e.max_health = hp
	e.base_damage = dmg
	e.description = desc
	e.mechanic_id = mechanic_id
	e.portrait = portrait
	return e

static func create_boss(name: String, t: EnemyData.Tier, hp: float, dmg: float, desc: String, sp_name: String, sp_desc: String, boss_rule: String, portrait: Texture2D = null) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = name
	e.enemy_type = EnemyData.EnemyType.BOSS
	e.tier = t
	e.max_health = hp
	e.base_damage = dmg
	e.description = desc
	e.has_special = true
	e.special_name = sp_name
	e.special_desc = sp_desc
	e.special_trigger_chance = 1.0
	e.boss_custom_rule = boss_rule
	e.mechanic_id = EnemyData.MechanicID.NONE
	e.portrait = portrait
	return e

## 层级主题名称（与层数索引0-5对应）
static var LAYER_NAMES: Array[String] = [
	"妖精幻境",
	"水晶幻境",
	"火焰幻境",
	"暗影幻境",
	"魔王城前庭",
	"魔王之间",
]

## 层级对应的Tier枚举（0-5 → Tier枚举）
static var LAYER_TIERS: Array = [
	EnemyData.Tier.FAIRY,
	EnemyData.Tier.CRYSTAL,
	EnemyData.Tier.FLAME,
	EnemyData.Tier.SHADOW,
	EnemyData.Tier.COURTYARD,
	EnemyData.Tier.THRONE,
]

## 层级Boss的key（按层索引）
static var LAYER_BOSS_KEYS: Array[String] = [
	"clover_spirit",     # 第1层：梅花精灵
	"diamond_giant",     # 第2层：方块巨人
	"heart_knight",      # 第3层：红桃骑士
	"spade_mage",        # 第4层：黑桃法师
	"captain_guard",     # 第5层：近卫队长
	"spade_king",        # 第6层：黑桃魔王
]

## 获取指定层（0-5）的所有可遇敌人（普通+精英）
static func get_enemies_for_layer(layer_idx: int) -> Array[EnemyData]:
	initialize()
	var tier: EnemyData.Tier = LAYER_TIERS[layer_idx] as EnemyData.Tier
	var result: Array[EnemyData] = []
	for enemy in enemies.values():
		var e := enemy as EnemyData
		if e.tier == tier:
			result.append(e)
	return result

## 获取指定层（0-5）的普通敌人随机一只
static func get_random_enemy_for_layer(layer_idx: int) -> EnemyData:
	initialize()
	layer_idx = clampi(layer_idx, 0, LAYER_TIERS.size() - 1)
	var tier: EnemyData.Tier = LAYER_TIERS[layer_idx] as EnemyData.Tier
	return get_random_enemy(tier)

## 获取指定层（0-5）的精英敌人随机一只
static func get_random_elite_for_layer(layer_idx: int) -> EnemyData:
	initialize()
	layer_idx = clampi(layer_idx, 0, LAYER_TIERS.size() - 1)
	var tier: EnemyData.Tier = LAYER_TIERS[layer_idx] as EnemyData.Tier
	return get_random_elite(tier)

## 随机获取指定层的「全部怪物」（普通+精英）——战斗/精英节点皆可从此池随机选取
static func get_random_any_for_layer(layer_idx: int) -> EnemyData:
	initialize()
	layer_idx = clampi(layer_idx, 0, LAYER_TIERS.size() - 1)
	var tier: EnemyData.Tier = LAYER_TIERS[layer_idx] as EnemyData.Tier
	var candidates: Array[EnemyData] = []
	for enemy in enemies.values():
		var e := enemy as EnemyData
		if e.tier == tier and (e.enemy_type == EnemyData.EnemyType.NORMAL or e.enemy_type == EnemyData.EnemyType.ELITE):
			candidates.append(e)
	if candidates.is_empty():
		return get_default_enemy(tier)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return candidates[rng.randi_range(0, candidates.size() - 1)]

## 获取指定层（0-5）的Boss
static func get_boss_for_layer(layer_idx: int) -> EnemyData:
	initialize()
	layer_idx = clampi(layer_idx, 0, LAYER_BOSS_KEYS.size() - 1)
	var key: String = LAYER_BOSS_KEYS[layer_idx]
	if bosses.has(key):
		return bosses[key] as EnemyData
	# 保底：按tier查找
	var tier: EnemyData.Tier = LAYER_TIERS[layer_idx] as EnemyData.Tier
	return get_boss(tier)

## 检查层级是否解锁
## layer_idx: 0-5, player_level: 当前角色等级, beat_captain_forms: 已击败近卫队长的形态数(0-3)
static func is_layer_unlocked(layer_idx: int, player_level: int, beat_captain_forms: int) -> bool:
	if layer_idx <= 4:
		return true
	if layer_idx == 5:
		# 魔王城前庭：需要任意角色达到20级
		return player_level >= 20
	if layer_idx == 6:
		# 魔王之间：需击败近卫队长全部3形态
		return beat_captain_forms >= 3
	return false

## 获取层级解锁条件描述
static func get_layer_lock_reason(layer_idx: int) -> String:
	match layer_idx:
		5: return "需要任意角色达到20级解锁"
		6: return "需击败近卫队长全部3形态"
		_: return ""

## 随机获取指定层的普通敌人（保留兼容）
static func get_random_enemy(tier: EnemyData.Tier) -> EnemyData:
	initialize()
	var candidates: Array[EnemyData] = []
	for enemy in enemies.values():
		var e := enemy as EnemyData
		if e.tier == tier and e.enemy_type == EnemyData.EnemyType.NORMAL:
			candidates.append(e)
	if candidates.is_empty():
		return get_default_enemy(tier)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return candidates[rng.randi_range(0, candidates.size() - 1)]

## 随机获取指定层的精英敌人
static func get_random_elite(tier: EnemyData.Tier) -> EnemyData:
	initialize()
	var candidates: Array[EnemyData] = []
	for enemy in enemies.values():
		var e := enemy as EnemyData
		if e.tier == tier and e.enemy_type == EnemyData.EnemyType.ELITE:
			candidates.append(e)
	if candidates.is_empty():
		return get_default_enemy(tier)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return candidates[rng.randi_range(0, candidates.size() - 1)]

## 获取指定层Boss
static func get_boss(tier: EnemyData.Tier) -> EnemyData:
	initialize()
	for boss in bosses.values():
		var b := boss as EnemyData
		if b.tier == tier:
			return b
	return get_default_enemy(tier)

## 获取默认敌人（保底）
static func get_default_enemy(tier: EnemyData.Tier) -> EnemyData:
	var hp_values := [20.0, 22.0, 24.0, 22.0, 32.0, 40.0]
	var dmg_values := [2.0, 2.0, 3.0, 2.0, 2.0, 4.0]
	var names := ["幻境怪物", "堕落之灵", "诅咒生物", "暗影随从"]
	var idx := tier as int
	return create_enemy(names[idx % names.size()], EnemyData.EnemyType.NORMAL, tier, hp_values[idx], dmg_values[idx], "被诅咒的生物。")
