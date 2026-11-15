extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1440,900)
	var scene = load("res://Levels/ComponentBuildingInspection.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for spec in [["front",0.72,0.37,68.0,Vector3(0,6,0)],["back",3.9,0.4,68.0,Vector3(0,6,0)],["join",0.42,0.15,15.0,Vector3(6.2,6.6,12)]]:
		scene.yaw = spec[1]
		scene.pitch = spec[2]
		scene.distance = spec[3]
		scene.focus = spec[4]
		scene._frame_camera()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/component-building-"+spec[0]+".png")
	scene.get_node("Building/UpperFloor").hide()
	scene.yaw = 0.72
	scene.pitch = 0.32
	scene.distance = 60
	scene.focus = Vector3(0,3,0)
	scene._frame_camera()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/component-building-ground-floor.png")
	scene.yaw = 3.9
	scene._frame_camera()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/component-building-ground-window.png")
	var building: Node3D = scene.get_node("Building")
	assert(building.find_children("*","MeshInstance3D",true,false).size() == 12)
	assert(building.get_node("GroundFloor").get_child_count() == 6)
	assert(building.get_node("UpperFloor").get_child_count() == 6)
	for floor_node in building.get_children():
		for component in floor_node.get_children():
			assert(component.scale.is_equal_approx(Vector3.ONE))
			assert(component.get_script() == null, "Inspection palette must not override authored materials")
			assert(component.scene_file_path.begins_with("res://Mesh/ComponentBuilding/"))
			for mesh in component.find_children("*","MeshInstance3D",true,false):
				assert(mesh.material_override == null)
				for surface in mesh.mesh.get_surface_count():
					assert(mesh.get_surface_override_material(surface) == null)
					var material: StandardMaterial3D = mesh.mesh.surface_get_material(surface)
					assert(material != null and material.albedo_texture != null, "Authored color bake missing")
	print("COMPONENT_BUILDING_PREVIEW_OK / 12 separate components; native scale retained; authored textures present; no palette overrides")
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
