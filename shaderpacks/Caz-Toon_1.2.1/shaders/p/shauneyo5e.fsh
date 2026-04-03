#include "/settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

in vec2 texcoord;

/* RENDERTARGETS: 0 */

#ifdef FXAA_ENABLED

float linearizeDepth(float d) {
return (2.0 * near * far) / (far + near - (2.0 * d - 1.0) * (far - near));
}

void main() {
ivec2 texel = ivec2(gl_FragCoord.xy);

vec4 centerSample = texelFetch(colortex0, texel, 0);
float rawDepth = texelFetch(depthtex0, texel, 0).x;
if (rawDepth >= 1.0 || centerSample.a < 0.95) {
gl_FragData[0] = centerSample;
return;
}

float depthC = linearizeDepth(rawDepth);

float rawN = texelFetch(depthtex0, texel + ivec2( 0, -1), 0).x;
float rawS = texelFetch(depthtex0, texel + ivec2( 0,  1), 0).x;
float rawW = texelFetch(depthtex0, texel + ivec2(-1,  0), 0).x;
float rawE = texelFetch(depthtex0, texel + ivec2( 1,  0), 0).x;

bool skyN = rawN >= 1.0;
bool skyS = rawS >= 1.0;
bool skyW = rawW >= 1.0;
bool skyE = rawE >= 1.0;

bool cloudN = texelFetch(colortex0, texel + ivec2( 0, -1), 0).a < 0.95;
bool cloudS = texelFetch(colortex0, texel + ivec2( 0,  1), 0).a < 0.95;
bool cloudW = texelFetch(colortex0, texel + ivec2(-1,  0), 0).a < 0.95;
bool cloudE = texelFetch(colortex0, texel + ivec2( 1,  0), 0).a < 0.95;

if (skyN || skyS || skyW || skyE || cloudN || cloudS || cloudW || cloudE) {
gl_FragData[0] = centerSample;
return;
}

float depthN = linearizeDepth(rawN);
float depthS = linearizeDepth(rawS);
float depthW = linearizeDepth(rawW);
float depthE = linearizeDepth(rawE);

float threshold = depthC * 0.02 * FXAA_QUALITY;
float diffN = abs(depthC - depthN);
float diffS = abs(depthC - depthS);
float diffW = abs(depthC - depthW);
float diffE = abs(depthC - depthE);

float maxDiff = max(max(diffN, diffS), max(diffW, diffE));

if (maxDiff < threshold) {
gl_FragData[0] = centerSample;
return;
}

vec3 colorC = texelFetch(colortex0, texel, 0).rgb;
vec3 colorN = texelFetch(colortex0, texel + ivec2( 0, -1), 0).rgb;
vec3 colorS = texelFetch(colortex0, texel + ivec2( 0,  1), 0).rgb;
vec3 colorW = texelFetch(colortex0, texel + ivec2(-1,  0), 0).rgb;
vec3 colorE = texelFetch(colortex0, texel + ivec2( 1,  0), 0).rgb;

float wN = 1.0 / (1.0 + diffN * 100.0 / depthC);
float wS = 1.0 / (1.0 + diffS * 100.0 / depthC);
float wW = 1.0 / (1.0 + diffW * 100.0 / depthC);
float wE = 1.0 / (1.0 + diffE * 100.0 / depthC);
float wC = 1.0;

float totalWeight = wC + wN + wS + wW + wE;
vec3 blended = (colorC * wC + colorN * wN + colorS * wS + colorW * wW + colorE * wE) / totalWeight;

float edgeStrength = smoothstep(threshold, threshold * 3.0, maxDiff);
gl_FragData[0] = vec4(mix(colorC, blended, edgeStrength * 0.5), centerSample.a);
}

#else

void main() {
gl_FragData[0] = texture(colortex0, texcoord);
}

#endif
