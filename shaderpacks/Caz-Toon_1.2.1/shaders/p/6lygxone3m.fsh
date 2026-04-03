/* RENDERTARGETS: 0,1,3,4,5 */

#include "/settings.glsl"
#include "/include/shadow.glsl"
uniform float biome_swamp;

uniform sampler2D gtexture;
uniform sampler2D shadowtex0;
uniform float alphaTestRef;
uniform float sunAngle;
uniform int currentRenderedItemId;
uniform int isEyeInWater;
uniform vec3 shadowLightPosition;
uniform int frameCounter;
#include "/include/lighting.glsl"
#ifdef EMISSIVE_MASKING
#include "/include/emissive_mask.glsl"
#endif

#ifdef END_SHADER
uniform float frameTimeCounter;
#ifdef END_EVENT_ENABLED
#include "/include/end_event.glsl"
#endif
#endif

in vec2 texcoord;
in vec4 glcolor;
in float skylight;
in float blocklight;
in float viewDistance;
in vec4 shadowPos;
in vec3 normal;
in vec3 worldPos;

void main() {
vec4 color = texture(gtexture, texcoord) * glcolor;

#ifdef TEXTURE_PALETTE_ENABLED
{
float levels = float(TEXTURE_PALETTE_LEVELS);
color.rgb = floor(color.rgb * levels) / levels;
}
#endif

if (color.a < alphaTestRef) {
discard;
}

vec3 rawColor = color.rgb;

bool isEmissiveItem = (currentRenderedItemId >= 10020 && currentRenderedItemId <= 10059) || currentRenderedItemId == 10087;

#ifdef EMISSIVE_MASKING
float handMask = 0.0;
bool pixelIsEmissive = false;
if (isEmissiveItem) {
int handEt = (currentRenderedItemId == 10087) ? 46 : currentRenderedItemId - 10020;
handMask = getEmissiveMask(handEt, rawColor);
pixelIsEmissive = (handMask >= 0.05);
}
#else
bool pixelIsEmissive = isEmissiveItem;
#endif

#ifdef END_SHADER
if (!pixelIsEmissive) {

#ifdef SHADOWS_ENABLED
if (shadowPos.w > 0.5) {
float dotNL = dot(normal, normalize(shadowLightPosition));
float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);
float r = quartic_length(shadowPos.xy * 2.0 - 1.0);
float distortFactor = r + SHADOW_DISTORTION;

float selfShadowBias = 0.003;
float slopeBias = (SHADOW_NORMAL_BIAS * 0.0001) * (1.1 - dotNL);
float totalBias = selfShadowBias + slopeBias;

vec3 biasedShadowPos = shadowPos.xyz;
biasedShadowPos.z -= totalBias;

vec3 shadow = getShadowColorPCF(shadowtex0, shadowcolor0, biasedShadowPos, distortFactor, dither, 0.0);

float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
shadow = mix(shadow, vec3(1.0), fadeFactor);
float shadowSkylight = max(skylight, 0.15);
shadow = mix(vec3(1.0), shadow, shadowSkylight);
shadow = mix(vec3(1.0), shadow, SHADOW_OPACITY);

float handShadowVal = dot(shadow, vec3(0.299, 0.587, 0.114));
float handSkylight = skylight;
color.rgb = applyLightingWithShadow(color.rgb, sunAngle, handSkylight, blocklight, 0.0, shadow, worldPos.y);
} else {
color.rgb = applyLighting(color.rgb, sunAngle, skylight, blocklight, worldPos.y);
}
#else
color.rgb = applyLighting(color.rgb, sunAngle, skylight, blocklight, worldPos.y);
#endif

float handDarken = mix(0.15, 1.0, smoothstep(0.0, 0.5, skylight));
color.rgb *= handDarken;

float baseDarken = 0.55;
float tintMult = 0.15;

float preserveBlend = 0.0;
vec3 preservedLight = vec3(0.0);

#if defined(END_SHADER) && defined(END_EVENT_ENABLED)
float eventDarkness = getEndEventTerrainDarkness(frameTimeCounter);
if (eventDarkness > 0.001) {
float bFalloff = getBlocklightFalloff(blocklight, skylight);
vec3 endBlockColor = vec3(END_BLOCKLIGHT_R, END_BLOCKLIGHT_G, END_BLOCKLIGHT_B);
preservedLight = rawColor * endBlockColor * bFalloff * bFalloff * END_BLOCKLIGHT_BRIGHTNESS;
preserveBlend = eventDarkness;
}
baseDarken = mix(baseDarken, 0.02, eventDarkness);
tintMult = mix(tintMult, 0.0, eventDarkness);
#endif

color.rgb *= baseDarken;
vec3 purpleTint = vec3(0.08, 0.06, 0.35);
color.rgb += purpleTint * tintMult;

color.rgb += preservedLight * preserveBlend;

#ifdef HANDHELD_LIGHT_ENABLED
color.rgb += getHandheldLightBoost(worldPos, rawColor, color.rgb);
#endif
} else {

color.rgb = rawColor * EMISSIVE_BRIGHTNESS * END_EMISSIVE_BOOST;
}
#else

