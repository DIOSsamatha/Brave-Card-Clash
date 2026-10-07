## 战斗场景主控制器 v5
## 流程：选姿态(弹窗) → 自动选王牌(根据姿态偏好) → 拼点(要牌/停牌) → 结算 → 自动下一局
## 战斗胜利后：全屏遮罩弹窗[继续冒险] → 进入下一层/新敌人（三保险：按钮+点击屏幕+自动倒计时）
extends Control

# === 顶部 ===
@onready var title_label: Label = $TopBar/TitleLabel

# === 左侧：玩家 ===
@onready var player_name_label: Label = $MainArea/PlayerPanel/PlayerNameLabel
@onready var player_hp_bar: ProgressBar = $MainArea/PlayerPanel/PlayerHPBox/PlayerHPBar
@onready var player_hp_label: Label = $MainArea/PlayerPanel/PlayerHPBox/PlayerHPLabel
@onready var player_hand_label: Label = $MainArea/PlayerPanel/PlayerHandLabel
@onready var player_stance_label: Label = $MainArea/PlayerPanel/PlayerStatusLabel
@onready var player_portrait: TextureRect = $PlayerPortrait

# === 右侧：敌人 ===
@onready var enemy_name_label: Label = $MainArea/EnemyPanel/EnemyNameLabel
@onready var enemy_hp_bar: ProgressBar = $MainArea/EnemyPanel/EnemyHPBox/EnemyHPBar
@onready var enemy_hp_label: Label = $MainArea/EnemyPanel/EnemyHPBox/EnemyHPLabel
@onready var enemy_hand_label: Label = $MainArea/EnemyPanel/EnemyHandLabel
@onready var enemy_stance_label: Label = $MainArea/EnemyPanel/EnemyStatusLabel
@onready var enemy_portrait: TextureRect = $EnemyPortrait

# === 底部控制区 ===
@onready var status_effect_label: Label = $BottomBar/StatusEffectLabel
@onready var result_label: Label = $BottomBar/ResultLabel
@onready var log_label: Label = $BottomBar/LogLabel
@onready var hit_button: Button = $BottomBar/ActionRow/HitButton
@onready var stand_button: Button = $BottomBar/ActionRow/StandButton
@onready var double_button: Button = $BottomBar/ActionRow/DoubleButton

# === 姿态选择弹窗 ===
@onready var stance_overlay: PanelContainer = $StanceOverlay
@onready var stance_buttons: HBoxContainer = $StanceOverlay/StanceVBox/StanceButtons

# === 结算/继续弹窗（全屏ColorRect遮罩，100%可见）===
@onready var round_end_overlay: ColorRect = $RoundEndOverlay
@onready var round_end_label: Label = $RoundEndOverlay/RoundEndVBox/RoundEndLabel
@onready var next_round_button: Button = $RoundEndOverlay/RoundEndVBox/NextRoundButton

# === 王牌面板（底部信息+可选点击）===
@onready var trump_cards_container: HBoxContainer = $BottomBar/TrumpPanel/TrumpScroll/TrumpCards

# === 道具面板 ===
@onready var item_buttons_container: HBoxContainer = $BottomBar/ItemPanel/ItemScroll/ItemButtons
var _item_panel: Control = null  # 运行时reparent后持有引用，避免路径失效

# === 血瓶按钮（死亡细胞风格）===
var _flask_button: Button = null

# === 技能按钮（动态创建）===
var _skill1_button: Button = null
var _skill2_button: Button = null

# === 预计伤害显示 ===
@onready var predict_label: Label = $MainArea/PlayerPanel/PredictLabel

# === 层主题背景图 ===
var _background_tex: TextureRect = null

# === 设置按钮 + 弹窗菜单 ===
var _settings_button: Button = null
var _settings_menu: Panel = null

# === 敌人技能悬浮提示 ===
var _skill_tooltip: Panel = null
var _skill_tooltip_label: RichTextLabel = null

## 各职业立绘路径（按 CharacterData.ClassType 索引）
const CLASS_PORTRAITS: PackedStringArray = [
	"res://resources/characters/swordsman.png",  # SWORDSMAN
	"res://resources/characters/mage.png",       # MAGE
	"res://resources/characters/thief.png",      # THIEF
	"res://resources/characters/priest.png",     # PRIEST
]

## 各层背景图路径（按 current_round 索引）
const LAYER_BACKGROOUNDS: PackedStringArray = [
	"res://resources/backgrounds/layer0_fairy.jpg",      # 第1层 妖精幻境
	"res://resources/backgrounds/layer1_crystal.png",     # 第2层 水晶幻境
	"res://resources/backgrounds/layer2_fire.png",        # 第3层 火焰幻境
	"res://resources/backgrounds/layer3_shadow.png",      # 第4层 暗影幻境
	"res://resources/backgrounds/layer4_castle.png",      # 第5层 魔王城前庭
	"res://resources/backgrounds/layer5_demonlord.png",   # 第6层 魔王之间
]

var _battle: BattleManager
var _waiting_for_stance: bool = false
var _battle_over: bool = false
var _round_ended: bool = false
var _game_cleared: bool = false          # 通关后等待返回主菜单
var _sub_round_count: int = 0
var _current_enemy: EnemyData = null
var _trump_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []
var _selected_trump: TrumpCardData = null   # 本小局选中的王牌
var _auto_advance_timer: float = 0.0        # 自动下一局倒计时
var _is_auto_advancing: bool = false        # 是否正在自动推进中
var _is_round_animating: bool = false       # 是否正在播放小局结束动画（屏蔽输入）
var _trump_cycle_index: int = 0             # 王牌循环索引（用于自动选取）
var _defeated: bool = false                 # 是否已战败（决定返回主菜单还是继续冒险）
var _pending_trump_loot: TrumpCardData = null  # 待安装的王牌战利品（手牌满时暂存）

# === 抽牌二选一弹窗 ===
var _choice_overlay: Control = null          # 二选一遮罩面板
var _choice_card_buttons: Array[Button] = [] # 两张牌的按钮
var _swap_overlay: Control = null            # 换牌遮罩面板
var _swap_card_buttons: Array[Button] = []   # 手牌选择按钮

func _ready() -> void:
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.hand_changed.connect(_on_hand_changed)
	EventBus.round_result.connect(_on_round_result)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.round_started.connect(_on_round_started)
	EventBus.player_busted.connect(_on_player_busted)
	EventBus.card_drawn.connect(_on_card_drawn)
	EventBus.battle_log.connect(_on_battle_log)

	# 初始化玩家数据
	if GameState.selected_character != null and GameState.is_battle_active:
		GameState.setup_player_from_character(GameState.selected_character, GameState.selected_char_level)
	else:
		GameState.setup_player(45.0, 5.0)

	# 选择敌人（优先使用地图传入的敌人数据）
	if GameState.current_enemy_data != null:
		_current_enemy = GameState.current_enemy_data
		# 地图已设置血量等数据，不重复覆盖
	else:
		_current_enemy = EnemyDatabase.get_random_enemy(EnemyData.Tier.FAIRY)
		GameState.setup_enemy_from_data(_current_enemy)

	# 构建面板
	_build_trump_buttons()
	_build_item_buttons()
	_create_flask_button()
	_create_skill_buttons()

	# 将道具面板并入王牌行（与血瓶同理，避免被BottomBar挤出屏幕而不可见）
	var ip := $BottomBar/ItemPanel as Control
	if ip != null:
		ip.reparent($BottomBar/TrumpPanel)
		_item_panel = ip  # 保存引用，避免路径变化后找不到

	# 设置层主题背景图（在所有UI之前，作为最底层）
	_setup_background()

	# 创建右上角设置按钮
	_create_settings_button()

	# 创建敌人技能悬浮提示
	_create_skill_tooltip()

	_start_new_battle()

func _input(event: InputEvent) -> void:
	# 设置菜单打开时，点击外部关闭菜单
	if event is InputEventMouseButton and event.pressed:
		if _settings_menu != null and _settings_menu.visible:
			# 检查点击是否在菜单/按钮区域外
			var mouse_pos: Vector2 = get_global_mouse_position()
			if not (_settings_menu.get_global_rect().has_point(mouse_pos)
					or _settings_button.get_global_rect().has_point(mouse_pos)):
				_settings_menu.visible = false
				return

	# 战斗/小局结束后：点击屏幕任意位置也可继续（动画期间不响应）
	if event is InputEventMouseButton and event.pressed:
		if not _is_round_animating and (_battle_over or (_round_ended and not _is_auto_advancing)):
			_do_continue()

