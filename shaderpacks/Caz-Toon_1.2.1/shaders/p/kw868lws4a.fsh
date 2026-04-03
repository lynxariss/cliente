/* RENDERTARGETS: 0,1,2,3,5,6 */

#include "/settings.glsl"
#include "/include/biome_overrides.glsl"
#include "/include/shadow.glsl"
#include "/include/hovering.glsl"
#include "/include/ocean_waves.glsl"

uniform sampler2D gtexture;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
#ifdef PBR_ENABLED
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
#define LAVA_HAS_NOISETEX
#endif
uniform float alphaTestRef;
uniform vec3 fogColor;
uniform int biome_category;
uniform float fogStart;
uniform float fogEnd;
uniform float far;
uniform float sunAngle;
uniform vec3 shadowLightPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int currentRenderedItemId;
uniform float biome_swamp;
uniform int isEyeInWater;

#include "/include/lighting.glsl"
#ifdef EMISSIVE_MASKING
#include "/include/emissive_mask.glsl"
#endif
uniform float frameTimeCounter;
#if defined(END_SHADER) && defined(END_EVENT_ENABLED)
#include "/include/end_event.glsl"
#endif
uniform int frameCounter;
uniform float biome_snowy;
uniform float biome_jungle;
uniform float biome_arid;

in vec2 texcoord;
in vec2 midTexCoord;
in vec4 glcolor;
in float viewDistance;
in float outlineMask;
in float skylight;
in float blocklight;
flat in float emissive;
flat in float emissiveType;
in vec3 worldPos;
in vec4 shadowPos;
in vec4 caveShadowCoord;
flat in float isGrassGeometry;
flat in float isHeatSource;
flat in float isHologram;
flat in float metalness;
flat in float reflective;
in vec3 normal;
flat in vec3 geoNormal;
flat in float blockId;
in float leafAO;
#ifdef PBR_ENABLED
in vec3 tangentVec;
in vec3 binormalVec;
#endif

#include "/include/fog_color.glsl"

#if defined(CLOUDS_2D_ENABLED) && defined(CLOUD_SHADOWS_ENABLED)
#include "/include/cloud_shadow.glsl"
#endif

float random(float x) {
return fract(sin(x * 12.9898) * 43758.5453);
}

#include "/include/noise.glsl"
#include "/include/lava_crust.glsl"

#include "/include/metalness.glsl"

