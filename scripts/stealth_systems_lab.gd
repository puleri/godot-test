extends Node3D
## Interactive, resettable demonstrations. Existing levels keep their controllers.

signal ready_for_play
const SPAWNS := [Vector3(-26, 0.49, 3), Vector3(-4, 0.49, 3), Vector3(18, 0.49, 3)]
const TITLES := ["01 / SOUND THROUGH DOORS", "02 / DIVIDE THE WATCH", "03 / SET THE TRAP"]
const HINTS := [
	"E makes a 12m pulse. Compare the doorway listener with the sealed control. G closes the door.",
	"The sentry resumes a short watch patrol. Audible footsteps elsewhere can draw it away. H tests takeover.",
	"F places a chime. Hold Shift to move quietly behind cover, then Q triggers it. Watch the search.",
]
@onready var player: CharacterBody3D = $Player
@onready var region: NavigationRegion3D = $NavigationRegion3D
@onready var acoustics: Node3D = $Acoustics
var guards: Array[Node3D] = []
var active_bay := 0
var door_open := true
var lure_armed := false
var completed := [false, false, false]
var ready_to_play := false
var leader: Node3D
var _pending_takeover := false
var last_routes: Array[Dictionary] = []
var _cooldown := 0.0
var _title: Label
var _hint: Label
var _readout: Label
var _progress: Label
var _report := "Stand on the blue pad and press E."
var _audio: AudioStreamPlayer
var _feedback: Array[Node3D] = []
var inspection_light := false


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for guard in $Guards.get_children():
		guards.append(guard)
		guard.player_caught.connect(_on_caught)
	player.noise_emitted.connect(_on_footstep)
	_build_hud()
	_audio = AudioStreamPlayer.new()
	_audio.stream = _chime_sound()
	_audio.volume_db = -18
	add_child(_audio)
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	var map := region.get_navigation_map()
	while NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_closest_point_owner(map, player.position) != region.get_rid():
		await get_tree().physics_frame
	for guard in guards:
		guard.navigation_ready = true
	ready_to_play = true
	select_bay(0)
	ready_for_play.emit()


func select_bay(index: int, jump := true) -> void:
	active_bay = clampi(index, 0, 2)
	if active_bay == 0:
		set_door(true)
	leader = null
	_pending_takeover = false
	for guard in guards:
		guard.reset_demo()
		guard.process_mode = Node.PROCESS_MODE_INHERIT if guard.bay == active_bay else Node.PROCESS_MODE_DISABLED
	if jump:
		player.jump_to(SPAWNS[active_bay])
	else:
		player.set_interaction_locked(false)
	for effect in _feedback:
		if is_instance_valid(effect):
			effect.queue_free()
	_feedback.clear()
	player.get_node("ExposureSensor").refresh()
	lure_armed = false
	$RemoteChime.hide()
	_cooldown = 0
	_report = "Stand on the blue pad and press E." if active_bay != 2 else "F places a chime. Find cover before you press Q."
	_refresh_hud()


func set_door(open: bool) -> void:
	door_open = open
	var gate := $NavigationRegion3D/AcousticGate
	gate.visible = not open
	for body in gate.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0 if open else 1
	_report = "DOOR %s. Press E from the blue pad to compare." % ("OPEN" if open else "CLOSED")


func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_play or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_1: select_bay(0)
	elif event is InputEventKey and event.physical_keycode == KEY_2: select_bay(1)
	elif event is InputEventKey and event.physical_keycode == KEY_3: select_bay(2)
	elif event.is_action_pressed("lab_door"):
		if active_bay == 0:
			set_door(not door_open)
	elif event.is_action_pressed("interact"):
		if _cooldown <= 0 and not player.interaction_locked:
			emit_noise(Vector3(player.position.x, 0, player.position.z), 12, "PULSE")
			_cooldown = 0.7
			_audio.play()
	elif event.is_action_pressed("place_chime"): place_chime()
	elif event.is_action_pressed("secondary_action"): trigger_chime()
	elif event.is_action_pressed("disable_investigator"): disable_investigator()
	elif event.is_action_pressed("toggle_map"): player.map_view = not player.map_view
	elif event.is_action_pressed("inspection_light"): toggle_inspection_light()
	elif event.is_action_pressed("toggle_vision"):
		for guard in guards:
			guard.set_vision_visible(not guard.show_vision)
	elif event.is_action_pressed("restart"): get_tree().reload_current_scene()


func _process(delta: float) -> void:
	_cooldown = maxf(0, _cooldown - delta)
	if not ready_to_play:
		return
	for i in 3:
		if i != active_bay and absf(player.position.x - (i - 1) * 22) < 7 and absf(player.position.z) < 6:
			select_bay(i, false)
			break
	_update_squad()
	for guard in guards:
		if guard.bay == 2 and guard.visited_search_points >= 2:
			completed[2] = true
	if player.position.y < -5:
		select_bay(active_bay)
	_refresh_hud()


