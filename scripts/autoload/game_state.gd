## 全局游戏状态
## 管理玩家状态、冒险数据、对战数据等跨场景数据
## 注意：此脚本作为Autoload单例注册名为"GameState"，不要加class_name（会隐藏autoload）
extends Node

# === 玩家基础属性 ===
var player_max_health: float = 30.0
var player_health: float = 30.0
var player_base_damage: float = 4.0
var player_shield: float = 0.0  # 护盾（优先吸收伤害）

# === 敌方数据 ===
var enemy_name: String = ""
var enemy_max_health: float = 20.0
var enemy_health: float = 20.0
var enemy_base_damage: float = 2.0
var enemy_shield: float = 0.0
var current_enemy_data: EnemyData = null  # 当前敌人的完整数据引用（地图场景传入）

# === 战斗追踪（供敌人机制读取）===
var player_life_lost: float = 0.0       # 玩家累计损失生命（恶魔猎犬）
var last_shield_break: float = 0.0       # 本回合击破的护盾量（暗影聚合体）

# === 对局状态 ===
var current_round: int = 0
var is_battle_active: bool = false

# === 冒险数据 ===
var current_tier: int = 0         # 当前层数（0-5）
var gold: int = 0                 # 冒险内金币
var map_seed: int = 0             # 地图种子（同一次冒险不变，保证地图一致）
const MAX_TRUMP_HAND: int = 3      # 王牌战斗手牌上限
const MAX_TOTAL_TRUMPS: int = 6    # 王牌总携带上限（手牌+背包合计）
const MAX_ITEMS: int = 3           # 道具携带上限

# === 血瓶系统（死亡细胞风格）===
const FLASK_BASE_MAX: int = 1      # 初始血瓶携带上限
const FLASK_MAX_CAP: int = 5       # 血瓶携带上限最高5瓶
var flask_max: int = FLASK_BASE_MAX     # 血瓶携带上限（局外用星尘升级）
var flask_current: int = FLASK_BASE_MAX # 当前持有血瓶数
var captain_forms_beaten: int = 0      # 已击败近卫队长的形态数（0-3，第6层解锁条件）
var is_boss_battle: bool = false        # 当前是否为Boss战（影响层数推进逻辑）

# 地图已访问节点持久化（保证从战斗返回后路径保留）
var map_visited: Dictionary = {}    # node_id -> bool
var map_current_node_id: int = -1   # 当前所在节点ID（路径锁定，从战斗返回后恢复）

var trump_bag: Array[TrumpCardData] = []         # 王牌背包（未装备的）
var item_bag: Array[BattleItemData] = []          # 道具袋
var current_trump_hand: Array[TrumpCardData] = [] # 当前装备王牌（最多3张）
var trumps_used_this_round: Dictionary = {}  # trump_card_name -> use_count
var draw_info: String = ""            # 技能提供的看牌信息（如顶牌/暗牌内容）

# === 角色与成长 ===
var selected_character: CharacterData = null  # 完整角色资源（主菜单选择后赋值）
var selected_char_level: int = 1              # 角色等级（存档读取）
var skill_executor: SkillExecutor = null      # 当前冒险的技能执行器实例

# === 全局进度 ===
var progression: ProgressionSystem = ProgressionSystem.new()

func _ready() -> void:
	# 初始化数据
	EnemyDatabase.initialize()
	TrumpCardDatabase.initialize()
	ItemDatabase.initialize()

	# 自动读取存档（恢复星尘、升级等永久进度）
	if SaveSystem.has_save():
		SaveSystem.load_game()

## 重置对战状态（注意：不要在此重置 current_round，它是地图层数追踪器）
func reset_battle() -> void:
	is_battle_active = false
	player_shield = 0.0
	enemy_shield = 0.0
	trumps_used_this_round.clear()
	current_enemy_data = null