void main() {
vec2 finalUV = texcoord;

vec4 color = texture(gtexture, finalUV) * glcolor;

if (color.a < alphaTestRef) {
discard;
}

if (!isForcedNetherBiome(biome) && !isForcedEndBiome(biome) && isEyeInWater != 1) {
#ifdef CHUNK_FADE_OUT_ENABLED
#ifndef DISTANT_HORIZONS

float horizontalDist = length(worldPos.xz - cameraPosition.xz);
float distGate = smoothstep(CHUNK_FADE_OUT_RADIUS, CHUNK_FADE_OUT_RADIUS + 24.0, horizontalDist);
if (distGate > 0.001) {
float reveal = 1.0 - distGate;
float minY = SEA_LEVEL_OFFSET - 96.0;
float maxY = SEA_LEVEL_OFFSET + 320.0;

float mask = smoothChunkNoise(worldPos.xz * 0.12);
float jitterY = (mask - 0.5) * 10.0;
float revealY = mix(minY, maxY, reveal) + jitterY;
float visible = 1.0 - smoothstep(revealY - 8.0, revealY + 8.0, worldPos.y);
color.rgb *= mix(0.60, 1.0, visible);
if (visible < 0.02) {
discard;
}
}
#endif
#endif
}

vec3 pureTexColor = texture(gtexture, finalUV).rgb;

vec3 rawColor = color.rgb;

float finalBlocklight = blocklight;
float finalSkylight = skylight;
float finalEmissive = emissive;

#ifdef EMISSIVE_MASKING
float emissiveMask = 0.0;
if (emissive > 0.5) {
emissiveMask = getEmissiveMask(int(floor(emissiveType + 0.5)), pureTexColor);

int cbEt = int(floor(emissiveType + 0.5));
if (cbEt == 39 || cbEt == 40 || cbEt == 41) {
vec3 blockUV = fract(worldPos);
vec3 absN = abs(normalize(mat3(gbufferModelViewInverse) * normal));
vec2 faceUV;
if (absN.y > absN.x && absN.y > absN.z) faceUV = blockUV.xz;
else if (absN.x > absN.z) faceUV = blockUV.yz;
else faceUV = blockUV.xy;
const int cbMask[16] = int[](
0, 0, 1632, 1632, 1632, 15996, 15996, 0,
0, 15996, 15996, 1632, 1632, 1632, 0, 0
);
ivec2 texel = clamp(ivec2(floor(faceUV * 16.0)), ivec2(0), ivec2(15));
bool isEmissivePixel = (cbMask[texel.y] & (1 << texel.x)) != 0;
emissiveMask *= isEmissivePixel ? 1.0 : 0.0;
}

if (emissiveMask < 0.05) {
finalEmissive = 0.0;
}

int emEt = int(floor(emissiveType + 0.5));
if (emEt == 44) {
finalEmissive = 0.0;
}
}
#endif

bool isHeldLight = (currentRenderedItemId == 10020 || currentRenderedItemId == 10021);

if (isGrassGeometry > 0.5) {
float dLightX = dFdx(blocklight);
float dLightZ = dFdy(blocklight);
vec2 blockFract = fract(worldPos.xz);
float gradientOffset = (blockFract.x - 0.5) * dLightX * 8.0 + (blockFract.y - 0.5) * dLightZ * 8.0;
finalBlocklight = clamp(blocklight + gradientOffset, 0.0, 1.0);
}

vec3 shadow = vec3(1.0);
float directSunLit = 0.0;
vec3 directSunColor = vec3(0.0);
#ifdef SHADOWS_ENABLED
if (finalSkylight > 0.05 && finalEmissive < 0.5 && !isForcedNetherBiome(biome)) {

vec3 shadowSamplePos = shadowPos.xyz;

#ifdef LEAF_SHEEN_ENABLED
{
int bid = int(blockId + 0.5);
if (bid == 10005 || bid == 10082) {
vec3 wN = normalize(mat3(gbufferModelViewInverse) * normal);
vec3 wL = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
float backFace = max(0.0, -dot(wN, wL));
shadowSamplePos.z -= backFace * LEAF_SHADOW_TRANSMITTANCE * 0.02;
}
}
#endif

int shadowBid = int(blockId + 0.5);
bool isLeafShadow = (shadowBid == 10005 || shadowBid == 10082);

float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);
float r = quartic_length(shadowSamplePos.xy * 2.0 - 1.0);
float distortFactor = r + SHADOW_DISTORTION;

if (isLeafShadow) {
#if LEAF_SHADOW_SOFTNESS <= 0.0

float mapDepth = texture(shadowtex0, shadowSamplePos.xy).r;
shadow = vec3(step(shadowSamplePos.z, mapDepth));
shadow = mix(vec3(1.0), shadow, shadowEdgeFade(shadowSamplePos));
float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
shadow = mix(shadow, vec3(1.0), fadeFactor);
#else
shadow = vec3(getShadowLeafFaded(shadowtex0, shadowSamplePos, distortFactor, viewDistance, dither));
#endif
} else {
#ifdef SHARP_SHADOWS
float mapDepth0 = texture(shadowtex0, shadowSamplePos.xy).r;
float mapDepth1 = texture(shadowtex1, shadowSamplePos.xy).r;
float inShadow0 = 1.0 - step(shadowSamplePos.z, mapDepth0);
float inShadow1 = 1.0 - step(shadowSamplePos.z, mapDepth1);

float isTranslucentShadow = inShadow0 * (1.0 - inShadow1);
float isOpaqueShadow = inShadow1;

vec4 shCol = texture(shadowcolor0, shadowSamplePos.xy);

vec3 tintColor = shCol.rgb;
float tintMax = max(max(tintColor.r, tintColor.g), tintColor.b);
if (tintMax > 0.001) tintColor /= tintMax;

vec3 transmit = mix(vec3(1.0), tintColor, 0.7);

shadow = vec3(1.0);
shadow = mix(shadow, vec3(0.0), isOpaqueShadow);
shadow = mix(shadow, transmit, isTranslucentShadow);
shadow = mix(vec3(1.0), shadow, shadowEdgeFade(shadowSamplePos));
float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
shadow = mix(shadow, vec3(1.0), fadeFactor);
#else
shadow = getShadowColorFaded(shadowtex0, shadowcolor0, shadowSamplePos, distortFactor, viewDistance, dither);
#endif
}

bool isFoliageShadowId = (shadowBid == 10002 || shadowBid == 10003 || shadowBid == 10004 || shadowBid == 10019);
if (isGrassGeometry < 0.5 && !isFoliageShadowId) {
float grazeBlend = smoothstep(0.15, 0.0, shadowPos.w);
shadow = mix(shadow, vec3(0.0), grazeBlend);
}

if (shadowBid == 10018) {
shadow = mix(shadow, vec3(1.0), 0.5);
}

float shadowCoverage = 1.0 - smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);

