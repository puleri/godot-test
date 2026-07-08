extends AudioStreamPlayer

@export var restart_delay: float = 0.0

func _ready() -> void:
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)

	if autoplay and not playing:
		play()

func _on_finished() -> void:
	if restart_delay > 0.0:
		await get_tree().create_timer(restart_delay).timeout

	if stream != null and is_inside_tree():
		play()