func _process(_delta: float) -> void:
	# 自动下一局倒计时
	if _is_auto_advancing and _auto_advance_timer > 0.0:
		_auto_advance_timer -= _delta
		# 更新按钮文字显示倒数
		if next_round_button.visible:
			next_round_button.text = "自动继续 (%.1f)" % maxf(0.0, _auto_advance_timer)
		if _auto_advance_timer <= 0.0:
			_is_auto_advancing = false
			_do_continue()

	# 敌人技能悬浮提示检测
	_update_skill_tooltip_hover()

func _start_new_battle() -> void:
	_battle = BattleManager.new()
	_battle.set_enemy(_current_enemy)
	_battle_over = false
	_round_ended = false
	_defeated = false
	_sub_round_count = 0
	_is_auto_advancing = false
	_auto_advance_timer = 0.0
	_trump_cycle_index = 0
	GameState.reset_battle()
	_update_all_display()
	_hide_actions()
	_refresh_panel_enabled(false)
	status_effect_label.text = "状态: 无"
	log_label.text = ""
	result_label.text = ""
	_show_stance_selection()

## 创建右上角设置按钮（⚙️）+ 弹出菜单
func _create_settings_button() -> void:
	# 设置按钮
	_settings_button = Button.new()
	_settings_button.text = "⚙"
	_settings_button.tooltip_text = "设置"
	_settings_button.custom_minimum_size = Vector2(40.0, 36.0)
	_settings_button.add_theme_font_size_override("font_size", 18)
	_settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_settings_button.position = Vector2(-50.0, 6.0)
	_settings_button.z_index = 10
	_settings_button.pressed.connect(_on_settings_pressed)
	add_child(_settings_button)

	# 弹出菜单面板（初始隐藏）
	_settings_menu = Panel.new()
	_settings_menu.visible = false
	_settings_menu.set_meta("internal_name", "SettingsMenu")
	_settings_menu.custom_minimum_size = Vector2(190.0, 140.0)
	_settings_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_settings_menu.position = Vector2(-195.0, 46.0)
	_settings_menu.z_index = 200

	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.15, 0.13, 0.22, 0.96)
	menu_style.border_color = Color(0.5, 0.45, 0.7, 0.8)
	menu_style.set_border_width_all(1)
	menu_style.set_corner_radius_all(6)
	var menu_theme := Theme.new()
	menu_theme.set_stylebox("panel", "Panel", menu_style)
	_settings_menu.theme = menu_theme

	var vbox := VBoxContainer.new()
	vbox.set_meta("internal_name", "MenuVBox")
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 8)
	_settings_menu.add_child(vbox)

	# 菜单标题
	var title_lbl := Label.new()
	title_lbl.text = "⚙ 设置"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(title_lbl)

	# 保存存档按钮
	var save_btn := Button.new()
	save_btn.text = "💾 保存存档"
	save_btn.pressed.connect(_on_save_game)
	vbox.add_child(save_btn)

	# 退出战斗按钮
	var exit_btn := Button.new()
	exit_btn.text = "🚪 退出战斗（回地图）"
	exit_btn.pressed.connect(_on_exit_battle)
	vbox.add_child(exit_btn)

	# 返回主菜单按钮
	var menu_btn := Button.new()
	menu_btn.text = "🏠 返回主菜单"
	menu_btn.pressed.connect(_on_return_to_main_menu)
	vbox.add_child(menu_btn)

	add_child(_settings_menu)

## 点击设置按钮 → 显示/隐藏菜单
func _on_settings_pressed() -> void:
	if _settings_menu != null:
		_settings_menu.visible = not _settings_menu.visible

## 退出当前战斗，返回地图界面
func _on_exit_battle() -> void:
	if _settings_menu != null:
		_settings_menu.visible = false
	# 标记战斗结束但不触发胜利结算
	_battle_over = true
	_defeated = false
	GameState.is_battle_active = false
	get_tree().change_scene_to_file("res://scenes/map/map_scene.tscn")

## 放弃本次冒险，返回主菜单
func _on_return_to_main_menu() -> void:
	if _settings_menu != null:
		_settings_menu.visible = false
	_battle_over = true
	_defeated = true
	GameState.is_battle_active = false
	# 返回主菜单前自动保存星尘/升级等永久进度
	SaveSystem.save_game()
	GameState.reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

## 保存当前游戏进度（星尘、升级等永久数据）
func _on_save_game() -> void:
	if _settings_menu != null:
		_settings_menu.visible = false
	if SaveSystem.save_game():
		EventBus.battle_log.emit("💾 存档成功！星尘和升级已保存")
	else:
		EventBus.battle_log.emit("❌ 存档失败，请重试")

