extends "res://scripts/midnight_exchange_builder.gd"
## Saved city construction. Repeated artwork is batched separately in each district.
const WIDTH := 160.0
const DEPTH := 136.0
const DISTRICT_TITLES := ["SALT QUAY", "LANTERN LANDING", "BRASS MARKET", "OLD FOUNDRY", "NINE BELLS", "SILK WARD", "WEST WATCH", "CROWN COURT", "MOON ARCHIVE"]
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _assets: Dictionary = {}
var _box_mesh := BoxMesh.new()
var _roof_mesh := PrismMesh.new()
var _rng := RandomNumberGenerator.new()
var _guard_index := 0

func build_city() -> Node3D:
	_rng.seed = 20816
	var level := Node3D.new()
	level.name = "NocturneCity"
	level.set_script(preload("res://scripts/night_city.gd"))
	level.set_meta("footprint", Vector2(WIDTH,DEPTH))
	level.set_meta("midnight_exchange_area_multiplier",20.0)
	level.set_meta("walkable_heights",PackedFloat32Array([0,3,6]))
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	nav.agent_height = 1.5
	nav.agent_radius = 0.5
	nav.agent_max_climb = 0.25
	nav.agent_max_slope = 46
	nav.region_min_size = 0
	nav.region_merge_size = 0
	region.navigation_mesh = nav
	level.add_child(region)
	var districts = kit.group(level,"Districts")
	kit.group(level,"Routes")
	kit.group(level,"Guards")
	kit.group(level,"Bells")
	var index := 0
	for z in [48,0,-48]:
		for x in [-56,0,56]:
			var district = kit.group(region,"District_%02d" % index)
			district.position = Vector3(x,0,z)
			var marker := Marker3D.new()
			marker.name = "District_%02d" % index
			marker.position = district.position
			marker.set_meta("title",DISTRICT_TITLES[index])
			districts.add_child(marker)
			_build_district(district,index)
			_add_patrol(level,"%s / QUAY WATCH" % DISTRICT_TITLES[index], [Vector3(x-20,0,z-17),Vector3(x+18,0,z-17),Vector3(x+18,0,z+17),Vector3(x-20,0,z+17)], index % 3 == 0)
			if index in [0,3,4,5,7,8]:
				_add_patrol(level,"%s / ROOF WATCH" % DISTRICT_TITLES[index], [Vector3(x-12,6,z-12),Vector3(x+12,6,z-12),Vector3(x+12,6,z-8),Vector3(x-12,6,z-8)],false)
			var bell = kit.group(level.get_node("Bells"),"Bell_%02d" % index)
			bell.position = Vector3(x-2,0,z+4)
			var visual := BELL.instantiate()
			visual.name = "Visual"
			bell.add_child(visual)
			var caption := Label3D.new()
			caption.name = "Caption"
			caption.position.y = 2.1
			caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			caption.font_size = 28
			caption.pixel_size = 0.007
			caption.modulate = Color("e4bc77")
			caption.visible = false
			bell.add_child(caption)
			index += 1
	var crossings = kit.group(region,"CanalCrossings")
	for z in [-48,0,48]:
		for x in [-28,28]:
			_add_bridge(crossings,Vector3(x-6,0,z),-PI/2)
	for x in [-56,0,56]:
		for z in [-24,24]:
			_add_bridge(crossings,Vector3(x,0,z+6),0)
	# Upper city links cross the water independently of the street bridges.
	for x in [-28,28]:
		_add_bridge(crossings,Vector3(x-6,6,-58),-PI/2)
		for side in [-1,1]:
			_platform(crossings,Vector3(x+side*12,6,-58),Vector3(12,0.4,4),Color("4b5966"))
	var stations = kit.group(level,"Stations")
	for spec in [["SaltSeal","SALT QUAY",Vector3(-56,0,48)], ["FoundrySeal","FOUNDRY ROOF",Vector3(-68,6,-13)], ["BellSeal","CROWN COURT",Vector3(0,0,-48)], ["ArchiveSeal","ARCHIVE ROOF",Vector3(68,6,-61)], ["SilkSeal","SILK WARD",Vector3(56,0,0)]]:
		var station = _station(stations,"NightSeal",spec[1],spec[2],2.0)
		station.name = spec[0]
	_environment_city(level)
	_player(level)
	var player := level.get_node("Player")
	player.set_script(preload("res://scripts/night_city_player.gd"))
	player.position = Vector3(0,0.49,64)
	player.side_plane_z = 64
	player.overview_camera_path = NodePath("../LevelCamera")
	player.collision_layer = 4
	player.collision_mask = 1
	player.floor_snap_length = 0.35
	player.max_walk_speed = MOVEMENT.ROOK_MOVE_SPEED
	player.jump_velocity = 7.0
	player.follow_size = 19.5
	player.floor_max_angle = deg_to_rad(48)
	level.get_node("LevelCamera").size = 19.5
	var sensor := Node3D.new()
	sensor.name = "ExposureSensor"
	sensor.set_script(preload("res://scripts/stealth_exposure_sensor.gd"))
	player.add_child(sensor)
	_exit(level)
	level.get_node("Extraction").position = Vector3(0,0,64)
	_flush_batches()
	_own_additions(level,level)
	return level

