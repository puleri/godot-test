extends SceneTree
## GPU regression for the real mouse/hound lamp geometry on the stone floor.
## Requires a real renderer; run without --headless and optionally pass
## -- --capture-dir=/tmp/headlamp-readability to retain comparison images.

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _environment: Environment
var _material: ShaderMaterial
var _lamp: SpotLight3D
var _key: DirectionalLight3D
var _cover: MeshInstance3D
var _capture_dir := ""
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func(): push_error("Headlamp GPU checks timed out"); quit(1))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	if not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)
	RenderingServer.global_shader_parameter_set("comic_lighting", false)
	_build_fixture()
	var lamps := [
		{"name": "mouse", "height": 0.8, "range": 5.0, "half_angle": 16.0,
			"depths": [2.0, 2.5, 3.0, 3.5, 4.0, 4.5], "width": 0.25},
		{"name": "hound", "height": 1.3, "range": 7.0, "half_angle": 20.0,
			"depths": [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0], "width": 0.4},
	]
	for specification in lamps:
		await _test_lamp(specification)
	await _test_toon_bands()
	await _test_other_illumination()
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_key.visible = false
	_lamp.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	_lamp.shadow_enabled = true
	for specification in lamps:
		await _test_lamp(specification, true)
	await _test_single_band()
	print("HEADLAMP GPU CHECKS: %d passed, %d failed" % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(512, 512)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment_node := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color.BLACK
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment_node.environment = _environment
	_world.add_child(environment_node)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(20.0, 0.2, 20.0)
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.1
	_material = load("res://Materials/NewToon-Stone.tres").duplicate() as ShaderMaterial
	floor_mesh.material_override = _material
	_world.add_child(floor_mesh)
	_lamp = SpotLight3D.new()
	_lamp.rotation_degrees.x = -12.0
	_lamp.light_energy = 8.0
	_lamp.spot_attenuation = 0.0
	_lamp.spot_angle_attenuation = 0.35
	_lamp.shadow_enabled = true
	_lamp.shadow_bias = 0.03
	_lamp.shadow_normal_bias = 0.02
	_world.add_child(_lamp)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-65.0, -20.0, 0.0)
	_key.light_color = Color(0.56, 0.67, 1.0)
	_key.light_energy = 0.65
	_key.visible = false
	_world.add_child(_key)
	_cover = MeshInstance3D.new()
	var cover_box := BoxMesh.new()
	cover_box.size = Vector3(3.0, 2.0, 0.2)
	_cover.mesh = cover_box
	_cover.position = Vector3(0.0, 1.0, -2.0)
	_cover.visible = false
	_world.add_child(_cover)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 18.0
	_camera.position = Vector3(0.0, 12.0, 0.0)
	_world.add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	_camera.make_current()


func _test_lamp(specification: Dictionary, comic: bool = false) -> void:
	var name: String = specification.name + ("_comic" if comic else "")
	RenderingServer.global_shader_parameter_set("comic_lighting", false)
	_lamp.position = Vector3(0.0, specification.height, 0.0)
	_lamp.spot_range = specification.range
	_lamp.spot_angle = specification.half_angle
	_lamp.visible = true
	_material.set_shader_parameter("toon_local_lighting", false)
	var legacy := await _capture(name + "_legacy")
	RenderingServer.global_shader_parameter_set("comic_lighting", comic)
	_material.set_shader_parameter("toon_local_lighting", true)
	var readable := await _capture(name + "_readable")
	var weakest := 1.0
	var legacy_sum := 0.0
	var readable_sum := 0.0
	var samples := 0
	for depth in specification.depths:
		for side in [-1.0, 0.0, 1.0]:
			var point := Vector3(side * specification.width, 0.0, -depth)
			var brightness := _at(readable, point)
			weakest = minf(weakest, brightness)
			readable_sum += brightness
			legacy_sum += _at(legacy, point)
			samples += 1
	_check(weakest > 0.12,
		"%s: light keeps the cone connected and readable (weakest %.3f)" % [name, weakest])
	_check(readable_sum / samples > legacy_sum / samples + 0.12,
		"%s: actual lamp reveals grazing ground missing from legacy bands (%.3f vs %.3f)" % [name, readable_sum / samples, legacy_sum / samples])
	var outside := 0.0
	for point in [Vector3(-4.0, 0.0, -3.0), Vector3(4.0, 0.0, -3.0), Vector3(0.0, 0.0, 2.0), Vector3(0.0, 0.0, -8.5)]:
		outside = maxf(outside, _at(readable, point))
	_check(outside < 0.015,
		"%s: outside, behind and beyond the lamp remain dark (brightest %.3f)" % [name, outside])
	_cover.visible = true
	var blocked := await _capture(name + "_blocked")
	var shadow_peak := 0.0
	for depth in [3.5, 4.0, 4.5]:
		shadow_peak = maxf(shadow_peak, _at(blocked, Vector3(0.0, 0.0, -depth)))
	_check(shadow_peak < 0.03,
		"%s: solid cover still blocks the readable lamp cone (brightest shadow %.3f)" % [name, shadow_peak])
	_cover.visible = false


