## 地图场景 v4 — 6层主题制分支路线图
## 每层独立主题（妖精/水晶/火焰/暗影/魔王城/魔王之间）
## 节点类型：宝箱/事件/战斗/精英/商店/Boss
## 第5层需Lv20解锁，第6层需击败近卫队长3形态
extends Control

# ============================================================
#  常量
# ============================================================
const TOTAL_LAYERS: int = 10         # 0=起点, 1~8=中间行(8行), 9=Boss（地图加长）
const MIN_NODES_PER_LAYER: int = 3   # 中间层最少节点数
const MAX_NODES_PER_LAYER: int = 4   # 中间层最多节点数

# 节点类型枚举
enum NodeType { START, TREASURE, EVENT, MONSTER, ELITE, SHOP, BOSS }

# 节点类型视觉配置
const NODE_CONFIG: Array[Dictionary] = [
	{NodeType.START:    {"icon": "●", "label": "起点",     "color": Color(0.5, 0.5, 0.5)}},
	{NodeType.TREASURE: {"icon": "★", "label": "宝箱",     "color": Color(1.0, 0.8, 0.15)}},
	{NodeType.EVENT:    {"icon": "?", "label": "事件",     "color": Color(0.4, 0.7, 1.0)}},
	{NodeType.MONSTER:  {"icon": "⚔", "label": "战斗",     "color": Color(1.0, 0.35, 0.3)}},
	{NodeType.ELITE:    {"icon": "♦", "label": "精英",     "color": Color(1.0, 0.4, 0.8)}},
	{NodeType.SHOP:     {"icon": "🏪", "label": "商店",    "color": Color(0.3, 1.0, 0.5)}},
	{NodeType.BOSS:     {"icon": "👑", "label": "Boss决战", "color": Color(1.0, 0.3, 0.0)}},
]

const EVENT_POOL: Array[Dictionary] = [
	{"text": "你发现了一座祝福之泉", "effect": "heal_30pct", "desc": "沐浴泉水，恢复30%生命"},
	{"text": "一位神秘商人路过", "effect": "random_item", "desc": "商人送你一个随机道具"},
	{"text": "古老的石碑散发微光", "effect": "random_trump", "desc": "石碑中浮现一张王牌"},
	{"text": "前方星尘矿脉", "effect": "bonus_dust", "desc": "采集到额外星尘"},
	{"text": "地面突然塌陷...", "effect": "trap_damage", "desc": "你受到10%生命伤害"},
	{"text": "一无所有的空旷房间", "effect": "nothing", "desc": "什么都没有发生"},
]

# ============================================================
#  地图数据结构
# ============================================================
## 单个地图节点
class MapNode:
	var layer: int = 0                  # 所在层 (0~5)
	var node_id: int = 0                # 全局唯一ID
	var node_type: int = NodeType.EVENT # 节点类型
	var grid_x: float = 0.0             # 网格X坐标（用于布局）
	var screen_pos: Vector2             # 屏幕坐标（渲染后填入）
	var visited: bool = false           # 是否已访问
	var enemy_data: EnemyData = null    # 战斗/精英/Boss节点的敌人数据
	var connections: Array[int] = []    # 连接到的下一层节点ID列表

	func _init(p_layer: int, p_id: int, p_type: int) -> void:
		layer = p_layer
		node_id = p_id
		node_type = p_type

## 整张地图
var _map_nodes: Array[MapNode] = []         # 所有节点
var _current_layer: int = 0                 # 当前所在层
var _current_node_id: int = -1              # 当前所在节点ID
var _game_clear: bool = false               # 是否通关

# ============================================================
#  UI 引用
# ============================================================
# 地图画布区域
var _map_area: Control = null
var _map_content: Control = null           # 可整体平移的地图内容容器（节点+连线）
var _line_drawer: Control = null            # 专门画线的Control
var _map_offset: Vector2 = Vector2.ZERO     # 地图内容平移偏移

# 拖动查看相关状态
var _drag_button_down: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _just_dragged: bool = false

# 标题区
var _floor_label: Label = null
var _tier_name_label: Label = null

# 角色状态（右上角）
var _char_status_panel: VBoxContainer = null
var _char_hp_bar: ProgressBar = null
var _char_hp_label: Label = null
var _char_name_label: Label = null
var _char_level_label: Label = null
var _flask_button: Button = null

# 道具栏（底部居中）
var _item_panel: HBoxContainer = null
var _item_buttons: Array[Button] = []

# 王牌面板（左下角弹窗）
var _trump_dialog: PanelContainer = null
var _trump_dialog_title: Label = null
var _trump_hand_box: VBoxContainer = null
var _trump_bag_box: VBoxContainer = null
var _trump_detail_label: Label = null
var _selected_trump: TrumpCardData = null
var _swap_selected_card: TrumpCardData = null # 交换模式：选中的源牌
var _swap_selected_is_hand: bool = false      # 源牌是否在手牌区
var _selected_row_control: Control = null      # 当前高亮的行引用

# 消息弹窗
var _message_overlay: ColorRect = null
var _message_label: Label = null

# 确认弹窗（跳过节点用，需用户二次确认）
var _confirm_overlay: ColorRect = null

# 节点按钮缓存（用于更新状态）
var _node_buttons: Dictionary = {}  # node_id -> Button

# 布局参数
const MAP_AREA_TOP: float = 140.0
const MAP_AREA_BOTTOM_OFFSET: float = 100.0  # 距底部留白
const LAYER_SPACING_X: float = 260.0         # 层间水平间距（加宽以支持拖动查看）
const NODE_SIZE: float = 48.0                # 节点圆形直径
const DRAG_THRESHOLD: float = 8.0            # 拖动判定阈值（像素），超过才算拖动

# ============================================================
#  生命周期
# ============================================================

func _ready() -> void:
	_build_ui()
	if GameState.map_seed == 0:
		# 首次进入地图，生成新种子
		var rng_seed := RandomNumberGenerator.new()
		rng_seed.randomize()
		GameState.map_seed = rng_seed.randi()
	_generate_new_map()
	_refresh_all()