## 创建敌人技能悬浮提示面板（隐藏状态）
func _create_skill_tooltip() -> void:
	_skill_tooltip = Panel.new()
	_skill_tooltip.set_meta("internal_name", "EnemySkillTooltip")
	_skill_tooltip.visible = false
	_skill_tooltip.z_index = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.18, 0.95)
	style.border_color = Color(0.7, 0.5, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	var theme := Theme.new()
	theme.set_stylebox("panel", "Panel", style)
	_skill_tooltip.theme = theme

	_skill_tooltip_label = RichTextLabel.new()
	_skill_tooltip_label.set_meta("internal_name", "SkillTooltipContent")
	_skill_tooltip_label.bbcode_enabled = true
	_skill_tooltip_label.fit_content = true
	_skill_tooltip_label.custom_minimum_size = Vector2(260.0, 0.0)
	_skill_tooltip_label.add_theme_font_size_override("normal_font_size", 14)
	_skill_tooltip.add_child(_skill_tooltip_label)

	add_child(_skill_tooltip)

## 每帧检测鼠标是否悬浮在敌人技能标签上
func _update_skill_tooltip_hover() -> void:
	if _skill_tooltip == null or enemy_stance_label == null:
		return
	if not is_inside_tree() or get_viewport() == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var label_rect: Rect2 = enemy_stance_label.get_global_rect()

	if label_rect.has_point(mouse_pos):
		# 鼠标在技能标签上 → 显示提示
		if not _skill_tooltip.visible and _current_enemy != null:
			_build_and_show_skill_tooltip(mouse_pos, label_rect)
		elif _skill_tooltip.visible:
			# 跟随鼠标（微调位置避免遮挡）
			_position_skill_tooltip(mouse_pos, label_rect)
	else:
		# 鼠标移开 → 隐藏
		if _skill_tooltip.visible:
			_skill_tooltip.visible = false

## 构建并显示技能提示内容
func _build_and_show_skill_tooltip(mouse_pos: Vector2, label_rect: Rect2) -> void:
	if _current_enemy == null:
		return

	var title_text: String = ""
	var body_text: String = ""

	if _current_enemy.has_special and _current_enemy.special_name != "":
		title_text = "[color=#ffcc44][b]%s[/b][/color]" % _current_enemy.special_name
		if _current_enemy.special_desc != "":
			body_text = "\n%s" % _current_enemy.special_desc
		elif _current_enemy.description != "":
			body_text = "\n%s" % _current_enemy.description
		else:
			body_text = "\n[color=#888888]暂无详细描述[/color]"
	else:
		title_text = "[color=#aaaaaa]无特殊技能[/color]"
		body_text = ""

	# 触发概率
	if _current_enemy.special_trigger_chance > 0.0 and _current_enemy.special_trigger_chance < 1.0:
		body_text += "\n\n[color=#99aaff]触发概率: %.0f%%[/color]" % (_current_enemy.special_trigger_chance * 100.0)

	_skill_tooltip_label.text = title_text + body_text
	_skill_tooltip_label.fit_content = true

	_position_skill_tooltip(mouse_pos, label_rect)
	_skill_tooltip.visible = true

## 定位技能提示面板（避免超出屏幕）
func _position_skill_tooltip(mouse_pos: Vector2, label_rect: Rect2) -> void:
	var tip_size: Vector2 = _skill_tooltip_label.size + Vector2(24.0, 16.0)  # padding
	# 默认显示在标签上方偏左
	var pos_x: float = label_rect.position.x
	var pos_y: float = label_rect.position.y - tip_size.y - 8.0

	# 如果上方空间不够，改到下方
	if pos_y < 10.0:
		pos_y = label_rect.end.y + 8.0

	# 如果右侧超出屏幕，左移
	if pos_x + tip_size.x > get_viewport().get_visible_rect().size.x - 10.0:
		pos_x = get_viewport().get_visible_rect().size.x - tip_size.x - 10.0

	# 最左边界
	if pos_x < 10.0:
		pos_x = 10.0

	_skill_tooltip.position = Vector2(pos_x, pos_y)
	_skill_tooltip.custom_minimum_size = tip_size

## 更新所有显示（血量、手牌、名称等）
func _update_all_display() -> void:
	_update_hp_display()
	_update_name_display()
	_update_title_display()
	if _battle != null:
		player_hand_label.text = "你的手牌: " + _battle.get_player_hand_description()
		enemy_hand_label.text = "庄家手牌: " + _battle.get_dealer_hand_description()

func _update_hp_display() -> void:
	var p_max := GameState.player_max_health
	var p_cur := GameState.player_health
	player_hp_bar.max_value = p_max
	player_hp_bar.value = p_cur
	player_hp_label.text = "HP: %d/%d" % [int(p_cur), int(p_max)]

	var e_max := GameState.enemy_max_health
	var e_cur := GameState.enemy_health
	enemy_hp_bar.max_value = e_max
	enemy_hp_bar.value = e_cur
	enemy_hp_label.text = "HP: %d/%d" % [int(e_cur), int(e_max)]

func _update_name_display() -> void:
	if GameState.selected_character != null:
		player_name_label.text = GameState.selected_character.char_name
		_load_player_portrait(GameState.selected_character.class_type)
	else:
		player_name_label.text = "勇者"
		_load_player_portrait(CharacterData.ClassType.SWORDSMAN)

	if _current_enemy != null:
		enemy_name_label.text = _current_enemy.enemy_name
		# 显示敌方技能/能力名称（替换???）
		if _current_enemy.has_special and _current_enemy.special_name != "":
			enemy_stance_label.text = "技能: " + _current_enemy.special_name
		elif _current_enemy.description != "":
			# 取描述前20字作为技能提示
			var short_desc: String = _current_enemy.description
			if short_desc.length() > 20:
				short_desc = short_desc.substr(0, 20) + "..."
			enemy_stance_label.text = "能力: " + short_desc
		else:
			enemy_stance_label.text = "技能: 无"
	else:
		enemy_name_label.text = "敌人"
		enemy_stance_label.text = "技能: ???"
	_load_enemy_portrait()

## 根据职业类型加载玩家立绘
func _load_player_portrait(class_type: CharacterData.ClassType) -> void:
	var idx: int = int(class_type)
	idx = clampi(idx, 0, CLASS_PORTRAITS.size() - 1)
	var tex := load(CLASS_PORTRAITS[idx]) as Texture2D
	if tex != null:
		player_portrait.texture = tex
		player_portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		push_warning("BattleScene: 玩家立绘加载失败: %s" % CLASS_PORTRAITS[idx])
		# 兜底：运行时生成蓝色渐变占位图，确保节点可见
		var grad := GradientTexture2D.new()
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(0.15, 0.35, 0.65, 1.0))
		gradient.add_point(1.0, Color(0.35, 0.55, 0.85, 1.0))
		grad.gradient = gradient
		grad.width = 256
		grad.height = 256
		grad.fill_from = Vector2(0.0, 0.0)
		grad.fill_to = Vector2(0.0, 1.0)
		player_portrait.texture = grad
		player_portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)

## 加载敌人战斗立绘
func _load_enemy_portrait() -> void:
	if _current_enemy != null and _current_enemy.portrait != null:
		enemy_portrait.texture = _current_enemy.portrait
		enemy_portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	# 兜底：运行时生成一个紫色渐变占位图
	var grad := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.25, 0.15, 0.45, 1.0))
	gradient.add_point(1.0, Color(0.45, 0.25, 0.65, 1.0))
	grad.gradient = gradient
	grad.width = 256
	grad.height = 256
	grad.fill_from = Vector2(0.0, 0.0)
	grad.fill_to = Vector2(0.0, 1.0)
	enemy_portrait.texture = grad
	enemy_portrait.modulate = Color(0.7, 0.7, 0.9, 1.0)

func _update_title_display() -> void:
	var stage_name: String
	match GameState.current_round:
		0: stage_name = "妖精幻境"
		1: stage_name = "水晶幻境"
		2: stage_name = "火焰幻境"
		3: stage_name = "暗影幻境"
		4: stage_name = "魔王城前庭"
		5: stage_name = "魔王之间"
		_: stage_name = "幻境"
	title_label.text = "第 %d 层 - %s" % [GameState.current_round + 1, stage_name]

# ==================== 姿态选择 ====================

func _show_stance_selection() -> void:
	_hide_actions()
	stance_overlay.show()
	_waiting_for_stance = true

	var idx := 0
	for button in stance_buttons.get_children():
		if button is Button and idx < 3:
			var stance := StanceData.get_all_stances()[idx]
			button.text = "%s\n胜×%.1f / 负×%.1f" % [stance.name, stance.win_multiplier, stance.lose_multiplier]
			idx += 1

func _on_defensive_pressed() -> void:
	_select_stance(StanceData.StanceType.DEFENSIVE)

func _on_balanced_pressed() -> void:
	_select_stance(StanceData.StanceType.BALANCED)

func _on_aggressive_pressed() -> void:
	_select_stance(StanceData.StanceType.AGGRESSIVE)

## 选择姿态后：自动选王牌 → 进入拼点
func _select_stance(stance: StanceData.StanceType) -> void:
	if not _waiting_for_stance:
		return
	_waiting_for_stance = false
	stance_overlay.hide()
	_sub_round_count += 1

	var stance_name := StanceData.get_stance_name(stance)
	player_stance_label.text = "姿态: " + stance_name

	_battle.start_round()
	_battle.set_player_stance(stance)

	# === 自动选择王牌（根据姿态偏好）===
	_auto_select_trump(stance)

	# 应用效果并进入拼点阶段
	_apply_trump_effect(_selected_trump)

	log_label.text = "%s | 王牌:%s | 拼点开始！" % [stance_name, _selected_trump.card_name]
	player_stance_label.text = "姿态: %s | 王牌: %s" % [stance_name, _selected_trump.card_name]

	# 进入玩家操作阶段
	if _battle.phase == BattleManager.Phase.PLAYER_TURN:
		_show_player_actions()

## 根据姿态自动选择王牌（循环使用基础攻防牌）
func _auto_select_trump(stance: StanceData.StanceType) -> void:
	var hand: Array = GameState.current_trump_hand
	if hand.is_empty():
		return

	# 按姿态偏好筛选：进攻→攻击牌，防御→防御牌，均衡→交替
	var preferred_category: TrumpCardData.Category
	match stance:
		StanceData.StanceType.AGGRESSIVE:
			preferred_category = TrumpCardData.Category.OPERATION
		StanceData.StanceType.DEFENSIVE:
			preferred_category = TrumpCardData.Category.DEFENSE
		_:
			# 均衡姿态：攻击和防御交替
			_trump_cycle_index = (_trump_cycle_index + 1) % maxi(1, hand.size())
			_selected_trump = hand[_trump_cycle_index % hand.size()] as TrumpCardData
			return

	# 找到首选分类的牌，找不到就用第一张
	var found: TrumpCardData = null
	for i in range(hand.size()):
		var idx := (_trump_cycle_index + i) % hand.size()
		var card: TrumpCardData = hand[idx] as TrumpCardData
		if card.category == preferred_category:
			found = card
			_trump_cycle_index = (idx + 1) % hand.size()
			break

	if found == null:
		found = hand[_trump_cycle_index % hand.size()] as TrumpCardData
		_trump_cycle_index = (_trump_cycle_index + 1) % hand.size()

	_selected_trump = found

