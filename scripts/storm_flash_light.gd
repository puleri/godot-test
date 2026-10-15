extends DirectionalLight3D

const STORM_RIM_PARAMETER := &"storm_rim_suppression"

@export_category("Storm Timing")
@export_range(0.1, 60.0, 0.1, "or_greater") var first_flash_delay := 4.0
@export_range(0.1, 60.0, 0.1, "or_greater") var minimum_interval := 7.0
@export_range(0.1, 60.0, 0.1, "or_greater") var maximum_interval := 22.0
@export_range(0.1, 60.0, 0.1, "or_greater") var burst_interval_minimum := 2.5
@export_range(0.1, 60.0, 0.1, "or_greater") var burst_interval_maximum := 6.0
@export_range(0.0, 1.0, 0.01) var burst_interval_chance := 0.18
@export_range(0.0, 1.0, 0.01) var extended_lull_chance := 0.2
@export_range(1.0, 4.0, 0.05) var extended_lull_multiplier := 1.9
@export_range(0.0, 1.0, 0.01) var double_flash_chance := 0.46
@export_range(0.0, 1.0, 0.01) var triple_flash_chance := 0.12
@export_range(0.01, 1.0, 0.01, "or_greater") var restrike_gap_minimum := 0.06
@export_range(0.01, 1.0, 0.01, "or_greater") var restrike_gap_maximum := 0.22

@export_category("Flash Shape")
@export_range(0.0, 4.0, 0.01, "or_greater") var minimum_peak_energy := 0.38
@export_range(0.0, 4.0, 0.01, "or_greater") var maximum_peak_energy := 1.12
@export_range(0.0, 1.0, 0.01) var intense_flash_chance := 0.13
@export_range(1.0, 3.0, 0.05) var intense_flash_multiplier := 1.4
@export_range(0.001, 1.0, 0.001, "or_greater") var flash_rise_time := 0.025
@export_range(0.0, 1.0, 0.001, "or_greater") var flash_hold_time := 0.045
@export_range(0.01, 3.0, 0.01, "or_greater") var flash_dissipation_time := 0.7
@export_range(0.0, 90.0, 0.5) var direction_variation_degrees := 24.0

@export_category("Playback")
@export var automatic := true

@export_category("Storm Audio")
@export var storm_ambience: AudioStream
@export var thunder_sounds: Array[AudioStream] = []
@export var audio_bus_name := "Storm"
@export_range(-60.0, 6.0, 0.5) var ambience_volume_db := -22.0
@export_range(0.5, 20.0, 0.5) var ambience_crossfade_seconds := 6.0
@export_range(-40.0, 0.0, 0.5) var thunder_minimum_volume_db := -18.0
@export_range(-30.0, 6.0, 0.5) var thunder_maximum_volume_db := -7.0
@export_range(0.0, 5.0, 0.05) var thunder_delay_minimum := 0.15
@export_range(0.0, 8.0, 0.05) var thunder_delay_maximum := 1.65
@export_range(0.0, 1.0, 0.01) var early_thunder_chance := 0.24
@export_range(0.0, 2.0, 0.05) var thunder_early_maximum := 0.6
@export_range(0.5, 1.5, 0.01) var thunder_pitch_minimum := 0.92
@export_range(0.5, 1.5, 0.01) var thunder_pitch_maximum := 1.07
@export_range(1, 8, 1) var thunder_voice_count := 4
@export_range(500.0, 16000.0, 100.0) var storm_filter_cutoff_hz := 4200.0
@export_range(0.01, 1.0, 0.01) var storm_filter_resonance := 0.18

var _rng := RandomNumberGenerator.new()
var _flash_timer: Timer
var _flash_tween: Tween
var _base_rotation := Vector3.ZERO
var _is_flashing := false
var _ambient_players: Array[AudioStreamPlayer] = []
var _thunder_players: Array[AudioStreamPlayer] = []
var _ambient_loop_timer: Timer
var _ambient_crossfade_tween: Tween
var _ambient_current_index := 0
var _ambient_crossfade_from := 0
var _ambient_crossfade_to := 1
var _ambient_loop_wait := 0.0
var _ambient_crossfade_duration := 0.0
var _audio_running := false
var _thunder_pool_cursor := 0
var _last_thunder_index := -1