if (!pixelIsEmissive) {

#ifdef SHADOWS_ENABLED
if (shadowPos.w > 0.5) {
float dotNL = dot(normal, normalize(shadowLightPosition));
float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);
float r = quartic_length(shadowPos.xy * 2.0 - 1.0);
float distortFactor = r + SHADOW_DISTORTION;

float selfShadowBias = 0.003;
float slopeBias = (SHADOW_NORMAL_BIAS * 0.0001) * (1.1 - dotNL);
float totalBias = selfShadowBias + slopeBias;

vec3 biasedShadowPos = shadowPos.xyz;
biasedShadowPos.z -= totalBias;

vec3 shadow = getShadowColorPCF(shadowtex0, shadowcolor0, biasedShadowPos, distortFactor, dither, 0.0);

float fadeFactor = smoothstep(SHADOW_DISTANCE * 0.8, SHADOW_DISTANCE, viewDistance);
shadow = mix(shadow, vec3(1.0), fadeFactor);
float shadowSkylight = max(skylight, 0.15);
shadow = mix(vec3(1.0), shadow, shadowSkylight);
shadow = mix(vec3(1.0), shadow, SHADOW_OPACITY);

float handShadowVal = dot(shadow, vec3(0.299, 0.587, 0.114));
float handSkylight = skylight;
color.rgb = applyLightingWithShadow(color.rgb, sunAngle, handSkylight, blocklight, 0.0, shadow, worldPos.y);
} else {
color.rgb = applyLighting(color.rgb, sunAngle, skylight, blocklight, worldPos.y);
}
#else
color.rgb = applyLighting(color.rgb, sunAngle, skylight, blocklight, worldPos.y);
#endif

#ifdef HANDHELD_LIGHT_ENABLED
color.rgb += getHandheldLightBoost(worldPos, rawColor, color.rgb);
#endif
} else {

color.rgb = rawColor * EMISSIVE_BRIGHTNESS;
}
#endif

float emissiveStrength = pixelIsEmissive ? 1.0 : 0.0;
gl_FragData[0] = color;

gl_FragData[1] = vec4(0.0, emissiveStrength, 0.0, 0.5);

vec3 bloomColor = vec3(0.0);
#ifdef EMISSIVE_MASKING
if (pixelIsEmissive) {
bloomColor = rawColor * EMISSIVE_BRIGHTNESS * clamp(handMask, 0.0, 1.0);
#ifdef END_SHADER
bloomColor *= END_EMISSIVE_BOOST;
#endif
}
#else
if (isEmissiveItem) {

bloomColor = vec3(1.0, 0.85, 0.4) * EMISSIVE_BRIGHTNESS;

if (currentRenderedItemId == 10021 || currentRenderedItemId == 10043) {
bloomColor = vec3(0.3, 0.7, 1.0) * EMISSIVE_BRIGHTNESS;
}

int cid = currentRenderedItemId;
if (cid == 10023 || cid == 10024 || cid == 10025 ||
cid == 10027 || cid == 10028 || cid == 10029 || cid == 10031 ||
cid == 10032 || cid == 10033 || cid == 10034 ||
cid == 10040 ||
cid == 10044 ||
cid == 10046 || cid == 10047 || cid == 10048 || cid == 10049 ||
cid == 10051 || cid == 10052 || cid == 10053 ||
cid == 10054 || cid == 10055 || cid == 10058 || cid == 10059) {
bloomColor = rawColor * EMISSIVE_BRIGHTNESS;
}
#ifdef END_SHADER
bloomColor *= END_EMISSIVE_BOOST;
#endif
}
#endif

gl_FragData[2] = vec4(bloomColor, 1.0);
gl_FragData[3] = vec4(0.0);
gl_FragData[4] = vec4(0.0);
}
