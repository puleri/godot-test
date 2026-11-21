shader_type canvas_item;

void fragment() {
	vec2 pixel = floor(FRAGCOORD.xy);
	float fleck = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	float tooth = smoothstep(0.68, 1.0, fleck);
	vec2 dot_cell = fract(pixel / 4.0) - 0.5;
	float halftone = step(length(dot_cell), 0.26) * (1.0 - smoothstep(0.0, 0.26, UV.x));
	float corners = step(0.018, UV.x + UV.y) * step(0.018, 2.0 - UV.x - UV.y);
	vec3 paper = vec3(0.90, 0.82, 0.66) - (tooth * 0.065 + halftone * 0.085);
	COLOR = vec4(paper, corners);
}