func _build_ui() -> void:
	var sw: float = get_window().size.x if get_window() else 1152.0
	var sh: float = get_window().size.y if get_window() else 648.0

	# === 背景 ===
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# === ���题 ===
	var title := Label.new()
	title.text = "冒险地图"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.position = Vector2(0, 10)
	title.size = Vector2(sw, 30)
	add_child(title)

	# === 层数显示 ===
	_floor_label = Label.new()
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_label.add_theme_font_size_override("font_size", 36)
	_floor_label.position = Vector2(0, 42)
	_floor_label.size = Vector2(sw, 44)
	add_child(_floor_label)

	_tier_name_label = Label.new()
	_tier_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_name_label.add_theme_font_size_override("font_size", 20)
	_tier_name_label.position = Vector2(0, 86)
	_tier_name_label.size = Vector2(sw, 28)
	add_child(_tier_name_label)

	# === 地图画布区域（视口，裁剪超出部分）===
	_map_area = Control.new()
	_map_area.position = Vector2(0, MAP_AREA_TOP)
	_map_area.size = Vector2(sw, sh - MAP_AREA_TOP - MAP_AREA_BOTTOM_OFFSET)
	_map_area.clip_contents = true
	add_child(_map_area)

	# 可平移的地图内容容器（节点与连线都放在这里，整体拖动）
	_map_content = Control.new()
	_map_content.position = _map_offset
	_map_area.add_child(_map_content)

	# 拖动查看提示
	var drag_hint := Label.new()
	drag_hint.text = "🖱 按住左键拖动查看地图"
	drag_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_hint.add_theme_font_size_override("font_size", 12)
	drag_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	drag_hint.position = Vector2(0, MAP_AREA_TOP + 6)
	drag_hint.size = Vector2(sw, 18)
	drag_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drag_hint)

	# 画线层（在节点下方，属于 _map_content）
	_line_drawer = Control.new()
	_line_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_content.add_child(_line_drawer)

	# === 角色状态面板（右上角）===
	_build_char_status_panel(sw)

	# === 道具栏（底部）===
	_build_item_bar(sw, sh)

	# === 王牌按钮（左下角）===
	var trump_btn := Button.new()
	trump_btn.text = "查看王牌"
	trump_btn.custom_minimum_size = Vector2(110, 30)
	trump_btn.position = Vector2(10, sh - 42)
	trump_btn.pressed.connect(_show_trump_dialog)
	add_child(trump_btn)

	# === 返回主菜单按钮（右下角）===
	var back_btn := Button.new()
	back_btn.text = "返回主菜单"
	back_btn.custom_minimum_size = Vector2(110, 30)
	back_btn.position = Vector2(sw - 120, sh - 42)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

	# === 跳过本层按钮（测试用，返回主菜单左侧）===
	var skip_btn := Button.new()
	skip_btn.text = "⏭ 跳过"
	skip_btn.custom_minimum_size = Vector2(90, 30)
	skip_btn.position = Vector2(sw - 220, sh - 42)
	skip_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	skip_btn.pressed.connect(_on_skip_pressed)
	add_child(skip_btn)

func _build_char_status_panel(sw: float) -> void:
	_char_status_panel = VBoxContainer.new()
	_char_status_panel.position = Vector2(sw - 200, 8)
	_char_status_panel.custom_minimum_size = Vector2(192, 110)
	_char_status_panel.add_theme_constant_override("separation", 3)

	var char_bg := StyleBoxFlat.new()
	char_bg.bg_color = Color(0.12, 0.12, 0.20, 0.92)
	char_bg.set_corner_radius_all(8)
	char_bg.content_margin_left = 8
	char_bg.content_margin_right = 8
	char_bg.content_margin_top = 5
	char_bg.content_margin_bottom = 5
	_char_status_panel.add_theme_stylebox_override("panel", char_bg)

	_char_name_label = Label.new()
	_char_name_label.add_theme_font_size_override("font_size", 14)
	_char_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_char_status_panel.add_child(_char_name_label)

	_char_level_label = Label.new()
	_char_level_label.add_theme_font_size_override("font_size", 12)
	_char_level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_char_status_panel.add_child(_char_level_label)

	_char_hp_bar = ProgressBar.new()
	_char_hp_bar.custom_minimum_size = Vector2(176, 12)
	_char_hp_bar.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_char_status_panel.add_child(_char_hp_bar)

	_char_hp_label = Label.new()
	_char_hp_label.add_theme_font_size_override("font_size", 11)
	_char_hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_char_status_panel.add_child(_char_hp_label)

	# 血瓶按钮（死亡细胞风格：回复当前生命值上限的一半）
	_flask_button = Button.new()
	_flask_button.custom_minimum_size = Vector2(176, 30)
	_flask_button.add_theme_font_size_override("font_size", 12)
	_flask_button.pressed.connect(_on_use_flask)
	_char_status_panel.add_child(_flask_button)

	add_child(_char_status_panel)

func _build_item_bar(sw: float, sh: float) -> void:
	var item_label := Label.new()
	item_label.text = "道具栏 (最多%d格)" % GameState.MAX_ITEMS
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 12)
	item_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	item_label.position = Vector2(sw / 2 - 100, sh - 68)
	item_label.size = Vector2(200, 18)
	add_child(item_label)

	_item_panel = HBoxContainer.new()
	_item_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_item_panel.position = Vector2(sw / 2 - 190, sh - 50)
	_item_panel.custom_minimum_size = Vector2(380, 38)
	_item_panel.add_theme_constant_override("separation", 10)
	add_child(_item_panel)

# ============================================================
#  地图生成
# ============================================================

## 生成一张新的随机分支地图（使用 GameState.map_seed 保证同一次冒险一致）
func _generate_new_map() -> void:
	_map_nodes.clear()
	_node_buttons.clear()
	var id_counter: int = 0

	# 使用固定种子保证同一次冒险中同一层地图不变
	var master_rng := RandomNumberGenerator.new()
	master_rng.seed = GameState.map_seed + GameState.current_round  # 每层不同但确定

	# 当前层索引（0-5对应6层主题）——直接从GameState读取，不依赖_current_layer
	var layer_idx: int = GameState.current_round

	# --- 第0行：起点（1个）---
	var start_node := MapNode.new(0, id_counter, NodeType.START)
	start_node.visited = true
	_current_node_id = id_counter
	_map_nodes.append(start_node)
	id_counter += 1

	# --- 第1~(TOTAL_LAYERS-2)行：中间节点（每行4个，路线更丰富）---
	var prev_row_nodes: Array[MapNode] = [start_node]
	for row in range(1, TOTAL_LAYERS - 1):
		var new_row_nodes: Array[MapNode] = []

		for i in range(MAX_NODES_PER_LAYER):
			var ntype: int = _random_node_type_seeded(layer_idx, master_rng)
			var node := MapNode.new(row, id_counter, ntype)
			# 根据当前层分配敌人数据
			if ntype == NodeType.MONSTER:
				# 普通战斗节点：从本层「全部怪物」池随机（含精英怪），避免只固定刷普通怪
				node.enemy_data = EnemyDatabase.get_random_any_for_layer(layer_idx)
			elif ntype == NodeType.ELITE:
				node.enemy_data = EnemyDatabase.get_random_elite_for_layer(layer_idx)
			_map_nodes.append(node)
			new_row_nodes.append(node)
			id_counter += 1

		# 连接上一行到这一行：
		# - 起点特殊：连到第一行全部节点，让玩家选择起始分支；
		# - 中间行：每个前驱节点只连 1 个下游节点，形成清晰路线，
		#   玩家选择某节点后只能沿该路线前进。
		if row == 1:
			for nxt in new_row_nodes:
				start_node.connections.append(nxt.node_id)
		else:
			_connect_rows(prev_row_nodes, new_row_nodes, master_rng)

		prev_row_nodes = new_row_nodes

	# --- 最后一行：Boss（当前层的Boss）---
	var boss_enemy: EnemyData = EnemyDatabase.get_boss_for_layer(layer_idx)
	var boss_node := MapNode.new(TOTAL_LAYERS - 1, id_counter, NodeType.BOSS)
	boss_node.enemy_data = boss_enemy
	_map_nodes.append(boss_node)
	id_counter += 1

	# 最后一行中间节点全部连接到Boss
	for prev in prev_row_nodes:
		prev.connections.append(boss_node.node_id)

	# 换层时清理过期访问记录（旧层node_id与新层不匹配，保留也无意义）
	if _current_layer != GameState.current_round:
		GameState.map_visited.clear()
		GameState.map_current_node_id = -1
	_current_layer = GameState.current_round

	# 恢复已访问状态（仅当前层的新节点可能被恢复）
	for n in _map_nodes:
		if GameState.map_visited.has(n.node_id):
			n.visited = GameState.map_visited[n.node_id]

	# 恢复"当前所在节点"（路径锁定：玩家只能从当前节点继续前进）
	if GameState.map_current_node_id >= 0 and _find_node_by_id(GameState.map_current_node_id) != null:
		_current_node_id = GameState.map_current_node_id
	else:
		_current_node_id = start_node.node_id

	# 确保至少有一个事件和一个非战斗节点
	var has_event: bool = false
	var has_shop_or_treasure: bool = false
	for n in _map_nodes:
		if n.node_type == NodeType.EVENT:
			has_event = true
		if n.node_type == NodeType.SHOP or n.node_type == NodeType.TREASURE:
			has_shop_or_treasure = true
	if not has_event:
		var candidates: Array[MapNode] = []
		for n in _map_nodes:
			if n.node_type != NodeType.START and n.node_type != NodeType.BOSS:
				candidates.append(n)
		if not candidates.is_empty():
			var target: MapNode = candidates[master_rng.randi_range(0, candidates.size() - 1)]
			target.node_type = NodeType.EVENT
	if not has_shop_or_treasure:
		var candidates: Array[MapNode] = []
		for n in _map_nodes:
			if n.node_type == NodeType.MONSTER:
				candidates.append(n)
		if not candidates.is_empty():
			var target: MapNode = candidates[master_rng.randi_range(0, candidates.size() - 1)]
			target.node_type = NodeType.SHOP if master_rng.randf() < 0.5 else NodeType.TREASURE

	_game_clear = false

