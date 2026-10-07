## 游戏主菜单控制器
## 标题画面 → 开始冒险 / 继续冒险 / 设置 / 退出
extends Control

@onready var start_btn: Button = $ButtonContainer/StartBtn
@onready var continue_btn: Button = $ButtonContainer/ContinueBtn
@onready var settings_btn: Button = $ButtonContainer/SettingsBtn
@onready var quit_btn: Button = $ButtonContainer/QuitBtn
@onready var save_info_label: Label = $SaveInfoLabel

const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/settings_panel.tscn")

var _settings_manager: Node = null

## 防止连点设置按钮重复打开面板
var _settings_open: bool = false

func _ready() -> void:
	# 先确保按钮有透明样式且可点
	_setup_button_style(start_btn)
	_setup_button_style(continue_btn)
	_setup_button_style(settings_btn)
	_setup_button_style(quit_btn)

	start_btn.pressed.connect(_on_start_game)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	# 检查是否有存档，并更新存档信息标签
	if SaveSystem.has_save():
		_load_save_info()
	else:
		continue_btn.disabled = true
		save_info_label.text = ""

	# 应用亮度设置（动态获取 Autoload，未注册时不报错）
	_settings_manager = get_node_or_null("/root/SettingsManager")
	if _settings_manager != null:
		_apply_brightness()
		_settings_manager.settings_changed.connect(_apply_brightness)

## 让按钮完全透明，hover 时轻微高亮，保留点击区域
func _setup_button_style(btn: Button) -> void:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	hover.set_corner_radius_all(8)
	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = Color(0.0, 0.0, 0.0, 0.12)
	pressed.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)

## 读取存档信息并显示在继续按钮下方的标签中
func _load_save_info() -> void:
	var file := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.READ)
	if file == null:
		continue_btn.disabled = true
		save_info_label.text = "继续冒险（读取失败）"
		return
	var json_text := file.get_as_text()
	file = null
	var json := JSON.new()
	if json.parse(json_text) != OK:
		continue_btn.disabled = true
		save_info_label.text = "继续冒险（存档损坏）"
		return
	var data: Dictionary = json.data as Dictionary
	var char_path: String = data.get("character_path", "")
	var stardust: int = data.get("stardust", 0)

	# 解析角色名
	var char_name: String = "未知角色"
	if not char_path.is_empty():
		var char_res: CharacterData = load(char_path) as CharacterData
		if char_res != null:
			char_name = char_res.char_name

	continue_btn.disabled = false
	save_info_label.text = "继续冒险 — %s | ✦%d" % [char_name, stardust]

func _on_start_game() -> void:
	print("[MainMenu] 开始冒险被按下")
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_continue() -> void:
	print("[MainMenu] 继续冒险被按下")
	if SaveSystem.load_game():
		get_tree().change_scene_to_file("res://scenes/ui/character_cultivate.tscn")
	else:
		push_error("存档读取失败")

func _on_settings() -> void:
	print("[MainMenu] 设置被按下")
	if _settings_open:
		return

	var panel_scene: PackedScene = SETTINGS_PANEL_SCENE
	if panel_scene == null:
		push_error("主菜单：无法加载设置面板场景")
		return

	var panel: Control = panel_scene.instantiate() as Control
	if panel == null:
		push_error("主菜单：设置面板实例化失败")
		return

	_settings_open = true
	if panel.has_signal("closed"):
		panel.connect("closed", _on_settings_closed)
	add_child(panel)
	panel.z_index = 100
	panel.move_to_front()
	_set_menu_interactive(false)

func _on_settings_closed() -> void:
	_settings_open = false
	_set_menu_interactive(true)

func _set_menu_interactive(enabled: bool) -> void:
	start_btn.disabled = not enabled
	continue_btn.disabled = not enabled or not SaveSystem.has_save()
	settings_btn.disabled = not enabled
	quit_btn.disabled = not enabled

func _on_quit() -> void:
	# 退出前自动保存一次（防止意外关闭丢失进度）
	SaveSystem.save_game()
	if _settings_manager != null:
		_settings_manager.save_settings()
	get_tree().quit()

func _apply_brightness() -> void:
	if _settings_manager == null:
		return
	modulate = _settings_manager.get_brightness_color()
