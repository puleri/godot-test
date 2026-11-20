extends Control

const Game = preload("res://Modules/Gameplay/Lockpicking/lock_test.gd")
const INK := Color("#121823ed")
const IVORY := Color("#fff0ca")
const GOLD := Color("#dfaf62")
const MUTED := Color("#89949e")
const BLUE := Color("#79c3cf")
const TITLES := ["Harbor Storehouse", "Lamplight Shop", "Canal Gatehouse"]

@onready var game := get_parent().get_parent() as Game
var font := ThemeDB.fallback_font

func caption(at: Vector2, words: String, px: int, color: Color) -> void:
	draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _draw() -> void:
	if not is_instance_valid(game.player):
		return
	var scale_factor := minf(size.x / 1280, size.y / 720)
	if scale_factor <= 0:
		return
	var extent := size / scale_factor
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * scale_factor)
	draw_rect(Rect2(30, 30, 245, 44), INK)
	draw_rect(Rect2(30, 30, 4, 44), GOLD)
	caption(Vector2(49, 59), TITLES[game.mechanism], 21, IVORY)
	var use_key := "○" if game.gamepad else "E"
	var back := "△" if game.gamepad else "Q"
	var hint := ""
	match game.phase:
		Game.Phase.APPROACH:
			hint = use_key + "   Pick lock" if game.in_reach() else "Approach the brass lock"
		Game.Phase.PICKING:
			var action := ""
			match game.mechanism:
				Game.Mechanism.DIAL:
					action = ("Stick ↔" if game.gamepad else "← →") + "   Align      " + use_key + "   Turn"
				Game.Mechanism.SLIDERS:
					_sliders(Vector2(extent.x - 295, extent.y * 0.5 - 132))
					action = ("Stick ↕" if game.gamepad else "↑ ↓") + "   Lift      " + use_key + "   Set"
				Game.Mechanism.TIMING:
					var anchor := game.camera.unproject_position(Vector3(0,3.2,0)) / scale_factor
					_track(anchor)
					action = use_key + "   Catch"
			hint = action + "      " + back + "   Back away"
		Game.Phase.OPENING:
			hint = "Latch released"
		Game.Phase.OPEN:
			if game.player.position.z > -0.9:
				hint = "Door open"
	if game.feedback_time > 0:
		_strip(game.feedback, extent, 112, GOLD)
	if not hint.is_empty():
		_strip(hint, extent, 55, IVORY)

func _strip(words: String, extent: Vector2, bottom: float, color: Color) -> void:
	var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var at := Vector2((extent.x - width) / 2, extent.y - bottom)
	draw_rect(Rect2(at - Vector2(18, 26), Vector2(width + 36, 42)), INK)
	caption(at + Vector2(0, 2), words, 20, color)

func _sliders(at: Vector2) -> void:
	draw_rect(Rect2(at, Vector2(255,264)), INK)
	caption(at + Vector2(19,33), "TUMBLERS", 16, GOLD)
	for i in 3:
		var x := at.x + 24 + i * 74
		draw_rect(Rect2(x, at.y + 52, 55, 185), Color("#303641"))
		var level := 0.18
		if i < game.stage:
			level = 0.57
		elif i == game.stage:
			level = game.height
		var y := at.y + 207 - level * 126
		draw_rect(Rect2(x + 7, y - 15, 41, 30), BLUE if i < game.stage else GOLD)
		draw_line(Vector2(x+10,y),Vector2(x+45,y), INK, 3)
		if i == game.stage:
			draw_rect(Rect2(x+3,y-19,49,38), IVORY,false,2)
	var line_y := at.y + 207 - 0.57 * 126
	draw_line(Vector2(at.x+14,line_y),Vector2(at.x+240,line_y),IVORY,2)

func _track(at: Vector2) -> void:
	draw_rect(Rect2(at - Vector2(132,32),Vector2(264,58)),INK)
	for i in 3:
		draw_circle(at + Vector2(-110 + i * 15,-16),4, GOLD if i < game.stage else MUTED)
	var start := at + Vector2(-110,7)
	draw_line(start,start + Vector2(220,0),IVORY,3)
	draw_rect(Rect2(start + Vector2((game.gate_target()-0.105)*220,-6),Vector2(46.2,12)),GOLD)
	var point := start + Vector2(game.cursor * 220,0)
	draw_colored_polygon(PackedVector2Array([point+Vector2.UP*9,point+Vector2.RIGHT*7,point+Vector2.DOWN*9,point+Vector2.LEFT*7]), IVORY)
