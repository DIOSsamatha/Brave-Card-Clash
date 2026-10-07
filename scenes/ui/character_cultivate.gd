## 角色养成界面
## 显示角色信息/等级/技能 → 星尘升级面板 → 开始冒险按钮
## 星尘为全局共享资源，在顶部醒目展示
extends Control

@onready var char_name_label: Label = $LeftPanel/VBox/CharNameLabel
@onready var level_label: Label = $LeftPanel/VBox/LevelLabel
@onready var hp_label: Label = $LeftPanel/VBox/HpLabel
@onready var dmg_label: Label = $LeftPanel/VBox/DmgLabel
@onready var passive_label: RichTextLabel = $LeftPanel/VBox/PassiveLabel
@onready var skill1_panel: PanelContainer = $LeftPanel/VBox/Skill1Panel
@onready var skill2_panel: PanelContainer = $LeftPanel/VBox/Skill2Panel
## 顶部星尘栏（全局共享资源）
@onready var stardust_label: Label = $TopBar/TopHBox/StardustLabel
@onready var upgrade_grid: GridContainer = $RightPanel/ScrollContainer/UpgradeGrid
@onready var start_btn: Button = $BottomBar/StartBtn
@onready var back_btn: Button = $BottomBar/BackBtn
@onready var log_label: Label = $RightPanel/LogLabel

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	start_btn.pressed.connect(_on_start_adventure)
	_refresh_character_info()
	_build_upgrade_buttons()

func _refresh_character_info() -> void:
	var char_data: CharacterData = GameState.selected_character
	if char_data == null:
		char_name_label.text = "未选择角色"
		return

	var lvl: int = GameState.selected_char_level
	char_name_label.text = char_data.char_name
	level_label.text = "Lv.%d / 30" % lvl
	hp_label.text = "生命值: %d" % int(char_data.get_total_health(lvl))
	dmg_label.text = "基础伤害: %.1f" % char_data.get_total_damage(lvl)

	passive_label.clear()
	passive_label.push_bold()
	passive_label.push_color(Color(0.7, 0.9, 1.0))
	passive_label.add_text("[被动] " + char_data.passive_name)
	passive_label.pop()
	passive_label.pop()
	passive_label.newline()
	passive_label.add_text(char_data.passive_desc)

	# 技能1
	var skill_lvl := CharacterData.level_to_skill_level(lvl)
	_update_skill_panel(skill1_panel, char_data.skill1_name, char_data.get_skill1_desc(skill_lvl), char_data.skill1_cooldown)
	# 技能2
	_update_skill_panel(skill2_panel, char_data.skill2_name, char_data.get_skill2_desc(skill_lvl), char_data.skill2_cooldown)

	# 更新星尘显示（金色醒目）
	stardust_label.text = "* 星尘: %d" % GameState.progression.star_dust

func _update_skill_panel(panel: PanelContainer, skill_name_str: String, desc: String, cd: int) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var vbox: VBoxContainer = panel.get_node_or_null("VBox")
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.layout_mode = 1
		panel.add_child(vbox)
		var title := Label.new()
		title.name = "Title"
		vbox.add_child(title)
		var d := Label.new()
		d.name = "Desc"
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(d)

	var title_lbl: Label = vbox.get_node_or_null("Title")
	var desc_lbl: Label = vbox.get_node_or_null("Desc")
	if title_lbl:
		title_lbl.text = "%s (CD:%d)" % [skill_name_str, cd]
	if desc_lbl:
		desc_lbl.text = desc

func _build_upgrade_buttons() -> void:
	# 清空旧按钮
	for child in upgrade_grid.get_children():
		child.queue_free()

	var upgrades: Dictionary = GameState.progression.upgrades
	for key in upgrades:
		var entry: ProgressionSystem.UpgradeEntry = upgrades[key]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(210.0, 65.0)

		# 根据是否可购买决定颜色
		var can_buy: bool = (entry.current_level < entry.max_level) and (GameState.progression.star_dust >= entry.cost_per_level[entry.current_level])
		var is_maxed: bool = entry.current_level >= entry.max_level

		var btn_style := StyleBoxFlat.new()
		if is_maxed:
			btn_style.bg_color = Color(0.15, 0.22, 0.15, 0.9)
			btn_style.border_color = Color(0.35, 0.55, 0.35, 0.7)
			btn.text = "%s\nLv.%d/%d ✓已满" % [entry.name, entry.current_level, entry.max_level]
		elif can_buy:
			btn_style.bg_color = Color(0.18, 0.15, 0.08, 0.92)
			btn_style.border_color = Color(0.75, 0.62, 0.22, 0.8)
			btn.text = "%s\nLv.%d/%d (%d✦)" % [entry.name, entry.current_level, entry.max_level, entry.cost_per_level[entry.current_level]]
		else:
			btn_style.bg_color = Color(0.15, 0.13, 0.16, 0.88)
			btn_style.border_color = Color(0.35, 0.32, 0.4, 0.5)
			btn.text = "%s\nLv.%d/%d (需%d✦)" % [entry.name, entry.current_level, entry.max_level, entry.cost_per_level[entry.current_level]]

		btn_style.set_corner_radius_all(6)
		btn_style.content_margin_left = 10
		btn_style.content_margin_right = 10
		btn_style.content_margin_top = 6
		btn_style.content_margin_bottom = 6
		var btn_theme := Theme.new()
		btn_theme.set_stylebox("normal", "Button", btn_style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = btn_style.bg_color.lightened(0.15)
		hover_style.border_color = btn_style.border_color.lightened(0.2)
		hover_style.set_corner_radius_all(6)
		hover_style.content_margin_left = 10
		hover_style.content_margin_right = 10
		hover_style.content_margin_top = 6
		hover_style.content_margin_bottom = 6
		btn_theme.set_stylebox("hover", "Button", hover_style)
		btn_theme.set_stylebox("pressed", "Button", btn_style)
		btn_theme.set_stylebox("focus", "Button", btn_style)
		btn.theme = btn_theme
		btn_theme.set_font_size("font_size", "Button", 14)

		btn.disabled = is_maxed or (not can_buy)
		var upgrade_id: ProgressionSystem.UpgradeID = key
		btn.pressed.connect(func(): _on_upgrade(upgrade_id))
		upgrade_grid.add_child(btn)

func _on_upgrade(upgrade_id: ProgressionSystem.UpgradeID) -> void:
	if GameState.progression.buy_upgrade(upgrade_id):
		log_label.text = "✦ 升级成功：%s" % str(upgrade_id)
		_refresh_character_info()
		_build_upgrade_buttons()

func _on_start_adventure() -> void:
	if GameState.selected_character == null:
		log_label.text = "请先选择角色！"
		return
	# 初始化冒险状态
	GameState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/map/map_scene.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
