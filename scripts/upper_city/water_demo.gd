@tool
extends Node3D
## Standalone visual demonstration. The Path3D curve can be edited in the Godot editor.
@export_range(0.0, 3.0) var flow_speed: float = 0.9
@export_range(1.0, 10.0) var river_width: float = 4.0:
 set(value):
  river_width = value
  if is_inside_tree():
   call_deferred("_rebuild_water")
var water_material: ShaderMaterial
var fall_material: ShaderMaterial
var foam_material: ShaderMaterial
var rotor: Node3D
var generated: Node3D
var splash: CPUParticles3D
var mist: CPUParticles3D
var dragging := false
var camera: Camera3D

func _ready() -> void:
 camera = $Camera3D
 camera.look_at(Vector3(-1, 3, -9))
 _find_geometry($MillAndCanal)
 $RiverPath.curve.changed.connect(_rebuild_water)
 _rebuild_water()
 if not Engine.is_editor_hint():
  _make_controls()
  if "--capture" in OS.get_cmdline_user_args():
   for i in range(40):
    await get_tree().process_frame
   var img := get_viewport().get_texture().get_image()
   img.save_png("res://art/UpperCityLibrary/godot_water_demo.png")
   get_tree().quit()

func _find_geometry(node: Node) -> void:
 if "WATER_PREVIEW" in str(node.name) and node is Node3D:
  node.visible = false
 var lower := str(node.name).to_lower()
 if "rotate" in lower and "waterwheel" in lower and node is Node3D:
  rotor = node
 for child in node.get_children():
  _find_geometry(child)

func _rebuild_water() -> void:
 if not is_inside_tree():
  return
 if is_instance_valid(generated):
  remove_child(generated)
  generated.queue_free()
 splash = null
 mist = null
 generated = Node3D.new()
 generated.name = "GeneratedWaterEffects"
 add_child(generated)
 water_material = ShaderMaterial.new()
 water_material.shader = load("res://Materials/UpperCity/flowing_water.gdshader")
 fall_material = water_material.duplicate()
 fall_material.set_shader_parameter("waterfall", true)
 foam_material = ShaderMaterial.new()
 foam_material.shader = load("res://Materials/UpperCity/foam.gdshader")
 var curve: Curve3D = $RiverPath.curve
 var length := curve.get_baked_length()
 if length < 0.1:
  return
 var vertices := PackedVector3Array()
 var uvs := PackedVector2Array()
 var indices := PackedInt32Array()
 var count := maxi(2, ceili(length / 0.3))
 for i in range(count + 1):
  var distance := length * float(i) / count
  var center := curve.sample_baked(distance)
  var direction := curve.sample_baked(minf(length, distance + 0.1)) - curve.sample_baked(maxf(0, distance - 0.1))
  var normal := Vector3(-direction.z, 0, direction.x).normalized()
  vertices.append(center - normal * river_width * 0.5)
  vertices.append(center + normal * river_width * 0.5)
  uvs.append(Vector2(0, distance))
  uvs.append(Vector2(1, distance))
  if i < count:
   var a := i * 2
   indices.append_array(PackedInt32Array([a, a+1, a+3, a, a+3, a+2]))
 _mesh("FlowingRiver", vertices, uvs, indices, water_material)
 _mesh("Waterfall", PackedVector3Array([Vector3(-2,3.8,2),Vector3(2,3.8,2),Vector3(2,0,2.5),Vector3(-2,0,2.5)]), PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,3.8),Vector2(0,3.8)]), PackedInt32Array([0,1,2,0,2,3]), fall_material)
 _plane("LowerPool", Vector3(0,0,8), Vector2(12,12), water_material)
 _plane("FallImpactFoam", Vector3(0,0.08,3.3), Vector2(7,3), foam_material)
 _plane("WheelFoam", Vector3(-1.5,0.09,2.2), Vector2(3,4), foam_material)
 splash = _particles(false)
 mist = _particles(true)

