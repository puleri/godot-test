shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep_color : source_color = vec4(0.025, 0.12, 0.16, 1.0);
uniform vec4 foam_color : source_color = vec4(0.65, 0.83, 0.81, 1.0);
uniform float flow_speed = 0.9;
uniform bool waterfall = false;
void vertex() {
 if (!waterfall) { VERTEX.y += sin(UV.y * 2.8 - TIME * flow_speed * 2.8 + UV.x * 12.0) * 0.025; }
}
void fragment() {
 float along = UV.y - TIME * flow_speed;
 float streak = sin(along * 5.0 + sin(UV.x * 25.0) * 1.4);
 float ripple = sin(UV.x * 37.0 + along * 2.0) * streak;
 float edge = smoothstep(0.78, 1.0, abs(UV.x - 0.5) * 2.0);
 float foam = edge * (0.45 + 0.4 * ripple);
 if (waterfall) { foam = 0.35 + 0.3 * sin(UV.x * 62.0 + along * 3.0) + 0.15 * streak; }
 ALBEDO = mix(deep_color.rgb, foam_color.rgb, clamp(foam, 0.0, 0.85));
 ROUGHNESS = waterfall ? 0.35 : 0.2;
 METALLIC = 0.22;
 EMISSION = ALBEDO * 0.06;
}
