## 21点手牌评估器
## 计算手牌点数、判断黑杰克、爆牌等
class_name HandEvaluator
extends RefCounted

## 手牌评估结果
class HandResult:
	var total_min: int = 0      # 最小可能点数
	var total_max: int = 0      # 最大可能点数
	var best_value: int = 0     # 最佳点数（不超过21的最大值，或最小点数）
	var is_blackjack: bool = false
	var is_busted: bool = false
	var ace_count: int = 0      # 手中A的数量

	func _init(cards: Array[Deck.Card]) -> void:
		_evaluate(cards)

	## 计算手牌点数
	func _evaluate(cards: Array[Deck.Card]) -> void:
		var total := 0
		var aces := 0

		for card in cards:
			var pts := card.point_range()
			total += pts[0]  # 先全部按最小值计算
			if card.is_ace():
				aces += 1

		total_min = total
		ace_count = aces

		# A可以计为11（如果不会爆牌的话）
		total_max = total
		for i in range(aces):
			if total_max + 10 <= 21:
				total_max += 10

		# 选择最佳点数
		if total_max <= 21:
			best_value = total_max
		else:
			best_value = total_min

		# 判断黑杰克（A + 10点，且只有2张牌）
		is_blackjack = (
			cards.size() == 2
			and aces == 1
			and total_max == 21
		)

		# 判断爆牌
		is_busted = total_min > 21

## 评估一组手牌
static func evaluate(cards: Array[Deck.Card]) -> HandResult:
	return HandResult.new(cards)

## 检查是否为黑杰克
static func is_blackjack(cards: Array[Deck.Card]) -> bool:
	if cards.size() != 2:
		return false
	return evaluate(cards).is_blackjack

## 检查是否爆牌
static func is_busted(cards: Array[Deck.Card]) -> bool:
	return evaluate(cards).is_busted

## 获取最佳点数
static func best_value(cards: Array[Deck.Card]) -> int:
	return evaluate(cards).best_value
