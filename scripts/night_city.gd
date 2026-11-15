extends Node3D
## Open exploration: recover five ward seals and escape the city watch.
signal ready_for_play
@onready var player: CharacterBody3D = $Player
var guards: Array[StealthGuard] = []
var ready_to_play := false
var finished := false
var won := false
var map_open := false
var vision_visible := false
var collected := 0
var elapsed := 0.0
var bell_cooldown := 0.0
var checkpoint := Vector3(0, 0.49, 64)
var _activity_clock := 0.0
var _notice_time := 0.0
var _hud: CanvasLayer
var _title: Label
var _objective: Label
var _status: Label
var _notice: Label
var _result: Label
var _atlas: Control
var _bell_audio: AudioStreamPlayer
var _faded_house: Node3D

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for guard in $Guards.get_children():
		guards.append(guard)
		guard.player_caught.connect(func(): end_run(false))
		guard.set_suspicion_visible(true)
	player.noise_emitted.connect(_on_noise)
	_build_hud()
	_bell_audio = AudioStreamPlayer.new()
	_bell_audio.stream = _bell_sound()
	add_child(_bell_audio)
	# Navigation is authored and saved once by the build tool.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var region: NavigationRegion3D = $NavigationRegion3D
	var map: RID = region.get_navigation_map()
	while NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_closest_point_owner(map, player.position) != region.get_rid():
		await get_tree().physics_frame
	for guard in guards:
		guard.navigation_ready = true
	ready_to_play = true
	_update_activity()
	show_notice("Five wards. One sleeping city. Recover the seals and return to the blue quay.", 9)
	ready_for_play.emit()

