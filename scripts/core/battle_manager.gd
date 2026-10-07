## 21点对战管理器
## 管理单小局的对战流程：发牌、玩家行动、庄家行动、结算
## 已集成：CombatStatus 状态系统、EnemyMechanics 敌人机制、道具激活、陷阱牌/强制抽牌/复活
class_name BattleManager
extends RefCounted

## 对战阶段
enum Phase {
	SELECT_STANCE,    # 选择姿态
	DEALING,          # 发牌
	PLAYER_TURN,      # 玩家回合
	DEALER_TURN,      # 庄家回合
	ROUND_RESULT,     # 小局结算
	BATTLE_OVER,      # 对战结束
}

## 玩家行动
enum PlayerAction {
	HIT,       # 要牌
	STAND,     # 停牌
	DOUBLE,    # 加倍（仅首2张时）
	SPLIT,     # 分牌（仅首2张同点）
}

# === 平衡性配置 ===
const MAX_PLAYER_CARDS: int = 5   # 玩家最多持牌数（初始2张+最多要3张）
const MAX_DEALER_CARDS: int = 5   # 庄家最多持牌数

# === 当前状态 ===
var phase: Phase = Phase.SELECT_STANCE
var deck: Deck
var player_cards: Array[Deck.Card] = []
var dealer_cards: Array[Deck.Card] = []
var player_stance: StanceData.StanceType = StanceData.StanceType.BALANCED
var dealer_stance: StanceData.StanceType = StanceData.StanceType.BALANCED
var has_doubled: bool = false
var is_player_turn: bool = false

# === 战斗系统 ===
var player_status: CombatStatus = CombatStatus.new()
var enemy_status: CombatStatus = CombatStatus.new()
var mechanics: EnemyMechanics = EnemyMechanics.new()
var current_enemy_data: EnemyData = null

# === 本小局追踪（供机制读取）===
var player_took_damage_this_round: bool = false
var player_dealt_damage_this_round: bool = false
var _player_damage_taken_this_round: float = 0.0
var last_round_winner: int = 0        # 0=平局 1=玩家 2=敌方
var _battle_round_count: int = 0
var enemy_dmg_bonus: float = 0.0       # 本小局敌方伤害加成（来自机制）

# === 机制控制标志 ===
var _enemy_immune_bust: bool = false
var _next_round_force_aggressive: bool = false
var _next_round_enemy_bonus: float = 0.0
var _next_draw_forced_value: int = -1   # 咒术师：下张要牌强制点数
var _trap_active: bool = false
var _force_player_bust: bool = false
var _player_has_busted: bool = false       # 玩家已爆牌（延迟结算，允许用道具/王牌）
var _player_blackjack_hit: bool = false
var _void_swap_pending: bool = false
var _battle_started: bool = false
var _re_double_used: bool = false
var _last_drawn_card: Deck.Card = null

# === 王牌效果（本小局）===
var _trump_attack_bonus: float = 0.0    # 攻击牌加成（如 0.25 = +25%伤害）
var _trump_defense_reduction: float = 0.0  # 防御牌减伤（如 0.25 = -25%受伤）

# === 道具使用计数 ===
var _items_used: Dictionary = {}

func _init() -> void:
	deck = Deck.new()

## 设置敌方数据并开始追踪
func set_enemy(data: EnemyData) -> void:
	current_enemy_data = data
	GameState.setup_enemy_from_data(data)

## 开始一小局
func start_round() -> void:
	deck.reset()
	player_cards.clear()
	dealer_cards.clear()
	has_doubled = false
	_re_double_used = false
	player_status.clear_transient()
	enemy_status.clear_transient()

	# 重置本局追踪
	player_took_damage_this_round = false
	player_dealt_damage_this_round = false
	_player_damage_taken_this_round = 0.0
	last_round_winner = 0
	_force_player_bust = false
	_player_has_busted = false
	_player_blackjack_hit = false
	_next_draw_forced_value = -1
	GameState.last_shield_break = 0.0
	_items_used.clear()

	phase = Phase.SELECT_STANCE
	_reset_trump_bonuses()

	# 对战开始钩子（仅一次）
	if not _battle_started and current_enemy_data != null:
		mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.BATTLE_START)
		_battle_started = true

	EventBus.round_started.emit(GameState.current_round)
	_need_stance_input()

