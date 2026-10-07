## 战斗状态系统（Buff/Debuff 容器）
## 玩家与敌方各自持有一个 CombatStatus 实例
## 设计：状态分「即时（rounds==0，本小局生效，下局开始清除）」与「持续（rounds>0，按回合递减）」
class_name CombatStatus
extends RefCounted

## 状态类型
enum StatusType {
	NONE = 0,
	THORNS,            # 荆棘：要牌时20%点数额外+1
	BLIND,             # 致盲：看不见敌方明牌
	HIDE_CARD,         # 迷雾：隐藏一张手牌点数
	BURN,              # 灼烧：每抽到一张数字牌损失生命
	CURSE_DRAW,        # 诅咒抽牌：下一张要牌强制为10点
	FORCED_STANCE,     # 强制姿态（value=姿态类型）
	SILENCE,           # 沉默：禁用主动技能
	FREEZE,            # 冻结：禁用技能+强制防御
	SHIELD_DURATION,   # 护盾（带持续时间）
	DAMAGE_BUFF,       # 本小局基础伤害+
	DAMAGE_REDUCE,     # 本小局受伤-
	PEEK,              # 透视：可见敌方姿态
	AUTO_STAND_BUST,   # 幸运：要牌会爆则自动停牌
	RE_DOUBLE,         # 肾上腺素：可再次加倍
	REVIVE,            # 回生：死亡复活一次
	ENEMY_DMG_BUFF,   # 敌方伤害+
	ENEMY_IMMUNE_BUST,# 敌方免疫一次爆牌
	ENEMY_ONCE_REDUCE,# 敌方单次减伤
	ENEMY_DMG_PER_TRUMP, # 敌方每用王牌伤害+
	# === 技能系统新增状态 ===
	FAIL_DAMAGE_REDUCE,  # 失败减伤（剑士技能2）
	SWAP_TOP,            # 与牌堆顶交换（法师技能1）
	FORCE_DRAW,          # 强制庄家多抽（法师技能2）
	SILENCED,            # 沉默敌方（盗贼技能2）
	INVINCIBLE,          # 免疫所有伤害（牧师技能2）
	HEAL_ON_WIN,         # 胜利回血（牧师被动）
}

## 单个状态效果
class StatusEffect:
	var type: int = StatusType.NONE
	var value: float = 0.0
	var rounds: int = 0        # 剩余小局数（0=仅当前小局）
	var stance: int = -1       # FORCED_STANCE 用
	var used: bool = false      # 一次性效果标记

	func _init(p_type: int, p_value: float = 0.0, p_rounds: int = 0, p_stance: int = -1) -> void:
		type = p_type
		value = p_value
		rounds = p_rounds
		stance = p_stance

var _effects: Array[StatusEffect] = []

## 添加状态（同类型刷新数值与回合）
func add_status(type: int, value: float = 0.0, rounds: int = 0, stance: int = -1) -> void:
	for e in _effects:
		if e.type == type:
			e.value = maxf(e.value, value)
			e.rounds = maxi(e.rounds, rounds)
			if stance >= 0:
				e.stance = stance
			return
	_effects.append(StatusEffect.new(type, value, rounds, stance))

## 是否有某状态（排除已消耗的一次性）
func has_status(type: int) -> bool:
	for e in _effects:
		if e.type == type and not e.used:
			return true
	return false

## 获取某状态（无则返回 null）
func get_status(type: int) -> StatusEffect:
	for e in _effects:
		if e.type == type:
			return e
	return null

## 移除某状态
func remove_status(type: int) -> void:
	var idx := 0
	while idx < _effects.size():
		if _effects[idx].type == type:
			_effects.remove_at(idx)
		else:
			idx += 1

## 标记一次性状态为已消耗
func consume_once(type: int) -> void:
	var e := get_status(type)
	if e != null:
		e.used = true

## 清除所有负面状态（净化卷轴）
func purge_negative() -> void:
	var negatives := [
		StatusType.THORNS, StatusType.BLIND, StatusType.HIDE_CARD,
		StatusType.BURN, StatusType.CURSE_DRAW, StatusType.FORCED_STANCE,
		StatusType.SILENCE, StatusType.FREEZE,
	]
	var idx := 0
	while idx < _effects.size():
		if _effects[idx].type in negatives:
			_effects.remove_at(idx)
		else:
			idx += 1

## 小局结束：递减持续型回合，移除到期项
func tick_round_end() -> void:
	var idx := 0
	while idx < _effects.size():
		if _effects[idx].rounds > 0:
			_effects[idx].rounds -= 1
			if _effects[idx].rounds <= 0:
				_effects.remove_at(idx)
				continue
		idx += 1

## 下一小局开始：清除仅当前小局生效的即时状态
func clear_transient() -> void:
	var idx := 0
	while idx < _effects.size():
		if _effects[idx].rounds == 0:
			_effects.remove_at(idx)
		else:
			idx += 1

## 获取全部状态（UI 显示）
func get_all() -> Array[StatusEffect]:
	return _effects

## 状态显示名
static func get_status_name(type: int) -> String:
	match type:
		StatusType.THORNS: return "荆棘"
		StatusType.BLIND: return "致盲"
		StatusType.HIDE_CARD: return "迷雾"
		StatusType.BURN: return "灼烧"
		StatusType.CURSE_DRAW: return "诅咒抽牌"
		StatusType.FORCED_STANCE: return "强制姿态"
		StatusType.SILENCE: return "沉默"
		StatusType.FREEZE: return "冻结"
		StatusType.SHIELD_DURATION: return "护盾"
		StatusType.DAMAGE_BUFF: return "力量"
		StatusType.DAMAGE_REDUCE: return "铁壁"
		StatusType.PEEK: return "透视"
		StatusType.AUTO_STAND_BUST: return "幸运"
		StatusType.RE_DOUBLE: return "肾上腺素"
		StatusType.REVIVE: return "回生"
		StatusType.ENEMY_DMG_BUFF: return "狂暴"
		StatusType.ENEMY_IMMUNE_BUST: return "抗爆"
		StatusType.ENEMY_ONCE_REDUCE: return "减伤"
		StatusType.ENEMY_DMG_PER_TRUMP: return "蓄能"
		StatusType.FAIL_DAMAGE_REDUCE: return "剑气护体"
		StatusType.SWAP_TOP: return "火焰置换"
		StatusType.FORCE_DRAW: return "诅咒爆牌"
		StatusType.SILENCED: return "沉默敌方"
		StatusType.INVINCIBLE: return "圣光庇护"
		StatusType.HEAL_ON_WIN: return "神圣祝福"
		_: return "未知"
