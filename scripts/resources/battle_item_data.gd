## 战斗道具系统
## 消耗性战斗道具：独立于王牌，冒险中获取，每场战斗选3个带入
class_name BattleItemData
extends Resource

## 道具类型
enum ItemType {
	HEAL,          # 回复类
	DAMAGE,        # 攻击类
	DEFENSE,       # 防御类
	CONTROL,       # 控制类
	UTILITY,       # 功能类
}

## 道具稀有度
enum Rarity {
	COMMON,      # 普通
	UNCOMMON,    # 精良（预留）
	RARE,        # 稀有
	EPIC,        # 史诗
	LEGENDARY,   # 传说
}

@export var item_name: String = ""
@export var item_type: ItemType = ItemType.HEAL
@export var rarity: Rarity = Rarity.COMMON
@export var description: String = ""
@export var effect_type: String = ""  # "heal" / "shield" / "purge" / "damage_buff" / "damage_reduce" / "peek_stance" / "auto_stand_bust" / "re_double" / "fire_damage_burn" / "freeze" / "revive"
@export var effect_value: float = 0.0
@export var effect_duration: int = 0  # 0=即时，>0=持续小局数
@export var max_per_round: int = 1    # 每小局限制使用次数

static func create(name: String, type: ItemType, rarity: Rarity, desc: String, e_type: String, value: float, dur: int = 0, max_per: int = 1) -> BattleItemData:
	var item := BattleItemData.new()
	item.item_name = name
	item.item_type = type
	item.rarity = rarity
	item.description = desc
	item.effect_type = e_type
	item.effect_value = value
	item.effect_duration = dur
	item.max_per_round = max_per
	return item
