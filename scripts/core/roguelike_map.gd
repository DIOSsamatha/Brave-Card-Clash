## 罗格莱克地图系统
## 管理6层随机节点路线、事件触发
class_name RoguelikeMap
extends RefCounted

## 节点类型
enum NodeType {
	BATTLE,         # 普通战斗
	ELITE_BATTLE,   # 精英战斗
	SHOP,           # 商店
	REST,           # 休息点（回血/升级王牌）
	CHEST,          # 宝箱
	EVENT,          # 随机事件
	REMOVE,         # 删除节点（移除王牌）
	COPY,           # 复制节点（复制王牌）
	BOSS,           # Boss
}

## 地图节点
class MapNode:
	var id: int
	var type: NodeType
	var name: String
	var description: String
	var connected_to: Array[int] = []  # 可通往下级节点ID列表
	var is_cleared: bool = false
	var node_data: Variant = null      # 附加数据（敌人名称/商店列表/事件ID等）

	func _init(p_id: int, p_type: NodeType, p_name: String, p_desc: String = "") -> void:
		id = p_id
		type = p_type
		name = p_name
		description = p_desc

## 整张地图：6层×每层节点
var _tiers: Array[Array] = []           # Array[Array[MapNode]]
var _current_node: MapNode = null
var _current_tier_index: int = -1
var _node_id_counter: int = 0

## 生成完整冒险地图
func generate() -> void:
	_tiers.clear()
	_node_id_counter = 0

	var tier_configs: Array[Dictionary] = [
		{"battles": 4, "elites": 1, "shops": 1, "rests": 1, "chests": 1, "events": 1, "removes": 1},  # 层1
		{"battles": 3, "elites": 1, "shops": 1, "rests": 1, "chests": 2, "events": 1, "removes": 1},  # 层2
		{"battles": 4, "elites": 1, "shops": 1, "rests": 1, "chests": 1, "events": 1, "removes": 1},  # 层3
		{"battles": 3, "elites": 2, "shops": 1, "rests": 1, "chests": 1, "events": 1, "copies": 1},   # 层4
		{"battles": 3, "elites": 1, "shops": 1, "rests": 1, "chests": 1, "events": 1, "removes": 1},  # 层5
	]

	var tier_names: Array[String] = ["妖精幻境", "水晶幻境", "火焰幻境", "暗影幻境", "魔王城前庭"]
	var tier_enemy_tier: Array[EnemyData.Tier] = [EnemyData.Tier.FAIRY, EnemyData.Tier.CRYSTAL, EnemyData.Tier.FLAME, EnemyData.Tier.SHADOW, EnemyData.Tier.COURTYARD]

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for tier_idx in 5:
		var nodes: Array[MapNode] = []
		var cfg := tier_configs[tier_idx]

		# 战斗节点
		for i in cfg["battles"]:
			var node := MapNode.new(_next_id(), NodeType.BATTLE, "战斗", "击败幻境怪物")
			var enemy := EnemyDatabase.get_random_enemy(tier_enemy_tier[tier_idx])
			node.node_data = enemy.enemy_name
			nodes.append(node)

		# 精英战斗
		for i in cfg["elites"]:
			var node := MapNode.new(_next_id(), NodeType.ELITE_BATTLE, "精英战", "打败强大的精英怪物")
			node.node_data = "精英怪物"
			nodes.append(node)

		# 商店
		for i in cfg["shops"]:
			nodes.append(MapNode.new(_next_id(), NodeType.SHOP, "商店", "使用金币购买资源"))

		# 休息点
		for i in cfg["rests"]:
			nodes.append(MapNode.new(_next_id(), NodeType.REST, "休息点", "恢复30%生命或升级一张王牌"))

		# 宝箱
		for i in cfg["chests"]:
			nodes.append(MapNode.new(_next_id(), NodeType.CHEST, "宝箱", "免费获得随机奖励"))

		# 事件
		for i in cfg["events"]:
			nodes.append(MapNode.new(_next_id(), NodeType.EVENT, "随机事件", "未知的奇遇..."))

		# 删除/复制节点
		if cfg.has("removes"):
			for i in cfg["removes"]:
				nodes.append(MapNode.new(_next_id(), NodeType.REMOVE, "删除", "永久移除一张王牌"))
		if cfg.has("copies"):
			for i in cfg["copies"]:
				nodes.append(MapNode.new(_next_id(), NodeType.COPY, "复制", "复制一张已有王牌"))

		# 洗牌节点顺序
		_shuffle_nodes(nodes, rng)

		# 建立层级间连接
		if tier_idx > 0:
			var prev_nodes := _tiers[tier_idx - 1]
			_connect_tiers(prev_nodes, nodes, rng)

		_tiers.append(nodes)

	# 第6层：Boss
	var final_tier: Array[MapNode] = []
	var boss_names: Array[String] = ["梅花精灵 ♣", "方块巨人 ♦", "红桃骑士 ♥", "黑桃法师 ♠", "近卫队长", "黑桃魔王 ♠"]
	for boss_idx in 6:
		var boss_node := MapNode.new(_next_id(), NodeType.BOSS, boss_names[boss_idx], "第%d层 Boss" % (boss_idx + 1))
		boss_node.node_data = boss_names[boss_idx]

		# Boss层：连接前一层所有节点到Boss
		var prev_tier_nodes: Array[MapNode] = []
		if boss_idx == 0:
			prev_tier_nodes = _tiers[4]  # 层5所有节点连接到Boss层1
		else:
			prev_tier_nodes = [final_tier[boss_idx - 1]]

		for prev_node in prev_tier_nodes:
			prev_node.connected_to.append(boss_node.id)

		final_tier.append(boss_node)

	_tiers.append(final_tier)

	# 起始节点：第1层所有节点都可通往
	_set_start_connections()