## 应用王牌效果到本局战斗（按分类统一处理）
func _apply_trump_effect(trump: TrumpCardData) -> void:
	match trump.category:
		TrumpCardData.Category.OPERATION:
			match trump.card_name:
				"换牌魔杖", "弃牌重抽", "顶牌置换", "置换魔方":
					# 换牌类：弹出手牌选择，手动选1张替换
					_request_swap_card(false, trump.card_name)
				"命运重构":
					# 自动换掉点数最高的风险牌
					_request_swap_card(true, trump.card_name)
				_:
					# 其余操作牌：effect_value 作为攻击加成（0=无加成的功能牌）
					if trump.effect_value > 0.0:
						_battle.set_active_trump_bonus("attack", trump.effect_value)
						EventBus.battle_log.emit("[%s]生效：本局伤害+%d%%" % [trump.card_name, int(trump.effect_value * 100)])
					else:
						EventBus.battle_log.emit("使用操作王牌: %s" % trump.card_name)
		TrumpCardData.Category.DEFENSE:
			# 防御类：effect_value 作为减伤比例
			if trump.card_name == "治疗药水":
				# 治疗药水：即时回复生命（原逻辑误写在 SPECIAL 分支，DEFENSE 类从不触发，此处修复）
				GameState.player_heal(12.0)
				_update_hp_display()
				EventBus.battle_log.emit("治疗药水：恢复12点生命")
			elif trump.effect_value > 0.0:
				_battle.set_active_trump_bonus("defense", trump.effect_value)
				EventBus.battle_log.emit("[%s]生效：本局减伤%d%%" % [trump.card_name, int(trump.effect_value * 100)])
			else:
				EventBus.battle_log.emit("使用防御王牌: %s" % trump.card_name)
		TrumpCardData.Category.INFO:
			# 信息类：不提供数值加成
			EventBus.battle_log.emit("信息王牌: %s" % trump.card_name)
		TrumpCardData.Category.SPECIAL:
			# 特殊类：按名称处理特殊效果
			_match_special_trump(trump)

## 处理特殊类王牌的个别效果
func _match_special_trump(trump: TrumpCardData) -> void:
	match trump.card_name:
		"沉默咒语":
			_battle.enemy_status.add_status(CombatStatus.StatusType.SILENCED, 1.0, 2)
			EventBus.battle_log.emit("沉默咒语：敌方沉默2回合")
		"吸血宝石":
			_battle.player_status.add_status(CombatStatus.StatusType.HEAL_ON_WIN, 6.0, 99)
			EventBus.battle_log.emit("吸血宝石：胜利时回复6点HP")
		_:
			EventBus.battle_log.emit("使用特殊王牌: %s" % trump.card_name)

# ==================== 操作按钮 ====================

func _show_player_actions() -> void:
	hit_button.text = "要牌"
	hit_button.remove_theme_color_override("font_color")
	hit_button.remove_theme_font_size_override("font_size")
	hit_button.show()
	stand_button.show()
	double_button.show()
	_refresh_panel_enabled(true)
	var can_double := (_battle.player_cards.size() == 2 and not _battle.has_doubled) \
		or (_battle.player_status.has_status(CombatStatus.StatusType.RE_DOUBLE) and _battle.player_cards.size() == 3)
	double_button.disabled = not can_double
	if _battle.player_status.has_status(CombatStatus.StatusType.FREEZE):
		double_button.disabled = true

	# 牌数提示
	var cards_left := BattleManager.MAX_PLAYER_CARDS - _battle.player_cards.size()
	if cards_left <= 0:
		hit_button.text = "已达上限"
		hit_button.disabled = true
	elif _battle._player_has_busted:
		# 爆牌后：禁用要牌，允许用道具/王牌后停牌结算
		hit_button.text = "已爆牌!"
		hit_button.disabled = true
		hit_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		stand_button.text = "结束回合(爆牌)"
		stand_button.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		hit_button.disabled = false
		stand_button.text = "停牌"
		stand_button.remove_theme_color_override("font_color")

	# 更新预计伤害显示
	_update_predict_damage()

	# 更新技能按钮
	_update_skill_buttons()

func _hide_actions() -> void:
	stance_overlay.hide()
	hit_button.hide()
	stand_button.hide()
	double_button.hide()
	round_end_overlay.hide()
	_refresh_panel_enabled(false)

## 播放小局结束动画（杀戮尖塔风格：胜利方前冲攻击，失败方受击抖动）
## 动画结束后自动弹出结算遮罩
func _play_round_end_animation(damage: float, result_text: String) -> void:
	# 锁定输入，防止动画期间误触
	_is_round_animating = true
	next_round_button.disabled = true

	var is_player_win := damage > 0.0
	var is_tie := damage == 0.0
	var tween := create_tween()
	tween.set_parallel(false)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	if is_tie:
		# 平局：双方轻微缩放
		tween.tween_property(player_portrait, "scale", Vector2(1.05, 1.05), 0.15)
		tween.parallel().tween_property(enemy_portrait, "scale", Vector2(1.05, 1.05), 0.15)
		tween.tween_property(player_portrait, "scale", Vector2(1.0, 1.0), 0.15)
		tween.parallel().tween_property(enemy_portrait, "scale", Vector2(1.0, 1.0), 0.15)
	elif is_player_win:
		# 玩家胜利：玩家向右前冲并放大，敌人受击抖动+变红
		var original_player_pos: Vector2 = player_portrait.position
		var original_enemy_pos: Vector2 = enemy_portrait.position
		var charge_offset: Vector2 = Vector2(80.0, 0.0)

		tween.tween_property(player_portrait, "position", original_player_pos + charge_offset, 0.18)
		tween.parallel().tween_property(player_portrait, "scale", Vector2(1.15, 1.15), 0.18)
		tween.tween_property(enemy_portrait, "modulate", Color(1.0, 0.4, 0.4, 1.0), 0.08)
		tween.parallel().tween_property(enemy_portrait, "position", original_enemy_pos + Vector2(10.0, 0.0), 0.05)
		tween.tween_property(enemy_portrait, "position", original_enemy_pos - Vector2(10.0, 0.0), 0.05)
		tween.tween_property(enemy_portrait, "position", original_enemy_pos + Vector2(6.0, 0.0), 0.05)
		tween.tween_property(enemy_portrait, "position", original_enemy_pos, 0.05)
		tween.tween_property(player_portrait, "position", original_player_pos, 0.18)
		tween.parallel().tween_property(player_portrait, "scale", Vector2(1.0, 1.0), 0.18)
		tween.parallel().tween_property(enemy_portrait, "modulate", Color(0.7, 0.7, 0.9, 1.0), 0.18)
	else:
		# 玩家失败：敌人向左前冲，玩家受击抖动+变红
		var original_player_pos: Vector2 = player_portrait.position
		var original_enemy_pos: Vector2 = enemy_portrait.position
		var charge_offset: Vector2 = Vector2(-80.0, 0.0)

		tween.tween_property(enemy_portrait, "position", original_enemy_pos + charge_offset, 0.18)
		tween.parallel().tween_property(enemy_portrait, "scale", Vector2(1.15, 1.15), 0.18)
		tween.tween_property(player_portrait, "modulate", Color(1.0, 0.4, 0.4, 1.0), 0.08)
		tween.parallel().tween_property(player_portrait, "position", original_player_pos - Vector2(10.0, 0.0), 0.05)
		tween.tween_property(player_portrait, "position", original_player_pos + Vector2(10.0, 0.0), 0.05)
		tween.tween_property(player_portrait, "position", original_player_pos - Vector2(6.0, 0.0), 0.05)
		tween.tween_property(player_portrait, "position", original_player_pos, 0.05)
		tween.tween_property(enemy_portrait, "position", original_enemy_pos, 0.18)
		tween.parallel().tween_property(enemy_portrait, "scale", Vector2(1.0, 1.0), 0.18)
		tween.parallel().tween_property(player_portrait, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

	tween.finished.connect(_on_round_end_animation_finished.bind(result_text))

## 动画结束回调：弹出结算遮罩
func _on_round_end_animation_finished(result_text: String) -> void:
	_is_round_animating = false
	_show_end_overlay(result_text, "下一小局", 1.5)
	_update_title_display()

## 显示结算弹窗（全屏ColorRect遮罩 + 居中按钮 + 自动倒计时 + 点击屏幕继续）
func _show_end_overlay(title_text: String, btn_text: String, delay: float) -> void:
	_hide_actions()
	round_end_label.text = title_text
	next_round_button.text = btn_text
	next_round_button.disabled = false
	round_end_overlay.show()
	_start_auto_advance(delay)

## 显示抽牌二选一弹窗
func _show_card_choice(cards: Array) -> void:
	# 隐藏操作按钮
	_hide_actions()

	# 每次都重建遮罩面板（避免子节点复用问题）
	if _choice_overlay != null:
		_choice_overlay.queue_free()
		_choice_overlay = null

	_choice_overlay = Control.new()
	_choice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var choice_bg := ColorRect.new()
	choice_bg.color = Color(0.0, 0.0, 0.0, 0.8)
	choice_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(choice_bg)

	# 标题
	var title_lbl := Label.new()
	title_lbl.text = "选择一张牌加入手牌"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.position = Vector2(0, get_window().size.y / 2 - 120)
	title_lbl.size = Vector2(get_window().size.x, 40)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	_choice_overlay.add_child(title_lbl)

	# 两张牌的容器（居中）
	var card_box := HBoxContainer.new()
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.anchor_left = 0.05
	card_box.anchor_right = 0.95
	card_box.anchor_top = 0.5
	card_box.anchor_bottom = 0.6
	card_box.offset_top = -40
	card_box.offset_bottom = 40
	card_box.add_theme_constant_override("separation", 60)
	_choice_overlay.add_child(card_box)

	# 清除旧按钮引用
	_choice_card_buttons.clear()

	# 创建两张牌的按钮
	for i in range(mini(cards.size(), 2)):
		var card: Deck.Card = cards[i] as Deck.Card
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 100)
		btn.text = "%s  %s" % [card.display_name(), CardData.suit_to_symbol(card.suit)]
		btn.tooltip_text = "点数: %d" % HandEvaluator.evaluate([card]).best_value
		btn.add_theme_font_size_override("font_size", 18)

		# 根据牌色着色
		if card.suit == CardData.Suit.HEARTS or card.suit == CardData.Suit.DIAMONDS:
			btn.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
		else:
			btn.add_theme_color_override("font_color", Color(0.25, 0.25, 0.95))

		var card_idx := i  # 闭包捕获
		btn.pressed.connect(_on_card_chosen.bind(card))
		card_box.add_child(btn)
		_choice_card_buttons.append(btn)

	add_child(_choice_overlay)

