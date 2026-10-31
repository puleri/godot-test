@tool
extends Node3D
## Decorative, collision-free harbor. Shared meshes are batched into a handful of draws.

var _batches: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 7361
	var stone := _material(Color("111b2c"))
	var far_stone := _material(Color("202f47"))
	var roof := _material(Color("0b1220"))
	var wood := _material(Color("1c202a"))
	var window := _material(Color("b58a4c"))
	var box := BoxMesh.new()
	var prism := PrismMesh.new()
	for side in [-1, 1]:
		for i in 16:
			var x := float(side) * (35.0 + i * 7.5)
			var z := -46.0 - float(i) * 3.5 + _rng.randf_range(-5, 5)
			var height := _rng.randf_range(5, 13)
			var width := _rng.randf_range(5, 9)
			_piece("Buildings", box, stone, Vector3(x, height/2.0-2, z), Vector3(width,height,8))
			_piece("Roofs", prism, roof, Vector3(x,height-0.5,z),Vector3(width+1,3,9))
			_piece("Buildings", box, stone, Vector3(x+width*0.25,height+1,z),Vector3(1,4,1))
			_piece("Quays", box, wood, Vector3(x,-1.8,z+6),Vector3(width+1,1,5))
			_piece("Quays", box, wood, Vector3(x,height-2,z+4.2),Vector3(width+0.6,0.3,0.4))
			_piece("Doors", box, roof, Vector3(x,-0.5,z+4.03),Vector3(1.3,3,0.08))
			for edge in [-1,1]:
				_piece("Quays",box,wood,Vector3(x+edge*width*0.46,height/2.0-2,z+4.1),Vector3(0.25,height,0.25))
			for w in 3:
				if _rng.randf() > 0.35:
					_piece("Windows",box,window,Vector3(x-width*0.3+w*width*0.3,height*0.55-2,z+4.02),Vector3(0.45,0.8,0.06))
	# A substantial quay anchors the encounter to the waterfront rather than a
	# floating tile board. Decorative geometry stays outside its collision floor.
	_piece("Foundations",box,stone,Vector3(0,-4,-3),Vector3(36,4,42))
	_piece("Foundations",box,stone,Vector3(0,-4,-35),Vector3(70,4,24))
	for side in [-1,1]:
		for i in 5:
			var x := float(side)*25.0
			var z := -12.0-i*8.0
			var height := _rng.randf_range(6,11)
			_piece("Buildings",box,stone,Vector3(x,height/2.0-1.5,z),Vector3(7,height,7))
			_piece("Roofs",prism,roof,Vector3(x,height,z),Vector3(8,3,8))
			_piece("Windows",box,window,Vector3(x,height*0.6,z+3.55),Vector3(0.6,1,0.08))
			_piece("Doors",box,roof,Vector3(x,0,z+3.56),Vector3(1.4,3,0.08))
			_piece("Quays",box,wood,Vector3(x,height-1.5,z+3.65),Vector3(7.6,0.35,0.4))
			for edge in [-1,1]:
				_piece("Quays",box,wood,Vector3(x+edge*3.3,height/2.0-1.5,z+3.6),Vector3(0.3,height,0.3))
			_piece("Quays",box,wood,Vector3(x,-1.7,z+5),Vector3(11,0.6,3))
			for post in [-1,1]:
				_piece("Quays",box,wood,Vector3(x+post*4.7,-1.2,z+6),Vector3(0.35,3,0.35))
	# Distant coast: broad, low silhouettes and one readable lighthouse landmark.
	for i in 14:
		var x := -210.0 + i * 32.0
		var height := _rng.randf_range(3,10)
		_piece("Islands",prism,far_stone,Vector3(x,height*0.5-3,-210-_rng.randf_range(0,35)),Vector3(40,height,25))
	_piece("Islands",prism,far_stone,Vector3(48,1,-170),Vector3(48,10,28))
	_piece("Buildings",box,far_stone,Vector3(48,13,-170),Vector3(4,20,4))
	_piece("Roofs",prism,roof,Vector3(48,24,-170),Vector3(6,3,6))
	_piece("Windows",box,window,Vector3(48,22,-167.9),Vector3(2,1.8,0.1))
	for key in _batches:
		var spec: Dictionary = _batches[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = spec.mesh
		multi.instance_count = spec.transforms.size()
		for i in multi.instance_count:
			multi.set_instance_transform(i,spec.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = key
		node.layers = 2
		node.multimesh = multi
		node.material_override = spec.material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	var water := MeshInstance3D.new()
	water.name = "OuterHarborWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200,1200)
	water.layers = 2
	water.mesh = plane
	water.position.y = -2.05
	var material := ShaderMaterial.new()
	material.shader = preload("res://Materials/harbor_water.gdshader")
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_batches.clear()

func _piece(key: String, mesh: Mesh, material: Material, at: Vector3, dimensions: Vector3) -> void:
	if not _batches.has(key):
		_batches[key] = {"mesh":mesh,"material":material,"transforms":[]}
	_batches[key].transforms.append(Transform3D(Basis.IDENTITY.scaled(dimensions),at))

func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	return material
