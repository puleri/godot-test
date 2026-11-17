shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec3 bounds_min;
uniform vec3 bounds_size;
uniform float sweep = -1.0;
varying vec3 mesh_position;
void vertex() { mesh_position = VERTEX; }
void fragment() {
	vec3 p = (mesh_position - bounds_min) / max(bounds_size, vec3(0.001));
	float diagonal = (p.x + p.y) * 0.5;
	float band = 1.0 - smoothstep(0.025, 0.12, abs(diagonal - sweep));
	ALBEDO = vec3(1.0, 0.87, 0.57);
	ALPHA = band * 0.65;
}
