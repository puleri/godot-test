extends Node3D
var lamps: Array[OmniLight3D] = []
var elapsed := 0.0
func _ready() -> void:
	var positions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/HubCity/lights.json"))
	for p: Array in positions:
		var light := OmniLight3D.new()
		light.position = Vector3(p[0],p[1],p[2])
		light.light_color = Color(1.0,0.64,0.29)
		light.light_energy = 1.3
		light.omni_range = 9.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		lamps.append(light)
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.25:
		return
	elapsed = 0.0
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	for lamp in lamps:
		lamp.visible = lamp.global_position.distance_squared_to(camera.global_position) < 3600.0
