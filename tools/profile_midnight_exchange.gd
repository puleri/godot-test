extends SceneTree
## Read-only scene audit and renderer benchmark. Never saves the loaded level.
## godot --path . --audio-driver Dummy --disable-vsync --script tools/profile_midnight_exchange.gd
## Optional user arguments: -- --inventory-only or --output=/tmp/custom.json

var level: Node3D
var report: Dictionary = {"samples": []}
var output := "/tmp/midnight-performance.json"
var inventory_only := false
var frames := 120
var resolution := Vector2i(1440, 900)
var brief := false
var audit_viewport: Viewport
var window_viewport := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--inventory-only":
			inventory_only = true
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--resolution="):
			var dimensions := argument.trim_prefix("--resolution=").split("x")
			resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
		elif argument == "--brief":
			brief = true
		elif argument == "--window-viewport":
			window_viewport = true
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 900)
	audit_viewport = root
	if not inventory_only and not window_viewport:
		var offscreen := SubViewport.new()
		offscreen.size = resolution
		offscreen.own_world_3d = true
		offscreen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(offscreen)
		audit_viewport = offscreen
		var preview := TextureRect.new()
		preview.texture = offscreen.get_texture()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = Vector2(1440, 900)
		root.add_child(preview)
	Engine.max_fps = 0
	level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.play_opening_dialogue = false
	audit_viewport.add_child(level)
	await level.ready_for_play
	print("AUDIT_READY")
	level.get_node("StormFlashLight").stop_flashing()
	level.set_process(false)
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	report["environment"] = {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"window_size": str(root.size),
		"lod_threshold": audit_viewport.mesh_lod_threshold,
		"occlusion_enabled": audit_viewport.use_occlusion_culling,
		"notes": "Editor binary; VSync disabled; storm stopped; no fixed FPS; frozen actor movement for camera comparisons. Animation trees remain active."
	}
	report["inventory"] = _inventory(level)
	report["branches"] = {}
	for child in level.get_children():
		if child is Node3D:
			report.branches[child.name] = _inventory(child)
	_save()
	if inventory_only:
		_save()
		quit()
		return
	# macOS can suppress automatic rendering for an obscured window while logic
	# continues. Explicit draws keep every counter sample tied to a rendered frame.
	RenderingServer.render_loop_enabled = false
	report.environment["manual_draw"] = true
	RenderingServer.viewport_set_measure_render_time(audit_viewport.get_viewport_rid(), true)
	# Allow initial pipelines and frame-rate monitors to settle before sampling.
	await _settle(180)
	for spec in [["entry", Vector3(0, 0.49, 14)], ["sorting", Vector3(-11, 0.49, 3)], ["crank", Vector3(11.5, 0.49, 3.5)], ["vault", Vector3(0, 0.49, -13)]]:
		_gameplay_camera(spec[1])
		await _sample("current_" + spec[0])
		if not brief:
			audit_viewport.mesh_lod_threshold = 0.0
			await _sample("current_" + spec[0] + "_lod_disabled")
			audit_viewport.mesh_lod_threshold = 1.0
	# Measure the real three-guard controller before adding population.
	_gameplay_camera(Vector3(0, 0.49, 14))
	for guard in level.guards:
		guard.set_physics_process(true)
	await _sample("current_entry_3_live_npcs")
	for guard in level.guards:
		guard.set_physics_process(false)
	var wide := Camera3D.new()
	wide.name = "AuditWideCamera"
	wide.fov = 64
	wide.far = 900
	level.add_child(wide)
	wide.position = Vector3(30, 11, 48)
	wide.look_at(Vector3(-5, 7, -65))
	wide.make_current()
	await _sample("current_opening_camera")
	if not brief:
		audit_viewport.mesh_lod_threshold = 0.0
		await _sample("current_opening_camera_lod_disabled")
		audit_viewport.mesh_lod_threshold = 1.0
	# Isolate the warehouse's object/surface count from the rest of the harbor.
	level.get_node("NorthQuayWarehouse").hide()
	await _sample("current_opening_without_warehouse")
	level.get_node("NorthQuayWarehouse").show()
	# Repeat collision and render geometry in ten adjacent courts: 10x area,
	# not 10x each linear dimension. Keep one backdrop and the existing lights.
	var expansion := Node3D.new()
	expansion.name = "AuditExpansion"
	level.add_child(expansion)
	var offsets: Array[Vector3] = []
	for row in 2:
		for column in 5:
			if row == 0 and column == 0:
				continue
			var offset := Vector3(column * 36, 0, -row * 38)
			offsets.append(offset)
			var court := Node3D.new()
			expansion.add_child(court)
			court.position = offset
			for source in level.region.get_children():
				court.add_child(source.duplicate())
			var warehouse := load("res://Modules/Buildings/StoneWarehouse.tscn").instantiate() as Node3D
			court.add_child(warehouse)
			warehouse.position = level.get_node("NorthQuayWarehouse").position
	report["expanded_inventory"] = _inventory(level)
	await _settle(180)
	_gameplay_camera(Vector3(0, 0.49, 14))
	await _sample("ten_courts_entry_3_npcs")
	wide.make_current()
	await _sample("ten_courts_opening_3_npcs")
	# Use fresh packed-scene guards (duplicating runtime animation trees is unsafe).
	var packed := load("res://Levels/MidnightExchange.tscn") as PackedScene
	for court_index in offsets.size():
		var template := packed.instantiate() as Node3D
		for original in template.get_node("Guards").get_children():
			var guard := original.duplicate() as CharacterBody3D
			guard.name = "AuditGuard_%d_%s" % [court_index, original.name]
			guard.route_path = NodePath("../../Routes/" + str(original.name))
			guard.player_path = NodePath("../../Player")
			guard.exposure_sensor_path = NodePath("../../Player/ExposureSensor")
			guard.position += offsets[court_index]
			level.get_node("Guards").add_child(guard)
			# Translate each cached route into a separate court.
			var route := Node3D.new()
			level.add_child(route)
			for point in guard._points:
				var marker := Marker3D.new()
				route.add_child(marker)
				marker.global_position = point.global_position + offsets[court_index]
			guard._points.clear()
			for point in route.get_children():
				guard._points.append(point)
			guard.navigation_ready = true
			guard.set_physics_process(false)
			guard.set_vision_visible(false)
			guard.set_suspicion_visible(false)
			guard._state_label.hide()
			level.guards.append(guard)
		template.free()
	level.exposure_sensor.refresh_lights()
	_gameplay_camera(Vector3(0, 0.49, 14))
	for guard in level.guards:
		guard.set_physics_process(true)
	await _sample("ten_courts_entry_30_live_npcs")
	wide.make_current()
	await _sample("ten_courts_opening_30_live_npcs")
	# Forty animated props, outside the tight camera but within the wide view.
	for i in 40:
		var bell := load("res://Mesh/Bell/bell.tscn").instantiate() as Node3D
		level.add_child(bell)
		bell.position = Vector3(20 + (i % 10) * 3, 0, -5 - (i / 10) * 4)
		bell.start_loop()
	_gameplay_camera(Vector3(0, 0.49, 14))
	await _sample("ten_courts_entry_30_npcs_40_animated_props")
	wide.make_current()
	await _sample("ten_courts_opening_30_npcs_40_animated_props")
	if not brief:
		# Test simplified static occluders made from solid wall/cover boxes.
		# Dynamic actors and animated props are deliberately excluded.
		for guard in level.guards:
			guard.set_physics_process(false)
		var occluders := Node3D.new()
		level.add_child(occluders)
		var occluder_count := 0
		for shape: CollisionShape3D in level.find_children("*", "CollisionShape3D", true, false):
			var path := str(shape.get_path())
			if not shape.shape is BoxShape3D or not ("/Walls/" in path or "/Cover/" in path or "/SolidExterior/" in path):
				continue
			var occluder := OccluderInstance3D.new()
			var box := BoxOccluder3D.new()
			box.size = shape.shape.size
			occluder.occluder = box
			occluders.add_child(occluder)
			occluder.global_transform = shape.global_transform
			occluder_count += 1
		report["experimental_occluder_count"] = occluder_count
		for spec in [["entry", Vector3(0, 0.49, 14)], ["vault", Vector3(0, 0.49, -13)], ["opening", Vector3.ZERO]]:
			if spec[0] == "opening":
				wide.make_current()
			else:
				_gameplay_camera(spec[1])
			audit_viewport.use_occlusion_culling = false
			await _sample("expanded_" + spec[0] + "_occlusion_off")
			audit_viewport.use_occlusion_culling = true
			await _sample("expanded_" + spec[0] + "_occlusion_on")
		audit_viewport.use_occlusion_culling = false
		# Isolate the warehouse to distinguish LOD changes from frustum changes.
		var asset := load("res://Modules/Buildings/StoneWarehouse.tscn").instantiate() as Node3D
		level.add_child(asset)
		asset.position = Vector3(1000, 0, 0)
		wide.make_current()
		for distance in [15, 50, 150]:
			wide.position = asset.position + Vector3(0, 3, distance)
			wide.look_at(asset.position + Vector3(0, 3, 0))
			for threshold in [1.0, 0.0]:
				audit_viewport.mesh_lod_threshold = threshold
				await _sample("warehouse_%dm_lod_%s" % [distance, threshold])
		audit_viewport.mesh_lod_threshold = 1.0
		asset.queue_free()
		await process_frame
		occluders.queue_free()
		await process_frame
	report["final_inventory"] = _inventory(level)
	_save()
	quit()


