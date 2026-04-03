/* RENDERTARGETS: 0,14 */

const bool colortex14Clear = false;

#include "/settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex14;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D dhDepthTex;
uniform sampler2D vxDepthTexTrans;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform mat4 dhProjectionInverse;
uniform mat4 vxProjInv;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform sampler2D shadowtex0;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float sunAngle;
uniform float dhFarPlane;
uniform float dhNearPlane;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float blindness;
uniform float nightVision;

uniform int isEyeInWater;
uniform int biome;
uniform int biome_category;
uniform int worldDay;
uniform int worldTime;
uniform int frameCounter;
uniform int renderVanillaClouds;

#define FRAME_TIME_COUNTER_DECLARED
uniform float frameTimeCounter;
#define RAIN_STRENGTH_DECLARED
uniform float rainStrength;
uniform float thunderStrength;

uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_snowy;
uniform float biome_arid;
uniform float biome_beach;
uniform float biome_ocean;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform ivec2 eyeBrightnessSmooth;

in vec2 texcoord;

#include "/include/biome_overrides.glsl"
#include "/include/depth_utils.glsl"
#include "/include/water_color.glsl"
#include "/include/ocean_waves.glsl"
#include "/include/color_utils.glsl"
#include "/include/sky_timeline.glsl"
#include "/include/noise.glsl"
#include "/include/shadow.glsl"

layout(std430, binding = 0) buffer persistentBuffer {
float storedExposure;
float smoothBeach;
float smoothSwamp;
float smoothJungle;
float smoothSnowy;
float smoothArid;
float storedScreenSkylight;
float smoothOcean;
float smoothNetherFogR;
float smoothNetherFogG;
float smoothNetherFogB;
};

#define SEA_LEVEL_OFFSET_DEFAULT 63
#ifndef SEA_LEVEL_OFFSET
#define SEA_LEVEL_OFFSET SEA_LEVEL_OFFSET_DEFAULT
#endif

#ifdef CLOUDS_3D_ENABLED
#include "/include/volumetric_clouds.glsl"
#endif
#ifdef CLOUDS_VANILLA_ENABLED
#include "/include/vanilla_clouds.glsl"
#endif
#include "/include/ilv_reflections.glsl"

#ifdef END_SHADER
#if defined(END_EVENT_ENABLED)
#include "/include/end_event.glsl"
#endif
#ifdef END_SKY_ENABLED
#include "/include/end_sky.glsl"
#endif
#endif

vec3 getHorizonColor();
vec3 getSkyCastHorizonColor();

bool isEndDimension() {
#ifdef END_SHADER
return true;
#else
#ifdef CAT_THE_END
return biome_category == CAT_THE_END;
#else
return isForcedEndBiome(biome);
#endif
#endif
}

bool isSkylessWorldHeuristic() {
float sunLen = length(sunPosition);
float shadowLen = length(shadowLightPosition);
vec3 skyMax = max(skyColor, vec3(0.0));
vec3 fogMax = max(fogColor, vec3(0.0));
float skyPeak = max(max(skyMax.r, skyMax.g), skyMax.b);
float fogPeak = max(max(fogMax.r, fogMax.g), fogMax.b);
bool noDirectionalLight = (sunLen < 0.001 && shadowLen < 0.001);
bool darkFlatAtmosphere = (skyPeak < 0.06 && fogPeak < 0.08);
return darkFlatAtmosphere && noDirectionalLight;
}

vec2 getSunScreenUV() {
vec3 sunDirView = normalize(shadowLightPosition);
vec3 sunPosView = sunDirView * 1000.0;
vec4 clip = gbufferProjection * vec4(sunPosView, 1.0);
if (clip.w <= 0.00001) return vec2(-1.0);
vec2 ndc = clip.xy / clip.w;
return ndc * 0.5 + 0.5;
}

vec4 sampleFogSmooth(sampler2D tex, vec2 uv) {
vec4 fog = max(texture(tex, uv), vec4(0.0));
fog.rgb = fog.rgb * fog.rgb;
fog.rgb = fog.rgb * fog.rgb;
fog.rgb *= 32.0;
return fog;
}

vec3 getWorldPos(vec2 uv, float depth) {
vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
vec4 viewPos = gbufferProjectionInverse * clipPos;
viewPos /= viewPos.w;
vec4 worldPos = gbufferModelViewInverse * viewPos;
return worldPos.xyz + cameraPosition;
}

vec3 getWorldPosDH(vec2 uv, float depth) {
float linearDepth = linearizeDepthDH(depth);
vec4 clipPos = vec4(uv * 2.0 - 1.0, -1.0, 1.0);
vec4 viewPosNear = gbufferProjectionInverse * clipPos;
viewPosNear /= viewPosNear.w;
vec3 viewDir = normalize(viewPosNear.xyz);
vec3 viewPos = viewDir * (linearDepth / max(abs(viewDir.z), 0.001));
vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
return worldPos.xyz + cameraPosition;
}

#include "/include/distance_fog.glsl"

