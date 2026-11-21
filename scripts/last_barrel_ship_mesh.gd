extends RefCounted
## Small joinery pieces share a mesh by logical prop, with named editable material slots.
## The builder uses local coordinates throughout, including for the animated chest lids.

const TIMBER_GRAIN := "res://Materials/TheLastBarrel/quarter_sawn_oak.png"
const PALETTE := {
	"oak": "976849", "oak_light": "ae8058", "oak_dark": "78503b", "oak_red": "8a5843",
	"frame": "684936", "tar": "423633", "wainscot": "5b4440", "blue": "42535c",
	"teal": "416569", "metal": "565760", "metal_lit": "899098", "brass": "bd934f",
	"brass_lit": "e2bd75", "cord": "b09773", "cord_dark": "897050", "canvas": "acaa9c",
	"canvas_dark": "858879", "paper": "e7ce9c", "ink": "392c34", "soot": "302b32",
	"velvet": "83464a", "wine": "744043", "silver": "8f9290", "ironblue": "546372",
	"glass": "344b69", "glass_light": "597a97", "harbor": "213248", "moon": "d1d4c4",
	"lamp": "ffcd75", "ember": "f79c63",
}
var materials: Dictionary = {}
var batches: Dictionary = {}


func _material(key: String) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = key.capitalize()
	mat.albedo_color = Color(PALETTE[key])
	mat.roughness = 0.82
	if key in ["oak", "oak_light", "oak_dark", "oak_red", "frame", "tar", "wainscot", "blue", "teal"]:
		mat.albedo_texture = load(TIMBER_GRAIN)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	elif key in ["brass", "brass_lit", "metal", "metal_lit", "ironblue", "silver"]:
		mat.metallic = 0.42
		mat.roughness = 0.52
	elif key in ["lamp", "glass", "glass_light", "harbor", "moon", "ember"]:
		mat.emission_enabled = true
		mat.emission = Color(PALETTE[key])
		mat.emission_energy_multiplier = 2.3 if key == "lamp" else 0.25
		if key in ["glass", "glass_light", "harbor", "moon"]:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials[key] = mat
	return mat


func _surface(part: Node3D, key: String) -> SurfaceTool:
	if not batches.has(part):
		batches[part] = {}
	if not batches[part].has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(_material(key))
		batches[part][key] = surface
	return batches[part][key]


func face(part: Node3D, key: String, vertices: PackedVector3Array, outward: Vector3, axis := Vector3.ZERO) -> void:
	var surface := _surface(part, key)
	var normal := outward.normalized()
	var reversed := (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).dot(normal) > 0.0
	var u: Vector3 = axis.slide(normal)
	if u.length_squared() < 0.01:
		u = Vector3.RIGHT.slide(normal)
	if u.length_squared() < 0.01:
		u = Vector3.FORWARD.slide(normal)
	u = u.normalized()
	var v := normal.cross(u)
	for index in range(1, vertices.size() - 1):
		for corner in [0, index + 1 if reversed else index, index if reversed else index + 1]:
			var p: Vector3 = vertices[corner]
			surface.set_normal(normal)
			surface.set_uv(Vector2(p.dot(u) * 0.4, p.dot(v) * 1.85))
			surface.add_vertex(p)


func box(part: Node3D, key: String, at: Vector3, size: Vector3, basis := Basis.IDENTITY, bevel := 0.018) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.48)
	var corner := h - Vector3.ONE * b
	var wood_axis := basis[size.max_axis_index()]
	# Clip the twelve arrises. Shared face normals keep the timber and hardware faceted.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for s: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = s
			var vertices := PackedVector3Array()
			for k in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				var p := n * h
				p[u] = k.x * corner[u]
				p[v] = k.y * corner[v]
				vertices.append(at + basis * p)
			face(part, key, vertices, basis * n, wood_axis)
	if b < 0.001:
		return
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var signs := Vector3(sx, sy, sz)
				var base := signs * corner
				var a := base + Vector3(sx * b, 0, 0)
				var c := base + Vector3(0, sy * b, 0)
				var d := base + Vector3(0, 0, sz * b)
				face(part, key, [at + basis*a, at + basis*c, at + basis*d], basis * signs, wood_axis)
				for axis in 3:
					if signs[axis] < 0:
						continue
					var shift := Vector3.ZERO
					shift[axis] = -2.0 * corner[axis]
					var f: Vector3 = [c, d, a][axis]
					var g: Vector3 = [d, a, c][axis]
					var n := signs
					n[axis] = 0
					face(part, key, [at + basis*f, at + basis*g, at + basis*(g + shift), at + basis*(f + shift)], basis*n, wood_axis)


func timber(part: Node3D, key: String, start: Vector3, end: Vector3, thick: float, deep: float) -> void:
	var along := (end - start).normalized()
	var cross_axis := Vector3.BACK.slide(along)
	if cross_axis.length_squared() < 0.03:
		cross_axis = Vector3.RIGHT.slide(along)
	cross_axis = cross_axis.normalized()
	var basis := Basis(along, cross_axis.cross(along), cross_axis)
	box(part, key, (start + end) * 0.5, Vector3(start.distance_to(end), thick, deep), basis)


func rod(part: Node3D, key: String, a: Vector3, b: Vector3, r1: float, r2: float = -1, sides := 8) -> void:
	var y := (b - a).normalized()
	if r2 < 0:
		r2 = r1
	var x := Vector3.RIGHT.slide(y)
	if x.length_squared() < 0.05:
		x = Vector3.BACK.slide(y)
	x = x.normalized()
	var z := x.cross(y)
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for i in sides:
		var ang := TAU * float(i) / sides
		var t := x * cos(ang) + z * sin(ang)
		bottom.append(a + t * r1)
		top.append(b + t * r2)
	for i in sides:
		var j := (i + 1) % sides
		face(part, key, [bottom[i],top[i],top[j],bottom[j]], (bottom[i] + bottom[j]) * 0.5 - a + y * ((r1-r2) * r1 / maxf(a.distance_to(b), 0.01)), y)
	face(part, key, bottom, -y)
	face(part, key, top, y)


func ring(part: Node3D, key: String, at: Vector3, radius: float, tube: float, axis_u: Vector3, axis_v: Vector3, segments := 18) -> void:
	# Solid annular rim with a flat face for brass bezels, eyelets and lashings.
	var normal := axis_u.cross(axis_v).normalized()
	for i in segments:
		var a := float(i) * TAU / segments
		var b := float(i + 1) * TAU / segments
		var u := axis_u * cos(a) + axis_v * sin(a)
		var v := axis_u * cos(b) + axis_v * sin(b)
		var aa := at + u * (radius - tube)
		var bb := at + v * (radius - tube)
		var cc := at + v * (radius + tube)
		var dd := at + u * (radius + tube)
		face(part, key, [aa, bb, cc, dd], normal)
		face(part, key, [aa, bb, bb - normal * tube, aa - normal * tube], -(u + v))
		face(part, key, [cc, dd, dd - normal * tube, cc - normal * tube], u + v)


func finish() -> void:
	for part: Node3D in batches:
		var mesh := ArrayMesh.new()
		mesh.resource_name = str(part.name)
		for surface: SurfaceTool in batches[part].values():
			surface.index()
			surface.commit(mesh)
		var visual := MeshInstance3D.new()
		visual.name = "Joinery"
		visual.mesh = mesh
		if part.get_node_or_null("Light") is Light3D:
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.add_child(visual)
	batches.clear()
