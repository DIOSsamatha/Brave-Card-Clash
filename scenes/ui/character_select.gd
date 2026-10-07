## 角色选择界面
## 显示4名角色卡片（立绘+名称+简介），悬浮显示详细技能信息，点击选中后确认进入养成界面
extends Control

@onready var char_grid: GridContainer = $ScrollContainer/CenterContainer/CharGrid
@onready var confirm_btn: Button = $BottomBar/ButtonRow/ConfirmBtn
@onready var back_btn: Button = $BottomBar/ButtonRow/BackBtn
@onready var desc_label: RichTextLabel = $BottomBar/DescPanel/DescLabel
@onready var base_bg: ColorRect = $ColorRect

var _background_tex: TextureRect = null
const CHAR_SELECT_BG: String = "res://resources/backgrounds/character_select_bg.png"

var _character_resources: Array[String] = [
	"res://resources/characters/swordsman_rein.tres",
	"res://resources/characters/mage_lilia.tres",
	"res://resources/characters/thief_sid.tres",
	"res://resources/characters/priest_erin.tres",
]
var _selected_index: int = -1
var _char_cards: Array[Panel] = []

## 悬浮详情弹窗（全局唯一）
var _tooltip_panel: Panel = null
var _tooltip_label: RichTextLabel = null

func _ready() -> void:
	_setup_background()
	_setup_tooltip()
	_create_character_cards()
	confirm_btn.pressed.connect(_on_confirm)
	back_btn.pressed.connect(_on_back)
	confirm_btn.disabled = true

## 设置角色选择界面背景图（全屏铺满，位于所有UI底层）
func _setup_background() -> void:
	base_bg.color = Color(0.08, 0.06, 0.14, 1)

	if not ResourceLoader.exists(CHAR_SELECT_BG):
		push_warning("角色选择背景图未找到: " + CHAR_SELECT_BG)
		return
	var tex := load(CHAR_SELECT_BG) as Texture2D
	if tex == null:
		push_warning("角色选择背景图加载失败: " + CHAR_SELECT_BG)
		return

	_background_tex = TextureRect.new()
	_background_tex.set_meta("internal_name", "CharSelectBG")
	_background_tex.texture = tex
	_background_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background_tex)
	move_child(_background_tex, 1)

	var dim := ColorRect.new()
	dim.set_meta("internal_name", "DimOverlay")
	dim.color = Color(0.05, 0.05, 0.1, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, 2)

	print("✅ 角色选择背景图加载成功")

