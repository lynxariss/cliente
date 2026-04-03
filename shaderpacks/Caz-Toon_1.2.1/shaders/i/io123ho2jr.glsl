#ifndef SHADOW_GLSL
#define SHADOW_GLSL

float pow4(float x) { return x * x * x * x; }

float quartic_length(vec2 v) {
return sqrt(sqrt(pow4(v.x) + pow4(v.y)));
}

vec3 distortShadowClipPos(vec3 pos) {
float factor = quartic_length(pos.xy) + SHADOW_DISTORTION;
return vec3(pos.xy / factor, pos.z * SHADOW_DEPTH_SCALE);
}

#ifdef CAVE_SHADOWS_ENABLED
uniform sampler2D caveShadowTex;
uniform sampler2D caveShadowTex0;
uniform sampler2D caveShadowTex1;
uniform sampler2D caveShadowTex2;
uniform sampler2D caveShadowTex3;
uniform sampler2D caveShadowTex4;
uniform mat4 caveShadowProjection;
uniform mat4 caveShadowModelView;
uniform mat4 caveShadowProjection0;
uniform mat4 caveShadowModelView0;
uniform mat4 caveShadowProjection1;
uniform mat4 caveShadowModelView1;
uniform mat4 caveShadowProjection2;
uniform mat4 caveShadowModelView2;
uniform mat4 caveShadowProjection3;
uniform mat4 caveShadowModelView3;
uniform mat4 caveShadowProjection4;
uniform mat4 caveShadowModelView4;
uniform int caveShadowLightCount;
uniform vec4 caveShadowLightPosRadius[5];

float caveShadowEdgeFade(vec3 shadowScreenPos) {
vec2 edgeDist = min(shadowScreenPos.xy, 1.0 - shadowScreenPos.xy);
float edgeFade = smoothstep(0.03, 0.16, min(edgeDist.x, edgeDist.y));
vec2 centered = shadowScreenPos.xy * 2.0 - 1.0;
float radialFade = 1.0 - smoothstep(0.60, 0.92, length(centered));
float zFade = smoothstep(0.03, 0.10, shadowScreenPos.z) * (1.0 - smoothstep(0.88, 0.98, shadowScreenPos.z));
return edgeFade * radialFade * zFade;
}

float sampleCaveShadowPCF(vec3 shadowScreenPos, float normalBias) {
vec2 texelSize = 1.0 / vec2(textureSize(caveShadowTex, 0));
float depthSoftness = max(fwidth(shadowScreenPos.z) * 0.75, 0.00006);
vec2 kernel[4] = vec2[](
vec2(-0.75, -0.25),
vec2( 0.75, -0.25),
vec2(-0.25,  0.75),
vec2( 0.25,  0.75)
);

float shadow = 0.0;
for (int i = 0; i < 4; ++i) {
float mapDepth = texture(caveShadowTex, shadowScreenPos.xy + kernel[i] * texelSize * 1.25).r;
float depthDelta = mapDepth - (shadowScreenPos.z - normalBias);
shadow += smoothstep(-depthSoftness, depthSoftness, depthDelta);
}

return shadow * 0.25;
}

float sampleCaveShadowPCFMap(sampler2D tex, vec3 shadowScreenPos, float normalBias) {
vec2 texelSize = 1.0 / vec2(textureSize(tex, 0));
float depthSoftness = max(fwidth(shadowScreenPos.z) * 0.75, 0.00006);
vec2 kernel[4] = vec2[](
vec2(-0.75, -0.25),
vec2( 0.75, -0.25),
vec2(-0.25,  0.75),
vec2( 0.25,  0.75)
);

float shadow = 0.0;
for (int i = 0; i < 4; ++i) {
float mapDepth = texture(tex, shadowScreenPos.xy + kernel[i] * texelSize * 1.25).r;
float depthDelta = mapDepth - (shadowScreenPos.z - normalBias);
shadow += smoothstep(-depthSoftness, depthSoftness, depthDelta);
}
return shadow * 0.25;
}

