## 敌人数据资源
## 定义怪物属性、技能、Boss机制
class_name EnemyData
extends Resource

## 敌人类型
enum EnemyType {
	NORMAL,    # 普通
	ELITE,     # 精英
	BOSS,      # Boss
}

## 怪物阶层
enum Tier {
	FAIRY = 0,     # 妖精幻境（层1）
	CRYSTAL = 1,   # 水晶幻境（层2）
	FLAME = 2,     # 火焰幻境（层3）
	SHADOW = 3,    # 暗影幻境（层4）
	COURTYARD = 4, # 魔王城前庭（层5）
	THRONE = 5,    # 魔王之间（层6）
}

## 机制ID（对应 enemy_mechanics.gd 中的实现）
enum MechanicID {
	NONE = 0,
	SPROUT_HEAL,       # 嫩芽妖精
	THORN_VINE,         # 荆棘藤蔓
	MISCHIEF_SPRITE,    # 恶作剧花精
	ANCIENT_GUARD,      # 古树守卫
	PHANTOM_UNICORN,    # 幻光独角仙
	CRYSTAL_SPIDER,     # 晶簇蜘蛛
	ECHO_BAT,           # 回声蝙蝠
	CRYSTAL_MINER,      # 掘晶矿工
	CRYSTAL_GOLEM,      # 水晶魔像
	PRISM_MAGE,         # 棱镜术士
	TORCH_WARRIOR,      # 火把战士
	FLAME_WIZARD,       # 烈焰巫师
	LAVA_HOUND,         # 熔岩猎犬
	FIRE_WING_KNIGHT,   # 火翼骑士
	PAIN_WARLOCK,       # 痛苦术士
	SHADOW_BOOK,        # 暗影书精
	SILENCE_MASK,       # 沉默面具
	VOID_SHADOW,        # 虚无之影
	CURATOR_SOUL,       # 馆长之魂
	SHADOW_AGGREGATE,   # 暗影聚合体
	HEAVY_GUARD,        # 重甲魔卫
	CURSE_MAGE,         # 咒术师
	DEMON_HOUND,        # 恶魔猎犬
	GUARD_KNIGHT,       # 近卫骑士
}

## 基础属性
@export var enemy_name: String = ""
@export var enemy_type: EnemyType = EnemyType.NORMAL
@export var tier: Tier = Tier.FAIRY
@export var max_health: float = 15.0
@export var base_damage: float = 2.0
@export var description: String = ""

## 特殊技能
@export var has_special: bool = false
@export var special_name: String = ""
@export var special_desc: String = ""
@export var special_trigger_chance: float = 0.3  # 触发概率

## Boss特有：暗牌规则
@export var boss_custom_rule: String = ""  # 如 "hit_soft_18=true" "must_stand_on_hard_15=true"

## 机制ID（对应 enemy_mechanics.gd）
@export var mechanic_id: int = MechanicID.NONE

## 战斗立绘
@export var portrait: Texture2D = null
