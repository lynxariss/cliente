/* RENDERTARGETS: 2,3 */

#include "/settings.glsl"

uniform sampler2D colortex2;
uniform sampler2D colortex3;

in vec2 texcoord;

const float weights[7] = float[7](
0.198596, 0.175713, 0.121703, 0.065984, 0.028002, 0.009300, 0.002216
);

void main() {
#ifdef BLOOM_ENABLED
vec2 texelSize = 1.0 / vec2(textureSize(colortex2, 0));
vec2 wideDirection = vec2(texelSize.x * BLOOM_RADIUS * BLOOM_CLOSE_RADIUS * 8.0, 0.0);
vec2 tightDirection = vec2(texelSize.x * BLOOM_RADIUS * BLOOM_FAR_RADIUS * 3.0, 0.0);

vec4 bloom = texture(colortex2, texcoord) * weights[0];
vec4 coloredLight = texture(colortex3, texcoord) * weights[0];

for (int i = 1; i < 7; i++) {
vec2 wideOffset = wideDirection * (float(i) + 0.5);
vec2 tightOffset = tightDirection * (float(i) + 0.5);
bloom += texture(colortex2, texcoord + wideOffset) * weights[i];
bloom += texture(colortex2, texcoord - wideOffset) * weights[i];
coloredLight += texture(colortex3, texcoord + tightOffset) * weights[i];
coloredLight += texture(colortex3, texcoord - tightOffset) * weights[i];
}

gl_FragData[0] = bloom;
gl_FragData[1] = coloredLight;
#else
gl_FragData[0] = vec4(0.0);
gl_FragData[1] = vec4(0.0);
#endif
}
