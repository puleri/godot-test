extends CanvasLayer

var coins_collected := 0

@onready var coin_count: Label = $Control/CoinIcon/CoinCount

func _ready() -> void:
	_update_coin_count()
	for coin in get_tree().get_nodes_in_group("coins"):
		coin.coin_collected.connect(_on_coin_collected)

func _on_coin_collected() -> void:
	coins_collected += 1
	_update_coin_count()

func _update_coin_count() -> void:
	coin_count.text = "x %02d" % coins_collected