## 设置姿态（玩家选择后调用）
func set_player_stance(stance: StanceData.StanceType) -> void:
	var final_stance: StanceData.StanceType = stance

	# 冻结/强制姿态覆盖
	if player_status.has_status(CombatStatus.StatusType.FREEZE):
		final_stance = StanceData.StanceType.DEFENSIVE
	elif player_status.has_status(CombatStatus.StatusType.FORCED_STANCE):
		var st := player_status.get_status(CombatStatus.StatusType.FORCED_STANCE)
		final_stance = st.stance as StanceData.StanceType

	# 熔岩猎犬：下一局强制全力进攻
	if _next_round_force_aggressive:
		final_stance = StanceData.StanceType.AGGRESSIVE
		_next_round_force_aggressive = false
		enemy_dmg_bonus += _next_round_enemy_bonus
		_next_round_enemy_bonus = 0.0

	player_stance = final_stance

	# 敌方随机选择姿态（简化版）
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var stances := [StanceData.StanceType.DEFENSIVE, StanceData.StanceType.BALANCED, StanceData.StanceType.AGGRESSIVE]
	dealer_stance = stances[rng.randi_range(0, 2)]

	EventBus.stance_selected.emit(player_stance)
	_deal_initial()

	# 小局开始钩子（发牌后）
	_battle_round_count += 1
	enemy_dmg_bonus = 0.0
	if current_enemy_data != null:
		mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.ROUND_START)

## 发初始牌
func _deal_initial() -> void:
	phase = Phase.DEALING

	# 玩家两张明牌
	player_cards.append(deck.draw_card(true))
	player_cards.append(deck.draw_card(true))
	# 庄家一明一暗
	dealer_cards.append(deck.draw_card(true))
	dealer_cards.append(deck.draw_card(false))

	EventBus.hand_changed.emit(player_cards)

	# 检查黑杰克 —— 开局黑杰克不直接结算，避免"发牌即胜利"
	# 改为：开局21点仅自动停牌，仍需走过正常结算流程
	var player_result := HandEvaluator.evaluate(player_cards)
	var dealer_result := HandEvaluator.evaluate(dealer_cards)

	# 开局不触发黑杰克速通：即使21点也进入玩家回合
	if HandEvaluator.best_value(player_cards) == 21:
		# 自动停牌但不结算，让玩家看到自己的牌
		pass

	# 进入玩家回合
	phase = Phase.PLAYER_TURN
	is_player_turn = true

	# 检查强制庄家多抽（法师技能2"诅咒爆牌"）
	_apply_force_dealer_draw()

## 玩家行动
func player_action(action: PlayerAction) -> bool:
	if phase != Phase.PLAYER_TURN or not is_player_turn:
		return false

	match action:
		PlayerAction.HIT:
			return _player_hit()
		PlayerAction.STAND:
			return _player_stand()
		PlayerAction.DOUBLE:
			return _player_double()
		PlayerAction.SPLIT:
			return _player_split()
	return false