## 将上一行和下一行节点连接成若干条随机分支路线
## 规则：
## 1) 每个前驱节点只连 1 个下游节点，形成清晰的"路线"；
## 2) 相邻列之间只能连到同列或相邻列（不能跳列），路线自然蜿蜒；
## 3) 保证每个下游节点至少 1 条入边，防止断线；
## 4) 起点到第一行仍保持多选，让玩家决定走哪条分支。
## 效果：玩家选择某节点后，只能沿着该路线继续走，未被选中的分支 unreachable。
func _connect_rows(prev_row: Array[MapNode], next_row: Array[MapNode], rng: RandomNumberGenerator) -> void:
	var in_count: Array[int] = []
	in_count.resize(next_row.size())
	in_count.fill(0)

	# 辅助：安全添加一条连接并更新入度
	var _try_connect := func(_prev_idx: int, _next_idx: int) -> bool:
		if _prev_idx < 0 or _prev_idx >= prev_row.size():
			return false
		if _next_idx < 0 or _next_idx >= next_row.size():
			return false
		var prev_node: MapNode = prev_row[_prev_idx]
		var next_node: MapNode = next_row[_next_idx]
		if prev_node.connections.has(next_node.node_id):
			return false
		prev_node.connections.append(next_node.node_id)
		in_count[_next_idx] += 1
		return true

	# 1) 打乱前驱节点的处理顺序，避免路线总是从左上到右下
	var prev_indices: Array[int] = []
	prev_indices.resize(prev_row.size())
	for k in range(prev_row.size()):
		prev_indices[k] = k
	prev_indices.shuffle()

	# 2) 每个前驱节点连 1~2 个下游节点（保证有出路，并制造分支选择），优先同列或相邻列
	for i in prev_indices:
		var candidates: Array[int] = [i]
		if i - 1 >= 0:
			candidates.append(i - 1)
		if i + 1 < next_row.size():
			candidates.append(i + 1)
		candidates.shuffle()

		# 第1条（保证每条路线都有出路）
		var first_connected: bool = false
		for j in candidates:
			if in_count[j] == 0:
				if _try_connect.call(i, j):
					first_connected = true
					break
		if not first_connected:
			# 候选都已有入边，则随便挑一个相邻的连出去
			for j in candidates:
				if _try_connect.call(i, j):
					first_connected = true
					break

		# 第2条（概率性额外分支，让玩家在路线上有选择）
		if first_connected and rng.randf() < 0.5:
			for j in candidates:
				if _try_connect.call(i, j):
					break

	# 3) 保证每个下游节点至少 1 条入边（从最近的 prev 补）
	for j in range(next_row.size()):
		if in_count[j] > 0:
			continue
		var nearest_i: int = clampi(j, 0, prev_row.size() - 1)
		if _try_connect.call(nearest_i, j):
			continue
		for i in range(prev_row.size()):
			if _try_connect.call(i, j):
				break

## 随机决定一个中间层的节点类型（使用seeded RNG保证可重现）
## 使用归一化权重，包含商店节点
func _random_node_type_seeded(layer: int, rng: RandomNumberGenerator) -> int:
	var battle_weight: float = 0.28 + layer * 0.05       # 28% → 53%
	var elite_weight: float = 0.05 + layer * 0.03        # 5% → 20%
	var treasure_weight: float = 0.18                    # 固定18%
	var event_weight: float = 0.25                       # 固定25%
	var shop_weight: float = 0.10 + layer * 0.02        # 10% → 20%

	var total: float = battle_weight + elite_weight + treasure_weight + event_weight + shop_weight
	var r: float = rng.randf() * total

	if r < battle_weight:
		return NodeType.MONSTER
	elif r < battle_weight + elite_weight:
		return NodeType.ELITE
	elif r < battle_weight + elite_weight + treasure_weight:
		return NodeType.TREASURE
	elif r < battle_weight + elite_weight + treasure_weight + event_weight:
		return NodeType.EVENT
	else:
		return NodeType.SHOP

## 随机决定一个中间层的节点类型（无种子版本，保留兼容）
func _random_node_type(layer: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return _random_node_type_seeded(layer, rng)

## 获取某层的敌人数据（使用seeded RNG——保留接口兼容）
func _get_enemy_for_layer_seeded(layer: int, is_elite: bool, _rng: RandomNumberGenerator) -> EnemyData:
	return _get_enemy_for_layer(layer, is_elite)

## 获取某层的敌人数据（直接委托给EnemyDatabase的层索引API）
func _get_enemy_for_layer(layer: int, is_elite: bool) -> EnemyData:
	if is_elite:
		return EnemyDatabase.get_random_elite_for_layer(layer)
	return EnemyDatabase.get_random_enemy_for_layer(layer)

func _get_nodes_at_layer(layer: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in _map_nodes:
		if n.layer == layer:
			result.append(n)
	return result

func _find_node_by_id(node_id: int) -> MapNode:
	for n in _map_nodes:
		if n.node_id == node_id:
			return n
	return null

# ============================================================
#  渲染
# ============================================================

func _refresh_all() -> void:
	# 当前层 = current_round（0=第一层妖精幻境, 1=第二层水晶幻境, ...）
	_current_layer = GameState.current_round
	if _current_layer >= TOTAL_LAYERS:
		_game_clear = true
		_current_layer = TOTAL_LAYERS - 1

	# 标题（使用主题名称 + 解锁状态）— 去掉"小局X"
	var tier_idx := mini(_current_layer, 5)
	_floor_label.text = "第 %d 层 - %s" % [_current_layer + 1, EnemyDatabase.LAYER_NAMES[tier_idx]]
	var layer_name: String = EnemyDatabase.LAYER_NAMES[tier_idx]
	if _current_layer >= 4:
		# 检查解锁状态
		var player_lvl: int = GameState.selected_char_level
		if not EnemyDatabase.is_layer_unlocked(_current_layer, player_lvl, GameState.captain_forms_beaten):
			var reason: String = EnemyDatabase.get_layer_lock_reason(_current_layer)
			_tier_name_label.text = "— %s [🔒%s] —" % [layer_name, reason]
			_tier_name_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		else:
			_tier_name_label.text = "— %s —" % layer_name
			_tier_name_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	else:
		_tier_name_label.text = "— %s —" % layer_name
		match tier_idx:
			0: _tier_name_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
			1: _tier_name_label.add_theme_color_override("font_color", Color(0.5, 0.6, 1.0))
			2: _tier_name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			3: _tier_name_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.9))
			_: _tier_name_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))

	# 绘制地图
	_render_map()

	# UI面板
	_refresh_char_status()
	_build_item_buttons()

