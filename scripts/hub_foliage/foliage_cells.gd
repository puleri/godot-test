extends Node3D
## Place this node at the same origin as the metre-scale city export.
## Cells use deterministic staggered thresholds and hysteresis for Compatibility.
@export var ground_distance: float = 35.0
@export var shrub_distance: float = 90.0
@export var tree_distance: float = 250.0
@export var update_interval: float = 0.15
var cells: Array[Dictionary] = []
var elapsed: float = 0.0
var instance_count: int = 0

func _ready() -> void:
	build_cells()

func build_cells() -> void:
	var mesh_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/HubFoliage/meshes.json"))
	var placements: Array = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/HubFoliage/placements.json"))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	var meshes: Dictionary = {}
	for asset: String in mesh_data:
		var levels: Array[ArrayMesh] = []
		for level: Dictionary in mesh_data[asset]:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			for i in range(0, level.vertices.size(), 3):
				verts.append(Vector3(level.vertices[i], level.vertices[i+1], level.vertices[i+2]))
				normals.append(Vector3(level.normals[i], level.normals[i+1], level.normals[i+2]))
			for i in range(0, level.colors.size(), 4):
				colors.append(Color(level.colors[i], level.colors[i+1], level.colors[i+2], level.colors[i+3]))
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = colors
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, material)
			levels.append(mesh)
		meshes[asset] = levels
	var groups: Dictionary = {}
	for placement: Dictionary in placements:
		var key := "%s:%s:%s" % [placement.asset, placement.cell[0], placement.cell[1]]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(placement)
	for key: String in groups:
		var group: Array = groups[key]
		var first: Dictionary = group[0]
		var size: float = first.cell_size
		var center := Vector3((first.cell[0] + 0.5)*size, 0, -(first.cell[1]+0.5)*size)
		var nodes: Array[MultiMeshInstance3D] = []
		var bounds := AABB()
		var initial := true
		for lod: int in range(meshes[first.asset].size()):
			var mesh: ArrayMesh = meshes[first.asset][lod]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = group.size()
			for i: int in range(group.size()):
				var p: Dictionary = group[i]
				var basis := Basis(Vector3.UP, float(p.yaw)).scaled(Vector3.ONE*float(p.scale))
				var pos := Vector3(p.position[0],p.position[1],p.position[2])-center
				var transform := Transform3D(basis,pos)
				mm.set_instance_transform(i, transform)
				var box: AABB = transform * mesh.get_aabb()
				bounds = box if initial else bounds.merge(box)
				initial = false
			var node := MultiMeshInstance3D.new()
			node.name = "%s_LOD%d" % [key.replace(":","_"),lod]
			node.multimesh = mm
			node.position = center
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if first.kind == "ground" or lod > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			node.visible = false
			add_child(node)
			nodes.append(node)
		# Include full mesh dimensions plus allowance for future wind deformation.
		for node in nodes:
			node.multimesh.custom_aabb = bounds.grow(0.5)
		var jitter := float(abs(key.hash()) % 1000)/1000.0*5.0
		cells.append({"nodes":nodes,"center":center+bounds.get_center(),"radius":bounds.size.length()*0.5,"kind":first.kind,"jitter":jitter,"lod":-2})
		instance_count += group.size()
	print("Foliage cells: ",cells.size(),"; plants: ",instance_count)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < update_interval:
		return
	elapsed = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera:
		update_visibility(camera.global_position)

func update_visibility(camera_position: Vector3) -> void:
	for cell in cells:
		var distance: float = maxf(0.0, camera_position.distance_to(to_global(cell.center))-cell.radius)
		var limit: float = ground_distance if cell.kind == "ground" else shrub_distance if cell.kind == "shrub" else tree_distance
		limit += cell.jitter
		var old: int = cell.lod
		var thresholds: Array = [18.0,limit] if cell.kind == "ground" else [45.0,limit] if cell.kind == "shrub" else [65.0,140.0,limit]
		var lod: int = thresholds.size()
		for i in range(thresholds.size()):
			var threshold: float = thresholds[i]
			# Hysteresis prevents flicker when the camera hovers near a boundary.
			if old >= 0:
				threshold += 2.0 if old <= i else -2.0
			if distance < threshold:
				lod = i
				break
		if lod == thresholds.size():
			lod = -1
		if lod != old:
			for i in range(cell.nodes.size()):
				cell.nodes[i].visible = i == lod
			cell.lod = lod
