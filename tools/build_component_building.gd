extends SceneTree
## A small, unmodified-component fit study. Individual pieces stay editable.
const LIBRARY := "res://Mesh/ComponentBuilding/"

func _initialize() -> void:
	var building := Node3D.new()
	building.name = "ComponentBuilding"
	building.set_meta("purpose", "Native component fit study; 12 pieces; open top for seam inspection")
	building.set_meta("source", "ComponentLibrary/foundation.blend")
	building.set_meta("materials", "Authored colors and procedural grain baked from Blender; matte PBR adaptation of Toon BSDF")
	building.set_meta("geometry_changes", "None. Library scale retained; translation and quarter-turn rotations only.")
	var specs: Array[Dictionary] = []
	# The corner pieces already contain both wall returns. Do not add walls on top.
	# Place their inner ends on the central bay edges; keep native trim differences.
	var ground_x := 12.3614311
	var ground_z := 6.22725296
	var upper_x := 12.4607301
	var upper_z := 6.48913097
	var upper_y := 6.60163498
	for floor_index in 2:
		var floor_node := Node3D.new()
		floor_node.name = "GroundFloor" if floor_index == 0 else "UpperFloor"
		building.add_child(floor_node)
		var corner := "plain_stone_corner_wall" if floor_index == 0 else "second_story_corner"
		var x := ground_x if floor_index == 0 else upper_x
		var z := ground_z if floor_index == 0 else upper_z
		var height := 0.0 if floor_index == 0 else upper_y
		for entry in [["FrontRight",x,z,0.0], ["BackRight",x,-z,PI/2], ["BackLeft",-x,-z,PI], ["FrontLeft",-x,z,-PI/2]]:
			# Rotating an L swaps its unequal extents. Correct the center of each
			# return so the inner ends meet on the side centerline.
			var at := Vector3(entry[1],height,entry[2])
			if entry[0] == "BackRight" or entry[0] == "FrontLeft":
				var bx := 6.18071556 if floor_index == 0 else 6.30422258
				var bz := 6.22725296 if floor_index == 0 else 6.48913097
				at.x += signf(at.x)*(bz-bx)
				at.z += signf(at.z)*(bx-bz)
			_add_piece(floor_node,entry[0]+"Corner",corner,at,entry[3],specs)
		# Match the facade plane of the L, rather than its outermost cornice.
		var facade_z := z + (5.75 if floor_index == 0 else 5.58)
		_add_piece(floor_node,"FrontDoor" if floor_index == 0 else "FrontWindow", "door_stone_wall" if floor_index == 0 else "second_story_window",Vector3(0,height,facade_z),0,specs)
		_add_piece(floor_node,"BackWindow" if floor_index == 0 else "BackWall", "windowed_stone_wall" if floor_index == 0 else "second_story_plain",Vector3(0,height,-facade_z),PI,specs)
	_save(building,"res://Modules/Buildings/ComponentBuilding.tscn")
	var file := FileAccess.open("res://art/ComponentBuilding/assembly.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"description":"12 native library pieces, no added building geometry", "pieces":specs},"\t"))
	building.free()
	_build_inspection()
	print("COMPONENT_BUILDING_SAVED / 12 original library components")
	quit()

func _add_piece(parent: Node3D, title: String, slug: String, at: Vector3, yaw: float, specs: Array[Dictionary]) -> void:
	var piece: Node3D = load(LIBRARY+slug+".glb").instantiate()
	piece.name = title
	piece.position = at
	piece.rotation.y = yaw
	piece.set_meta("library_component",slug)
	parent.add_child(piece)
	specs.append({"name":str(parent.name)+"/"+title,"component":slug,"position":[at.x,at.y,at.z],"yaw":yaw})

func _build_inspection() -> void:
	var scene := Node3D.new()
	scene.name = "ComponentBuildingInspection"
	scene.set_script(preload("res://scripts/component_building_inspection.gd"))
	var building: Node3D = load("res://Modules/Buildings/ComponentBuilding.tscn").instantiate()
	building.name = "Building"
	scene.add_child(building)
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("333e48")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d1d8df")
	env.environment.ambient_light_energy = 0.6
	scene.add_child(env)
	var key := DirectionalLight3D.new()
	key.name = "InspectionLight"
	key.rotation_degrees = Vector3(-48,-30,0)
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 100
	scene.add_child(key)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "InspectionGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(90,80)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.05
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("414e58")
	ground.roughness = 1
	floor_mesh.material_override = ground
	scene.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.name = "InspectionCamera"
	camera.position = Vector3(42,29,48)
	camera.basis = Basis.looking_at(Vector3(0,6,0)-camera.position)
	camera.near = 0.05
	camera.far = 250
	camera.fov = 48
	camera.current = true
	scene.add_child(camera)
	_save(scene,"res://Levels/ComponentBuildingInspection.tscn")
	scene.free()

func _save(node: Node, path: String) -> void:
	_own(node,node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,path) == OK)

func _own(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = scene_root
		_own(child,scene_root)
