extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var script = load("res://scripts/hub_foliage/foliage_cells.gd")
	assert(script != null)
	var foliage = Node3D.new()
	foliage.set_script(script)
	root.add_child(foliage)
	assert(foliage.instance_count > 100)
	assert(foliage.cells.size() > 1)
	var near: Vector3 = foliage.cells[0].center
	foliage.update_visibility(near)
	var visible_count := 0
	for cell in foliage.cells:
		var enabled := 0
		for node in cell.nodes:
			assert(node.multimesh.instance_count > 0)
			assert(node.multimesh.custom_aabb.size.length() > 0)
			if node.visible:
				enabled += 1
		assert(enabled <= 1)
		visible_count += enabled
	assert(visible_count > 0)
	foliage.update_visibility(Vector3(10000,10000,10000))
	for cell in foliage.cells:
		for node in cell.nodes:
			assert(not node.visible)
	print("FOLIAGE_VALIDATION_PASS: ",foliage.instance_count," placements; ",foliage.cells.size()," batches; near visible=",visible_count,"; far hidden; LOD exclusivity passed")
	foliage.queue_free()
	quit(0)
