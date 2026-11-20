extends PanelContainer
## Keeps the cargo mark legible while Rook compares the actual marks below deck.

const PAPER := Color("#e7cf9e")
const INK := Color("#332a29")

class CargoTag extends Control:
	func _draw() -> void:
		# A clipped paper corner, a brass tack and the slate's crescent-and-two-dots mark.
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 5), Vector2(6, 0), Vector2(58, 0), Vector2(58, 42), Vector2(0, 42)
		]), PAPER)
		draw_circle(Vector2(6, 6), 2.0, Color("#96784b"), true, -1, true)
		draw_circle(Vector2(23, 22), 13.0, INK, true, -1, true)
		draw_circle(Vector2(29, 18), 12.0, PAPER, true, -1, true)
		draw_circle(Vector2(38, 28), 3.0, INK, true, -1, true)
		draw_circle(Vector2(48, 28), 3.0, INK, true, -1, true)

var _tag: CargoTag
var _source: Label
var _instruction: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(26, 22)
	add_theme_stylebox_override("panel", caption_style())
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	add_child(content)
	_tag = CargoTag.new()
	_tag.custom_minimum_size = Vector2(58, 42)
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_tag)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	content.add_child(text)
	_source = Label.new()
	_source.add_theme_color_override("font_color", Color("#d2ad73"))
	_source.add_theme_font_size_override("font_size", 13)
	text.add_child(_source)
	_instruction = Label.new()
	_instruction.add_theme_color_override("font_color", Color("#fff1d6"))
	_instruction.add_theme_font_size_override("font_size", 22)
	text.add_child(_instruction)
	hide()


func display(source: String, instruction: String, marked: bool) -> void:
	_source.text = source
	_instruction.text = instruction
	_tag.visible = marked
	reset_size()
	show()


static func caption_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.069, 0.073, 0.087, 0.91)
	panel.border_color = Color("#c39b61")
	panel.border_width_left = 2
	panel.content_margin_left = 14
	panel.content_margin_right = 16
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	return panel
