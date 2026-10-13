@tool
extends Node3D

const STYLIZED_SHADER := preload("res://Materials/stylized.gdshader")

const PALETTE := {
	"Wall_Charcoal": Color(0.07, 0.055, 0.055, 1.0),
	"Wall_Warm_Patch": Color(0.14, 0.105, 0.085, 1.0),
	"Stone_Warm_Grey": Color(0.24, 0.20, 0.16, 1.0),
	"Stone_Highlight": Color(0.36, 0.29, 0.225, 1.0),
	"Wood_Dark": Color(0.115, 0.052, 0.02, 1.0),
	"Wood_Warm": Color(0.24, 0.105, 0.035, 1.0),
	"Roof_Black_Brown": Color(0.025, 0.018, 0.026, 1.0),
	"Window_Deep_Blue": Color(0.01, 0.022, 0.04, 1.0),
	"Sign_Blank": Color(0.17, 0.075, 0.12, 1.0),
	"Sign_Edge": Color(0.035, 0.018, 0.024, 1.0),
	"Brass": Color(0.34, 0.17, 0.025, 1.0),
	"Candle_Wax": Color(0.58, 0.39, 0.14, 1.0),
	"Candle_Flame": Color(1.0, 0.22, 0.018, 1.0),
}

var _materials_by_name: Dictionary = {}


func _ready() -> void:
	_apply_game_materials(self)


func _apply_game_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		# PreviewGround is useful in the Blender file, but is not part of the
		# in-game storefront.
		if mesh_instance.name.to_lower().contains("previewground"):
			mesh_instance.visible = false

		# Keep the storefront on visual layer 2. The window spotlights only
		# affect layer 1, so their light reaches the level floor without washing
		# across the facade.
		mesh_instance.layers = 2
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.mesh.surface_get_material(surface_index)
				if source == null or not PALETTE.has(source.resource_name):
					continue
				var game_material := _get_game_material(source.resource_name)
				mesh_instance.set_surface_override_material(surface_index, game_material)

	for child in node.get_children():
		_apply_game_materials(child)


func _get_game_material(material_name: String) -> Material:
	if _materials_by_name.has(material_name):
		return _materials_by_name[material_name] as Material

	if material_name == "Candle_Flame":
		var flame_material := StandardMaterial3D.new()
		flame_material.resource_name = material_name + "_Game"
		flame_material.albedo_color = PALETTE[material_name]
		flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame_material.emission_enabled = true
		flame_material.emission = Color(1.0, 0.08, 0.005, 1.0)
		flame_material.emission_energy_multiplier = 1.5
		_materials_by_name[material_name] = flame_material
		return flame_material

	if material_name == "Window_Deep_Blue":
		var window_material := StandardMaterial3D.new()
		window_material.resource_name = material_name + "_Game"
		window_material.albedo_color = Color(0.5, 0.16, 0.025, 1.0)
		window_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		window_material.emission_enabled = true
		window_material.emission = Color(1.0, 0.5, 0.1, 1.0)
		window_material.emission_energy_multiplier = 2.0
		_materials_by_name[material_name] = window_material
		return window_material

	var game_material := ShaderMaterial.new()
	game_material.resource_name = material_name + "_Game"
	game_material.shader = STYLIZED_SHADER
	game_material.set_shader_parameter("albedo_color", PALETTE[material_name])
	game_material.set_shader_parameter("albedo_affect", 0.55)
	game_material.set_shader_parameter("use_stepped", true)
	game_material.set_shader_parameter("steps", 2.0)
	game_material.set_shader_parameter("step_smoothness", 0.0)
	game_material.set_shader_parameter("shadow_tint", Color(0.008, 0.006, 0.01, 1.0))
	game_material.set_shader_parameter("shadow_tint_amount", 0.4)
	game_material.set_shader_parameter("specular", 0.0)
	game_material.set_shader_parameter("normal_strength", 0.0)
	game_material.set_shader_parameter("use_rim", true)
	game_material.set_shader_parameter("rim_color", Color(0.72, 0.68, 0.78, 1.0))
	game_material.set_shader_parameter("rim_amount", 2.0)
	game_material.set_shader_parameter("rim_smoothness", 0.2)
	game_material.set_shader_parameter("rim_mask_shadow", 0.0)
	game_material.set_shader_parameter("rim_blend", 0.3)
	game_material.set_shader_parameter("use_pattern", false)

	_materials_by_name[material_name] = game_material
	return game_material
