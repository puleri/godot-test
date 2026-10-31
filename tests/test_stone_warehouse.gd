extends SceneTree
## Exterior integrity and placement checks; the encounter test covers live routes.

var failures := 0

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var warehouse: Node3D = load("res://Modules/Buildings/StoneWarehouse.tscn").instantiate()
	root.add_child(warehouse)
	await physics_frame
	await physics_frame
	var meshes := warehouse.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 5, "441 editable pieces export as five section meshes")
	var bounds := AABB()
	var first := true
	var glowing_glass := false
	for mesh in meshes:
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			_check(material != null and material.resource_name.ends_with("_Game"), "Surface uses the warehouse game palette")
			if material is StandardMaterial3D and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				glowing_glass = true
	_check(bounds.size.x > 10 and bounds.size.x < 11 and bounds.end.y > 7.4, "Warehouse retains its full two-story silhouette and quay")
	_check(glowing_glass and warehouse.find_children("*", "Light3D", true, false).is_empty(), "Windows glow without adding stealth illumination")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0,2,9),Vector3(0,2,0),1)
	var hit := warehouse.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(not hit.is_empty() and hit.collider == warehouse.get_node("SolidExterior"), "Closed loading facade blocks physical sight rays")
	warehouse.queue_free()
	await process_frame
	var level: Node3D = load("res://Levels/MidnightExchange.tscn").instantiate()
	var placed: Node3D = level.get_node("NorthQuayWarehouse")
	_check(placed.scene_file_path == "res://Modules/Buildings/StoneWarehouse.tscn", "Saved level instances the reusable warehouse")
	_check(placed.position == Vector3(-7,0,-24), "Warehouse occupies the north quay")
	for collider in placed.find_children("*", "CollisionShape3D", true, false):
		var size: Vector3 = collider.shape.size
		var at: Vector3 = placed.position + collider.position
		_check(at.z + size.z/2 < -17.0, "Warehouse collision stays beyond every courtyard route")
	level.free()
	var builder = load("res://scripts/midnight_exchange_builder.gd").new()
	var regenerated: Node3D = builder.build_exchange()
	_check(regenerated.has_node("NorthQuayWarehouse") and regenerated.get_node("NorthQuayWarehouse").position == Vector3(-7,0,-24), "Level builder retains the warehouse on regeneration")
	regenerated.free()
	print("STONE WAREHOUSE: %d failures" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error(description)
