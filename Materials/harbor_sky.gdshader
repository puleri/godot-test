shader_type sky;
render_mode use_debanding;

// Pattern-space units per second. Independent offsets keep layers drifting
// past each other rather than sliding the entire sky as one texture.
uniform vec2 far_cloud_velocity = vec2(0.008, 0.003);
uniform vec2 middle_cloud_velocity = vec2(0.025, -0.009);
uniform vec2 near_cloud_velocity = vec2(0.055, 0.014);
uniform float cloud_motion_speed : hint_range(0.0, 3.0) = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 if (AT_CUBEMAP_PASS) {
  // The encounter uses its own lights. Keep any radiance fallback cheap and
  // static instead of evaluating cloud layers into all six cubemap faces.
  COLOR = vec3(0.025, 0.039, 0.075) * 0.44;
 } else {
  float height = max(EYEDIR.y, 0.0);
  vec3 col = mix(vec3(0.105,0.145,0.23),vec3(0.018,0.031,0.075),smoothstep(0.0,0.7,height));
  vec2 p = EYEDIR.xz / (abs(EYEDIR.y)+0.24) * 3.0;
  // TIME continues during the cinematic's gameplay pause.
  float clock = TIME * cloud_motion_speed;
  vec2 far_p = p + clock * far_cloud_velocity;
  vec2 middle_p = p + clock * middle_cloud_velocity;
  vec2 near_p = p + clock * near_cloud_velocity;
  float far_clouds = smoothstep(0.35,0.72,noise(far_p*0.65));
  float middle_clouds = smoothstep(0.38,0.70,noise(middle_p*1.1)*0.75+noise(middle_p*2.2)*0.25);
  float near_clouds = smoothstep(0.43,0.73,noise(near_p*1.7)*0.8+noise(near_p*3.4)*0.2);
  // The closest bank fades toward the horizon to suggest height and depth.
  near_clouds *= smoothstep(0.0,0.25,height);
  col = mix(col,vec3(0.065,0.085,0.135),far_clouds*0.55);
  col = mix(col,vec3(0.032,0.047,0.085),middle_clouds*0.72);
  col = mix(col,vec3(0.019,0.030,0.060),near_clouds*0.86);
  float clouds = 1.0-(1.0-far_clouds*0.55)*(1.0-middle_clouds*0.72)*(1.0-near_clouds*0.86);
  vec3 moon_dir = normalize(vec3(0.3,0.23,-1.0));
  float moon = dot(EYEDIR,moon_dir);
  col += vec3(0.19,0.24,0.34)*pow(max(moon,0.0),90.0)*(1.0-clouds*0.8);
  col += vec3(0.4,0.48,0.6)*smoothstep(0.9996,0.9998,moon)*(1.0-clouds);
  COLOR = col * 0.44;
 }
}
