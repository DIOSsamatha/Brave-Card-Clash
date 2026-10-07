## 王牌系统（Trump Card / 魔法卡）
## 26张王牌：局内主动使用，战术核心
class_name TrumpCardData
extends Resource

## 王牌稀有度
enum Rarity {
	NORMAL,    # N 普通（灰）
	RARE,      # R 稀有（蓝）
	EPIC,      # SR 史诗（紫）
	LEGENDARY,  # SSR 传说（金）
}

## 王牌分类
enum Category {
	INFO,      # 信息类
	OPERATION,  # 操作类
	DEFENSE,    # 防御类
	SPECIAL,    # 特殊类
}

@export var card_name: String = ""
@export var rarity: Rarity = Rarity.NORMAL
@export var category: Category = Category.INFO
@export var description: String = ""
@export var uses_per_battle: int = 1       # 每场战斗使用次数（999=无限循环）
@export var source: String = ""             # 获取来源描述
@export var tip: String = ""                # 策略提示
@export var effect_value: float = 0.0       # 效果数值（攻击牌=伤害加成倍率，防御牌=减伤比例）

## 快捷创建
static func create(name: String, rarity: Rarity, cat: Category, desc: String,
	uses: int, src: String, strategy_tip: String, eff_val: float = 0.0) -> TrumpCardData:
	var c := TrumpCardData.new()
	c.card_name = name
	c.rarity = rarity
	c.category = cat
	c.description = desc
	c.uses_per_battle = uses
	c.source = src
	c.tip = strategy_tip
	c.effect_value = eff_val
	return c

## 获取稀有度标签
static func get_rarity_label(r: Rarity) -> String:
	match r:
		Rarity.NORMAL: return "N"
		Rarity.RARE: return "R"
		Rarity.EPIC: return "SR"
		Rarity.LEGENDARY: return "SSR"
	return "?"

## 获取稀有度中文名
static func get_rarity_name(r: Rarity) -> String:
	match r:
		Rarity.NORMAL: return "普通"
		Rarity.RARE: return "稀有"
		Rarity.EPIC: return "史诗"
		Rarity.LEGENDARY: return "传说"
	return "?"

## 获取分类名
static func get_category_name(c: Category) -> String:
	match c:
		Category.INFO: return "信息类"
		Category.OPERATION: return "操作类"
		Category.DEFENSE: return "防御类"
		Category.SPECIAL: return "特殊类"
	return "?"