## 渲染整张地图（线条 + 节点按钮）
func _render_map() -> void:
	# 清理旧节点按钮
	for btn in _node_buttons.values():
		if is_instance_valid(btn):
			btn.queue_free()
	_node_buttons.clear()

	# 清理 _map_content 下所有子节点（含旧的 line_drawer），重新创建
	for child in _map_content.get_children():
		child.queue_free()

	# 重新创建画线层（属于 _map_content，随内容一起平移）
	_line_drawer = Control.new()
	_line_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_content.add_child(_line_drawer)

	var area_size: Vector2 = _map_area.size
	var center_y: float = area_size.y / 2.0
	var max_x: float = 0.0

	# 计算每个节点的屏幕位置并创建按钮
	for layer in range(TOTAL_LAYERS):
		var nodes_in_layer: Array[MapNode] = _get_nodes_at_layer(layer)
		var layer_count: int = nodes_in_layer.size()
		var x_pos: float = 60.0 + float(layer) * LAYER_SPACING_X

		for idx in range(layer_count):
			var node: MapNode = nodes_in_layer[idx]
			# Y轴均匀分布
			var y_pos: float
			if layer_count == 1:
				y_pos = center_y
			else:
				var spacing: float = area_size.y * 0.55 / float(layer_count - 1)
				y_pos = center_y - area_size.y * 0.275 + float(idx) * spacing

			node.screen_pos = Vector2(x_pos, y_pos)
			_create_node_button(node)
			max_x = maxf(max_x, x_pos)

	# 设定内容容器尺寸（宽度 = 最右节点 + 边距，支持横向拖动）
	_map_content.size = Vector2(max_x + NODE_SIZE + 60.0, area_size.y)
	_update_map_content_position()
	_ensure_current_visible()

	# 画连线
	_draw_connections()

## 根据 _map_offset 设置地图内容容器的位置，并夹紧在视口范围内
func _update_map_content_position() -> void:
	if _map_content == null or _map_area == null:
		return
	var area_size: Vector2 = _map_area.size
	var content_size: Vector2 = _map_content.size

	# 横向：内容比视口宽才允许向左拖动
	var min_x: float = minf(area_size.x - content_size.x, 0.0)
	_map_offset.x = clampf(_map_offset.x, min_x, 0.0)
	# 纵向：内容比视口高才允许上下拖动
	var min_y: float = minf(area_size.y - content_size.y, 0.0)
	_map_offset.y = clampf(_map_offset.y, min_y, 0.0)

	_map_content.position = _map_offset

## 确保当前所在节点（或其首个可达节点）在视口内，否则平移地图使其可见（类 StS 镜头跟随）
func _ensure_current_visible() -> void:
	var focus: MapNode = _find_node_by_id(_current_node_id)
	if focus == null:
		return
	var local: Vector2 = focus.screen_pos
	var area_w: float = _map_area.size.x
	var margin: float = 120.0
	var view_left: float = -_map_offset.x
	var view_right: float = view_left + area_w
	if local.x < view_left + margin or local.x > view_right - margin:
		_map_offset.x = -(local.x - area_w / 2.0)
		_update_map_content_position()

## 鼠标长按拖动查看地图（区分点击与拖动，拖动后抑制误触节点）
func _input(event: InputEvent) -> void:
	# 弹窗打开时不处理拖动，避免穿透
	if _message_overlay != null or _confirm_overlay != null or _trump_dialog != null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 仅在地图区域内才开始拖动，避免误触角落按钮
				var rect := Rect2(_map_area.global_position, _map_area.size)
				if not rect.has_point(event.position):
					_drag_button_down = false
					return
				_drag_button_down = true
				_just_dragged = false
				_drag_start_pos = event.position
				_drag_start_offset = _map_offset
				_is_panning = false
			else:
				if _is_panning:
					_just_dragged = true
				_drag_button_down = false
				_is_panning = false
	elif event is InputEventMouseMotion and _drag_button_down:
		var delta: Vector2 = event.position - _drag_start_pos
		if not _is_panning and delta.length() > DRAG_THRESHOLD:
			_is_panning = true
		if _is_panning:
			_map_offset = _drag_start_offset + delta
			_update_map_content_position()

## 检查节点是否可点击
## 路径锁定（类杀戮尖塔）：玩家选定分支后只能沿当前节点的下游连线前进，
## 其余分支即使曾经可达也变为不可达。可达条件 = 当前节点连接到的、未访问的、非起点的节点。
func _is_node_reachable(node: MapNode) -> bool:
	if node.visited:
		return false
	if node.node_type == NodeType.START:
		return false
	var current: MapNode = _find_node_by_id(_current_node_id)
	if current == null:
		return false
	return current.connections.has(node.node_id)

## 创建一个可点击的节点按钮
func _create_node_button(node: MapNode) -> void:
	var config: Dictionary = _get_node_config(node.node_type)
	var color: Color = config["color"]
	var icon: String = config["icon"]
	var label_text: String = config["label"]

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.text = icon
	btn.tooltip_text = _make_node_tooltip(node)

	# 字体大小
	btn.add_theme_font_size_override("font_size", 18)

	# 根据节点状态设置样式
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(NODE_SIZE / 2.0)

	var can_click: bool = _is_node_reachable(node)
	if node.visited:
		# 已访问 — 实心暗色
		style.bg_color = color.darkened(0.5)
		btn.add_theme_color_override("font_color", color.darkened(0.3))
	elif can_click:
		# 可达可点击 — 发光边框
		style.bg_color = Color(0.12, 0.12, 0.20)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = color
		btn.add_theme_color_override("font_color", color)
		# ��冲动画提示可点击
		_add_pulse_animation(btn, color)
	else:
		# 暂时不可达 — 半透明
		style.bg_color = Color(0.08, 0.08, 0.14)
		btn.add_theme_color_override("font_color", color.darkened(0.6))

	btn.add_theme_stylebox_override("normal", style)

	# hover样式（仅可达可交互时）
	if can_click:
		var hover := StyleBoxFlat.new()
		hover.set_corner_radius_all(NODE_SIZE / 2.0)
		hover.bg_color = color.darkened(0.15)
		hover.border_width_left = 3
		hover.border_width_right = 3
		hover.border_width_top = 3
		hover.border_width_bottom = 3
		hover.border_color = color.lightened(0.3)
		btn.add_theme_stylebox_override("hover", hover)

	btn.position = node.screen_pos - Vector2(NODE_SIZE / 2.0, NODE_SIZE / 2.0)

	# 点击事件
	if can_click:
		btn.pressed.connect(_on_node_clicked.bind(node))
	else:
		btn.disabled = true

	_map_content.add_child(btn)
	_node_buttons[node.node_id] = btn

	# 节点标签（名称）
	var lbl := Label.new()
	lbl.text = label_text if node.node_type != NodeType.BOSS else "Boss"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	if node.visited:
		lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	elif can_click:
		lbl.add_theme_color_override("font_color", color.lightened(0.2))
	else:
		lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	lbl.position = node.screen_pos + Vector2(-NODE_SIZE / 2.0, NODE_SIZE / 2.0 + 2)
	lbl.size = Vector2(NODE_SIZE, 16)
	_map_content.add_child(lbl)

