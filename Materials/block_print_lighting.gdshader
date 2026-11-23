shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D world_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D dither_matrix : repeat_enable, filter_nearest;
uniform bool use_dot_dither = false;
uniform vec4 ink : source_color = vec4(0.12941177, 0.12156863, 0.11372549, 1.0);
uniform vec4 paper : source_color = vec4(0.94509804, 0.90196078, 0.8, 1.0);
uniform bool preserve_black = false;
uniform float middle_threshold : hint_range(0.0, 0.33, 0.001) = 0.105;

void fragment() {
	vec3 world = texture(world_color, SCREEN_UV).rgb;
	float luminance = dot(world, vec3(0.2126, 0.7152, 0.0722));
	float dither;
	if (use_dot_dither) {
		// Six screen pixels between dots in the 16-by-16 matrix.
		float dot_sample = texture(dither_matrix, SCREEN_UV / SCREEN_PIXEL_SIZE / 96.0).r;
		dither = (dot_sample - 0.09) * 0.018;
	} else {
		// The grain belongs to the print surface and has no time or camera input.
		vec2 cell = floor(SCREEN_UV * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0) * 540.0);
		float grain = fract(52.9829189 * fract(dot(cell, vec2(0.06711056, 0.00583715))));
		dither = (grain - 0.5) * 0.018;
	}
	float tone = luminance + dither;
	float middle = smoothstep(middle_threshold, middle_threshold + 0.016, tone);
	float highlight = smoothstep(0.354, 0.374, tone);
	// A small amount of the original tonal variation keeps routes legible inside a band.
	float paper_amount = middle * 0.34 + highlight * 0.61 + clamp(luminance, 0.0, 1.0) * 0.05;
	vec3 print_color = mix(ink.rgb, paper.rgb, paper_amount);
	if (preserve_black) {
		print_color *= smoothstep(0.0, 0.045, luminance);
	}
	COLOR = vec4(print_color, 1.0);
}