#if (defined(WATER_REFLECTIONS_ENABLED) || defined(MATERIAL_REFLECTIONS_ENABLED)) && defined(WALL_RUNOFF_ENABLED)
float runoffHash(vec2 p) {
return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float runoffNoise(vec2 p) {
vec2 i = floor(p);
vec2 f = fract(p);
f = f * f * (3.0 - 2.0 * f);
float a = runoffHash(i);
float b = runoffHash(i + vec2(1.0, 0.0));
float c = runoffHash(i + vec2(0.0, 1.0));
float d = runoffHash(i + vec2(1.0, 1.0));
return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
#endif

void main() {
ivec2 texelcoord = ivec2(gl_FragCoord.xy);

vec4 opaqueData = texelFetch(colortex0, texelcoord, 0);
vec3 opaqueColor = opaqueData.rgb;
float cloudAlpha = opaqueData.a;
float cloudMask = cloudAlpha;

vec4 translucentData = texelFetch(colortex7, texelcoord, 0);
vec4 maskData = texelFetch(colortex1, texelcoord, 0);
vec4 glassTint = texelFetch(colortex4, texelcoord, 0);
vec4 reflData = texelFetch(colortex5, texelcoord, 0);

float depth0 = texelFetch(depthtex0, texelcoord, 0).r;
float depth1 = texelFetch(depthtex1, texelcoord, 0).r;
float depth2 = texelFetch(depthtex2, texelcoord, 0).r;
float dhDepth = texelFetch(dhDepthTex, texelcoord, 0).r;

float depthOpaque = depth1;
float depthNoHand = depth2;
float depthAll = depth0;
bool isSky = (depthOpaque >= 0.9999);
bool isHandPixel = (depthAll < depthNoHand - 0.000001) && (abs(depthAll - depthOpaque) < 0.000001);
bool isHandEarly = (depth0 < depth2 - 0.000001) && (abs(depth0 - depth1) < 0.000001);

vec3 color = opaqueColor;

if (isHandPixel) {

float transAlpha = translucentData.a;
if (transAlpha > 0.001 && !isHandEarly) {
color = color * (1.0 - transAlpha) + translucentData.rgb;
}
gl_FragData[0] = vec4(color, cloudAlpha);
gl_FragData[1] = vec4(0.0);
return;
}

float transAlpha = translucentData.a;
bool entityInFront = !isHandPixel && (maskData.a > 0.01 && maskData.a < 0.99);
vec4 waterData = reflData;
bool isGlassC17 = (glassTint.a > 0.45);
bool particleOverSky = isSky && (depthAll < 0.9999) && (waterData.y < 0.5) && !isGlassC17;

#if defined(WATER_REFLECTIONS_ENABLED) || defined(MATERIAL_REFLECTIONS_ENABLED)

bool hasReflection = (reflData.z > 0.001 || reflData.w > 0.001) && !isHandEarly;

float nx = reflData.z * 2.0 - 1.0;
float ny = reflData.w * 2.0 - 1.0;
float nz = sqrt(max(1.0 - nx * nx - ny * ny, 0.0));
vec3 decodedWorldNormal = vec3(nx, ny, nz);
bool isHorizontalSurface = (decodedWorldNormal.y > 0.5);

bool isWaterTagged = (reflData.y > 0.9);

float voxyMarker = maskData.a;
bool isEntityOrHand = (voxyMarker > 0.01 && voxyMarker < 0.99) || isHandEarly;

bool isWater = hasReflection && isWaterTagged && !isEntityOrHand;
bool isVoxyLod = (voxyMarker > 0.999);
bool isVoxyWater = hasReflection && isWaterTagged && isVoxyLod && !isWater;
if (isVoxyWater) isWater = true;
bool isDhWater = hasReflection && isWaterTagged && !isWater && (depth0 >= 0.9999) && (dhDepth < 0.9999);
bool isMaterialRefl = hasReflection && !isWater && !isDhWater;

bool isIceBlock = (glassTint.a > 0.75 && glassTint.a < 0.85);

if (isIceBlock) {
isWater = false;
isDhWater = false;
isMaterialRefl = false;
}
bool isGlassOverWater = (isWater || isDhWater) && isGlassC17;
bool isWaterOnly = (isWater || isDhWater) && !isGlassOverWater;

vec3 preSpecularColor = color;

float beachWaveHeight = reflData.x;
float beachWaveHeightSm = beachWaveHeight;
if (isWater || isDhWater) {
float whL1 = texelFetch(colortex5, texelcoord + ivec2(-1, 0), 0).x;
float whR1 = texelFetch(colortex5, texelcoord + ivec2( 1, 0), 0).x;
float whU1 = texelFetch(colortex5, texelcoord + ivec2(0, -1), 0).x;
float whD1 = texelFetch(colortex5, texelcoord + ivec2(0,  1), 0).x;
beachWaveHeightSm = (beachWaveHeight + whL1 + whR1 + whU1 + whD1) * 0.2;
}

float waveBiome = max(biome_beach, biome_ocean);

#ifdef WATER_REFLECTION_DEBUG
if (isWater) color = vec3(1.0, 0.0, 1.0);
if (isDhWater) color = vec3(1.0, 1.0, 0.0);
if (isMaterialRefl) color = vec3(0.0, 1.0, 1.0);
#else

#if 0

#ifdef WATER_REFLECTIONS_ENABLED
if (isWater && isEyeInWater != 1) {
if (depth0 < 1.0) {
vec3 viewPos;
if (isVoxyWater) {
vec4 vClip = dhProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
viewPos = vClip.xyz / vClip.w;
} else {
vec3 screenPos = vec3(texcoord, depth0);
viewPos = ilv_screenToView(screenPos);
}
vec3 waterWorldN = decodedWorldNormal;
bool isSideWater = (waterWorldN.y < 0.5);
if (isSideWater) waterWorldN = vec3(0.0, 1.0, 0.0);
waterWorldN = normalize(mix(vec3(0.0, 1.0, 0.0), waterWorldN, 0.05));
vec3 normal = normalize(mat3(gbufferModelView) * waterWorldN);

vec2 waveOffset = vec2(0.0);
#ifdef WATER_WAVES_ENABLED
{
ivec2 tcMax = ivec2(viewWidth - 1.0, viewHeight - 1.0);
ivec2 tcL = clamp(texelcoord + ivec2(-1, 0), ivec2(0), tcMax);
ivec2 tcR = clamp(texelcoord + ivec2( 1, 0), ivec2(0), tcMax);
ivec2 tcU = clamp(texelcoord + ivec2(0, -1), ivec2(0), tcMax);
ivec2 tcD = clamp(texelcoord + ivec2(0,  1), ivec2(0), tcMax);
float whL = texelFetch(colortex5, tcL, 0).x;
float whR = texelFetch(colortex5, tcR, 0).x;
float whU = texelFetch(colortex5, tcU, 0).x;
float whD = texelFetch(colortex5, tcD, 0).x;
vec2 hGrad = vec2(whR - whL, whD - whU);
float waveDist = max(length(viewPos), 1.0);
float distScale = 1.0 / waveDist;
waveOffset = vec2(0.0);
}
#endif

TimeWeightsSimple reflTS = getTimeWeightsSimple(sunAngle);
float reflDay = reflTS.day + reflTS.twilight;
float reflNight = reflTS.night + reflTS.blueHour;
float reflTOD = mix(0.15, 1.0, reflDay) + reflNight * 0.85;
float reflectionStrength = mix(WATER_REFLECTION_AMOUNT, max(WATER_REFLECTION_AMOUNT, 0.85), reflNight) * reflTOD * WATER_OPACITY;
float crestReflectCut = 1.0;
reflectionStrength *= crestReflectCut;
float waterSkylight = texelFetch(colortex1, texelcoord, 0).b;
vec2 lmcoord = vec2(0.0, waterSkylight);

vec3 reflDirView = reflect(normalize(viewPos), normal);
vec3 reflDirWorld = mat3(gbufferModelViewInverse) * reflDirView;

float ssrDist = length(viewPos);
float ssrFade = 1.0 - smoothstep(float(SSR_RENDER_DISTANCE) * 0.8, float(SSR_RENDER_DISTANCE), ssrDist);

if (isSideWater) {

vec3 sideNormalWorld = decodedWorldNormal;
sideNormalWorld.y = 0.0;
float sideNLen = length(sideNormalWorld);
if (sideNLen < 0.001) sideNormalWorld = vec3(0.0, 0.0, 1.0);
else sideNormalWorld /= sideNLen;

vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
vec3 viewDirWorld = normalize(worldPos);
vec3 sideReflWorld = reflect(viewDirWorld, sideNormalWorld);
sideReflWorld.y += 0.15;

float sideNoise = reflData.x;
sideReflWorld.x += (sideNoise - 0.5) * 0.12;
sideReflWorld.y += (sideNoise - 0.5) * 0.08;
sideReflWorld = normalize(sideReflWorld);

vec3 sideSkyCol;
if (sideReflWorld.y > 0.0) {
vec3 sideReflView = normalize(mat3(gbufferModelView) * sideReflWorld);
sideSkyCol = ilv_getSkyColor(sideReflView, worldPos + cameraPosition) * 0.8;
} else {
vec3 horizDir = normalize(vec3(sideReflWorld.x, 0.001, sideReflWorld.z));
vec3 horizView = normalize(mat3(gbufferModelView) * horizDir);
sideSkyCol = ilv_getSkyColor(horizView, worldPos + cameraPosition) * 0.8;
}

float sideSkyGate = smoothstep(13.0 / 15.0, 14.0 / 15.0, waterSkylight);
reflectionStrength *= sideSkyGate;

vec3 sideNormalPerturbed = sideNormalWorld;
sideNormalPerturbed.y += (sideNoise - 0.5) * 0.1;
sideNormalPerturbed.x += (sideNoise - 0.5) * 0.05;
sideNormalPerturbed = normalize(sideNormalPerturbed);
vec3 sideNormalView = normalize(mat3(gbufferModelView) * sideNormalPerturbed);
vec2 sideWaveOffset = vec2((sideNoise - 0.5) * 0.008, (sideNoise - 0.5) * 0.015);
vec3 preRefl = color;
ilv_addReflection(color, viewPos, sideNormalView, lmcoord, reflectionStrength * max(ssrFade, 0.001), sideWaveOffset);
vec3 ssrDeltaLocal = color - preRefl;
color = preRefl;
color += ssrDeltaLocal * WATER_BRIGHTNESS;
float ssrHit = clamp(length(ssrDeltaLocal) * 5.0, 0.0, 1.0);
color = mix(mix(color, sideSkyCol, reflectionStrength), color, ssrHit);

{
vec3 sideN = normalize(mat3(gbufferModelView) * sideNormalWorld);
sideN = normalize(sideN + vec3((sideNoise - 0.5) * 0.5, (sideNoise - 0.5) * 0.5, 0.0));
vec3 sideL = normalize(shadowLightPosition);
vec3 sideV = normalize(-viewPos);
vec3 sideH = normalize(sideV + sideL);
float sideNdotH = max(dot(sideN, sideH), 0.0);
float sideSpec = smoothstep(0.985, 0.995, sideNdotH);
TimeWeightsSimple sideSpecTS = getTimeWeightsSimple(sunAngle);
float sideDayFactor = sideSpecTS.day + sideSpecTS.twilight * 0.7;
float sideSunsetBoost = 1.0 + sideSpecTS.twilight * 2.0;
float sideGlow = sideSpec * sideDayFactor * waterSkylight * sideSunsetBoost;
vec3 sideGlowCol = mix(vec3(1.0, 0.95, 0.85),
vec3(SUNSET_HORIZON_R, SUNSET_HORIZON_G, SUNSET_HORIZON_B), sideSpecTS.twilight);
vec3 sideShadowScenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
vec4 sideShadowClip = shadowProjection * shadowModelView * vec4(sideShadowScenePos, 1.0);
vec3 sideShadowDistorted = distortShadowClipPos(sideShadowClip.xyz / sideShadowClip.w);
vec3 sideShadowScreen = sideShadowDistorted * 0.5 + 0.5;
float sideShadow = 0.0;
if (sideShadowScreen.x > 0.0 && sideShadowScreen.x < 1.0 && sideShadowScreen.y > 0.0 && sideShadowScreen.y < 1.0) {
float sideShadowDepth = texture(shadowtex0, sideShadowScreen.xy).r;
sideShadow = step(sideShadowScreen.z - 0.001, sideShadowDepth);
}
preSpecularColor = color;
color += sideGlowCol * sideGlow * WATER_SPECULAR_INTENSITY * sideShadow;
}
} else {

vec3 preRefl = color;
ilv_addReflection(color, viewPos, normal, lmcoord, reflectionStrength * max(ssrFade, 0.001), waveOffset);
vec3 reflDelta = color - preRefl;
float wb = WATER_BRIGHTNESS;
color = preRefl + reflDelta * wb;

vec3 topL = normalize(shadowLightPosition);
vec3 topV = normalize(-viewPos);
vec3 topWorldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
float topWt = frameTimeCounter * WATER_WAVE_SPEED;

#define SPEC_HASH(p) fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453)
vec3 sp1 = vec3(topWorldPos.xz * WATER_WAVE_SCALE * 0.4, topWt * 0.5);
vec3 si1 = floor(sp1); vec3 sf1 = fract(sp1);
sf1 = sf1 * sf1 * (3.0 - 2.0 * sf1);
float sn1 = mix(mix(mix(SPEC_HASH(si1), SPEC_HASH(si1+vec3(1,0,0)), sf1.x),
mix(SPEC_HASH(si1+vec3(0,1,0)), SPEC_HASH(si1+vec3(1,1,0)), sf1.x), sf1.y),
mix(mix(SPEC_HASH(si1+vec3(0,0,1)), SPEC_HASH(si1+vec3(1,0,1)), sf1.x),
mix(SPEC_HASH(si1+vec3(0,1,1)), SPEC_HASH(si1+vec3(1,1,1)), sf1.x), sf1.y), sf1.z);
vec3 sp2 = vec3(topWorldPos.xz * WATER_WAVE_SCALE * 0.9, topWt * 1.2) + vec3(17.0);
vec3 si2 = floor(sp2); vec3 sf2 = fract(sp2);
sf2 = sf2 * sf2 * (3.0 - 2.0 * sf2);
float sn2 = mix(mix(mix(SPEC_HASH(si2), SPEC_HASH(si2+vec3(1,0,0)), sf2.x),
mix(SPEC_HASH(si2+vec3(0,1,0)), SPEC_HASH(si2+vec3(1,1,0)), sf2.x), sf2.y),
mix(mix(SPEC_HASH(si2+vec3(0,0,1)), SPEC_HASH(si2+vec3(1,0,1)), sf2.x),
mix(SPEC_HASH(si2+vec3(0,1,1)), SPEC_HASH(si2+vec3(1,1,1)), sf2.x), sf2.y), sf2.z);
vec3 sp3 = vec3(topWorldPos.xz * WATER_WAVE_SCALE * 1.8, topWt * 2.0) + vec3(31.0);
vec3 si3 = floor(sp3); vec3 sf3 = fract(sp3);
sf3 = sf3 * sf3 * (3.0 - 2.0 * sf3);
float sn3 = mix(mix(mix(SPEC_HASH(si3), SPEC_HASH(si3+vec3(1,0,0)), sf3.x),
mix(SPEC_HASH(si3+vec3(0,1,0)), SPEC_HASH(si3+vec3(1,1,0)), sf3.x), sf3.y),
mix(mix(SPEC_HASH(si3+vec3(0,0,1)), SPEC_HASH(si3+vec3(1,0,1)), sf3.x),
mix(SPEC_HASH(si3+vec3(0,1,1)), SPEC_HASH(si3+vec3(1,1,1)), sf3.x), sf3.y), sf3.z);
#undef SPEC_HASH

float wx = (sn1 - 0.5) * 0.5 + (sn2 - 0.5) * 0.3 + (sn3 - 0.5) * 0.2;
float wz = (sn2 - 0.5) * 0.5 + (sn3 - 0.5) * 0.3 + (sn1 - 0.5) * 0.2;

vec3 topN = normalize(normal + mat3(gbufferModelView) * vec3(wx * 0.5, 0.0, wz * 0.5));
vec3 topH = normalize(topV + topL);
float topNdotH = max(dot(topN, topH), 0.0);
TimeWeightsSimple topTS = getTimeWeightsSimple(sunAngle);
float topDayFactor = topTS.day + topTS.twilight * 0.7;
float topSunsetBoost = 1.0 + topTS.twilight * 2.0;
float topSpec = smoothstep(0.985, 0.995, topNdotH);
float topGlow = topSpec * topDayFactor * waterSkylight * topSunsetBoost;
vec3 topGlowCol = mix(vec3(1.0, 0.95, 0.85),
vec3(SUNSET_HORIZON_R, SUNSET_HORIZON_G, SUNSET_HORIZON_B), topTS.twilight);

vec3 topShadowScenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
vec4 topShadowClip = shadowProjection * shadowModelView * vec4(topShadowScenePos, 1.0);
vec3 topShadowDistorted = distortShadowClipPos(topShadowClip.xyz / topShadowClip.w);
vec3 topShadowScreen = topShadowDistorted * 0.5 + 0.5;
float topShadow = 0.0;
if (topShadowScreen.x > 0.0 && topShadowScreen.x < 1.0 && topShadowScreen.y > 0.0 && topShadowScreen.y < 1.0) {
float topShadowDepth = texture(shadowtex0, topShadowScreen.xy).r;
topShadow = step(topShadowScreen.z - 0.001, topShadowDepth);
}
float topGlowAmt = topGlow * WATER_SPECULAR_INTENSITY * topShadow;
preSpecularColor = color;
color += topGlowCol * topGlowAmt;
}
}
}

if (isDhWater && isWaterOnly && isEyeInWater != 1) {
vec3 dhWorldNormal = vec3(
reflData.z * 2.0 - 1.0,
reflData.w * 2.0 - 1.0,
0.0
);
dhWorldNormal.z = sqrt(max(1.0 - dhWorldNormal.x * dhWorldNormal.x - dhWorldNormal.y * dhWorldNormal.y, 0.0));
vec3 dhNormalView = normalize(mat3(gbufferModelView) * dhWorldNormal);

vec3 dhScreenPos = vec3(texcoord, dhDepth);
vec3 dhNdc = dhScreenPos * 2.0 - 1.0;
vec4 dhViewH = dhProjectionInverse * vec4(dhNdc, 1.0);
vec3 dhViewPos = dhViewH.xyz / dhViewH.w;

float dhFresnel = 1.0 - abs(dot(normalize(-dhViewPos), dhNormalView));
dhFresnel *= dhFresnel;
dhFresnel *= dhFresnel;
float dhFresnelMod = mix(0.3, 1.0, dhFresnel) * WATER_REFLECTION_FADE;
dhFresnelMod = clamp(dhFresnelMod, 0.0, 1.0);

TimeWeightsSimple dhReflTS = getTimeWeightsSimple(sunAngle);
float dhReflDay = dhReflTS.day + dhReflTS.twilight;
float dhReflNight = dhReflTS.night + dhReflTS.blueHour;
float dhReflTOD = mix(0.15, 1.0, dhReflDay) + dhReflNight * 0.85;

vec3 dhReflDir = reflect(normalize(dhViewPos), dhNormalView);
vec3 dhWorldPos = (gbufferModelViewInverse * vec4(dhViewPos, 1.0)).xyz + cameraPosition;
{
float dhWT = frameTimeCounter * WATER_WAVE_SPEED;
vec2 dhWP = dhWorldPos.xz * WATER_WAVE_SCALE * 2.5;
float dhWX = sin(dhWP.x * 3.0 + dhWP.y * 0.3 + dhWT * 1.5) * 0.5
+ sin(dhWP.x * 5.0 + dhWP.y * 0.5 + dhWT * 2.2) * 0.3
+ sin(dhWP.x * 8.0 + dhWP.y * 0.2 + dhWT * 3.0) * 0.2;
float dhWZ = sin(dhWP.x * 0.3 + dhWP.y * 3.0 + dhWT * 1.3) * 0.5
+ sin(dhWP.x * 0.5 + dhWP.y * 5.0 + dhWT * 2.0) * 0.3;
dhReflDir.x += dhWX * 0.005;
dhReflDir.z += dhWZ * 0.005;
dhReflDir = normalize(dhReflDir);
}
float dhRbTOD = mix(0.20, 1.0, dhReflNight / max(dhReflDay + dhReflNight, 0.001));
float dhRbActive = max(dhReflDay, dhReflNight);
dhRbTOD = mix(0.60, dhRbTOD, dhRbActive);
float dhNightBlend = dhReflNight / max(dhReflDay + dhReflNight, 0.001);
float dhSkyBright = mix(WATER_SKY_BRIGHTNESS_DAY, WATER_SKY_BRIGHTNESS_NIGHT, dhNightBlend);
dhSkyBright = mix(mix(WATER_SKY_BRIGHTNESS_DAY, WATER_SKY_BRIGHTNESS_NIGHT, 0.5), dhSkyBright, dhRbActive);
vec3 dhSkyColor = ilv_getSkyColor(dhReflDir, dhWorldPos) * 1.3;

float dhReflStrength = WATER_REFLECTION_AMOUNT * dhReflTOD * dhFresnelMod * WATER_SKY_REFLECTION * WATER_OPACITY;
float dhCrestReflectCut = 1.0;
dhReflStrength *= dhCrestReflectCut;
float dhSkylight = texelFetch(colortex1, texelcoord, 0).b;
dhReflStrength *= smoothstep(13.0 / 15.0, 14.0 / 15.0, dhSkylight);
dhReflStrength = clamp(dhReflStrength, 0.0, 1.0);
color = mix(color, dhSkyColor, dhReflStrength);
}
#endif

ssrDelta = color - preSSR;

ssrPreSpecularColor = preSpecularColor;

color = preSSR;

preSpecularColor = preSSR;

#endif
#endif
#endif

if (isEyeInWater != 1) {
vec2 cloudUV = texcoord;
bool isWaterSide = (waterData.y > 0.9) && (waterData.w * 2.0 - 1.0 < 0.5);
if (isWaterSide) {
float sideNoise = waterData.x;
vec2 refrOffset = vec2((sideNoise - 0.5) * 0.8, (sideNoise - 0.5) * 1.2);
float refrPx = 14.0 / max(viewWidth, 1.0);
cloudUV += refrOffset * refrPx;
cloudUV = clamp(cloudUV, vec2(0.0), vec2(1.0));
}
vec4 cloudData = texture(colortex8, cloudUV);
cloudData.a *= 1.0 - smoothSwamp;
cloudData.rgb *= 1.0 - smoothSwamp;
if (cloudData.a > 0.001 && !entityInFront) {
color = color * (1.0 - cloudData.a) + cloudData.rgb;
}
}

#ifdef OVERWORLD_FOG_ENABLED
if (!entityInFront) {
float darkeningDepth = depthOpaque;
bool darkeningSky = (darkeningDepth >= 0.9999);
if (!darkeningSky) {
float angle = fract(sunAngle);
float dayFactor = smoothstep(0.54, 0.48, angle) * smoothstep(0.96, 0.02, angle);

float treelessBiome = max(smoothArid, max(smoothBeach, smoothOcean));
float darkeningAmount = smoothstep(0.15, 0.5, storedExposure) * dayFactor * (1.0 - treelessBiome);
if (darkeningAmount > 0.01) {
vec4 clipPos = vec4(texcoord * 2.0 - 1.0, darkeningDepth * 2.0 - 1.0, 1.0);
vec4 viewPos = gbufferProjectionInverse * clipPos;
viewPos /= viewPos.w;
vec3 worldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;

vec3 delta = worldPos - cameraPosition;
float dist = length(delta);
float heightAbovePlayer = worldPos.y - cameraPosition.y;

float heightFade = 1.0 - smoothstep(0.0, 10.0, heightAbovePlayer);
float seaLevel = float(SEA_LEVEL_OFFSET);
heightFade *= smoothstep(seaLevel - 5.0, seaLevel, worldPos.y);
vec3 scenePos = worldPos - cameraPosition;
vec4 shadowViewPos = shadowModelView * vec4(scenePos, 1.0);
vec4 shadowClipPos = shadowProjection * shadowViewPos;
vec3 shadowNDC = distortShadowClipPos(shadowClipPos.xyz);
vec3 shadowScreenPos = shadowNDC * 0.5 + 0.5;
float sunlit = 0.0;
if (shadowScreenPos.x > 0.0 && shadowScreenPos.x < 1.0 &&
shadowScreenPos.y > 0.0 && shadowScreenPos.y < 1.0) {
sunlit = step(shadowScreenPos.z - 0.001, texture(shadowtex0, shadowScreenPos.xy).r);
}
float shadowMask = mix(1.0, 0.2, sunlit);

float darkeningFog = smoothstep(50.0, 100.0, dist) * darkeningAmount * heightFade * shadowMask;
darkeningFog = clamp(darkeningFog, 0.0, 0.65);

if (darkeningFog > 0.001) {
vec3 darkeningColor = fogColor;
float luma = dot(darkeningColor, vec3(0.299, 0.587, 0.114));
darkeningColor = mix(vec3(luma), darkeningColor, 15.0);
darkeningColor = max(darkeningColor, vec3(0.0));
darkeningColor *= 0.10;

vec3 jungleColor = vec3(10.0, 50.0, 20.0) / 255.0;
vec3 swampColor  = vec3(20.0, 45.0, 10.0) / 255.0;
vec3 snowyColor  = vec3(37.0, 65.0, 106.0) / 255.0;
vec3 forestColor = vec3(18.0, 30.0, 46.0) / 255.0;

darkeningColor = forestColor;
darkeningColor = mix(darkeningColor, jungleColor, smoothJungle);
darkeningColor = mix(darkeningColor, swampColor, smoothSwamp);
darkeningColor = mix(darkeningColor, snowyColor, smoothSnowy);

color = mix(color, darkeningColor, darkeningFog);
}
}
}
}
#endif

#if defined(CAVE_FOG_ENABLED) && !defined(END_SHADER)
if (isEyeInWater != 1 && !entityInFront && !isForcedNetherBiome(biome)) {
float caveFogSkylight = texelFetch(colortex1, texelcoord, 0).b;
float caveFogGate = 1.0 - smoothstep(1.0 / 15.0, 3.0 / 15.0, caveFogSkylight);

if (caveFogGate > 0.01) {
float caveFogDepth = depthOpaque;
bool caveFogIsSky = (caveFogDepth >= 0.9999);

if (!caveFogIsSky) {
vec4 caveFogClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, caveFogDepth * 2.0 - 1.0, 1.0);
vec3 caveFogViewPos = caveFogClip.xyz / caveFogClip.w;
vec3 caveFogWorldPos = (gbufferModelViewInverse * vec4(caveFogViewPos, 1.0)).xyz + cameraPosition;
float caveFogDist = length(caveFogViewPos);

vec3 caveFogColor = vec3(CAVE_FOG_R, CAVE_FOG_G, CAVE_FOG_B) / 255.0;
vec3 rayDir = normalize(caveFogViewPos);
float rayLen = min(caveFogDist, CAVE_FOG_DISTANCE);

float caveFogTime = frameTimeCounter * CAVE_FOG_SPEED;

float caveFogAccum = 0.0;
int caveFogSteps = 32;
float stepSize = rayLen / float(caveFogSteps);
float dither = fract(sin(dot(gl_FragCoord.xy + vec2(frameCounter * 0.1), vec2(12.9898, 78.233))) * 43758.5453);

for (int i = 0; i < caveFogSteps; i++) {
float t = (float(i) + dither) * stepSize;
vec3 samplePos = cameraPosition + (gbufferModelViewInverse * vec4(rayDir * t, 0.0)).xyz;

float depthRamp = smoothstep(CAVE_FOG_RAMP_START, CAVE_FOG_RAMP_END, t);
if (depthRamp < 0.001) continue;

vec3 wp = samplePos;
wp.x += sin(samplePos.z * 0.04 + caveFogTime * 1.3) * 4.0 + cos(samplePos.y * 0.06 + caveFogTime * 0.7) * 3.0;
wp.y += sin(samplePos.x * 0.05 + caveFogTime * 0.9) * 3.0 + cos(samplePos.z * 0.03 + caveFogTime * 1.1) * 2.5;
wp.z += cos(samplePos.x * 0.04 + caveFogTime * 1.5) * 4.0 + sin(samplePos.y * 0.05 + caveFogTime * 0.6) * 3.0;

float n = noise3D(wp * CAVE_FOG_NOISE_SCALE);
n = clamp((n - 0.3) * 2.5, 0.0, 1.0);

if (n > 0.3) {
float fogStep = smoothstep(0.3, 0.6, n) * CAVE_FOG_DENSITY * depthRamp;
caveFogAccum += fogStep;
}
}

float caveFogAmount = min(caveFogAccum, 1.0) * caveFogGate;
color = mix(color, caveFogColor, caveFogAmount);
}
}
}
#endif

float fogAmount = 0.0;
vec3 savedSunColor = color;

#if defined(NETHER_FOG_ENABLED) || defined(END_FOG_ENABLED) || defined(OVERWORLD_FOG_ENABLED)

bool netherEntityFog = entityInFront && isForcedNetherBiome(biome);
if (!entityInFront || netherEntityFog) {
vec3 fogScatter = vec3(0.0);
float fogTrans = 1.0;
float fogAmountLocal = 0.0;

float fogDepth;
vec3 fogWorldPos;
bool fogIsSky = false;
bool fogFromDH = false;

float vxDepthFog = texture(vxDepthTexTrans, texcoord).r;
bool hasVoxyDepthFog = (vxDepthFog > 0.00001 && vxDepthFog < 0.9999);
bool isVoxyLodPixel = (maskData.a > 0.999);
bool hasDHAtPixel = hasValidDHDepth(dhDepth);

if (netherEntityFog) {
fogDepth = depthOpaque;
fogWorldPos = getWorldPos(texcoord, fogDepth);
fogFromDH = false;
fogIsSky = false;
} else if (hasVoxyDepthFog) {
fogDepth = vxDepthFog;
vec4 vxClip = vxProjInv * vec4(texcoord * 2.0 - 1.0, vxDepthFog * 2.0 - 1.0, 1.0);
vec3 vxView = vxClip.xyz / vxClip.w;
fogWorldPos = (gbufferModelViewInverse * vec4(vxView, 1.0)).xyz + cameraPosition;
fogFromDH = false;
fogIsSky = false;
} else if (depthOpaque < 0.9999 || isVoxyLodPixel) {
fogDepth = depthOpaque;
fogWorldPos = getWorldPos(texcoord, fogDepth);
fogFromDH = false;
float linearOpaque = linearizeDepth(depthOpaque);
float linearDH = hasDHAtPixel ? linearizeDepthDH(dhDepth) : 1e10;
if (hasDHAtPixel && linearDH < linearOpaque) {
fogDepth = dhDepth;
fogWorldPos = getWorldPosDH(texcoord, fogDepth);
fogFromDH = true;
}
fogIsSky = false;
} else if (hasDHAtPixel) {
fogDepth = dhDepth;
fogWorldPos = getWorldPosDH(texcoord, fogDepth);
fogFromDH = true;
fogIsSky = false;
} else {
fogIsSky = true;
fogDepth = 1.0;
vec4 clipPos = vec4(texcoord * 2.0 - 1.0, 0.0, 1.0);
vec4 viewPos = gbufferProjectionInverse * clipPos;
vec3 viewDir = normalize(viewPos.xyz);
vec4 worldDir = gbufferModelViewInverse * vec4(viewDir, 0.0);
fogWorldPos = cameraPosition + worldDir.xyz * far;
fogFromDH = false;
}

vec4 fog = (isEyeInWater == 2) ? vec4(0.0, 0.0, 0.0, 1.0) : computeVolumetricFog(texcoord, fogDepth, fogWorldPos, fogIsSky, fogFromDH);

#ifdef OVERWORLD_FOG_ENABLED
if (isEyeInWater == 1 && !isForcedNetherBiome(biome) && !isEndDimension()) {
fog = vec4(0.0, 0.0, 0.0, 1.0);
}

if (isEyeInWater != 1 && !isForcedNetherBiome(biome) && !isEndDimension()) {
bool isUnderwaterOpaque = fogWorldPos.y < float(SEA_LEVEL_OFFSET);
if (isUnderwaterOpaque) {
float underwaterFogFade = smoothstep(float(SEA_LEVEL_OFFSET) - 4.0, float(SEA_LEVEL_OFFSET) + 1.0, fogWorldPos.y);
fog.rgb *= underwaterFogFade;
fog.a = mix(1.0, fog.a, underwaterFogFade);
}
}
#endif

fogScatter = fog.rgb;
fogTrans = clamp(fog.a, 0.0, 1.0);
fogAmountLocal = clamp(1.0 - fogTrans, 0.0, 1.0);

#ifdef NETHER_FOG_ENABLED
if (isForcedNetherBiome(biome) && fogIsSky) {
vec3 netherSkyFog = getForcedBiomeFogColor(biome, vec3(NETHER_FOG_R, NETHER_FOG_G, NETHER_FOG_B)) * NETHER_BRIGHTNESS;
color = netherSkyFog;
fogAmountLocal = 1.0;
}
#endif

fogAmountLocal *= cloudMask;
fogScatter *= cloudMask;
fogTrans = 1.0 - fogAmountLocal;

if (fogAmountLocal > 0.001) {

bool isEmissive = maskData.g > 0.5;
#ifdef NETHER_FOG_ENABLED
if (isForcedNetherBiome(biome) && isEmissive) {
float emissiveDist = length(fogWorldPos - cameraPosition);
float emissiveFogStart = NETHER_DISTANCE_FOG_START * 1.5;
float emissiveFogResist = 1.0 - smoothstep(emissiveFogStart, float(NETHER_FOG_DISTANCE), emissiveDist);
fogAmountLocal *= mix(1.0, 0.0, emissiveFogResist);
fogScatter *= mix(1.0, 0.0, emissiveFogResist);
fogTrans = 1.0 - fogAmountLocal;
}
#endif

#ifdef END_SHADER

{
float fogTransLocal = 1.0 - fogAmountLocal;
vec3 additiveResult = color * (1.0 - fogAmountLocal * 0.4) + fogScatter;
vec3 standardResult = color * fogTransLocal + fogScatter;

float baseMix = 0.5;
#ifdef END_EVENT_ENABLED
float endBlendDark = getEndEvent(frameTimeCounter).fogDarkness;
baseMix = mix(baseMix, 1.0, endBlendDark);
#endif

color = mix(additiveResult, standardResult, baseMix);
}
#else

color = color * fogTrans + fogScatter;
#endif
fogAmount = max(fogAmount, fogAmountLocal);
}
}
#endif

#if defined(HAZE_FOG_ENABLED) || defined(NETHER_FOG_ENABLED)
{
vec4 haze = max(texture(colortex10, texcoord), vec4(0.0));

#ifdef HAZE_FOG_ENABLED
if (!isForcedNetherBiome(biome)) {
float hazeVxD = texture(vxDepthTexTrans, texcoord).r;
bool hazeHasVoxy = (hazeVxD > 0.00001 && hazeVxD < 0.9999) || (maskData.a > 0.999);
bool hazeIsTrueSky = isSky && !hasValidDHDepth(dhDepth) && !hazeHasVoxy;
if (hazeIsTrueSky) haze = vec4(0.0);
}
#endif
if (haze.a > 0.001 && !entityInFront) {
color = haze.rgb + color * (1.0 - haze.a);
}
}
#endif

#if defined(ATMO_FOG_ENABLED) || defined(UNDERWATER_FOG_ENABLED)
if (isEyeInWater != 1 && !entityInFront) {
vec4 atmoFog = max(texture(colortex9, texcoord), vec4(0.0));
if (atmoFog.a > 0.001) {
color = atmoFog.rgb + color * (1.0 - atmoFog.a);
}
}
#endif

#ifdef WEATHER_FOG_ENABLED
if (!entityInFront) {
vec4 weatherFog = max(texture(colortex11, texcoord), vec4(0.0));
if (weatherFog.a > 0.001) {
color = weatherFog.rgb + color * (1.0 - weatherFog.a);
}
}
#endif

#ifdef END_SHADER
{
bool endIsEmissive = (maskData.g > 0.5) && !entityInFront;
bool endIsTrueSky = isSky && !hasValidDHDepth(dhDepth) && !(maskData.a > 0.999);
if (!endIsEmissive && !endIsTrueSky) {
float baseDarken = 0.73;
vec3 purpleTint = vec3(0.08, 0.06, 0.35);
float tintMult = 0.15;
float colorShift = 0.55;

#ifdef END_EVENT_ENABLED
float eventDarkness = getEndEvent(frameTimeCounter).terrainDarkness;
baseDarken = mix(baseDarken, 0.02, eventDarkness);
tintMult = mix(tintMult, 0.0, eventDarkness);
colorShift = mix(colorShift, 0.0, eventDarkness);
#endif

float entityDarkenScale = entityInFront ? 0.1 : 1.0;
color *= mix(1.0, baseDarken, entityDarkenScale);
color += purpleTint * tintMult * entityDarkenScale;
color = mix(color, color * vec3(0.55, 0.58, 1.35), colorShift * entityDarkenScale);

vec3 endWorldPos;
if (maskData.a > 0.999) {

float endVxD = texture(vxDepthTexTrans, texcoord).r;
if (endVxD > 0.00001 && endVxD < 0.9999) {
vec4 endVxClip = vxProjInv * vec4(texcoord * 2.0 - 1.0, endVxD * 2.0 - 1.0, 1.0);
endWorldPos = (gbufferModelViewInverse * vec4(endVxClip.xyz / endVxClip.w, 1.0)).xyz + cameraPosition;
} else {
vec4 endClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depthOpaque * 2.0 - 1.0, 1.0);
endWorldPos = (gbufferModelViewInverse * vec4(endClip.xyz / endClip.w, 1.0)).xyz + cameraPosition;
}
} else {
vec4 endClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depthOpaque * 2.0 - 1.0, 1.0);
endWorldPos = (gbufferModelViewInverse * vec4(endClip.xyz / endClip.w, 1.0)).xyz + cameraPosition;
}
float depthDarken = entityInFront ? 0.0 : (1.0 - smoothstep(28.0, 53.0, endWorldPos.y));
color *= mix(1.0, 0.25, depthDarken);
}
}
#endif

