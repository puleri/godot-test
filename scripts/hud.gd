extends CanvasLayer

@export var show_coin_counter := true

var coins_collected := 0

@onready var coin_count: Label = $Control/CoinIcon/CoinCount

func _ready() -> void:
	coin_count.get_parent().visible = show_coin_counter
	if not show_coin_counter:
		return
	_update_coin_count()
	for coin in get_tree().get_nodes_in_group("coins"):
		coin.coin_collected.connect(_on_coin_collected)

func _on_coin_collected() -> void:
	coins_collected += 1
	_update_coin_count()

func _update_coin_count() -> void:
	coin_count.text = "x %02d" % coins_collected