func _update_squad() -> void:
	if active_bay != 1 or player.interaction_locked:
		return
	var lost_partner: bool = is_instance_valid(leader) and (not leader.active or leader.process_mode == Node.PROCESS_MODE_DISABLED)
	_pending_takeover = _pending_takeover or lost_partner
	leader = null
	for guard in guards:
		if guard.bay != 1 or not guard.active or guard.process_mode == Node.PROCESS_MODE_DISABLED or guard.duty != "INVESTIGATOR":
			continue
		if guard.guard_state == StealthGuard.GuardState.PATROL:
			guard.duty = "PATROL"
		elif leader == null:
			leader = guard
	# A second incident may already have its own investigator.
	if leader != null:
		_pending_takeover = false
		return
	for guard in guards:
		if guard.bay != 1 or not guard.active or guard.duty != "SENTRY" or guard.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if _pending_takeover:
			if guard.guard_state != StealthGuard.GuardState.PATROL or guard.player_visible or guard.uncertain_visible:
				continue
			leader = guard
			guard.investigate_incident(guard.covered_incident, "PARTNER UNAVAILABLE")
			_pending_takeover = false
			guard._update_feedback(0)
			_report = "%s TAKING OVER the last sound investigation. Press 2 to reset." % guard.guard_title
			break
		guard.duty = "PATROL"


func disable_investigator() -> bool:
	if active_bay != 1 or player.interaction_locked or not is_instance_valid(leader) or not leader.active:
		return false
	leader.active = false
	leader.velocity = Vector3.ZERO
	leader.has_lamp = false
	leader._update_feedback(0)
	_update_squad()
	_refresh_hud()
	return true


func _on_footstep(at: Vector3, radius: float, kind: String) -> void:
	if ready_to_play and not player.interaction_locked:
		emit_noise(Vector3(at.x, 0, at.z), radius, kind)


func emit_noise(at: Vector3, radius: float, kind: String) -> Array[Dictionary]:
	last_routes.clear()
	for guard in guards:
		if guard.bay != active_bay or not guard.active:
			continue
		var result: Dictionary = acoustics.route(at, guard.position, minf(radius, guard.hearing_range))
		last_routes.append({"guard": guard, "result": result})
	if active_bay == 1:
		_dispatch_squad(at, kind)
	else:
		for receipt in last_routes:
			receipt.guard.receive_noise(at, kind, receipt.result)
	if active_bay == 0 and last_routes.size() == 2 and last_routes[0].result.audible and not last_routes[1].result.audible:
		completed[0] = true
	for receipt in last_routes:
		receipt.guard._update_feedback(0)
	var lines := PackedStringArray([kind + " / maximum reach %.1fm" % radius])
	for receipt in last_routes:
		var result: Dictionary = receipt.result
		lines.append("%s: %s" % [receipt.guard.guard_title,
			"HEARD / %.1fm route" % result.distance if result.audible else ("SEALED" if is_inf(result.distance) else "TOO FAR / %.1fm route" % result.distance)])
	_report = "\n".join(lines)
	_draw_noise(at, radius, last_routes)
	return last_routes


func _dispatch_squad(at: Vector3, kind: String) -> void:
	_update_squad()
	var investigators: Array[Node3D] = []
	var existing_interest := false
	for guard in guards:
		if guard.bay == 1 and guard.active and guard.duty == "INVESTIGATOR" and guard.process_mode != Node.PROCESS_MODE_DISABLED:
			investigators.append(guard)
			if at.distance_to(guard.investigation_target) < 4.0:
				existing_interest = true
	var chosen: Node3D
	# Group nearby repeats by incident; a separate audible footstep is still
	# a real disturbance. Busy investigators retain their assigned targets.
	if not existing_interest:
		var best := INF
		for receipt in last_routes:
			var guard: Node3D = receipt.guard
			if receipt.result.audible and guard.active and not guard.player_visible and not guard.uncertain_visible and guard.guard_state == StealthGuard.GuardState.PATROL and guard.duty != "INVESTIGATOR" and receipt.result.distance < best:
				chosen = guard
				best = receipt.result.distance
		if chosen != null:
			chosen.investigate_incident(at, kind)
			if leader == null:
				leader = chosen
			if investigators.is_empty():
				for receipt in last_routes:
					var guard: Node3D = receipt.guard
					if guard != chosen and receipt.result.audible and not guard.player_visible and not guard.uncertain_visible and guard.guard_state == StealthGuard.GuardState.PATROL:
						guard.hold_exit(at)
			completed[1] = true
	for receipt in last_routes:
		# Assignment above starts investigations. Every audible event still
		# reaches sentry reaction, even when no new investigator is needed.
		receipt.guard.receive_noise(at, kind, receipt.result, false)


