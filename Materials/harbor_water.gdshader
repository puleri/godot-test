shader_type spatial;
render_mode unshaded, fog_disabled;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float ripple = sin(world.x*1.7+sin(world.z*0.8)+TIME*0.6)*sin(world.z*3.5-TIME*0.4);
 float glint = step(0.87,ripple)*0.009;
 float band = exp(-pow((world.x-35.0+sin(world.z*0.15)*8.0)/24.0,2.0));
 ALBEDO = vec3(0.006,0.014,0.029)+vec3(0.012,0.022,0.04)*band+vec3(glint)*(0.25+band);
}
