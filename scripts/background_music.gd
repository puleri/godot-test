extends AudioStreamPlayer

@export var music_bus_name: String = "Music"
@export var restart_delay: float = 0.0

func _ready() -> void:
	_ensure_music_bus()
	bus = music_bus_name

	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)

	if autoplay and not playing:
		play()

func _on_finished() -> void:
	if restart_delay > 0.0:
		await get_tree().create_timer(restart_delay).timeout

	if stream != null and is_inside_tree():
		play()

func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(music_bus_name) != -1:
		return

	AudioServer.add_bus(AudioServer.get_bus_count())
	AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, music_bus_name)