func place_chime() -> bool:
	if active_bay != 2 or player.interaction_locked or _cooldown > 0:
		return false
	$RemoteChime.position = Vector3(player.position.x, 0, player.position.z)
	$RemoteChime.show()
	lure_armed = true
	_report = "CHIME ARMED. Move behind a wall; Q activates it remotely."
	_preview_chime()
	return true


func _preview_chime() -> void:
	var preview: Array[Dictionary] = []
	for guard in guards:
		if guard.bay == 2:
			preview.append({"guard": guard, "result": acoustics.route($RemoteChime.position, guard.position, 12)})
	_draw_noise($RemoteChime.position, 12, preview)


func trigger_chime() -> bool:
	if active_bay != 2 or not lure_armed or player.interaction_locked:
		return false
	lure_armed = false
	$RemoteChime/Visual.ring()
	_audio.play()
	emit_noise($RemoteChime.position, 12, "CHIME")
	_cooldown = 6.0
	return true


func _on_caught() -> void:
	player.set_interaction_locked(true)
	for guard in guards:
		guard.active = false
	_report = "CAUGHT. Press %d to reset this bay, or R to reset the lab." % (active_bay + 1)


func toggle_inspection_light() -> void:
	inspection_light = not inspection_light
	var storm := $StormFlashLight
	storm.stop_flashing()
	if inspection_light:
		storm.visible = true
		storm.light_energy = 0.65
		RenderingServer.global_shader_parameter_set("storm_rim_suppression", 1.0)
	else:
		storm.automatic = true
		storm.trigger_flash()


func _draw_noise(at: Vector3, radius: float, receipts: Array[Dictionary]) -> void:
	var fx := Node3D.new()
	_feedback.append(fx)
	fx.name = "NoiseFeedback"
	add_child(fx)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.45, 0.87, 0.92, 0.8)
	var circle_material := material.duplicate() as StandardMaterial3D
	circle_material.albedo_color.a = 0.35
	var circle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.994
	ring.outer_radius = 1.006
	circle.mesh = ring
	circle.material_override = circle_material
	circle.position = at + Vector3.UP * 0.08
	circle.scale = Vector3(0.1, 1, 0.1)
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(circle)
	var mesh := ImmediateMesh.new()
	var has_lines := false
	for receipt in receipts:
		if receipt.result.audible and receipt.result.path.size() > 1:
			if not has_lines:
				mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				has_lines = true
			var path: PackedVector3Array = receipt.result.path
			for i in range(path.size() - 1):
				mesh.surface_add_vertex(path[i])
				mesh.surface_add_vertex(path[i + 1])
	if has_lines:
		mesh.surface_end()
		var route_mesh := MeshInstance3D.new()
		route_mesh.mesh = mesh
		fx.add_child(route_mesh)
	var tween := fx.create_tween()
	tween.tween_property(circle, "scale", Vector3(radius, 1, radius), 0.4)
	tween.tween_interval(1.6)
	tween.tween_property(material, "albedo_color:a", 0, 0.4)
	tween.parallel().tween_property(circle_material, "albedo_color:a", 0, 0.4)
	tween.tween_callback(func() -> void:
		_feedback.erase(fx)
		fx.queue_free()
	)


func _chime_sound() -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(11025 * 2)
	for i in 11025:
		var t := i / 22050.0
		var sample := (sin(TAU * 740 * t) + sin(TAU * 1170 * t) * 0.35) * exp(-9 * t) * 0.3
		bytes.encode_s16(i * 2, roundi(sample * 32767))
	sound.data = bytes
	return sound


func _refresh_hud() -> void:
	_title.text = TITLES[active_bay]
	_hint.text = HINTS[active_bay]
	_readout.text = _report
	_progress.text = "DOOR TEST %s     TEAM ROLES %s     AREA SEARCH %s" % ["✓" if completed[0] else "—", "✓" if completed[1] else "—", "✓" if completed[2] else "—"]


func _label(text: String, size: int, color := Color("e6e9e4")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LabHUD"
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.add_theme_constant_override("separation", 8)
	layer.add_child(box)
	box.add_child(_label("ROOK / STEALTH SYSTEMS LAB", 13, Color("e4bc77")))
	_title = _label("", 26)
	box.add_child(_title)
	_hint = _label("", 15)
	box.add_child(_hint)
	_readout = _label("", 14, Color("83d8dd"))
	box.add_child(_readout)
	box.add_child(_label("Circle = maximum reach. Cyan paths = guards that actually hear it.", 13, Color("a0acb7")))
	_progress = _label("", 13, Color("e4bc77"))
	box.add_child(_progress)
	var controls := _label("1/2/3 reset bay   WASD move   SHIFT quiet   E noise   G door   H disable investigator   F/Q chime   TAB sight   M map   L light   R reset", 12)
	controls.position = Vector2(30, 858)
	layer.add_child(controls)
