#ifndef ILV_REFLECTIONS_GLSL
#define ILV_REFLECTIONS_GLSL

#include "/include/sky_night_features.glsl"
#include "/include/sky_timeline.glsl"

vec4 startMat(vec3 pos) {
return vec4(pos.xyz, 1.0);
}

vec3 endMat(vec4 pos) {
return pos.xyz / pos.w;
}

float ilv_bayer2  (vec2 a) { a = 0.5 * floor(a); return fract(1.5 * fract(a.y) + a.x); }
float ilv_bayer4  (vec2 a) { return 0.25 * ilv_bayer2  (0.5 * a) + ilv_bayer2(a); }
float ilv_bayer8  (vec2 a) { return 0.25 * ilv_bayer4  (0.5 * a) + ilv_bayer2(a); }
float ilv_bayer16 (vec2 a) { return 0.25 * ilv_bayer8  (0.5 * a) + ilv_bayer2(a); }
float ilv_bayer32 (vec2 a) { return 0.25 * ilv_bayer16 (0.5 * a) + ilv_bayer2(a); }
float ilv_bayer64 (vec2 a) { return 0.25 * ilv_bayer32 (0.5 * a) + ilv_bayer2(a); }

float ilv_pack_2x8(vec2 v) {
return dot(floor(255.0 * v + 0.5), vec2(1.0 / 65535.0, 256.0 / 65535.0));
}
float ilv_pack_2x8(float x, float y) { return ilv_pack_2x8(vec2(x, y)); }

vec2 ilv_unpack_2x8(float pack) {
vec2 xy; xy.x = modf((65535.0 / 256.0) * pack, xy.y);
return xy * vec2(256.0 / 255.0, 1.0 / 255.0);
}

vec2 ilv_encodeNormal(vec3 v) {
v /= abs(v.x) + abs(v.y) + abs(v.z);
v.xy = (v.z >= 0.0) ? v.xy : (1.0 - abs(v.yx)) * (vec2(v.x >= 0.0, v.y >= 0.0) * 2.0 - 1.0);
return v.xy * 0.5 + 0.5;
}

vec3 ilv_decodeNormal(vec2 v) {
vec2 f = v * 2.0 - 1.0;
vec3 n = vec3(f, 1.0 - abs(f.x) - abs(f.y));
float t = max(-n.z, 0.0);
n.xy += vec2(n.x >= 0.0 ? -t : t, n.y >= 0.0 ? -t : t);
return normalize(n);
}

vec3 ilv_screenToView(vec3 pos) {
vec4 iProjDiag = vec4(
gbufferProjectionInverse[0].x,
gbufferProjectionInverse[1].y,
gbufferProjectionInverse[2].zw
);
vec3 p3 = pos * 2.0 - 1.0;
vec4 viewPos = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
return viewPos.xyz / viewPos.w;
}

#ifndef RAIN_STRENGTH_DECLARED
#define RAIN_STRENGTH_DECLARED
uniform float rainStrength;
#endif

#ifndef WETNESS_DECLARED
#define WETNESS_DECLARED
uniform float wetness;
#endif

#ifndef FRAME_TIME_COUNTER_DECLARED
#define FRAME_TIME_COUNTER_DECLARED
uniform float frameTimeCounter;
#endif

