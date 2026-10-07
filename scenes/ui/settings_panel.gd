## 设置面板控制器
## 提供亮度、音量调节，并将改动同步到 SettingsManager。
class_name SettingsPanel
extends Control

signal closed

@onready var brightness_slider: HSlider = $BrightnessSlider
@onready var volume_slider: HSlider = $VolumeSlider
@onready var back_btn: Button = $BackBtn

var _settings_manager: Node = null

func _ready() -> void:
	_setup_button_style(back_btn)

	_settings_manager = get_node_or_null("/root/SettingsManager")
	if _settings_manager != null:
		brightness_slider.value = _settings_manager.brightness
		volume_slider.value = _settings_manager.master_volume
		_settings_manager.settings_changed.connect(_on_settings_changed)

	brightness_slider.value_changed.connect(_on_brightness_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_btn.pressed.connect(_on_back_pressed)

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

func _on_brightness_changed(value: float) -> void:
	if _settings_manager == null:
		return
	_settings_manager.set_brightness(value)

func _on_volume_changed(value: float) -> void:
	if _settings_manager == null:
		return
	_settings_manager.set_master_volume(value)

func _on_settings_changed() -> void:
	# 防止外部修改时滑块显示不一致
	if _settings_manager == null:
		return
	brightness_slider.value = _settings_manager.brightness
	volume_slider.value = _settings_manager.master_volume

func _on_back_pressed() -> void:
	print("[SettingsPanel] 返回被按下")
	closed.emit()
	queue_free()
