extends "res://Modules/Gameplay/Lockpicking/lock_hud.gd"

const ListeningLock = preload("res://Modules/Gameplay/Lockpicking/listening_lock.gd")
const BRASS := Color("#aa814a")
const BRONZE := Color("#684c32")
@onready var lock := game as ListeningLock

func _draw() -> void:
	if not is_instance_valid(lock) or not is_instance_valid(lock.player):
		return
	var factor := minf(size.x / 1280, size.y / 720)
	if factor <= 0:
		return
	var extent := size / factor
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * factor)
	var use_key := "○" if lock.gamepad else "E"
	var back := "△" if lock.gamepad else "Q"
	var hint := ""
	match lock.phase:
		Game.Phase.APPROACH:
			hint = use_key + "   Pick lock" if lock.in_reach() else "Approach the shop door"
		Game.Phase.PICKING:
			_cutaway(Vector2(extent.x - 268, 28))
			var sweep := "Stick ↔" if lock.gamepad else "← →"
			hint = sweep + "   Feel for contact      Hold " + use_key + "   Listen      " + back + "   Back away"
		Game.Phase.OPENING:
			hint = "Latch released"
		Game.Phase.OPEN:
			if lock.player.position.z > -0.9:
				hint = "Door open"
	if not hint.is_empty():
		_strip(hint, extent, 52, IVORY)
	if lock.feedback_time > 0:
		_strip(lock.feedback, extent, 103, GOLD)

func _cutaway(at: Vector2) -> void:
	var corners := PackedVector2Array([Vector2(12,0),Vector2(222,0),Vector2(234,12),
		Vector2(234,138),Vector2(222,150),Vector2(12,150),Vector2(0,138),Vector2(0,12)])
	for i in corners.size():
		corners[i] += at
	draw_colored_polygon(corners, INK)
	corners.append(corners[0])
	draw_polyline(corners, BRASS, 3, true)
	draw_rect(Rect2(at + Vector2(18,18), Vector2(198,6)), BRONZE)
	draw_rect(Rect2(at + Vector2(18,121), Vector2(198,8)), BRASS)
	for i in 4:
		var x := at.x + 46 + i * 47
		var y := at.y + 85 + [4, -2, 7, 0][i] as float
		var face := BRASS
		if i < lock.stage:
			y = at.y + 70
			face = GOLD
		elif i == lock.stage:
			if lock.contact:
				y -= 5.0 + 12.0 * lock.settling / lock.SET_TIME
			face = BRASS.lerp(IVORY, clampf(lock.glint * 4, 0, 1))
		var spring := PackedVector2Array()
		for k in 13:
			var offset := 5.0 if k % 2 else -5.0
			spring.append(Vector2(x + offset, lerpf(at.y+25, y-12, k/12.0)))
		draw_polyline(spring, BRASS, 2, true)
		draw_rect(Rect2(x-8,y-11,16,18),face)
		draw_rect(Rect2(x-8,y+9,16,17),face.darkened(0.18))
