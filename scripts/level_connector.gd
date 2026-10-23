@tool
extends Node3D
## Connection markers use -Z as the outward direction and sit on the walking surface.

@export var module_label: String = "Connector"
@export_category("Connect")
@export var source_connection: StringName = &"South"
@export_node_path("Marker3D") var target_connection: NodePath
@export_tool_button("Snap To Connection", "Snap") var snap_action = _snap_from_inspector


func get_connection(connection_name: StringName) -> Marker3D:
	return get_node_or_null(NodePath("Connections/" + String(connection_name))) as Marker3D


func connect_to(connection_name: StringName, target: Marker3D) -> bool:
	var placement := connection_placement(connection_name, target)
	if placement.is_empty():
		return false
	transform = placement[0]
	return true


func connection_placement(connection_name: StringName, target: Marker3D) -> Array[Transform3D]:
	var source := get_connection(connection_name)
	if source == null or target == null or is_ancestor_of(target):
		push_warning("Choose one of this module's connections and a marker on another module.")
		return []
	if not target.get_meta("level_connection", false):
		push_warning("The target must be a level connection marker.")
		return []
	if not is_equal_approx(float(source.get_meta("width", 6.0)), float(target.get_meta("width", 6.0))):
		push_warning("Connection widths must match.")
		return []
	var current_world := world_transform(self)
	var target_world := world_transform(target)
	if not current_world.basis.get_scale().is_equal_approx(Vector3.ONE) or not target_world.basis.get_scale().is_equal_approx(Vector3.ONE):
		push_warning("Use unit scale on connector modules and their parents before snapping.")
		return []
	var source_local := current_world.affine_inverse() * world_transform(source)
	var desired := target_world * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * source_local.affine_inverse()
	var parent_world := Transform3D.IDENTITY
	if get_parent() is Node3D:
		parent_world = world_transform(get_parent())
	return [parent_world.affine_inverse() * desired]


func _snap_from_inspector() -> void:
	var target := get_node_or_null(target_connection) as Marker3D
	var placement := connection_placement(source_connection, target)
	if placement.is_empty():
		return
	if Engine.is_editor_hint() and is_inside_tree():
		var editor = Engine.get_singleton("EditorInterface")
		var history = editor.get_editor_undo_redo()
		history.create_action("Snap level connector", UndoRedo.MERGE_DISABLE, self)
		history.add_do_property(self, "transform", placement[0])
		history.add_undo_property(self, "transform", transform)
		history.commit_action()
		editor.mark_scene_as_unsaved()
	else:
		transform = placement[0]


static func world_transform(node: Node3D) -> Transform3D:
	# Also works while a builder is assembling a detached scene for PackedScene.pack().
	if node.is_inside_tree():
		return node.global_transform
	var result := node.transform
	var ancestor := node.get_parent()
	if node.top_level:
		return result
	while ancestor != null:
		if ancestor is Node3D:
			result = ancestor.transform * result
			if ancestor.top_level:
				break
		ancestor = ancestor.get_parent()
	return result
