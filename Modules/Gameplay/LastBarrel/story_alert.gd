extends Node3D
## Alert artwork for scripted observers that do not use StealthGuard.

var _icon: Sprite3D
var _remaining := 0.0


func _ready() -> void:
	_icon = Sprite3D.new()
	_icon.name = "AlertIcon"
	_icon.texture = preload("res://textures/Exclamation.png")
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.pixel_size = 0.0018
	_icon.position.y = 1.75
	_icon.visible = false
	add_child(_icon)


func update_awareness(value: float) -> void:
	if value > 0.01:
		_remaining = 0.28
	_icon.visible = _remaining > 0.0
	_icon.modulate = Color("ff7468") if value >= 0.95 else Color("ffca76")


func confirm() -> void:
	_remaining = 2.0
	_icon.visible = true
	_icon.modulate = Color("ff7468")


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining == 0.0:
		_icon.visible = false
