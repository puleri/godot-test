class_name StealthExposureSensor
extends Node3D
## Shared, renderer-independent exposure at Rook's torso and head.
## Register real lights in stealth_lights. Decorative/emissive materials do not count.

@export var sample_offsets := PackedVector3Array([Vector3(0, 0.1, 0), Vector3(0, 0.55, 0)])
@export_flags_3d_physics var blocker_mask := 1
@export var hidden_threshold := 0.12
@export var exposed_threshold := 0.30
@export var directional_probe_distance := 80.0
var exposure := 0.0
var lightning_exposure := 0.0
var sample_exposures := PackedFloat32Array()
var _lights: Array[Light3D] = []


func _ready() -> void:
	process_physics_priority = -20
	refresh_lights()


func refresh_lights() -> void:
	_lights.clear()
	for node in get_tree().get_nodes_in_group("stealth_lights"):
		if node is Light3D and node.get_world_3d() == get_world_3d():
			_lights.append(node)


func _physics_process(_delta: float) -> void:
	refresh()


func sample_positions() -> PackedVector3Array:
	var points := PackedVector3Array()
	for offset in sample_offsets:
		points.append(global_position + offset)
	return points


func refresh() -> void:
	exposure = 0.0
	lightning_exposure = 0.0
	sample_exposures.clear()
	var points := sample_positions()
	for point in points:
		var illumination := 0.0
		var lightning := 0.0
		for light in _lights:
			if not is_instance_valid(light) or not light.is_visible_in_tree() or light.light_energy <= 0 or light.light_negative:
				continue
			var value := contribution(light, point)
			illumination += value
			if light is DirectionalLight3D:
				lightning += value
		var sample_value := clampf(illumination, 0, 1)
		sample_exposures.append(sample_value)
		exposure += sample_value
		lightning_exposure += clampf(lightning, 0, 1)
	if not points.is_empty():
		exposure /= points.size()
		lightning_exposure /= points.size()


func contribution(light: Light3D, point: Vector3) -> float:
	var source := light.global_position
	var strength := light.light_energy * float(light.get_meta("stealth_strength", 1.0))
	if light is DirectionalLight3D:
		source = point + light.global_basis.z.normalized() * directional_probe_distance
	elif light is OmniLight3D or light is SpotLight3D:
		var offset := point - source
		var distance := offset.length()
		var reach: float = light.spot_range if light is SpotLight3D else light.omni_range
		if distance >= reach or reach <= 0:
			return 0.0
		var attenuation: float = light.spot_attenuation if light is SpotLight3D else light.omni_attenuation
		strength *= pow(maxf(0, 1.0 - distance / reach), maxf(attenuation, 0))
		if light is SpotLight3D and distance > 0.001:
			var facing := -light.global_basis.z.normalized()
			var edge := cos(deg_to_rad(light.spot_angle))
			var alignment := facing.dot(offset / distance)
			if alignment <= edge:
				return 0.0
			var angular := clampf((alignment - edge) / maxf(0.001, 1.0 - edge), 0, 1)
			strength *= pow(angular, maxf(light.spot_angle_attenuation, 0.01))
	else:
		return 0.0
	if strength <= 0.001:
		return 0.0
	# The illumination ray is independent of every guard's sight ray.
	var query := PhysicsRayQueryParameters3D.create(point, source, blocker_mask)
	return strength if get_world_3d().direct_space_state.intersect_ray(query).is_empty() else 0.0


func exposure_name() -> String:
	if exposure <= hidden_threshold:
		return "HIDDEN"
	if exposure < exposed_threshold:
		return "DIM"
	return "EXPOSED"