directSunLit = dot(shadow, vec3(0.333)) * shadowCoverage;
directSunColor = shadow * shadowCoverage;

shadow = mix(vec3(1.0), shadow, finalSkylight);

float shadowLum = dot(shadow, vec3(0.299, 0.587, 0.114));

float darkened = mix(1.0, shadowLum, SHADOW_OPACITY);

shadow = (shadowLum > 0.001) ? shadow * (darkened / shadowLum) : vec3(darkened);
}
#endif

float caveShadowAtten = 1.0;
#ifdef CAVE_SHADOWS_ENABLED
if (finalEmissive < 0.5) {
float caveBlocklightMask = smoothstep(0.06, 0.40, finalBlocklight);
float caveShadowMix = (1.0 - smoothstep(0.12, 0.40, finalSkylight)) * caveBlocklightMask * CAVE_SHADOW_STRENGTH;
if (caveShadowMix > 0.001) {
float caveShadow = getCaveShadow(worldPos);
caveShadowAtten = getCaveShadowAttenuation(caveShadow, caveShadowMix);

#ifdef CAVE_SHADOW_DEBUG_VIEW
float caveDebug = smoothstep(0.05, 0.35, 1.0 - caveShadowAtten);
color.rgb = mix(color.rgb, vec3(0.0, 1.0, 0.7), clamp(caveDebug * 2.0, 0.0, 1.0));
#endif
}
}
#endif

#if defined(CLOUDS_2D_ENABLED) && defined(CLOUD_SHADOWS_ENABLED)
if (finalSkylight > 0.1) {
float cloudShadow = getCloudShadow(worldPos, frameTimeCounter);
shadow *= cloudShadow;
}
#endif

color.rgb = applyLightingWithShadow(color.rgb, sunAngle, finalSkylight, finalBlocklight, finalEmissive, shadow, worldPos.y);
color.rgb *= caveShadowAtten;

#ifdef WATER_WAVES_ENABLED
if (isEyeInWater == 1 && worldPos.y < float(SEA_LEVEL_OFFSET) && finalSkylight > 0.1) {
float waterSurfaceY = float(SEA_LEVEL_OFFSET);
float submergedDepth = waterSurfaceY - worldPos.y;

float ct = frameTimeCounter * WATER_WAVE_SPEED * 0.4;
vec3 cPos3D = worldPos * 0.75;

float cA = 0.0;
{
float amp = 1.0, freq = 0.7, total = 0.0;
vec3 p = cPos3D;
for (int i = 0; i < 2; i++) {

p = vec3(p.x * 0.866 - p.z * 0.5, p.y, p.x * 0.5 + p.z * 0.866);
cA += abs(noise3D(p * freq + ct * (1.0 + float(i) * 0.3)) - 0.5) * amp;
total += amp * 0.5;
amp *= 0.5;
freq *= 2.0;
}
cA = 1.0 - cA / total;
}

float cB = 0.0;
{
float amp = 1.0, freq = 0.7, total = 0.0;
vec3 p = cPos3D + 5.0;
for (int i = 0; i < 2; i++) {
p = vec3(p.x * 0.866 - p.z * 0.5, p.y, p.x * 0.5 + p.z * 0.866);
cB += abs(noise3D(p * freq + ct * 1.15 * (1.0 + float(i) * 0.3)) - 0.5) * amp;
total += amp * 0.5;
amp *= 0.5;
freq *= 2.0;
}
cB = 1.0 - cB / total;
}

float caustic = min(cA, cB);
caustic = pow(caustic, 2.0) * 2.5;
caustic = max(caustic - 0.15, 0.0) * (1.0 / 0.85);

float depthFade = exp(-submergedDepth * 0.03);

float causticSunLit = clamp(shadowPos.w, 0.0, 1.0);

float causticStrength = caustic * depthFade * causticSunLit * finalSkylight;

color.rgb *= 1.0 + causticStrength;
}
#endif