## 玩家选择了某张牌
func _on_card_chosen(chosen: Deck.Card) -> void:
	# 隐藏选择弹窗
	if _choice_overlay != null:
		_choice_overlay.hide()

	# 将选中的牌加入手牌
	_battle.confirm_choice_card(chosen)

	# 刷新UI
	_refresh_status()
	_update_predict_damage()

	# 如果还在玩家回合，重新显示操作按钮
	if _battle.phase == BattleManager.Phase.PLAYER_TURN:
		_show_player_actions()

## 请求换牌：auto_pick_worst=true自动换掉点数最高的牌；否则弹出手牌选择
func _request_swap_card(auto_pick_worst: bool, source: String) -> void:
	if _battle == null or _battle.phase != BattleManager.Phase.PLAYER_TURN:
		return
	if auto_pick_worst:
		var worst_idx := _find_highest_card_index()
		if worst_idx >= 0:
			_battle.redraw_player_card(worst_idx)
			EventBus.battle_log.emit("%s：自动换掉点数最高的手牌" % source)
		_refresh_after_swap()
	else:
		_show_swap_choice()

## 找到手牌中点数最高的牌下标
func _find_highest_card_index() -> int:
	var best_idx := -1
	var best_pts := -1
	for i in range(_battle.player_cards.size()):
		var single: Array[Deck.Card] = [_battle.player_cards[i]]
		var pts := HandEvaluator.evaluate(single).best_value
		if pts > best_pts:
			best_pts = pts
			best_idx = i
	return best_idx

## 显示换牌选择面板（点击手牌替换）
func _show_swap_choice() -> void:
	_hide_actions()
	if _swap_overlay == null:
		_swap_overlay = Control.new()
		_swap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		var bg := ColorRect.new()
		bg.color = Color(0.0, 0.0, 0.0, 0.78)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_swap_overlay.add_child(bg)
		var title := Label.new()
		title.text = "选择要替换的手牌"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		title.position = Vector2(0, get_window().size.y / 2 - 110)
		_swap_overlay.add_child(title)
		var card_box := HBoxContainer.new()
		card_box.name = "CardBox"
		card_box.alignment = BoxContainer.ALIGNMENT_CENTER
		card_box.position = Vector2(0, get_window().size.y / 2 - 60)
		card_box.size = Vector2(get_window().size.x, 90)
		card_box.add_theme_constant_override("separation", 30)
		_swap_overlay.add_child(card_box)
		var cancel := Button.new()
		cancel.text = "取消"
		cancel.custom_minimum_size = Vector2(100, 36)
		cancel.position = Vector2(get_window().size.x / 2 - 50, get_window().size.y / 2 + 50)
		cancel.pressed.connect(_on_swap_cancel)
		_swap_overlay.add_child(cancel)
		add_child(_swap_overlay)
	_swap_overlay.show()

	# 重建手牌按钮
	for btn in _swap_card_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_swap_card_buttons.clear()
	var box := _swap_overlay.get_node("CardBox") as HBoxContainer
	for i in range(_battle.player_cards.size()):
		var card: Deck.Card = _battle.player_cards[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 80)
		btn.text = card.display_name()
		btn.tooltip_text = "%s\n点数: %d" % [card.display_name(), HandEvaluator.evaluate([card]).best_value]
		btn.add_theme_font_size_override("font_size", 16)
		if card.suit == CardData.Suit.HEARTS or card.suit == CardData.Suit.DIAMONDS:
			btn.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
		else:
			btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.95))
		btn.pressed.connect(_on_swap_card_chosen.bind(i))
		box.add_child(btn)
		_swap_card_buttons.append(btn)

func _on_swap_card_chosen(index: int) -> void:
	if _swap_overlay != null:
		_swap_overlay.hide()
	if _battle != null:
		_battle.redraw_player_card(index)
	_refresh_after_swap()

func _on_swap_cancel() -> void:
	if _swap_overlay != null:
		_swap_overlay.hide()
	if _battle != null and _battle.phase == BattleManager.Phase.PLAYER_TURN:
		_show_player_actions()

## 换牌后统一刷新UI
func _refresh_after_swap() -> void:
	if _battle == null:
		return
	_refresh_status()
	_update_predict_damage()
	if _battle.phase == BattleManager.Phase.PLAYER_TURN:
		_show_player_actions()

func _on_hit_pressed() -> void:
	# 通关后 → 返回主菜单
	if _game_cleared:
		_return_to_main_menu()
		return
	# 战斗结束后也通过统一入口处理
	if _battle_over:
		_do_continue()
		return
	if _battle.phase != BattleManager.Phase.PLAYER_TURN:
		return

	# === 抽牌二选一 ===
	var two_cards: Array = _battle.draw_two_for_choice()
	if two_cards.size() >= 2:
		_show_card_choice(two_cards)
	elif two_cards.size() == 1:
		# 牌堆只剩1张，直接加入
		_battle.confirm_choice_card(two_cards[0] as Deck.Card)
		_refresh_status()
		if _battle.phase == BattleManager.Phase.PLAYER_TURN:
			_show_player_actions()
			_update_predict_damage()
	else:
		# 无法抽牌（牌堆空等），走原来的逻辑
		_battle.player_action(BattleManager.PlayerAction.HIT)
		_refresh_status()
		if _battle.phase == BattleManager.Phase.PLAYER_TURN:
			_show_player_actions()

func _on_stand_pressed() -> void:
	if _battle.phase != BattleManager.Phase.PLAYER_TURN:
		return
	_battle.player_action(BattleManager.PlayerAction.STAND)
	_hide_actions()
	_refresh_panel_enabled(false)

func _on_double_pressed() -> void:
	if _battle.phase != BattleManager.Phase.PLAYER_TURN:
		return
	var success: bool = _battle.player_action(BattleManager.PlayerAction.DOUBLE)
	if not success:
		return  # 加倍条件不满足（牌数不对等），不执行任何操作
	_hide_actions()
	_refresh_panel_enabled(false)
	log_label.text = "加倍！"

