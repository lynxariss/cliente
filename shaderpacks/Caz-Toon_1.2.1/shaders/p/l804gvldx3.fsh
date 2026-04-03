/* RENDERTARGETS: 11 */

#include "/settings.glsl"

#ifdef WEATHER_FOG_ENABLED

#include "/include/shadow.glsl"
#include "/include/biome_overrides.glsl"

in vec2 texcoord;

uniform sampler2D colortex1;
uniform sampler2D colortex11;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D dhDepthTex;
uniform sampler2D shadowtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 vxProjInv;
uniform sampler2D vxDepthTexTrans;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float sunAngle;
uniform float near;
uniform float far;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform float rainStrength;
uniform float thunderStrength;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform int biome;
uniform int biome_category;
uniform int isEyeInWater;
uniform float biome_swamp;

#include "/include/noise.glsl"
#include "/include/sky_timeline.glsl"
#include "/include/depth_utils.glsl"

#ifdef LIGHTNING_ENABLED
#include "/include/lightning.glsl"
#endif

vec3 getWeatherFogColor(float timeBrightness) {
TimeWeights tw = getTimeWeights(sunAngle);

vec3 dayZenith      = vec3(DAY_ZENITH_R,      DAY_ZENITH_G,      DAY_ZENITH_B);
vec3 sunsetZenith   = vec3(SUNSET_ZENITH_R,   SUNSET_ZENITH_G,   SUNSET_ZENITH_B);
vec3 bluehourZenith = vec3(BLUEHOUR_ZENITH_R,  BLUEHOUR_ZENITH_G,  BLUEHOUR_ZENITH_B);
vec3 nightZenith    = vec3(NIGHT_ZENITH_R,     NIGHT_ZENITH_G,     NIGHT_ZENITH_B);
vec3 sunriseZenith  = vec3(SUNRISE_ZENITH_R,   SUNRISE_ZENITH_G,   SUNRISE_ZENITH_B);

vec3 zenithColor = dayZenith      * tw.day
+ sunsetZenith   * tw.sunset
+ bluehourZenith * tw.blueHour
+ nightZenith    * tw.night
+ sunriseZenith  * tw.sunrise;

float luma = dot(zenithColor, vec3(0.299, 0.587, 0.114));
zenithColor = mix(vec3(luma), zenithColor, 0.5);
zenithColor *= vec3(0.7, 0.75, 1.0);

return zenithColor * WEATHER_FOG_BRIGHTNESS * timeBrightness * 0.7;
}

void main() {

float swampW = clamp(biome_swamp, 0.0, 1.0);
if (rainStrength < 0.01 && swampW < 0.01) {
gl_FragData[0] = vec4(0.0);
return;
}

if (isForcedNetherBiome(biome)) {
gl_FragData[0] = vec4(0.0);
return;
}
#ifdef END_SHADER
gl_FragData[0] = vec4(0.0);
return;
#else
#ifdef CAT_THE_END
if (biome_category == CAT_THE_END) {
gl_FragData[0] = vec4(0.0);
return;
}
#endif
#endif

if (isEyeInWater == 1) {
gl_FragData[0] = vec4(0.0);
return;
}

float depth0 = texture(depthtex0, texcoord).r;
float depth1 = texture(depthtex1, texcoord).r;
float vxDepth = texture(vxDepthTexTrans, texcoord).r;
bool hasVoxyDepth = (vxDepth > 0.00001 && vxDepth < 0.9999);
vec4 maskData = texture(colortex1, texcoord);
bool isVoxyLodPixel = (maskData.a > 0.999 && maskData.g < 0.01);
bool isTranslucent = (depth0 < depth1 - 0.00001);

float sceneDepth;
bool useVoxyProj = false;
if (hasVoxyDepth && (isTranslucent || isVoxyLodPixel)) {
sceneDepth = vxDepth;
useVoxyProj = true;
} else if (isTranslucent) {
sceneDepth = depth1;
} else if (isVoxyLodPixel) {
sceneDepth = depth0;
useVoxyProj = true;
} else {
sceneDepth = depth0;
}
bool isSky = (sceneDepth >= 1.0) && !hasVoxyDepth && !isVoxyLodPixel;
float dhDepth = texture(dhDepthTex, texcoord).r;
bool hasDH = hasValidDHDepth(dhDepth);

vec3 rayDir;
float maxDist;

if (!isSky) {
vec4 clipPos = vec4(texcoord * 2.0 - 1.0, sceneDepth * 2.0 - 1.0, 1.0);
mat4 projInv = useVoxyProj ? vxProjInv : gbufferProjectionInverse;
vec4 viewPos = projInv * clipPos;
viewPos /= viewPos.w;
vec3 worldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
rayDir = normalize(worldPos - cameraPosition);
maxDist = length(worldPos - cameraPosition);
} else if (hasDH) {
float dhLinear = linearizeDepthDH(dhDepth);
vec4 clipFar = vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
vec4 viewPosFar = gbufferProjectionInverse * clipFar;
vec3 viewDir = normalize(viewPosFar.xyz / max(viewPosFar.w, 0.0001));
maxDist = dhLinear / max(-viewDir.z, 0.001);
rayDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
} else {
vec4 vd4 = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
rayDir = normalize(mat3(gbufferModelViewInverse) * (vd4.xyz / vd4.w));
maxDist = 256.0;
}

maxDist = min(maxDist, 256.0);

float tEntry = WEATHER_FOG_NEAR_DIST;
float tExit  = maxDist;

if (tEntry >= tExit) {
gl_FragData[0] = vec4(0.0);
return;
}

vec3 windOffset = vec3(-1.0, -0.3, 0.0) * frameTimeCounter * 12.0;

float dither = fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y)
+ 5.588238 * float(frameCounter & 63));