vec3 ilv_getSkyColor(vec3 viewDir, vec3 worldPos) {
#ifdef END_SHADER
vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
float height = max(worldDir.y, 0.0);

vec3 horizonColor = vec3(END_SKY_HORIZON_R, END_SKY_HORIZON_G, END_SKY_HORIZON_B);
vec3 midColor = vec3(END_SKY_MID_R, END_SKY_MID_G, END_SKY_MID_B);
vec3 zenithColor = vec3(END_SKY_ZENITH_R, END_SKY_ZENITH_G, END_SKY_ZENITH_B);

float midSmooth = smoothstep(0.25, 0.65, height);
vec3 sky = mix(mix(horizonColor, midColor, smoothstep(0.0, 0.25, height)), zenithColor, midSmooth);

if (worldDir.y < 0.0) {
float belowFade = smoothstep(0.0, -0.4, worldDir.y);
#ifdef END_FOG_ENABLED
vec3 voidColor = vec3(END_FOG_R, END_FOG_G, END_FOG_B);
#else
vec3 voidColor = horizonColor * 0.3;
#endif
sky = mix(horizonColor, voidColor, belowFade);
}

return sky * END_SKY_BRIGHTNESS * 0.5;
#else

float angle = fract(sunAngle);
TimeWeightsSimple ts = getTimeWeightsSimple(sunAngle);

float upDot = dot(viewDir, gbufferModelView[1].xyz);
float belowHorizon = max(-upDot, 0.0);
float groundFade = smoothstep(0.0, 0.15, belowHorizon);
float upDotClamped = max(upDot, 0.0);

float horizonBias = 1.0 - upDotClamped;
horizonBias *= horizonBias;
horizonBias *= horizonBias;
horizonBias = 1.0 - horizonBias;
vec3 skCol = getTimelineHorizonColor(sunAngle, horizonBias);

{
vec3 biomeHorizon = skCol;
vec3 biomeMid = skCol;
vec3 biomeZenith = skCol;
bool hasBiomeSky = false;
if (biome_snowy > 0.001) {
biomeHorizon = mix(biomeHorizon, vec3(0.92, 0.94, 0.96), biome_snowy);
biomeMid = mix(biomeMid, vec3(0.88, 0.91, 0.95), biome_snowy);
biomeZenith = mix(biomeZenith, vec3(0.75, 0.85, 0.95), biome_snowy);
hasBiomeSky = true;
}
if (biome_jungle > 0.001) {
biomeHorizon = mix(biomeHorizon, vec3(81.0, 189.0, 92.0) / 255.0, biome_jungle);
biomeMid = mix(biomeMid, vec3(154.0, 194.0, 110.0) / 255.0, biome_jungle);
biomeZenith = mix(biomeZenith, vec3(122.0, 211.0, 255.0) / 255.0, biome_jungle);
hasBiomeSky = true;
}
if (biome_swamp > 0.001) {
biomeHorizon = mix(biomeHorizon, vec3(66.0, 128.0, 75.0) / 255.0, biome_swamp);
biomeMid = mix(biomeMid, vec3(83.0, 77.0, 102.0) / 255.0, biome_swamp);
biomeZenith = mix(biomeZenith, vec3(144.0, 199.0, 90.0) / 255.0, biome_swamp);
hasBiomeSky = true;
}
if (biome_arid > 0.001) {
biomeHorizon = mix(biomeHorizon, vec3(235.0, 213.0, 185.0) / 255.0, biome_arid);
biomeMid = mix(biomeMid, vec3(214.0, 206.0, 224.0) / 255.0, biome_arid);
biomeZenith = mix(biomeZenith, vec3(191.0, 198.0, 255.0) / 255.0, biome_arid);
hasBiomeSky = true;
}
if (hasBiomeSky) {
float midBlend = smoothstep(0.0, 0.3, upDotClamped);
float zenithBlend = smoothstep(0.3, 0.7, upDotClamped);
vec3 biomeSky = mix(biomeHorizon, mix(biomeMid, biomeZenith, zenithBlend), midBlend);
float dayGate = ts.day + ts.twilight * 0.7;

float swampGate = clamp(biome_swamp, 0.0, 1.0);
float timeGate = mix(dayGate, 1.0, swampGate);
float biomeWeight = max(max(biome_jungle, biome_swamp), max(biome_snowy, biome_arid));
skCol = mix(skCol, biomeSky, biomeWeight * timeGate);
}
}

skCol *= mix(1.0, 0.7, upDotClamped);

vec3 groundColor = getTimelineHorizonColor(sunAngle, 0.0);
skCol = mix(skCol, groundColor, groundFade);

float sunDot = dot(viewDir, normalize(shadowLightPosition)) * 0.5 + 0.5;
sunDot = 1.0 - (1.0 - sunDot) * (1.0 - sunDot);
sunDot *= 1.0 - upDotClamped;
sunDot *= 1.0 - (1.0 - ts.twilight) * (1.0 - ts.twilight);
vec3 sunHorizon = sunAngle > 0.25 && sunAngle < 0.75
? vec3(SUNSET_HORIZON_R, SUNSET_HORIZON_G, SUNSET_HORIZON_B)
: vec3(SUNRISE_HORIZON_R, SUNRISE_HORIZON_G, SUNRISE_HORIZON_B);

skCol *= 1.0 + sunDot * 0.3 * (1.0 - clamp(biome_swamp, 0.0, 1.0));

skCol *= mix(1.0, 0.6, clamp(biome_swamp, 0.0, 1.0));

TimeWeights tw = getTimeWeights(sunAngle);
float heightBlend = smoothstep(0.0, 0.5, max(upDotClamped, 0.0));

float daySunsetMix = min(tw.day, tw.sunset + tw.sunrise) * 2.0;
vec3 daySunsetCP = mix(vec3(1.0, 0.92, 0.4), vec3(0.85, 0.15, 0.55), heightBlend);
daySunsetCP *= max(DAY_BRIGHTNESS, SUNSET_BRIGHTNESS);
skCol = mix(skCol, daySunsetCP, daySunsetMix * mix(0.4, 0.5, heightBlend));

float sunsetBlueMix = min(tw.sunset, tw.blueHour) * 2.0;
vec3 sunsetBlueCP = mix(vec3(0.9, 0.25, 0.55), vec3(0.4, 0.1, 1.0), heightBlend);
sunsetBlueCP *= mix(SUNSET_BRIGHTNESS, BLUEHOUR_BRIGHTNESS, 0.5);
skCol = mix(skCol, sunsetBlueCP, sunsetBlueMix * mix(0.35, 0.5, heightBlend));

float reflNightDim = tw.night + tw.blueHour;
skCol *= 1.0 - reflNightDim * 0.8;

float skLum = dot(skCol, vec3(0.299, 0.587, 0.114));
skCol = mix(vec3(skLum), skCol, SKY_SATURATION * 1.2);
skCol = max(skCol, vec3(0.0));

vec3 reflWorldDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
vec3 nightSkyFeatures = skyAddNightFeatures(vec3(0.0), reflWorldDir, sunAngle, frameTimeCounter, rainStrength);
nightSkyFeatures *= 1.0 - clamp(biome_swamp, 0.0, 1.0);
skCol += nightSkyFeatures;

if (biome_swamp > 0.01) {
float upBlend = smoothstep(0.0, 0.5, upDotClamped);
vec3 swampReflSky = mix(vec3(66.0, 128.0, 75.0) / 255.0, vec3(144.0, 199.0, 90.0) / 255.0, upBlend);
swampReflSky *= 0.15;
skCol = mix(skCol, swampReflSky, biome_swamp);
}

vec3 skyTint = skCol;

float cloudRainFade = 1.0 - max(wetness, rainStrength) * (float(CLOUD_RAIN_OPACITY_REDUCTION) / 100.0);

#ifdef CLOUDS_3D_ENABLED
{

if (reflWorldDir.y > 0.01) {
float gameTimeSec = (float(worldDay) * 24000.0 + float(worldTime)) / 20.0;
vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
vec4 cloudResult = renderCloudReflection(reflWorldDir, gameTimeSec, worldPos, sunAngle, sunDirWorld, gl_FragCoord.xy, frameCounter);
cloudResult.a *= cloudRainFade;
cloudResult.a *= 1.0 - biome_swamp;
cloudResult.a *= 0.4;
if (cloudResult.a > 0.001) {

float cLum = dot(cloudResult.rgb, vec3(0.299, 0.587, 0.114));
vec3 skyNorm = skyTint / max(dot(skyTint, vec3(0.299, 0.587, 0.114)), 0.01);
vec3 tintedCloud = mix(cloudResult.rgb, cLum * skyNorm * 1.4, 0.35);
tintedCloud *= 1.6;
skCol = mix(skCol, tintedCloud, cloudResult.a);
}
}
}
#endif

#ifdef CLOUDS_VANILLA_ENABLED
{
if (reflWorldDir.y > 0.01) {
float gameTimeSec = (float(worldDay) * 24000.0 + float(worldTime)) / 20.0;
vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
float vanHitT = 0.0;
vec4 vanResult = computeVanillaClouds(reflWorldDir, gameTimeSec, worldPos, sunAngle, sunDirWorld, 30000.0, gl_FragCoord.xy, frameCounter, vanHitT, cloudRainFade);
vanResult.a *= 1.0 - biome_swamp;
vanResult.a *= 0.4;
if (vanResult.a > 0.001) {

float cLum = dot(vanResult.rgb, vec3(0.299, 0.587, 0.114));
vec3 skyNorm = skyTint / max(dot(skyTint, vec3(0.299, 0.587, 0.114)), 0.01);
vec3 tintedCloud = mix(vanResult.rgb, cLum * skyNorm, 0.4);
tintedCloud *= 1.6;
skCol = mix(skCol, tintedCloud, vanResult.a);
}
}
}
#endif

float reflHorizonFade = 1.0 - max(reflWorldDir.y, 0.0);
reflHorizonFade = reflHorizonFade * reflHorizonFade * reflHorizonFade;
vec3 reflFogColor = getTimelineHorizonColor(sunAngle, 0.0);
skCol = mix(skCol, reflFogColor, reflHorizonFade * 0.5);

return skCol;
#endif
}