func _ready() -> void:
	light_energy = 0.0
	visible = false
	_set_storm_rim_suppression(0.0)
	_base_rotation = rotation
	_rng.randomize()
	_setup_storm_audio()

	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(_on_flash_timer_timeout)
	add_child(_flash_timer)

	if automatic:
		_schedule_next_flash(first_flash_delay)


func trigger_flash(peak_energy := -1.0, use_precursor := false) -> void:
	if _is_flashing:
		return

	if _flash_timer != null:
		_flash_timer.stop()

	var resolved_peak := peak_energy
	if resolved_peak < 0.0:
		resolved_peak = _random_peak_energy()

	_play_flash_sequence(resolved_peak, use_precursor)


func stop_flashing() -> void:
	automatic = false
	_is_flashing = false
	if _flash_timer != null:
		_flash_timer.stop()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	light_energy = 0.0
	visible = false
	_set_storm_rim_suppression(0.0)


func _exit_tree() -> void:
	_audio_running = false
	if _ambient_loop_timer != null:
		_ambient_loop_timer.stop()
	if _ambient_crossfade_tween != null and _ambient_crossfade_tween.is_valid():
		_ambient_crossfade_tween.kill()
	for ambience_player in _ambient_players:
		ambience_player.stop()
	for thunder_player in _thunder_players:
		thunder_player.stop()
	_set_storm_rim_suppression(0.0)


func _on_flash_timer_timeout() -> void:
	_play_flash_sequence(_random_peak_energy(), false)


func _play_flash_sequence(peak_energy: float, use_precursor: bool) -> void:
	_is_flashing = true
	var early_thunder_lead := _start_thunder_timing(peak_energy)
	if early_thunder_lead > 0.0:
		await get_tree().create_timer(early_thunder_lead).timeout
		if not is_inside_tree() or not _is_flashing:
			return

	_set_storm_rim_suppression(1.0)
	rotation = _base_rotation + Vector3(
		0.0,
		deg_to_rad(_rng.randf_range(-direction_variation_degrees, direction_variation_degrees)),
		0.0
	)

	var pulse_count := _random_pulse_count()
	if use_precursor:
		pulse_count = maxi(pulse_count, 2)
	var main_pulse_index := _rng.randi_range(0, pulse_count - 1)

	for pulse_index in pulse_count:
		var is_main_pulse := pulse_index == main_pulse_index
		var is_final_pulse := pulse_index == pulse_count - 1
		var pulse_strength := peak_energy
		if not is_main_pulse:
			pulse_strength *= _rng.randf_range(0.38, 0.88)

		var rise_scale := _rng.randf_range(0.35, 1.35)
		var hold_scale := _rng.randf_range(0.25, 1.45)
		var decay_scale := _rng.randf_range(0.72, 1.35)
		if not is_final_pulse:
			decay_scale = _rng.randf_range(0.09, 0.25)

		await _play_pulse(
			pulse_strength,
			flash_rise_time * rise_scale,
			flash_hold_time * hold_scale,
			flash_dissipation_time * decay_scale
		)

		if not is_final_pulse:
			await get_tree().create_timer(_random_restrike_gap()).timeout

	_is_flashing = false
	_set_storm_rim_suppression(0.0)
	if automatic:
		_schedule_next_flash(_random_interval())