#if 0
#if defined(WATER_REFLECTIONS_ENABLED) || defined(MATERIAL_REFLECTIONS_ENABLED)

TimeWeightsSimple wsTS = getTimeWeightsSimple(sunAngle);
float wsDay = wsTS.day + wsTS.twilight;
float wsNight = wsTS.night + wsTS.blueHour;
float wsNightFactor = wsNight / max(wsDay + wsNight, 0.001);
float wsActive = max(wsDay, wsNight);
wsNightFactor = mix(0.0, wsNightFactor, wsActive);

if (isWater || isDhWater) {
float lum = dot(color, vec3(0.299, 0.587, 0.114));
float sat = mix(WATER_SATURATION, WATER_SATURATION * WATER_NIGHT_SATURATION, wsNightFactor);
color = mix(vec3(lum), color, sat);
}

#ifdef UNDERWATER_FOG_ENABLED
if ((isWater || isDhWater) && isEyeInWater != 1) {
float beerDepth0 = depth0;
float beerDepth1 = texelFetch(depthtex1, texelcoord, 0).r;

vec4 beerWaterClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, beerDepth0 * 2.0 - 1.0, 1.0);
vec3 beerWaterView = beerWaterClip.xyz / beerWaterClip.w;
vec4 beerTerrainClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, beerDepth1 * 2.0 - 1.0, 1.0);
vec3 beerTerrainView = beerTerrainClip.xyz / beerTerrainClip.w;

