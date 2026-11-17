class_name AlertEye
extends Node2D
## Shared suspicion display. Only searches following a chase pulse the overlay.

enum OverlayState { CLEAR, PURSUIT, SEARCH }

@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar

var _hearing_seconds := 0.0
var _hearing_caption: Label

var _overlay_state := OverlayState.CLEAR
var _overlay_tween: Tween
var _pursuing_guards: Dictionary = {}


func _ready() -> void:
	texture_progress_bar.step = 0.0
	texture_progress_bar.value = 0.0
	texture_progress_bar.tint_over.a = 0.0
	_hearing_caption = Label.new()
	_hearing_caption.position = Vector2(232, 160)
	_hearing_caption.add_theme_font_size_override("font_size", 20)
	add_child(_hearing_caption)
	_hearing_caption.hide()
	refresh()


func _process(delta: float) -> void:
	_hearing_seconds = maxf(0.0, _hearing_seconds - delta)
	_hearing_caption.visible = _hearing_seconds > 0.0
	_hearing_caption.modulate.a = minf(1.0, _hearing_seconds / 0.35)
	refresh()


func notify_heard(kind: String) -> void:
	_hearing_seconds = 2.5
	_hearing_caption.text = "BELL HEARD" if kind == "BELL" else "YOU WERE HEARD"
	_hearing_caption.show()
	_hearing_caption.modulate.a = 1.0


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