func _test_single_band() -> void:
	RenderingServer.global_shader_parameter_set("comic_lighting", true)
	_lamp.spot_range = 50.0
	_lamp.spot_angle = 60.0
	_lamp.shadow_enabled = false
	# Sweep across all four former lit tiers, both with and without the
	# encounter's readable-floor override. There must be just one lit value.
	for readable in [false, true]:
		_material.set_shader_parameter("toon_local_lighting", readable)
		var darkest := 1.0
		var brightest := 0.0
		for lambert in [0.025, 0.075, 0.13, 0.21, 0.3, 0.6, 0.85, 0.95]:
			_aim_for_lambert(lambert)
			var frame := await _capture("comic_spot_%s_%.3f" % [readable, lambert])
			var brightness := _at(frame, Vector3.ZERO)
			darkest = minf(darkest, brightness)
			brightest = maxf(brightest, brightness)
		_check(darkest > 0.12 and brightest - darkest < 0.008,
			"Comic spotlight has one lit tone across grazing and direct light, readable=%s (%.3f–%.3f)" % [readable, darkest, brightest])
	_aim_for_lambert(0.004)
	var below_edge := await _capture("comic_spot_below_edge")
	_check(_at(below_edge, Vector3.ZERO) < 0.015, "Comic spotlight keeps a hard dark cutoff")
	_lamp.visible = false
	var omni := OmniLight3D.new()
	omni.light_energy = 8.0
	omni.omni_range = 50.0
	omni.omni_attenuation = 0.0
	_world.add_child(omni)
	var darkest := 1.0
	var brightest := 0.0
	for lambert in [0.025, 0.13, 0.3, 0.6, 0.95]:
		omni.position = Vector3(0.0, 10.0 * lambert, 10.0 * sqrt(1.0 - lambert * lambert))
		var frame := await _capture("comic_omni_%.3f" % lambert)
		var brightness := _at(frame, Vector3.ZERO)
		darkest = minf(darkest, brightness)
		brightest = maxf(brightest, brightness)
	_check(darkest > 0.12 and brightest - darkest < 0.008,
		"Comic point lamps have one lit tone (%.3f–%.3f)" % [darkest, brightest])
	omni.queue_free()
	await process_frame
	_key.visible = true
	darkest = 1.0
	brightest = 0.0
	for lambert in [0.6, 0.75, 0.95]:
		_key.rotation.x = -asin(lambert)
		var frame := await _capture("comic_directional_%.3f" % lambert)
		var brightness := _at(frame, Vector3.ZERO)
		darkest = minf(darkest, brightness)
		brightest = maxf(brightest, brightness)
	_check(darkest > 0.05 and brightest - darkest < 0.008,
		"Comic directional lighting has one lit tone (%.3f–%.3f)" % [darkest, brightest])
	_key.rotation.x = -asin(0.4)
	var shadow := await _capture("comic_directional_shadow")
	_check(_at(shadow, Vector3.ZERO) < 0.015, "Comic directional lighting keeps its shadow side dark")
	_key.visible = false
	var unlit := await _capture("comic_unlit")
	_check(_at(unlit, Vector3.ZERO) < 0.015, "Comic mode adds no light to an unlit surface")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.4, 0.5, 0.7)
	_environment.ambient_light_energy = 0.3
	_environment.ambient_light_sky_contribution = 0.0
	var ambient := await _capture("comic_ambient")
	RenderingServer.global_shader_parameter_set("comic_lighting", false)
	var original := await _capture("original_ambient")
	_check(_at(ambient, Vector3.ZERO) > 0.05 and _difference(ambient, original) < 0.004,
		"Comic mode preserves the existing ambient base palette")