## 重置冒险状态（开始新冒险）
func reset_adventure() -> void:
	current_tier = 0
	gold = 0
	map_seed = 0
	trump_bag.clear()
	item_bag.clear()
	current_trump_hand.clear()
	trumps_used_this_round.clear()
	current_round = 0
	flask_max = FLASK_BASE_MAX
	flask_current = FLASK_BASE_MAX
	captain_forms_beaten = 0
	map_visited.clear()
	map_current_node_id = -1
	reset_battle()

## 设置敌方数据
func setup_enemy(name: String, max_hp: float, base_dmg: float) -> void:
	enemy_name = name
	enemy_max_health = max_hp
	enemy_health = max_hp
	enemy_base_damage = base_dmg
	enemy_shield = 0.0

## 设置敌方数据（从EnemyData）
## 按已访问节点数做深度缩放（最多+50%）；使用 duplicate 避免污染共享数据库
func setup_enemy_from_data(data: EnemyData) -> void:
	var scaled := data.duplicate() as EnemyData
	var depth_scale := 1.0 + minf(0.5, float(map_visited.size()) * 0.04)
	scaled.max_health = data.max_health * depth_scale
	scaled.base_damage = data.base_damage * depth_scale
	setup_enemy(scaled.enemy_name, scaled.max_health, scaled.base_damage)
	current_enemy_data = scaled

## 设置玩家数据
func setup_player(max_hp: float, base_dmg: float) -> void:
	player_max_health = max_hp
	player_health = max_hp
	player_base_damage = base_dmg
	player_shield = 0.0

## 设置玩家从角色数据（应用等级加成）
func setup_player_from_character(data: CharacterData, level: int) -> void:
	var hp := data.get_total_health(level)
	var dmg := data.get_total_damage(level)
	# 应用升级加成
	hp += progression.get_upgrade_effect(ProgressionSystem.UpgradeID.START_HP_BONUS)
	dmg += progression.get_upgrade_effect(ProgressionSystem.UpgradeID.START_DAMAGE_BONUS)
	setup_player(hp, dmg)

	selected_character = data
	selected_char_level = level
	skill_executor = SkillExecutor.new(data, level)

	# 触发被动（战斗开始类型）
	_trigger_passive_skills("battle_start")

## 安全触发被动技能（空值保护）
func _trigger_passive_skills(context: String) -> void:
	if skill_executor == null:
		return
	var passive_results: Array = skill_executor.trigger_passive(context)
	for pr in passive_results:
		_apply_skill_result(pr)

## 新游戏选择角色后重置（从主菜单→角色选择过来）
func reset_for_new_run() -> void:
	reset_adventure()
	# 血瓶上限来自局外升级（初始1瓶，最多升级到5瓶）
	flask_max = FLASK_BASE_MAX + int(progression.get_upgrade_effect(ProgressionSystem.UpgradeID.FLASK_CAPACITY))
	flask_max = clampi(flask_max, FLASK_BASE_MAX, FLASK_MAX_CAP)
	flask_current = flask_max
	if selected_character != null:
		setup_player_from_character(selected_character, selected_char_level)
	# 初始化基础王牌牌堆（2攻击+1防御，共3张）
	current_trump_hand = TrumpCardDatabase.get_starter_cards()

## 开始冒险（从养成界面点"开始冒险"）
func start_new_run() -> void:
	progression.total_runs += 1
	reset_for_new_run()
	is_battle_active = true

## 冒险结束（胜利或失败）——调用存档
func end_run(won: bool, stage_reached: int) -> void:
	is_battle_active = false
	if won and stage_reached > progression.best_stage:
		progression.best_stage = stage_reached
	# 胜利奖励星尘
	if won:
		var bonus: int = stage_reached * 10 + 20
		progression.add_star_dust(bonus)
	SaveSystem.save_game()

## 应用技能效果到GameState/BattleManager
func _apply_skill_result(result: SkillResult) -> void:
	match result.effect_type:
		"shield":
			add_player_shield(result.effect_value)
			EventBus.battle_log.emit(result.description)
		"heal":
			player_heal(result.effect_value)
			EventBus.battle_log.emit(result.description)
		"damage_buff":
			player_base_damage += result.effect_value
			EventBus.battle_log.emit(result.description)
		"draw_info":
			draw_info = result.description
			EventBus.battle_log.emit("获得看牌信息")
		"invincible":
			EventBus.battle_log.emit("免疫本局所有伤害与负面效果")
		_:
			if result.description != "":
				EventBus.battle_log.emit("触发: %s" % result.description)

