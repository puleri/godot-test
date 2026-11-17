extends Node
## Brief surface-only highlight every five seconds; no gameplay illumination.
var subject: Node3D
var materials: Array[ShaderMaterial] = []
var elapsed := 0.0

func setup(target: Node3D) -> void:
	subject = target
	_install(target.get_node("Visual"))

func _install(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		var material := ShaderMaterial.new()
		material.shader = preload("res://Materials/interaction_shimmer.gdshader")
		var bounds: AABB = node.mesh.get_aabb()
		material.set_shader_parameter("bounds_min", bounds.position)
		material.set_shader_parameter("bounds_size", bounds.size)
		node.material_overlay = material
		materials.append(material)
	for child in node.get_children():
		_install(child)

func _process(delta: float) -> void:
	elapsed += delta
	var phase := fmod(elapsed, 5.0)
	var complete := bool(subject.get("completed")) if subject.get_script() == preload("res://scripts/exchange_station.gd") else false
	var sweep := lerpf(-0.15, 1.15, phase / 0.75) if phase < 0.75 and not complete else -1.0
	for material in materials:
		material.set_shader_parameter("sweep", sweep)
