#ifndef LIGHTING_GLSL
#define LIGHTING_GLSL

#include "/include/color_utils.glsl"
#include "/include/biome_overrides.glsl"
#include "/include/sky_timeline.glsl"

uniform float rainStrength;

uniform vec3 skyColor;

uniform int biome;

#ifdef HANDHELD_LIGHT_ENABLED
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int heldItemId;
uniform int heldItemId2;

uniform vec3 eyePosition;
#endif

vec3 normalizeLightColor(vec3 c);
vec3 getTimeOfDaySkylightColor(float sunAngle);
vec3 getDaySkylightTintColor();

#ifdef HANDHELD_LIGHT_ENABLED
vec3 getHandheldLightBoost(vec3 worldPos, vec3 baseColor, vec3 litColor) {
float mainHeld = clamp(float(max(heldBlockLightValue,  0)) / 15.0, 0.0, 1.0);
float offHeld  = clamp(float(max(heldBlockLightValue2, 0)) / 15.0, 0.0, 1.0);

float heldLevel;
int dominantId;
if (mainHeld >= offHeld) {
heldLevel   = mainHeld;
dominantId  = heldItemId;
} else {
heldLevel   = offHeld;
dominantId  = heldItemId2;
}
if (heldLevel < 0.001) return vec3(0.0);

vec3 playerCenter = eyePosition - vec3(0.0, 0.5, 0.0);
vec3 delta = worldPos - playerCenter;

float radius = max(HANDHELD_LIGHT_RADIUS, 0.01);

float xzDist = sqrt(delta.x * delta.x + delta.z * delta.z);
float yOffset = max(abs(delta.y) - 1.0, 0.0);
float dist = sqrt(xzDist * xzDist + yOffset * yOffset);

float t = clamp(dist / radius, 0.0, 1.0);
float atten = 1.0 - t * t;
atten = atten * atten * atten;

float intensity = heldLevel * atten * HANDHELD_LIGHT_STRENGTH;

vec3 tint;
if (dominantId == 10021 || dominantId == 10043) {
tint = vec3(0.3, 0.7, 1.0);
} else {
tint = vec3(1.0, 0.75, 0.4);
}

vec3 lightColor = baseColor * tint * intensity;
vec3 boost = litColor + lightColor - litColor * lightColor;
return max(boost - litColor, vec3(0.0));
}
#endif

vec3 applySaturationAndVibrance(vec3 c, float saturationMult, float vibrance) {
c = max(c, vec3(0.0));

float lum = dot(c, vec3(0.299, 0.587, 0.114));
c = mix(vec3(lum), c, max(saturationMult, 0.0));

vec3 hsv = rgb2hsv(clamp(c, vec3(0.0), vec3(10.0)));
float v = clamp(vibrance, 0.0, 2.0);
hsv.y = clamp(hsv.y + (1.0 - hsv.y) * v * (1.0 - hsv.y), 0.0, 1.0);
return hsv2rgb(hsv);
}

float getStableDayFactor(float sunAngle) {
TimeWeights tw = getTimeWeights(sunAngle);
return smoothstep(0.5, 0.9, tw.day);
}

vec3 getBiomeSkylightColor() {

float biomeLum = dot(skyColor, vec3(0.299, 0.587, 0.114));
if (biomeLum <= 0.0005) return vec3(1.0);
return normalizeLightColor(skyColor);
}

vec3 getCombinedSkylightTintColor(float sunAngle) {

vec3 tod = getTimeOfDaySkylightColor(sunAngle);
vec3 biome = mix(vec3(1.0), getBiomeSkylightColor(), getStableDayFactor(sunAngle));
return normalizeLightColor(tod * biome);
}

vec4 getTimeOfDayLighting(float sunAngle) {
vec2 bd = getTimelineBrightness(sunAngle);

return vec4(bd.x, 0.0, 0.0, bd.y);
}

vec3 normalizeLightColor(vec3 c) {

float lum = dot(c, vec3(0.299, 0.587, 0.114));
vec3 n = c / max(lum, 0.35);
return clamp(n, vec3(0.0), vec3(2.0));
}