float getCaveShadowAttenuation(float caveShadow, float strength) {
float s = clamp(strength / 10.0, 0.0, 1.0);
return mix(1.0, clamp(caveShadow, 0.0, 1.0), s);
}

mat4 getCaveShadowProjectionForIndex(int idx) {
if (idx == 1) return caveShadowProjection1;
if (idx == 2) return caveShadowProjection2;
if (idx == 3) return caveShadowProjection3;
if (idx == 4) return caveShadowProjection4;
return caveShadowProjection0;
}

mat4 getCaveShadowModelViewForIndex(int idx) {
if (idx == 1) return caveShadowModelView1;
if (idx == 2) return caveShadowModelView2;
if (idx == 3) return caveShadowModelView3;
if (idx == 4) return caveShadowModelView4;
return caveShadowModelView0;
}

float sampleCaveShadowMapByIndex(int idx, vec3 shadowScreenPos, float normalBias) {
if (idx == 1) return sampleCaveShadowPCFMap(caveShadowTex1, shadowScreenPos, normalBias);
if (idx == 2) return sampleCaveShadowPCFMap(caveShadowTex2, shadowScreenPos, normalBias);
if (idx == 3) return sampleCaveShadowPCFMap(caveShadowTex3, shadowScreenPos, normalBias);
if (idx == 4) return sampleCaveShadowPCFMap(caveShadowTex4, shadowScreenPos, normalBias);
return sampleCaveShadowPCFMap(caveShadowTex0, shadowScreenPos, normalBias);
}

vec3 getCaveShadowPos(vec4 caveShadowCoord) {
if (abs(caveShadowCoord.w) < 0.0001) return vec3(-1.0);
vec3 shadowScreenPos = caveShadowCoord.xyz / caveShadowCoord.w;
shadowScreenPos = shadowScreenPos * 0.5 + 0.5;
if (shadowScreenPos.x < -0.01 || shadowScreenPos.x > 1.01 ||
shadowScreenPos.y < -0.01 || shadowScreenPos.y > 1.01 ||
shadowScreenPos.z < -0.01 || shadowScreenPos.z > 1.01) {
return vec3(-1.0);
}
return shadowScreenPos;
}

float getCaveShadow(vec3 worldPos) {
int count = clamp(caveShadowLightCount, 0, 5);
int selected = -1;
float bestDist = 1e30;
for (int i = 0; i < 5; ++i) {
if (i >= count) break;
vec4 info = caveShadowLightPosRadius[i];
if (info.w <= 0.0) continue;
float d = distance(worldPos, info.xyz);
if (d > info.w) continue;
if (d < bestDist) {
bestDist = d;
selected = i;
}
}
if (selected < 0) return 1.0;

vec4 caveShadowCoord = getCaveShadowProjectionForIndex(selected) * getCaveShadowModelViewForIndex(selected) * vec4(worldPos, 1.0);
vec3 shadowScreenPos = getCaveShadowPos(caveShadowCoord);
if (shadowScreenPos.x < 0.0) return 1.0;

float normalBias = 0.00001;
float shadow = sampleCaveShadowMapByIndex(selected, shadowScreenPos, normalBias);
float coverage = caveShadowEdgeFade(shadowScreenPos);
return mix(1.0, shadow, coverage);
}

