shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.36, 0.42, 1.0);
uniform float night_fill = 0.13;
void fragment() {
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.94;
	EMISSION = tint.rgb * night_fill;
}
void light() {
	float amount = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float bands = floor(amount * 4.0 + 0.3) / 4.0;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * bands / PI;
}