## 玩家受到伤害（护盾优先吸收）
func player_take_damage(amount: float) -> void:
	var remaining: float = amount

	# 先扣护盾
	if player_shield > 0.0:
		var absorbed: float = minf(player_shield, remaining)
		player_shield -= absorbed
		remaining -= absorbed
		# 护盾被击破记录（供暗影聚合体机制）
		if player_shield <= 0.0 and absorbed > 0.0:
			last_shield_break = absorbed

	player_life_lost += remaining
	player_health = maxf(0.0, player_health - remaining)
	EventBus.health_changed.emit("player", player_health, player_max_health)
	if player_health <= 0.0:
		EventBus.player_died.emit()

## 玩家受到强制伤害（无视护盾：强扣/灼烧/反震）
func force_player_damage(amount: float) -> void:
	player_health = maxf(0.0, player_health - amount)
	player_life_lost += amount
	EventBus.health_changed.emit("player", player_health, player_max_health)
	if player_health <= 0.0:
		EventBus.player_died.emit()

## 敌方恢复生命
func enemy_heal(amount: float) -> void:
	enemy_health = minf(enemy_max_health, enemy_health + amount)
	EventBus.health_changed.emit("enemy", enemy_health, enemy_max_health)

## 王牌累计使用数（馆长之魂机制用）
func get_total_trumps_used() -> int:
	var total := 0
	for v in trumps_used_this_round.values():
		total += v as int
	return total

## 敌方受到伤害（护盾优先吸收）
func enemy_take_damage(amount: float) -> void:
	var remaining: float = amount

	if enemy_shield > 0.0:
		var absorbed: float = minf(enemy_shield, remaining)
		enemy_shield -= absorbed
		remaining -= absorbed

	enemy_health = maxf(0.0, enemy_health - remaining)
	EventBus.health_changed.emit("enemy", enemy_health, enemy_max_health)
	if enemy_health <= 0.0:
		EventBus.enemy_died.emit()

## 玩家恢复生命
func player_heal(amount: float) -> void:
	player_health = minf(player_max_health, player_health + amount)
	EventBus.health_changed.emit("player", player_health, player_max_health)

# ============================================================
#  血瓶系统（死亡细胞风格）
# ============================================================

## 单瓶血瓶回复量：当前生命值上限的一半
func get_flask_heal_amount() -> float:
	return player_max_health * 0.5

## 使用一瓶血瓶（地图/Battle外均可）
func use_flask() -> String:
	if flask_current <= 0:
		return "没有可用的血瓶"
	if player_health >= player_max_health:
		return "生命值已满，无需使用血瓶"
	var amt: float = get_flask_heal_amount()
	flask_current -= 1
	player_heal(amt)
	return "使用血瓶：恢复 %.0f 点生命（剩余%d/%d瓶）" % [amt, flask_current, flask_max]

## Boss关过时补充1瓶血瓶
func refill_flask_on_boss() -> void:
	if flask_current < flask_max:
		flask_current += 1

## 直接删除手牌中的一张王牌（永久丢弃）
func delete_trump_from_hand(card: TrumpCardData) -> void:
	var idx: int = current_trump_hand.find(card)
	if idx >= 0:
		var name: String = card.card_name
		current_trump_hand.remove_at(idx)
		EventBus.trump_card_removed.emit(name)

## 添加护盾
func add_player_shield(amount: float) -> void:
	player_shield += amount
	EventBus.health_changed.emit("player", player_health, player_max_health)

func add_enemy_shield(amount: float) -> void:
	enemy_shield += amount

## 王牌总携带数量（背包+手牌）
func get_total_trump_count() -> int:
	return trump_bag.size() + current_trump_hand.size()