func _mesh(title: String, vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, material: Material) -> void:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(vertices.size()):
  st.set_uv(uvs[i])
  st.add_vertex(vertices[i])
 for index in indices:
  st.add_index(index)
 st.generate_normals()
 var node := MeshInstance3D.new()
 node.name = title
 node.mesh = st.commit()
 node.material_override = material
 generated.add_child(node)

func _plane(title: String, pos: Vector3, size: Vector2, material: Material) -> void:
 var node := MeshInstance3D.new()
 node.name = title
 var plane := PlaneMesh.new()
 plane.size = size
 plane.subdivide_width = 20
 plane.subdivide_depth = 20
 node.mesh = plane
 node.material_override = material
 generated.add_child(node)
 node.position = pos

func _particles(is_mist: bool) -> CPUParticles3D:
 var p := CPUParticles3D.new()
 p.name = "Mist" if is_mist else "Splash"
 p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 p.amount = 40 if is_mist else 80
 p.lifetime = 2.5 if is_mist else 1.2
 p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
 p.emission_box_extents = Vector3(1.8,0.1,0.3)
 p.direction = Vector3.UP
 p.spread = 35
 p.initial_velocity_min = 0.2 if is_mist else 1.0
 p.initial_velocity_max = 0.7 if is_mist else 2.2
 p.gravity = Vector3(0,0.1,0) if is_mist else Vector3(0,-3,0)
 p.scale_amount_min = 0.3 if is_mist else 0.035
 p.scale_amount_max = 0.7 if is_mist else 0.09
 var quad := QuadMesh.new()
 quad.size = Vector2.ONE
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
 material.vertex_color_use_as_albedo = true
 material.albedo_color = Color(0.75,0.86,0.85,0.15 if is_mist else 0.7)
 var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
 for y in range(32):
  for x in range(32):
   var radius := (Vector2(x,y) - Vector2(15.5,15.5)).length() / 15.5
   var alpha := clampf(1.0 - radius,0.0,1.0)
   image.set_pixel(x,y,Color(1,1,1,alpha * alpha))
 material.albedo_texture = ImageTexture.create_from_image(image)
 quad.material = material
 p.mesh = quad
 var gradient := Gradient.new()
 gradient.set_color(0,Color(1,1,1,0.5))
 gradient.set_color(1,Color(1,1,1,0))
 p.color_ramp = gradient
 generated.add_child(p)
 p.position = Vector3(0,0.25,2.7)
 p.emitting = not Engine.is_editor_hint()
 return p

func _process(delta: float) -> void:
 if water_material:
  water_material.set_shader_parameter("flow_speed",flow_speed)
  fall_material.set_shader_parameter("flow_speed",flow_speed * 1.8)
  foam_material.set_shader_parameter("speed",flow_speed)
 if Engine.is_editor_hint():
  return
 if rotor:
  rotor.rotate_object_local(Vector3.FORWARD, delta * flow_speed / 2.4)
 if splash:
  splash.emitting = flow_speed > 0.01
  mist.emitting = flow_speed > 0.01
 if dragging and camera:
  var direction := Vector3.ZERO
  direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
  direction.z = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
  direction.y = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
  camera.position += camera.transform.basis * direction * delta * (24.0 if Input.is_key_pressed(KEY_SHIFT) else 10.0)

func _unhandled_input(event: InputEvent) -> void:
 if Engine.is_editor_hint():
  return
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
  dragging = event.pressed
 if event is InputEventMouseMotion and dragging:
  camera.rotation.y -= event.relative.x * 0.003
  camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003,-1.5,1.5)

func _make_controls() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 var panel := VBoxContainer.new()
 panel.position = Vector2(24,24)
 panel.custom_minimum_size = Vector2(460,80)
 layer.add_child(panel)
 var label := Label.new()
 label.text = "Upper city water study\nHold right mouse + WASD to fly; Q/E down/up. Shift speeds up.\nFlow speed (also drives the mill wheel)"
 panel.add_child(label)
 var slider := HSlider.new()
 slider.min_value = 0
 slider.max_value = 3
 slider.step = 0.05
 slider.value = flow_speed
 slider.value_changed.connect(func(value: float): flow_speed = value)
 panel.add_child(slider)