## 玩家要牌
func _player_hit() -> bool:
	if phase != Phase.PLAYER_TURN or not is_player_turn:
		return false

	# 牌数上限：最多3张（初始2张+最多要1张），严格限制
	if player_cards.size() >= MAX_PLAYER_CARDS:
		EventBus.battle_log.emit("已达最大牌数(%d张)，自动停牌" % MAX_PLAYER_CARDS)
		return _player_stand()

	# 幸运硬币：会爆牌则自动停牌
	if player_status.has_status(CombatStatus.StatusType.AUTO_STAND_BUST):
		var pr := HandEvaluator.evaluate(player_cards)
		if pr.best_value >= 12:
			return _player_stand()

	var card: Deck.Card = deck.draw_card(true)
	if card == null:
		return false

	# 咒术师：强制下张为10点
	if _next_draw_forced_value >= 0:
		card.rank = CardData.Rank.TEN
		_next_draw_forced_value = -1

	player_cards.append(card)
	_last_drawn_card = card
	EventBus.hand_changed.emit(player_cards)
	EventBus.card_drawn.emit(card.display_name(), true)

	# 二次保险：抽牌后立即检查牌数上限（防止绕过）
	if player_cards.size() >= MAX_PLAYER_CARDS:
		EventBus.battle_log.emit("已满%d张牌，自动停牌" % MAX_PLAYER_CARDS)

	# 抽牌钩子（荆棘/灼烧/陷阱）
	if current_enemy_data != null:
		mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.PLAYER_DRAW)

	# 陷阱强制爆牌 → 延迟结算
	if _force_player_bust:
		_force_player_bust = false
		_player_has_busted = true
		EventBus.player_busted.emit()
		return true

	# 检查是否爆牌 → 设标志位但不立即结算（允许玩家用道具/王牌）
	if HandEvaluator.is_busted(player_cards):
		_player_has_busted = true
		EventBus.player_busted.emit()
		if current_enemy_data != null:
			mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.PLAYER_BUST)
		return true

	# 检查21点自动停牌
	if HandEvaluator.best_value(player_cards) == 21:
		_player_stand()
	return true

## 预抽2张牌供玩家选择（不加入手牌，返回两张牌）
## 用于"抽牌二选一"机制
func draw_two_for_choice() -> Array:
	var result: Array[Deck.Card] = []
	if phase != Phase.PLAYER_TURN or not is_player_turn:
		return result
	if player_cards.size() >= MAX_PLAYER_CARDS:
		return result

	# 抽第1张
	var card1: Deck.Card = deck.draw_card(true)
	if card1 == null:
		return result

	# 抽第2张
	var card2: Deck.Card = deck.draw_card(true)
	if card2 == null:
		# 牌堆只有1张时，直接返回这张
		result.append(card1)
		return result

	result.append(card1)
	result.append(card2)
	return result

## 玩家确认选择后，将选中的牌加入手牌
func confirm_choice_card(card: Deck.Card) -> bool:
	if player_cards.size() >= MAX_PLAYER_CARDS:
		return false
	player_cards.append(card)
	_last_drawn_card = card
	EventBus.hand_changed.emit(player_cards)
	EventBus.card_drawn.emit(card.display_name(), true)

	# 检查是否爆牌 → 设标志位，不立即结算
	if HandEvaluator.is_busted(player_cards):
		_player_has_busted = true
		EventBus.player_busted.emit()
		return true

	# 达到上限自动停牌
	if player_cards.size() >= MAX_PLAYER_CARDS:
		EventBus.battle_log.emit("已满%d张牌，自动停牌" % MAX_PLAYER_CARDS)
		_player_stand()
		return true

	return true

## 换牌：弃掉手牌中指定位置的牌，从牌堆重抽1张补回原位
## [param index] 要替换的手牌下标
## returns: 新抽到的牌；下标无效/非玩家回合/牌堆空返回 null
func redraw_player_card(index: int) -> Deck.Card:
	if phase != Phase.PLAYER_TURN or not is_player_turn:
		return null
	if index < 0 or index >= player_cards.size():
		return null

	var new_card: Deck.Card = deck.draw_card(true)
	if new_card == null:
		return null

	# 旧牌进弃牌堆，新牌补回原位
	deck.discard_card(player_cards[index])
	player_cards[index] = new_card
	_last_drawn_card = new_card
	EventBus.hand_changed.emit(player_cards)
	EventBus.card_drawn.emit(new_card.display_name(), true)

	# 抽牌钩子（荆棘/灼烧/陷阱）
	if current_enemy_data != null:
		mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.PLAYER_DRAW)

	# 换来的牌若直接爆牌 → 延迟结算（允许用道具/王牌）
	if HandEvaluator.is_busted(player_cards):
		_player_has_busted = true
		EventBus.player_busted.emit()
		return new_card

	# 凑到21点自动停牌
	if HandEvaluator.best_value(player_cards) == 21:
		_player_stand()
	return new_card

