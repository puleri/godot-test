extends Node3D
## Orbit the saved assembly without generating or changing its geometry.
var focus := Vector3(0,6,0)
var yaw := 0.72
var pitch := 0.37
var distance := 68.0
var exploded := false
var floor_mode := 0
var _upper_y := 0.0

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440,900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_upper_y = $Building/UpperFloor.position.y
	_frame_camera()
	var hud := CanvasLayer.new()
	add_child(hud)
	var text := Label.new()
	text.position = Vector2(24,20)
	text.text = "COMPONENT BUILDING  /  CURRENT BLENDER EXPORT  /  AUTHORED COLORS\nDrag left mouse: orbit   Drag right mouse: pan   Wheel: zoom\n1: assembled   2: ground floor   3: upper floor   X: separate stories   F: reset view"
	text.add_theme_font_size_override("font_size",16)
	text.add_theme_color_override("font_color",Color("ebedf0"))
	text.add_theme_color_override("font_shadow_color",Color("182027"))
	text.add_theme_constant_override("shadow_offset_x",2)
	text.add_theme_constant_override("shadow_offset_y",2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(text)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			yaw -= event.relative.x*0.006
			pitch = clampf(pitch+event.relative.y*0.006,-0.3,1.5)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			focus += (-$InspectionCamera.basis.x*event.relative.x+$InspectionCamera.basis.y*event.relative.y)*distance*0.0012
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2,distance*0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(170,distance/0.88)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				floor_mode = event.physical_keycode-KEY_1
				$Building/GroundFloor.visible = floor_mode != 2
				$Building/UpperFloor.visible = floor_mode != 1
			KEY_X:
				exploded = not exploded
				$Building/UpperFloor.position.y = _upper_y+(5.0 if exploded else 0.0)
			KEY_F:
				focus = Vector3(0,6,0)
				yaw = 0.72
				pitch = 0.37
				distance = 68
	_frame_camera()

func _frame_camera() -> void:
	$InspectionCamera.position = focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	$InspectionCamera.look_at(focus)