float waterThickness = max(length(beerTerrainView) - length(beerWaterView), 0.0);

if (waterThickness < 0.5 && (isVoxyLod || isDhWater)) {
vec3 beerWorldPos = (gbufferModelViewInverse * vec4(beerWaterView, 1.0)).xyz + cameraPosition;
waterThickness = max(float(SEA_LEVEL_OFFSET) - beerWorldPos.y + 2.0, 0.0);
}

vec3 beerAbsorb = vec3(0.009, 0.004, 0.0015);
vec3 beerTrans = exp(-waterThickness * beerAbsorb);
vec3 beerTint = vec3(0.1, 0.4, 0.8);

#ifdef WATER_DEBUG_COLORS_ENABLED
color = vec3(voxyMarker);
if (isVoxyLod) color = vec3(1.0, 0.0, 0.0);
if (isDhWater) color = vec3(0.0, 1.0, 0.0);
if (isVoxyWater) color = vec3(1.0, 1.0, 0.0);
#endif
}
#endif

#ifdef WATER_FOAM_ENABLED
if ((isWater || isDhWater) && isEyeInWater != 1) {
vec3 rfViewPos;
if (isDhWater || isVoxyWater) {
float rfDepthLOD = isDhWater ? dhDepth : depth0;
vec4 rfClipDH = dhProjectionInverse * vec4(texcoord * 2.0 - 1.0, rfDepthLOD * 2.0 - 1.0, 1.0);
rfViewPos = rfClipDH.xyz / rfClipDH.w;
} else {
vec4 rfClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
rfViewPos = rfClip.xyz / rfClip.w;
}
vec3 rfWorldPos = (gbufferModelViewInverse * vec4(rfViewPos, 1.0)).xyz + cameraPosition;
float rft = frameTimeCounter * WATER_WAVE_SPEED;
float rfEps = 0.15;

#define RF_WAVE_RAW(f) (smoothstep(0.15, 0.25, f) * (1.0 - pow(smoothstep(0.25, 1.15, f), 0.45)))
#define RF_WAVE(px) RF_WAVE_RAW(1.0 - fract(px))
#define RF_OWAVE(px) (pow(0.5 + 0.5 * sin((fract(px) - 0.25) * 6.2832), 1.6))
#define RF_SMAX(a, b, k) (max(a, b) + pow(max(k - abs(a - b), 0.0) / k, 3.0) * k * 0.166667)

vec2 rfSlope = vec2(0.0);
bool rfIsSide = (decodedWorldNormal.y < 0.5) && isWaterTagged;

if (rfIsSide) {
float sideRefrNoise = texelFetch(colortex5, texelcoord, 0).x;
rfSlope = vec2((sideRefrNoise - 0.5) * 0.8, (sideRefrNoise - 0.5) * 1.2);
} else if (biome_beach > 0.01 && biome_beach >= biome_ocean) {
float rfwx = rfWorldPos.x * WATER_WAVE_SCALE;
float rfwz = rfWorldPos.z * WATER_WAVE_SCALE;
float rfzOff1 = sin(rfwz * 0.21 + 3.7) * 2.5 + sin(rfwz * 0.53 + 1.2) * 1.3;
float rfzOff2 = sin(rfwz * 0.37 + 5.1) * 1.8 + sin(rfwz * 0.71 + 2.8) * 1.1;
float rfzOff3 = sin(rfwz * 0.62 + 0.9) * 1.2 + sin(rfwz * 0.89 + 4.3) * 0.8;
float rfH = clamp(RF_SMAX(RF_WAVE((rfwx * 0.8 + rfzOff1 - rft) / 6.2832), RF_WAVE((rfwx * 1.8 + rfzOff2 - rft * 1.6) / 6.2832) * 0.55, 0.15), 0.0, 1.0);
rfH += RF_WAVE((rfwx * 4.0 + rfzOff3 - rft * 2.2) / 6.2832) * 0.15 * rfH;
float rfwxp = (rfWorldPos.x + rfEps) * WATER_WAVE_SCALE;
float rfHx = clamp(RF_SMAX(RF_WAVE((rfwxp * 0.8 + rfzOff1 - rft) / 6.2832), RF_WAVE((rfwxp * 1.8 + rfzOff2 - rft * 1.6) / 6.2832) * 0.55, 0.15), 0.0, 1.0);
rfHx += RF_WAVE((rfwxp * 4.0 + rfzOff3 - rft * 2.2) / 6.2832) * 0.15 * rfHx;
float rfwzp = (rfWorldPos.z + rfEps) * WATER_WAVE_SCALE;
float rfzOff1z = sin(rfwzp * 0.21 + 3.7) * 2.5 + sin(rfwzp * 0.53 + 1.2) * 1.3;
float rfzOff2z = sin(rfwzp * 0.37 + 5.1) * 1.8 + sin(rfwzp * 0.71 + 2.8) * 1.1;
float rfzOff3z = sin(rfwzp * 0.62 + 0.9) * 1.2 + sin(rfwzp * 0.89 + 4.3) * 0.8;
float rfHz = clamp(RF_SMAX(RF_WAVE((rfwx * 0.8 + rfzOff1z - rft) / 6.2832), RF_WAVE((rfwx * 1.8 + rfzOff2z - rft * 1.6) / 6.2832) * 0.55, 0.15), 0.0, 1.0);
rfHz += RF_WAVE((rfwx * 4.0 + rfzOff3z - rft * 2.2) / 6.2832) * 0.15 * rfHz;
rfSlope = vec2(rfHx - rfH, rfHz - rfH) / rfEps;
}
#undef RF_WAVE
#undef RF_WAVE_RAW
#undef RF_OWAVE
#undef RF_SMAX

float rfBiomeFactor = max(waveBiome, 0.5);
float rfDist = max(length(rfViewPos), 1.0);
float refrDistFade = 1.0 - smoothstep(30.0, 80.0, rfDist);
float refrBase = (biome_beach > 0.01) ? 18.0 : 14.0;
float refrPx = refrBase * rfBiomeFactor / max(rfDist * 0.02, 0.5);
ivec2 refrCoord = texelcoord + ivec2(rfSlope * refrPx);
refrCoord = clamp(refrCoord, ivec2(0), ivec2(viewWidth - 1.0, viewHeight - 1.0));
float refrDepth = texelFetch(depthtex1, refrCoord, 0).r;
if (refrDepth > depth0 && refrDistFade > 0.01) {
vec3 refrOpaque = texelFetch(colortex0, refrCoord, 0).rgb;
vec4 refrTrans = texelFetch(colortex7, refrCoord, 0);
vec3 refrColor = refrTrans.a > 0.001 ? refrOpaque * (1.0 - refrTrans.a) + refrTrans.rgb : refrOpaque;
color = mix(color, refrColor, 0.95 * refrDistFade);
}
}
#endif

if (false && (isWater || isDhWater) && isWaterOnly && isEyeInWater != 1) {
float wDist;
if (isDhWater) {
vec4 dhClip = dhProjectionInverse * vec4(texcoord * 2.0 - 1.0, dhDepth * 2.0 - 1.0, 1.0);
wDist = -dhClip.z / dhClip.w;
} else {
vec4 wClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
wDist = -wClip.z / wClip.w;
}

float fogDensity = mix(0.025, 2.0, biome_swamp);
float fogMax = mix(0.95, 1.0, biome_swamp);
float uwFogAmount = 1.0 - exp(-wDist * fogDensity);
uwFogAmount = clamp(uwFogAmount, 0.0, fogMax);

if (uwFogAmount > 0.001) {
float uwAngle = fract(sunAngle);
float uwTwilight = smoothstep(0.40, 0.48, uwAngle) * smoothstep(0.55, 0.48, uwAngle)
+ smoothstep(0.94, 1.0, uwAngle) + smoothstep(0.06, 0.0, uwAngle);
if (uwTwilight > 0.001) {
float uwLum = dot(color, vec3(0.299, 0.587, 0.114));
color = mix(color, vec3(uwLum), uwTwilight * 0.6);
}
vec3 beachTint = biomeWaterColor(sunAngle, 1.0, 0.0, 0.0, 0.0, 0.0);
vec3 swampTint = vec3(0.04, 0.08, 0.02);
vec3 uwWaterTint = mix(beachTint, swampTint, biome_swamp);
color *= mix(vec3(1.0), uwWaterTint * 3.0, uwFogAmount);
color += uwWaterTint * uwFogAmount;
}
}

#ifdef SWAMP_SNAKE_LIGHT_ENABLED
if ((isWater || isDhWater) && isEyeInWater != 1 && biome_swamp > 0.01) {
float waterSurfDepth = isDhWater ? dhDepth : depth0;
vec3 surfViewPos = ilv_screenToView(vec3(texcoord, waterSurfDepth));
vec3 surfWorldPos = (gbufferModelViewInverse * vec4(surfViewPos, 1.0)).xyz + cameraPosition;

float st = frameTimeCounter;
vec3 snakeAnchor = vec3(
floor(cameraPosition.x / 16.0) * 16.0 + 8.0,
surfWorldPos.y,
floor(cameraPosition.z / 16.0) * 16.0 + 8.0
);

vec3 viewDir = normalize(surfWorldPos - cameraPosition);
float snakeGlow = 0.0;
int steps = 6;
float maxDist = 6.0;
float stepLen = maxDist / float(steps);

for (int s = 0; s < steps; s++) {
float marchDist = stepLen * (float(s) + 0.5);
vec3 samplePos = surfWorldPos + viewDir * marchDist;
float fogAtten = exp(-marchDist * 1.0);
for (int i = 0; i < 16; i++) {
float tt = float(i) * 0.8;
float sx = sin(tt * 1.2 + st * 0.4) * 3.0 + sin(tt * 0.5 + st * 0.15) * 6.0;
float sz = cos(tt * 0.9 + st * 0.3) * 4.0 + cos(tt * 0.4 + st * 0.2) * 5.0;
float sy = -0.5 - sin(tt * 1.8 + st * 0.5) * 0.5 - abs(sin(tt * 0.3 + st * 0.1)) * 1.0;
vec3 spinePos = snakeAnchor + vec3(sx, sy, sz);
float dist = length(samplePos - spinePos);
snakeGlow += fogAtten / (1.0 + dist * dist * 2.0);
}
}
snakeGlow = snakeGlow / float(steps);
snakeGlow = clamp(snakeGlow * 0.25, 0.0, 1.0);
vec3 glowColor = vec3(0.2, 0.55, 0.1);
color += glowColor * snakeGlow * biome_swamp;
}
#endif

#endif
#endif

if (isEyeInWater == 1) {
bool uwAbove = (depth1 >= 0.9999);
if (!uwAbove) {
bool uwIsVoxy = (maskData.a > 0.99);
mat4 uwProj = uwIsVoxy ? dhProjectionInverse : gbufferProjectionInverse;
vec4 uwClip = uwProj * vec4(texcoord * 2.0 - 1.0, depth1 * 2.0 - 1.0, 1.0);
vec3 uwViewP = uwClip.xyz / uwClip.w;
vec3 uwWorldP = (gbufferModelViewInverse * vec4(uwViewP, 1.0)).xyz + cameraPosition;
uwAbove = (uwWorldP.y > float(SEA_LEVEL_OFFSET) + 0.5);
}
if (uwAbove) {
vec4 uwrClip = vec4(texcoord * 2.0 - 1.0, 0.5, 1.0);
vec4 uwrView = gbufferProjectionInverse * uwrClip;
vec3 uwViewDir = normalize(uwrView.xyz);
vec3 uwWorldDir = normalize(mat3(gbufferModelViewInverse) * uwViewDir);
float uwTRay = (float(SEA_LEVEL_OFFSET) - cameraPosition.y) / max(uwWorldDir.y, 0.001);
vec2 uwSurfXZ = cameraPosition.xz + uwWorldDir.xz * max(uwTRay, 0.0);

vec2 uwWP = uwSurfXZ * 0.5;
float uwT = frameTimeCounter * WATER_WAVE_SPEED;
float uwSx = cos(uwWP.x * 2.0 + uwWP.y * 0.7 + uwT * 1.2) * 0.3
+ cos(uwWP.x * 1.3 - uwWP.y * 1.8 + uwT * 0.8) * 0.2;
float uwSz = cos(uwWP.y * 2.2 + uwWP.x * 0.5 + uwT * 1.0) * 0.3
+ cos(uwWP.y * 1.5 - uwWP.x * 1.6 + uwT * 1.1) * 0.2;

float uwRefrPx = 14.0;
ivec2 uwRefrCoord = texelcoord + ivec2(vec2(uwSx, uwSz) * uwRefrPx);
uwRefrCoord = clamp(uwRefrCoord, ivec2(0), ivec2(viewWidth - 1.0, viewHeight - 1.0));
vec3 uwRefrOpaque = texelFetch(colortex0, uwRefrCoord, 0).rgb;
vec4 uwRefrTrans = texelFetch(colortex7, uwRefrCoord, 0);
vec3 uwRefrColor = uwRefrTrans.a > 0.001
? uwRefrOpaque * (1.0 - uwRefrTrans.a) + uwRefrTrans.rgb
: uwRefrOpaque;
color = uwRefrColor;
transAlpha = 0.0;
}
}

vec3 rawGbufColor;
{
bool opaqueIsEntity = (maskData.a > 0.3 && maskData.a < 0.7);
bool skipBehindEntity = opaqueIsEntity && (depth0 >= depth1 - 0.00005);
if (transAlpha > 0.001 && !isHandEarly && !skipBehindEntity) {
color = color * (1.0 - transAlpha) + translucentData.rgb;

#if defined(ATMO_FOG_ENABLED) || defined(UNDERWATER_FOG_ENABLED)
if (isEyeInWater != 1) {
vec4 atmoFogReapply = max(texture(colortex9, texcoord), vec4(0.0));
if (atmoFogReapply.a > 0.001) {
color = atmoFogReapply.rgb + color * (1.0 - atmoFogReapply.a);
}
}
#endif
}
rawGbufColor = color;
}