func _gameplay_camera(at: Vector3) -> void:
	level.player.position = at
	level.player._focus = Vector3(at.x, 0.3, at.z)
	level.player._update_phase_camera()
	level.get_node("LevelCamera").make_current()


func _sample(label: String) -> void:
	await _settle(45)
	var values: Dictionary = {}
	var last := Time.get_ticks_usec()
	var started := last
	for frame in frames:
		await process_frame
		RenderingServer.force_draw(false)
		var now := Time.get_ticks_usec()
		var metrics := {
			"frame_ms": (now - last) / 1000.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(audit_viewport.get_viewport_rid()),
			"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(audit_viewport.get_viewport_rid()),
			"draw_calls_total": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"draw_calls_visible": audit_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"draw_calls_shadow": audit_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"draw_calls_canvas": audit_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives_visible": audit_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
			"objects_visible": audit_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
			"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576,
			"video_memory_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576
		}
		last = now
		for key in metrics:
			if not values.has(key):
				values[key] = []
			values[key].append(metrics[key])
		if now - started > 8000000:
			break
	var result := {"label": label, "frames": values.frame_ms.size(), "render_size": str(audit_viewport.get_texture().get_size()), "lod_threshold": audit_viewport.mesh_lod_threshold, "camera": str(audit_viewport.get_camera_3d().name)}
	for key in values:
		var data: Array = values[key]
		data.sort()
		var total := 0.0
		for value in data:
			total += float(value)
		result[key] = {"mean": total / data.size(), "p50": data[data.size() / 2], "p95": data[int(data.size() * 0.95)], "max": data.back()}
	report.samples.append(result)
	if RenderingServer.get_current_rendering_method() != "gl_compatibility" and label in ["current_entry", "ten_courts_opening_30_npcs_40_animated_props"]:
		audit_viewport.get_texture().get_image().save_png(output.trim_suffix(".json") + "-" + label + ".png")
	print("AUDIT_SAMPLE " + JSON.stringify(result))
	_save()