void ilv_raytrace(out vec2 reflectionPos, out float border, vec3 viewPos, vec3 reflectionDir, vec3 normal, float dither) {

border = 0.0;

vec3 screenPos = endMat(gbufferProjection * startMat(viewPos)) * 0.5 + 0.5;
vec3 viewEnd = viewPos + reflectionDir;
vec3 screenEnd = endMat(gbufferProjection * startMat(viewEnd)) * 0.5 + 0.5;
vec3 screenDir = normalize(screenEnd - screenPos);

vec3 start = viewPos + normal * (length(viewPos) * 0.025 + 0.05);
vec3 step = reflectionDir * 0.5;
vec3 marchPos = start + step;
vec3 totalStep = step;

int refinements = 0;
int maxRefinements = 10;

for (int i = 0; i < REFLECTION_ITERATIONS; i++) {

vec3 refPos = endMat(gbufferProjection * startMat(marchPos)) * 0.5 + 0.5;

if (refPos.x < -0.05 || refPos.x > 1.05 || refPos.y < -0.05 || refPos.y > 1.05) break;

float sceneDepth = texture(depthtex1, refPos.xy).r;
vec3 sceneViewPos = ilv_screenToView(vec3(refPos.xy, sceneDepth));
float err = length(marchPos - sceneViewPos);

vec2 screenDelta = refPos.xy - screenPos.xy;
bool correctDirection = dot(screenDelta, screenDir.xy) > 0.0;

if (err < length(step) * 3.0 && correctDirection) {

refinements++;
if (refinements >= maxRefinements) {
reflectionPos = refPos.xy;

float edgeX = smoothstep(0.0, 0.15, min(refPos.x, 1.0 - refPos.x));
float edgeY = smoothstep(0.0, 0.15, min(refPos.y, 1.0 - refPos.y));
border = edgeX * edgeY;
return;
}
totalStep -= step;
step *= 0.1;
}
step *= 2.0;
totalStep += step;
marchPos = start + totalStep;
}
}

