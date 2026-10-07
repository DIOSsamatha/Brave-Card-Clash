## 敌人机制分发器
## 每个机制对应 EnemyData.MechanicID 的一个值
## apply(id, battle, hook) 在战斗钩子点被调用
class_name EnemyMechanics
extends RefCounted

## 钩子点
enum Hook {
	BATTLE_START,    # 对战开始（仅一次）
	ROUND_START,     # 小局开始（发牌后）
	PLAYER_DRAW,     # 玩家抽到一张牌
	PLAYER_STAND,    # 玩家停牌
	PLAYER_BUST,     # 玩家爆牌
	ROUND_RESOLVE,   # 小局结算
	PLAYER_DAMAGED,  # 玩家受到伤害
	ENEMY_DAMAGED,  # 敌方受到伤害
	BATTLE_END,      # 对战结束（敌方死亡）
}

## 局部随机
func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r

## 主分发
func apply(id: int, battle: BattleManager, hook: int) -> void:
	match id:
		EnemyData.MechanicID.SPROUT_HEAL:
			_apply_sprout_heal(battle, hook)
		EnemyData.MechanicID.THORN_VINE:
			_apply_thorn_vine(battle, hook)
		EnemyData.MechanicID.MISCHIEF_SPRITE:
			_apply_mischief_sprite(battle, hook)
		EnemyData.MechanicID.ANCIENT_GUARD:
			_apply_ancient_guard(battle, hook)
		EnemyData.MechanicID.PHANTOM_UNICORN:
			_apply_phantom_unicorn(battle, hook)
		EnemyData.MechanicID.CRYSTAL_SPIDER:
			_apply_crystal_spider(battle, hook)  # 注：已移除停牌强制抽牌，保留钩子位置以便后续设计新机制
		EnemyData.MechanicID.ECHO_BAT:
			_apply_echo_bat(battle, hook)
		EnemyData.MechanicID.CRYSTAL_MINER:
			_apply_crystal_miner(battle, hook)
		EnemyData.MechanicID.CRYSTAL_GOLEM:
			_apply_crystal_golem(battle, hook)
		EnemyData.MechanicID.PRISM_MAGE:
			_apply_prism_mage(battle, hook)
		EnemyData.MechanicID.TORCH_WARRIOR:
			_apply_torch_warrior(battle, hook)
		EnemyData.MechanicID.FLAME_WIZARD:
			_apply_flame_wizard(battle, hook)
		EnemyData.MechanicID.LAVA_HOUND:
			_apply_lava_hound(battle, hook)
		EnemyData.MechanicID.FIRE_WING_KNIGHT:
			_apply_fire_wing_knight(battle, hook)
		EnemyData.MechanicID.PAIN_WARLOCK:
			_apply_pain_warlock(battle, hook)
		EnemyData.MechanicID.SHADOW_BOOK:
			_apply_shadow_book(battle, hook)
		EnemyData.MechanicID.SILENCE_MASK:
			_apply_silence_mask(battle, hook)
		EnemyData.MechanicID.VOID_SHADOW:
			_apply_void_shadow(battle, hook)
		EnemyData.MechanicID.CURATOR_SOUL:
			_apply_curator_soul(battle, hook)
		EnemyData.MechanicID.SHADOW_AGGREGATE:
			_apply_shadow_aggregate(battle, hook)
		EnemyData.MechanicID.HEAVY_GUARD:
			_apply_heavy_guard(battle, hook)
		EnemyData.MechanicID.CURSE_MAGE:
			_apply_curse_mage(battle, hook)
		EnemyData.MechanicID.DEMON_HOUND:
			_apply_demon_hound(battle, hook)
		EnemyData.MechanicID.GUARD_KNIGHT:
			_apply_guard_knight(battle, hook)

# === 第1层：妖精幻境 ===