func _build_district(parent: Node3D, index: int) -> void:
	# A real 8m water gap separates neighboring stone islands.
	var floor_group = kit.group(parent,"Quays")
	kit.box(floor_group,Vector3(48,3,40),Vector3(0,-1.5,0))
	_asset(floor_group,"foundation",Vector3(0,-3,0),Vector3(48,2.8,40))
	# Original harbor floor mesh, 480 shared instances per district, one batch.
	for x in range(-23,24,2):
		for z in range(-19,20,2):
			_stamp(floor_group,KIT.TILE,Vector3(x,0,z),Vector3(2,0.32,2),true)
	var buildings = kit.group(parent,"Buildings")
	for x in [-10,10]:
		for z in [-10,10]:
			_building(buildings,Vector3(x,0,z),index + (1 if x>0 else 0), z>0)
	var upper = kit.group(parent,"UpperRoutes")
	# Two flights: 0 → 3 → 6. The connector's ramp collision is retained.
	for flight in 2:
		var stairs := load("res://Modules/Connectors/Staircase.tscn").instantiate() as Node3D
		stairs.name = "Stairs_%d" % flight
		stairs.position = Vector3(21,flight*3,18-flight*8)
		stairs.scale = Vector3(0.7,1.5,1)
		upper.add_child(stairs)
		# Open the left balustrade at the +3m landing onto its balcony.
		for piece in stairs.get_node("Geometry").get_children():
			if piece.position.x < -2.9 and ((flight == 0 and piece.position.z < -6) or (flight == 1 and piece.position.z > -2)):
				piece.free()
		_flatten_visuals(stairs,upper)
	_platform(upper,Vector3(21,6,-6),Vector3(4.2,0.4,16),Color("48586a"))
	_platform(upper,Vector3(18,6,-10),Vector3(6,0.4,4),Color("48586a"))
	_add_bridge(upper,Vector3(-6,6,-10),-PI/2)
	_add_bridge(upper,Vector3(-6,6,10),-PI/2)
	# Connect the two northern/southern roof rows along their east side.
	_add_bridge(upper,Vector3(10,6,6),0)
	# A broken western crossing has an optional 1.8m jump over open air.
	_platform(upper,Vector3(-10,6,-3.45),Vector3(3.6,0.35,5.1),Color("6c5644"))
	_platform(upper,Vector3(-10,6,3.45),Vector3(3.6,0.35,5.1),Color("6c5644"))
	upper.set_meta("jump_gap_metres",1.8)
	for z in [-10,10]:
		_asset(upper,"broken_arch_wall",Vector3(0,6,z),Vector3(8,3.3,0.6))
	# Low canal rails leave the four bridge mouths open.
	for z in [-20,20]:
		for x in [-14,14]:
			_rail(parent,Vector3(x,0,z),Vector3.RIGHT,20)
	for x in [-24,24]:
		for z in [-12,12]:
			_rail(parent,Vector3(x,0,z),Vector3.FORWARD,16)
	var props = kit.group(parent,"StreetLife")
	for data in [[-6,6], [6,-5],[-18,-8],[17,8],[-3,-14],[3,14]]:
		var at := Vector3(data[0],0,data[1])
		_stamp(props,BARREL,at,Vector3(0.9,1.25,0.9))
		kit.box(props,Vector3(0.85,1.25,0.85),at+Vector3.UP*0.625)
		_stamp(props,GRASS,at+Vector3(0.8,0,0.3),Vector3(0.5,0.45,0.5))
	# Market stalls, cloth canopies and cargo stacks give each square a use.
	for side in [-1,1]:
		var at := Vector3(side*7,0,3)
		_cube(props,at+Vector3(0,0.75,0),Vector3(3,1.5,1.2),Color("584531"))
		kit.box(props,Vector3(3,1.5,1.2),at+Vector3.UP*0.75)
		_cube(props,at+Vector3(0,2.6,0),Vector3(3.5,0.18,2.2),[Color("5b536d"),Color("476b68"),Color("885f4c")][index%3])
		for edge in [-1,1]:
			_cube(props,at+Vector3(edge*1.5,1.3,0.7),Vector3(0.12,2.6,0.12),Color("42392e"))
		for item in 5:
			_cube(props,at+Vector3(-1+item*0.45,1.65,0),Vector3(0.3,0.3,0.5),Color("aa925a"))
	# Physical cover beside the central road; generous paths around both ends.
	_cover_wall(props,"SquareScreen",Vector3(-5,0,-3),4)
	for at in [Vector3(-20,0,7),Vector3(4,0,-17),Vector3(3,0,16)]:
		_lantern(parent,at)
	_sign(parent,DISTRICT_TITLES[index],Vector3(0,3.4,16),Color("c6b18d"))
	_district_identity(parent,index)

