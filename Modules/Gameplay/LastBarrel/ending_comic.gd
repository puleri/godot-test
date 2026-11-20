extends Control

const CAPTIONS := [
	"With the Night Seal tucked under one wing, Rook slips over the rail of the burning ship.",
	"He drops into the harbor mist, spreads his wings, and glides clear of the flames.",
	"Rook looks back. Two red eyes stare down at him from the crow’s nest.",
	"Close on the eyes. They follow him through the smoke. A speech bubble hangs beside them.",
]

var panel := -1
var controller := false
var captions: Array[Label] = []
var bubble: Label
var instruction: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var paper := ColorRect.new()
	paper.color = Color("e6d7b4")
	add_child(paper)
	paper.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 38)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margins.add_child(page)
	page.add_child(_label("THE LAST BARREL", 32))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	for line in CAPTIONS:
		var frame := PanelContainer.new()
		frame.size_flags_horizontal = SIZE_EXPAND_FILL
		frame.size_flags_vertical = SIZE_EXPAND_FILL
		var border := StyleBoxFlat.new()
		border.bg_color = Color("f2e5c6")
		border.border_color = Color("252229")
		border.set_border_width_all(3)
		border.content_margin_left = 21
		border.content_margin_right = 21
		border.content_margin_top = 12
		border.content_margin_bottom = 12
		frame.add_theme_stylebox_override("panel", border)
		grid.add_child(frame)
		var panel_content := VBoxContainer.new()
		panel_content.alignment = BoxContainer.ALIGNMENT_CENTER
		frame.add_child(panel_content)
		var caption := _label(line, 23)
		panel_content.add_child(caption)
		captions.append(caption)
		if line == CAPTIONS.back():
			bubble = _label("YOU", 30)
			bubble.autowrap_mode = TextServer.AUTOWRAP_OFF
			bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var ink := StyleBoxFlat.new()
			ink.bg_color = Color("fff7df")
			ink.border_color = Color("252229")
			ink.set_border_width_all(2)
			ink.set_corner_radius_all(18)
			ink.content_margin_left = 24
			ink.content_margin_right = 24
			ink.content_margin_top = 5
			ink.content_margin_bottom = 5
			bubble.add_theme_stylebox_override("normal", ink)
			bubble.size_flags_horizontal = SIZE_SHRINK_END
			panel_content.add_child(bubble)
	instruction = _label("", 17)
	page.add_child(instruction)
	hide()


func begin(using_controller: bool) -> void:
	controller = using_controller
	show()
	advance()


func advance() -> void:
	panel = mini(panel + 1, CAPTIONS.size() - 1)
	for index in captions.size():
		# Keep text in the layout even while its panel is waiting to be revealed.
		captions[index].modulate.a = 1.0 if index <= panel else 0.0
	bubble.modulate.a = 1.0 if panel == CAPTIONS.size() - 1 else 0.0
	if panel < CAPTIONS.size() - 1:
		instruction.text = "Cross   Next panel" if controller else "Space   Next panel"
	else:
		instruction.text = "End  ·  Night Seal recovered"


func _label(line: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = line
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("252229"))
	label.add_theme_font_size_override("font_size", font_size)
	return label
