## 姿态倍率系统
## 每小局开始前选择姿态，影响攻防倍率
class_name StanceData
extends RefCounted

## 姿态枚举
enum StanceType {
	DEFENSIVE = 0,    # 谨慎防御
	BALANCED = 1,     # 均衡策略
	AGGRESSIVE = 2,   # 全力进攻
}

## 姿态数据
class StanceConfig:
	var type: StanceType
	var name: String
	var description: String
	var win_multiplier: float        # 胜利时伤害倍率
	var lose_multiplier: float       # 失败时受击倍率
	var enemy_multiplier: float      # 敌方输出倍率（用于NPC）

	func _init(
		p_type: StanceType,
		p_name: String,
		p_desc: String,
		p_win: float,
		p_lose: float,
		p_enemy: float,
	) -> void:
		type = p_type
		name = p_name
		description = p_desc
		win_multiplier = p_win
		lose_multiplier = p_lose
		enemy_multiplier = p_enemy

## 所有姿态配置
static var STANCES: Dictionary = {
	StanceType.DEFENSIVE: StanceConfig.new(
		StanceType.DEFENSIVE,
		"谨慎防御",
		"胜率优先，降低风险。胜利伤害×0.8，失败受伤×0.6",
		0.8,   # win_mult
		0.6,   # lose_mult (受击减少)
		0.8,   # enemy output mult
	),
	StanceType.BALANCED: StanceConfig.new(
		StanceType.BALANCED,
		"均衡策略",
		"标准攻防，稳定发挥。胜利伤害×1.0，失败受伤×1.0",
		1.0,   # win_mult
		1.0,   # lose_mult
		1.0,   # enemy output mult
	),
	StanceType.AGGRESSIVE: StanceConfig.new(
		StanceType.AGGRESSIVE,
		"全力进攻",
		"高风险高回报。胜利伤害×1.8，失败受伤×1.5",
		1.8,   # win_mult
		1.5,   # lose_mult (受击增加)
		1.5,   # enemy output mult
	),
}

## 获取姿态配置
static func get_stance(type: StanceType) -> StanceConfig:
	return STANCES[type] as StanceConfig

## 获取所有姿态列表
static func get_all_stances() -> Array[StanceConfig]:
	var result: Array[StanceConfig] = []
	for stance in STANCES.values():
		result.append(stance as StanceConfig)
	return result

## 获取姿态显示名称
static func get_stance_name(type: StanceType) -> String:
	return get_stance(type).name