## 给可点击节点加脉冲动画提示
func _add_pulse_animation(btn: Button, _glow_color: Color) -> void:
	var tween := btn.create_tween()
	tween.set_loops()
	tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.8)
	tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)

## 画节点间的连接线
func _draw_connections() -> void:
	# 断开旧连接避免重复绑定
	if _line_drawer.is_connected("draw", _on_draw_lines):
		_line_drawer.disconnect("draw", _on_draw_lines)
	_line_drawer.connect("draw", _on_draw_lines)
	_line_drawer.queue_redraw()

func _on_draw_lines() -> void:
	var line_color_visited: Color = Color(0.25, 0.25, 0.3)
	var line_color_available: Color = Color(0.35, 0.35, 0.45)
	var line_color_future: Color = Color(0.15, 0.15, 0.2)

	for node in _map_nodes:
		for target_id in node.connections:
			var target: MapNode = _find_node_by_id(target_id)
			if target == null:
				continue

			var from_pos: Vector2 = node.screen_pos
			var to_pos: Vector2 = target.screen_pos

			# 决定线颜色
			var lc: Color
			if node.visited:
				lc = line_color_visited
			elif node.layer == _current_layer - 1 or (node.layer < _current_layer):
				lc = line_color_available
			else:
				lc = line_color_future

			_line_drawer.draw_line(from_pos, to_pos, lc, 2.0, true)

			# 画箭头方向指示（小三角）
			var direction: Vector2 = (to_pos - from_pos).normalized()
			var arrow_pos: Vector2 = from_pos + direction * ((to_pos - from_pos).length() * 0.55)
			var arrow_size: float = 6.0
			var perp: Vector2 = Vector2(-direction.y, direction.x) * arrow_size * 0.5
			var points: PackedVector2Array = PackedVector2Array([
				arrow_pos + direction * arrow_size,
				arrow_pos - perp,
				arrow_pos + perp,
			])
			_line_drawer.draw_colored_polygon(points, lc)

## 生成节点tooltip文字
func _make_node_tooltip(node: MapNode) -> String:
	var config: Dictionary = _get_node_config(node.node_type)
	var base: String = "%s [%s]" % [config["label"], EnemyDatabase.LAYER_NAMES[mini(node.layer, 5)]]
	match node.node_type:
		NodeType.TREASURE:
			base += "\n获得道具和王牌\n稀有度随层数提升"
		NodeType.EVENT:
			base += "\n触发未知奇遇..."
		NodeType.SHOP:
			base += "\n神秘商人，可管理背包"
		NodeType.MONSTER:
			if node.enemy_data != null:
				base += "\n敌人: %s" % node.enemy_data.enemy_name
		NodeType.ELITE:
			if node.enemy_data != null:
				base += "\n精英: %s (强敌!)" % node.enemy_data.enemy_name
		NodeType.BOSS:
			if node.enemy_data != null:
				base += "\n%s" % node.enemy_data.enemy_name
	return base

func _get_node_type_string(nType: int) -> String:
	match nType:
		NodeType.START: return "起点"
		NodeType.TREASURE: return "宝箱"
		NodeType.EVENT: return "事件"
		NodeType.MONSTER: return "战斗"
		NodeType.ELITE: return "精英"
		NodeType.BOSS: return "Boss"
	return "?"

func _get_node_config(nType: int) -> Dictionary:
	match nType:
		NodeType.START:    return {"icon": "●", "label": "起点",     "color": Color(0.5, 0.5, 0.55)}
		NodeType.TREASURE: return {"icon": "★", "label": "宝箱",     "color": Color(1.0, 0.8, 0.15)}
		NodeType.EVENT:    return {"icon": "?", "label": "事件",     "color": Color(0.4, 0.7, 1.0)}
		NodeType.MONSTER:  return {"icon": "⚔", "label": "战斗",     "color": Color(1.0, 0.35, 0.3)}
		NodeType.ELITE:    return {"icon": "♦", "label": "精英",     "color": Color(1.0, 0.4, 0.8)}
		NodeType.SHOP:     return {"icon": "🏪", "label": "商店",    "color": Color(0.3, 1.0, 0.5)}
		NodeType.BOSS:     return {"icon": "👑", "label": "Boss",     "color": Color(1.0, 0.3, 0.0)}
	return {"icon": "?", "label": "???", "color": Color(1.0, 1.0, 1.0)}

# ============================================================
#  节点点击处理
# ============================================================

func _on_node_clicked(node: MapNode) -> void:
	if _just_dragged:
		_just_dragged = false
		return
	if node.visited:
		return
	# 可达性由 _is_node_reachable() 在创建按钮时已验证
	# 不再检查 node.layer（layer是地图行号0~3，不是游戏层数）

	# 标记已访问
	node.visited = true
	_current_node_id = node.node_id
	GameState.map_visited[node.node_id] = true
	GameState.map_current_node_id = node.node_id

	match node.node_type:
		NodeType.TREASURE:
			_execute_treasure(node)
		NodeType.EVENT:
			_execute_event(node)
		NodeType.SHOP:
			_execute_shop(node)
		NodeType.MONSTER, NodeType.ELITE, NodeType.BOSS:
			_execute_battle(node)

## 宝箱节点
func _execute_treasure(node: MapNode) -> void:
	var tier_idx: int = mini(node.layer, 5)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var msg: String = "打开宝箱！\n\n"

	# 1个道具
	var item: BattleItemData = ItemDatabase.get_random_item_by_tier(tier_idx)
	if item != null:
		if GameState.add_item(item):
			msg += "获得道具: [%s] %s\n" % [_rarity_s(item.rarity), item.item_name]
		else:
			msg += "道具栏已满！%s 放不下了\n" % item.item_name

	# 1张王牌
	var trump: TrumpCardData = TrumpCardDatabase.get_random_card_by_tier(tier_idx)
	if trump != null:
		if GameState.try_add_trump(trump):
			msg += "获得王牌: [%s] %s" % [_rarity_t(trump.rarity), trump.card_name]
		else:
			msg += "王牌背包已满(共%d)! [%s] %s 无法携带" % [GameState.MAX_TOTAL_TRUMPS, _rarity_t(trump.rarity), trump.card_name]

	show_message(msg, 2.0)
	_build_item_buttons()
	_advance_after_node()