#if defined(WATER_REFLECTIONS_ENABLED) || defined(MATERIAL_REFLECTIONS_ENABLED)
#ifndef WATER_REFLECTION_DEBUG
#ifdef WATER_FOAM_ENABLED
if ((isWater || isDhWater) && isWaterOnly && isEyeInWater != 1) {
vec3 rfViewPos;
if (isDhWater || isVoxyWater) {
float rfDepthLOD = isDhWater ? dhDepth : depth0;
vec4 rfClipDH = dhProjectionInverse * vec4(texcoord * 2.0 - 1.0, rfDepthLOD * 2.0 - 1.0, 1.0);
rfViewPos = rfClipDH.xyz / rfClipDH.w;
} else {
vec4 rfClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
rfViewPos = rfClip.xyz / rfClip.w;
}
vec3 rfWorldPos = (gbufferModelViewInverse * vec4(rfViewPos, 1.0)).xyz + cameraPosition;
float rft = frameTimeCounter * WATER_WAVE_SPEED;
float rfEps = 0.15;

#define RF_WAVE_RAW_10B(f) (smoothstep(0.15, 0.25, f) * (1.0 - pow(smoothstep(0.25, 1.15, f), 0.45)))
#define RF_WAVE_10B(px) RF_WAVE_RAW_10B(1.0 - fract(px))
#define RF_SMAX_10B(a, b, k) (max(a, b) + pow(max(k - abs(a - b), 0.0) / k, 3.0) * k * 0.166667)

vec2 rfSlope = vec2(0.0);
bool rfIsSide = (decodedWorldNormal.y < 0.5) && isWaterTagged;

if (rfIsSide) {
float sideRefrNoise = texelFetch(colortex5, texelcoord, 0).x;
rfSlope = vec2((sideRefrNoise - 0.5) * 0.8, (sideRefrNoise - 0.5) * 1.2);
} else if (biome_beach > 0.01 && biome_beach >= biome_ocean) {
float rfwx = rfWorldPos.x * WATER_WAVE_SCALE;
float rfwz = rfWorldPos.z * WATER_WAVE_SCALE;
float rfzOff1 = sin(rfwz * 0.21 + 3.7) * 2.5 + sin(rfwz * 0.53 + 1.2) * 1.3;
float rfzOff2 = sin(rfwz * 0.37 + 5.1) * 1.8 + sin(rfwz * 0.71 + 2.8) * 1.1;
float rfzOff3 = sin(rfwz * 0.62 + 0.9) * 1.2 + sin(rfwz * 0.89 + 4.3) * 0.8;
float rfH = clamp(RF_SMAX_10B(RF_WAVE_10B((rfwx * 0.8 + rfzOff1 - rft) / 6.2832), RF_WAVE_10B((rfwx * 1.8 + rfzOff2 - rft * 1.6) / 6.2832) * 0.55, 0.15), 0.0, 1.0);
rfH += RF_WAVE_10B((rfwx * 4.0 + rfzOff3 - rft * 2.2) / 6.2832) * 0.15 * rfH;
float rfwxp = (rfWorldPos.x + rfEps) * WATER_WAVE_SCALE;
float rfHx = clamp(RF_SMAX_10B(RF_WAVE_10B((rfwxp * 0.8 + rfzOff1 - rft) / 6.2832), RF_WAVE_10B((rfwxp * 1.8 + rfzOff2 - rft * 1.6) / 6.2832) * 0.55, 0.15), 0.0, 1.0);
rfHx += RF_WAVE_10B((rfwxp * 4.0 + rfzOff3 - rft * 2.2) / 6.2832) * 0.15 * rfHx;
float rfwzp = (rfWorldPos.z + rfEps) * WATER_WAVE_SCALE;
float rfzOff1z = sin(rfwzp * 0.21 + 3.7) * 2.5 + sin(rfwzp * 0.53 + 1.2) * 1.3;
float rfzOff2z = sin(rfwzp * 0.37 + 5.1) * 1.8 + sin(rfwzp * 0.71 + 2.8) * 1.1;
float rfzOff3z = sin(rfwzp * 0.62 + 0.9) * 1.2 + sin(rfwzp * 0.89 + 4.3) * 0.8;
float rfHz = clamp(RF_SMAX_10B(RF_WAVE_10B((rfwx * 0.8 + rfzOff1z - rft) / 6.2832), RF_WAVE_10B((rfwx * 1.8 + rfzOff2z - rft * 1.6) / 6.2832) * 0.55, 0.15), 0.0, 1.0);
rfHz += RF_WAVE_10B((rfwx * 4.0 + rfzOff3z - rft * 2.2) / 6.2832) * 0.15 * rfHz;
rfSlope = vec2(rfHx - rfH, rfHz - rfH) / rfEps;
} else {

#define RF_HASH(p) fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453)
vec3 rfsp1 = vec3(rfWorldPos.xz * WATER_WAVE_SCALE * 0.4, rft * 0.5);
vec3 rfsi1 = floor(rfsp1); vec3 rfsf1 = fract(rfsp1);
rfsf1 = rfsf1 * rfsf1 * (3.0 - 2.0 * rfsf1);
float rfsn1 = mix(mix(mix(RF_HASH(rfsi1), RF_HASH(rfsi1+vec3(1,0,0)), rfsf1.x),
mix(RF_HASH(rfsi1+vec3(0,1,0)), RF_HASH(rfsi1+vec3(1,1,0)), rfsf1.x), rfsf1.y),
mix(mix(RF_HASH(rfsi1+vec3(0,0,1)), RF_HASH(rfsi1+vec3(1,0,1)), rfsf1.x),
mix(RF_HASH(rfsi1+vec3(0,1,1)), RF_HASH(rfsi1+vec3(1,1,1)), rfsf1.x), rfsf1.y), rfsf1.z);
vec3 rfsp2 = vec3(rfWorldPos.xz * WATER_WAVE_SCALE * 0.9, rft * 1.2) + vec3(17.0);
vec3 rfsi2 = floor(rfsp2); vec3 rfsf2 = fract(rfsp2);
rfsf2 = rfsf2 * rfsf2 * (3.0 - 2.0 * rfsf2);
float rfsn2 = mix(mix(mix(RF_HASH(rfsi2), RF_HASH(rfsi2+vec3(1,0,0)), rfsf2.x),
mix(RF_HASH(rfsi2+vec3(0,1,0)), RF_HASH(rfsi2+vec3(1,1,0)), rfsf2.x), rfsf2.y),
mix(mix(RF_HASH(rfsi2+vec3(0,0,1)), RF_HASH(rfsi2+vec3(1,0,1)), rfsf2.x),
mix(RF_HASH(rfsi2+vec3(0,1,1)), RF_HASH(rfsi2+vec3(1,1,1)), rfsf2.x), rfsf2.y), rfsf2.z);
vec3 rfsp3 = vec3(rfWorldPos.xz * WATER_WAVE_SCALE * 1.8, rft * 2.0) + vec3(31.0);
vec3 rfsi3 = floor(rfsp3); vec3 rfsf3 = fract(rfsp3);
rfsf3 = rfsf3 * rfsf3 * (3.0 - 2.0 * rfsf3);
float rfsn3 = mix(mix(mix(RF_HASH(rfsi3), RF_HASH(rfsi3+vec3(1,0,0)), rfsf3.x),
mix(RF_HASH(rfsi3+vec3(0,1,0)), RF_HASH(rfsi3+vec3(1,1,0)), rfsf3.x), rfsf3.y),
mix(mix(RF_HASH(rfsi3+vec3(0,0,1)), RF_HASH(rfsi3+vec3(1,0,1)), rfsf3.x),
mix(RF_HASH(rfsi3+vec3(0,1,1)), RF_HASH(rfsi3+vec3(1,1,1)), rfsf3.x), rfsf3.y), rfsf3.z);
#undef RF_HASH
float rfwx = (rfsn1 - 0.5) * 0.5 + (rfsn2 - 0.5) * 0.3 + (rfsn3 - 0.5) * 0.2;
float rfwz = (rfsn2 - 0.5) * 0.5 + (rfsn3 - 0.5) * 0.3 + (rfsn1 - 0.5) * 0.2;
rfSlope = vec2(rfwx, rfwz) * 0.8;
}
#undef RF_WAVE_10B
#undef RF_WAVE_RAW_10B
#undef RF_SMAX_10B

float rfBiomeFactor = max(waveBiome, 0.5);
float rfDist = max(length(rfViewPos), 1.0);
float refrDistFade = 1.0 - smoothstep(30.0, 80.0, rfDist);
float refrBase = (biome_beach > 0.01) ? 18.0 : 14.0;
float refrPx = refrBase * rfBiomeFactor / max(rfDist * 0.02, 0.5);
ivec2 refrCoord = texelcoord + ivec2(rfSlope * refrPx);
refrCoord = clamp(refrCoord, ivec2(0), ivec2(viewWidth - 1.0, viewHeight - 1.0));
float refrDepth = texelFetch(depthtex1, refrCoord, 0).r;
if (refrDepth > depth0 && refrDistFade > 0.01) {
vec3 refrOpaque = texelFetch(colortex0, refrCoord, 0).rgb;
vec4 refrTrans = texelFetch(colortex7, refrCoord, 0);
vec3 refrColor = refrTrans.a > 0.001 ? refrOpaque * (1.0 - refrTrans.a) + refrTrans.rgb : refrOpaque;
color = mix(color, refrColor, 0.95 * refrDistFade);
}
}
#endif
#endif
#endif

preSpecularColor = color;

#ifdef WATER_REFLECTIONS_ENABLED
if (isWater && isWaterOnly && isEyeInWater != 1) {
if (depth0 < 1.0) {
vec3 viewPos;
if (isVoxyWater) {
vec4 vClip = dhProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
viewPos = vClip.xyz / vClip.w;
} else {
vec3 screenPos = vec3(texcoord, depth0);
viewPos = ilv_screenToView(screenPos);
}
vec3 waterWorldN = decodedWorldNormal;
bool isSideWater = (waterWorldN.y < 0.5);
if (isSideWater) waterWorldN = vec3(0.0, 1.0, 0.0);
waterWorldN = normalize(mix(vec3(0.0, 1.0, 0.0), waterWorldN, 0.05));
vec3 normal = normalize(mat3(gbufferModelView) * waterWorldN);

vec2 waveOffset = vec2(0.0);
#ifdef WATER_WAVES_ENABLED
{
ivec2 tcMax = ivec2(viewWidth - 1.0, viewHeight - 1.0);
ivec2 tcL = clamp(texelcoord + ivec2(-1, 0), ivec2(0), tcMax);
ivec2 tcR = clamp(texelcoord + ivec2( 1, 0), ivec2(0), tcMax);
ivec2 tcU = clamp(texelcoord + ivec2(0, -1), ivec2(0), tcMax);
ivec2 tcD = clamp(texelcoord + ivec2(0,  1), ivec2(0), tcMax);
float whL = texelFetch(colortex5, tcL, 0).x;
float whR = texelFetch(colortex5, tcR, 0).x;
float whU = texelFetch(colortex5, tcU, 0).x;
float whD = texelFetch(colortex5, tcD, 0).x;
vec2 hGrad = vec2(whR - whL, whD - whU);
float waveDist = max(length(viewPos), 1.0);
float distScale = 1.0 / waveDist;
waveOffset = vec2(0.0);
}
#endif

TimeWeightsSimple reflTS = getTimeWeightsSimple(sunAngle);
float reflDay = reflTS.day + reflTS.twilight;
float reflNight = reflTS.night + reflTS.blueHour;
float reflTOD = mix(0.15, 1.0, reflDay) + reflNight * 0.85;
float reflectionStrength = mix(WATER_REFLECTION_AMOUNT, max(WATER_REFLECTION_AMOUNT, 0.85), reflNight) * reflTOD * WATER_OPACITY;
float crestReflectCut = 1.0;
reflectionStrength *= crestReflectCut;
float waterSkylight = texelFetch(colortex1, texelcoord, 0).b;
vec2 lmcoord = vec2(0.0, waterSkylight);

vec3 reflDirView = reflect(normalize(viewPos), normal);
vec3 reflDirWorld = mat3(gbufferModelViewInverse) * reflDirView;

float ssrDist = length(viewPos);
float ssrFade = 1.0 - smoothstep(float(SSR_RENDER_DISTANCE) * 0.8, float(SSR_RENDER_DISTANCE), ssrDist);

if (isSideWater) {
vec3 sideNormalWorld = decodedWorldNormal;
sideNormalWorld.y = 0.0;
float sideNLen = length(sideNormalWorld);
if (sideNLen < 0.001) sideNormalWorld = vec3(0.0, 0.0, 1.0);
else sideNormalWorld /= sideNLen;

vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
vec3 viewDirWorld = normalize(worldPos);
vec3 sideReflWorld = reflect(viewDirWorld, sideNormalWorld);
sideReflWorld.y += 0.15;

float sideNoise = reflData.x;
sideReflWorld.x += (sideNoise - 0.5) * 0.12;
sideReflWorld.y += (sideNoise - 0.5) * 0.08;
sideReflWorld = normalize(sideReflWorld);

vec3 sideSkyCol;
if (sideReflWorld.y > 0.0) {
vec3 sideReflView = normalize(mat3(gbufferModelView) * sideReflWorld);
sideSkyCol = ilv_getSkyColor(sideReflView, worldPos + cameraPosition) * 0.8;
} else {
vec3 horizDir = normalize(vec3(sideReflWorld.x, 0.001, sideReflWorld.z));
vec3 horizView = normalize(mat3(gbufferModelView) * horizDir);
sideSkyCol = ilv_getSkyColor(horizView, worldPos + cameraPosition) * 0.8;
}

float sideSkyGate = smoothstep(13.0 / 15.0, 14.0 / 15.0, waterSkylight);
reflectionStrength *= sideSkyGate;

vec3 sideNormalPerturbed = sideNormalWorld;
sideNormalPerturbed.y += (sideNoise - 0.5) * 0.1;
sideNormalPerturbed.x += (sideNoise - 0.5) * 0.05;
sideNormalPerturbed = normalize(sideNormalPerturbed);
vec3 sideNormalView = normalize(mat3(gbufferModelView) * sideNormalPerturbed);
vec2 sideWaveOffset = vec2((sideNoise - 0.5) * 0.008, (sideNoise - 0.5) * 0.015);
vec3 preRefl = color;
ilv_addReflection(color, viewPos, sideNormalView, lmcoord, reflectionStrength * max(ssrFade, 0.001), sideWaveOffset);
vec3 ssrDeltaLocal = color - preRefl;
color = preRefl;
color += ssrDeltaLocal * WATER_BRIGHTNESS;
float ssrHit = clamp(length(ssrDeltaLocal) * 5.0, 0.0, 1.0);
color = mix(mix(color, sideSkyCol, reflectionStrength), color, ssrHit);

{
vec3 sideN = normalize(mat3(gbufferModelView) * sideNormalWorld);
sideN = normalize(sideN + vec3((sideNoise - 0.5) * 0.5, (sideNoise - 0.5) * 0.5, 0.0));
vec3 sideL = normalize(shadowLightPosition);
vec3 sideV = normalize(-viewPos);
vec3 sideH = normalize(sideV + sideL);
float sideNdotH = max(dot(sideN, sideH), 0.0);
float sideSpec = smoothstep(0.985, 0.995, sideNdotH);
TimeWeightsSimple sideSpecTS = getTimeWeightsSimple(sunAngle);
float sideDayFactor = sideSpecTS.day + sideSpecTS.twilight * 0.7;
float sideSunsetBoost = 1.0 + sideSpecTS.twilight * 2.0;
float sideGlow = sideSpec * sideDayFactor * waterSkylight * sideSunsetBoost;
vec3 sideGlowCol = mix(vec3(1.0, 0.95, 0.85),
vec3(SUNSET_HORIZON_R, SUNSET_HORIZON_G, SUNSET_HORIZON_B), sideSpecTS.twilight);
vec3 sideShadowScenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
vec4 sideShadowClip = shadowProjection * shadowModelView * vec4(sideShadowScenePos, 1.0);
vec3 sideShadowDistorted = distortShadowClipPos(sideShadowClip.xyz / sideShadowClip.w);
vec3 sideShadowScreen = sideShadowDistorted * 0.5 + 0.5;
float sideShadow = 0.0;
if (sideShadowScreen.x > 0.0 && sideShadowScreen.x < 1.0 && sideShadowScreen.y > 0.0 && sideShadowScreen.y < 1.0) {
float sideShadowDepth = texture(shadowtex0, sideShadowScreen.xy).r;
sideShadow = step(sideShadowScreen.z - 0.001, sideShadowDepth);
}
preSpecularColor = color;
color += sideGlowCol * sideGlow * WATER_SPECULAR_INTENSITY * sideShadow;
}
} else {

vec3 preRefl = color;
ilv_addReflection(color, viewPos, normal, lmcoord, reflectionStrength * max(ssrFade, 0.001), waveOffset);
vec3 reflDelta = color - preRefl;
float wb = WATER_BRIGHTNESS;
color = preRefl + reflDelta * wb;

vec3 topL = normalize(shadowLightPosition);
vec3 topV = normalize(-viewPos);
vec3 topWorldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
float topWt = frameTimeCounter * WATER_WAVE_SPEED;

#define SPEC_HASH(p) fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453)
vec3 sp1 = vec3(topWorldPos.xz * WATER_WAVE_SCALE * 0.4, topWt * 0.5);
vec3 si1 = floor(sp1); vec3 sf1 = fract(sp1);
sf1 = sf1 * sf1 * (3.0 - 2.0 * sf1);
float sn1 = mix(mix(mix(SPEC_HASH(si1), SPEC_HASH(si1+vec3(1,0,0)), sf1.x),
mix(SPEC_HASH(si1+vec3(0,1,0)), SPEC_HASH(si1+vec3(1,1,0)), sf1.x), sf1.y),
mix(mix(SPEC_HASH(si1+vec3(0,0,1)), SPEC_HASH(si1+vec3(1,0,1)), sf1.x),
mix(SPEC_HASH(si1+vec3(0,1,1)), SPEC_HASH(si1+vec3(1,1,1)), sf1.x), sf1.y), sf1.z);
vec3 sp2 = vec3(topWorldPos.xz * WATER_WAVE_SCALE * 0.9, topWt * 1.2) + vec3(17.0);
vec3 si2 = floor(sp2); vec3 sf2 = fract(sp2);
sf2 = sf2 * sf2 * (3.0 - 2.0 * sf2);
float sn2 = mix(mix(mix(SPEC_HASH(si2), SPEC_HASH(si2+vec3(1,0,0)), sf2.x),
mix(SPEC_HASH(si2+vec3(0,1,0)), SPEC_HASH(si2+vec3(1,1,0)), sf2.x), sf2.y),
mix(mix(SPEC_HASH(si2+vec3(0,0,1)), SPEC_HASH(si2+vec3(1,0,1)), sf2.x),
mix(SPEC_HASH(si2+vec3(0,1,1)), SPEC_HASH(si2+vec3(1,1,1)), sf2.x), sf2.y), sf2.z);
vec3 sp3 = vec3(topWorldPos.xz * WATER_WAVE_SCALE * 1.8, topWt * 2.0) + vec3(31.0);
vec3 si3 = floor(sp3); vec3 sf3 = fract(sp3);
sf3 = sf3 * sf3 * (3.0 - 2.0 * sf3);
float sn3 = mix(mix(mix(SPEC_HASH(si3), SPEC_HASH(si3+vec3(1,0,0)), sf3.x),
mix(SPEC_HASH(si3+vec3(0,1,0)), SPEC_HASH(si3+vec3(1,1,0)), sf3.x), sf3.y),
mix(mix(SPEC_HASH(si3+vec3(0,0,1)), SPEC_HASH(si3+vec3(1,0,1)), sf3.x),
mix(SPEC_HASH(si3+vec3(0,1,1)), SPEC_HASH(si3+vec3(1,1,1)), sf3.x), sf3.y), sf3.z);
#undef SPEC_HASH

float wx = (sn1 - 0.5) * 0.5 + (sn2 - 0.5) * 0.3 + (sn3 - 0.5) * 0.2;
float wz = (sn2 - 0.5) * 0.5 + (sn3 - 0.5) * 0.3 + (sn1 - 0.5) * 0.2;

vec3 topN = normalize(normal + mat3(gbufferModelView) * vec3(wx * 0.5, 0.0, wz * 0.5));
vec3 topH = normalize(topV + topL);
float topNdotH = max(dot(topN, topH), 0.0);
TimeWeightsSimple topTS = getTimeWeightsSimple(sunAngle);
float topDayFactor = topTS.day + topTS.twilight * 0.7;
float topSunsetBoost = 1.0 + topTS.twilight * 2.0;
float topSpec = smoothstep(0.985, 0.995, topNdotH);
float topGlow = topSpec * topDayFactor * waterSkylight * topSunsetBoost;
vec3 topGlowCol = mix(vec3(1.0, 0.95, 0.85),
vec3(SUNSET_HORIZON_R, SUNSET_HORIZON_G, SUNSET_HORIZON_B), topTS.twilight);

vec3 topShadowScenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
vec4 topShadowClip = shadowProjection * shadowModelView * vec4(topShadowScenePos, 1.0);
vec3 topShadowDistorted = distortShadowClipPos(topShadowClip.xyz / topShadowClip.w);
vec3 topShadowScreen = topShadowDistorted * 0.5 + 0.5;
float topShadow = 0.0;
if (topShadowScreen.x > 0.0 && topShadowScreen.x < 1.0 && topShadowScreen.y > 0.0 && topShadowScreen.y < 1.0) {
float topShadowDepth = texture(shadowtex0, topShadowScreen.xy).r;
topShadow = step(topShadowScreen.z - 0.001, topShadowDepth);
}
float topGlowAmt = topGlow * WATER_SPECULAR_INTENSITY * topShadow;
preSpecularColor = color;
color += topGlowCol * topGlowAmt;
}
}
}