## 统一继续入口（按钮点击 / 屏幕点击 / 自动倒计时 都走这里）
func _do_continue() -> void:
	if _battle_over:
		_continue_adventure()
	elif _round_ended:
		_do_auto_next_round()

func _on_next_round_pressed() -> void:
	_do_continue()

## 继续冒险：Boss战回到地图推进层，普通战回到同层地图
func _continue_adventure() -> void:
	_is_auto_advancing = false
	_auto_advance_timer = 0.0

	if _game_cleared or _defeated:
		_return_to_main_menu()
		return

	if _battle_over:
		# === Boss战检测（双重保险）===
		var is_boss: bool = GameState.is_boss_battle
		# Fallback: 如果is_boss_battle被意外清掉，通过敌人Tier判断
		if not is_boss and _current_enemy != null:
			match _current_enemy.tier:
				EnemyData.Tier.FAIRY, EnemyData.Tier.CRYSTAL, \
				EnemyData.Tier.FLAME, EnemyData.Tier.SHADOW, \
				EnemyData.Tier.COURTYARD, EnemyData.Tier.THRONE:
					# 这些Tier本身不决定是否为Boss——但Boss的enemy_name包含"精灵/巨人/骑士/法师/队长/魔王"
					var boss_names := ["梅花精灵", "方块巨人", "红桃骑士", "黑桃法师", "近卫队长", "黑桃魔王"]
					for bn in boss_names:
						if _current_enemy.enemy_name.find(bn) >= 0:
							is_boss = true
							break

		if is_boss:
			# Boss战胜利 → 推进到下一层
			GameState.current_round += 1
			GameState.is_boss_battle = false
			print("【Boss击败】推进到第 %d 层" % (GameState.current_round + 1))
			if GameState.current_round >= 6:
				# 全部通关！
				_show_end_overlay("恭喜通关！\n征服了所有6层！", "返回主菜单", 999.0)
				_game_cleared = true
				return
			# 第5层Boss（近卫队长）：记录击败形态数
			if GameState.current_round == 5:  # 刚从第4层(暗影幻境)过来，current_round已+1=5
				# 注意：captain_forms_beaten在_on_battle_ended中已经+1了，这里不需要重复加
				pass
		# 回到地图（同层或下一层，由current_round决定）
		get_tree().change_scene_to_file("res://scenes/map/map_scene.tscn")
	elif _round_ended:
		_do_auto_next_round()

func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

## 小局结算后自动进入下一局
func _do_auto_next_round() -> void:
	_is_auto_advancing = false
	_auto_advance_timer = 0.0
	_round_ended = false
	result_label.text = ""
	_hide_actions()
	$BottomBar/TrumpPanel.show()
	if _item_panel != null:
		_item_panel.show()
	_selected_trump = null
	log_label.text = "选择本小局的姿态"
	_update_title_display()
	_show_stance_selection()

# ==================== 王牌/道具面板构建 ====================

func _build_trump_buttons() -> void:
	for b in _trump_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_trump_buttons.clear()

	for trump in GameState.current_trump_hand:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 34)

		# 攻击牌红色、防御牌蓝色、其他灰色
		match trump.category:
			TrumpCardData.Category.OPERATION:
				btn.text = "%s" % trump.card_name
				btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			TrumpCardData.Category.DEFENSE:
				btn.text = "%s" % trump.card_name
				btn.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
			_:
				btn.text = "%s" % trump.card_name

		btn.tooltip_text = "[%s] %s\n%s\n提示: %s" % [
			TrumpCardData.get_rarity_label(trump.rarity),
			trump.card_name,
			trump.description,
			trump.tip
		]
		btn.pressed.connect(_on_trump_panel_pressed.bind(trump))
		trump_cards_container.add_child(btn)
		_trump_buttons.append(btn)

func _on_trump_panel_pressed(trump: TrumpCardData) -> void:
	# 显示王牌信息
	var info := "[%s] %s - %s\n%s" % [
		TrumpCardData.get_rarity_label(trump.rarity),
		trump.card_name,
		trump.tip,
		trump.description
	]
	log_label.text = info

	# 如果有待安装的新王牌（从战利品获得），点击已装备的王牌可替换
	if _pending_trump_loot != null:
		_do_replace_trump(trump, _pending_trump_loot)

func _build_item_buttons() -> void:
	for b in _item_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_item_buttons.clear()

	for item in GameState.item_bag:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 34)
		btn.text = "%s[%s]" % [item.item_name, _rarity_label(item.rarity)]
		btn.tooltip_text = "%s\n%s" % [item.item_name, item.description]
		btn.pressed.connect(_on_item_pressed.bind(item))
		item_buttons_container.add_child(btn)
		_item_buttons.append(btn)

	# 空状态提示
	if GameState.item_bag.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（无道具）"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		item_buttons_container.add_child(empty_lbl)

## 创建血瓶按钮（战斗中可用）— 放在TrumpPanel内确保可见
func _create_flask_button() -> void:
	_flask_button = Button.new()
	_flask_button.custom_minimum_size = Vector2(120, 30)
	_flask_button.add_theme_font_size_override("font_size", 11)
	_flask_button.pressed.connect(_on_battle_flask_pressed)
	# 放到TrumpPanel里（不是ItemPanel——ItemPanel在130px高的BottomBar中被挤到底部不可见）
	$BottomBar/TrumpPanel.add_child(_flask_button)
	_update_flask_button()

func _update_flask_button() -> void:
	if _flask_button == null:
		return
	_flask_button.text = "🧪 血瓶 %d/%d" % [GameState.flask_current, GameState.flask_max]
	_flask_button.disabled = (GameState.flask_current <= 0) or (GameState.player_health >= GameState.player_max_health)

func _on_battle_flask_pressed() -> void:
	var msg: String = GameState.use_flask()
	log_label.text = msg
	_update_hp_display()
	_update_flask_button()
	EventBus.battle_log.emit(msg)

func _rarity_label(rarity: BattleItemData.Rarity) -> String:
	match rarity:
		BattleItemData.Rarity.COMMON: return "N"
		BattleItemData.Rarity.UNCOMMON: return "N+"
		BattleItemData.Rarity.RARE: return "R"
		BattleItemData.Rarity.EPIC: return "SR"
		BattleItemData.Rarity.LEGENDARY: return "SSR"
	return "?"

func _on_item_pressed(item: BattleItemData) -> void:
	if _battle == null or _battle.phase != BattleManager.Phase.PLAYER_TURN:
		log_label.text = "只能在拼点阶段使用道具"
		return
	if _battle.use_item(item):
		GameState.consume_item(item)
		_update_hp_display()
		_refresh_status()
		_build_item_buttons()
		EventBus.battle_log.emit("使用了道具: %s" % item.item_name)
		# 换牌类道具：触发换牌UI
		if item.effect_type == "redraw_card":
			_request_swap_card(false, item.item_name)
		elif item.effect_type == "redraw_card_auto":
			_request_swap_card(true, item.item_name)
	else:
		log_label.text = "本小局无法使用该道具"

# ==================== 技能系统 ====================

## 创建角色技能按钮（动态添加到底部区域）
func _create_skill_buttons() -> void:
	# 清理旧按钮
	if _skill1_button != null and is_instance_valid(_skill1_button):
		_skill1_button.queue_free()
	if _skill2_button != null and is_instance_valid(_skill2_button):
		_skill2_button.queue_free()

	if GameState.skill_executor == null:
		return

	var skill_container := $BottomBar/ActionRow
	if skill_container == null:
		return

	# 技能1按钮
	_skill1_button = Button.new()
	_skill1_button.custom_minimum_size = Vector2(100, 34)
	_skill1_button.text = "技能1"
	_skill1_button.visible = false
	_skill1_button.pressed.connect(_on_skill1_pressed)
	skill_container.add_child(_skill1_button)

	# 技能2按钮
	_skill2_button = Button.new()
	_skill2_button.custom_minimum_size = Vector2(100, 34)
	_skill2_button.text = "技能2"
	_skill2_button.visible = false
	_skill2_button.pressed.connect(_on_skill2_pressed)
	skill_container.add_child(_skill2_button)