func _play_pulse(peak_energy: float, rise_time: float, hold_time: float, dissipation_time: float) -> void:
	light_energy = 0.0
	visible = true
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "light_energy", peak_energy, rise_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_interval(hold_time)
	_flash_tween.tween_property(self, "light_energy", 0.0, dissipation_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _flash_tween.finished
	light_energy = 0.0
	visible = false


func _random_pulse_count() -> int:
	var roll := _rng.randf()
	if roll < triple_flash_chance:
		return 3
	if roll < triple_flash_chance + double_flash_chance:
		return 2
	return 1


func _random_peak_energy() -> float:
	# Bias the storm toward restrained flashes while preserving rare, dramatic peaks.
	var energy_roll := pow(_rng.randf(), 1.65)
	var peak := lerpf(minimum_peak_energy, maximum_peak_energy, energy_roll)
	if _rng.randf() < intense_flash_chance:
		peak *= _rng.randf_range(1.15, intense_flash_multiplier)
	return peak


func _random_interval() -> float:
	var delay: float
	if _rng.randf() < burst_interval_chance:
		# Squaring the roll creates tight clusters without making their cadence regular.
		delay = lerpf(burst_interval_minimum, burst_interval_maximum, pow(_rng.randf(), 2.0))
	else:
		delay = lerpf(minimum_interval, maximum_interval, pow(_rng.randf(), 1.35))
		if _rng.randf() < extended_lull_chance:
			delay *= _rng.randf_range(1.25, extended_lull_multiplier)
	return delay


func _random_restrike_gap() -> float:
	return lerpf(restrike_gap_minimum, restrike_gap_maximum, pow(_rng.randf(), 1.6))


func _setup_storm_audio() -> void:
	_ensure_audio_bus()

	for player_index in 2:
		var ambience_player := AudioStreamPlayer.new()
		ambience_player.name = "StormAmbience%d" % (player_index + 1)
		ambience_player.bus = audio_bus_name
		ambience_player.stream = storm_ambience
		ambience_player.volume_db = -80.0
		add_child(ambience_player)
		_ambient_players.append(ambience_player)

	for player_index in thunder_voice_count:
		var thunder_player := AudioStreamPlayer.new()
		thunder_player.name = "ThunderVoice%d" % (player_index + 1)
		thunder_player.bus = audio_bus_name
		add_child(thunder_player)
		_thunder_players.append(thunder_player)

	if storm_ambience != null and storm_ambience.get_length() > 0.0:
		_ambient_loop_timer = Timer.new()
		_ambient_loop_timer.name = "StormAmbienceLoopTimer"
		_ambient_loop_timer.one_shot = true
		_ambient_loop_timer.timeout.connect(_on_ambient_loop_timer_timeout)
		add_child(_ambient_loop_timer)
		_audio_running = true
		_start_ambience_loop()


func _start_ambience_loop() -> void:
	var stream_length := storm_ambience.get_length()
	_ambient_crossfade_duration = clampf(ambience_crossfade_seconds, 0.1, stream_length * 0.45)
	_ambient_loop_wait = maxf(stream_length - _ambient_crossfade_duration, 0.1)
	var current_player := _ambient_players[_ambient_current_index]
	current_player.volume_db = -80.0
	current_player.play()

	var fade_in := create_tween()
	fade_in.tween_property(current_player, "volume_db", ambience_volume_db, minf(2.0, _ambient_crossfade_duration))
	_ambient_loop_timer.start(_ambient_loop_wait)


func _on_ambient_loop_timer_timeout() -> void:
	if not _audio_running:
		return
	var next_index := 1 - _ambient_current_index
	_begin_ambience_crossfade(_ambient_current_index, next_index)


func _begin_ambience_crossfade(from_index: int, to_index: int) -> void:
	_ambient_crossfade_from = from_index
	_ambient_crossfade_to = to_index
	var incoming := _ambient_players[to_index]
	incoming.stream = storm_ambience
	incoming.volume_db = -80.0
	incoming.play()

	_ambient_crossfade_tween = create_tween()
	_ambient_crossfade_tween.tween_method(
		_apply_ambient_crossfade,
		0.0,
		1.0,
		_ambient_crossfade_duration
	)
	_ambient_crossfade_tween.finished.connect(_on_ambience_crossfade_finished)


func _on_ambience_crossfade_finished() -> void:
	if not _audio_running or not is_inside_tree():
		return
	var outgoing := _ambient_players[_ambient_crossfade_from]
	var incoming := _ambient_players[_ambient_crossfade_to]
	outgoing.stop()
	outgoing.volume_db = -80.0
	incoming.volume_db = ambience_volume_db
	_ambient_current_index = _ambient_crossfade_to
	_ambient_loop_timer.start(_ambient_loop_wait)


func _apply_ambient_crossfade(mix_amount: float) -> void:
	if _ambient_players.size() < 2:
		return
	var target_gain := db_to_linear(ambience_volume_db)
	var outgoing_gain := cos(mix_amount * PI * 0.5) * target_gain
	var incoming_gain := sin(mix_amount * PI * 0.5) * target_gain
	_ambient_players[_ambient_crossfade_from].volume_db = linear_to_db(maxf(outgoing_gain, 0.0001))
	_ambient_players[_ambient_crossfade_to].volume_db = linear_to_db(maxf(incoming_gain, 0.0001))


func _start_thunder_timing(strike_energy: float) -> float:
	if thunder_sounds.is_empty() or _thunder_players.is_empty():
		return 0.0

	var distance_roll := pow(_rng.randf(), 1.35)
	if thunder_early_maximum > 0.0 and _rng.randf() < early_thunder_chance:
		_play_random_thunder(strike_energy, distance_roll)
		return _rng.randf_range(0.05, thunder_early_maximum)

	var delay := lerpf(thunder_delay_minimum, thunder_delay_maximum, distance_roll)
	_schedule_thunder(strike_energy, distance_roll, delay)
	return 0.0


func _schedule_thunder(strike_energy: float, distance_roll: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	_play_random_thunder(strike_energy, distance_roll)


func _play_random_thunder(strike_energy: float, distance_roll: float) -> void:
	var thunder_index := _rng.randi_range(0, thunder_sounds.size() - 1)
	if thunder_sounds.size() > 1 and thunder_index == _last_thunder_index:
		thunder_index = (thunder_index + _rng.randi_range(1, thunder_sounds.size() - 1)) % thunder_sounds.size()
	_last_thunder_index = thunder_index

	var player := _next_thunder_player()
	player.stream = thunder_sounds[thunder_index]
	player.pitch_scale = _rng.randf_range(thunder_pitch_minimum, thunder_pitch_maximum)

	var loudest_expected_energy := maximum_peak_energy * intense_flash_multiplier
	var intensity := inverse_lerp(minimum_peak_energy, loudest_expected_energy, strike_energy)
	intensity = clampf(intensity, 0.0, 1.0)
	var distance_attenuation := lerpf(0.0, -4.5, distance_roll)
	var volume_variance := _rng.randf_range(-2.25, 2.25)
	player.volume_db = clampf(
		lerpf(thunder_minimum_volume_db, thunder_maximum_volume_db, intensity)
		+ distance_attenuation
		+ volume_variance,
		-40.0,
		6.0
	)
	player.play()


func _next_thunder_player() -> AudioStreamPlayer:
	for player in _thunder_players:
		if not player.playing:
			return player

	var player := _thunder_players[_thunder_pool_cursor]
	_thunder_pool_cursor = (_thunder_pool_cursor + 1) % _thunder_players.size()
	player.stop()
	return player


func _ensure_audio_bus() -> void:
	var bus_index := AudioServer.get_bus_index(audio_bus_name)
	if bus_index == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, audio_bus_name)

	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		var existing_effect := AudioServer.get_bus_effect(bus_index, effect_index)
		if existing_effect is AudioEffectLowPassFilter:
			existing_effect.cutoff_hz = storm_filter_cutoff_hz
			existing_effect.resonance = storm_filter_resonance
			return

	var low_pass_filter := AudioEffectLowPassFilter.new()
	low_pass_filter.cutoff_hz = storm_filter_cutoff_hz
	low_pass_filter.resonance = storm_filter_resonance
	AudioServer.add_bus_effect(bus_index, low_pass_filter, 0)


func _schedule_next_flash(delay: float) -> void:
	if _flash_timer == null or not automatic:
		return
	_flash_timer.start(maxf(delay, 0.01))


func _set_storm_rim_suppression(amount: float) -> void:
	RenderingServer.global_shader_parameter_set(STORM_RIM_PARAMETER, clampf(amount, 0.0, 1.0))
