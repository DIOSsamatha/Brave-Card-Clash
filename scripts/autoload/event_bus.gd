## 全局事件总线
## 用于解耦各系统之间的通信
extends Node

# ==================== 对战相关信号 ====================
signal battle_started(enemy_name: String)
signal battle_ended(victory: bool)
signal round_started(round_number: int)

## 手牌相关
signal card_drawn(card_display: String, face_up: bool)
signal hand_changed(cards: Array)  # Array[Deck.Card]
signal player_busted
signal player_blackjack

## 姿态相关
signal stance_selected(stance: int)  # StanceData.StanceType

## 伤害相关
signal damage_dealt(target: String, amount: float, is_critical: bool)
signal health_changed(target: String, new_health: float, max_health: float)
signal shield_changed(target: String, shield: float)
signal player_died
signal enemy_died

## 小局结果
signal round_result(result_text: String, damage: float)

## 战斗日志（机制/道具反馈）
signal battle_log(text: String)

# ==================== 冒险系统信号 ====================
signal map_node_entered(node_type: int, node_data: Variant)
signal map_node_cleared(node_id: int)
signal gold_changed(new_gold: int)
signal tier_advanced(new_tier: int)

# ==================== 王牌系统信号 ====================
signal trump_card_used(card_name: String)
signal trump_card_acquired(card_name: String)
signal trump_card_removed(card_name: String)
signal trump_hand_changed(hand: Array)

# ==================== 道具系统信号 ====================
signal item_used(item_name: String)
signal item_acquired(item_name: String)

# ==================== 角色成长信号 ====================
signal character_leveled(class_type: int, new_level: int)
signal star_dust_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: int, new_level: int)

# ==================== 冒险事件信号 ====================
signal shop_entered(items_for_sale: Array)
signal rest_entered(heal_amount: float)
signal event_triggered(event_id: String)
