extends Node3D

const CUTS := [
	[Vector2(-0.65, 0.24), Vector2(0.24, 0.34), Vector2(0.52, 0.25), Vector2(-0.38, 0.17)],
	[Vector2(-0.38, 0.03), Vector2(0.58, 0.12), Vector2(0.29, -0.02), Vector2(-0.30, -0.04)],
	[Vector2(-0.63, -0.17), Vector2(-0.08, -0.09), Vector2(-0.20, -0.22), Vector2(-0.54, -0.25)],
	[Vector2(-0.10, -0.34), Vector2(0.51, -0.22), Vector2(0.28, -0.34), Vector2(-0.04, -0.40)],
]

func _ready() -> void:
	# Marks are fixed to the level's paving and deck, and receive their lights.
	_stamp(Vector3(-5.85, 2.825, 28.9), 1.35)
	_stamp(Vector3(-4.0, 2.825, 29.5), 1.05)
	_stamp(Vector3(-7.5, 2.825, 28.5), 1.05)
	_stamp(Vector3(3.6, 0.06, -5.3), 1.0)
	_stamp(Vector3(2.85, 0.06, -22.8), 0.9)


func _stamp(at: Vector3, size: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for shape: Array in CUTS:
		for index in Geometry2D.triangulate_polygon(PackedVector2Array(shape)):
			var point: Vector2 = shape[index] * size
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(point.x, 0, point.y))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("302822")
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	var visual := MeshInstance3D.new()
	visual.mesh = surface.commit()
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
