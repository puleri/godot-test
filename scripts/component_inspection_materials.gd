@tool
extends Node3D
## Display-only palette on existing material slots. Never modifies source meshes.
const PALETTE := {
	"stone_wall": Color("647580"), "stone": Color("9da7ac"),
	"wood": Color("63503c"), "wall-loop": Color("303b43"),
	"second level ": Color("697883"), "material": Color("b4cbd0"),
}
static var _materials: Dictionary = {}

func _ready() -> void:
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.mesh.surface_get_material(surface)
			var key := original.resource_name.to_lower().get_slice(".",0) if original else "stone_wall"
			if not _materials.has(key):
				var material := StandardMaterial3D.new()
				material.resource_name = "Inspection_"+key
				material.albedo_color = PALETTE.get(key,Color("79868e"))
				material.roughness = 0.9
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				_materials[key] = material
			mesh.set_surface_override_material(surface,_materials[key])