func _district_identity(parent: Node3D, index: int) -> void:
	var details = kit.group(parent,"DistrictLandmarks")
	# Retaining stones and native corner blocks keep the quay edges substantial.
	for side in [-1,1]:
		_asset(details,"retaining_wall",Vector3(0,-2.9,side*19.7),Vector3(44,2.4,0.6))
		for x in [-22,22]:
			_asset(details,"foundation_corner",Vector3(x,-2.9,side*18),Vector3(4,2.6,4))
	# High pennants and washing lines introduce silhouettes across the lanes.
	for z in [-4,5]:
		_cube(details,Vector3(0,4.8,z),Vector3(12,0.045,0.045),Color("3d3b38"))
		for flag in 7:
			var palette := [Color("957057"),Color("486d70"),Color("796080")]
			_cube(details,Vector3(-4.5+flag*1.5,4.35,z),Vector3(0.7,0.85,0.035),palette[(flag+index)%3])
	match index:
		0: # Salt quay: stacked freight and mooring timbers on the water side.
			for x in [-18,-15,15,18]:
				for y in 2:
					_cube(details,Vector3(x,0.6+y*1.2,18.6),Vector3(2,1.2,1.5),Color("5f503e"))
				kit.box(details,Vector3(2,2.4,1.5),Vector3(x,1.2,18.6))
			for z in [-14,-7,7,14]:
				_cube(details,Vector3(-24,-0.4,z),Vector3(0.65,5.5,0.65),Color("493d31"))
		1: # Arrival: two monumental arches frame the first avenue.
			for z in [-15]:
				_asset(details,"broken_arch_wall",Vector3(0,0,z),Vector3(7,5.5,0.7))
				for side in [-1,1]:
					kit.box(details,Vector3(0.65,4.2,0.7),Vector3(side*3.2,2.1,z))
		2: # Brass market: a second row of copper-colored awnings.
			for x in [-12,12]:
				_cube(details,Vector3(x,3.5,-3.8),Vector3(6,0.2,3),Color("92644c"))
				for offset in [-2.7,2.7]:
					_cube(details,Vector3(x+offset,1.7,-2.6),Vector3(0.12,3.4,0.12),Color("473c30"))
		3: # Foundry: sawtooth roof vents and tall brick flues.
			for x in [-13,-7,7,13]:
				_cube(details,Vector3(x,9,11),Vector3(1.1,6,1.2),Color("424958"))
				_cube(details,Vector3(x,12.1,11),Vector3(1.5,0.35,1.6),Color("273341"))
		4: # Nine Bells: raised garden beds and stone civic benches.
			for x in [-3,3]:
				_cube(details,Vector3(x,0.4,-14),Vector3(2,0.8,3),Color("52606c"))
				kit.box(details,Vector3(2,0.8,3),Vector3(x,0.4,-14))
				for z in [-15,-14,-13]:
					_stamp(details,GRASS,Vector3(x,0.8,z),Vector3(1.3,1.1,1.3))
		5: # Silk ward: long colored drapes on the southern house fronts.
			for x in [-13,-7,7,13]:
				_cube(details,Vector3(x,3.8,14.45),Vector3(1.25,3.3,0.08),Color("69547b"))
				_cube(details,Vector3(x,2.1,14.45),Vector3(1.35,0.18,0.12),Color("c3a16d"))
		6: # West Watch: a fortified turret above the southern roofs.
			_asset(details,"plain_stone_corner_wall",Vector3(-10,6,10),Vector3(7,4,7))
			_asset(details,"second_story_corner",Vector3(-10,10,10),Vector3(7,4,7))
			kit.box(details,Vector3(7,8,7),Vector3(-10,10,10))
			_piece(details,_roof_mesh,Vector3(-10,15,10),Vector3(9,3,9),_material("turret_roof",Color("283a50")))
		7: # Crown Court: a broad civic arcade and warm ceremonial windows.
			for x in [-9,9]:
				_asset(details,"broken_arch_wall",Vector3(x,0,18.5),Vector3(10,4.2,0.7))
			for x in [-14,-4,4,14]:
				kit.box(details,Vector3(0.7,3,0.7),Vector3(x,1.5,18.5))
		8: # Moon Archive: a roof observatory with a tall slate crown.
			_asset(details,"second_story_corner",Vector3(10,6,10),Vector3(6,4,6))
			kit.box(details,Vector3(6,4,6),Vector3(10,8,10))
			_piece(details,_roof_mesh,Vector3(10,11,10),Vector3(8,3.5,8),_material("archive_roof",Color("374359")))
			_cube(details,Vector3(10,8,13.2),Vector3(1.4,1.8,0.1),Color("90beca"),true)

