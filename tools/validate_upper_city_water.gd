extends SceneTree
func _initialize() -> void:
 call_deferred("check_demo")
func check_demo() -> void:
 var packed = load("res://Levels/UpperCityWaterDemo.tscn")
 var demo = packed.instantiate()
 root.add_child(demo)
 for i in range(3): await process_frame
 assert(demo.rotor != null, "Mill rotor not found in imported assembly")
 assert(demo.get_node("RiverPath").curve.point_count == 7)
 var river = demo.generated.get_node("FlowingRiver")
 assert(river.mesh.surface_get_array_len(0) > 100)
 demo.flow_speed = 1.0
 var before: Basis = demo.rotor.basis
 for i in range(4): await process_frame
 assert(not demo.rotor.basis.is_equal_approx(before), "Wheel failed to rotate with flow")
 demo.flow_speed = 0.0
 for i in range(2): await process_frame
 before = demo.rotor.basis
 for i in range(4): await process_frame
 assert(demo.rotor.basis.is_equal_approx(before), "Wheel did not stop at zero flow")
 assert(not demo.splash.emitting and not demo.mist.emitting)
 var report = {"rotor_found": true, "river_path_points": 7, "river_vertices": river.mesh.surface_get_array_len(0), "flow_rotates_wheel": true, "zero_flow_stops_wheel_and_particles": true}
 var file = FileAccess.open("res://art/UpperCityLibrary/godot_validation.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 print("UPPER_CITY_WATER_VALIDATED ", JSON.stringify(report))
 quit(0)