void ilv_raytrace(out vec2 reflectionPos, out int error, vec3 viewPos, vec3 reflectionDir, vec3 normal) {
float border;
ilv_raytrace(reflectionPos, border, viewPos, reflectionDir, normal, 0.5);
error = (border > 0.001) ? 0 : 1;
}

void ilv_addReflection(inout vec3 color, vec3 viewPos, vec3 normal, vec2 lmcoord, float reflectionStrength, vec2 uvOffset) {

vec3 reflectionDirection = reflect(normalize(viewPos), normalize(normal));
vec2 reflectionPos;
float border;
float dither = ilv_bayer8(gl_FragCoord.xy);
ilv_raytrace(reflectionPos, border, viewPos, reflectionDirection, normal, dither);

float fresnel = 1.0 - abs(dot(normalize(viewPos), normal));
fresnel *= fresnel;
fresnel *= fresnel;

float fresnelMod = mix(0.7, 1.0, fresnel) * WATER_REFLECTION_FADE;
fresnelMod = clamp(fresnelMod, 0.0, 1.0);
reflectionStrength *= fresnelMod;

vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;

float wt = frameTimeCounter * WATER_WAVE_SPEED;
vec2 wp = worldPos.xz * WATER_WAVE_SCALE * 2.5;
float waveX = sin(wp.x * 3.0 + wp.y * 0.3 + wt * 1.5) * 0.5
+ sin(wp.x * 5.0 + wp.y * 0.5 + wt * 2.2) * 0.3
+ sin(wp.x * 8.0 + wp.y * 0.2 + wt * 3.0) * 0.2;
float waveZ = sin(wp.x * 0.3 + wp.y * 3.0 + wt * 1.3) * 0.5
+ sin(wp.x * 0.5 + wp.y * 5.0 + wt * 2.0) * 0.3;

reflectionPos.x += waveX * 0.004;
reflectionPos.y += waveZ * 0.003;

vec3 skyReflDir = reflectionDirection;
skyReflDir.x += waveX * 0.01;
skyReflDir.z += waveZ * 0.01;
skyReflDir = normalize(skyReflDir);
vec3 skyColor = ilv_getSkyColor(skyReflDir, worldPos);

skyColor *= 1.6;

if (isEyeInWater == 1) {
skyColor = 0.08 + 0.125 * skyColor;
skyColor += vec3(0.0, 0.03, 0.3);
}

const float inputColorWeight = 0.2;

vec3 ssrColor = vec3(0.0);
if (border > 0.001) {
float hitDepth0 = texture(depthtex0, reflectionPos).r;
float hitDepth1 = texture(depthtex1, reflectionPos).r;
float hitVoxyMarker = texture(colortex1, reflectionPos).a;
bool hitIsVoxyTerrain = (hitVoxyMarker > 0.999);

bool hitIsWater = (hitDepth0 < hitDepth1 - 0.0001);

if (hitDepth0 >= 0.9999 && !hitIsVoxyTerrain) {
border = 0.0;
} else {
ssrColor = texture(colortex0, reflectionPos).rgb;
}

}

TimeWeightsSimple rbTS = getTimeWeightsSimple(sunAngle);
float rbDay = rbTS.day + rbTS.twilight;
float rbNight = rbTS.night + rbTS.blueHour;
float rbTOD = mix(0.20, 1.0, rbNight / max(rbDay + rbNight, 0.001));
float rbActive = max(rbDay, rbNight);
rbTOD = mix(0.60, rbTOD, rbActive);
float nightBlend = rbNight / max(rbDay + rbNight, 0.001);
float activeBlend = rbActive;

float skyBright = mix(WATER_SKY_BRIGHTNESS_DAY, WATER_SKY_BRIGHTNESS_NIGHT, nightBlend);
skyBright = mix(mix(WATER_SKY_BRIGHTNESS_DAY, WATER_SKY_BRIGHTNESS_NIGHT, 0.5), skyBright, activeBlend);

float skyGate = smoothstep(13.0 / 15.0, 14.0 / 15.0, lmcoord.y);

vec3 skyRefl = skyColor * skyBright * skyGate * rbTOD;
skyRefl *= (1.0 - inputColorWeight) + color * inputColorWeight;

ssrColor *= 1.5;

if (border > 0.001) {

vec4 reflAtmoFog = max(texture(colortex9, reflectionPos), vec4(0.0));
if (reflAtmoFog.a > 0.001) {
ssrColor = reflAtmoFog.rgb + ssrColor * (1.0 - reflAtmoFog.a);
}

vec4 reflHazeFog = max(texture(colortex10, reflectionPos), vec4(0.0));
if (reflHazeFog.a > 0.001) {
ssrColor = reflHazeFog.rgb + ssrColor * (1.0 - reflHazeFog.a);
}

vec4 reflWeatherFog = max(texture(colortex11, reflectionPos), vec4(0.0));
if (reflWeatherFog.a > 0.001) {
ssrColor = reflWeatherFog.rgb + ssrColor * (1.0 - reflWeatherFog.a);
}
}

vec3 reflectionColor = mix(skyRefl, ssrColor, border);
color = mix(color, reflectionColor, reflectionStrength);

}