## 更新技能按钮显示（在_show_player_actions中调用）
func _update_skill_buttons() -> void:
	if GameState.skill_executor == null or _skill1_button == null:
		return

	var se := GameState.skill_executor
	var char_data := GameState.selected_character

	# 更新技能1
	if char_data != null and char_data.skill1_name != "":
		_skill1_button.visible = true
		var cd1 := se.skill1_current_cooldown
		if cd1 > 0:
			_skill1_button.text = "%s (CD:%d)" % [char_data.skill1_name, cd1]
			_skill1_button.disabled = true
		else:
			_skill1_button.text = char_data.skill1_name
			_skill1_button.disabled = _battle.player_status.has_status(CombatStatus.StatusType.SILENCE)
		_skill1_button.tooltip_text = se.get_skill1_description()
	else:
		_skill1_button.visible = false

	# 更新技能2
	if char_data != null and char_data.skill2_name != "":
		_skill2_button.visible = true
		var cd2 := se.skill2_current_cooldown
		if cd2 > 0:
			_skill2_button.text = "%s (CD:%d)" % [char_data.skill2_name, cd2]
			_skill2_button.disabled = true
		else:
			_skill2_button.text = char_data.skill2_name
			_skill2_button.disabled = _battle.player_status.has_status(CombatStatus.StatusType.SILENCE)
		_skill2_button.tooltip_text = se.get_skill2_description()
	else:
		_skill2_button.visible = false

## 根据当前层加载主题背景图（全屏铺满，位于所有UI底层）
func _setup_background() -> void:
	var layer_idx: int = clampi(GameState.current_round, 0, LAYER_BACKGROOUNDS.size() - 1)
	var bg_path: String = LAYER_BACKGROOUNDS[layer_idx]

	# 先验证文件可加载
	if not ResourceLoader.exists(bg_path):
		push_warning("背景图未找到: %s" % bg_path)
		return

	var tex := load(bg_path) as Texture2D
	if tex == null:
		push_warning("背景图加载失败: %s" % bg_path)
		return

	print("✅ 加载背景图: %s (%d x %d)" % [bg_path, tex.get_width(), tex.get_height()])

	# 创建TextureRect（先配置好所有属性，再加入场景树）
	_background_tex = TextureRect.new()
	_background_tex.name = "BackgroundImage"
	_background_tex.texture = tex
	_background_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 关键：忽略纹理原始尺寸，完全由锚点布局控制全屏
	_background_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 等比缩放铺满（可能裁剪边缘）
	_background_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 锚点全屏（必须在add_child前设置，确保首次布局正确）
	_background_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_tex.set_offsets_preset(Control.PRESET_FULL_RECT)

	# 加入场景树并移到最底层
	add_child(_background_tex)
	move_child(_background_tex, 0)
	# 轻微降低背景亮度，保留色彩（避免纯白/亮色冲掉UI文字）
	_background_tex.self_modulate = Color(0.78, 0.78, 0.82)

	# 半透明暗色遮罩：提升UI文字对比度（位于背景之上、UI之下）
	var dim := ColorRect.new()
	dim.name = "BackgroundDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, 1)  # 紧跟背景图之后，所有UI之前

func _on_skill1_pressed() -> void:
	_use_active_skill(1)

func _on_skill2_pressed() -> void:
	_use_active_skill(2)

## 使用主动技能
func _use_active_skill(skill_num: int) -> void:
	if _battle == null or GameState.skill_executor == null:
		return
	if _battle.phase != BattleManager.Phase.PLAYER_TURN:
		log_label.text = "只能在拼点阶段使用技能"
		return

	var result: SkillResult = null
	match skill_num:
		1: result = GameState.skill_executor.use_skill1()
		2: result = GameState.skill_executor.use_skill2()

	if result == null:
		log_label.text = "技能冷却中！"
		return

	# 应用技能效果
	_apply_skill_effect_to_battle(result)
	log_label.text = result.description
	EventBus.battle_log.emit(result.description)
	_update_skill_buttons()

## 将SkillResult应用到战斗状态
func _apply_skill_effect_to_battle(result: SkillResult) -> void:
	match result.effect_type:
		"peek_enemy_card":
			# 查看敌方暗牌：亮出一张暗牌
			if _battle.dealer_cards.size() >= 2:
				for card in _battle.dealer_cards:
					if not card.face_up:
						card.face_up = true
						EventBus.hand_changed.emit(_battle.dealer_cards)
						break
		"fail_damage_reduce":
			# 失败减伤：添加到玩家状态
			_battle.player_status.add_status(CombatStatus.StatusType.FAIL_DAMAGE_REDUCE, result.effect_value, result.duration)
		"fireball_card":
			pass  # 小火球：通过被动系统处理
		"swap_deck_top":
			_request_swap_card(false, "火焰置换")
		"force_dealer_draw":
			_battle.enemy_status.add_status(CombatStatus.StatusType.FORCE_DRAW, result.effect_value, 1)
		"peek_deck_top":
			pass  # 通过draw_info传递
		"steal_dealer_card":
			if _battle.dealer_cards.size() > 0 and _battle.player_cards.size() > 0:
				var rng := RandomNumberGenerator.new()
				rng.randomize()
				var di := rng.randi_range(0, _battle.dealer_cards.size() - 1)
				var pi := rng.randi_range(0, _battle.player_cards.size() - 1)
				var tmp := _battle.player_cards[pi]
				_battle.player_cards[pi] = _battle.dealer_cards[di]
				_battle.dealer_cards[di] = tmp
				EventBus.hand_changed.emit(_battle.player_cards)
		"silence_enemy":
			_battle.enemy_status.add_status(CombatStatus.StatusType.SILENCED, 1.0, result.duration)
		"heal":
			GameState.player_heal(result.effect_value)
			_update_hp_display()
		"invincible":
			_battle.player_status.add_status(CombatStatus.StatusType.INVINCIBLE, 1.0, result.duration)
		"heal_on_win":
			_battle.player_status.add_status(CombatStatus.StatusType.HEAL_ON_WIN, result.effect_value, 99)
		_:
			pass

func _refresh_panel_enabled(enabled: bool) -> void:
	for b in _trump_buttons:
		b.disabled = not enabled
	for b in _item_buttons:
		b.disabled = not enabled

# ==================== 信号回调 ====================

func _on_health_changed(_target: String, _new_health: float, _max_health: float) -> void:
	_update_hp_display()
	_update_flask_button()
	_refresh_status()

func _on_hand_changed(_cards: Array) -> void:
	if _battle != null:
		player_hand_label.text = "你的手牌: " + _battle.get_player_hand_description()
		enemy_hand_label.text = "庄家手牌: " + _battle.get_dealer_hand_description()
	_update_predict_damage()

func _on_card_drawn(card_name: String, face_up: bool) -> void:
	var vis: String = "明牌" if face_up else "暗牌"
	log_label.text = "拼点: %s (%s)" % [card_name, vis]

func _on_round_result(result_text: String, damage: float) -> void:
	result_label.text = result_text
	log_label.text = "小局结束"
	_hide_actions()
	_round_ended = true
	$BottomBar/TrumpPanel.hide()
	if _item_panel != null:
		_item_panel.hide()
	_refresh_status()

	# 技能冷却递减
	if GameState.skill_executor != null:
		GameState.skill_executor.tick_cooldowns()

	if not _battle_over:
		# 小局结束 → 先播放攻击/受击动画，再弹出结算遮罩
		_play_round_end_animation(damage, result_text)

func _on_player_busted() -> void:
	log_label.text = "爆牌！超过21点了！"

