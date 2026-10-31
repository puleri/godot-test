@tool
extends Node3D
## Apply the project palette while keeping the wrapper a small GLB instance.

const PALETTE := {
	"Warehouse_Stone": Color(0.30, 0.34, 0.37),
	"Warehouse_stone_wall": Color(0.19, 0.23, 0.26),
	"Warehouse_wood": Color(0.19, 0.085, 0.035),
	"Warehouse_wall-loop": Color(0.035, 0.045, 0.055),
	"Warehouse_Material": Color(1.0, 0.62, 0.24),
	"Warehouse_Slate": Color(0.075, 0.12, 0.17),
	"Warehouse_SlateLight": Color(0.105, 0.16, 0.20),
	"Warehouse_Iron": Color(0.045, 0.06, 0.075),
	"Warehouse_Brass": Color(0.67, 0.40, 0.15),
	"Warehouse_Recess": Color(0.018, 0.025, 0.035),
}
var materials: Dictionary = {}
var exterior_shader: Shader


func _ready() -> void:
	# Native wall panels include intentionally two-sided faces. Keep that property
	# when adapting their glTF materials to the shared toon shader. A low surface
	# fill keeps the exterior readable at night without illuminating gameplay.
	exterior_shader = Shader.new()
	exterior_shader.code = preload("res://Materials/stylized.gdshader").code.replace(
		"shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;").replace(
		"ALBEDO = albedo.rgb;", "ALBEDO = albedo.rgb;\n\tEMISSION = ALBEDO * 0.10;")
	_apply_materials($Visual)


func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original: Material = node.mesh.surface_get_material(surface)
			assert(original and PALETTE.has(original.resource_name), "Unknown warehouse material")
			node.set_surface_override_material(surface, _material(original.resource_name))
	for child in node.get_children():
		_apply_materials(child)


func _material(key: String) -> Material:
	if materials.has(key):
		return materials[key]
	var tint: Color = PALETTE[key]
	var material: Material
	if key == "Warehouse_Material":
		var glass := StandardMaterial3D.new()
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.albedo_color = tint
		glass.emission_enabled = true
		glass.emission = tint
		glass.emission_energy_multiplier = 1.2
		material = glass
	else:
		var toon := ShaderMaterial.new()
		toon.shader = exterior_shader
		toon.set_shader_parameter("albedo_color", tint)
		toon.set_shader_parameter("albedo_affect", 0.55)
		toon.set_shader_parameter("use_stepped", true)
		toon.set_shader_parameter("steps", 2.0)
		toon.set_shader_parameter("shadow_tint", Color("10131c"))
		toon.set_shader_parameter("shadow_tint_amount", 0.35)
		toon.set_shader_parameter("specular", 0.0)
		toon.set_shader_parameter("use_rim", true)
		toon.set_shader_parameter("rim_color", Color("b8c1d1"))
		toon.set_shader_parameter("rim_amount", 1.5)
		toon.set_shader_parameter("rim_smoothness", 0.2)
		toon.set_shader_parameter("rim_mask_shadow", 0.0)
		toon.set_shader_parameter("rim_blend", 0.22)
		toon.set_shader_parameter("use_pattern", false)
		material = toon
	material.resource_name = key + "_Game"
	materials[key] = material
	return material


