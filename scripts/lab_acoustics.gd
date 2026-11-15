extends Node3D
## An opt-in acoustic waypoint graph. Edges require actual clear physics rays;
## distance is consumed along the route, independently of character navigation.

@export_flags_3d_physics var blocker_mask := 1


func route(source: Vector3, listener: Vector3, radius: float) -> Dictionary:
	var points: Array[Vector3] = [source + Vector3.UP * 0.8, listener + Vector3.UP * 0.8]
	for marker in get_children():
		if marker is Marker3D:
			points.append(marker.global_position + Vector3.UP * 0.8)
	var costs: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for point in points:
		costs.append(INF)
		previous.append(-1)
		visited.append(false)
	costs[0] = 0.0
	for iteration in points.size():
		var best := -1
		for i in points.size():
			if not visited[i] and (best < 0 or costs[i] < costs[best]):
				best = i
		if best < 0 or is_inf(costs[best]):
			break
		if best == 1:
			break
		visited[best] = true
		for i in points.size():
			if visited[i] or i == best:
				continue
			var next_cost := costs[best] + points[best].distance_to(points[i])
			if next_cost >= costs[i] or not clear_segment(points[best], points[i]):
				continue
			costs[i] = next_cost
			previous[i] = best
	var path := PackedVector3Array()
	if not is_inf(costs[1]):
		var index := 1
		while index >= 0:
			path.insert(0, points[index] - Vector3.UP * 0.72)
			index = previous[index]
	return {"audible": costs[1] <= radius, "distance": costs[1], "path": path,
		"direct": path.size() == 2}


func clear_segment(from: Vector3, to: Vector3) -> bool:
	if from.distance_squared_to(to) < 0.00001:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to, blocker_mask)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