vec3 getTimeOfDaySkylightColor(float sunAngle) {
TimeWeights tw = getTimeWeights(sunAngle);

vec3 daySky     = vec3(DAY_ZENITH_R, DAY_ZENITH_G, DAY_ZENITH_B);
vec3 sunsetSky  = vec3(SUNSET_ZENITH_R, SUNSET_ZENITH_G, SUNSET_ZENITH_B);
vec3 blueSky    = vec3(BLUEHOUR_ZENITH_R, BLUEHOUR_ZENITH_G, BLUEHOUR_ZENITH_B);
vec3 nightSky   = vec3(NIGHT_ZENITH_R, NIGHT_ZENITH_G, NIGHT_ZENITH_B);
vec3 sunriseSky = vec3(SUNRISE_ZENITH_R, SUNRISE_ZENITH_G, SUNRISE_ZENITH_B);
vec3 dawnSky    = vec3(DAWN_ZENITH_R, DAWN_ZENITH_G, DAWN_ZENITH_B);

vec3 sky = daySky     * tw.day
+ sunsetSky  * tw.sunset
+ blueSky    * tw.blueHour
+ nightSky   * tw.night
+ sunriseSky * tw.sunrise
+ dawnSky    * tw.dawn;

float daySunsetMix = min(tw.day, tw.sunset) * 2.0;
sky = mix(sky, vec3(0.9, 0.15, 0.85), daySunsetMix * 0.5);
float sunsetBlueMix = min(tw.sunset, tw.blueHour) * 2.0;
sky = mix(sky, vec3(0.4, 0.1, 1.0), sunsetBlueMix * 0.5);

return normalizeLightColor(sky);
}

vec3 getDaySkylightTintColor() {
vec3 daySky = vec3(DAY_ZENITH_R, DAY_ZENITH_G, DAY_ZENITH_B);
return normalizeLightColor(daySky);
}

float getBlocklightFalloff(float blocklight, float skylight) {
float x = clamp(blocklight, 0.0, 1.0);
float falloff = x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
falloff *= smoothstep(0.0, 0.15, blocklight);
return falloff;
}

vec3 getBlockLightColor(float intensity) {
vec3 warmLight = vec3(1.0, 0.9, 0.8);
return warmLight * intensity * intensity * BLOCKLIGHT_BRIGHTNESS;
}