float getCaveShadowBiased(vec3 worldPos, float normalBias) {
int count = clamp(caveShadowLightCount, 0, 5);
int selected = -1;
float bestDist = 1e30;
for (int i = 0; i < 5; ++i) {
if (i >= count) break;
vec4 info = caveShadowLightPosRadius[i];
if (info.w <= 0.0) continue;
float d = distance(worldPos, info.xyz);
if (d > info.w) continue;
if (d < bestDist) {
bestDist = d;
selected = i;
}
}
if (selected < 0) return 1.0;

vec4 caveShadowCoord = getCaveShadowProjectionForIndex(selected) * getCaveShadowModelViewForIndex(selected) * vec4(worldPos, 1.0);
vec3 shadowScreenPos = getCaveShadowPos(caveShadowCoord);
if (shadowScreenPos.x < 0.0) return 1.0;

float shadow = sampleCaveShadowMapByIndex(selected, shadowScreenPos, normalBias);
float coverage = caveShadowEdgeFade(shadowScreenPos);
return mix(1.0, shadow, coverage);
}
#endif

#ifdef SHADOWS_ENABLED

uniform sampler2D shadowcolor0;

float computeBias(vec3 pos) {
float r = quartic_length(pos.xy);
float factor = r + SHADOW_DISTORTION;
float numerator = factor * factor;

float depthScaleCompensation = 0.5 / SHADOW_DEPTH_SCALE;
return SHADOW_NORMAL_BIAS / float(shadowMapResolution) * (numerator / SHADOW_DISTORTION) * depthScaleCompensation;
}

vec3 getShadowBias(vec3 scenePos, vec3 normal, float NoL) {

float distanceFactor = clamp(0.12 + 0.01 * length(scenePos), 0.0, 1.0);

float angleFactor = 2.0 - clamp(NoL, 0.0, 1.0);
return 0.25 * normal * distanceFactor * angleFactor;
}

float interleavedGradientNoise(vec2 pos) {
return fract(52.9829189 * fract(0.06711056 * pos.x + 0.00583715 * pos.y));
}
float interleavedGradientNoise(vec2 pos, int t) {
return interleavedGradientNoise(pos + 5.588238 * float(t & 63));
}

mat2 getRotationMatrix(float angle) {
float c = cos(angle);
float s = sin(angle);
return mat2(c, -s, s, c);
}

const vec2[16] blueNoiseDisk = vec2[](
vec2( 0.478712,  0.875764),
vec2(-0.337956, -0.793959),
vec2(-0.955259, -0.028164),
vec2( 0.864527,  0.325689),
vec2( 0.209342, -0.395657),
vec2(-0.106779,  0.672585),
vec2( 0.156213,  0.235113),
vec2(-0.413644, -0.082856),
vec2(-0.415667,  0.323909),
vec2( 0.141896, -0.939980),
vec2( 0.954932, -0.182516),
vec2(-0.766184,  0.410799),
vec2(-0.434912, -0.458845),
vec2( 0.415242, -0.078724),
vec2( 0.728335, -0.491777),
vec2(-0.058086, -0.066401)
);

float shadowEdgeFade(vec3 shadowScreenPos) {
vec2 edgeDist = min(shadowScreenPos.xy, 1.0 - shadowScreenPos.xy);
float edgeFade = smoothstep(0.0, 0.05, min(edgeDist.x, edgeDist.y));
float zFade = smoothstep(0.0, 0.02, shadowScreenPos.z) * smoothstep(1.0, 0.98, shadowScreenPos.z);
return edgeFade * zFade;
}

float getShadowPCF(sampler2D shadowtex, vec3 shadowScreenPos, float distortFactor, float dither) {

if (shadowScreenPos.x < -0.01 || shadowScreenPos.x > 1.01 ||
shadowScreenPos.y < -0.01 || shadowScreenPos.y > 1.01 ||
shadowScreenPos.z < -0.01 || shadowScreenPos.z > 1.01) {
return 1.0;
}

float filterRadius = SHADOW_PCF_RADIUS * (1.0 / float(shadowMapResolution)) * distortFactor;
mat2 rotateAndScale = getRotationMatrix(6.28318 * dither) * filterRadius;

float shadow = 0.0;
const int sampleCount = 6;

for (int i = 0; i < sampleCount; ++i) {
vec2 offset = rotateAndScale * blueNoiseDisk[i];
vec2 sampleCoord = shadowScreenPos.xy + offset;

float sampleDepth = texture(shadowtex, sampleCoord).r;
shadow += step(shadowScreenPos.z, sampleDepth);
}

shadow /= float(sampleCount);

return mix(1.0, shadow, shadowEdgeFade(shadowScreenPos));
}

