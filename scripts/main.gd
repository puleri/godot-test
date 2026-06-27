extends Control

@onready var hello_label: Label = $HelloLabel

func _ready() -> void:
	hello_label.text = "Hello, Towel!"