## 添加王牌到战斗手牌（上限MAX_TRUMP_HAND张）
func add_trump_to_hand(card: TrumpCardData) -> bool:
	if current_trump_hand.size() >= MAX_TRUMP_HAND:
		return false
	current_trump_hand.append(card)
	return true

## 替换战斗手牌中的一张王牌
func replace_trump_in_hand(old_card: TrumpCardData, new_card: TrumpCardData) -> bool:
	var idx: int = current_trump_hand.find(old_card)
	if idx < 0:
		return false
	current_trump_hand[idx] = new_card
	return true

## 从手牌移除一张王牌（放入背包或直接丢弃）
func remove_trump_from_hand(card: TrumpCardData) -> bool:
	var idx: int = current_trump_hand.find(card)
	if idx < 0:
		return false
	current_trump_hand.remove_at(idx)
	return true

## 将王牌从背包移动到手牌（需手牌有空位）
func equip_trump_from_bag(card: TrumpCardData) -> bool:
	var idx: int = trump_bag.find(card)
	if idx < 0:
		return false
	if current_trump_hand.size() >= MAX_TRUMP_HAND:
		return false
	trump_bag.remove_at(idx)
	current_trump_hand.append(card)
	EventBus.trump_hand_changed.emit(current_trump_hand)
	return true

## 将王牌从手牌卸下到背包（需背包有空间）
func unequip_trump_to_bag(card: TrumpCardData) -> bool:
	var idx: int = current_trump_hand.find(card)
	if idx < 0:
		return false
	current_trump_hand.remove_at(idx)
	trump_bag.append(card)
	EventBus.trump_hand_changed.emit(current_trump_hand)
	return true

## 从背包中删除一张王牌（永久丢弃）
func delete_trump_from_bag(card: TrumpCardData) -> void:
	var idx: int = trump_bag.find(card)
	if idx >= 0:
		var name: String = card.card_name
		trump_bag.remove_at(idx)
		EventBus.trump_card_removed.emit(name)

## 添加王牌到背包（总携带量上限MAX_TOTAL_TRUMPS）
func add_trump_card(card: TrumpCardData) -> bool:
	if get_total_trump_count() >= MAX_TOTAL_TRUMPS:
		return false
	trump_bag.append(card)
	return true

## 添加道具到背包（上限MAX_ITEMS格位，用完即弃）
func add_item(item: BattleItemData) -> bool:
	if item_bag.size() >= MAX_ITEMS:
		return false
	item_bag.append(item)
	return true

## 战后掉落道具（自动添加到背包）
func loot_item(tier_idx: int = 0) -> BattleItemData:
	var item: BattleItemData = ItemDatabase.get_random_item_by_tier(tier_idx)
	if item != null and add_item(item):
		EventBus.battle_log.emit("获得道具: %s" % item.item_name)
		return item
	return null

## 消耗一个道具（使用后移除，可在任何场景调用）
func consume_item(item: BattleItemData) -> void:
	var idx: int = item_bag.find(item)
	if idx >= 0:
		item_bag.remove_at(idx)
		EventBus.item_used.emit(item.item_name)

## 使用道具效果（在战斗外也可使用，如回复类道具在地图使用）
func use_item_effect(item: BattleItemData) -> String:
	var result_text: String = ""
	match item.effect_type:
		"heal":
			player_heal(item.effect_value)
			result_text = "使用%s：恢复%.0f点生命" % [item.item_name, item.effect_value]
		_:
			result_text = "%s只能在战斗中使用" % item.item_name
			return result_text
	consume_item(item)
	return result_text

## 尝试添加王牌（优先手牌→背包→替换提示）
## 返回: true(已添加), false(需要手动处理替换)
func try_add_trump(card: TrumpCardData) -> bool:
	if add_trump_to_hand(card):
		return true
	if add_trump_card(card):
		return true
	return false

## 检查王牌是否可在本小局使用
func can_use_trump(card: TrumpCardData) -> bool:
	if current_trump_hand.find(card) == -1:
		return false
	var used := trumps_used_this_round.get(card.card_name, 0) as int
	return used < card.uses_per_battle