#ifdef SHADOWS_ENABLED
float indoorFactor = 1.0 - smoothstep(0.0, 0.5, finalSkylight);
float aboveSeaLevel = smoothstep(float(SEA_LEVEL_OFFSET) - 4.0, float(SEA_LEVEL_OFFSET), worldPos.y);
if (indoorFactor > 0.01 && directSunLit > 0.01 && finalEmissive < 0.5 && aboveSeaLevel > 0.01 && !isForcedNetherBiome(biome)) {
float angle = fract(sunAngle);
float todBright = max(
smoothstep(0.02, 0.08, angle) * (1.0 - smoothstep(0.44, 0.52, angle)),
smoothstep(0.55, 0.62, angle) * (1.0 - smoothstep(0.90, 0.96, angle)) * 0.15
);

vec3 sunDir = normalize(shadowLightPosition);
float NdotL = max(dot(normal, sunDir), 0.0);
float facingSun = smoothstep(0.0, 0.3, NdotL);
color.rgb += rawColor * directSunColor * todBright * indoorFactor * facingSun * 0.8;
}
#endif

#ifdef EMISSIVE_MASKING
if (emissive > 0.5 && emissiveMask >= 0.05) {
int sceneEt = int(floor(emissiveType + 0.5));
if (sceneEt == 44) {

float whiteness = smoothstep(0.7, 0.95, dot(rawColor, vec3(0.333)));
color.rgb = mix(color.rgb, rawColor * (1.0 + whiteness * 0.1), 0.75);
} else {
vec3 emSrc = (sceneEt == 19) ? pureTexColor : rawColor;
vec3 emissiveResult = emSrc * EMISSIVE_BRIGHTNESS;
#ifdef END_SHADER
emissiveResult *= END_EMISSIVE_BOOST;
#endif
color.rgb = mix(color.rgb, emissiveResult, clamp(emissiveMask, 0.0, 1.0));
}
}
#endif

bool outputHeldBloom = false;
vec3 heldBloomColor = vec3(0.0);
#ifdef HANDHELD_LIGHT_ENABLED
float distToEye = length(worldPos - eyePosition);

bool isHeldLightItem = (heldItemId >= 10020 && heldItemId <= 10059) || heldItemId == 10087 ||
(heldItemId2 >= 10020 && heldItemId2 <= 10059) || heldItemId2 == 10087;

if (distToEye < 2.0 && isHeldLightItem && blockId < 1.0) {
#ifdef EMISSIVE_MASKING
int heldEt = 0;
if (heldItemId == 10087) heldEt = 46;
else if (heldItemId >= 10020 && heldItemId <= 10059) heldEt = heldItemId - 10020;
else if (heldItemId2 == 10087) heldEt = 46;
else if (heldItemId2 >= 10020 && heldItemId2 <= 10059) heldEt = heldItemId2 - 10020;
float heldMask = getEmissiveMask(heldEt, rawColor);
float hm = clamp(heldMask, 0.0, 1.0);

vec3 litColor = applyLighting(rawColor, sunAngle, skylight, blocklight, worldPos.y);
vec3 emResult = rawColor * EMISSIVE_BRIGHTNESS * HELD_BLOOM_EMISSION;
color.rgb = mix(litColor, emResult, hm);
finalEmissive = (hm > 0.05) ? 1.0 : 0.0;
float heldBloomMult = (heldEt == 46) ? 0.15 : 1.0;
heldBloomColor = rawColor * EMISSIVE_BRIGHTNESS * HELD_BLOOM_STRENGTH * hm * heldBloomMult;
outputHeldBloom = (hm > 0.05);
#else
color.rgb = rawColor * EMISSIVE_BRIGHTNESS * HELD_BLOOM_EMISSION;
finalEmissive = 1.0;
heldBloomColor = rawColor * EMISSIVE_BRIGHTNESS * HELD_BLOOM_STRENGTH;
outputHeldBloom = true;
#endif
}

if (!outputHeldBloom) {
bool holdingLight = (heldBlockLightValue > 7 || heldBlockLightValue2 > 7);
if (holdingLight && distToEye < HELD_BLOOM_RADIUS && blockId < 1.0) {
float rawColorLuma = dot(rawColor, vec3(0.299, 0.587, 0.114));
if (rawColorLuma > HELD_BLOOM_THRESHOLD && blocklight > 0.8) {
#ifdef EMISSIVE_MASKING
int fbEt = 0;
if (heldItemId == 10087) fbEt = 46;
else if (heldItemId >= 10020 && heldItemId <= 10063) fbEt = heldItemId - 10020;
else if (heldItemId2 == 10087) fbEt = 46;
else if (heldItemId2 >= 10020 && heldItemId2 <= 10063) fbEt = heldItemId2 - 10020;
float fbMask = getEmissiveMask(fbEt, rawColor);
float fm = clamp(fbMask, 0.0, 1.0);
vec3 litColor = applyLighting(rawColor, sunAngle, skylight, blocklight, worldPos.y);
vec3 emResult = rawColor * EMISSIVE_BRIGHTNESS * HELD_BLOOM_EMISSION;
color.rgb = mix(litColor, emResult, fm);
finalEmissive = (fm > 0.05) ? 1.0 : 0.0;
heldBloomColor = rawColor * EMISSIVE_BRIGHTNESS * HELD_BLOOM_STRENGTH * fm;
outputHeldBloom = (fm > 0.05);
#else
color.rgb = rawColor * EMISSIVE_BRIGHTNESS * HELD_BLOOM_EMISSION;
finalEmissive = 1.0;
heldBloomColor = rawColor * EMISSIVE_BRIGHTNESS * HELD_BLOOM_STRENGTH;
outputHeldBloom = true;
#endif
}
}
}
#endif
#ifdef HANDHELD_LIGHT_ENABLED
if (finalEmissive < 0.5) color.rgb += getHandheldLightBoost(worldPos, rawColor, color.rgb);
#endif
color.rgb *= TERRAIN_BRIGHTNESS;

