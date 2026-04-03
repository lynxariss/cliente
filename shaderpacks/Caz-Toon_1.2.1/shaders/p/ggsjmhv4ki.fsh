/* RENDERTARGETS: 0,1,2,3 */

#include "/settings.glsl"
#include "/include/biome_overrides.glsl"
#include "/include/shadow.glsl"

uniform sampler2D gtexture;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor1;
uniform float alphaTestRef;
uniform vec3 fogColor;
uniform int biome_category;
uniform float fogStart;
uniform float fogEnd;
uniform float sunAngle;
uniform vec3 shadowLightPosition;
uniform int frameCounter;
uniform int entityId;
uniform int currentRenderedItemId;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec3 cameraPosition;
uniform vec4 entityColor;
uniform float biome_snowy;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_arid;

#include "/include/lighting.glsl"
#ifdef EMISSIVE_MASKING
#include "/include/emissive_mask.glsl"
#endif
#if defined(END_SHADER) && defined(END_EVENT_ENABLED)
#include "/include/end_event.glsl"
#endif

in vec2 texcoord;
in vec4 glcolor;
in float viewDistance;
in float skylight;
in float blocklight;
in float emissive;
flat in float emissiveType;
in vec4 shadowPos;
in vec4 caveShadowCoord;
flat in vec4 caveShadowCoordFlat;
in vec3 normal;
in vec3 worldPos;
in float nametagHolo;

#include "/include/fog_color.glsl"

#include "/include/noise.glsl"

void main() {

#ifdef EMISSIVE
discard;
#endif

vec4 color = texture(gtexture, texcoord) * glcolor;

float emissiveStrength = emissive;

if (emissiveStrength > 0.5) {
vec3 rawTex = texture(gtexture, texcoord).rgb;
float rawLuma = dot(rawTex, vec3(0.299, 0.587, 0.114));
float rawMax = max(rawTex.r, max(rawTex.g, rawTex.b));
float rawMin = min(rawTex.r, min(rawTex.g, rawTex.b));
float rawSat = (rawMax - rawMin) / max(rawMax, 0.001);
if (rawLuma > 0.65 && rawSat < 0.3) emissiveStrength = 0.0;
}

#ifdef TEXTURE_PALETTE_ENABLED
{
float levels = float(TEXTURE_PALETTE_LEVELS);
color.rgb = floor(color.rgb * levels) / levels;
}
#endif

color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);

if (color.a < alphaTestRef) {
discard;
}

#ifdef CHUNK_FADE_OUT_ENABLED
#ifndef DISTANT_HORIZONS
if (!isForcedNetherBiome(biome) && !isForcedEndBiome(biome)) {
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
}
#endif
#endif

vec3 entityRawColor = color.rgb;

{
if (entityId == 100) {

} else if (entityId == 101) {
if (color.r > 0.8 && color.g < 0.2 && color.b < 0.2) emissiveStrength = 1.0 * PROCEDURAL_GLOW_STRENGTH;
} else if (entityId == 102) {

} else if (entityId == 103) {
if (color.r > 0.7 && color.g > 0.8 && color.b < 0.4) emissiveStrength = 0.8 * PROCEDURAL_GLOW_STRENGTH;
} else if (entityId == 104) {
if (color.r > 0.8 && color.g > 0.9 && color.b > 0.9) emissiveStrength = 0.9 * PROCEDURAL_GLOW_STRENGTH;
} else if (entityId == 105) {
emissiveStrength = 0.7 * PROCEDURAL_GLOW_STRENGTH;
} else if (entityId == 106) {
if (color.r > 0.5 && color.g > 0.8 && color.b > 0.9) emissiveStrength = 0.8 * PROCEDURAL_GLOW_STRENGTH;
} else if (entityId == 107) {
if (color.r > 0.6 && color.g < 0.3 && color.b < 0.3) emissiveStrength = 0.9 * PROCEDURAL_GLOW_STRENGTH;
} else if (entityId == 108) {
if (color.r > 0.9 && color.g > 0.5 && color.b < 0.6) emissiveStrength = 0.6 * PROCEDURAL_GLOW_STRENGTH;
} else if (entityId == 109) {
emissiveStrength = 1.0;
}
}

