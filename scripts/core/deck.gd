## 标准52张扑克牌管理
## 管理洗牌、发牌、牌堆状态
class_name Deck
extends RefCounted

## 单张牌的数据结构
class Card:
	var suit: CardData.Suit
	var rank: CardData.Rank
	var face_up: bool = false

	func _init(p_suit: CardData.Suit, p_rank: CardData.Rank) -> void:
		suit = p_suit
		rank = p_rank

	## 显示名称（如 "A♠"）
	func display_name() -> String:
		return CardData.rank_to_name(rank) + CardData.suit_to_symbol(suit)

	## 获取点数范围
	func point_range() -> Array[int]:
		return CardData.get_rank_points(rank)

	## 是否是A
	func is_ace() -> bool:
		return CardData.is_ace(rank)

	func _to_string() -> String:
		return display_name()

# 牌堆数据
var _cards: Array[Card] = []
var _discard_pile: Array[Card] = []

## 初始化并创建52张牌
func initialize() -> void:
	_cards.clear()
	_discard_pile.clear()

	for suit in range(4):
		for rank in range(2, 15):
			var card := Card.new(suit as CardData.Suit, rank as CardData.Rank)
			_cards.append(card)

## 洗牌（Fisher-Yates）
func shuffle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(_cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := _cards[i]
		_cards[i] = _cards[j]
		_cards[j] = temp

## 发一张牌
## [param face_up] 是否明牌
## returns: Card 或 null（牌堆为空）
func draw_card(face_up: bool = true) -> Card:
	if _cards.is_empty():
		# 从弃牌堆回收并重新洗牌
		reshuffle_from_discard()
		if _cards.is_empty():
			return null

	var card: Card = _cards.pop_back()
	card.face_up = face_up
	return card

## 将牌放入弃牌堆
func discard_card(card: Card) -> void:
	card.face_up = true
	_discard_pile.append(card)

## 从弃牌堆回收并重新洗牌
func reshuffle_from_discard() -> void:
	_cards.append_array(_discard_pile)
	_discard_pile.clear()
	shuffle()

## 剩余牌数
func remaining() -> int:
	return _cards.size()

## 弃牌堆牌数
func discard_count() -> int:
	return _discard_pile.size()

## 重置牌堆（清空弃牌，重新创建并洗牌）
func reset() -> void:
	initialize()
	shuffle()