func _test_toon_bands() -> void:
	# Aim a distant spotlight directly at the same floor point while changing
	# its elevation. Center-cone attenuation stays fixed, so a smooth shader
	# would change continuously; a toon response must hold a flat value.
	_lamp.spot_range = 50.0
	_lamp.spot_angle = 60.0
	_lamp.shadow_enabled = false
	_material.set_shader_parameter("toon_local_lighting", true)
	var tier_brightness: Array[float] = []
	for tier in [
		{"name": "outer", "angles": [0.025, 0.05, 0.075]},
		{"name": "inner", "angles": [0.13, 0.17, 0.21]},
	]:
		var darkest := 1.0
		var brightest := 0.0
		for lambert in tier.angles:
			_aim_for_lambert(lambert)
			var frame := await _capture("toon_%s_%.3f" % [tier.name, lambert])
			var brightness := _at(frame, Vector3.ZERO)
			darkest = minf(darkest, brightness)
			brightest = maxf(brightest, brightness)
		_check(darkest > 0.12 and brightest - darkest < 0.008,
			"%s grazing tier stays visibly flat as lamp angle changes (%.3f–%.3f)" % [tier.name, darkest, brightest])
		tier_brightness.append((darkest + brightest) * 0.5)
	_check(tier_brightness[1] > tier_brightness[0] + 0.04,
		"Grazing light has distinct high-contrast bands (%.3f vs %.3f)" % [tier_brightness[0], tier_brightness[1]])
	_aim_for_lambert(0.004)
	var beyond_edge := await _capture("toon_below_edge")
	_check(_at(beyond_edge, Vector3.ZERO) < 0.015,
		"Light below the lowest band stays dark rather than adding an ambient floor")
	var largest_authored_difference := 0.0
	for lambert in [0.3, 0.45, 0.6, 0.85, 0.95]:
		_aim_for_lambert(lambert)
		_material.set_shader_parameter("toon_local_lighting", false)
		var authored := await _capture("authored_band_%.3f" % lambert)
		_material.set_shader_parameter("toon_local_lighting", true)
		var readable := await _capture("readable_band_%.3f" % lambert)
		largest_authored_difference = maxf(largest_authored_difference,
			absf(_at(authored, Vector3.ZERO) - _at(readable, Vector3.ZERO)))
	_check(largest_authored_difference < 0.008,
		"Existing bright toon bands keep their authored brightness (largest change %.3f)" % largest_authored_difference)


func _aim_for_lambert(lambert: float) -> void:
	var distance := 10.0
	_lamp.position = Vector3(0.0, distance * lambert / sqrt(1.0 - lambert * lambert), distance)
	_lamp.look_at(Vector3.ZERO)


func _test_other_illumination() -> void:
	_lamp.visible = false
	_material.set_shader_parameter("toon_local_lighting", false)
	var dark_legacy := await _capture("unlit_legacy")
	_material.set_shader_parameter("toon_local_lighting", true)
	var dark_readable := await _capture("unlit_readable")
	_check(_difference(dark_legacy, dark_readable) < 0.004 and _at(dark_readable, Vector3.ZERO) < 0.015,
		"Unlit stone remains black; the readable material adds no ambient glow")
	_key.visible = true
	_material.set_shader_parameter("toon_local_lighting", false)
	var directional_legacy := await _capture("directional_legacy")
	_material.set_shader_parameter("toon_local_lighting", true)
	var directional_readable := await _capture("directional_readable")
	_check(_at(directional_legacy, Vector3.ZERO) > 0.05 and _difference(directional_legacy, directional_readable) < 0.004,
		"Directional storm illumination retains its authored toon response")
	_key.visible = false
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.4, 0.5, 0.7)
	_environment.ambient_light_energy = 0.3
	_environment.ambient_light_sky_contribution = 0.0
	_material.set_shader_parameter("toon_local_lighting", false)
	var ambient_legacy := await _capture("ambient_legacy")
	_material.set_shader_parameter("toon_local_lighting", true)
	var ambient_readable := await _capture("ambient_readable")
	_check(_at(ambient_legacy, Vector3.ZERO) > 0.05 and _difference(ambient_legacy, ambient_readable) < 0.004,
		"Ambient illumination and the dark base palette remain unchanged (brightness %.3f, difference %.3f)" % [_at(ambient_legacy, Vector3.ZERO), _difference(ambient_legacy, ambient_readable)])


func _capture(name: String) -> Image:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var frame := _viewport.get_texture().get_image()
	if not _capture_dir.is_empty():
		frame.save_png(_capture_dir.path_join(name + ".png"))
	return frame


func _at(image: Image, world_position: Vector3) -> float:
	var pixel := Vector2i(_camera.unproject_position(world_position))
	var total := 0.0
	for y in range(pixel.y - 1, pixel.y + 2):
		for x in range(pixel.x - 1, pixel.x + 2):
			var color := image.get_pixel(x, y)
			total += (color.r + color.g + color.b) / 3.0
	return total / 9.0


func _difference(before: Image, after: Image) -> float:
	var largest := 0.0
	for y in range(32, 480, 8):
		for x in range(32, 480, 8):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			largest = maxf(largest, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
	return largest


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