## 起始层 — 边境小镇
func _set_start_connections() -> void:
	# 第1层所有节点自动从起始可达
	pass

## 获取指定层的所有节点
func get_nodes_at_tier(tier: int) -> Array[MapNode]:
	if tier < 0 or tier >= _tiers.size():
		return []
	return _tiers[tier]

## 获取当前层节点
func get_current_tier_nodes() -> Array[MapNode]:
	return get_nodes_at_tier(_current_tier_index)

## 移动到指定节点
func move_to_node(node_id: int) -> MapNode:
	for tier_nodes in _tiers:
		for node in tier_nodes:
			if node.id == node_id:
				_current_node = node
				node.is_cleared = true
				return node
	return null

## 获取下一层可到达的节点
func get_reachable_nodes() -> Array[MapNode]:
	if _current_node == null:
		_current_tier_index = 0
		return get_nodes_at_tier(0)

	if _current_node.connected_to.is_empty():
		return []

	var result: Array[MapNode] = []
	for node_id in _current_node.connected_to:
		var node := find_node_by_id(node_id)
		if node != null:
			result.append(node)
	return result

## 进入下一层
func advance_to_next_tier() -> void:
	if _current_tier_index < _tiers.size() - 1:
		_current_tier_index += 1

func find_node_by_id(node_id: int) -> MapNode:
	for tier_nodes in _tiers:
		for node in tier_nodes:
			if node.id == node_id:
				return node
	return null

func _next_id() -> int:
	_node_id_counter += 1
	return _node_id_counter

func _shuffle_nodes(nodes: Array[MapNode], rng: RandomNumberGenerator) -> void:
	for i in range(nodes.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := nodes[i]
		nodes[i] = nodes[j]
		nodes[j] = temp

func _connect_tiers(prev: Array[MapNode], current: Array[MapNode], rng: RandomNumberGenerator) -> void:
	# 每层节点随机连接到下层节点（每个上层节点连2-3个下层）
	for p_node in prev:
		var connect_count: int = rng.randi_range(1, mini(3, current.size()))
		var available: Array[int] = []
		for c_node in current:
			available.append(c_node.id)
		available.shuffle()

		for i in connect_count:
			if i < available.size():
				p_node.connected_to.append(available[i])