bool isHeldEmissiveItem = (currentRenderedItemId >= 10020 && currentRenderedItemId <= 10059) || currentRenderedItemId == 10087;
bool heldPixelIsEmissive = false;
float heldEmissiveMask = 0.0;
if (isHeldEmissiveItem) {
#ifdef EMISSIVE_MASKING
int heldEt = currentRenderedItemId - 10020;
heldEmissiveMask = getEmissiveMask(heldEt, entityRawColor);
heldPixelIsEmissive = (heldEmissiveMask >= 0.05);
#else
heldPixelIsEmissive = true;
#endif
}

vec3 entityEmissiveVisible = vec3(0.0);
vec3 entityEmissiveBloom = vec3(0.0);

if (heldPixelIsEmissive) {

entityEmissiveVisible = entityRawColor * EMISSIVE_BRIGHTNESS;

#ifdef EMISSIVE_MASKING
entityEmissiveBloom = entityRawColor * EMISSIVE_BRIGHTNESS * clamp(heldEmissiveMask, 0.0, 1.0);
#else
entityEmissiveBloom = vec3(1.0, 0.85, 0.4) * EMISSIVE_BRIGHTNESS;
if (currentRenderedItemId == 10021 || currentRenderedItemId == 10043) {
entityEmissiveBloom = vec3(0.3, 0.7, 1.0) * EMISSIVE_BRIGHTNESS;
}
int cid = currentRenderedItemId;
if (cid == 10023 || cid == 10024 || cid == 10025 ||
cid == 10027 || cid == 10028 || cid == 10029 || cid == 10031 ||
cid == 10032 || cid == 10033 || cid == 10034 ||
cid == 10040 || cid == 10044 ||
cid == 10046 || cid == 10047 || cid == 10048 || cid == 10049 ||
cid == 10051 || cid == 10052 || cid == 10053 ||
cid == 10054 || cid == 10055 || cid == 10058 || cid == 10059) {
entityEmissiveBloom = entityRawColor * EMISSIVE_BRIGHTNESS;
}
#endif
emissiveStrength = 1.0;
} else if (isHeldEmissiveItem && !heldPixelIsEmissive) {

emissiveStrength = 0.0;
} else if (emissiveStrength > 0.5 && !isHeldEmissiveItem) {

float entityEmissiveScale = EMISSIVE_BRIGHTNESS * max(emissiveStrength, 1.0);
float entityBloomSeedBoost = 1.25 + 0.75 * max(emissiveStrength, 1.0);
entityEmissiveVisible = entityRawColor;
entityEmissiveBloom = entityRawColor * entityEmissiveScale * ENTITY_EMISSIVE_BLOOM * entityBloomSeedBoost;
}

if (entityId == 109 && emissiveStrength > 0.5) {
entityEmissiveVisible = entityRawColor;
entityEmissiveBloom = entityRawColor * 0.15;
}

if (entityId == 105 && emissiveStrength > 0.5) {
entityEmissiveVisible = entityRawColor;
entityEmissiveBloom = entityRawColor * 0.01;
}

float caveShadowAtten = 1.0;

#ifdef SHADOWS_ENABLED
if (shadowPos.w > 0.5 && emissiveStrength < 0.5 && !isForcedNetherBiome(biome)) {

float dotNL = dot(normal, normalize(shadowLightPosition));

float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);
float r = quartic_length(shadowPos.xy * 2.0 - 1.0);
float distortFactor = r + SHADOW_DISTORTION;

vec3 biasedShadowPos = shadowPos.xyz;
biasedShadowPos.z -= 0.0005;

