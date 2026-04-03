#ifndef VOXY_COMPAT_GLSL
#define VOXY_COMPAT_GLSL

#include "/include/sky_timeline.glsl"

float voxy_luma(vec3 c) {
return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 voxy_normalize_light_color(vec3 c) {
float lum = voxy_luma(c);
vec3 n = c / max(lum, 0.35);
return clamp(n, vec3(0.0), vec3(2.0));
}

vec3 voxy_apply_color_adjust(vec3 color) {
color = (color - 0.5) * VOXY_CONTRAST + 0.5;
color = max(color, vec3(0.0));
float l = voxy_luma(color);
color = mix(vec3(l), color, VOXY_SATURATION);

if (VOXY_HIGHLIGHT_COMPRESS > 0.001) {
color = color / (color + vec3(VOXY_HIGHLIGHT_COMPRESS));
color *= (1.0 + VOXY_HIGHLIGHT_COMPRESS);
}

return color;
}

uint voxy_block_id(uint rawId) {
return (rawId >= 10000u) ? (rawId - 10000u) : rawId;
}

vec3 voxy_face_normal(uint face) {
vec3 axis = vec3(
float((face >> 1u) == 2u),
float((face >> 1u) == 0u),
float((face >> 1u) == 1u)
);
float sign = float((int(face) & 1) * 2 - 1);
return axis * sign;
}

vec4 voxy_time_of_day_lighting(float sunAngle) {
vec2 bd = getTimelineBrightness(sunAngle);
TimeWeightsSimple ts = getTimeWeightsSimple(sunAngle);
return vec4(bd.x, bd.y, ts.day, ts.twilight);
}

vec3 voxy_tod_skylight_tint(float sunAngle) {
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

return voxy_normalize_light_color(sky);
}

float voxy_blocklight_falloff(float blocklight) {
float x = clamp(blocklight, 0.0, 1.0);
float falloff = x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
falloff *= smoothstep(0.0, 0.15, x);
return falloff;
}

float voxy_face_shade(uint face) {
float shadeValues[6] = float[6](
0.5,
1.0,
0.8,
0.8,
0.6,
0.6
);
return shadeValues[min(face, 5u)];
}

vec3 voxy_hueToRGB(float hue) {
float h = mod(hue, 360.0) / 60.0;
float x = 1.0 - abs(mod(h, 2.0) - 1.0);
vec3 rgb;
if (h < 1.0) rgb = vec3(1.0, x, 0.0);
else if (h < 2.0) rgb = vec3(x, 1.0, 0.0);
else if (h < 3.0) rgb = vec3(0.0, 1.0, x);
else if (h < 4.0) rgb = vec3(0.0, x, 1.0);
else if (h < 5.0) rgb = vec3(x, 0.0, 1.0);
else rgb = vec3(1.0, 0.0, x);
return rgb;
}

vec3 voxy_applySaturation(vec3 c, float satMult) {
float lum = voxy_luma(c);
return mix(vec3(lum), c, max(satMult, 0.0));
}

vec3 voxy_apply_chunk_like_lighting(vec3 color, float sunAngle, float skylight, float blocklight) {
vec4 tod = voxy_time_of_day_lighting(sunAngle);
float todBrightness = tod.x;
float darkness = tod.y;
float dayAmount = tod.z;
float sunsetAmount = tod.w;

float voxyAngle = fract(sunAngle);
float voxyTransitionDip = smoothstep(0.42, 0.5146, voxyAngle) * (1.0 - smoothstep(0.5146, 0.5604, voxyAngle));
todBrightness *= 1.0 - voxyTransitionDip;

float lmSkylight = clamp(max(skylight, 0.3), 0.0, 1.0);

float sunsetTintBoost = smoothstep(0.38, 0.45, voxyAngle) * (1.0 - smoothstep(0.48, 0.55, voxyAngle))
+ smoothstep(0.95, 1.0, voxyAngle) + (1.0 - smoothstep(0.0, 0.05, voxyAngle));

float dayTintReduce = smoothstep(0.07, 0.15, voxyAngle) * (1.0 - smoothstep(0.40, 0.46, voxyAngle));
float baseTint = SKYLIGHT_COLOR_TINT * (1.0 - dayTintReduce * 0.6);
float tintStrength = clamp(baseTint + sunsetTintBoost * SUNSET_TERRAIN_TINT, 0.0, 1.0);
float lightSatBlend = clamp(SKYLIGHT_TINT_LIGHT_SATURATION, 0.0, 1.0);

vec3 todTint = voxy_tod_skylight_tint(sunAngle);
vec3 biomeTint = voxy_normalize_light_color(skyColor);
float biomeWeight = smoothstep(0.5, 0.9, dayAmount);
vec3 tintBase = voxy_normalize_light_color(todTint * mix(vec3(1.0), biomeTint, biomeWeight));

float sunsetSatBoost = 1.0 + sunsetTintBoost * (SUNSET_TERRAIN_TINT * 1.09);
vec3 tintShadow = voxy_normalize_light_color(voxy_applySaturation(tintBase, SKYLIGHT_TINT_SATURATION * sunsetSatBoost));
float litSat = mix(1.0, SKYLIGHT_TINT_SATURATION * sunsetSatBoost, lightSatBlend);
vec3 tintLit = voxy_normalize_light_color(voxy_applySaturation(tintBase, litSat));

#ifdef END_SHADER

vec3 skyTintShadow = vec3(1.0);
vec3 skyTintLit = vec3(1.0);
#else
vec3 skyTintShadow = mix(vec3(1.0), tintShadow, tintStrength * lmSkylight);
vec3 skyTintLit = mix(vec3(1.0), tintLit, tintStrength);
#endif

vec3 rawShadowHue = voxy_hueToRGB(SHADOW_HUE > 0.0 ? 180.0 + SHADOW_HUE : 360.0 + SHADOW_HUE);
float hueLuminance = voxy_luma(rawShadowHue);
vec3 normalizedHue = rawShadowHue / max(hueLuminance, 0.3);
normalizedHue = min(normalizedHue, vec3(2.0));

float nightSatReduce = smoothstep(0.0, 0.20, todBrightness);
float effectiveLmSat = mix(LIGHTMAP_SATURATION * 0.15, LIGHTMAP_SATURATION, nightSatReduce);
vec3 shadowTintColor = mix(vec3(1.0), normalizedHue, effectiveLmSat);

float isNightTime = 1.0 - smoothstep(0.0, 0.25, todBrightness);
float lightAmount = clamp(lmSkylight * todBrightness, 0.0, 1.0);

float shadowDark = 0.15 * lmSkylight * (1.0 - isNightTime * 0.5);
lightAmount += lmSkylight * isNightTime * 0.30;

vec3 darkShadowColor = shadowTintColor * shadowDark;
darkShadowColor *= skyTintShadow;

vec3 litColor = mix(vec3(1.0), tintLit, tintStrength);
vec3 lightMultiplier = mix(darkShadowColor, litColor, lightAmount);

float isDaySuppress = smoothstep(0.25, 0.85, todBrightness);
float effectiveBlock = clamp(blocklight * (1.0 - BLOCKLIGHT_SKYLIGHT_REDUCTION * lmSkylight * isDaySuppress), 0.0, 1.0);
float bFalloff = voxy_blocklight_falloff(effectiveBlock);
vec3 blockLight = vec3(1.0, 0.9, 0.8) * bFalloff * bFalloff * BLOCKLIGHT_BRIGHTNESS;
float blocklightSkySuppress = 1.0 - smoothstep(0.6, 1.0, lmSkylight * isDaySuppress);

float minBright = 0.18 * (1.0 - lmSkylight + darkness * 0.5);
float nightAmbient = NIGHT_AMBIENT * darkness * lmSkylight;

vec3 result = color * lightMultiplier
+ color * blockLight * blocklightSkySuppress;
result = max(result, color * vec3(minBright));
result += color * nightAmbient;

#ifndef END_SHADER
if (isEyeInWater != 1) {
float caveTintFactor = (1.0 - smoothstep(0.00, 9.0 / 15.0, skylight)) * clamp(max(tintStrength * 3.0, 0.85), 0.0, 1.0);
caveTintFactor = min(caveTintFactor * 0.6, 1.0);
vec3 caveTintShadow = voxy_normalize_light_color(vec3(45.0, 70.0, 105.0) / 255.0);
result = mix(result, result * caveTintShadow, caveTintFactor);
}
#endif

#ifdef END_SHADER
result *= mix(1.0, VOXY_LOD_BRIGHTNESS, 0.3);
#else
result *= VOXY_LOD_BRIGHTNESS;
#endif

return result;
}

#ifdef VOXY_TILE_BLUR_ENABLED

vec4 voxy_tile_blur(vec2 uv, float depth) {
const vec2 tileSize = vec2(1.0 / (3.0 * 256.0), 1.0 / (2.0 * 256.0));
vec2 tileMin = floor(uv / tileSize) * tileSize;
vec2 centerUV = tileMin + tileSize * 0.5;
return textureLod(blockModelAtlas, centerUV, 0);
}

float voxy_tile_blur_strength(float depth) {
return smoothstep(VOXY_TILE_BLUR_START, min(VOXY_TILE_BLUR_START + 0.1, 0.999), depth);
}
#endif

#endif