func _on_battle_ended(victory: bool) -> void:
	_battle_over = true
	_round_ended = false
	_is_auto_advancing = false
	_auto_advance_timer = 0.0

	# 强制隐藏所有操作控件（防御性：确保无论之前状态如何都隐藏）
	_hide_actions()
	$BottomBar/TrumpPanel.hide()
	if _item_panel != null:
		_item_panel.hide()

	if victory:
		# === 胜利结算：经验 + 星尘 + 掉落 ===
		var char_type := CharacterData.ClassType.SWORDSMAN
		if GameState.selected_character != null:
			char_type = GameState.selected_character.class_type

		var exp_gained := _calculate_victory_reward()
		var dust_gained := maxi(10, GameState.current_round * 5 + 10)  # 胜利星尘更多
		var result := GameState.progression.add_exp(char_type, exp_gained)
		var levels_gained: int = result[0]
		var milestones: Array = result[1]
		GameState.progression.add_star_dust(dust_gained)

		result_label.text = "战斗胜利！击败了 %s！" % GameState.enemy_name
		log_label.text = "胜利！经验+%d 星尘+%d" % [exp_gained, dust_gained]

		var rng := RandomNumberGenerator.new()
		# === 道具掉落（70%概率）===
		if rng.randf() < 0.7:
			var loot: BattleItemData = GameState.loot_item(GameState.current_round)
			if loot != null:
				EventBus.battle_log.emit("战利品: [%s] %s" % [loot.item_name, loot.description])
				_build_item_buttons()
		# === 王牌掉落（50%概率）===
		if rng.randf() < 0.5:
			var new_trump: TrumpCardData = TrumpCardDatabase.get_random_card()
			if GameState.current_trump_hand.size() >= GameState.MAX_TRUMP_HAND:
				# 手牌满了，尝试放背包
				if GameState.add_trump_card(new_trump):
					EventBus.battle_log.emit("王牌获取(背包): [%s] %s" % [TrumpCardData.get_rarity_label(new_trump.rarity), new_trump.card_name])
				else:
					# 手牌+背包全满，提示替换
					_pending_trump_loot = new_trump
					EventBus.battle_log.emit("王牌获取(已满): [%s] %s - 点击已有王牌替换" % [TrumpCardData.get_rarity_label(new_trump.rarity), new_trump.card_name])
			elif GameState.add_trump_to_hand(new_trump):
				EventBus.battle_log.emit("王牌获取: [%s] %s" % [TrumpCardData.get_rarity_label(new_trump.rarity), new_trump.card_name])
				_build_trump_buttons()

		# 构建胜利弹窗文字（含升级信息）
		var overlay_text := "战斗胜利！\n击败了 %s\n\n经验: +%d\n星尘: +%d" % [GameState.enemy_name, exp_gained, dust_gained]
		# Boss关过时补充1瓶血瓶
		if GameState.current_round >= 5:
			GameState.refill_flask_on_boss()
			overlay_text += "\n🧪 击破Boss！血瓶+1（%d/%d）" % [GameState.flask_current, GameState.flask_max]
			# 第5层Boss（近卫队长）：记录击败形态数
			if GameState.current_round == 5:
				GameState.captain_forms_beaten += 1
				overlay_text += "\n⚔ 近卫队长形态 %d/3 已击破" % GameState.captain_forms_beaten
				if GameState.captain_forms_beaten >= 3:
					overlay_text += "\n★ 魔王之间已解锁！"
		if levels_gained > 0:
			overlay_text += "\n\n★ 升级! Lv.%d → Lv.%d ★" % [GameState.selected_char_level, GameState.selected_char_level + levels_gained]
			GameState.selected_char_level += levels_gained  # 同步等级
		for ms in milestones:
			overlay_text += "\n✦ %s" % str(ms)
		_show_end_overlay(overlay_text, "继续冒险", 4.0)
	else:
		# === 战败结算：经验 + 星尘（比胜利少）===
		_defeated = true
		var char_type_def := CharacterData.ClassType.SWORDSMAN
		if GameState.selected_character != null:
			char_type_def = GameState.selected_character.class_type

		var exp_gained_def := _calculate_defeat_reward()
		var dust_gained_def := maxi(4, GameState.current_round * 3 + 4)  # 战败星尘较少
		var result_def := GameState.progression.add_exp(char_type_def, exp_gained_def)
		var levels_def: int = result_def[0]
		var milestones_def: Array = result_def[1]
		GameState.progression.add_star_dust(dust_gained_def)

		result_label.text = "你被 %s 击败了..." % GameState.enemy_name

		var overlay_text_def := "战败...\n\n经验: +%d\n星尘: +%d\n到达第%d层" % [exp_gained_def, dust_gained_def, GameState.current_round + 1]
		if levels_def > 0:
			overlay_text_def += "\n\n★ 升级! Lv.%d → Lv.%d ★" % [GameState.selected_char_level, GameState.selected_char_level + levels_def]
			GameState.selected_char_level += levels_def
		for ms_def in milestones_def:
			overlay_text_def += "\n✦ %s" % str(ms_def)
		_show_end_overlay(overlay_text_def, "返回主菜单", 999.0)

func _on_round_started(_round_number: int) -> void:
	_update_title_display()
	_refresh_status()

func _on_battle_log(text: String) -> void:
	log_label.text = text

## 启动自动继续倒计时
func _start_auto_advance(delay: float) -> void:
	_is_auto_advancing = true
	_auto_advance_timer = delay

## 状态展示
func _refresh_status() -> void:
	if _battle == null or _battle.current_enemy_data == null:
		status_effect_label.text = "状态: 无"
		return
	var parts: Array[String] = ["你:"]
	for e in _battle.player_status.get_all():
		parts.append(CombatStatus.get_status_name(e.type))
	var player_status_str := "你:" + " ".join(parts) if parts.size() > 1 else "你:无"

	var enemy_parts: Array[String] = []
	for e in _battle.enemy_status.get_all():
		enemy_parts.append(CombatStatus.get_status_name(e.type))
	var enemy_status_str := ""
	if not enemy_parts.is_empty():
		enemy_status_str = "  |  %s:" % _battle.current_enemy_data.enemy_name + " ".join(enemy_parts)

	# 敌方姿态透视
	var peek_str := ""
	if _battle.can_peek_stance():
		peek_str = "  |  敌方姿态:%s" % StanceData.get_stance_name(_battle.dealer_stance)
		enemy_stance_label.text = "姿态: " + StanceData.get_stance_name(_battle.dealer_stance)

	# 显示当前王牌
	var trump_str := ""
	if _selected_trump != null:
		trump_str = "  |  王牌:[%s]" % _selected_trump.card_name

	status_effect_label.text = "状态: %s%s%s%s" % [player_status_str, enemy_status_str, peek_str, trump_str]

## 更新预计伤害显示（只显示攻击伤害，不显示受击）
func _update_predict_damage() -> void:
	if _battle == null or predict_label == null:
		return
	if _battle.phase != BattleManager.Phase.PLAYER_TURN:
		predict_label.text = ""
		return

	var pred := _battle.get_predicted_damage()
	if pred > 0.1:
		predict_label.text = "预计伤害: %.1f ▲" % pred
		predict_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		predict_label.text = "预计伤害: 0.0"
		predict_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

## 计算胜利经验奖励（基于层数+小局数+敌人难度）
func _calculate_victory_reward() -> int:
	var base_exp := 30  # 胜利基础经验比战败高
	var tier_bonus := (GameState.current_round + 1) * 8   # 每层+8
	var round_bonus := _sub_round_count * 3               # 每小局+3
	# 敌人难度加成
	var enemy_bonus := 0
	if _current_enemy != null:
		match _current_enemy.tier:
			EnemyData.Tier.CRYSTAL: enemy_bonus = 10
			EnemyData.Tier.FLAME: enemy_bonus = 20
			EnemyData.Tier.SHADOW: enemy_bonus = 35
			EnemyData.Tier.COURTYARD: enemy_bonus = 50
			EnemyData.Tier.THRONE: enemy_bonus = 80
	return base_exp + tier_bonus + round_bonus + enemy_bonus

## 计算战败经验奖励（基于到达层数+击败小局数，比胜利少）
func _calculate_defeat_reward() -> int:
	var base_exp := 10
	var tier_bonus := GameState.current_round * 5     # 每层+5
	var round_bonus := _sub_round_count * 2           # 每小局+2
	return base_exp + tier_bonus + round_bonus

## 替换王牌（旧→新）
func _do_replace_trump(old_trump: TrumpCardData, new_trump: TrumpCardData) -> void:
	if GameState.replace_trump_in_hand(old_trump, new_trump):
		EventBus.battle_log.emit("王牌替换: %s → %s" % [old_trump.card_name, new_trump.card_name])
		_pending_trump_loot = null
		_build_trump_buttons()
	else:
		log_label.text = "替换失败"