# 嫩芽妖精：每局未受伤则回复3点生命值
func _apply_sprout_heal(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_RESOLVE and not battle.player_took_damage_this_round:
		GameState.enemy_heal(3.0)
		EventBus.battle_log.emit("%s 未受伤，回复3点生命" % battle.current_enemy_data.enemy_name)

# 荆棘藤蔓：要牌时有20%几率点数额外+1
func _apply_thorn_vine(battle: BattleManager, hook: int) -> void:
	if hook == Hook.PLAYER_DRAW and battle._last_drawn_card != null:
		var r := _rng()
		if r.randf() < 0.2:
			var c := battle._last_drawn_card
			if c.rank < CardData.Rank.KING:
				c.rank = (c.rank as int + 1) as CardData.Rank
			EventBus.hand_changed.emit(battle.player_cards)
			EventBus.battle_log.emit("荆棘藤蔓：一张牌点数额外+1")

# 恶作剧花精：隐藏玩家一张手牌的点数显示
func _apply_mischief_sprite(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		if not battle.player_status.has_status(CombatStatus.StatusType.HIDE_CARD):
			var idx := 0
			if battle.player_cards.size() > 0:
				var r := _rng()
				idx = r.randi_range(0, battle.player_cards.size() - 1)
			battle.player_status.add_status(CombatStatus.StatusType.HIDE_CARD, float(idx), 0)

# 古树守卫：玩家爆牌时额外强扣2点；拥有1次单次减伤2点
func _apply_ancient_guard(battle: BattleManager, hook: int) -> void:
	if hook == Hook.BATTLE_START:
		battle.enemy_status.add_status(CombatStatus.StatusType.ENEMY_ONCE_REDUCE, 2.0, 99)
	if hook == Hook.PLAYER_BUST:
		GameState.force_player_damage(2.0)
		EventBus.battle_log.emit("%s 触发：爆牌额外强扣2点" % battle.current_enemy_data.enemy_name)

# 幻光独角仙：胜利时50%致盲；被黑杰克命中时受到双倍伤害
func _apply_phantom_unicorn(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_RESOLVE and battle.last_round_winner == 1:
		var r := _rng()
		if r.randf() < 0.5:
			battle.player_status.add_status(CombatStatus.StatusType.BLIND, 0.0, 0)
			EventBus.battle_log.emit("%s 致盲了你！看不见敌方明牌" % battle.current_enemy_data.enemy_name)

# === 第2层：水晶幻境 ===

# 晶簇蜘蛛：停牌强制抽牌已移除（玩家要求"停牌就结算"，不再在停牌时塞牌）
# 保留钩子位置，后续可在此接入不破坏停牌结算的新机制（如回合开始自身增益等）
func _apply_crystal_spider(_battle: BattleManager, _hook: int) -> void:
	# 停牌强制抽牌已移除：停牌即进入庄家行动与结算，不在停牌时塞牌
	# 保留钩子位置，后续可在此接入不破坏停牌结算的新机制（如回合开始自身增益等）
	pass

# 回声蝙蝠：玩家点数≥18时，反震1点伤害给玩家
func _apply_echo_bat(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_RESOLVE:
		var pr := HandEvaluator.evaluate(battle.player_cards)
		if pr.best_value >= 18:
			GameState.force_player_damage(1.0)
			EventBus.battle_log.emit("回声蝙蝠反震1点伤害！")

# 掘晶矿工：开场自带4点护盾，护盾存在时受伤-1（伤害减免在伤害辅助函数处理）
func _apply_crystal_miner(battle: BattleManager, hook: int) -> void:
	if hook == Hook.BATTLE_START:
		GameState.add_enemy_shield(4.0)

# 水晶魔像：每3局免疫一次爆牌；死亡时强扣玩家5点
func _apply_crystal_golem(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		if battle._battle_round_count % 3 == 0:
			battle._enemy_immune_bust = true
	if hook == Hook.BATTLE_END:
		GameState.force_player_damage(5.0)
		EventBus.battle_log.emit("%s 碎裂，强扣你5点生命！" % battle.current_enemy_data.enemy_name)

# 棱镜术士：牌堆洗入「分身」陷阱，玩家抽到即爆牌并受3点伤害
func _apply_prism_mage(battle: BattleManager, hook: int) -> void:
	if hook == Hook.BATTLE_START:
		battle._trap_active = true
	if hook == Hook.PLAYER_DRAW and battle._trap_active:
		var r := _rng()
		if r.randf() < 0.25:
			battle._trap_active = false
			battle._force_player_bust = true
			GameState.force_player_damage(3.0)
			EventBus.battle_log.emit("分身陷阱！直接爆牌并受到3点伤害")

# === 第3层：火焰幻境 ===

# 火把战士：玩家选「全力进攻」时，自身基础伤害+2（本小局）
func _apply_torch_warrior(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		if battle.player_stance == StanceData.StanceType.AGGRESSIVE:
			battle.enemy_dmg_bonus += 2.0

# 烈焰巫师：附加「灼烧」2局，玩家每抽数字牌损失1点生命
func _apply_flame_wizard(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		battle.player_status.add_status(CombatStatus.StatusType.BURN, 1.0, 2)
	if hook == Hook.PLAYER_DRAW and battle._last_drawn_card != null:
		var c := battle._last_drawn_card
		if c.rank >= CardData.Rank.TWO and c.rank <= CardData.Rank.TEN:
			GameState.force_player_damage(1.0)

# 熔岩猎犬：玩家爆牌后，下一局强制全力进攻且自身伤害+3
func _apply_lava_hound(battle: BattleManager, hook: int) -> void:
	if hook == Hook.PLAYER_BUST:
		battle._next_round_force_aggressive = true
		battle._next_round_enemy_bonus = 3.0

# 火翼骑士：每局结束玩家血量>50%则强扣2点；自身低血回血+攻击
func _apply_fire_wing_knight(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_RESOLVE:
		if GameState.player_health > GameState.player_max_health * 0.5:
			GameState.force_player_damage(2.0)
			EventBus.battle_log.emit("%s 强扣你2点生命！" % battle.current_enemy_data.enemy_name)
	if hook == Hook.ROUND_START:
		if GameState.enemy_health < GameState.enemy_max_health * 0.3:
			GameState.enemy_heal(3.0)
			battle.enemy_dmg_bonus += 2.0

# 痛苦术士：自身受伤时玩家同步损失1点；小局胜利回血量=玩家受到的伤害
func _apply_pain_warlock(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ENEMY_DAMAGED:
		GameState.force_player_damage(1.0)
	if hook == Hook.ROUND_RESOLVE and battle.last_round_winner == 2:
		GameState.enemy_heal(battle._player_damage_taken_this_round)

# === 第4层：暗影幻境 ===

# 暗影书精：小局胜利时随机弃掉玩家一张已装备王牌
func _apply_shadow_book(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_RESOLVE and battle.last_round_winner == 2:
		if GameState.current_trump_hand.size() > 0:
			var r := _rng()
			var idx := r.randi_range(0, GameState.current_trump_hand.size() - 1)
			var card: TrumpCardData = GameState.current_trump_hand[idx] as TrumpCardData
			GameState.current_trump_hand.remove_at(idx)
			var cname: String = "王牌" if card == null else card.card_name
			EventBus.trump_card_removed.emit(cname)
			EventBus.battle_log.emit("%s 弃掉了你的一张王牌！" % battle.current_enemy_data.enemy_name)

# 沉默面具：附加「沉默」1局，禁用玩家主动技能
func _apply_silence_mask(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		battle.player_status.add_status(CombatStatus.StatusType.SILENCE, 0.0, 1)

# 虚无之影：开局随机与玩家交换一张手牌
func _apply_void_shadow(battle: BattleManager, hook: int) -> void:
	if hook == Hook.BATTLE_START:
		battle._void_swap_pending = true
	if hook == Hook.ROUND_START and battle._void_swap_pending:
		battle._void_swap_pending = false
		if battle.player_cards.size() > 0 and battle.dealer_cards.size() > 0:
			var r := _rng()
			var pi := r.randi_range(0, battle.player_cards.size() - 1)
			var di := r.randi_range(0, battle.dealer_cards.size() - 1)
			var tmp := battle.player_cards[pi]
			battle.player_cards[pi] = battle.dealer_cards[di]
			battle.dealer_cards[di] = tmp
			EventBus.hand_changed.emit(battle.player_cards)
			EventBus.battle_log.emit("%s 与你交换了一张手牌！" % battle.current_enemy_data.enemy_name)

# 馆长之魂：每3局封印玩家技能；玩家用王牌越多自身伤害越高（每局封顶+4）
func _apply_curator_soul(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		if battle._battle_round_count % 3 == 0:
			EventBus.battle_log.emit("%s 封印了你一个主动技能！" % battle.current_enemy_data.enemy_name)
		var used := float(GameState.get_total_trumps_used())
		battle.enemy_dmg_bonus += minf(used * 0.5, 4.0)

# 暗影聚合体：击破护盾额外强扣等量生命；玩家单局未造成伤害则回复8点
func _apply_shadow_aggregate(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_RESOLVE and not battle.player_dealt_damage_this_round:
		GameState.enemy_heal(8.0)
		EventBus.battle_log.emit("%s 回复8点生命" % battle.current_enemy_data.enemy_name)

# === 第5层：魔王城前庭 ===

# 重甲魔卫：开场自带5点护盾，护盾存在时免疫负面（护盾减免在伤害函数处理）
func _apply_heavy_guard(battle: BattleManager, hook: int) -> void:
	if hook == Hook.BATTLE_START:
		GameState.add_enemy_shield(5.0)

# 咒术师：强制玩家下一张要牌变为10点
func _apply_curse_mage(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		battle._next_draw_forced_value = 10

# 恶魔猎犬：玩家每损失10点生命，自身基础伤害+1（封顶+4，避免后期爆炸）
func _apply_demon_hound(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		var lost := int(GameState.player_life_lost) / 10
		battle.enemy_dmg_bonus += minf(float(lost), 4.0)

# 近卫骑士：胜利时30%追加3点神圣伤害；每局自动回1点生命
func _apply_guard_knight(battle: BattleManager, hook: int) -> void:
	if hook == Hook.ROUND_START:
		GameState.enemy_heal(1.0)
	if hook == Hook.ROUND_RESOLVE and battle.last_round_winner == 2:
		var r := _rng()
		if r.randf() < 0.3:
			GameState.force_player_damage(3.0)
			EventBus.battle_log.emit("%s 追加3点神圣伤害！" % battle.current_enemy_data.enemy_name)
