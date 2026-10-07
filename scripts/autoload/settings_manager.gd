## 全局设置管理器（Autoload）
## 负责保存/读取亮度、音量等用户偏好设置。
extends Node

const SETTINGS_PATH: String = "user://settings.cfg"

signal settings_changed

var brightness: float = 1.0
var master_volume: float = 0.75

func _ready() -> void:
	_load_settings()
	_apply_volume()

## 加载设置文件；若不存在则使用默认值。
func _load_settings() -> void:
	var config := ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: 未能读取设置文件，使用默认值。错误码: %d" % err)
		return

	brightness = config.get_value("display", "brightness", 1.0) as float
	master_volume = config.get_value("audio", "master_volume", 0.75) as float

## 保存当前设置到文件。
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "brightness", brightness)
	config.set_value("audio", "master_volume", master_volume)
	var err: int = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("SettingsManager: 保存设置失败，错误码: %d" % err)

## 获取用于 CanvasModulate 或 modulation 的亮度颜色。
func get_brightness_color() -> Color:
	var v: float = clampf(brightness, 0.1, 1.5)
	return Color(v, v, v, 1.0)

## 设置亮度并立即生效。
func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.1, 1.5)
	save_settings()
	settings_changed.emit()

## 设置主音量并立即生效。
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	save_settings()
	_apply_volume()
	settings_changed.emit()

func _apply_volume() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))