func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("toggle_map"):
		if not finished:
			map_open = not map_open
			_atlas.visible = map_open
			_atlas.queue_redraw()
			player.set_interaction_locked(map_open)
			_update_activity()
	elif event.is_action_pressed("toggle_vision"):
		vision_visible = not vision_visible
		for guard in guards:
			guard.set_vision_visible(vision_visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("secondary_action"):
		if not map_open:
			ring_nearest_bell()
	elif event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if not ready_to_play or finished or map_open:
		return
	elapsed += delta
	bell_cooldown = maxf(0, bell_cooldown-delta)
	_notice_time = maxf(0, _notice_time-delta)
	_notice.visible = _notice_time > 0
	_activity_clock -= delta
	if _activity_clock <= 0:
		_activity_clock = 0.4
		_update_activity()
	_update_camera_occlusion()
	_update_interaction(delta)
	var nearest := _nearest_station()
	var sensor: StealthExposureSensor = $Player/ExposureSensor
	var district := "THE CANALS"
	for marker in $Districts.get_children():
		if absf(player.position.x-marker.position.x) < 24 and absf(player.position.z-marker.position.z) < 20:
			district = marker.get_meta("title")
			if player.is_on_floor() and player.position.y < 1 and player.position.distance_to(marker.position) < 5 and not under_pursuit():
				checkpoint = marker.position + Vector3(0,0.49,0)
	_title.text = "NOCTURNE  /  " + district
	if nearest != null:
		var offset: Vector3 = nearest.position-player.position
		_objective.text = "WARD SEALS  %d / 5     %s  ·  %dm%s" % [collected, nearest.title, roundi(Vector2(offset.x,offset.z).length()), "  ·  ROOFTOP +6m" if nearest.position.y > 2 else ""]
	else:
		_objective.text = "ALL FIVE SEALS SECURED  /  RETURN TO THE BLUE ARRIVAL QUAY"
	var threat := 0.0
	for guard in guards:
		threat = maxf(threat, guard.awareness)
	_status.text = "%s  /  %s  /  %s" % [sensor.exposure_name(), "WATCH ALERTED" if under_pursuit() else "WATCH %d%%" % roundi(threat*100), "STREET" if player.position.y < 2 else ("BALCONY +3m" if player.position.y < 5 else "ROOFTOPS +6m")]
	_status.modulate = Color("ef9884") if under_pursuit() else Color("93cbd1")
	if player.position.y < -4:
		recover_from_fall()
	try_extract()
	for bell in $Bells.get_children():
		bell.get_node("Caption").visible = bell.position.distance_to(player.position) < 3.2
		bell.get_node("Caption").text = "Q / RING WATCH BELL" if bell_cooldown <= 0 else "BELL / %.0fs" % ceilf(bell_cooldown)

func _update_activity() -> void:
	for guard in guards:
		var near: bool = guard.position.distance_to(player.position) < 52 or guard.guard_state == StealthGuard.GuardState.CHASE
		guard.process_mode = Node.PROCESS_MODE_INHERIT if near and not map_open and not finished else Node.PROCESS_MODE_DISABLED
		guard.get_node("SightLight").visible = near and guard.has_lamp

func _nearest_station() -> Node3D:
	var nearest: Node3D
	for station in $Stations.get_children():
		if not station.completed and (nearest == null or station.position.distance_squared_to(player.position) < nearest.position.distance_squared_to(player.position)):
			nearest = station
	return nearest

func under_pursuit() -> bool:
	for guard in guards:
		if guard.player_visible or guard.guard_state == StealthGuard.GuardState.CHASE:
			return true
	return false

func _update_interaction(delta: float, holding := Input.is_action_pressed("interact")) -> void:
	for station in $Stations.get_children():
		if station.completed:
			continue
		var near: bool = station.position.distance_to(player.position) < 1.9
		station.get_node("Caption").visible = near
		if near and holding and not under_pursuit():
			if station.advance(delta):
				collected += 1
				station.get_node("Visual").hide()
				station.get_node("Caption").hide()
				show_notice("Ward seal secured  /  %d of 5" % collected)
		else:
			station.reset_progress()
			station.get_node("Caption").text = "E / HOLD TO SECURE\n" + station.title

func _on_noise(at: Vector3, radius: float, kind: String) -> void:
	for guard in guards:
		if guard.process_mode != Node.PROCESS_MODE_DISABLED:
			guard.hear_sound(at,radius,kind)

func ring_nearest_bell() -> bool:
	if finished or map_open or bell_cooldown > 0:
		return false
	for bell in $Bells.get_children():
		if bell.position.distance_to(player.position) < 2.6:
			bell.get_node("Visual").ring()
			if _bell_audio.stream != null:
				_bell_audio.play()
			for guard in guards:
				if guard.process_mode != Node.PROCESS_MODE_DISABLED:
					guard.investigate_noise(bell.position)
			bell_cooldown = 9.0
			show_notice("The watch heard that. Move while they investigate.")
			return true
	return false

func recover_from_fall() -> void:
	player.position = checkpoint
	player.velocity = Vector3.ZERO
	player._focus = checkpoint
	show_notice("Back on dry stone. Your recovered seals are safe.")

func try_extract() -> void:
	if collected == 5 and player.position.distance_to($Extraction.position) < 1.8 and not under_pursuit():
		end_run(true)

func end_run(success: bool) -> void:
	if finished:
		return
	finished = true
	won = success
	player.set_interaction_locked(true)
	for guard in guards:
		guard.active = false
	_update_activity()
	_result.text = ("THE CITY KEEPS ITS SECRETS\nFive ward seals recovered. Back before dawn.\n%d:%02d" % [int(elapsed)/60, int(elapsed)%60] if success else "THE WATCH CAUGHT ROOK\nUse upper routes, quiet steps and bells to slip past patrols.") + "\n\nR / start a new night"
	_result.show()

func show_notice(message: String, duration := 4.0) -> void:
	_notice.text = message
	_notice_time = duration
	_notice.show()

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "CityHUD"
	add_child(_hud)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(screen)
	_title = _label(screen, Vector2(32,26), 15, Color("e2bb7e"))
	_objective = _label(screen, Vector2(32,52), 20, Color("e6e8df"))
	_status = _label(screen, Vector2(32,84), 13, Color("93cbd1"))
	var controls := _label(screen, Vector2.ZERO, 14, Color("b0c3cf"))
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 32
	controls.offset_top = -35
	controls.text = "WASD  move     SHIFT  quiet steps     SPACE  jump     E  secure seal     Q  bell     M  city atlas     TAB  vision     R  restart"
	_notice = _label(screen, Vector2.ZERO, 18, Color("f0c889"))
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.offset_left = -520
	_notice.offset_top = -90
	_notice.offset_right = 520
	_notice.custom_minimum_size.x = 1040
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result = _label(screen, Vector2.ZERO, 26, Color("f0d5a9"))
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result.offset_left = -500
	_result.offset_top = -110
	_result.offset_right = 500
	_result.offset_bottom = 110
	_result.custom_minimum_size = Vector2(1000,220)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.hide()
	_atlas = preload("res://scripts/night_city_map.gd").new()
	_atlas.city = self
	screen.add_child(_atlas)
	_atlas.hide()

func _label(parent: Control, at: Vector2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	label.add_theme_color_override("font_shadow_color",Color(0.01,0.02,0.03,0.95))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _bell_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050*2)
	for sample in 22050:
		var t := float(sample)/22050.0
		var wave := sin(TAU*660*t)*exp(-4*t) + sin(TAU*1327*t)*0.35*exp(-7*t)
		data.encode_s16(sample*2,int(wave*minf(t*250,1)*12000))
	stream.data = data
	return stream

func _update_camera_occlusion() -> void:
	var query := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*0.45,$LevelCamera.position,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var house: Node3D
	if not hit.is_empty():
		var candidate: Node = hit.collider
		while candidate != self and candidate != null:
			if str(candidate.name).begins_with("House_"):
				house = candidate
				break
			candidate = candidate.get_parent()
	if house == _faded_house:
		return
	if is_instance_valid(_faded_house):
		for geometry in _faded_house.find_children("*","GeometryInstance3D",true,false):
			geometry.transparency = 0.0
	_faded_house = house
	if is_instance_valid(house):
		for geometry in house.find_children("*","GeometryInstance3D",true,false):
			geometry.transparency = 0.78