func _building(parent: Node3D, at: Vector3, variant: int, south: bool) -> void:
	var body = kit.group(parent,"House_%02d" % parent.get_child_count())
	body.position = at
	var width := 12.0
	var height := 6.0
	kit.box(body,Vector3(width,height,8),Vector3(0,height/2,0))
	for side in [-1,1]:
		_asset(body,"door_stone_wall" if side>0 else "windowed_stone_wall",Vector3(0,0,side*4),Vector3(width,3,0.7),0 if side>0 else PI)
		_asset(body,"second_story_window",Vector3(0,3,side*4),Vector3(width,3,0.7),0 if side>0 else PI)
		_asset(body,"plain_stone_wall",Vector3(side*6,0,0),Vector3(8,3,0.65),PI/2)
		_asset(body,"second_story_plain",Vector3(side*6,3,0),Vector3(8,3,0.65),PI/2)
		# Separate warm glass accents read clearly in the wider camera.
		for window in [-3,0,3]:
			_cube(body,Vector3(window,4.4,side*4.37),Vector3(0.75,1.05,0.06),Color("d5a15c"),true)
	_platform(body,Vector3(0,6,0),Vector3(12.5,0.28,8.5),Color("455363"))
	# A recessed central roof volume leaves a ring for patrols and traversal.
	if variant%3 != 0:
		_cube(body,Vector3(-1,7,0),Vector3(5,2,2),Color("26313f"))
		kit.box(body,Vector3(5,2,2),Vector3(-1,7,0))
		_piece(body,_roof_mesh,Vector3(-1,8.4,0),Vector3(6,1.5,4),_material("slate",Color("263544")))
	_cube(body,Vector3(3,7.1,-1.8),Vector3(0.7,2.3,0.8),Color("38404a"))
	# Balconies at +3m are reached from the half-height stair landing.
	if south:
		_platform(body,Vector3(9,3,-1),Vector3(5,0.3,4),Color("5b584c"))
	# Use the newly authored corner pieces as small corner turrets at skyline ends.
	if variant%3 == 0 and not south:
		_asset(body,"plain_stone_corner_wall",Vector3(-3,6,-1),Vector3(4,2,4))
		_asset(body,"second_story_corner",Vector3(-3,8,-1),Vector3(4,2,4))

func _add_bridge(parent: Node3D, at: Vector3, yaw: float) -> void:
	var bridge := load("res://Modules/Connectors/Bridge.tscn").instantiate() as Node3D
	bridge.name = "Bridge_%02d" % parent.get_child_count()
	bridge.position = at
	bridge.rotation.y = yaw
	parent.add_child(bridge)
	_flatten_visuals(bridge,parent)

func _platform(parent: Node3D, at: Vector3, size: Vector3, tint: Color) -> void:
	_cube(parent,at-Vector3.UP*size.y*0.5,size,tint)
	kit.box(parent,size,at-Vector3.UP*size.y*0.5)