float angle = fract(sunAngle);
float dayFactor = smoothstep(0.02, 0.08, angle) * (1.0 - smoothstep(0.44, 0.52, angle));
float nightFactor = smoothstep(0.55, 0.62, angle) * (1.0 - smoothstep(0.90, 0.96, angle));
float timeBrightness = max(dayFactor, nightFactor * 0.15);

vec3 fogColor = getWeatherFogColor(timeBrightness);

vec3 biomeFogTint = getForcedBiomeFogColorCat(biome, biome_category, vec3(-1.0));
if (biomeFogTint.r >= 0.0) {

float biomeLuma = dot(biomeFogTint, vec3(0.299, 0.587, 0.114));
biomeFogTint = mix(vec3(biomeLuma), biomeFogTint, 0.6);
biomeFogTint *= timeBrightness * WEATHER_FOG_BRIGHTNESS * 0.7;
fogColor = mix(fogColor, biomeFogTint, 0.6);
}

TimeWeights twFog = getTimeWeights(sunAngle);
float twilightBlend = twFog.sunset + twFog.sunrise;
vec3 sunsetHorizon = vec3(SUNSET_HORIZON_R, SUNSET_HORIZON_G, SUNSET_HORIZON_B) * SUNSET_BRIGHTNESS;
vec3 sunriseHorizon = vec3(SUNRISE_HORIZON_R, SUNRISE_HORIZON_G, SUNRISE_HORIZON_B) * SUNRISE_BRIGHTNESS;
vec3 twilightColor = (sunsetHorizon * twFog.sunset + sunriseHorizon * twFog.sunrise) / max(twilightBlend, 0.001);

if (twilightBlend > 0.01) {
fogColor = mix(fogColor, twilightColor * 0.5, twilightBlend * 0.4);
}

vec3 swampFogColor = vec3(0.0);
float swampDensity = 0.0;
if (swampW > 0.01) {
swampFogColor = vec3(30.0, 55.0, 25.0) / 255.0;
swampFogColor *= timeBrightness * 3.0;

if (twilightBlend > 0.01) {
swampFogColor = mix(swampFogColor, twilightColor * 0.4, twilightBlend * 0.5);
}
swampDensity = 1.5 * swampW;
}

float thunderBoost = 1.0 + rainStrength * WEATHER_FOG_THUNDER_BOOST;
float density = WEATHER_FOG_DENSITY * rainStrength * thunderBoost;

float marchLength = tExit - tEntry;
float stepSize = marchLength / float(WEATHER_FOG_STEPS);

vec3  fogAccum = vec3(0.0);
float transmittance = 1.0;

for (int i = 0; i < WEATHER_FOG_STEPS; i++) {
float t = tEntry + (float(i) + dither) * stepSize;
vec3 samplePos = cameraPosition + rayDir * t;

vec3 noiseCoord = (samplePos + windOffset) * WEATHER_FOG_NOISE_SCALE;
float noiseSample = noise3D(noiseCoord);
noiseSample += 0.5 * noise3D(noiseCoord * 2.1);
noiseSample /= 1.5;

float fogPresence = smoothstep(0.2, 0.65, noiseSample);

float distFade = smoothstep(WEATHER_FOG_NEAR_DIST, WEATHER_FOG_FAR_DIST, t);

float localDensity = fogPresence * distFade * density * stepSize * 0.002;

if (swampW > 0.01) {
vec3 swampNoiseCoord = (samplePos + windOffset * 0.3) * 0.04;
float swampNoise = noise3D(swampNoiseCoord);
swampNoise += 0.5 * noise3D(swampNoiseCoord * 2.1);
swampNoise /= 1.5;
float swampPresence = smoothstep(0.25, 0.6, swampNoise);
float swampDistFade = smoothstep(8.0, 80.0, t);
float swampLocalDensity = swampPresence * swampDistFade * swampDensity * stepSize * 0.01;
if (swampLocalDensity > 0.0001) {
fogAccum += swampFogColor * swampLocalDensity * transmittance;
transmittance *= exp(-swampLocalDensity);
}
}

if (localDensity > 0.001) {

float shadow = 1.0;
#ifdef SHADOWS_ENABLED
{
vec3 scenePos = samplePos - cameraPosition;
vec4 shadowViewPos = shadowModelView * vec4(scenePos, 1.0);
vec4 shadowClipPos = shadowProjection * shadowViewPos;
vec3 shadowNDC = distortShadowClipPos(shadowClipPos.xyz);
vec3 shadowScreenPos = shadowNDC * 0.5 + 0.5;
shadowScreenPos.z -= 0.0005;

if (shadowScreenPos.x > 0.0 && shadowScreenPos.x < 1.0 &&
shadowScreenPos.y > 0.0 && shadowScreenPos.y < 1.0 &&
shadowScreenPos.z > 0.0 && shadowScreenPos.z < 1.0) {
shadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
}
}
#endif

float extinction = min(localDensity, 0.06);
float scatterAmount = min(localDensity * shadow, 0.06);

#ifdef LIGHTNING_ENABLED
{
float lGlow = getLightningGlow(samplePos, frameTimeCounter, thunderStrength);
fogAccum += vec3(LIGHTNING_R, LIGHTNING_G, LIGHTNING_B) * scatterAmount * lGlow * transmittance;
}
#endif

fogAccum += fogColor * scatterAmount * transmittance;
transmittance *= exp(-extinction);
}

if (transmittance < 0.01) break;
}

float fogOpacity = 1.0 - transmittance;

gl_FragData[0] = vec4(fogAccum, fogOpacity);
}

#else

in vec2 texcoord;

void main() {
gl_FragData[0] = vec4(0.0);
}

#endif
