extends Node3D

const OPEN_DELAY := 0.55
var opens_on_lean := true
var progress := 0.0
var opened := false
var _panel: StaticBody3D


func _ready() -> void:
	_panel = $Panel


func update_lean(leaning_into: bool, delta: float) -> void:
	if opened:
		return
	progress = move_toward(progress, 1.0 if leaning_into else 0.0, delta / OPEN_DELAY)
	var target := progress * 0.32
	_panel.position.y = target
	if progress >= 1.0:
		open()


func open() -> void:
	if opened:
		return
	opened = true
	_panel.collision_layer = 0
	create_tween().tween_property(_panel, "position:y", 2.23, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
