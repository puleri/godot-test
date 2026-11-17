extends SpringBoneSimulator3D
## Add under the crow's Skeleton3D after any body pose modifiers.

@export_range(0.1, 12.0) var coat_stiffness := 4.7
@export_range(0.0, 1.0) var coat_drag := 0.42
@export_range(0.1, 12.0) var satchel_stiffness := 3.3
@export_range(0.0, 1.0) var satchel_drag := 0.34

const COAT_PANELS := ["R", "Back", "L"]


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or skeleton.find_bone("Spine") == -1:
		push_error("Crow outfit motion requires the crow Skeleton3D.")
		active = false
		return

	# A body proxy keeps the spring tips from swinging freely into the torso.
	var torso := SpringBoneCollisionSphere3D.new()
	torso.name = "TorsoCollision"
	torso.radius = 0.215
	add_child(torso)
	torso.set_bone_name("Spine")
	var spine_rest := skeleton.get_bone_global_rest(skeleton.find_bone("Spine"))
	torso.position_offset = spine_rest.affine_inverse() * Vector3(0.0, 0.60, 0.04)

	setting_count = COAT_PANELS.size() + 1
	for index in COAT_PANELS.size():
		var panel: String = COAT_PANELS[index]
		_configure_chain(index, "CoatUpper_" + panel, "CoatTip_" + panel,
			coat_stiffness, coat_drag, 0.012)
	_configure_chain(COAT_PANELS.size(), "Satchel", "SatchelTip",
		satchel_stiffness, satchel_drag, 0.075)


func _configure_chain(index: int, root: String, tip: String, stiffness: float,
		drag: float, radius: float) -> void:
	set_root_bone_name(index, root)
	set_end_bone_name(index, tip)
	set_center_from(index, CENTER_FROM_WORLD_ORIGIN)
	set_stiffness(index, stiffness)
	set_drag(index, drag)
	set_radius(index, radius)
	set_enable_all_child_collisions(index, true)
