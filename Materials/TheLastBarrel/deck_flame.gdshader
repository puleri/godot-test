shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

varying float height;

void vertex() {
	height = UV.y;
	float phase = MODEL_MATRIX[3].z * 9.1 + MODEL_MATRIX[3].x;
	VERTEX.x += height * height * (0.12 * sin(TIME * 5.6 + phase) + 0.04 * sin(TIME * 12.0 + phase));
	VERTEX.z += height * height * 0.06 * cos(TIME * 8.2 + phase);
}

void fragment() {
	vec3 foot = vec3(1.0, 0.78, 0.25);
	vec3 middle = vec3(1.0, 0.31, 0.047);
	vec3 edge = vec3(0.94, 0.073, 0.012);
	vec3 color = mix(foot, middle, smoothstep(0.04, 0.65, height));
	ALBEDO = mix(color, edge, smoothstep(0.47, 1.0, height)) * 1.7;
}