vec3 applyLighting(vec3 color, float sunAngle, float skylight, float blocklight, float worldY) {
vec4 todLighting = getTimeOfDayLighting(sunAngle);
float todBrightness = todLighting.x;
float darkness = todLighting.w;

todBrightness *= mix(1.0, 0.6, biome_swamp);

float angle_ = fract(sunAngle);
float transitionDipSimple = smoothstep(0.47, 0.5146, angle_) * (1.0 - smoothstep(0.5146, 0.5604, angle_));
todBrightness *= 1.0 - transitionDipSimple;

bool isNether = isForcedNetherBiome(biome);

float darkSteps = clamp(float(SKYLIGHT_DARKNESS_LEVELS), 0.0, 13.0);
float darkAmt = isNether ? 0.0 : darkSteps / 13.0;
float skyLevel = clamp(skylight * 15.0, 0.0, 15.0);

float zBlend = clamp(SKYLIGHT_DARKNESS_Z, 0.0, 1.0);
float a = mix(0.1, 1.0, zBlend);

float n;
if (isNether) {
n = 0.0;
} else {
n = clamp((15.0 - skyLevel) / 14.0 * 14.0, 0.0, 14.0);
}
float cumulative = n + 0.5 * a * n * (n - 1.0);
float total = 14.0 + 0.5 * a * 14.0 * 13.0;
float levelWeight = cumulative / max(total, 0.0001);
float atten = isNether ? 1.0 : (1.0 - darkAmt * levelWeight);

float effectiveSkylight = isNether ? 1.0 : skylight;
float lmSkylight = clamp(effectiveSkylight * atten, 0.0, 1.0);
float sunsetTintBoost = smoothstep(0.38, 0.45, angle_) * (1.0 - smoothstep(0.48, 0.55, angle_))
+ smoothstep(0.95, 1.0, angle_) + (1.0 - smoothstep(0.0, 0.05, angle_));

float dayTintReduce = smoothstep(0.07, 0.15, angle_) * (1.0 - smoothstep(0.40, 0.46, angle_));
float baseTint = SKYLIGHT_COLOR_TINT * (1.0 - dayTintReduce * 0.6);
float tintStrength = clamp(baseTint + sunsetTintBoost * SUNSET_TERRAIN_TINT, 0.0, 1.0);
float lightSatBlend = clamp(SKYLIGHT_TINT_LIGHT_SATURATION, 0.0, 1.0);

vec3 tintBase = getCombinedSkylightTintColor(sunAngle);

float sunsetSatBoost = 1.0 + sunsetTintBoost * (SUNSET_TERRAIN_TINT * 1.09);
vec3 tintShadow = normalizeLightColor(applySaturationAndVibrance(tintBase, SKYLIGHT_TINT_SATURATION * sunsetSatBoost, 0.0));
float litSat = mix(1.0, SKYLIGHT_TINT_SATURATION * sunsetSatBoost, lightSatBlend);
vec3 tintLit = normalizeLightColor(applySaturationAndVibrance(tintBase, litSat, 0.0));

#ifdef END_SHADER
vec3 skyTint = vec3(1.0);
#else
vec3 skyTint = mix(vec3(1.0), tintShadow, tintStrength * lmSkylight);
#endif

vec3 rawShadowHue = hueToRGB(SHADOW_HUE > 0.0 ? 180.0 + SHADOW_HUE : 360.0 + SHADOW_HUE);
float hueLuminance = dot(rawShadowHue, vec3(0.299, 0.587, 0.114));
vec3 normalizedHue = rawShadowHue / max(hueLuminance, 0.3);
normalizedHue = min(normalizedHue, vec3(2.0));

float nightSatReduce = smoothstep(0.0, 0.20, todBrightness);
float caveSatReduce = smoothstep(0.10, 0.55, lmSkylight);
float effectiveLmSat = mix(LIGHTMAP_SATURATION * 0.10, LIGHTMAP_SATURATION, nightSatReduce * caveSatReduce);
vec3 shadowTintColor = mix(vec3(1.0), normalizedHue, effectiveLmSat);

float lightAmount = clamp(lmSkylight * todBrightness, 0.0, 1.0);

float shadowDark = 0.15 * lmSkylight;

vec3 darkShadowColor = shadowTintColor * shadowDark;

darkShadowColor *= skyTint;

vec3 litColor = mix(vec3(1.0), tintLit, tintStrength);
vec3 lightMultiplier = mix(darkShadowColor, litColor, lightAmount);
if (isNether) lightMultiplier *= NETHER_BRIGHTNESS;

vec3 skylitResult = color * lightMultiplier;

float isDaySuppress = isNether ? 0.0 : smoothstep(0.25, 0.85, todBrightness) * (1.0 - rainStrength * 0.35);

float effectiveBlocklight = clamp(blocklight * (1.0 - BLOCKLIGHT_SKYLIGHT_REDUCTION * lmSkylight * isDaySuppress), 0.0, 1.0);
float blocklightFalloff = getBlocklightFalloff(effectiveBlocklight, lmSkylight);
vec3 blockLight = getBlockLightColor(blocklightFalloff);
float skyVis = lmSkylight;

float blocklightSkySuppress = 1.0 - smoothstep(0.6, 1.0, skyVis * isDaySuppress);

#ifdef END_SHADER
vec3 endBlockColor = vec3(END_BLOCKLIGHT_R, END_BLOCKLIGHT_G, END_BLOCKLIGHT_B);
vec3 endBlockLight = endBlockColor * blocklightFalloff * blocklightFalloff * END_BLOCKLIGHT_BRIGHTNESS;
vec3 result = skylitResult + color * endBlockLight;
#else
vec3 result = skylitResult + color * blockLight * blocklightSkySuppress;
#endif

float seaLevel = float(SEA_LEVEL_OFFSET);
float depthBelow = max(seaLevel - worldY, 0.0);
float heightAmbient = 1.0 - smoothstep(0.0, 96.0, depthBelow);

float undergroundBright = mix(0.30, 0.18, heightAmbient);
float interiorBright = 0.35;
float enclosedFactor = 1.0 - lmSkylight;
float undergroundBlend = smoothstep(24.0, 96.0, depthBelow);
float baseInteriorToCave = mix(interiorBright, undergroundBright, undergroundBlend);
float minBright = baseInteriorToCave * (enclosedFactor + darkness * 0.5 * lmSkylight);
result = max(result, color * minBright);

if (!isNether) {
float nightAmbientBoost = NIGHT_AMBIENT * darkness * lmSkylight;
result += color * nightAmbientBoost;
}

if (isEyeInWater != 1) {
float blocklightReduce = 1.0 - smoothstep(0.3, 0.9, blocklight);
float caveTintFactor = (1.0 - smoothstep(0.00, 9.0 / 15.0, skylight)) * clamp(max(tintStrength * 3.0, 0.85), 0.0, 1.0) * blocklightReduce;
vec3 caveTintShadow = normalizeLightColor(vec3(45.0, 70.0, 105.0) / 255.0);
result = mix(result, result * caveTintShadow, caveTintFactor);
}

#ifdef SHADOW_DEBUG_TINT
float debugShadowMask = clamp(1.0 - lightAmount, 0.0, 1.0);
result = mix(result, vec3(1.0, 0.1, 0.1), debugShadowMask * 0.85);
#endif

#ifdef CAVE_LIGHT_DEBUG
float lowSkyDebug = 1.0 - lmSkylight;
float caveFloorDebug = clamp(minBright / max(dot(color, vec3(0.3333)), 0.001), 0.0, 1.0);
vec3 debugColor = vec3(caveFloorDebug, 0.0, lowSkyDebug);
result = mix(result, debugColor, 0.9);
#endif

return result;
}

