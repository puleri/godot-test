class_name AlertEye
extends Node2D
## Shared suspicion display. Only searches following a chase pulse the overlay.

enum OverlayState { CLEAR, PURSUIT, SEARCH }

@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar

var _overlay_state := OverlayState.CLEAR
var _overlay_tween: Tween
var _pursuing_guards: Dictionary = {}


func _ready() -> void:
	texture_progress_bar.step = 0.0
	texture_progress_bar.value = 0.0
	texture_progress_bar.tint_over.a = 0.0
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var awareness := 0.0
	var pursuing := false
	var searching := false
	var remembered: Dictionary = {}
	for node in get_tree().get_nodes_in_group("stealth_guards"):
		var guard := node as StealthGuard
		if guard == null:
			continue
		awareness = maxf(awareness, clampf(guard.awareness, 0.0, 1.0))
		var id := guard.get_instance_id()
		if guard.guard_state == StealthGuard.GuardState.CHASE:
			pursuing = true
			remembered[id] = true
		elif guard.guard_state == StealthGuard.GuardState.SEARCH and _pursuing_guards.has(id):
			searching = true
			remembered[id] = true
	_pursuing_guards = remembered
	texture_progress_bar.value = awareness * 100.0
	_set_overlay_state(OverlayState.PURSUIT if pursuing else (OverlayState.SEARCH if searching else OverlayState.CLEAR))


func freeze() -> void:
	# Capture the final physics state, including capture on the first chase frame.
	refresh()
	set_process(false)
	if _overlay_tween != null:
		_overlay_tween.pause()


func _set_overlay_state(next: OverlayState) -> void:
	if next == _overlay_state:
		return
	_overlay_state = next
	if _overlay_tween != null:
		_overlay_tween.kill()
	_overlay_tween = create_tween()
	if next == OverlayState.SEARCH:
		# Start at full opacity so every pulse stays inside the 30–100% range.
		texture_progress_bar.tint_over.a = 1.0
		_overlay_tween.set_loops()
		_overlay_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_overlay_tween.tween_property(texture_progress_bar, "tint_over:a", 0.3, 0.5)
		_overlay_tween.tween_property(texture_progress_bar, "tint_over:a", 1.0, 0.5)
	else:
		_overlay_tween.tween_property(texture_progress_bar, "tint_over:a", 1.0 if next == OverlayState.PURSUIT else 0.0, 0.2)
