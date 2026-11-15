extends Control
## A readable schematic of the playable canals, streets and upper crossings.
var city: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	if city == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.027, 0.05, 0.97))
	var font := ThemeDB.fallback_font
	var scale_factor := minf((size.x - 120) / 160.0, (size.y - 210) / 136.0)
	var origin := size * 0.5 + Vector2(0, 22)
	draw_string(font, Vector2(48, 58), "NOCTURNE  /  CITY ATLAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("f0c889"))
	draw_string(font, Vector2(48, 86), "Cyan: Rook     Gold: unfinished seal     Green: secured     Red: watch     M: return", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9db6cb"))
	for z in [-48, 0, 48]:
		for x in [-28, 28]:
			draw_line(origin + Vector2(x-6, z)*scale_factor, origin + Vector2(x+6, z)*scale_factor, Color("aa875a"), 6)
	for x in [-56, 0, 56]:
		for z in [-24, 24]:
			draw_line(origin + Vector2(x, z-6)*scale_factor, origin + Vector2(x, z+6)*scale_factor, Color("aa875a"), 6)
	for marker in city.get_node("Districts").get_children():
		var point: Vector2 = origin + Vector2(marker.position.x, marker.position.z)*scale_factor
		draw_rect(Rect2(point - Vector2(24,20)*scale_factor, Vector2(48,40)*scale_factor), Color("223347"))
		draw_rect(Rect2(point - Vector2(24,20)*scale_factor, Vector2(48,40)*scale_factor), Color("456075"), false, 1)
		draw_line(point - Vector2(22,0)*scale_factor, point + Vector2(22,0)*scale_factor, Color("385269"), 3)
		draw_line(point - Vector2(0,18)*scale_factor, point + Vector2(0,18)*scale_factor, Color("385269"), 3)
		draw_string(font, point + Vector2(-22*scale_factor,-15*scale_factor), marker.get_meta("title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d3dfeb"))
	for station in city.get_node("Stations").get_children():
		var point: Vector2 = origin + Vector2(station.position.x, station.position.z)*scale_factor
		draw_circle(point, 6, Color("8ed7bb") if station.completed else Color("f0c889"))
		if station.position.y > 2:
			draw_string(font, point + Vector2(9,5), "+6m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f0c889"))
	for guard in city.guards:
		var point: Vector2 = origin + Vector2(guard.position.x, guard.position.z)*scale_factor
		draw_circle(point, 3, Color("da7d7b"))
	var rook: Vector2 = origin + Vector2(city.player.position.x, city.player.position.z)*scale_factor
	draw_circle(rook, 7, Color("8be2e7"))
	draw_arc(rook, 11, 0, TAU, 24, Color("8be2e7"), 2)
	draw_string(font, Vector2(48,size.y-35), "160 × 136 m  /  20× Midnight Exchange  /  Streets 0m · balconies +3m · rooftops +6m", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9db6cb"))