vec3 getShadowColorPCF(sampler2D shadowtex, sampler2D colortex, vec3 shadowScreenPos, float distortFactor, float dither, float bias) {
if (shadowScreenPos.x < -0.01 || shadowScreenPos.x > 1.01 ||
shadowScreenPos.y < -0.01 || shadowScreenPos.y > 1.01 ||
shadowScreenPos.z < -0.01 || shadowScreenPos.z > 1.01) {
return vec3(1.0);
}

float filterRadius = SHADOW_PCF_RADIUS * (1.0 / float(shadowMapResolution)) * distortFactor;
mat2 rotateAndScale = getRotationMatrix(6.28318 * dither) * filterRadius;

vec3 shadowColor = vec3(0.0);
const int sampleCount = 6;

for (int i = 0; i < sampleCount; ++i) {
vec2 offset = rotateAndScale * blueNoiseDisk[i];
vec2 sampleCoord = shadowScreenPos.xy + offset;

float sampleDepth = texture(shadowtex, sampleCoord).r;
if (shadowScreenPos.z - bias > sampleDepth) {
vec4 col = texture(colortex, sampleCoord);
vec3 transmit = mix(vec3(1.0), col.rgb, 0.5);
shadowColor += transmit;
} else {
shadowColor += vec3(1.0);
}
}

vec3 result = shadowColor / float(sampleCount);
return mix(vec3(1.0), result, shadowEdgeFade(shadowScreenPos));
}

vec3 getShadowColorPCFNoEntity(sampler2D shadowtex, sampler2D colortex, sampler2D entityMarkerTex, vec3 shadowScreenPos, float distortFactor, float dither, float bias) {
if (shadowScreenPos.x < -0.01 || shadowScreenPos.x > 1.01 ||
shadowScreenPos.y < -0.01 || shadowScreenPos.y > 1.01 ||
shadowScreenPos.z < -0.01 || shadowScreenPos.z > 1.01) {
return vec3(1.0);
}

float filterRadius = SHADOW_PCF_RADIUS * (1.0 / float(shadowMapResolution)) * distortFactor;
mat2 rotateAndScale = getRotationMatrix(6.28318 * dither) * filterRadius;

vec3 shadowColor = vec3(0.0);
const int sampleCount = 6;

for (int i = 0; i < sampleCount; ++i) {
vec2 offset = rotateAndScale * blueNoiseDisk[i];
vec2 sampleCoord = shadowScreenPos.xy + offset;

float sampleDepth = texture(shadowtex, sampleCoord).r;
if (shadowScreenPos.z - bias > sampleDepth) {

float entityFlag = texture(entityMarkerTex, sampleCoord).r;
if (entityFlag > 0.5) {

shadowColor += vec3(1.0);
} else {
vec4 col = texture(colortex, sampleCoord);
vec3 transmit = mix(vec3(1.0), col.rgb, 0.5);
shadowColor += transmit;
}
} else {
shadowColor += vec3(1.0);
}
}

vec3 result = shadowColor / float(sampleCount);
return mix(vec3(1.0), result, shadowEdgeFade(shadowScreenPos));
}

float getShadowHardwareFiltered(sampler2DShadow shadowtex, vec3 shadowScreenPos) {
if (shadowScreenPos.x < -0.01 || shadowScreenPos.x > 1.01 ||
shadowScreenPos.y < -0.01 || shadowScreenPos.y > 1.01 ||
shadowScreenPos.z < -0.01 || shadowScreenPos.z > 1.01) {
return 1.0;
}
float shadow = texture(shadowtex, shadowScreenPos);
return mix(1.0, shadow, shadowEdgeFade(shadowScreenPos));
}