## 事件节点
func _execute_event(_node: MapNode) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var event: Dictionary = EVENT_POOL[rng.randi_range(0, EVENT_POOL.size() - 1)]

	var msg: String = event["text"] + "\n\n" + event["desc"]
	match event["effect"]:
		"heal_30pct":
			var heal_amt: float = GameState.player_max_health * 0.3
			GameState.player_heal(heal_amt)
			msg += "\n恢复 %.0f 生命" % heal_amt
		"random_item":
			var item: BattleItemData = ItemDatabase.get_random_item_by_tier(GameState.current_round)
			if item != null and GameState.add_item(item):
				msg += "\n获得: %s" % item.item_name
			else:
				msg += "\n道具栏已满"
		"random_trump":
			var trump: TrumpCardData = TrumpCardDatabase.get_random_card_by_tier(GameState.current_round)
			if trump != null and GameState.try_add_trump(trump):
				msg += "\n获得王牌: %s" % trump.card_name
			else:
				msg += "\n王牌已满"
		"bonus_dust":
			var dust: int = (GameState.current_round + 1) * 5 + 10
			GameState.progression.add_star_dust(dust)
			msg += "\n星尘 +%d" % dust
		"trap_damage":
			var dmg: float = GameState.player_max_health * 0.1
			GameState.player_take_damage(dmg)
			msg += "\n受到 %.0f 伤害" % dmg
		"nothing":
			pass

	show_message(msg, 2.0)
	_build_item_buttons()
	_refresh_char_status()
	_advance_after_node()

## 商店节点
func _execute_shop(_node: MapNode) -> void:
	# 简单商店：用金币购买道具或王牌
	var msg: String = "神秘商店\n\n你拥有 %d 金币\n\n" % GameState.gold
	msg += "【商店已整合到道具/王牌管理中】\n"
	msg += "离开商店后可查看背包使用道具、管理王牌"
	show_message(msg, 2.5)
	# 商店不推进层数（可以反复访问不同商店节点）
	# 但节点标记为已访问，不能再次获得收益
	_refresh_all()

## 战斗节点（含精英和Boss）
func _execute_battle(node: MapNode) -> void:
	if node.enemy_data == null:
		push_error("map_scene: 战斗节点(%d)没有敌人数据" % node.node_id)
		return

	GameState.setup_enemy_from_data(node.enemy_data)
	# 标记是否为Boss战（影响战斗胜利后的层数推进）
	GameState.is_boss_battle = (node.node_type == NodeType.BOSS)

	# 进入战斗场景
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")

## 节点执行完后刷新（不自动推进层——只有Boss战才推进）
func _advance_after_node() -> void:
	# 非Boss节点：停留在当前层，刷新UI显示已访问状态
	# Boss节点：由battle_scene._continue_adventure处理层推进
	_refresh_all()

	# 刷新地图显示新的一层
	_refresh_all()

## 显示通关画面
func _show_victory_screen() -> void:
	_refresh_all()  # 会刷新为game_clear状态
	show_message(
		"恭喜通关！\n\n征服了全部 %d 层！\n最终击杀了 Boss！" % TOTAL_LAYERS
	)

# ============================================================
#  角色状态面板
# ============================================================

func _refresh_char_status() -> void:
	if GameState.selected_character != null:
		_char_name_label.text = GameState.selected_character.char_name
	else:
		_char_name_label.text = "勇者"

	_char_level_label.text = "Lv.%d | 第%d层" % [GameState.selected_char_level, _current_layer + 1]

	var pmax: float = GameState.player_max_health
	var pcur: float = GameState.player_health
	_char_hp_bar.max_value = pmax
	_char_hp_bar.value = pcur
	_char_hp_label.text = "HP: %.0f / %.0f" % [pcur, pmax]

	# 血瓶状态
	if _flask_button != null:
		_flask_button.text = "🧪 血瓶 %d/%d" % [GameState.flask_current, GameState.flask_max]
		_flask_button.disabled = (GameState.flask_current <= 0) or (pcur >= pmax)

## 使用血瓶（死亡细胞风格）
func _on_use_flask() -> void:
	var msg: String = GameState.use_flask()
	show_message(msg)
	_refresh_char_status()

# ============================================================
#  道具栏
# ============================================================

func _build_item_buttons() -> void:
	for b in _item_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_item_buttons.clear()

	for item in GameState.item_bag:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(112, 32)
		btn.text = "[%s] %s" % [_rarity_s(item.rarity), item.item_name]
		btn.tooltip_text = "%s\n效果: %s\n点击使用" % [item.item_name, item.description]
		btn.add_theme_font_size_override("font_size", 11)

		if item.effect_type == "heal":
			btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))

		btn.pressed.connect(_on_map_item_used.bind(item))
		_item_panel.add_child(btn)
		_item_buttons.append(btn)

	# 空位填充
	var empty_count: int = GameState.MAX_ITEMS - GameState.item_bag.size()
	for _i in range(empty_count):
		var empty := Button.new()
		empty.text = "[空]"
		empty.disabled = true
		empty.custom_minimum_size = Vector2(112, 32)
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
		_item_panel.add_child(empty)
		_item_buttons.append(empty)

func _on_map_item_used(item: BattleItemData) -> void:
	var result: String = GameState.use_item_effect(item)
	show_message(result)
	_build_item_buttons()
	_refresh_char_status()

# ============================================================
#  王牌管理面板（左下角弹窗）
# ============================================================

func _show_trump_dialog() -> void:
	if _trump_dialog != null:
		_trump_dialog.queue_free()
		_trump_dialog = null

	_trump_dialog = PanelContainer.new()
	_trump_dialog.position = Vector2(8, 120)
	_trump_dialog.custom_minimum_size = Vector2(340.0, 420.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.16, 0.96)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_trump_dialog.add_theme_stylebox_override("panel", style)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	_trump_dialog.add_child(outer_vbox)

	# 标题栏
	var title_row := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "王牌管理 (总%d/手%d)" % [GameState.get_total_trump_count(), GameState.current_trump_hand.size()]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title_row.add_child(title_lbl)
	title_row.add_child(_make_spacer(true))

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(26, 26)
	close_btn.pressed.connect(_hide_trump_dialog)
	title_row.add_child(close_btn)
	outer_vbox.add_child(title_row)

	# 手牌区
	var hand_lbl := Label.new()
	hand_lbl.text = "装备中 (手牌 %d/%d):" % [GameState.current_trump_hand.size(), GameState.MAX_TRUMP_HAND]
	hand_lbl.add_theme_font_size_override("font_size", 11)
	hand_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	outer_vbox.add_child(hand_lbl)

	_trump_hand_box = VBoxContainer.new()
	outer_vbox.add_child(_trump_hand_box)

	# 分隔
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 2)
	outer_vbox.add_child(sep)

	# 背包区
	var bag_lbl := Label.new()
	bag_lbl.text = "背包 (共%d/%d):" % [GameState.trump_bag.size(), GameState.MAX_TOTAL_TRUMPS]
	bag_lbl.add_theme_font_size_override("font_size", 11)
	bag_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.45))
	outer_vbox.add_child(bag_lbl)

	_trump_bag_box = VBoxContainer.new()
	outer_vbox.add_child(_trump_bag_box)

	# 详情
	_trump_detail_label = Label.new()
	_trump_detail_label.add_theme_font_size_override("font_size", 10)
	_trump_detail_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	outer_vbox.add_child(_trump_detail_label)

	_redraw_trump_dialog()
	add_child(_trump_dialog)