func _settle(count: int) -> void:
	var started := Time.get_ticks_usec()
	for frame in count:
		await process_frame
		RenderingServer.force_draw(false)
		if Time.get_ticks_usec() - started > 3000000:
			break


func _inventory(node: Node) -> Dictionary:
	var counts := {"nodes": 0, "mesh_instances": 0, "surfaces": 0, "base_triangles": 0, "lod_surfaces": 0, "multimesh_batches": 0, "multimesh_instances": 0, "skeletons": 0, "bones": 0, "animation_players": 0, "animation_trees": 0, "lights": 0, "shadow_lights": 0, "occluders": 0, "visibility_ranges": 0, "collision_shapes": 0}
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	var groups: Dictionary = {}
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var item: Node = stack.pop_back()
		counts.nodes += 1
		stack.append_array(item.get_children())
		if item is MeshInstance3D and item.mesh:
			counts.mesh_instances += 1
			counts.surfaces += item.mesh.get_surface_count()
			meshes[item.mesh.get_instance_id()] = true
			for surface in item.mesh.get_surface_count():
				var material: Material = item.get_active_material(surface)
				if material:
					materials[material.get_instance_id()] = true
				var key := str(item.mesh.get_instance_id()) + ":" + str(material.get_instance_id() if material else 0)
				groups[key] = int(groups.get(key, 0)) + 1
				if item.mesh is ArrayMesh:
					counts.base_triangles += maxi(item.mesh.surface_get_array_index_len(surface), item.mesh.surface_get_array_len(surface)) / 3
					var surface_data := RenderingServer.mesh_get_surface(item.mesh.get_rid(), surface)
					if not surface_data.get("lods", {}).is_empty():
						counts.lod_surfaces += 1
		elif item is MultiMeshInstance3D and item.multimesh:
			counts.multimesh_batches += 1
			counts.multimesh_instances += item.multimesh.instance_count
		if item is GeometryInstance3D and (item.visibility_range_begin > 0 or item.visibility_range_end > 0):
			counts.visibility_ranges += 1
		if item is Skeleton3D:
			counts.skeletons += 1
			counts.bones += item.get_bone_count()
		if item is AnimationPlayer:
			counts.animation_players += 1
		if item is AnimationTree:
			counts.animation_trees += 1
		if item is Light3D:
			counts.lights += 1
			if item.shadow_enabled:
				counts.shadow_lights += 1
		if item is OccluderInstance3D:
			counts.occluders += 1
		if item is CollisionShape3D:
			counts.collision_shapes += 1
	counts["unique_mesh_resources"] = meshes.size()
	counts["unique_material_resources"] = materials.size()
	counts["mesh_material_groups"] = groups.size()
	return counts


func _save() -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("AUDIT_REPORT " + output)
