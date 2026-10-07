## 存档/读档系统
## JSON文件存档，管理角色选择、等级、星尘、图鉴等全局进度
class_name SaveSystem
extends RefCounted

const SAVE_PATH := "user://save_data.json"
const MAX_SAVE_SLOTS := 3

## 存档数据结构
class SaveData:
	var slot: int = 0
	var character_path: String = ""
	var char_level: int = 1
	var char_exp: float = 0.0
	var stardust: int = 0
	var upgrades: Dictionary = {}  # upgrade_id → level
	var unlocked_trumps: Array[String] = []  # 王牌图鉴解锁列表
	var unlocked_items: Array[String] = []   # 道具图鉴解锁列表
	var total_runs: int = 0
	var best_stage: int = 0
	var timestamp: String = ""

	func to_dict() -> Dictionary:
		return {
			"slot": slot,
			"character_path": character_path,
			"char_level": char_level,
			"char_exp": char_exp,
			"stardust": stardust,
			"upgrades": upgrades.duplicate(),
			"unlocked_trumps": unlocked_trumps.duplicate(),
			"unlocked_items": unlocked_items.duplicate(),
			"total_runs": total_runs,
			"best_stage": best_stage,
			"timestamp": timestamp,
		}

	static func from_dict(data: Dictionary) -> SaveData:
		var sd := SaveData.new()
		sd.slot = data.get("slot", 0)
		sd.character_path = data.get("character_path", "")
		sd.char_level = data.get("char_level", 1)
		sd.char_exp = data.get("char_exp", 0.0)
		sd.stardust = data.get("stardust", 0)
		sd.upgrades = data.get("upgrades", {}).duplicate()
		var raw_trumps: Array = data.get("unlocked_trumps", [])
		sd.unlocked_trumps.assign(raw_trumps)
		var raw_items: Array = data.get("unlocked_items", [])
		sd.unlocked_items.assign(raw_items)
		sd.total_runs = data.get("total_runs", 0)
		sd.best_stage = data.get("best_stage", 0)
		sd.timestamp = data.get("timestamp", "")
		return sd

## 从当前 GameState 构建存档数据
static func _build_save_data() -> SaveData:
	var sd := SaveData.new()
	if GameState.selected_character != null:
		sd.character_path = GameState.selected_character.resource_path
	sd.char_level = GameState.selected_char_level
	sd.stardust = GameState.progression.star_dust
	sd.total_runs = GameState.progression.total_runs
	sd.best_stage = GameState.progression.best_stage

	# 序列化升级状态
	for key in GameState.progression.upgrades:
		var entry: ProgressionSystem.UpgradeEntry = GameState.progression.upgrades[key]
		sd.upgrades[key] = entry.current_level

	# 时间戳
	var dt := Time.get_datetime_dict_from_system(false)
	sd.timestamp = "%04d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	return sd

## 将存档数据恢复到 GameState
static func _apply_save_data(sd: SaveData) -> void:
	# 恢复角色
	if not sd.character_path.is_empty():
		var char_res: CharacterData = load(sd.character_path) as CharacterData
		if char_res != null:
			GameState.selected_character = char_res
	GameState.selected_char_level = sd.char_level
	GameState.progression.star_dust = sd.stardust
	GameState.progression.total_runs = sd.total_runs
	GameState.progression.best_stage = sd.best_stage

	# 恢复升级
	for key in sd.upgrades:
		if GameState.progression.upgrades.has(key):
			GameState.progression.upgrades[key].current_level = sd.upgrades[key]

## 保存游戏（覆盖槽位1）
static func save_game() -> bool:
	var sd := _build_save_data()
	var json := JSON.stringify(sd.to_dict(), "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: 无法写入存档文件")
		return false
	file.store_string(json)
	file.flush()
	file = null
	print("SaveSystem: 存档成功 - ", sd.timestamp)
	return true

## 读取游戏
static func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("SaveSystem: 存档文件不存在")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: 无法读取存档文件")
		return false
	var json_text := file.get_as_text()
	file = null
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		push_error("SaveSystem: 存档JSON解析失败: ", json.get_error_message())
		return false
	var sd := SaveData.from_dict(json.data as Dictionary)
	_apply_save_data(sd)
	print("SaveSystem: 读档成功 - ", sd.timestamp)
	return true

## 是否有存档
static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 删除存档
static func delete_save() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		return true
	return false
