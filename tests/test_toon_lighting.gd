extends SceneTree

## GPU regression: adding a light must not erase existing diffuse illumination.
## Run with a real renderer (not --headless), using --audio-driver Dummy if desired.
var _viewport: SubViewport
var _material: ShaderMaterial
var _lamp: SpotLight3D
var _failures := 0
var _checks := 0
var _capture_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shader := load("res://Materials/stylized.gdshader") as Shader
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shader-source="):
			shader.code = FileAccess.get_file_as_string(argument.trim_prefix("--shader-source="))
		elif argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	if not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)
	_build_fixture(shader)
	var cases := [
		{"name": "smooth_matte", "stepped": false, "specular": 0.0, "rim": false, "steps": 2.0},
		{"name": "hard_matte", "stepped": true, "specular": 0.0, "rim": false, "steps": 2.0},
		{"name": "smooth_shiny", "stepped": false, "specular": 1.0, "rim": false, "steps": 2.0},
		{"name": "hard_rim", "stepped": true, "specular": 0.0, "rim": true, "steps": 2.0},
		{"name": "zero_band_count", "stepped": true, "specular": 0.0, "rim": false, "steps": 0.0},
	]
	for test_case in cases:
		_material.set_shader_parameter("use_stepped", test_case.stepped)
		_material.set_shader_parameter("steps", test_case.steps)
		_material.set_shader_parameter("specular", test_case.specular)
		_material.set_shader_parameter("use_rim", test_case.rim)
		_lamp.visible = false
		var baseline := await _capture(test_case.name + "_baseline")
		_check(_lit_pixel_count(baseline) > 1000, test_case.name + ": fixture renders a lit floor")
		_lamp.visible = true
		for direction in [0.0, PI * 0.5, PI]:
			_lamp.rotation.y = direction
			var frame := await _capture(test_case.name + "_" + str(direction))
			var darkened := _darkened_pixel_count(baseline, frame)
			_check(darkened == 0, "%s: spotlight at %.2f does not erase existing light (%d bad pixels)" % [test_case.name, direction, darkened])
	print("TOON GPU CHECKS: %d passed, %d failed" % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _build_fixture(shader: Shader) -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 256)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var world := Node3D.new()
	_viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	world.add_child(environment)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(16.0, 0.2, 16.0)
	floor_mesh.mesh = box
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("albedo_color", Color(0.25, 0.32, 0.4))
	_material.set_shader_parameter("albedo_affect", 0.0)
	_material.set_shader_parameter("use_pattern", false)
	_material.set_shader_parameter("step_smoothness", 0.0)
	_material.set_shader_parameter("rim_smoothness", 0.0)
	_material.set_shader_parameter("shadow_tint", Color.BLACK)
	floor_mesh.material_override = _material
	world.add_child(floor_mesh)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-65.0, -20.0, 0.0)
	key.light_color = Color(0.56, 0.67, 1.0)
	key.light_energy = 0.65
	key.shadow_enabled = false
	world.add_child(key)
	_lamp = SpotLight3D.new()
	_lamp.position = Vector3(0.0, 0.75, 0.0)
	_lamp.light_energy = 8.0
	_lamp.spot_range = 7.0
	_lamp.spot_angle = 40.0
	_lamp.spot_attenuation = 0.0
	_lamp.spot_angle_attenuation = 0.35
	_lamp.shadow_enabled = false
	world.add_child(_lamp)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 12.0, 12.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.make_current()


func _capture(name: String) -> Image:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var frame := _viewport.get_texture().get_image()
	if not _capture_dir.is_empty():
		frame.save_png(_capture_dir.path_join(name + ".png"))
	return frame


func _brightness(color: Color) -> float:
	return color.r + color.g + color.b


func _lit_pixel_count(image: Image) -> int:
	var count := 0
	for y in range(8, 248, 2):
		for x in range(8, 248, 2):
			if _brightness(image.get_pixel(x, y)) > 0.05:
				count += 1
	return count


func _darkened_pixel_count(baseline: Image, frame: Image) -> int:
	var count := 0
	for y in range(8, 248, 2):
		for x in range(8, 248, 2):
			var before := _brightness(baseline.get_pixel(x, y))
			if before > 0.05 and _brightness(frame.get_pixel(x, y)) < before - 0.02:
				count += 1
	return count


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
