shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float speed = 0.9;
void fragment() {
 vec2 p = (UV - vec2(0.5)) * 2.0;
 float r = length(p);
 float rings = sin(r * 35.0 - TIME * speed * 5.0 + sin(p.x * 18.0));
 ALBEDO = vec3(0.7, 0.86, 0.84);
 ALPHA = (1.0 - smoothstep(0.55, 1.0, r)) * smoothstep(-0.3, 0.7, rings) * 0.65;
}