func _rail(parent: Node3D, at: Vector3, along: Vector3, length: float) -> void:
	var rail = kit.visual(parent,KIT.RAIL,at,Vector3(length,0.85,0.28))
	rail.rotation.y = atan2(-along.z,along.x)
	kit.box(rail,Vector3(length,0.85,0.28),Vector3(0,0.425,0))
	_flatten_visuals(rail,parent)

func _lantern(parent: Node3D, at: Vector3) -> void:
	_cube(parent,at+Vector3.UP*2,Vector3(0.14,4,0.14),Color("2b3540"))
	_cube(parent,at+Vector3.UP*3.9,Vector3(0.5,0.7,0.5),Color("edb96d"),true)
	_cube(parent,at+Vector3.UP*4.35,Vector3(0.7,0.16,0.7),Color("2b3540"))
	var lamp := OmniLight3D.new()
	lamp.name = "WatchLantern_%d" % parent.get_child_count()
	lamp.position = at+Vector3.UP*3.65
	lamp.light_color = Color("ffc17c")
	lamp.light_energy = 3.2
	lamp.omni_range = 8.5
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = true
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 30
	lamp.distance_fade_length = 12
	lamp.add_to_group("stealth_lights",true)
	parent.add_child(lamp)

func _add_patrol(level: Node3D, title: String, points: Array, hound: bool) -> void:
	var id := "Watch_%02d" % _guard_index
	var route = kit.group(level.get_node("Routes"),id)
	for at in points:
		var marker := Marker3D.new()
		marker.position = at
		route.add_child(marker)
	var guard: CharacterBody3D = (HOUND if hound else MOUSE).instantiate()
	guard.set_script(preload("res://scripts/night_city_guard.gd"))
	guard.name = id
	guard.guard_title = title
	guard.visual_forward_yaw_offset = PI/2
	guard.position = points[0]
	guard.player_path = NodePath("../../Player")
	guard.route_path = NodePath("../../Routes/"+id)
	guard.walk_speed = 1.7 if hound else 1.85
	guard.locomotion_uses_run = not hound
	guard.run_speed = MOVEMENT.HOUND_PURSUIT_SPEED if hound else 3.7
	guard.acceleration = 8
	guard.braking = 10
	guard.sight_range = 12 if hound else 10
	guard.field_of_view_degrees = 100 if hound else 110
	guard.eye_height = 0.75 if hound else 0.32
	guard.lamp_height_offset = 0.55 if hound else 0.48
	guard.lamp_range = 9 if hound else 7
	guard.lamp_fov_degrees = 45
	guard.lamp_downward_angle_degrees = 12
	guard.seconds_to_detect = 1.2
	guard.capture_distance = 0.8
	guard.hearing_range = 16
	guard.pause_min_seconds = 1.4
	guard.pause_max_seconds = 2.4
	guard.show_vision = false
	guard.random_seed = 7200 + _guard_index
	guard.floor_snap_length = 0.4
	level.get_node("Guards").add_child(guard)
	var beam := SpotLight3D.new()
	beam.name = "SightLight"
	beam.light_energy = 8
	beam.shadow_enabled = true
	beam.shadow_bias = 0.03
	beam.spot_attenuation = 0
	beam.spot_angle_attenuation = 0.35
	beam.add_to_group("stealth_lights",true)
	guard.add_child(beam)
	_guard_index += 1

func _environment_city(level: Node3D) -> void:
	_environment(level)
	level.get_node("HarborLights").free()
	level.get_node("NightFill").free()
	var world: WorldEnvironment = level.get_node("WorldEnvironment")
	var env := world.environment
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://Materials/harbor_sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7a91bb")
	env.ambient_light_energy = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_light_color = Color("15243b")
	env.fog_light_energy = 0.4
	env.fog_density = 0.002
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-48,-30,0)
	moon.light_color = Color("9baed5")
	moon.light_energy = 0.48
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 65
	level.add_child(moon)
	var storm = level.get_node("StormFlashLight")
	storm.directional_shadow_max_distance = 110
	storm.add_to_group("stealth_lights",true)
	var water: MeshInstance3D = level.get_node("HarborWater")
	water.mesh = PlaneMesh.new()
	water.mesh.size = Vector2(1400,1400)
	water.position = Vector3(0,-3.5,0)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Materials/harbor_water.gdshader")
	water.material_override = mat
	var backdrop = kit.group(level,"DistantCity")
	for i in 46:
		var x := -190 + i*8.5
		var h := _rng.randf_range(9,24)
		_cube(backdrop,Vector3(x,h/2-2,-100-_rng.randf_range(0,24)),Vector3(_rng.randf_range(6,10),h,9),Color("1b293c"))
		_piece(backdrop,_roof_mesh,Vector3(x,h-1,-105),Vector3(9,4,11),_material("far_roof",Color("121e30")))
		for w in 3:
			_cube(backdrop,Vector3(x-2+w*2,h*0.5,-95.4),Vector3(0.45,0.9,0.08),Color("89704d"),true)
	# Tall, legible bell tower anchors the northern court.
	for y in [0,6,12]:
		_asset(backdrop,"plain_stone_corner_wall",Vector3(0,y,-75),Vector3(9,6,9))
		_asset(backdrop,"second_story_corner",Vector3(0,y+6,-75),Vector3(9,6,9))
	_piece(backdrop,_roof_mesh,Vector3(0,25,-75),Vector3(12,7,12),_material("tower_roof",Color("263448")))
	_cube(backdrop,Vector3(0,19.5,-70.4),Vector3(2,2.5,0.1),Color("e2b76d"),true)
	level.get_node("LevelCamera").far = 500