## 玩家停牌
func _player_stand() -> bool:
	if phase != Phase.PLAYER_TURN:
		return false
	is_player_turn = false

	# 晶簇蜘蛛：停牌后强制额外抽牌
	if current_enemy_data != null:
		mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.PLAYER_STAND)

	_dealer_reveal()
	_dealer_play()
	_resolve_round()
	return true

## 玩家加倍
func _player_double() -> bool:
	# 普通加倍：仅首2张；肾上腺素：允许已加倍后再加一次（此时3张）
	# 但不能超过最大牌数限制
	var allowed := (player_cards.size() == 2) or \
		(player_status.has_status(CombatStatus.StatusType.RE_DOUBLE) and player_cards.size() == 3 and MAX_PLAYER_CARDS > 3)
	if not allowed:
		return false

	if player_cards.size() == 2:
		has_doubled = true
	else:
		# 二次加倍（肾上腺素）
		player_status.consume_once(CombatStatus.StatusType.RE_DOUBLE)
		_re_double_used = true

	var card: Deck.Card = deck.draw_card(true)
	if card == null:
		return false

	if _next_draw_forced_value >= 0:
		card.rank = CardData.Rank.TEN
		_next_draw_forced_value = -1

	player_cards.append(card)
	_last_drawn_card = card
	EventBus.hand_changed.emit(player_cards)
	EventBus.card_drawn.emit(card.display_name(), true)

	if current_enemy_data != null:
		mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.PLAYER_DRAW)

	if _force_player_bust:
		_force_player_bust = false
		_player_has_busted = true
		EventBus.player_busted.emit()
		return true

	if HandEvaluator.is_busted(player_cards):
		_player_has_busted = true
		EventBus.player_busted.emit()
		if current_enemy_data != null:
			mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.PLAYER_BUST)
		return true

	# 未爆牌：加倍后强制停牌（标准21点规则：加倍=抽1张+不能再要牌）
	_player_stand()
	return true

## 分牌（简化：暂不实现完整分牌逻辑）
func _player_split() -> bool:
	if player_cards.size() != 2:
		return false
	if player_cards[0].rank != player_cards[1].rank:
		return false
	push_warning("分牌功能将在后续版本实现")
	return false

## 庄家亮暗牌
func _dealer_reveal() -> void:
	for card in dealer_cards:
		card.face_up = true
	EventBus.hand_changed.emit(dealer_cards)

## 应用强制庄家多抽效果（法师技能2"诅咒爆牌"）
## 检查 enemy_status 的 FORCE_DRAW 状态，让庄家额外抽 N 张牌
func _apply_force_dealer_draw() -> void:
	var fd := enemy_status.get_status(CombatStatus.StatusType.FORCE_DRAW)
	if fd == null or fd.used:
		return

	var extra_count: int = int(fd.value)
	if extra_count <= 0:
		return

	for i in range(extra_count):
		if dealer_cards.size() >= MAX_DEALER_CARDS:
			break
		var card: Deck.Card = deck.draw_card(true)
		if card == null:
			break
		dealer_cards.append(card)
		EventBus.hand_changed.emit(dealer_cards)
		EventBus.card_drawn.emit(card.display_name(), true)
		EventBus.battle_log.emit("🔮 诅咒爆牌：庄家被迫抽取 [%s]" % card.display_name())

	# 标记为已消耗并移除（单次触发）
	fd.used = true
	enemy_status.remove_status(CombatStatus.StatusType.FORCE_DRAW)

## 庄家自动要牌（软17必叫；水晶魔像免疫一次爆牌）
func _dealer_play() -> void:
	phase = Phase.DEALER_TURN

	# 检查强制庄家多抽（法师技能2"诅咒爆牌"）
	_apply_force_dealer_draw()

	while true:
		var result := HandEvaluator.evaluate(dealer_cards)

		# 爆牌判定（含免疫）
		if result.is_busted:
			if _enemy_immune_bust:
				_enemy_immune_bust = false
			break

		# 牌数上限（平衡性限制）
		if dealer_cards.size() >= MAX_DEALER_CARDS:
			break

		# 软17必叫
		var has_soft_17 := false
		if result.ace_count > 0 and result.total_min == 7 and result.total_max == 17:
			has_soft_17 = true

		if result.best_value >= 16 and not has_soft_17:  # 庄家停牌线(原14→16)：更有压迫感但仍会爆牌
			break

		var card: Deck.Card = deck.draw_card(true)
		if card == null:
			break
		dealer_cards.append(card)
		EventBus.hand_changed.emit(dealer_cards)
		EventBus.card_drawn.emit(card.display_name(), true)

