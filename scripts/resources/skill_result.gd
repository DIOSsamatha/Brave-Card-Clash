## 技能效果结果
## 独立全局类，避免内部类类型注解问题
class_name SkillResult
extends RefCounted

var effect_type: String = ""  # 效果类型标识 (heal/shield/damage_buff/draw_info/...)
var effect_value: float = 0.0
var duration: int = 0         # 持续小局数（0=即时）
var description: String = ""
## 额外数据（如目标牌索引等）
var extra_data: Variant = null

func _init(p_type: String, p_value: float, p_dur: int = 0, p_desc: String = "", p_extra: Variant = null) -> void:
	effect_type = p_type
	effect_value = p_value
	duration = p_dur
	description = p_desc
	extra_data = p_extra
