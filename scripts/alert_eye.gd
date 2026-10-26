extends Node2D

@onready 
var texture_progress_bar: TextureProgressBar = $TextureProgressBar
var tint_over = Color (.75,.73,.71,0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.




func _seenTimer():
	$TextureProgressBar.value += 1

func _persuit():
	var tint_over = Color (.75,.73,.71,0)
	var tween = create_tween()
	tween.tween_property($TextureProgressBar, "tint_over", Color (.75,.73,.71,1), .2)