#ifdef END_SHADER
if (finalEmissive < 0.5) {

#ifdef END_TERRAIN_PATCHES_ENABLED
{
vec3 patchPos3D = worldPos * END_TERRAIN_PATCH_SCALE;
float pn = 0.0;
float pAmp = 0.6;
for (int octave = 0; octave < 3; octave++) {
vec3 ip = floor(patchPos3D);
vec3 fp = fract(patchPos3D);
fp = fp * fp * (3.0 - 2.0 * fp);
float a = fract(sin(dot(ip, vec3(127.1, 311.7, 74.7))) * 43758.5453);
float b = fract(sin(dot(ip + vec3(1,0,0), vec3(127.1, 311.7, 74.7))) * 43758.5453);
float c = fract(sin(dot(ip + vec3(0,1,0), vec3(127.1, 311.7, 74.7))) * 43758.5453);
float d = fract(sin(dot(ip + vec3(1,1,0), vec3(127.1, 311.7, 74.7))) * 43758.5453);
float e = fract(sin(dot(ip + vec3(0,0,1), vec3(127.1, 311.7, 74.7))) * 43758.5453);
float f = fract(sin(dot(ip + vec3(1,0,1), vec3(127.1, 311.7, 74.7))) * 43758.5453);
float g = fract(sin(dot(ip + vec3(0,1,1), vec3(127.1, 311.7, 74.7))) * 43758.5453);
float h = fract(sin(dot(ip + vec3(1,1,1), vec3(127.1, 311.7, 74.7))) * 43758.5453);
float z0 = mix(mix(a, b, fp.x), mix(c, d, fp.x), fp.y);
float z1 = mix(mix(e, f, fp.x), mix(g, h, fp.x), fp.y);
pn += mix(z0, z1, fp.z) * pAmp;
patchPos3D *= 2.3;
pAmp *= 0.45;
}
float patchDark = smoothstep(0.25, 0.55, pn);
patchDark = mix(1.0, 1.0 - END_TERRAIN_PATCH_STRENGTH, 1.0 - patchDark);
color.rgb *= patchDark;
}
#endif

#if defined(END_SHADER) && defined(END_EVENT_ENABLED)
EndEvent endEvent = getEndEvent(frameTimeCounter);
#endif
#if defined(END_SHADER) && defined(END_EVENT_ENABLED) && defined(END_EVENT_EYE_ENABLED) && defined(END_EVENT_SPOTLIGHT_ENABLED)
if (endEvent.eyeOpen > 0.01) {

vec2 playerXZ = eyePosition.xz;
vec2 fragXZ = worldPos.xz;
float hDist = length(fragXZ - playerXZ);

float spotRadius = END_EVENT_SPOTLIGHT_RADIUS;
float spot = 1.0 - smoothstep(spotRadius * 0.4, spotRadius, hDist);

float upFacing = max(normal.y, 0.0);
spot *= upFacing;

spot *= endEvent.eyeOpen;

vec3 spotColor = vec3(
END_EVENT_EYE_IRIS_R * 0.5 + 0.5,
END_EVENT_EYE_IRIS_G * 0.3 + 0.4,
END_EVENT_EYE_IRIS_B * 0.4 + 0.6
);
color.rgb += rawColor * spotColor * spot * END_EVENT_SPOTLIGHT_INTENSITY * TERRAIN_BRIGHTNESS;
}
#endif
}
#endif

