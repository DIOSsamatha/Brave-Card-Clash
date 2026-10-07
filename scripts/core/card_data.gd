## 扑克牌核心数据定义
## 定义牌的花色、点数、以及完整的52张牌数据
class_name CardData
extends RefCounted

## 花色枚举
enum Suit {
	SPADES = 0,    # 黑桃 ♠
	HEARTS = 1,    # 红心 ♥
	DIAMONDS = 2,  # 方块 ♦
	CLUBS = 3,     # 梅花 ♣
}

## 牌面值枚举（用于显示）
enum Rank {
	TWO = 2,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	EIGHT = 8,
	NINE = 9,
	TEN = 10,
	JACK = 11,
	QUEEN = 12,
	KING = 13,
	ACE = 14,
}

## 返回花色的显示符号
static func suit_to_symbol(suit: Suit) -> String:
	match suit:
		Suit.SPADES:
			return "♠"
		Suit.HEARTS:
			return "♥"
		Suit.DIAMONDS:
			return "♦"
		Suit.CLUBS:
			return "♣"
	return "?"

## 返回牌面值的显示名称
static func rank_to_name(rank: Rank) -> String:
	match rank:
		Rank.ACE:
			return "A"
		Rank.JACK:
			return "J"
		Rank.QUEEN:
			return "Q"
		Rank.KING:
			return "K"
		_:
			return str(rank)

## 获取牌的点数（用于21点计算）
## 返回数组: [最小点数, 最大点数]（因为A可以是1或11）
static func get_rank_points(rank: Rank) -> Array[int]:
	match rank:
		Rank.ACE:
			return [1, 11]
		Rank.JACK, Rank.QUEEN, Rank.KING:
			return [10, 10]
		_:
			var val := rank as int
			return [val, val]

## 判断是否为花牌（J/Q/K）
static func is_face_card(rank: Rank) -> bool:
	return rank in [Rank.JACK, Rank.QUEEN, Rank.KING]

## 判断是否为A
static func is_ace(rank: Rank) -> bool:
	return rank == Rank.ACE

## 获取花色颜色（用于UI显示）
static func suit_color(suit: Suit) -> Color:
	match suit:
		Suit.SPADES:
			return Color.BLACK
		Suit.HEARTS:
			return Color.RED
		Suit.DIAMONDS:
			return Color.RED
		Suit.CLUBS:
			return Color.BLACK
	return Color.WHITE