func _redraw_trump_dialog() -> void:
	if _trump_hand_box == null or _trump_bag_box == null:
		return
	# 清除交换选中状态（重绘后行引用失效）
	_clear_swap_selection()
	for child in _trump_hand_box.get_children():
		child.queue_free()
	for child in _trump_bag_box.get_children():
		child.queue_free()

	for c in GameState.current_trump_hand:
		_trump_hand_box.add_child(_make_trump_row(c, true))
	for c in GameState.trump_bag:
		_trump_bag_box.add_child(_make_trump_row(c, false))

func _make_trump_row(card: TrumpCardData, is_hand: bool) -> PanelContainer:
	# 外层Panel：整行可点击（用于交换选择）
	var row_panel := PanelContainer.new()
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row_panel.add_child(row)

	# 主按钮：点击触发交换选择逻辑（替代gui_input，因为Button会吞掉鼠标事件）
	var btn := Button.new()
	btn.text = "[%s] %s" % [_rarity_t(card.rarity), card.card_name]
	btn.tooltip_text = "%s\n使用次数: %d\n提示: %s\n(点击选中进行交换)" % [card.description, card.uses_per_battle, card.tip]
	btn.custom_minimum_size = Vector2(185, 26)
	btn.add_theme_font_size_override("font_size", 10)

	match card.rarity:
		TrumpCardData.Rarity.NORMAL: btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		TrumpCardData.Rarity.RARE: btn.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		TrumpCardData.Rarity.EPIC: btn.add_theme_color_override("font_color", Color(0.8, 0.3, 1.0))
		TrumpCardData.Rarity.LEGENDARY: btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))

	# 点击主按钮 → 交换选择模式（核心修复：用btn.pressed替代gui_input）
	btn.pressed.connect(_on_trump_row_clicked.bind(row_panel, card, is_hand))
	row.add_child(btn)

	if is_hand:
		var unequip := Button.new()
		unequip.text = "↓"
		unequip.custom_minimum_size = Vector2(24, 24)
		unequip.add_theme_font_size_override("font_size", 11)
		unequip.tooltip_text = "卸下到背包"
		unequip.pressed.connect(_on_unequip_trump.bind(card))
		row.add_child(unequip)

		# 手牌直接丢弃
		var del_h := Button.new()
		del_h.text = "✕"
		del_h.custom_minimum_size = Vector2(24, 24)
		del_h.add_theme_font_size_override("font_size", 11)
		del_h.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		del_h.tooltip_text = "直接丢弃"
		del_h.pressed.connect(_on_delete_trump_from_hand.bind(card))
		row.add_child(del_h)
	else:
		var equip := Button.new()
		equip.text = "↑"
		equip.custom_minimum_size = Vector2(24, 24)
		equip.add_theme_font_size_override("font_size", 11)
		equip.tooltip_text = "装备到手牌"
		if GameState.current_trump_hand.size() >= GameState.MAX_TRUMP_HAND:
			equip.disabled = true
		equip.pressed.connect(_on_equip_trump.bind(card))
		row.add_child(equip)

		var del := Button.new()
		del.text = "✕"
		del.custom_minimum_size = Vector2(24, 24)
		del.add_theme_font_size_override("font_size", 11)
		del.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		del.tooltip_text = "永久丢弃"
		del.pressed.connect(_on_delete_trump.bind(card))
		row.add_child(del)

	# === 整行点击：使用btn.pressed信号（不再用gui_input，解决Button吞事件问题） ===
	# (已通过 btn.pressed.connect(_on_trump_row_clicked) 绑定在上面)

	return row_panel

func _on_trump_detail(card: TrumpCardData) -> void:
	_selected_trump = card
	if _trump_detail_label != null:
		_trump_detail_label.text = "%s | %s\n%s" % [_rarity_t(card.rarity), card.card_name, card.description]

## 整行点击：交换选择模式（通过Button.pressed触发，解决gui_input被Button吞事件的问题）
func _on_trump_row_clicked(row_control: Control, card: TrumpCardData, is_hand: bool) -> void:
	# 情况1：已有选中，且点击的是另一区的牌 → 执行交换
	if _swap_selected_card != null and _swap_selected_card != card and _swap_selected_is_hand != is_hand:
		_do_swap_cards(_swap_selected_card, _swap_selected_is_hand, card, is_hand)
		_clear_swap_selection()
		_redraw_trump_dialog()
		_refresh_trump_dialog_title()
		return

	# 情况2：点击已选中的同一行 → 取消选择
	if _swap_selected_card == card:
		_clear_swap_selection()
		return

	# 情况3：新选中 → 先清除旧选中状态，再高亮新行
	if _selected_row_control != null:
		_update_row_highlight(_selected_row_control, false)
	_swap_selected_card = card
	_swap_selected_is_hand = is_hand
	_selected_row_control = row_control
	_update_row_highlight(row_control, true)

	# 在详情区显示提示 + 卡牌详情
	if _trump_detail_label != null:
		var section: String = "手牌" if is_hand else "背包"
		_trump_detail_label.text = "已选中: [%s] %s (%s)\n点击%s区的牌来完成交换\n\n%s" % [
			_rarity_t(card.rarity), card.card_name, section,
			"背包" if is_hand else "手牌",
			card.description
		]

## 执行两张牌的交换
func _do_swap_cards(src: TrumpCardData, src_is_hand: bool, dst: TrumpCardData, dst_is_hand: bool) -> void:
	if src_is_hand and not dst_is_hand:
		# 手牌→背包（卸下src）+ 背包→手牌（装备dst）
		if GameState.current_trump_hand.size() <= 1:
			show_message("至少需要保留1张王牌在手牌中！")
			return
		GameState.unequip_trump_to_bag(src)
		GameState.equip_trump_from_bag(dst)
	elif not src_is_hand and dst_is_hand:
		# 背包→手牌（装备src）+ 手牌→背包（卸下dst）
		if GameState.current_trump_hand.size() <= 1:
			show_message("至少需要保留1张王牌在手牌中！")
			return
		GameState.equip_trump_from_bag(src)
		GameState.unequip_trump_to_bag(dst)

	if _trump_detail_label != null:
		_trump_detail_label.text = "交换完成！"

## 清除交换选择状态
func _clear_swap_selection() -> void:
	_swap_selected_card = null
	_swap_selected_is_hand = false
	if _selected_row_control != null:
		_update_row_highlight(_selected_row_control, false)
		_selected_row_control = null

## 更新行的高亮状态
func _update_row_highlight(row_control: Control, highlighted: bool) -> void:
	if row_control == null:
		return
	if highlighted:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.45, 0.30, 0.7)
		style.set_corner_radius_all(4)
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		row_control.add_theme_stylebox_override("panel", style)
	else:
		row_control.remove_theme_stylebox_override("panel")

func _on_equip_trump(card: TrumpCardData) -> void:
	if GameState.equip_trump_from_bag(card):
		_redraw_trump_dialog()
		_refresh_trump_dialog_title()

func _on_unequip_trump(card: TrumpCardData) -> void:
	if GameState.current_trump_hand.size() <= 1:
		show_message("至少需要保留1张王牌在手牌中！")
		return
	if GameState.unequip_trump_to_bag(card):
		_redraw_trump_dialog()
		_refresh_trump_dialog_title()

