/* RENDERTARGETS: 2,3 */

#include "/settings.glsl"

uniform sampler2D colortex2;
uniform sampler2D colortex3;

in vec2 texcoord;

const float weights[13] = float[13](
0.1176, 0.1133, 0.1009, 0.0831, 0.0633, 0.0446, 0.0291, 0.0175, 0.0098, 0.0050, 0.0024, 0.0010, 0.0004
);

void main() {
#ifdef BLOOM_ENABLED
vec2 texelSize = 1.0 / vec2(textureSize(colortex2, 0));
vec2 wideDirection = vec2(texelSize.x * BLOOM_RADIUS * BLOOM_CLOSE_RADIUS * 3.5, 0.0);
vec2 tightDirection = vec2(texelSize.x * BLOOM_RADIUS * BLOOM_FAR_RADIUS * 1.6, 0.0);

vec4 bloom = texture(colortex2, texcoord) * weights[0];
vec4 coloredLight = texture(colortex3, texcoord) * weights[0];

for (int i = 1; i < 13; i++) {
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