vec3 applyLightingWithShadow(vec3 color, float sunAngle, float skylight, float blocklight, float emissive, vec3 shadow, float worldY) {
if (emissive > 0.5) {
#ifdef END_SHADER

return color * EMISSIVE_BRIGHTNESS * END_EMISSIVE_BOOST;
#else
return color * EMISSIVE_BRIGHTNESS;
#endif
}

vec4 todLighting = getTimeOfDayLighting(sunAngle);
float todBrightness = todLighting.x;
float darkness = todLighting.w;

todBrightness *= mix(1.0, 0.6, biome_swamp);

bool isNether = isForcedNetherBiome(biome);

float darkSteps = clamp(float(SKYLIGHT_DARKNESS_LEVELS), 0.0, 13.0);
float darkAmt = isNether ? 0.0 : darkSteps / 13.0;
float skyLevel = clamp(skylight * 15.0, 0.0, 15.0);

float zBlend = clamp(SKYLIGHT_DARKNESS_Z, 0.0, 1.0);
float a = mix(0.1, 1.0, zBlend);

float n;
if (isNether) {
n = 0.0;
} else {
n = clamp((15.0 - skyLevel) / 14.0 * 14.0, 0.0, 14.0);
}
float cumulative = n + 0.5 * a * n * (n - 1.0);
float total = 14.0 + 0.5 * a * 14.0 * 13.0;
float levelWeight = cumulative / max(total, 0.0001);
float atten = isNether ? 1.0 : (1.0 - darkAmt * levelWeight);

float effectiveSkylight = isNether ? 1.0 : skylight;
float lmSkylight = clamp(effectiveSkylight * atten, 0.0, 1.0);

float angleS = fract(sunAngle);
float sunsetTintBoostS = smoothstep(0.38, 0.45, angleS) * (1.0 - smoothstep(0.48, 0.55, angleS))
+ smoothstep(0.95, 1.0, angleS) + (1.0 - smoothstep(0.0, 0.05, angleS));

float dayTintReduceS = smoothstep(0.07, 0.15, angleS) * (1.0 - smoothstep(0.40, 0.46, angleS));
float baseTintS = SKYLIGHT_COLOR_TINT * (1.0 - dayTintReduceS * 0.6);
float tintStrength = clamp(baseTintS + sunsetTintBoostS * SUNSET_TERRAIN_TINT, 0.0, 1.0);
float lightSatBlend = clamp(SKYLIGHT_TINT_LIGHT_SATURATION, 0.0, 1.0);

vec3 tintBase = getCombinedSkylightTintColor(sunAngle);
float sunsetSatBoostS = 1.0 + sunsetTintBoostS * (SUNSET_TERRAIN_TINT * 1.09);
vec3 tintShadow = normalizeLightColor(applySaturationAndVibrance(tintBase, SKYLIGHT_TINT_SATURATION * sunsetSatBoostS, 0.0));
float litSat = mix(1.0, SKYLIGHT_TINT_SATURATION * sunsetSatBoostS, lightSatBlend);
vec3 tintLit = normalizeLightColor(applySaturationAndVibrance(tintBase, litSat, 0.0));

#ifdef END_SHADER
vec3 skyTint = vec3(1.0);
#else
vec3 skyTint = mix(vec3(1.0), tintShadow, tintStrength * lmSkylight);
#endif

vec3 rawShadowHue = hueToRGB(SHADOW_HUE > 0.0 ? 180.0 + SHADOW_HUE : 360.0 + SHADOW_HUE);
float hueLuminance = dot(rawShadowHue, vec3(0.299, 0.587, 0.114));
vec3 normalizedHue = rawShadowHue / max(hueLuminance, 0.3);
normalizedHue = min(normalizedHue, vec3(2.0));

float nightSatReduceS = smoothstep(0.0, 0.20, todBrightness);
float caveSatReduceS = smoothstep(0.10, 0.55, lmSkylight);
float effectiveShadowSat = mix(SHADOW_SATURATION * 0.10, SHADOW_SATURATION, nightSatReduceS * caveSatReduceS);
vec3 shadowTintColor = mix(vec3(1.0), normalizedHue, effectiveShadowSat);

float shadowVal = dot(shadow, vec3(0.299, 0.587, 0.114));

float transitionDip = smoothstep(0.47, 0.5146, angleS) * (1.0 - smoothstep(0.5146, 0.5604, angleS));
todBrightness *= 1.0 - transitionDip;

float isDaySuppress = isNether ? 0.0 : smoothstep(0.25, 0.85, todBrightness) * (1.0 - rainStrength * 0.35);

float effectiveBlocklight = clamp(blocklight * (1.0 - BLOCKLIGHT_SKYLIGHT_REDUCTION * lmSkylight * isDaySuppress), 0.0, 1.0);
float blocklightFalloff = getBlocklightFalloff(effectiveBlocklight, lmSkylight);
float shadowOverride = clamp(blocklightFalloff * BLOCKLIGHT_SHADOW_OVERRIDE, 0.0, 1.0);
float shadowValLifted = mix(shadowVal, 1.0, shadowOverride);

float lightAmount = clamp(lmSkylight * todBrightness * shadowValLifted, 0.0, 1.0);

float isNightTime = 1.0 - smoothstep(0.0, 0.25, todBrightness);
float shadowDark = 0.15 * lmSkylight * (1.0 - isNightTime * 0.75);

lightAmount += lmSkylight * shadowValLifted * isNightTime * 0.30;

vec3 darkShadowColor = shadowTintColor * shadowDark;
darkShadowColor *= skyTint;

vec3 litColor = mix(vec3(1.0), tintLit, tintStrength);
vec3 lightMultiplier = mix(darkShadowColor, litColor, lightAmount);

if (isNether) lightMultiplier *= NETHER_BRIGHTNESS;

vec3 skylitResult = color * lightMultiplier;

float sLum = dot(shadow, vec3(0.299, 0.587, 0.114));
if (sLum > 0.001) {
vec3 shadowNorm = shadow / sLum;
float sat = max(shadowNorm.r, max(shadowNorm.g, shadowNorm.b)) - min(shadowNorm.r, min(shadowNorm.g, shadowNorm.b));
if (sat > 0.1) {

skylitResult *= mix(vec3(1.0), shadowNorm, smoothstep(0.1, 0.4, sat) * 0.4);
}
}

vec3 blockLight = getBlockLightColor(blocklightFalloff);
float skyVis = lmSkylight;
float blocklightSkySuppress = 1.0 - smoothstep(0.6, 1.0, skyVis * isDaySuppress);

#ifdef END_SHADER

vec3 endBlockColor = vec3(END_BLOCKLIGHT_R, END_BLOCKLIGHT_G, END_BLOCKLIGHT_B);
vec3 endBlockLight = endBlockColor * blocklightFalloff * blocklightFalloff * END_BLOCKLIGHT_BRIGHTNESS;
vec3 result = skylitResult + color * endBlockLight;
#else
vec3 result = skylitResult + color * blockLight * blocklightSkySuppress;
#endif

float seaLevel = float(SEA_LEVEL_OFFSET);
float depthBelow = max(seaLevel - worldY, 0.0);
float heightAmbient = 1.0 - smoothstep(0.0, 96.0, depthBelow);

float undergroundBright = mix(0.30, 0.18, heightAmbient);
float interiorBright = 0.35;
float enclosedFactor = 1.0 - lmSkylight;
float undergroundBlend = smoothstep(24.0, 96.0, depthBelow);
float baseInteriorToCave = mix(interiorBright, undergroundBright, undergroundBlend);
float minBright = baseInteriorToCave * (enclosedFactor + darkness * 0.5 * lmSkylight);
result = max(result, color * minBright);

if (!isNether) {
float nightAmbientBoost = NIGHT_AMBIENT * darkness * lmSkylight;
result += color * nightAmbientBoost;
}

if (isEyeInWater != 1) {
float blocklightReduce = 1.0 - smoothstep(0.3, 0.9, blocklight);
float caveTintFactor = (1.0 - smoothstep(0.00, 9.0 / 15.0, skylight)) * clamp(max(tintStrength * 3.0, 0.85), 0.0, 1.0) * blocklightReduce;
vec3 caveTintShadow = normalizeLightColor(vec3(45.0, 70.0, 105.0) / 255.0);
result = mix(result, result * caveTintShadow, caveTintFactor);
}

#ifdef SHADOW_DEBUG_TINT
float debugShadowMask = clamp(1.0 - shadowValLifted, 0.0, 1.0);
result = mix(result, vec3(1.0, 0.1, 0.1), debugShadowMask * 0.85);
#endif

#ifdef CAVE_LIGHT_DEBUG
float lowSkyDebug = 1.0 - lmSkylight;
float caveFloorDebug = clamp(minBright / max(dot(color, vec3(0.3333)), 0.001), 0.0, 1.0);
vec3 debugColor = vec3(caveFloorDebug, 0.0, lowSkyDebug);
result = mix(result, debugColor, 0.9);
#endif

return result;
}

vec3 applyLightingWithShadow(vec3 color, float sunAngle, float skylight, float blocklight, float emissive, float shadow, float worldY) {
return applyLightingWithShadow(color, sunAngle, skylight, blocklight, emissive, vec3(shadow), worldY);
}

vec3 applyLightingEmissive(vec3 color, float sunAngle, float skylight, float blocklight, float emissive, float worldY) {
if (emissive > 0.5) {
#ifdef END_SHADER
return color * EMISSIVE_BRIGHTNESS * END_EMISSIVE_BOOST;
#else
return color * EMISSIVE_BRIGHTNESS;
#endif
}
return applyLighting(color, sunAngle, skylight, blocklight, worldY);
}

vec3 applyLightingEmissiveWithWorldPos(vec3 color, float sunAngle, float skylight, float blocklight, float emissive, vec3 worldPos) {
return applyLightingEmissive(color, sunAngle, skylight, blocklight, emissive, worldPos.y);
}

vec3 applyTimeOfDayLighting(vec3 color, float sunAngle, float skylight, float worldY) {
return applyLighting(color, sunAngle, skylight, 0.0, worldY);
}

#endif
