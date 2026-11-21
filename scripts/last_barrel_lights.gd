extends RefCounted


static func add_spot(parent: Node3D, title: String, at: Vector3, target: Vector3,
		color: Color, energy: float, reach: float, angle: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = title
	light.transform = Transform3D(Basis.looking_at(target - at, Vector3.BACK), at)
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = true
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = 0.55
	light.spot_angle_attenuation = 0.35
	parent.add_child(light)
	return light