if (isDhWater && isWaterOnly && isEyeInWater != 1) {
vec3 dhWorldNormal = vec3(
reflData.z * 2.0 - 1.0,
reflData.w * 2.0 - 1.0,
0.0
);
dhWorldNormal.z = sqrt(max(1.0 - dhWorldNormal.x * dhWorldNormal.x - dhWorldNormal.y * dhWorldNormal.y, 0.0));
vec3 dhNormalView = normalize(mat3(gbufferModelView) * dhWorldNormal);

vec3 dhScreenPos = vec3(texcoord, dhDepth);
vec3 dhNdc = dhScreenPos * 2.0 - 1.0;
vec4 dhViewH = dhProjectionInverse * vec4(dhNdc, 1.0);
vec3 dhViewPos = dhViewH.xyz / dhViewH.w;

float dhFresnel = 1.0 - abs(dot(normalize(-dhViewPos), dhNormalView));
dhFresnel *= dhFresnel;
dhFresnel *= dhFresnel;
float dhFresnelMod = mix(0.3, 1.0, dhFresnel) * WATER_REFLECTION_FADE;
dhFresnelMod = clamp(dhFresnelMod, 0.0, 1.0);

TimeWeightsSimple dhReflTS = getTimeWeightsSimple(sunAngle);
float dhReflDay = dhReflTS.day + dhReflTS.twilight;
float dhReflNight = dhReflTS.night + dhReflTS.blueHour;
float dhReflTOD = mix(0.15, 1.0, dhReflDay) + dhReflNight * 0.85;

vec3 dhReflDir = reflect(normalize(dhViewPos), dhNormalView);
vec3 dhWorldPos = (gbufferModelViewInverse * vec4(dhViewPos, 1.0)).xyz + cameraPosition;
{
float dhWT = frameTimeCounter * WATER_WAVE_SPEED;
vec2 dhWP = dhWorldPos.xz * WATER_WAVE_SCALE * 2.5;
float dhWX = sin(dhWP.x * 3.0 + dhWP.y * 0.3 + dhWT * 1.5) * 0.5
+ sin(dhWP.x * 5.0 + dhWP.y * 0.5 + dhWT * 2.2) * 0.3
+ sin(dhWP.x * 8.0 + dhWP.y * 0.2 + dhWT * 3.0) * 0.2;
float dhWZ = sin(dhWP.x * 0.3 + dhWP.y * 3.0 + dhWT * 1.3) * 0.5
+ sin(dhWP.x * 0.5 + dhWP.y * 5.0 + dhWT * 2.0) * 0.3;
dhReflDir.x += dhWX * 0.005;
dhReflDir.z += dhWZ * 0.005;
dhReflDir = normalize(dhReflDir);
}
float dhRbTOD = mix(0.20, 1.0, dhReflNight / max(dhReflDay + dhReflNight, 0.001));
float dhRbActive = max(dhReflDay, dhReflNight);
dhRbTOD = mix(0.60, dhRbTOD, dhRbActive);
float dhNightBlend = dhReflNight / max(dhReflDay + dhReflNight, 0.001);
float dhSkyBright = mix(WATER_SKY_BRIGHTNESS_DAY, WATER_SKY_BRIGHTNESS_NIGHT, dhNightBlend);
dhSkyBright = mix(mix(WATER_SKY_BRIGHTNESS_DAY, WATER_SKY_BRIGHTNESS_NIGHT, 0.5), dhSkyBright, dhRbActive);
vec3 dhSkyColor = ilv_getSkyColor(dhReflDir, dhWorldPos) * 1.3;

float dhReflStrength = WATER_REFLECTION_AMOUNT * dhReflTOD * dhFresnelMod * WATER_SKY_REFLECTION * WATER_OPACITY;
float dhCrestReflectCut = 1.0;
dhReflStrength *= dhCrestReflectCut;
float dhSkylight = texelFetch(colortex1, texelcoord, 0).b;
dhReflStrength *= smoothstep(13.0 / 15.0, 14.0 / 15.0, dhSkylight);
dhReflStrength = clamp(dhReflStrength, 0.0, 1.0);
color = mix(color, dhSkyColor, dhReflStrength);
}
#endif

if (isIceBlock && depthAll < 0.9999) {
vec3 iceViewPos;
bool iceIsVoxy = (maskData.a > 0.999);
if (iceIsVoxy) {
vec4 iceClip = dhProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
iceViewPos = iceClip.xyz / iceClip.w;
} else {
iceViewPos = ilv_screenToView(vec3(texcoord, depth0));
}
vec3 iceWorldNormal = decodedWorldNormal;
if (length(iceWorldNormal) < 0.01) iceWorldNormal = vec3(0.0, 1.0, 0.0);
vec3 iceNormalView = normalize(mat3(gbufferModelView) * iceWorldNormal);

float iceSkylight = texelFetch(colortex1, texelcoord, 0).b;
float iceReflStr = 0.3 * smoothstep(0.1, 0.8, iceSkylight);

vec3 preIceRefl = color;
ilv_addReflection(color, iceViewPos, iceNormalView, vec2(0.0, iceSkylight), iceReflStr, vec2(0.0));

vec3 iceWorldPos = (gbufferModelViewInverse * vec4(iceViewPos, 1.0)).xyz + cameraPosition;
float iceWt = frameTimeCounter * 0.5;
float iceWaveX = sin(iceWorldPos.x * 2.5 + iceWorldPos.z * 0.3 + iceWt * 1.2) * 0.5
+ sin(iceWorldPos.x * 4.0 + iceWorldPos.z * 0.8 + iceWt * 1.8) * 0.3;
float iceWaveZ = sin(iceWorldPos.z * 2.5 + iceWorldPos.x * 0.3 + iceWt * 1.0) * 0.5
+ sin(iceWorldPos.z * 4.0 + iceWorldPos.x * 0.6 + iceWt * 1.5) * 0.3;

vec3 icePerturbedNormal = iceNormalView;
icePerturbedNormal.x += iceWaveX * 0.03;
icePerturbedNormal.z += iceWaveZ * 0.03;
icePerturbedNormal = normalize(icePerturbedNormal);

vec3 iceL = normalize(shadowLightPosition);
vec3 iceV = normalize(-iceViewPos);
vec3 iceH = normalize(iceV + iceL);
float iceNdotH = max(dot(icePerturbedNormal, iceH), 0.0);
float iceSpec = smoothstep(0.985, 0.995, iceNdotH);
TimeWeightsSimple iceTS = getTimeWeightsSimple(sunAngle);
float iceDayFactor = iceTS.day + iceTS.twilight * 0.7;
float iceSunsetBoost = 1.0 + iceTS.twilight * 2.0;
float iceGlow = iceSpec * iceDayFactor * iceSkylight * iceSunsetBoost;
vec3 iceGlowCol = mix(vec3(1.0, 0.95, 0.85),
vec3(SUNSET_HORIZON_R, SUNSET_HORIZON_G, SUNSET_HORIZON_B), iceTS.twilight);

vec3 iceScenePos = (gbufferModelViewInverse * vec4(iceViewPos, 1.0)).xyz;
vec4 iceShadowClip = shadowProjection * shadowModelView * vec4(iceScenePos, 1.0);
vec3 iceShadowDist = distortShadowClipPos(iceShadowClip.xyz / iceShadowClip.w);
vec3 iceShadowScreen = iceShadowDist * 0.5 + 0.5;
float iceShadow = 0.0;
if (iceShadowScreen.x > 0.0 && iceShadowScreen.x < 1.0 && iceShadowScreen.y > 0.0 && iceShadowScreen.y < 1.0) {
iceShadow = step(iceShadowScreen.z - 0.001, texture(shadowtex0, iceShadowScreen.xy).r);
}
color += iceGlowCol * iceGlow * WATER_SPECULAR_INTENSITY * iceShadow;
}

#if defined(WATER_REFLECTIONS_ENABLED) || defined(MATERIAL_REFLECTIONS_ENABLED)
#ifndef WATER_REFLECTION_DEBUG

if (isWaterOnly) {
TimeWeightsSimple wsTS = getTimeWeightsSimple(sunAngle);
float wsDay = wsTS.day + wsTS.twilight;
float wsNight = wsTS.night + wsTS.blueHour;
float wsNightFactor = wsNight / max(wsDay + wsNight, 0.001);
float wsActive = max(wsDay, wsNight);
wsNightFactor = mix(0.0, wsNightFactor, wsActive);

if (isWater || isDhWater) {
float lum = dot(color, vec3(0.299, 0.587, 0.114));
float sat = mix(WATER_SATURATION, WATER_SATURATION * WATER_NIGHT_SATURATION, wsNightFactor);
color = mix(vec3(lum), color, sat);
}
}

#ifdef UNDERWATER_FOG_ENABLED
if ((isWater || isDhWater) && isWaterOnly && isEyeInWater != 1) {
float beerDepth0 = depth0;
float beerDepth1 = texelFetch(depthtex1, texelcoord, 0).r;

vec4 beerWaterClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, beerDepth0 * 2.0 - 1.0, 1.0);
vec3 beerWaterView = beerWaterClip.xyz / beerWaterClip.w;
vec4 beerTerrainClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, beerDepth1 * 2.0 - 1.0, 1.0);
vec3 beerTerrainView = beerTerrainClip.xyz / beerTerrainClip.w;

float waterThickness = max(length(beerTerrainView) - length(beerWaterView), 0.0);

if (waterThickness < 0.5 && (isVoxyLod || isDhWater)) {
vec3 beerWorldPos = (gbufferModelViewInverse * vec4(beerWaterView, 1.0)).xyz + cameraPosition;
waterThickness = max(float(SEA_LEVEL_OFFSET) - beerWorldPos.y + 2.0, 0.0);
}

vec3 beerAbsorb = vec3(0.009, 0.004, 0.0015);
vec3 beerTrans = exp(-waterThickness * beerAbsorb);
vec3 beerTint = vec3(0.1, 0.4, 0.8);
}
#endif

if (false && (isWater || isDhWater) && isWaterOnly && isEyeInWater != 1) {
float wDist;
if (isDhWater) {
vec4 dhClip = dhProjectionInverse * vec4(texcoord * 2.0 - 1.0, dhDepth * 2.0 - 1.0, 1.0);
wDist = -dhClip.z / dhClip.w;
} else {
vec4 wClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
wDist = -wClip.z / wClip.w;
}

float fogDensity = mix(0.025, 2.0, biome_swamp);
float fogMax = mix(0.95, 1.0, biome_swamp);
float uwFogAmount = 1.0 - exp(-wDist * fogDensity);
uwFogAmount = clamp(uwFogAmount, 0.0, fogMax);

if (uwFogAmount > 0.001) {
float uwAngle = fract(sunAngle);
float uwTwilight = smoothstep(0.40, 0.48, uwAngle) * smoothstep(0.55, 0.48, uwAngle)
+ smoothstep(0.94, 1.0, uwAngle) + smoothstep(0.06, 0.0, uwAngle);
if (uwTwilight > 0.001) {
float uwLum = dot(color, vec3(0.299, 0.587, 0.114));
color = mix(color, vec3(uwLum), uwTwilight * 0.6);
}
vec3 beachTint = biomeWaterColor(sunAngle, 1.0, 0.0, 0.0, 0.0, 0.0);
vec3 swampTint = vec3(0.04, 0.08, 0.02);
vec3 uwWaterTint = mix(beachTint, swampTint, biome_swamp);
color *= mix(vec3(1.0), uwWaterTint * 3.0, uwFogAmount);
color += uwWaterTint * uwFogAmount;
}
}

#endif
#endif

#if defined(WATER_REFLECTIONS_ENABLED) || defined(MATERIAL_REFLECTIONS_ENABLED)
#ifndef WATER_REFLECTION_DEBUG

if ((isWater || isDhWater) && isWaterOnly && isEyeInWater != 1) {
vec3 specDelta = max(color - preSpecularColor, vec3(0.0));
vec3 biomeWater = biomeWaterColor(sunAngle, biome_beach, biome_swamp, biome_jungle, biome_snowy, biome_arid);
vec3 defaultBlue = vec3(0.0, 66.0, 102.0) / 255.0;
float hasBiome = max(max(biome_swamp, biome_jungle), max(biome_snowy, biome_arid));
vec3 waterTint = mix(defaultBlue, biomeWater, clamp(hasBiome, 0.0, 1.0));
float tintLum = dot(waterTint, vec3(0.299, 0.587, 0.114));
waterTint = mix(vec3(tintLum), waterTint, 2.0);
waterTint = max(waterTint, vec3(0.0));
float waterSkyDim = mix(0.05, 1.0, texelFetch(colortex1, texelcoord, 0).b);
waterTint *= waterSkyDim;
vec3 tinted = mix(preSpecularColor, waterTint, 0.5);

float gbufLum = dot(rawGbufColor, vec3(0.299, 0.587, 0.114));
float foamMask = smoothstep(0.7, 0.95, gbufLum);
color = mix(tinted, preSpecularColor, foamMask) + specDelta;
}

#ifdef WATER_FOAM_ENABLED
if ((isWater || isDhWater) && isWaterOnly && waveBiome > 0.01 && beachWaveHeight > 0.001 && isEyeInWater != 1) {
vec4 wvClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
float wvDist = max(-wvClip.z / wvClip.w, 1.0);
int sampleOff = clamp(int(wvDist * 0.15), 2, 20);
float whL = texelFetch(colortex5, texelcoord + ivec2(-sampleOff, 0), 0).x;
float whR = texelFetch(colortex5, texelcoord + ivec2( sampleOff, 0), 0).x;
float slope = abs(whR - whL);
float wallMask = 0.0;
color *= mix(vec3(1.0), vec3(0.75, 0.88, 0.90), wallMask);
}
#endif

bool glassInFront = (depth0 < depth1 - 0.0001) && !entityInFront;
bool hasGlassLayer = (glassTint.a > 0.55 && glassTint.a < 0.65) && glassInFront && (transAlpha > 0.001);
#ifdef GLASS_FILTER_ENABLED
if (hasGlassLayer && !entityInFront) {
vec3 tint = glassTint.rgb;
float maxTint = max(max(tint.r, tint.g), tint.b);
if (maxTint > 0.01) {
tint /= maxTint;
float sat = GLASS_FILTER_SATURATION;
float tintLumGF = dot(tint, vec3(0.299, 0.587, 0.114));
tint = mix(vec3(tintLumGF), tint, sat);
tint = min(tint, vec3(1.0));
float str = GLASS_FILTER_STRENGTH;
float enforce = GLASS_FILTER_ENFORCEMENT;
color = mix(color, color * tint, str * enforce);
}
}
#endif

if (hasGlassLayer && !entityInFront && glassInFront && isEyeInWater != 1) {
float glassOpaqueDepth = texelFetch(depthtex1, texelcoord, 0).r;
if (glassOpaqueDepth < 0.9999) {
vec4 glassClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, glassOpaqueDepth * 2.0 - 1.0, 1.0);
vec3 glassViewP = glassClip.xyz / glassClip.w;
vec3 glassBehindWorld = (gbufferModelViewInverse * vec4(glassViewP, 1.0)).xyz + cameraPosition;
if (glassBehindWorld.y < float(SEA_LEVEL_OFFSET)) {
vec3 glassViewDir = normalize(glassViewP);
vec3 glassNormal = normalize(mat3(gbufferModelView) * vec3(0.0, 1.0, 0.0));
vec3 glassReflDir = reflect(glassViewDir, glassNormal);
vec3 glassReflWorld = mat3(gbufferModelViewInverse) * glassReflDir;
vec3 glassSkyRefl = ilv_getSkyColor(glassReflDir, glassBehindWorld) * WATER_SKY_REFLECTION;
float glassFresnel = 1.0 - abs(dot(normalize(-glassViewP), glassNormal));
glassFresnel = glassFresnel * glassFresnel * glassFresnel;
float glassReflStr = mix(0.2, 0.8, glassFresnel) * WATER_OPACITY;
color = mix(color, glassSkyRefl, glassReflStr);
}
}
}

#if defined(CAVE_FOG_ENABLED) && !defined(END_SHADER)
float caveFogEmissive2 = texelFetch(colortex1, texelcoord, 0).g;
if (isEyeInWater != 1 && transAlpha > 0.001 && !isForcedNetherBiome(biome) && caveFogEmissive2 < 0.5) {
float caveFogSkylight2 = texelFetch(colortex1, texelcoord, 0).b;
float caveFogGate2 = 1.0 - smoothstep(1.0 / 15.0, 3.0 / 15.0, caveFogSkylight2);

if (caveFogGate2 > 0.01 && depth0 < 0.9999) {
vec4 caveFogClip2 = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
vec3 caveFogViewPos2 = caveFogClip2.xyz / caveFogClip2.w;
float caveFogDist2 = length(caveFogViewPos2);

vec3 caveFogColor2 = vec3(CAVE_FOG_R, CAVE_FOG_G, CAVE_FOG_B) / 255.0;
vec3 rayDir2 = normalize(caveFogViewPos2);
float rayLen2 = min(caveFogDist2, CAVE_FOG_DISTANCE);

float caveFogTime2 = frameTimeCounter * CAVE_FOG_SPEED;

float caveFogAccum2 = 0.0;
int caveFogSteps2 = 32;
float stepSize2 = rayLen2 / float(caveFogSteps2);
float dither2 = fract(sin(dot(gl_FragCoord.xy + vec2(frameCounter * 0.1), vec2(12.9898, 78.233))) * 43758.5453);

for (int i = 0; i < caveFogSteps2; i++) {
float t = (float(i) + dither2) * stepSize2;
vec3 samplePos2 = cameraPosition + (gbufferModelViewInverse * vec4(rayDir2 * t, 0.0)).xyz;

float depthRamp2 = smoothstep(CAVE_FOG_RAMP_START, CAVE_FOG_RAMP_END, t);
if (depthRamp2 < 0.001) continue;

vec3 wp2 = samplePos2;
wp2.x += sin(samplePos2.z * 0.04 + caveFogTime2 * 1.3) * 4.0 + cos(samplePos2.y * 0.06 + caveFogTime2 * 0.7) * 3.0;
wp2.y += sin(samplePos2.x * 0.05 + caveFogTime2 * 0.9) * 3.0 + cos(samplePos2.z * 0.03 + caveFogTime2 * 1.1) * 2.5;
wp2.z += cos(samplePos2.x * 0.04 + caveFogTime2 * 1.5) * 4.0 + sin(samplePos2.y * 0.05 + caveFogTime2 * 0.6) * 3.0;

float n2 = noise3D(wp2 * CAVE_FOG_NOISE_SCALE);
n2 = clamp((n2 - 0.3) * 2.5, 0.0, 1.0);

if (n2 > 0.3) {
float fogStep2 = smoothstep(0.3, 0.6, n2) * CAVE_FOG_DENSITY * depthRamp2;
caveFogAccum2 += fogStep2;
}
}

float caveFogAmount2 = min(caveFogAccum2, 1.0) * caveFogGate2;
color = mix(color, caveFogColor2, caveFogAmount2);
}
}
#endif

vec4 ssrTaaOutput = vec4(0.0);
#ifdef MATERIAL_REFLECTIONS_ENABLED
{
bool isHandPixelMat = isHandEarly;
bool isEntityPixelMat = isEntityOrHand;
if (isMaterialRefl && isEyeInWater != 1 && !isHandPixelMat && !isEntityPixelMat) {
if (depth0 < 1.0) {
float mnx = reflData.z * 2.0 - 1.0;
float mny = reflData.w * 2.0 - 1.0;
float mnz = sqrt(max(1.0 - mnx * mnx - mny * mny, 0.0));
vec3 worldNormal = vec3(mnx, mny, mnz);
vec3 matNormal = normalize(mat3(gbufferModelView) * worldNormal);

float matReflStr = MATERIAL_REFLECTION_AMOUNT;
vec3 screenPos = vec3(texcoord, depth0);
vec3 matViewPos = ilv_screenToView(screenPos);

vec3 V = normalize(-matViewPos);
float NdotV = max(dot(matNormal, V), 0.0);
float fresnel = pow(1.0 - NdotV, 3.0) * MATERIAL_REFLECTION_FRESNEL;

float matDayFactor = smoothstep(0.02, 0.10, fract(sunAngle)) * smoothstep(0.48, 0.40, fract(sunAngle));
fresnel *= mix(0.1, 1.0, matDayFactor);
matReflStr = mix(matReflStr * 0.4, matReflStr, fresnel);

float matSsrDist = length(matViewPos);
float matSsrFade = 1.0 - smoothstep(float(SSR_RENDER_DISTANCE) * 0.8, float(SSR_RENDER_DISTANCE), matSsrDist);
matReflStr *= matSsrFade;
float matSkylight = texelFetch(colortex1, texelcoord, 0).b;

if (matReflStr > 0.001) {

vec3 preSSRColor = color;
ilv_addMaterialReflection(color, matViewPos, matNormal, matReflStr, matSkylight);

vec3 ssrDelta = max(color - preSSRColor, vec3(0.0));

float ssrBrightness = dot(ssrDelta, vec3(0.299, 0.587, 0.114));
if (ssrBrightness > 0.05) {
ssrDelta *= 2.5;
}

color = preSSRColor;
ssrTaaOutput = vec4(ssrDelta, 1.0);
}

}
}
}
#endif

#if defined(PUDDLES_ENABLED)
{
float rs = clamp(rainStrength, 0.0, 1.0);
float puddleStrength = clamp(PUDDLES_STRENGTH, 0.0, 1.0) * rs;

float puddleDepth2 = depth2;
bool isHandHeld = isHandEarly;
if (!isWater && !isEntityOrHand && !isHandHeld && puddleStrength > 0.0001 && isEyeInWater != 1) {
float puddleDepth = puddleDepth2;
float pxSkylight = texelFetch(colortex1, texelcoord, 0).b;
float pxOutlineMask = texelFetch(colortex1, texelcoord, 0).r;
bool isLeafPixel = (pxOutlineMask < 0.1);
if (puddleDepth < 0.9999 && pxSkylight > 0.95 && !isLeafPixel) {
vec2 px = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
vec3 puddleViewPos = ilv_screenToView(vec3(texcoord, puddleDepth));
float dR = texelFetch(depthtex2, ivec2(texelcoord + ivec2(1, 0)), 0).r;
float dL = texelFetch(depthtex2, ivec2(texelcoord + ivec2(-1, 0)), 0).r;
float dU = texelFetch(depthtex2, ivec2(texelcoord + ivec2(0, -1)), 0).r;
float dD = texelFetch(depthtex2, ivec2(texelcoord + ivec2(0, 1)), 0).r;
vec3 vR = ilv_screenToView(vec3(texcoord + vec2(px.x, 0.0), dR));
vec3 vL = ilv_screenToView(vec3(texcoord - vec2(px.x, 0.0), dL));
vec3 vU = ilv_screenToView(vec3(texcoord - vec2(0.0, px.y), dU));
vec3 vD = ilv_screenToView(vec3(texcoord + vec2(0.0, px.y), dD));
vec3 pdx = vR - vL;
vec3 pdy = vD - vU;
vec3 viewNormal = normalize(cross(pdx, pdy));
vec3 upV = normalize(gbufferModelView[1].xyz);
float upness = clamp(abs(dot(viewNormal, upV)), 0.0, 1.0);
float flatMask = smoothstep(0.85, 0.98, upness);

vec3 scenePos = (gbufferModelViewInverse * vec4(puddleViewPos, 1.0)).xyz;
vec3 puddleWorldPos = scenePos + cameraPosition;
float n = smoothChunkNoise(puddleWorldPos.xz * 0.12);
float patches = smoothstep(0.62, 0.86, n);
patches = pow(patches, 1.35);
float outer = smoothstep(0.56, 0.82, n);
float inner = patches;
float edgeBand = clamp(outer - inner, 0.0, 1.0);

float topSkyGate = smoothstep(0.90, 0.98, pxSkylight);
float puddleMask = puddleStrength * flatMask * patches * topSkyGate;
if (puddleMask > 0.0001) {
float wetDarken = mix(1.0, 0.80, puddleMask);
wetDarken *= mix(1.0, 0.82, edgeBand * puddleStrength);
color *= wetDarken;
color += vec3(0.03) * edgeBand * puddleStrength;

vec3 reflNormal = normalize(mix(viewNormal, upV, 0.75));
float t = float(frameCounter) * 0.016;
float r1 = sin(puddleWorldPos.x * 18.0 + t * 6.0);
float r2 = sin(puddleWorldPos.z * 21.0 - t * 5.2);
float r3 = sin((puddleWorldPos.x + puddleWorldPos.z) * 14.0 + t * 7.4);
float r4 = sin((puddleWorldPos.x - puddleWorldPos.z) * 32.0 - t * 8.1);
float ripple = (r1 + r2 + 0.65 * r3 + 0.35 * r4) / 3.0;
float rippleAmp = 0.014 * rs * puddleStrength;
vec3 tangent = normalize(cross(upV, vec3(0.0, 0.0, 1.0)));
if (length(tangent) < 0.01) tangent = normalize(cross(upV, vec3(1.0, 0.0, 0.0)));
vec3 bitangent = normalize(cross(upV, tangent));
reflNormal = normalize(reflNormal + tangent * (ripple * rippleAmp) + bitangent * (r2 * rippleAmp * 0.35));
float reflStr = puddleMask * clamp(PUDDLES_REFLECTION_STRENGTH, 0.0, 1.0);
reflStr *= mix(0.85, 1.20, patches);
reflStr *= (1.0 - 0.05 * abs(ripple) * rs);
ilv_addReflection(color, puddleViewPos, reflNormal, vec2(0.0, 1.0), reflStr, vec2(0.0));
}
}
}
}
#endif