func _on_delete_trump(card: TrumpCardData) -> void:
	GameState.delete_trump_from_bag(card)
	_redraw_trump_dialog()
	_refresh_trump_dialog_title()
	if _trump_detail_label != null:
		_trump_detail_label.text = "已丢弃: %s" % card.card_name

## 直接丢弃手牌中的王牌
func _on_delete_trump_from_hand(card: TrumpCardData) -> void:
	if GameState.current_trump_hand.size() <= 1:
		show_message("至少需要保留1张王牌在手牌中！")
		return
	GameState.delete_trump_from_hand(card)
	_redraw_trump_dialog()
	_refresh_trump_dialog_title()
	if _trump_detail_label != null:
		_trump_detail_label.text = "已丢弃: %s" % card.card_name

func _refresh_trump_dialog_title() -> void:
	if _trump_dialog == null:
		return
	var outer: VBoxContainer = _trump_dialog.get_child(0) as VBoxContainer
	if outer == null:
		return
	var title_row: HBoxContainer = outer.get_child(0) as HBoxContainer
	if title_row == null:
		return
	var title: Label = title_row.get_child(0) as Label
	if title != null:
		title.text = "王牌管理 (总%d/手%d)" % [GameState.get_total_trump_count(), GameState.current_trump_hand.size()]

func _hide_trump_dialog() -> void:
	if _trump_dialog != null:
		_trump_dialog.queue_free()
		_trump_dialog = null

# ============================================================
#  消息弹窗
# ============================================================

## 显示消息弹窗（宝箱/事件结果等）— 支持自动倒计时关闭
var _message_auto_timer: float = 0.0
var _message_auto_close: bool = false

func show_message(msg: String, auto_close_sec: float = 0.0) -> void:
	if _message_overlay != null:
		_message_overlay.queue_free()

	_message_overlay = ColorRect.new()
	_message_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	_message_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(380, 180)

	_message_label = Label.new()
	_message_label.text = msg
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 17)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	vbox.add_child(_message_label)

	var ok := Button.new()
	if auto_close_sec > 0.0:
		ok.text = "确定 (%.1f)" % auto_close_sec
		_message_auto_timer = auto_close_sec
		_message_auto_close = true
	else:
		ok.text = "确定"
		_message_auto_close = false
	ok.custom_minimum_size = Vector2(130, 38)
	ok.add_theme_font_size_override("font_size", 15)
	ok.pressed.connect(_on_message_ok)
	vbox.add_child(ok)

	_message_overlay.add_child(vbox)
	add_child(_message_overlay)

## 每帧处理：消息弹窗自动倒计时关闭
func _process(_delta: float) -> void:
	if _message_auto_close and _message_auto_timer > 0.0:
		_message_auto_timer -= _delta
		# 更新按钮文字显示剩余时间
		if _message_overlay != null and _message_auto_timer > 0.0:
			var vbox: VBoxContainer = _message_overlay.get_child(0) as VBoxContainer
			if vbox != null and vbox.get_child_count() >= 2:
				var ok_btn: Button = vbox.get_child(1) as Button
				if ok_btn != null and _message_auto_timer > 0.0:
					ok_btn.text = "确定 (%.1f)" % maxf(0.0, _message_auto_timer)
		if _message_auto_timer <= 0.0:
			_message_auto_close = false
			_on_message_ok()

func _on_message_ok() -> void:
	if _message_overlay != null:
		_message_overlay.queue_free()
		_message_overlay = null

	# 如果已经通关，确定后回到主菜单
	if _game_clear and _current_layer >= TOTAL_LAYERS:
		_on_back_pressed()

## ============================================================
##  确认弹窗（确定 / 取消）
## ============================================================
## 显示确认弹窗，点击"确定"时调用 [on_confirm]，点击"取消"仅关闭
func _show_confirm(msg: String, on_confirm: Callable) -> void:
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
	_confirm_overlay = ColorRect.new()
	_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 200)

	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	vbox.add_child(lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)

	var btn_yes := Button.new()
	btn_yes.text = "确定"
	btn_yes.custom_minimum_size = Vector2(120, 42)
	btn_yes.add_theme_font_size_override("font_size", 15)
	btn_yes.pressed.connect(_on_confirm_yes.bind(on_confirm))
	hbox.add_child(btn_yes)

	var btn_no := Button.new()
	btn_no.text = "取消"
	btn_no.custom_minimum_size = Vector2(120, 42)
	btn_no.add_theme_font_size_override("font_size", 15)
	btn_no.pressed.connect(_on_confirm_no)
	hbox.add_child(btn_no)

	vbox.add_child(hbox)
	_confirm_overlay.add_child(vbox)
	add_child(_confirm_overlay)

func _on_confirm_yes(on_confirm: Callable) -> void:
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	on_confirm.call()

func _on_confirm_no() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
		_confirm_overlay = null

func _on_back_pressed() -> void:
	# 先关闭可能打开的弹窗（消息弹窗/确认弹窗/王牌面板）
	if _message_overlay != null:
		_message_overlay.queue_free()
		_message_overlay = null
		_message_auto_close = false
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	if _trump_dialog != null:
		_trump_dialog.queue_free()
		_trump_dialog = null

	# 安全结束冒险（存档失败不阻止返回）
	if GameState.is_battle_active:
		GameState.end_run(false, _current_layer)

	# 延迟一帧切换场景（确保当前帧处理完毕）
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main/main_menu.tscn")

## 测试用跳过键：有节点就跳节点，没节点就进下一层（无弹窗，直接生效）
func _on_skip_pressed() -> void:
	if _game_clear:
		return

	# 1) 先找第一个可达且未访问的节点
	var target: MapNode = null
	for n in _map_nodes:
		var node: MapNode = n as MapNode
		if _is_node_reachable(node):
			target = node
			break

	if target != null:
		# 有节点 → 直接跳过（不弹窗）
		target.visited = true
		_current_node_id = target.node_id
		GameState.map_visited[target.node_id] = true
		_refresh_all()
		return

	# 2) 没有可达节点了 → 直接进下一层
	if _current_layer >= TOTAL_LAYERS - 1:
		return
	# 推进层数 + 清理旧数据 + 重生成新层地图
	GameState.current_round += 1
	GameState.map_visited.clear()
	_generate_new_map()
	_refresh_all()


# ============================================================
#  工具函数
# ============================================================

func _rarity_s(rarity: BattleItemData.Rarity) -> String:
	match rarity:
		BattleItemData.Rarity.COMMON: return "N"
		BattleItemData.Rarity.RARE: return "R"
		BattleItemData.Rarity.EPIC: return "SR"
		BattleItemData.Rarity.LEGENDARY: return "SSR"
	return "?"

func _rarity_t(rarity: TrumpCardData.Rarity) -> String:
	match rarity:
		TrumpCardData.Rarity.NORMAL: return "N"
		TrumpCardData.Rarity.RARE: return "R"
		TrumpCardData.Rarity.EPIC: return "SR"
		TrumpCardData.Rarity.LEGENDARY: return "SSR"
	return "?"

func _make_spacer(horizontal: bool) -> Control:
	var spacer := Control.new()
	if horizontal:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer
