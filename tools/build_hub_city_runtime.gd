extends SceneTree
func _initialize() -> void:
	call_deferred("build")
func build() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file("res://art/HubCityGameExport/hub_city.glb", state)
	assert(err == OK)
	var city: Node3D = document.generate_scene(state)
	city.name = "HubCityGeometry"
	var nodes := city.find_children("*", "MeshInstance3D", true, false)
	var colliders := 0
	for node: MeshInstance3D in nodes:
		for surface in range(node.mesh.get_surface_count()):
			var mat = node.mesh.surface_get_material(surface)
			var colors = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			if mat is BaseMaterial3D and colors != null and colors.size() > 0:
				mat.vertex_color_use_as_albedo = true
		if node.name.begins_with("Solid") or node.name.begins_with("RampCollision"):
			var body := StaticBody3D.new()
			body.name = "StaticCollision"
			node.add_child(body)
			body.owner = city
			var collision := CollisionShape3D.new()
			collision.shape = node.mesh.create_trimesh_shape()
			body.add_child(collision)
			collision.owner = city
			colliders += 1
		if node.name.begins_with("Sailboat"):
			node.set_script(load("res://scripts/hub_foliage/lagoon_sailboat.gd"))
		if node.name.begins_with("RampCollision"):
			node.visible = false
	var packed := PackedScene.new()
	assert(packed.pack(city) == OK)
	assert(ResourceSaver.save(packed,"res://Assets/HubCity/HubCityGeometry.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	print("HUB_RUNTIME_BUILT meshes=",nodes.size()," colliders=",colliders)
	city.free()
	quit()