float getShadowSharp(sampler2D shadowtex, vec3 shadowScreenPos) {
if (shadowScreenPos.x < -0.01 || shadowScreenPos.x > 1.01 ||
shadowScreenPos.y < -0.01 || shadowScreenPos.y > 1.01 ||
shadowScreenPos.z < -0.01 || shadowScreenPos.z > 1.01) {
return 1.0;
}
float mapDepth = texture(shadowtex, shadowScreenPos.xy).r;
float shadow = step(shadowScreenPos.z, mapDepth);
return mix(1.0, shadow, shadowEdgeFade(shadowScreenPos));
}

float getShadowFaded(sampler2D shadowtex, vec3 shadowScreenPos, float viewDistance) {
float shadow = getShadowSharp(shadowtex, shadowScreenPos);

float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
return mix(shadow, 1.0, fadeFactor);
}

float getShadowSharp(sampler2DShadow shadowtex, vec3 shadowScreenPos) {
return getShadowHardwareFiltered(shadowtex, shadowScreenPos);
}

float getShadowFaded(sampler2D shadowtex, vec3 shadowScreenPos, float distortFactor, float viewDistance, float dither) {
float shadow = getShadowPCF(shadowtex, shadowScreenPos, distortFactor, dither);

float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
return mix(shadow, 1.0, fadeFactor);
}

vec3 getShadowColorFaded(sampler2D shadowtex, sampler2D colortex, vec3 shadowScreenPos, float distortFactor, float viewDistance, float dither) {
vec3 shadow = getShadowColorPCF(shadowtex, colortex, shadowScreenPos, distortFactor, dither, 0.0);
float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
return mix(shadow, vec3(1.0), fadeFactor);
}

float getShadowFaded(sampler2DShadow shadowtex, vec3 shadowScreenPos, float viewDistance) {
float shadow = getShadowHardwareFiltered(shadowtex, shadowScreenPos);

float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
return mix(shadow, 1.0, fadeFactor);
}

float getShadowFaded(sampler2D shadowtex, vec3 shadowScreenPos, vec3 shadowClipPos, float viewDistance, float dither) {
float r = quartic_length(shadowClipPos.xy);
float distortFactor = r + SHADOW_DISTORTION;
return getShadowFaded(shadowtex, shadowScreenPos, distortFactor, viewDistance, dither);
}

float getShadowLeafSoft(sampler2D shadowtex, vec3 shadowScreenPos, float distortFactor, float dither) {
if (shadowScreenPos.x < -0.01 || shadowScreenPos.x > 1.01 ||
shadowScreenPos.y < -0.01 || shadowScreenPos.y > 1.01 ||
shadowScreenPos.z < -0.01 || shadowScreenPos.z > 1.01) {
return 1.0;
}

float filterRadius = LEAF_SHADOW_SOFTNESS * (1.0 / float(shadowMapResolution)) * distortFactor;
mat2 rotateAndScale = getRotationMatrix(6.28318 * dither) * filterRadius;

float shadow = 0.0;
for (int i = 0; i < 16; ++i) {
vec2 offset = rotateAndScale * blueNoiseDisk[i];
float sampleDepth = texture(shadowtex, shadowScreenPos.xy + offset).r;
shadow += step(shadowScreenPos.z, sampleDepth);
}
shadow /= 16.0;
return mix(1.0, shadow, shadowEdgeFade(shadowScreenPos));
}

float getShadowLeafFaded(sampler2D shadowtex, vec3 shadowScreenPos, float distortFactor, float viewDistance, float dither) {
float shadow = getShadowLeafSoft(shadowtex, shadowScreenPos, distortFactor, dither);
float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
return mix(shadow, 1.0, fadeFactor);
}

#endif

#endif