void ilv_addMaterialReflection(inout vec3 color, vec3 viewPos, vec3 normal, float reflectionStrength, float skylight) {

vec3 roughNormal = normalize(normal);
float matRoughness = 0.20;
{
float dither = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
float dither2 = fract(sin(dot(gl_FragCoord.xy, vec2(93.989, 67.345))) * 24634.635);
vec3 tangent = normalize(cross(roughNormal, abs(roughNormal.y) > 0.9 ? vec3(1,0,0) : vec3(0,1,0)));
vec3 bitangent = cross(roughNormal, tangent);
roughNormal = normalize(roughNormal + (tangent * (dither - 0.5) + bitangent * (dither2 - 0.5)) * matRoughness);
}
vec3 reflectionDirection = reflect(normalize(viewPos), roughNormal);
vec2 reflectionPos;
int error;
ilv_raytrace(reflectionPos, error, viewPos, reflectionDirection, roughNormal);

float skyGate = step(14.0 / 15.0, skylight);
vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
vec3 skyColor = ilv_getSkyColor(reflectionDirection, worldPos) * 0.8 * skyGate;

vec3 surfaceColor = color;
float surfaceLum = dot(surfaceColor, vec3(0.299, 0.587, 0.114));
vec3 surfaceHue = (surfaceLum > 0.01) ? surfaceColor / surfaceLum : vec3(1.0);
surfaceHue = clamp(surfaceHue, vec3(0.0), vec3(3.0));

vec3 worldNormalMat = normalize(mat3(gbufferModelViewInverse) * normal);
float upFacing = abs(worldNormalMat.y);
reflectionStrength *= mix(0.1, 1.0, upFacing * upFacing);

if (error == 2) {
color = mix(color, color, reflectionStrength);
} else if (error == 0) {
float hitMarker = texture(colortex1, reflectionPos).a;
bool hitEntityLike = (hitMarker > 0.001 && hitMarker < 0.999);
float hitDepth = min(texture(depthtex2, reflectionPos).r, texture(depthtex1, reflectionPos).r);
if (hitEntityLike) {

color = mix(color, color, reflectionStrength);
} else if (hitDepth < 0.9999) {

float hitDist = length(viewPos);
float lod = log2(viewHeight / 8.0 * matRoughness * (1.0 - exp(-0.125 * matRoughness * hitDist))) * 0.5;
lod = max(lod, 0.0);
vec3 reflectionColor = textureLod(colortex0, reflectionPos, lod).rgb;

vec4 matAtmoFog = max(texture(colortex9, reflectionPos), vec4(0.0));
if (matAtmoFog.a > 0.001) {
reflectionColor = matAtmoFog.rgb + reflectionColor * (1.0 - matAtmoFog.a);
}
vec4 matHazeFog = max(texture(colortex10, reflectionPos), vec4(0.0));
if (matHazeFog.a > 0.001) {
reflectionColor = matHazeFog.rgb + reflectionColor * (1.0 - matHazeFog.a);
}
vec4 matWeatherFog = max(texture(colortex11, reflectionPos), vec4(0.0));
if (matWeatherFog.a > 0.001) {
reflectionColor = matWeatherFog.rgb + reflectionColor * (1.0 - matWeatherFog.a);
}

float edgeX = smoothstep(0.0, 0.15, min(reflectionPos.x, 1.0 - reflectionPos.x));
float edgeY = smoothstep(0.0, 0.15, min(reflectionPos.y, 1.0 - reflectionPos.y));
float edgeFade = edgeX * edgeY;

vec3 blended = mix(skyColor, reflectionColor, edgeFade);
float blendLum = dot(blended, vec3(0.299, 0.587, 0.114));
vec3 tintedBlend = blendLum * surfaceHue;
color = mix(color, mix(blended, tintedBlend, 1.0), reflectionStrength);
} else {

float skyLum = dot(skyColor, vec3(0.299, 0.587, 0.114));
vec3 tintedSky = skyLum * surfaceHue;
color = mix(color, mix(skyColor, tintedSky, 1.0), reflectionStrength);
}
} else {

float skyLum = dot(skyColor, vec3(0.299, 0.587, 0.114));
vec3 tintedSky = skyLum * surfaceHue;
color = mix(color, mix(skyColor, tintedSky, 1.0), reflectionStrength);
}
}

#endif