## 获取当前预计伤害（正数=对敌造成，负数=自己受到，0=平局）
## 可在玩家回合随时调用，用于UI实时预览
func get_predicted_damage() -> float:
	# 如果牌太少无法预测
	if player_cards.size() < 2:
		return 0.0
	return _calculate_damage()
func _calculate_damage() -> float:
	var player_result := HandEvaluator.evaluate(player_cards)
	var dealer_result := HandEvaluator.evaluate(dealer_cards)

	var player_config := StanceData.get_stance(player_stance)
	var dealer_config := StanceData.get_stance(dealer_stance)

	# 玩家增益（力量药水）
	var p_buff := 0.0
	var pst := player_status.get_status(CombatStatus.StatusType.DAMAGE_BUFF)
	if pst != null:
		p_buff = pst.value

	# 情况1: 玩家爆牌
	if player_result.is_busted:
		var dmg := GameState.enemy_base_damage + enemy_dmg_bonus
		dmg *= player_config.lose_multiplier
		dmg *= dealer_config.enemy_multiplier
		# 防御牌减伤（即使爆牌也生效）
		dmg *= (1.0 - _trump_defense_reduction)
		return -dmg

	# 情况2: 敌方爆牌
	if dealer_result.is_busted:
		var dmg := GameState.player_base_damage + p_buff
		dmg *= player_config.win_multiplier
		dmg *= dealer_config.lose_multiplier
		# 攻击牌加成
		dmg *= (1.0 + _trump_attack_bonus)
		if has_doubled:
			dmg *= 1.5
		return dmg

	# 情况3: 均未爆牌，比较点数
	var p_val := player_result.best_value
	var d_val := dealer_result.best_value

	if p_val == d_val:
		# 特殊规则：玩家Blackjack(2牌21点) 赢 庄家普通21点(3+牌)
		if player_result.is_blackjack and not dealer_result.is_blackjack:
			var bj_dmg := (GameState.player_base_damage + p_buff) * player_config.win_multiplier * dealer_config.lose_multiplier
			bj_dmg *= (1.0 + _trump_attack_bonus)
			if has_doubled:
				bj_dmg *= 1.5
			bj_dmg += 3.0  # BlackJack bonus
			return bj_dmg
		return 0.0

	var is_player_win := p_val > d_val
	var point_diff: int = absi(p_val - d_val)

	# 黑杰克额外奖励
	var blackjack_bonus := 0.0
	if player_result.is_blackjack:
		blackjack_bonus = 3.0

	# 基础伤害（含机制加成）
	var base_damage := 0.0
	if is_player_win:
		base_damage = GameState.player_base_damage + p_buff
	else:
		base_damage = GameState.enemy_base_damage + enemy_dmg_bonus

	# 伤害公式（点数差倍率 0.15→0.18：领先越多伤害越高）
	var raw_damage := base_damage * (1.0 + point_diff * 0.18)

	if is_player_win:
		raw_damage *= player_config.win_multiplier
		raw_damage *= dealer_config.lose_multiplier
		# 攻击牌：胜利时额外加成
		raw_damage *= (1.0 + _trump_attack_bonus)
	else:
		raw_damage *= player_config.lose_multiplier
		raw_damage *= dealer_config.enemy_multiplier
		# 防御牌：受伤时减少
		raw_damage *= (1.0 - _trump_defense_reduction)

	if has_doubled and is_player_win:
		raw_damage *= 1.5

	raw_damage += blackjack_bonus

	return raw_damage if is_player_win else -raw_damage