## 初始化悬浮详情弹窗（隐藏状态）
func _setup_tooltip() -> void:
	_tooltip_panel = Panel.new()
	_tooltip_panel.set_meta("internal_name", "HoverTooltip")
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 100

	# 用 Theme 资源设置样式（兼容所有 Godot 4.x 版本）
	var tooltip_theme := Theme.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.18, 0.95)
	style.border_color = Color(0.4, 0.35, 0.6, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	tooltip_theme.set_stylebox("panel", "Panel", style)
	_tooltip_panel.theme = tooltip_theme

	_tooltip_label = RichTextLabel.new()
	_tooltip_label.set_meta("internal_name", "TooltipContent")
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.custom_minimum_size = Vector2(280.0, 0.0)
	_tooltip_label.add_theme_font_size_override("normal_font_size", 13)
	_tooltip_panel.add_child(_tooltip_label)

	add_child(_tooltip_panel)

## 构建悬浮详情文本（BBCode富文本）
func _build_tooltip_text(char_data: CharacterData) -> String:
	var type_name: String = _get_type_name(char_data.class_type)

	var raw: String = (
		"[center][b]%s[/b]  [color=#88aaff]%s[/color]  HP:%d[/center]\n%s\n\n"
		+ "[color=#ffdd66][b]▎被动：%s[/b][/color]\n%s\n\n"
		+ "[color=#66ddbb][b]▎技能1：%s[/b][/color] (CD:%d)\n%s\n\n"
		+ "[color=#dd8866][b]▎技能2：%s[/b][/color] (CD:%d)\n%s"
	)
	return raw % [
		char_data.char_name,
		type_name,
		int(char_data.max_health),
		char_data.description,
		char_data.passive_name,
		char_data.passive_desc,
		char_data.skill1_name,
		char_data.skill1_cooldown,
		char_data.skill1_desc_lv1,
		char_data.skill2_name,
		char_data.skill2_cooldown,
		char_data.skill2_desc_lv1,
	]

## 显示悬浮详情弹窗
func _show_tooltip(char_data: CharacterData, card_pos: Vector2) -> void:
	if _tooltip_panel == null:
		return
	_tooltip_label.text = _build_tooltip_text(char_data)
	_tooltip_panel.visible = true
	_tooltip_panel.position = card_pos + Vector2(230.0, -20.0)
	if float(_tooltip_panel.position.x) + 300.0 > size.x:
		_tooltip_panel.position.x = card_pos.x - 310.0

## 隐藏悬浮详情弹窗
func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false

## 获取职业类型名称
func _get_type_name(class_type: CharacterData.ClassType) -> String:
	match class_type:
		CharacterData.ClassType.SWORDSMAN: return "平衡型"
		CharacterData.ClassType.MAGE: return "进攻型"
		CharacterData.ClassType.THIEF: return "技巧型"
		CharacterData.ClassType.PRIEST: return "防御型"
	return "未知"

func _create_character_cards() -> void:
	for i in range(_character_resources.size()):
		var res_path: String = _character_resources[i]
		var char_data: CharacterData = load(res_path) as CharacterData
		if char_data == null:
			continue

		var idx := i

		# ===== 卡片容器 =====
		var card := Panel.new()
		card.custom_minimum_size = Vector2(220.0, 380.0)

		# 用 Theme 资源设置卡片样式
		var card_theme := Theme.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.13, 0.11, 0.18, 0.92)
		card_style.border_color = Color(0.3, 0.28, 0.45, 0.6)
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(10)
		card_theme.set_stylebox("panel", "Panel", card_style)
		card.theme = card_theme

		var vbox := VBoxContainer.new()
		vbox.set_meta("internal_name", "VBox")
		vbox.anchors_preset = Control.PRESET_FULL_RECT
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		card.add_child(vbox)

		# ===== 立绘区域 =====
		var portrait_tex: Texture2D = null
		if char_data.portrait != "" and ResourceLoader.exists(char_data.portrait):
			portrait_tex = load(char_data.portrait) as Texture2D

		var portrait_rect := TextureRect.new()
		portrait_rect.set_meta("internal_name", "Portrait")
		portrait_rect.custom_minimum_size = Vector2(200.0, 240.0)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if portrait_tex != null:
			portrait_rect.texture = portrait_tex
		else:
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.2, 0.18, 0.28, 1.0)
			placeholder.custom_minimum_size = Vector2(200.0, 240.0)
			portrait_rect.add_child(placeholder)
		vbox.add_child(portrait_rect)

		# ===== 角色名称 =====
		var name_lbl := Label.new()
		name_lbl.text = char_data.char_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		vbox.add_child(name_lbl)

		# ===== 类型标签 + HP =====
		var info_hbox := HBoxContainer.new()
		info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var type_tag := Label.new()
		type_tag.text = "[%s]" % _get_type_name(char_data.class_type)
		type_tag.add_theme_font_size_override("font_size", 12)
		type_tag.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
		var hp_tag := Label.new()
		hp_tag.text = "HP:%d" % int(char_data.max_health)
		hp_tag.add_theme_font_size_override("font_size", 12)
		hp_tag.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		info_hbox.add_child(type_tag)
		info_hbox.add_child(hp_tag)
		vbox.add_child(info_hbox)

		# ===== 简介 =====
		var desc_lbl := Label.new()
		desc_lbl.text = char_data.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.82))
		desc_lbl.custom_minimum_size = Vector2(200.0, 0.0)
		vbox.add_child(desc_lbl)

		# ===== 事件连接 =====
		card.mouse_entered.connect(func(): _show_tooltip(char_data, card.global_position))
		card.mouse_exited.connect(_hide_tooltip)
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select_character(idx)
		)

		char_grid.add_child(card)
		_char_cards.append(card)

func _select_character(index: int) -> void:
	_selected_index = index
	_hide_tooltip()

	for i in range(_char_cards.size()):
		var card: Panel = _char_cards[i]
		var style: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		if i == index:
			style.bg_color = Color(0.18, 0.22, 0.35, 1)
			style.border_color = Color(0.5, 0.45, 0.75, 1)
		else:
			style.bg_color = Color(0.13, 0.11, 0.18, 0.92)
			style.border_color = Color(0.3, 0.28, 0.45, 0.6)

	var char_data: CharacterData = load(_character_resources[index]) as CharacterData
	desc_label.text = "[center][b]%s[/b] — %s\n\n%s[/center]" % [
		char_data.char_name,
		_get_type_name(char_data.class_type),
		char_data.description,
	]
	confirm_btn.disabled = false

func _on_confirm() -> void:
	if _selected_index < 0:
		return
	var char_data: CharacterData = load(_character_resources[_selected_index]) as CharacterData
	GameState.selected_character = char_data
	GameState.selected_char_level = 1
	GameState.reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/ui/character_cultivate.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