#ifndef END_SHADER
{
int bid = int(blockId + 0.5);
int btype = (bid >= 10000) ? (bid - 10000) : -1;
if (btype == 15 && finalEmissive < 0.5) {

float upFacing = max(normal.y, 0.0);
if (upFacing > 0.3) {
vec2 patchPos = worldPos.xz * 0.15;
float pn = 0.0;
float pAmp = 0.6;
for (int octave = 0; octave < 3; octave++) {
vec2 ip = floor(patchPos);
vec2 fp = fract(patchPos);
fp = fp * fp * (3.0 - 2.0 * fp);
float a = fract(sin(dot(ip, vec2(127.1, 311.7))) * 43758.5453);
float b = fract(sin(dot(ip + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
float c = fract(sin(dot(ip + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
float d = fract(sin(dot(ip + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
pn += mix(mix(a, b, fp.x), mix(c, d, fp.x), fp.y) * pAmp;
patchPos *= 2.3;
pAmp *= 0.45;
}

float patchMask = 1.0 - smoothstep(0.25, 0.55, pn);
float patchStrength = 0.20 * patchMask * upFacing;

color.rgb *= mix(vec3(1.0), vec3(0.7, 0.8, 0.95), patchStrength);
}
}
}
#endif

#ifdef TEXTURE_PALETTE_ENABLED
if (finalEmissive < 0.5) {
float levels = float(TEXTURE_PALETTE_LEVELS);
color.rgb = floor(color.rgb * levels) / levels;
}
#endif

#ifdef METALNESS_ENABLED
if (metalness > 0.5 && finalEmissive < 0.5) {
vec3 viewDir = normalize(worldPos - cameraPosition);

vec3 worldNormalMetal = normalize(mat3(gbufferModelViewInverse) * normal);
vec3 worldLightMetal = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

#ifdef END_SHADER
float endLightAngle = frameTimeCounter * 0.15;
vec3 endLight = normalize(vec3(sin(endLightAngle) * 0.4, 0.8, cos(endLightAngle) * 0.4));
color.rgb = applyMetalnessEnd(color.rgb, viewDir, worldNormalMetal, endLight, metalness, worldPos, frameTimeCounter, rawColor, 1.0, blocklight);
#else
float shadowLit = dot(shadow, vec3(0.333)) * smoothstep(0.1, 0.5, skylight);
color.rgb = applyMetalness(color.rgb, viewDir, worldNormalMetal, worldLightMetal, sunAngle, metalness, worldPos, rawColor, shadowLit, blocklight);
#endif
}
#endif

#ifdef PBR_ENABLED
float pbrEmissive = 0.0;
vec3 pbrNormal = normal;
if (finalEmissive < 0.5 && metalness < 0.5) {

vec4 normalData = texture(normals, texcoord);
vec4 specData = texture(specular, texcoord);

bool normalIsFlat = abs(normalData.r - 0.5) < 0.05 && abs(normalData.g - 0.5) < 0.05 && normalData.b > 0.90;
bool specIsEmpty = (specData.r + specData.g + specData.b + specData.a) < 0.02;
bool hasPBR = !normalIsFlat || !specIsEmpty;

float pbrRoughness;
float pbrF0;
float pbrMetallic;

if (hasPBR) {
#ifdef MC_TEXTURE_FORMAT_LAB_PBR

float perceptualSmooth = specData.r;
pbrRoughness = pow(1.0 - perceptualSmooth, 2.0);

float rawF0 = specData.g * 255.0;
if (rawF0 > 229.5) {
pbrMetallic = 1.0;
pbrF0 = 0.7;
} else {
pbrMetallic = 0.0;
pbrF0 = specData.g * (255.0 / 229.0);
pbrF0 = max(pbrF0, 0.02);
}
#else

pbrRoughness = pow(1.0 - specData.r, 2.0);
pbrMetallic = step(0.5, specData.g);
pbrF0 = pbrMetallic > 0.5 ? 0.7 : 0.04;
#endif
} else {

int bid = int(blockId + 0.5);
int btype = (bid >= 10000) ? (bid - 10000) : -1;

if (btype == 10) {

pbrRoughness = DEFAULT_WOOD_ROUGHNESS;
pbrF0 = 0.04;
pbrMetallic = 0.0;
} else if (btype == 18) {

pbrRoughness = DEFAULT_STONE_ROUGHNESS;
pbrF0 = 0.04;
pbrMetallic = 0.0;
} else if (btype == 17) {

pbrRoughness = 0.45;
pbrF0 = 0.05;
pbrMetallic = 0.0;
} else {

pbrRoughness = -1.0;
pbrF0 = 0.0;
pbrMetallic = 0.0;
}
}

if (pbrRoughness >= 0.0) {

vec3 N;
if (hasPBR) {

vec3 tNormal = normalData.rgb * 2.0 - 1.0;
tNormal.xy *= PBR_NORMAL_STRENGTH;
tNormal = normalize(tNormal);

mat3 TBN = mat3(normalize(tangentVec), normalize(binormalVec), normalize(normal));
N = normalize(TBN * tNormal);
} else {

vec3 rawColor = texture(gtexture, texcoord).rgb;
N = perturbNormal(normalize(normal), rawColor, worldPos);
}

vec3 L = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
vec3 Nworld = normalize(mat3(gbufferModelViewInverse) * N);

float NdotL = max(dot(Nworld, L), 0.0);

float sunVisibility = dot(shadow, vec3(0.299, 0.587, 0.114)) * finalSkylight;

float dayFactor = smoothstep(0.02, 0.10, fract(sunAngle)) * smoothstep(0.48, 0.40, fract(sunAngle));

if (hasPBR) {

vec3 Vworld = normalize(cameraPosition - worldPos);
vec3 Hworld = normalize(Vworld + L);
float NdotH = max(dot(Nworld, Hworld), 0.0);
float NdotV = max(dot(Nworld, Vworld), 0.001);

float D = distributionGGX(NdotH, max(pbrRoughness, 0.04));
float F = fresnelSchlick(NdotV, pbrF0);
float spec = D * F * NdotL;

vec3 specColor = pbrMetallic > 0.5 ? color.rgb * 2.5 : vec3(1.0);
color.rgb += spec * specColor * PBR_SPECULAR_STRENGTH * sunVisibility * dayFactor;

if (pbrMetallic > 0.5) {
vec3 R = reflect(-Vworld, Nworld);
vec3 envColor = getEnvironmentColor(R, sunAngle);
float envFresnel = fresnelSchlick(NdotV, pbrF0) * 0.5;
color.rgb = mix(color.rgb, envColor * color.rgb, envFresnel * PBR_SPECULAR_STRENGTH);
}
} else {

vec3 NworldFlat = normalize(mat3(gbufferModelViewInverse) * normalize(normal));

vec3 fixedV = normalize(L + vec3(0.0, 0.4, 0.0));
vec3 Hworld = normalize(fixedV + L);
float flatNdotH = max(dot(NworldFlat, Hworld), 0.0);
float flatNdotL = max(dot(NworldFlat, L), 0.0);

float shininess = mix(4.0, 32.0, 1.0 - pbrRoughness);
float spec = pow(flatNdotH, shininess);

float normFactor = (shininess + 2.0) / (2.0 * 3.14159);
spec *= normFactor;

float wrappedNdotL = max(flatNdotL, 0.25);

float specAmount = spec * wrappedNdotL * 0.15;
color.rgb += specAmount * PBR_SPECULAR_STRENGTH * sunVisibility * dayFactor;
}

pbrNormal = N;
}

if (hasPBR) {
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
pbrEmissive = specData.a;
#else
pbrEmissive = specData.b;
#endif
}
}

if (pbrEmissive > 0.01) {

finalEmissive = max(finalEmissive, pbrEmissive);

color.rgb = mix(color.rgb, rawColor * 1.5, pbrEmissive * 0.5);
}
#endif

#ifdef LEAF_SHEEN_ENABLED
{
int bid = int(blockId + 0.5);
if ((bid == 10005 || bid == 10082) && finalEmissive < 0.5) {
vec3 worldLightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
vec3 viewDir = normalize(worldPos - cameraPosition);

float VdotL = max(dot(viewDir, worldLightDir), 0.0);
float sss = pow(VdotL, 3.0) * LEAF_SSS_STRENGTH;
vec3 sssColor = color.rgb * vec3(1.2, 1.1, 0.7) * sss * finalSkylight * shadow;

color.rgb += sssColor;
}
}
#endif

#ifdef LAVA_CRUST_ENABLED
{
int lavaBid = int(blockId + 0.5);
bool isLava = (lavaBid == 10039);
if (isLava) {
vec3 lavaN = normalize(mat3(gbufferModelViewInverse) * normal);
color.rgb = applyLavaCrust(color.rgb, worldPos, lavaN);

#ifdef BIOME_SOUL_SAND_VALLEY
if (biome == BIOME_SOUL_SAND_VALLEY) {
float lavaLum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
vec3 blueLava = vec3(1.0/255.0, 158.0/255.0, 210.0/255.0) * lavaLum * 2.0;
color.rgb = blueLava;
}
#endif
}
}
#endif

#ifdef BIOME_SOUL_SAND_VALLEY
{
int magmaBid = int(blockId + 0.5);
if (magmaBid == 10040 && biome == BIOME_SOUL_SAND_VALLEY) {
float magmaLum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
vec3 blueMagma = vec3(1.0/255.0, 158.0/255.0, 210.0/255.0) * magmaLum * 2.0;

float magmaWarmth = max(color.r - color.b, 0.0);
color.rgb = mix(color.rgb, blueMagma, smoothstep(0.05, 0.2, magmaWarmth));
}
}
#endif

if (finalEmissive < 0.5 && isEyeInWater != 1 && !isForcedNetherBiome(biome)) {
float denom = max(fogEnd - fogStart, 0.0001);
float fogFactor = clamp((fogEnd - viewDistance) / denom, 0.0, 1.0);
color.rgb = mix(getTimeBasedFogColor(), color.rgb, fogFactor);
}

gl_FragData[0] = color;

gl_FragData[1] = vec4(outlineMask, finalEmissive, finalSkylight, isHeatSource);

vec3 lightColor = vec3(0.0);
#ifdef EMISSIVE_MASKING
if (emissive > 0.5 && emissiveMask >= 0.05) {
int bloomEt = int(floor(emissiveType + 0.5));
if (bloomEt == 19) {
lightColor = vec3(1.0, 0.75, 0.2) * EMISSIVE_BRIGHTNESS * 0.15;
} else if (bloomEt == 17) {

lightColor = vec3(1.0, 0.8, 0.3) * EMISSIVE_BRIGHTNESS * clamp(emissiveMask, 0.0, 1.0) * 1.5;
} else if (bloomEt == 46) {

lightColor = rawColor * EMISSIVE_BRIGHTNESS * 0.15;
} else {
lightColor = rawColor * EMISSIVE_BRIGHTNESS * clamp(emissiveMask, 0.0, 1.0);
}
#ifdef END_SHADER
lightColor *= END_EMISSIVE_BOOST;
#endif
}
#else
if (finalEmissive > 0.5) {
int et = int(floor(emissiveType + 0.5));
bool isWarmLight = (et == -14 || et == 0 || et == 15 || et == 16 || et == 22 || et == 30);
bool isSoulLight = (et == 1 || et == 23);
if (isWarmLight) {
lightColor = vec3(1.0, 0.85, 0.4) * EMISSIVE_BRIGHTNESS;
} else if (isSoulLight) {
lightColor = vec3(0.3, 0.7, 1.0) * EMISSIVE_BRIGHTNESS;
} else {
lightColor = rawColor * EMISSIVE_BRIGHTNESS;
}
#ifdef END_SHADER
lightColor *= END_EMISSIVE_BOOST;
#endif
}
#endif

if (outputHeldBloom) {
lightColor = heldBloomColor;
}

#ifdef BIOME_SOUL_SAND_VALLEY
{
int bloomBid = int(blockId + 0.5);
if ((bloomBid == 10039 || bloomBid == 10040) && biome == BIOME_SOUL_SAND_VALLEY) {
float bloomLum = dot(lightColor, vec3(0.299, 0.587, 0.114));
lightColor = vec3(1.0/255.0, 158.0/255.0, 210.0/255.0) * bloomLum * 2.0;
}
}
#endif
gl_FragData[2] = vec4(lightColor, 1.0);
gl_FragData[3] = vec4(lightColor, 1.0);

gl_FragData[5] = vec4(blockId / 65535.0, 0.0, 0.0, 1.0);

#ifdef MATERIAL_REFLECTIONS_ENABLED
if (reflective > 0.5 && finalEmissive < 0.5) {

#ifdef PBR_ENABLED
vec3 ssrNormal = pbrNormal;
#else
vec3 ssrNormal = normal;
#endif
vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * ssrNormal);
vec3 encodedNormal = worldNormal * 0.5 + 0.5;

float packedLmcoord = dot(floor(255.0 * vec2(blocklight, skylight) + 0.5), vec2(1.0 / 65535.0, 256.0 / 65535.0));

float rawTexLum = clamp(dot(rawColor, vec3(0.299, 0.587, 0.114)), 0.0, 0.85);
float packedReflect = dot(floor(255.0 * vec2(MATERIAL_REFLECTION_AMOUNT, rawTexLum) + 0.5), vec2(1.0 / 65535.0, 256.0 / 65535.0));
gl_FragData[4] = vec4(packedLmcoord, packedReflect, encodedNormal.x, encodedNormal.y);
} else {
gl_FragData[4] = vec4(0.0);
}
#else
gl_FragData[4] = vec4(0.0);
#endif
}