## 结算小局
func _resolve_round() -> void:
	phase = Phase.ROUND_RESULT
	var damage := _calculate_damage()
	var result_text: String

	if damage > 0:
		last_round_winner = 1
		var pr := HandEvaluator.evaluate(player_cards)
		if pr.is_blackjack:
			_player_blackjack_hit = true
		var dealt := _deal_enemy_damage(damage)
		result_text = "你赢了！造成 %.1f 点伤害！" % dealt
	elif damage < 0:
		last_round_winner = 2
		var dmg_abs := absf(damage)
		var taken := _deal_player_damage(dmg_abs)
		result_text = "你输了！受到 %.1f 点伤害！" % taken
	else:
		last_round_winner = 0
		result_text = "平局！"

	EventBus.round_result.emit(result_text, damage)

	# 小结结算钩子
	if current_enemy_data != null:
		mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.ROUND_RESOLVE)

	# 状态回合递减
	player_status.tick_round_end()
	enemy_status.tick_round_end()

	# 检查对战是否结束
	if GameState.enemy_health <= 0.0:
		phase = Phase.BATTLE_OVER
		if current_enemy_data != null:
			mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.BATTLE_END)
		EventBus.battle_ended.emit(true)
	elif GameState.player_health <= 0.0:
		phase = Phase.BATTLE_OVER
		EventBus.battle_ended.emit(false)

## 对敌方造成伤害（含机制：减伤/黑杰克双倍），返回实际造成的伤害
func _deal_enemy_damage(amount: float) -> float:
	var dmg := amount

	# 古树守卫：敌方单次减伤
	var reduce := enemy_status.get_status(CombatStatus.StatusType.ENEMY_ONCE_REDUCE)
	if reduce != null and not reduce.used:
		dmg = maxf(0.0, dmg - reduce.value)
		reduce.used = true

	# 防止敌方减伤机制把伤害完全吞掉（保持"减伤"而非"免伤"）
	if amount > 0.0 and dmg <= 0.0:
		dmg = 1.0

	# 幻光独角仙：被黑杰克命中受双倍伤害
	if current_enemy_data != null and current_enemy_data.mechanic_id == EnemyData.MechanicID.PHANTOM_UNICORN and _player_blackjack_hit:
		dmg *= 2.0

	GameState.enemy_take_damage(dmg)
	player_dealt_damage_this_round = true

	if current_enemy_data != null:
		mechanics.apply(current_enemy_data.mechanic_id, self, EnemyMechanics.Hook.ENEMY_DAMAGED)

	return dmg

## 对玩家造成伤害（含机制：铁壁/护盾击破/回生），返回实际受到的伤害
func _deal_player_damage(amount: float) -> float:
	var dmg := amount

	# 铁壁药水：本小局受伤-
	var red := player_status.get_status(CombatStatus.StatusType.DAMAGE_REDUCE)
	if red != null:
		dmg = maxf(0.0, dmg - red.value)

	# 防止减伤把伤害完全吞掉（保持"减伤"而非"免伤"）
	if amount > 0.0 and dmg <= 0.0:
		dmg = 1.0

	# 回生羽毛：死亡复活一次
	if dmg >= GameState.player_health and player_status.has_status(CombatStatus.StatusType.REVIVE):
		player_status.consume_once(CombatStatus.StatusType.REVIVE)
		player_status.purge_negative()
		GameState.player_health = GameState.player_max_health * 0.3
		EventBus.health_changed.emit("player", GameState.player_health, GameState.player_max_health)
		EventBus.battle_log.emit("回生羽毛触发！恢复30%生命")
		return 0.0

	GameState.player_take_damage(dmg)
	player_took_damage_this_round = true
	_player_damage_taken_this_round += dmg

	# 暗影聚合体：击破护盾额外强扣等量生命
	if GameState.last_shield_break > 0.0 and current_enemy_data != null and current_enemy_data.mechanic_id == EnemyData.MechanicID.SHADOW_AGGREGATE:
		var extra := GameState.last_shield_break
		GameState.last_shield_break = 0.0
		GameState.player_take_damage(extra)

	return dmg