vec3 shadow = getShadowColorPCFNoEntity(shadowtex1, shadowcolor0, shadowcolor1, biasedShadowPos, distortFactor, dither, 0.0);

float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
shadow = mix(shadow, vec3(1.0), fadeFactor);

float rawShadowVal = dot(shadow, vec3(0.299, 0.587, 0.114));
float entitySkylight = max(skylight, rawShadowVal * 0.95);

shadow = mix(vec3(1.0), shadow, entitySkylight);

shadow = mix(vec3(1.0), shadow, SHADOW_OPACITY);

color.rgb = applyLightingWithShadow(color.rgb, sunAngle, entitySkylight, blocklight, emissiveStrength, shadow, worldPos.y);
color.rgb *= caveShadowAtten;
} else {
color.rgb = applyLightingEmissive(color.rgb, sunAngle, skylight, blocklight, emissiveStrength, worldPos.y);
color.rgb *= caveShadowAtten;
}
#else
{
color.rgb = applyLightingEmissive(color.rgb, sunAngle, skylight, blocklight, emissiveStrength, worldPos.y);
color.rgb *= caveShadowAtten;
}
#endif
#ifdef HANDHELD_LIGHT_ENABLED
if (emissiveStrength < 0.5) color.rgb += getHandheldLightBoost(worldPos, entityRawColor, color.rgb);
#endif

color.rgb *= TERRAIN_BRIGHTNESS;

#ifdef END_SHADER
if (emissiveStrength < 0.5) {
float entBaseDarken = 0.55;
vec3 purpleTint = vec3(0.08, 0.06, 0.35);
float entTintMult = 0.15;
float entColorShift = 0.55;

float entPreserveBlend = 0.0;
vec3 entPreservedLight = vec3(0.0);

#if defined(END_SHADER) && defined(END_EVENT_ENABLED)
float entEventDarkness = getEndEventTerrainDarkness(frameTimeCounter);
if (entEventDarkness > 0.001) {
float bFalloff = getBlocklightFalloff(blocklight, skylight);
vec3 endBlockColor = vec3(END_BLOCKLIGHT_R, END_BLOCKLIGHT_G, END_BLOCKLIGHT_B);
entPreservedLight = entityRawColor * endBlockColor * bFalloff * bFalloff * END_BLOCKLIGHT_BRIGHTNESS * TERRAIN_BRIGHTNESS;

#ifdef HANDHELD_LIGHT_ENABLED
entPreservedLight += getHandheldLightBoost(worldPos, entityRawColor, vec3(0.0)) * TERRAIN_BRIGHTNESS;
#endif

entPreserveBlend = entEventDarkness;
}
entBaseDarken = mix(entBaseDarken, 0.02, entEventDarkness);
entTintMult = mix(entTintMult, 0.0, entEventDarkness);
entColorShift = mix(entColorShift, 0.0, entEventDarkness);
#endif

color.rgb *= entBaseDarken;
color.rgb += purpleTint * entTintMult;
color.rgb = mix(color.rgb, color.rgb * vec3(0.55, 0.58, 1.35), entColorShift);

color.rgb += entPreservedLight * entPreserveBlend;
}
#endif

if (heldPixelIsEmissive) {

color.rgb = entityRawColor * EMISSIVE_BRIGHTNESS;
} else if (emissiveStrength > 0.5) {
color.rgb = max(color.rgb, entityEmissiveVisible);
}

if (isEyeInWater != 1) {
float denom = max(fogEnd - fogStart, 0.0001);
float fogFactor = clamp((fogEnd - viewDistance) / denom, 0.0, 1.0);
color.rgb = mix(getTimeBasedFogColor(), color.rgb, fogFactor);
}

gl_FragData[0] = vec4(color.rgb, 1.0);
gl_FragData[1] = vec4(1.0, emissiveStrength, 0.0, 0.5);
gl_FragData[2] = vec4(entityEmissiveBloom, 1.0);
gl_FragData[3] = vec4(entityEmissiveBloom, 1.0);
}
