#include "/settings.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 texcoord;
flat in int block_id_out;
flat in float grass_blade_mask_out;
flat in float grass_cube_mask_out;
flat in int block_id_raw_out;

/* DRAWBUFFERS:01 */
layout(location = 0) out vec4 shadowcolor;
layout(location = 1) out vec4 shadowcolor1out;

void main() {

float isEntity = (block_id_raw_out == 0) ? 1.0 : 0.0;
shadowcolor1out = vec4(isEntity, 0.0, 0.0, 1.0);

#ifdef GRASS_3D_RP_MODE
if (block_id_out == 2 || block_id_out == 3 || block_id_out == 4 || block_id_out == 19) {
discard;
}
if (block_id_out == 15) {

if (grass_cube_mask_out < 0.5 || grass_blade_mask_out > 0.5) {
discard;
}
}
#else
if (block_id_out == 2 || block_id_out == 3 || block_id_out == 4 || block_id_out == 19) {
discard;
}
#endif

if (block_id_out == 1 || block_id_out == 8) discard;

vec4 color = texture(gtexture, texcoord);

if (color.a < 0.01) {
discard;
}

bool isGlass = (block_id_out == 14 || (block_id_out >= 64 && block_id_out <= 79) || block_id_out == 80);
if (isGlass) {

float maxC = max(max(color.r, color.g), color.b);
vec3 tint = (maxC > 0.01) ? color.rgb / maxC : vec3(1.0);

shadowcolor = vec4(tint, 0.05);
return;
}

if (block_id_out == 62) {
shadowcolor = vec4(0.6, 0.1, 1.0, 0.05);
return;
}
if (block_id_out == 63) {
shadowcolor = vec4(0.2, 0.8, 0.6, 0.05);
return;
}

shadowcolor = color;
}