#if defined(WALL_RUNOFF_ENABLED)
{
float rs = clamp(rainStrength, 0.0, 1.0);
float runoffStrength = clamp(WALL_RUNOFF_STRENGTH, 0.0, 1.0) * rs;
if (!isWater && runoffStrength > 0.0001 && isEyeInWater != 1) {
float pxSkylight = texelFetch(colortex1, texelcoord, 0).b;
float outdoor = smoothstep(0.15, 0.60, pxSkylight);
if (outdoor > 0.001) {
float roDepth = texelFetch(depthtex2, texelcoord, 0).r;
if (roDepth < 0.9999) {
vec2 px = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
vec3 roViewPos = ilv_screenToView(vec3(texcoord, roDepth));
float rdR = texelFetch(depthtex2, ivec2(texelcoord + ivec2(1, 0)), 0).r;
float rdL = texelFetch(depthtex2, ivec2(texelcoord + ivec2(-1, 0)), 0).r;
float rdU = texelFetch(depthtex2, ivec2(texelcoord + ivec2(0, -1)), 0).r;
float rdD = texelFetch(depthtex2, ivec2(texelcoord + ivec2(0, 1)), 0).r;
vec3 roVR = ilv_screenToView(vec3(texcoord + vec2(px.x, 0.0), rdR));
vec3 roVL = ilv_screenToView(vec3(texcoord - vec2(px.x, 0.0), rdL));
vec3 roVU = ilv_screenToView(vec3(texcoord - vec2(0.0, px.y), rdU));
vec3 roVD = ilv_screenToView(vec3(texcoord + vec2(0.0, px.y), rdD));
vec3 roDx = roVR - roVL;
vec3 roDy = roVD - roVU;
vec3 roViewNormal = normalize(cross(roDx, roDy));
vec3 roUpV = normalize(gbufferModelView[1].xyz);
float roUpness = clamp(abs(dot(roViewNormal, roUpV)), 0.0, 1.0);
float vertical = 1.0 - smoothstep(0.30, 0.70, roUpness);

vec3 roScenePos = (gbufferModelViewInverse * vec4(roViewPos, 1.0)).xyz;
vec3 roWorldPos = roScenePos + cameraPosition;

float laneLayout = runoffNoise(roWorldPos.xz * 0.90);
float lanes = roWorldPos.x * 2.2 + roWorldPos.z * 1.7 + laneLayout * 2.0;
float laneCell = fract(lanes);
float laneCore = 1.0 - abs(laneCell - 0.5) * 2.0;
laneCore = pow(clamp(laneCore, 0.0, 1.0), 6.0);

float t = float(frameCounter) * 0.016 * clamp(WALL_RUNOFF_SPEED, 0.0, 5.0);
float flow = fract(roWorldPos.y * 1.25 - t + laneLayout);
float drops = smoothstep(0.10, 0.00, flow) + smoothstep(0.90, 1.00, flow);
drops = clamp(drops, 0.0, 1.0);

float mask = runoffStrength * outdoor * vertical * laneCore;
mask *= mix(0.55, 1.0, drops);
mask = clamp(mask, 0.0, 1.0);

if (mask > 0.0001) {
color *= mix(1.0, 0.86, mask);
color += vec3(0.05, 0.06, 0.07) * mask;
}
}
}
}
}
#endif

#endif
#endif

if (isEyeInWater == 1) {
float uwtDepth = texture(depthtex0, texcoord).r;
if (uwtDepth < 1.0) {
float uwtEmissive = texture(colortex1, texcoord).g;

float emissiveReduce = (uwtEmissive > 0.5) ? 0.15 : 1.0;
vec4 uwtClip = vec4(texcoord * 2.0 - 1.0, uwtDepth * 2.0 - 1.0, 1.0);
vec4 uwtView = gbufferProjectionInverse * uwtClip;
uwtView /= uwtView.w;
float uwtDist = length(uwtView.xyz);
float tintAmount = smoothstep(0.0, 40.0, uwtDist) * 0.6 * emissiveReduce;
vec3 uwTintColor = vec3(UNDERWATER_FOG_R, UNDERWATER_FOG_G, UNDERWATER_FOG_B);
float lumUW = dot(color, vec3(0.299, 0.587, 0.114));
vec3 tintedUW = lumUW * uwTintColor;
color = mix(color, tintedUW, tintAmount);
}
}

#if defined(ATMO_FOG_ENABLED) || defined(UNDERWATER_FOG_ENABLED)
if (isEyeInWater == 1) {
vec4 atmoFog = max(texture(colortex9, texcoord), vec4(0.0));
if (atmoFog.a > 0.001) {
float uwEmissive = texture(colortex1, texcoord).g;
float emissiveBypass = uwEmissive * 0.5 * (1.0 - smoothstep(0.3, 0.6, atmoFog.a));
float uwFogAlpha = atmoFog.a * (1.0 - emissiveBypass);
color = atmoFog.rgb * (uwFogAlpha / max(atmoFog.a, 0.001)) + color * (1.0 - uwFogAlpha);
}
}
#endif

#ifdef UNDERWATER_FOG_ENABLED
if (isEyeInWater == 1) {
float uwEmissiveBoost = texture(colortex1, texcoord).g;
if (uwEmissiveBoost > 0.01) {
vec4 uwFogCheck = max(texture(colortex9, texcoord), vec4(0.0));
float uwFogTrans = 1.0 - uwFogCheck.a;
color *= 1.0 + uwEmissiveBoost * 3.5 * uwFogTrans;
}
}
#endif

#ifdef UNDERWATER_FOG_ENABLED
if (isEyeInWater == 1) {
vec4 cloudData = texture(colortex8, texcoord);
float uwDepthBelow = float(SEA_LEVEL_OFFSET) - cameraPosition.y;
float uwBandFade = smoothstep(0.5, 6.0, uwDepthBelow);
cloudData.a *= (1.0 - uwBandFade);
cloudData.rgb *= (1.0 - uwBandFade);
if (cloudData.a > 0.001 && !entityInFront && !particleOverSky) {
color += cloudData.rgb * cloudData.a;
}
}
#endif

#if !defined(NETHER_SHADER) && !defined(END_SHADER)
{
vec2 sunUV = getSunScreenUV();
float fsAngle = fract(sunAngle);
float fsDayVis = smoothstep(0.02, 0.08, fsAngle) * smoothstep(0.48, 0.42, fsAngle);
float fsSunrise = smoothstep(0.0, 0.03, fsAngle) * smoothstep(0.10, 0.06, fsAngle);
float fsSunset  = smoothstep(0.40, 0.44, fsAngle) * smoothstep(0.48, 0.46, fsAngle);
float fsVis = fsDayVis + max(fsSunrise, fsSunset) * 0.5;

if (sunUV.x > -0.5 && fsVis > 0.001) {
vec2 delta = texcoord - sunUV;
delta.x *= viewWidth / viewHeight;
float dist = length(delta);

float noonFactor = 1.0 - smoothstep(0.0, 0.25, abs(fsAngle - 0.25));
float radiusScale = mix(1.0, 1.8, noonFactor);

float r = SUN_GLOW_RADIUS * 0.08 * radiusScale;
float glow = exp(-dist * dist / (r * r));

float r2 = SUN_GLOW_RADIUS * 0.2 * radiusScale;
float halo = 1.0 / (1.0 + pow(dist / r2, 4.0));

float combined = glow * 0.35 + halo * 0.08;
combined *= fsVis * SUN_GLOW_INTENSITY;
if (isEyeInWater == 1) combined *= 0.0;

bool postIsSky = isSky && !hasValidDHDepth(dhDepth);
if (!postIsSky) {
#ifdef WEATHER_FOG_ENABLED
float weatherAlpha = max(texture(colortex11, texcoord), vec4(0.0)).a;
combined *= weatherAlpha * 0.5;
#else
combined = 0.0;
#endif
}
combined *= smoothstep(0.0, 0.15, max(rainStrength, biome_swamp));

color += vec3(1.0) * combined;
}
}
#endif

#if !defined(NETHER_SHADER) && !defined(END_SHADER)
{
vec3 moonDirView = normalize(moonPosition);
vec3 moonPosView = moonDirView * 1000.0;
vec4 moonClip = gbufferProjection * vec4(moonPosView, 1.0);
if (moonClip.w > 0.00001) {
vec2 moonUV = (moonClip.xy / moonClip.w) * 0.5 + 0.5;
float moonAngle = fract(sunAngle);
float moonVis = smoothstep(0.52, 0.58, moonAngle) * (1.0 - smoothstep(0.94, 0.98, moonAngle));

if (moonVis > 0.001) {
vec2 moonDelta = texcoord - moonUV;
moonDelta.x *= viewWidth / viewHeight;
float moonDist = length(moonDelta);

float mr = SUN_GLOW_RADIUS * 0.12;
float moonGlow = exp(-moonDist * moonDist / (mr * mr));

float mr2 = SUN_GLOW_RADIUS * 0.35;
float moonHalo = 1.0 / (1.0 + pow(moonDist / mr2, 4.0));

float moonCombined = moonGlow * 0.25 + moonHalo * 0.04;
moonCombined *= moonVis;
if (isEyeInWater == 1) moonCombined = 0.0;
bool postIsSkyMoon = isSky && !hasValidDHDepth(dhDepth);
if (!postIsSkyMoon) moonCombined = 0.0;

color += vec3(0.7, 0.8, 1.0) * moonCombined;
}
}
}
#endif

#if !defined(NETHER_SHADER) && !defined(END_SHADER)
{
if (!isSkylessWorldHeuristic()) {
ivec2 sunTexel = ivec2(gl_FragCoord.xy);
float sunDepthMC = texelFetch(depthtex0, sunTexel, 0).x;
float sunDepthDH = texelFetch(dhDepthTex, sunTexel, 0).x;
bool sunIsSky = (sunDepthMC >= 0.9999 && !hasValidDHDepth(sunDepthDH));
if (sunIsSky && fogAmount > 0.05) {
float sunGateAngle = fract(sunAngle);
float sunTexGate = smoothstep(0.0, 0.04, sunGateAngle) * (1.0 - smoothstep(0.50, 0.54, sunGateAngle));
float savedLum = dot(savedSunColor, vec3(0.299, 0.587, 0.114));
float foggedLum = dot(color, vec3(0.299, 0.587, 0.114));
float sunStrength = smoothstep(0.15, 0.4, savedLum - foggedLum);
sunStrength *= 1.0 - smoothstep(0.3, 0.8, fogAmount);
sunStrength *= sunTexGate;
color = mix(color, savedSunColor, sunStrength);
}
}
}
#endif

if (isEyeInWater == 1) {
float uwEmissiveFlag = texture(colortex1, texcoord).g;
float uwTintStr = (uwEmissiveFlag > 0.5) ? 0.05 : 1.0;
vec3 uwScreenTint = vec3(UNDERWATER_FOG_R, UNDERWATER_FOG_G, UNDERWATER_FOG_B);
vec3 uwOrigColor = color;

color.r *= mix(0.55, 0.75, uwScreenTint.r);
color.g *= mix(0.75, 0.95, uwScreenTint.g);

float uwLum = dot(color, vec3(0.299, 0.587, 0.114));
color.b = mix(color.b, max(color.b, uwLum * 0.6), 0.3);

color = mix(vec3(uwLum), color, 0.85);

color = mix(uwOrigColor, color, uwTintStr);
}

if (darknessFactor > 0.01) {
float darkPulse = darknessLightFactor;

float emFlag = texture(colortex1, texcoord).g;
float emResist = (emFlag > 0.5) ? 0.4 : 0.0;
float darkenAmount = darkPulse * (1.0 - emResist);
color *= 1.0 - darkenAmount * 0.85;

vec2 vignetteUV = texcoord * 2.0 - 1.0;
float vignette = dot(vignetteUV, vignetteUV);
color *= 1.0 - vignette * darkPulse * 0.5;
}

if (blindness > 0.01) {
float blindDepth = texture(depthtex0, texcoord).r;
if (blindDepth < 0.9999) {
vec4 blindClip = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, blindDepth * 2.0 - 1.0, 1.0);
float blindDist = length(blindClip.xyz / blindClip.w);
float blindFog = smoothstep(3.0, 6.0, blindDist) * blindness;
color = mix(color, vec3(0.0), blindFog);
} else {

color = mix(color, vec3(0.0), blindness);
}
}

if (nightVision > 0.01) {
float nvLum = dot(color, vec3(0.299, 0.587, 0.114));

float nvBoost = (1.0 - smoothstep(0.0, 0.5, nvLum)) * 0.6;
color *= 1.0 + nvBoost * nightVision;

color.g *= 1.0 + 0.05 * nightVision;
}

gl_FragData[0] = vec4(color, cloudAlpha);

if (ssrTaaOutput.a < 0.5) ssrTaaOutput = vec4(fogAmount, 0.0, 0.0, 0.0);
gl_FragData[1] = ssrTaaOutput;
}
