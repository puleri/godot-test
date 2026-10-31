extends SceneTree
## Save a reusable GLB exterior with the project palette and simplified collision.

const MODEL_PATH := "res://Mesh/StoneWarehouse/stone_warehouse.glb"
const SCENE_PATH := "res://Modules/Buildings/StoneWarehouse.tscn"


func _initialize() -> void:
	var warehouse := Node3D.new()
	warehouse.name = "StoneWarehouse"
	warehouse.set_meta("description", "Two-story stone harbor warehouse; closed exterior, local front +Z")
	warehouse.set_meta("source", "art/StoneWarehouse/StoneWarehouse.blend")
	var model: Node3D = load(MODEL_PATH).instantiate()
	model.name = "Visual"
	warehouse.add_child(model)
	warehouse.set_script(preload("res://Mesh/StoneWarehouse/stone_warehouse_materials.gd"))
	var collision := StaticBody3D.new()
	collision.name = "SolidExterior"
	collision.collision_layer = 1
	collision.collision_mask = 0
	warehouse.add_child(collision)
	_box(collision, "Building", Vector3(9.25, 4.65, 6.25), Vector3(0, 2.325, 0))
	_box(collision, "Quay", Vector3(10.5, 0.85, 8.1), Vector3(0, 0.425, 0.45))
	for i in 3:
		_box(collision, "Step%d" % i, Vector3(2.7, 0.28 + i*0.28, 0.7), Vector3(0, 0.14 + i*0.14, 5.35-i*0.35))
	_own(warehouse, warehouse)
	var packed := PackedScene.new()
	var result := packed.pack(warehouse)
	if result == OK:
		DirAccess.make_dir_recursive_absolute("res://Modules/Buildings")
		result = ResourceSaver.save(packed, SCENE_PATH)
	warehouse.free()
	print("STONE_WAREHOUSE_SAVED ", error_string(result))
	quit(0 if result == OK else 1)


func _box(parent: Node, title: String, size: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.name = title
	collider.shape = shape
	collider.position = at
	parent.add_child(collider)


func _own(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		if child.scene_file_path.is_empty():
			_own(child, scene_root)