func _asset(parent: Node3D, slug: String, at: Vector3, size: Vector3, yaw := 0.0) -> void:
	if not _assets.has(slug):
		_assets[slug] = load("res://Mesh/NightCity/%s.glb" % slug)
	_stamp(parent,_assets[slug],at,size,false,yaw)

func _stamp(parent: Node3D, asset: PackedScene, at: Vector3, size: Vector3, top := false, yaw := 0.0) -> void:
	var node = kit.visual(parent,asset,at,size,top)
	node.rotation.y = yaw
	_flatten_visuals(node,parent)
	node.free()

func _flatten_visuals(node: Node3D, batch_parent: Node3D) -> void:
	var meshes: Array[Node] = node.find_children("*","MeshInstance3D",true,false)
	for visual: MeshInstance3D in meshes:
		var transform := _relative_transform(visual,batch_parent)
		var key := str(visual.mesh.get_instance_id())
		if not _mesh_cache.has(key):
			var copy := visual.mesh.duplicate() as Mesh
			for surface in copy.get_surface_count():
				var original: Material = visual.get_active_material(surface)
				var label := original.resource_name.to_lower() if original != null else "stone"
				var tint := Color("52616d")
				var glow := false
				if "wood" in label:
					tint = Color("574536")
				elif "wall-loop" in label:
					tint = Color("27303b")
				elif "material" in label:
					tint = Color("d9a05b")
					glow = true
				elif "stone_wall" in label or "second level" in label:
					tint = Color("3d4c5b")
				copy.surface_set_material(surface,_material(label,tint,glow))
			_mesh_cache[key] = copy
		_piece(batch_parent,_mesh_cache[key],transform.origin,Vector3.ONE,null,transform.basis)
		visual.free()

func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var current := node.get_parent()
	while current != ancestor:
		if current is Node3D:
			result = current.transform * result
		current = current.get_parent()
	return result

func _cube(parent: Node3D, at: Vector3, dimensions: Vector3, tint: Color, glow := false) -> void:
	_piece(parent,_box_mesh,at,dimensions,_material(str(tint),tint,glow))

func _material(key: String, tint: Color, glow := false) -> Material:
	if _materials.has(key):
		return _materials[key]
	var material: Material
	if glow:
		material = _glow(tint)
	else:
		var shader := ShaderMaterial.new()
		shader.shader = preload("res://Materials/night_city.gdshader")
		shader.set_shader_parameter("tint",tint)
		material = shader
	_materials[key] = material
	return material

func _piece(parent: Node3D, mesh: Mesh, at: Vector3, dimensions: Vector3, material: Material, basis := Basis.IDENTITY) -> void:
	var key := "%d/%d/%d" % [parent.get_instance_id(),mesh.get_instance_id(),material.get_instance_id() if material else 0]
	if not _batches.has(key):
		_batches[key] = {"parent":parent,"mesh":mesh,"material":material,"transforms":[]}
	_batches[key].transforms.append(Transform3D(basis.scaled(dimensions),at))

func _flush_batches() -> void:
	for spec in _batches.values():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = spec.mesh
		multi.instance_count = spec.transforms.size()
		for i in multi.instance_count:
			multi.set_instance_transform(i,spec.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = "ArtBatch_%03d" % spec.parent.get_child_count()
		node.multimesh = multi
		node.material_override = spec.material
		if spec.material is StandardMaterial3D and spec.material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spec.parent.add_child(node)
	_batches.clear()