## 使用道具（返回是否成功）
func use_item(item: BattleItemData) -> bool:
	if item == null:
		return false

	# 每小局限制
	var used := _items_used.get(item.item_name, 0) as int
	if used >= item.max_per_round:
		return false
	_items_used[item.item_name] = used + 1

	match item.effect_type:
		"heal":
			GameState.player_heal(item.effect_value)
		"shield":
			GameState.add_player_shield(item.effect_value)
			player_status.add_status(CombatStatus.StatusType.SHIELD_DURATION, item.effect_value, item.effect_duration)
		"purge":
			player_status.purge_negative()
		"damage_buff":
			player_status.add_status(CombatStatus.StatusType.DAMAGE_BUFF, item.effect_value, 0)
		"damage_reduce":
			player_status.add_status(CombatStatus.StatusType.DAMAGE_REDUCE, item.effect_value, 0)
		"peek_stance":
			player_status.add_status(CombatStatus.StatusType.PEEK, 0.0, 0)
		"auto_stand_bust":
			player_status.add_status(CombatStatus.StatusType.AUTO_STAND_BUST, 0.0, 0)
		"re_double":
			player_status.add_status(CombatStatus.StatusType.RE_DOUBLE, 0.0, 0)
		"fire_damage_burn":
			GameState.force_player_damage(item.effect_value)
			player_status.add_status(CombatStatus.StatusType.BURN, 1.0, item.effect_duration)
		"freeze":
			player_status.add_status(CombatStatus.StatusType.FREEZE, 0.0, item.effect_duration)
		"revive":
			player_status.add_status(CombatStatus.StatusType.REVIVE, item.effect_value, 99)
		"redraw_card", "redraw_card_auto":
			# 实际换牌由 battle_scene 触发UI完成；此处仅登记使用次数
			pass
		_:
			push_warning("未知道具效果: " + item.effect_type)
			return false

	EventBus.battle_log.emit("使用道具：%s" % item.item_name)
	EventBus.item_used.emit(item.item_name)
	return true

## 获取对战状态文本
func get_status_text() -> String:
	match phase:
		Phase.SELECT_STANCE:
			return "选择姿态"
		Phase.DEALING:
			return "发牌中..."
		Phase.PLAYER_TURN:
			return "你的回合 - 要牌/停牌/加倍"
		Phase.DEALER_TURN:
			return "庄家回合..."
		Phase.ROUND_RESULT:
			return "结算中..."
		Phase.BATTLE_OVER:
			return "战斗结束"
	return ""

func _need_stance_input() -> void:
	pass

## 获取手牌显示字符串
func _cards_to_display(cards: Array[Deck.Card], show_all: bool = true) -> String:
	if cards.is_empty():
		return "空"
	var strs: Array[String] = []
	for card in cards:
		if show_all or card.face_up:
			strs.append(card.display_name())
		else:
			strs.append("??")
	var packed := PackedStringArray(strs)
	return " ".join(packed)

## 获取显示用描述（玩家手牌，考虑迷雾）
func get_player_hand_description() -> String:
	var hide_idx := -1
	var hide := player_status.get_status(CombatStatus.StatusType.HIDE_CARD)
	if hide != null:
		hide_idx = int(hide.value)
	var parts: Array[String] = []
	var i := 0
	for card in player_cards:
		if i == hide_idx:
			parts.append("??")
		else:
			parts.append(card.display_name())
		i += 1
	var packed := PackedStringArray(parts)
	var result := HandEvaluator.evaluate(player_cards)
	return " ".join(packed) + "  [点数: %d]" % result.best_value

## 获取显示用描述（庄家手牌，考虑致盲）
func get_dealer_hand_description() -> String:
	if player_status.has_status(CombatStatus.StatusType.BLIND):
		return "?? ?? (致盲)"
	return _cards_to_display(dealer_cards, false)

## 玩家可见敌方姿态？（偷窥眼镜）
func can_peek_stance() -> bool:
	return player_status.has_status(CombatStatus.StatusType.PEEK)

## 设置本小局王牌效果
func set_active_trump_bonus(bonus_type: String, value: float) -> void:
	match bonus_type:
		"attack":
			_trump_attack_bonus = value
		"defense":
			_trump_defense_reduction = value

## 重置本小局王牌效果（每小局开始时调用）
func _reset_trump_bonuses() -> void:
	_trump_attack_bonus = 0.0
	_trump_defense_reduction = 0.0
