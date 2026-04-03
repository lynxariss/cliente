/* RENDERTARGETS: 9 */

#include "/settings.glsl"

#if defined(ATMO_FOG_ENABLED) || defined(UNDERWATER_FOG_ENABLED) || defined(LAVA_FOG_ENABLED)

#include "/include/shadow.glsl"
#include "/include/biome_overrides.glsl"

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

in vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex9;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D dhDepthTex;
uniform sampler2D noisetex;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 vxProjInv;
uniform sampler2D vxDepthTexTrans;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float sunAngle;
uniform float near;
uniform float far;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform int biome;
uniform int biome_category;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_snowy;
uniform float biome_arid;
uniform float biome_beach;
uniform float biome_ocean;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

#include "/include/noise.glsl"
#include "/include/sky_timeline.glsl"

float afFogDensity(vec3 pos) {
float n = noise3D(pos);
n += 0.50 * noise3D(pos * 1.97);
n /= 1.50;
return n;
}

#include "/include/depth_utils.glsl"

void main() {

#ifdef LAVA_FOG_ENABLED
if (isEyeInWater == 2) {
gl_FragData[0] = vec4(0.0);
return;
}
#endif

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

#ifdef UNDERWATER_FOG_ENABLED
if (isEyeInWater == 1) {

float uwDepth0 = min(texture(depthtex0, texcoord).r, texture(depthtex1, texcoord).r);
float uwMaxDist;
vec3 uwRayDir;
bool uwHitsAboveSurface = false;

if (uwDepth0 < 1.0) {
vec4 uwClipPos = vec4(texcoord * 2.0 - 1.0, uwDepth0 * 2.0 - 1.0, 1.0);
vec4 uwViewPos = gbufferProjectionInverse * uwClipPos;
uwViewPos /= uwViewPos.w;
vec3 uwWorldPos = (gbufferModelViewInverse * uwViewPos).xyz + cameraPosition;
uwRayDir = normalize(uwWorldPos - cameraPosition);
uwMaxDist = length(uwWorldPos - cameraPosition);

float uwWaterSurface = float(SEA_LEVEL_OFFSET) - 0.125;
if (uwWorldPos.y > uwWaterSurface - 0.5) {
uwHitsAboveSurface = true;

float surfaceDist = max(uwWaterSurface - cameraPosition.y, 0.1);
float upComponent = max(uwRayDir.y, 0.01);
uwMaxDist = min(uwMaxDist, surfaceDist / upComponent);
}
} else {
float uwDhDepth = texture(dhDepthTex, texcoord).r;
if (hasValidDHDepth(uwDhDepth)) {
float uwDhLinear = linearizeDepthDH(uwDhDepth);
vec4 uwClipFar = vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
vec4 uwViewPosFar = gbufferProjectionInverse * uwClipFar;
vec3 uwViewDir = normalize(uwViewPosFar.xyz / max(uwViewPosFar.w, 0.0001));
uwMaxDist = uwDhLinear / max(-uwViewDir.z, 0.001);
uwRayDir = normalize(mat3(gbufferModelViewInverse) * uwViewDir);

vec3 uwDhWorldPos = cameraPosition + uwRayDir * uwMaxDist;
uwHitsAboveSurface = (uwDhWorldPos.y > float(SEA_LEVEL_OFFSET) - 0.625);
} else {

uwHitsAboveSurface = true;
vec4 uwVd4 = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
uwRayDir = normalize(mat3(gbufferModelViewInverse) * (uwVd4.xyz / uwVd4.w));

float surfaceDist = max(float(SEA_LEVEL_OFFSET) - 0.125 - cameraPosition.y, 0.1);

float upComponent = max(uwRayDir.y, 0.01);
uwMaxDist = surfaceDist / upComponent;
}
}

float uwSwampDistScale = mix(1.0, 0.3, biome_swamp);
uwMaxDist = min(uwMaxDist, float(UNDERWATER_FOG_DISTANCE) * uwSwampDistScale);

float uwExtCoeff = UNDERWATER_FOG_DENSITY * 0.008 / uwSwampDistScale;
float uwFogDist = max(uwMaxDist - UNDERWATER_FOG_START * uwSwampDistScale, 0.0);
float uwTransmittance = exp(-uwFogDist * uwExtCoeff);
float uwFogOpacity = 1.0 - uwTransmittance;

vec3 uwSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
vec3 uwMoonDir = normalize(mat3(gbufferModelViewInverse) * moonPosition);
float uwSunDot = dot(uwRayDir, uwSunDir);
float uwSunFactor = uwSunDot * 0.5 + 0.5;
uwSunFactor = pow(uwSunFactor, 2.0);

float nightFade = 1.0 - smoothstep(-0.05, 0.3, uwSunDir.y);

float uwSunHeight = uwSunDir.y;
float sunsetFade = smoothstep(0.0, 0.15, uwSunHeight) * (1.0 - smoothstep(0.15, 0.35, uwSunHeight));
sunsetFade = pow(sunsetFade, 0.7);

vec3 uwDarkDay  = vec3(0.12, 0.22, 0.50);
vec3 uwBrightDay = vec3(0.25, 0.94, 1.0);

vec3 uwDarkSunset  = vec3(0.60, 0.22, 0.05);
vec3 uwBrightSunset = vec3(1.0, 0.80, 0.15);

vec3 uwDarkNight  = vec3(0.10, 0.18, 0.42);
vec3 uwBrightNight = vec3(0.10, 0.22, 0.45);

vec3 uwDarkBlue  = mix(mix(uwDarkDay, uwDarkSunset, sunsetFade), uwDarkNight, nightFade);
vec3 uwBrightBlue = mix(mix(uwBrightDay, uwBrightSunset, sunsetFade), uwBrightNight, nightFade);
vec3 uwScatterColor = mix(uwDarkBlue, uwBrightBlue, uwSunFactor);

if (biome_swamp > 0.001) {
vec3 uwSwampDark  = vec3(0.04, 0.10, 0.02);
vec3 uwSwampBright = vec3(0.10, 0.22, 0.05);
vec3 uwSwampScatter = mix(uwSwampDark, uwSwampBright, uwSunFactor);
uwScatterColor = mix(uwScatterColor, uwSwampScatter, biome_swamp);
}

float uwMoonDot = dot(uwRayDir, uwMoonDir) * 0.5 + 0.5;
uwMoonDot = pow(uwMoonDot, 2.0);
vec3 uwMoonBright = vec3(0.18, 0.32, 0.75);
uwScatterColor = mix(uwScatterColor, uwMoonBright, uwMoonDot * nightFade * 0.7);

float surfaceY = float(SEA_LEVEL_OFFSET) - 0.125;

vec3  uwFogAccum = uwScatterColor * uwFogOpacity;

{
float viewFogStart = float(UNDERWATER_VIEW_FOG_START) * uwSwampDistScale;
float viewFogEnd   = float(UNDERWATER_VIEW_FOG_END) * uwSwampDistScale;
float viewFogFactor = smoothstep(viewFogStart, viewFogEnd, uwMaxDist);
if (viewFogFactor > 0.001) {
float viewFogTransmittance = 1.0 - viewFogFactor;
uwFogAccum = uwFogAccum * viewFogTransmittance + uwScatterColor * viewFogFactor;
uwFogOpacity = min(1.0 - (1.0 - uwFogOpacity) * viewFogTransmittance, 0.99);
}
}

float camY = cameraPosition.y;
float depthBelow = surfaceY - camY;
float bandStrength = smoothstep(0.0, 6.0, depthBelow);
if (bandStrength > 0.001 && uwHitsAboveSurface) {
float bandTop = surfaceY;
float bandBottom = surfaceY - 0.5;

float tEnter = 0.0;
float tExit = 0.0;
bool hitsBank = false;

if (camY >= bandBottom && camY <= bandTop) {

tEnter = 0.0;
if (uwRayDir.y > 0.001) {
tExit = (bandTop - camY) / uwRayDir.y;
} else if (uwRayDir.y < -0.001) {
tExit = (bandBottom - camY) / uwRayDir.y;
} else {
tExit = 3.0;
}
hitsBank = true;
} else if (camY < bandBottom && uwRayDir.y > 0.001) {

tEnter = (bandBottom - camY) / uwRayDir.y;
tExit = (bandTop - camY) / uwRayDir.y;
hitsBank = tEnter < 200.0;
}

if (hitsBank) {
float bandOpacity = mix(0.50, 1.0, bandStrength);
float bandTransmittance = 1.0 - bandOpacity;

float bandDirDot = mix(
dot(uwRayDir, uwSunDir) * 0.5 + 0.5,
dot(uwRayDir, uwMoonDir) * 0.5 + 0.5,
nightFade
);
bandDirDot = pow(bandDirDot, 3.0);

vec3 bandDayTarget = vec3(0.30, 0.95, 1.0);
vec3 bandSunsetTarget = vec3(1.0, 0.65, 0.10);
vec3 bandNightTarget = vec3(0.16, 0.30, 0.70);
vec3 bandCyanTarget = mix(mix(bandDayTarget, bandSunsetTarget, sunsetFade), bandNightTarget, nightFade);

if (biome_swamp > 0.001) {
bandCyanTarget = mix(bandCyanTarget, vec3(0.08, 0.18, 0.04), biome_swamp);
}
vec3 bandColor = mix(uwScatterColor, bandCyanTarget, bandDirDot * 0.25);
uwFogAccum = uwFogAccum * bandTransmittance + bandColor * (1.0 - bandTransmittance);
uwFogOpacity = min(1.0 - (1.0 - uwFogOpacity) * bandTransmittance, 1.0);
}
}

#ifdef UNDERWATER_SHAFTS_ENABLED
{
float glowSunUp = max(uwSunDir.y + sunsetFade * 0.15, 0.0);
if (glowSunUp > 0.01) {

vec3 viewUp = normalize(mat3(gbufferModelViewInverse) * vec3(0.0, 1.0, 0.0));
vec3 sunRight = normalize(cross(uwSunDir, viewUp));
vec3 sunUp = cross(sunRight, uwSunDir);

float sunDot = dot(uwRayDir, uwSunDir);
float combined = 0.0;
if (sunDot > 0.0) {

vec3 delta = uwRayDir - uwSunDir * sunDot;
float dx = abs(dot(delta, sunRight));
float dy = abs(dot(delta, sunUp));

float sqDist = pow(pow(dx, 4.0) + pow(dy, 4.0), 0.25);
combined = 0.35 / (1.0 + sqDist * sqDist * 100.0);
}

float glowShadow = 1.0;
#ifdef SHADOWS_ENABLED
{

float tSurf = max((surfaceY - cameraPosition.y) / max(uwRayDir.y, 0.001), 0.0);
vec3 surfCheckPos = uwRayDir * min(tSurf, uwMaxDist);
vec4 gsClip = shadowProjection * shadowModelView * vec4(surfCheckPos, 1.0);
vec3 gsNDC = distortShadowClipPos(gsClip.xyz);
vec3 gsScreen = gsNDC * 0.5 + 0.5;
gsScreen.z -= 0.001;
if (gsScreen.x > 0.0 && gsScreen.x < 1.0 &&
gsScreen.y > 0.0 && gsScreen.y < 1.0) {
glowShadow = step(gsScreen.z, texture(shadowtex0, gsScreen.xy).r);
}
}
#endif
combined *= glowSunUp * UNDERWATER_SHAFTS_INTENSITY * glowShadow;

vec3 glowColor = mix(vec3(0.75, 0.95, 1.0), vec3(1.0, 0.70, 0.15), sunsetFade);
uwFogAccum += glowColor * combined;
}

float glowMoonUp = max(uwMoonDir.y, 0.0);
if (glowMoonUp > 0.01) {
vec3 viewUpM = normalize(mat3(gbufferModelViewInverse) * vec3(0.0, 1.0, 0.0));
vec3 moonRight = normalize(cross(uwMoonDir, viewUpM));
vec3 moonUp = cross(moonRight, uwMoonDir);

float moonDot = dot(uwRayDir, uwMoonDir);
float moonCombined = 0.0;
if (moonDot > 0.0) {
vec3 delta = uwRayDir - uwMoonDir * moonDot;
float dx = abs(dot(delta, moonRight));
float dy = abs(dot(delta, moonUp));
float sqDist = pow(pow(dx, 4.0) + pow(dy, 4.0), 0.25);
moonCombined = 0.35 / (1.0 + sqDist * sqDist * 100.0);
}
float moonGlowShadow = 1.0;
#ifdef SHADOWS_ENABLED
{
float tSurf = max((surfaceY - cameraPosition.y) / max(uwRayDir.y, 0.001), 0.0);
vec3 surfCheckPos = uwRayDir * min(tSurf, uwMaxDist);
vec4 gsClip = shadowProjection * shadowModelView * vec4(surfCheckPos, 1.0);
vec3 gsNDC = distortShadowClipPos(gsClip.xyz);
vec3 gsScreen = gsNDC * 0.5 + 0.5;
gsScreen.z -= 0.001;
if (gsScreen.x > 0.0 && gsScreen.x < 1.0 &&
gsScreen.y > 0.0 && gsScreen.y < 1.0) {
moonGlowShadow = step(gsScreen.z, texture(shadowtex0, gsScreen.xy).r);
}
}
#endif
moonCombined *= glowMoonUp * UNDERWATER_SHAFTS_INTENSITY * 0.7 * moonGlowShadow;
uwFogAccum += vec3(0.6, 0.7, 0.9) * moonCombined;
}
}
#endif

float dither = fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y)
+ 5.588238 * float(frameCounter & 63));
vec3 uwColorFog = vec3(0.0);
float uwColorFogDensity = 0.0;
int uwColorSteps = 32;
float uwColorStepSize = min(uwMaxDist, float(UNDERWATER_FOG_DISTANCE)) / float(uwColorSteps);

vec3 uwColor1 = vec3(1.0, 0.502, 0.682);
vec3 uwColor2 = vec3(0.071, 0.922, 1.0);
vec3 uwColor3 = vec3(0.722, 0.612, 1.0);

if (biome_swamp > 0.001) {
uwColor1 = mix(uwColor1, vec3(0.15, 0.25, 0.05), biome_swamp);
uwColor2 = mix(uwColor2, vec3(0.08, 0.18, 0.03), biome_swamp);
uwColor3 = mix(uwColor3, vec3(0.12, 0.10, 0.04), biome_swamp);
}

for (int i = 0; i < uwColorSteps; i++) {
float t = (float(i) + dither) * uwColorStepSize;
vec3 samplePos = cameraPosition + uwRayDir * t;

float warpTime = frameTimeCounter * 0.6;
vec3 warpedPos = samplePos;
warpedPos.x += sin(samplePos.z * 0.04 + warpTime * 1.3) * 15.0 + cos(samplePos.y * 0.06 + warpTime * 0.7) * 10.0;
warpedPos.y += sin(samplePos.x * 0.05 + warpTime * 0.9) * 12.0 + cos(samplePos.z * 0.03 + warpTime * 1.1) * 8.0;
warpedPos.z += cos(samplePos.x * 0.04 + warpTime * 1.5) * 14.0 + sin(samplePos.y * 0.05 + warpTime * 0.6) * 10.0;

float n = noise3D(vec3(warpedPos.x * 0.035, warpedPos.y * 0.03, warpedPos.z * 0.035));

if (n > 0.58) {
float fogAmount = smoothstep(0.58, 0.8, n) * 0.005;

float colorSelect = noise3D(vec3(warpedPos.x * 0.025, warpedPos.y * 0.02, warpedPos.z * 0.025) + vec3(100.0, 0.0, 50.0));
vec3 fogColor;
if (colorSelect < 0.33) fogColor = uwColor1;
else if (colorSelect < 0.66) fogColor = uwColor2;
else fogColor = uwColor3;

uwColorFog += fogColor * fogAmount;
uwColorFogDensity += fogAmount;
}
}

uwFogAccum += uwColorFog;
uwFogOpacity = min(uwFogOpacity + uwColorFogDensity, 1.0);

#ifdef UNDERWATER_SHAFTS_ENABLED
{
vec3 sunDir = uwSunDir;
float sunUpFactor = max(sunDir.y, 0.0);

if (sunUpFactor > 0.01) {
vec3 shaftScatter = vec3(0.0);
int shaftSteps = 24;

float shaftCeilingY = surfaceY - 2.0;
float shaftStartT = 0.0;
if (uwRayDir.y > 0.001 && cameraPosition.y < shaftCeilingY) {

shaftStartT = 0.0;
} else if (uwRayDir.y > 0.001) {

shaftStartT = (shaftCeilingY - cameraPosition.y) / uwRayDir.y;
}
float shaftMaxDist = min(uwMaxDist, 48.0);
float shaftRange = max(shaftMaxDist - shaftStartT, 0.0);
float shaftStepSize = shaftRange / float(shaftSteps);

vec3 shaftColorBright = vec3(0.75, 0.95, 1.0);
vec3 shaftColorDeep   = vec3(0.3, 0.55, 0.9);

for (int i = 0; i < shaftSteps; i++) {
float t = shaftStartT + (float(i) + dither) * shaftStepSize;
vec3 sampleWorldPos = cameraPosition + uwRayDir * t;

float distToSurface = (surfaceY - sampleWorldPos.y) / max(sunDir.y, 0.001);
vec3 surfaceHit = sampleWorldPos + sunDir * distToSurface;
vec3 shaftCoord = vec3(surfaceHit.xz * (UNDERWATER_SHAFTS_SCALE * 5.0), 0.0)
+ vec3(0.0, frameTimeCounter * UNDERWATER_SHAFTS_SPEED, 0.0);

float shaft = noise3D(shaftCoord);

float shaftMask = smoothstep(1.0 - UNDERWATER_SHAFTS_DENSITY * 0.6, 1.0, shaft);

float sampleDepth = max(surfaceY - sampleWorldPos.y, 0.0);
if (sampleDepth < 2.0) continue;

#ifdef SHADOWS_ENABLED
{
vec3 scenePos = sampleWorldPos - cameraPosition;
vec4 shClipPos = shadowProjection * shadowModelView * vec4(scenePos, 1.0);
vec3 shNDC = distortShadowClipPos(shClipPos.xyz);
vec3 shScreen = shNDC * 0.5 + 0.5;
shScreen.z -= 0.001;
if (shScreen.x > 0.0 && shScreen.x < 1.0 &&
shScreen.y > 0.0 && shScreen.y < 1.0) {
if (step(shScreen.z, texture(shadowtex0, shScreen.xy).r) < 0.5) continue;
}
}
#endif

float surfaceFadeIn = smoothstep(2.0, 6.0, sampleDepth);

float depthAtten = exp(-sampleDepth * 0.025) * surfaceFadeIn;

float surfaceProximity = smoothstep(16.0, 5.0, sampleDepth);
vec3 shaftColor = mix(shaftColorDeep, shaftColorBright, surfaceProximity);

float localDensity = shaftMask * depthAtten * UNDERWATER_SHAFTS_INTENSITY * 0.15;
float scatter = localDensity * shaftStepSize * 0.2;

shaftScatter += shaftColor * scatter;
}

uwFogAccum += shaftScatter * sunUpFactor;
}

float moonUpFactor = max(uwMoonDir.y, 0.0);
if (moonUpFactor > 0.01) {
vec3 moonShaftScatter = vec3(0.0);
int moonSteps = 24;

float mCeilingY = surfaceY - 2.0;
float mStartT = 0.0;
if (uwRayDir.y > 0.001 && cameraPosition.y < mCeilingY) {
mStartT = 0.0;
} else if (uwRayDir.y > 0.001) {
mStartT = (mCeilingY - cameraPosition.y) / uwRayDir.y;
}
float mMaxDist = min(uwMaxDist, 48.0);
float mRange = max(mMaxDist - mStartT, 0.0);
float mStepSize = mRange / float(moonSteps);

vec3 mBright = vec3(0.5, 0.6, 0.8);
vec3 mDeep   = vec3(0.2, 0.3, 0.6);

for (int i = 0; i < moonSteps; i++) {
float t = mStartT + (float(i) + dither) * mStepSize;
vec3 sampleWorldPos = cameraPosition + uwRayDir * t;

float distToSurface = (surfaceY - sampleWorldPos.y) / max(uwMoonDir.y, 0.001);
vec3 surfaceHit = sampleWorldPos + uwMoonDir * distToSurface;

vec3 mCoord = vec3(surfaceHit.xz * (UNDERWATER_SHAFTS_SCALE * 5.0) + 100.0, 0.0)
+ vec3(0.0, frameTimeCounter * UNDERWATER_SHAFTS_SPEED * 0.7, 0.0);
float mShaft = noise3D(mCoord);
float mMask = smoothstep(1.0 - UNDERWATER_SHAFTS_DENSITY * 0.6, 1.0, mShaft);

float sampleDepth = max(surfaceY - sampleWorldPos.y, 0.0);
if (sampleDepth < 2.0) continue;

#ifdef SHADOWS_ENABLED
{
vec3 scenePos = sampleWorldPos - cameraPosition;
vec4 shClipPos = shadowProjection * shadowModelView * vec4(scenePos, 1.0);
vec3 shNDC = distortShadowClipPos(shClipPos.xyz);
vec3 shScreen = shNDC * 0.5 + 0.5;
shScreen.z -= 0.001;
if (shScreen.x > 0.0 && shScreen.x < 1.0 &&
shScreen.y > 0.0 && shScreen.y < 1.0) {
if (step(shScreen.z, texture(shadowtex0, shScreen.xy).r) < 0.5) continue;
}
}
#endif

float surfaceFadeIn = smoothstep(2.0, 6.0, sampleDepth);
float depthAtten = exp(-sampleDepth * 0.025) * surfaceFadeIn;
float surfaceProximity = smoothstep(16.0, 5.0, sampleDepth);
vec3 mColor = mix(mDeep, mBright, surfaceProximity);

float scatter = mMask * depthAtten * UNDERWATER_SHAFTS_INTENSITY * 0.15 * mStepSize * 0.2;
moonShaftScatter += mColor * scatter;
}

uwFogAccum += moonShaftScatter * moonUpFactor * 0.25;
}
}
#endif

gl_FragData[0] = vec4(uwFogAccum, uwFogOpacity);
return;
}
#else

if (isEyeInWater == 1) {
gl_FragData[0] = vec4(0.0);
return;
}
#endif

#if !defined(ATMO_FOG_ENABLED)
{

if (gl_FragCoord.x < 1.0 && gl_FragCoord.y < 1.0) {
smoothBeach  = biome_beach;
smoothSwamp  = biome_swamp;
smoothJungle = biome_jungle;
smoothSnowy  = biome_snowy;
smoothArid   = biome_arid;
smoothOcean  = biome_ocean;

vec3 targetFog = getForcedBiomeFogColor(biome, vec3(NETHER_FOG_R, NETHER_FOG_G, NETHER_FOG_B));
vec3 prevFog = vec3(smoothNetherFogR, smoothNetherFogG, smoothNetherFogB);
if (prevFog == vec3(0.0)) prevFog = targetFog;
vec3 newFog = mix(prevFog, targetFog, 0.03);
smoothNetherFogR = newFog.r;
smoothNetherFogG = newFog.g;
smoothNetherFogB = newFog.b;

memoryBarrierBuffer();
}
gl_FragData[0] = vec4(0.0);
return;
}
#endif

vec4 maskData = texture(colortex1, texcoord);
float depth0 = texture(depthtex0, texcoord).r;
float depth1 = texture(depthtex1, texcoord).r;
float dhDepth = texture(dhDepthTex, texcoord).r;
float vxDepth = texture(vxDepthTexTrans, texcoord).r;
bool hasDHAtPixel = hasValidDHDepth(dhDepth);
bool isVoxyLodPixel = (maskData.a > 0.999 && maskData.g < 0.01);
bool hasVoxyDepth = (vxDepth > 0.00001 && vxDepth < 0.9999);

bool isTranslucent = (depth0 < depth1 - 0.00001);
float sceneDepth;
bool useVoxyProj = false;
if (hasVoxyDepth && (isTranslucent || isVoxyLodPixel)) {

sceneDepth = vxDepth;
useVoxyProj = true;
} else if (isTranslucent) {

sceneDepth = (depth1 < 0.9999) ? depth1 : depth0;
} else if (isVoxyLodPixel) {

sceneDepth = depth0;
useVoxyProj = true;
} else {
sceneDepth = depth0;
}
bool hasMCDepth = (sceneDepth < 0.9999) || isVoxyLodPixel || hasVoxyDepth;
bool isSky = !hasMCDepth;

vec3 rayDir;
float maxDist;

if (hasMCDepth) {
vec4 clipPos = vec4(texcoord * 2.0 - 1.0, sceneDepth * 2.0 - 1.0, 1.0);
mat4 projInv = useVoxyProj ? vxProjInv : gbufferProjectionInverse;
vec4 viewPos = projInv * clipPos;
viewPos /= viewPos.w;
vec3 worldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
rayDir = normalize(worldPos - cameraPosition);
maxDist = length(worldPos - cameraPosition);
} else {

if (hasDHAtPixel) {
float dhLinear = linearizeDepthDH(dhDepth);
vec4 clipFar = vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
vec4 viewPosFar = gbufferProjectionInverse * clipFar;
vec3 viewDir = normalize(viewPosFar.xyz / max(viewPosFar.w, 0.0001));
maxDist = dhLinear / max(-viewDir.z, 0.001);
rayDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
} else {

vec4 vd4 = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
rayDir = normalize(mat3(gbufferModelViewInverse) * (vd4.xyz / vd4.w));
maxDist = 0.0;
#ifdef ATMO_FOG_ENABLED
maxDist = max(maxDist, float(ATMO_FOG_DISTANCE));
#endif
}
}

float fogMaxDist = 0.0;
#ifdef ATMO_FOG_ENABLED
fogMaxDist = max(fogMaxDist, float(ATMO_FOG_DISTANCE));
#endif

if (isSky || (isTranslucent && sceneDepth >= 0.9999)) {
maxDist = fogMaxDist;
} else {
maxDist = min(maxDist, fogMaxDist);
}

float fogBottom = 0.0;
float fogTop    = 0.0;
float tEntry = 0.0;
float tExit  = 0.0;
bool hasAtmoSegment = false;

#ifdef ATMO_FOG_ENABLED

fogBottom = float(SEA_LEVEL_OFFSET);
fogTop    = cameraPosition.y + float(ATMO_FOG_ABOVE);
tEntry = 0.0;
tExit  = maxDist;

if (abs(rayDir.y) > 0.0001) {
float tBottom = (fogBottom - cameraPosition.y) / rayDir.y;
float tTop    = (fogTop    - cameraPosition.y) / rayDir.y;
float tNear = min(tBottom, tTop);
float tFar  = max(tBottom, tTop);
tEntry = max(tNear, 0.0);
tExit  = min(tFar, maxDist);
hasAtmoSegment = tEntry < tExit;
} else {
hasAtmoSegment = !(cameraPosition.y < fogBottom || cameraPosition.y > fogTop);
if (hasAtmoSegment) tExit = maxDist;
}
#endif

if (!hasAtmoSegment) {

if (gl_FragCoord.x < 1.0 && gl_FragCoord.y < 1.0) {
smoothBeach  = biome_beach;
smoothSwamp  = biome_swamp;
smoothJungle = biome_jungle;
smoothSnowy  = biome_snowy;
smoothArid   = biome_arid;
smoothOcean  = biome_ocean;

vec3 targetFog = getForcedBiomeFogColor(biome, vec3(NETHER_FOG_R, NETHER_FOG_G, NETHER_FOG_B));
vec3 prevFog = vec3(smoothNetherFogR, smoothNetherFogG, smoothNetherFogB);
float fogLerpSpeed = (length(prevFog) < 0.001) ? 1.0 : 0.03;
vec3 newFog = mix(prevFog, targetFog, fogLerpSpeed);
smoothNetherFogR = newFog.r;
smoothNetherFogG = newFog.g;
smoothNetherFogB = newFog.b;

memoryBarrierBuffer();
}
gl_FragData[0] = vec4(0.0);
return;
}

float windAngle = 1.2;
vec2 windDir2D = vec2(cos(windAngle), sin(windAngle));
vec3 windOffset = vec3(windDir2D.x, 0.0, windDir2D.y) * frameTimeCounter * ATMO_FOG_WIND_SPEED * 2.0;

float blueNoise = texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 255, 0).b;
float dither = fract(blueNoise + float(frameCounter) * 0.6180339887);

vec3 baseFogColor = getSmoothBiomeFogColor(fogColor, biome_snowy, biome_jungle, biome_swamp, biome_arid);
float fogLuma = dot(baseFogColor, vec3(0.299, 0.587, 0.114));
TimeWeightsSimple ts = getTimeWeightsSimple(sunAngle);
float dayFactor = ts.day;
float nightFactor = ts.night;

vec3 moonlightTint = vec3(0.55, 0.65, 1.0);
baseFogColor = mix(baseFogColor, moonlightTint, nightFactor);

fogLuma = dot(baseFogColor, vec3(0.299, 0.587, 0.114));
baseFogColor = max(mix(vec3(fogLuma), baseFogColor, 1.3), vec3(0.0));

float timeBrightness = max(dayFactor, nightFactor * 0.45);

float fogAngle = fract(sunAngle);
float fogTransitionDip = smoothstep(0.42, 0.5146, fogAngle) * (1.0 - smoothstep(0.5146, 0.5604, fogAngle));
timeBrightness *= 1.0 - fogTransitionDip;

float smoothedMask = storedExposure;
if (gl_FragCoord.x < 1.0 && gl_FragCoord.y < 1.0) {
float shadowedLuma = 0.0;
float litLuma = 0.0;
int shadowedCount = 0;
int litCount = 0;
for (int sy = 0; sy < 8; sy++) {
for (int sx = 0; sx < 8; sx++) {
vec2 sampleUV = (vec2(float(sx), float(sy)) + 0.5) / 8.0;
float luma = dot(texture(colortex0, sampleUV).rgb, vec3(0.299, 0.587, 0.114));

float d = texture(depthtex0, sampleUV).r;
bool inShadow = false;
if (d < 1.0) {
vec4 cp = vec4(sampleUV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
vec4 vp = gbufferProjectionInverse * cp;
vp /= vp.w;
vec3 scenePos = (gbufferModelViewInverse * vp).xyz;
vec4 sv = shadowModelView * vec4(scenePos, 1.0);
vec4 sc = shadowProjection * sv;
vec3 sn = distortShadowClipPos(sc.xyz);
vec3 ss = sn * 0.5 + 0.5;
if (ss.x > 0.0 && ss.x < 1.0 && ss.y > 0.0 && ss.y < 1.0) {
float mapD = texture(shadowtex0, ss.xy).r;
inShadow = (ss.z - 0.003) > mapD;
}
}

if (inShadow) {
shadowedLuma += luma;
shadowedCount++;
} else {
litLuma += luma;
litCount++;
}
}
}

float shadowRatio = (shadowedCount + litCount > 0) ? float(shadowedCount) / float(shadowedCount + litCount) : 0.0;
float targetMask = smoothstep(0.4, 0.75, shadowRatio);

float prevMask = storedExposure;
if (prevMask >= 0.0 && prevMask <= 1.5) {
smoothedMask = mix(prevMask, targetMask, 0.01);
} else {
smoothedMask = targetMask;
}
storedExposure = smoothedMask;

smoothBeach  = biome_beach;
smoothSwamp  = biome_swamp;
smoothJungle = biome_jungle;
smoothSnowy  = biome_snowy;
smoothArid   = biome_arid;
smoothOcean  = biome_ocean;

vec3 targetFog = getForcedBiomeFogColor(biome, vec3(NETHER_FOG_R, NETHER_FOG_G, NETHER_FOG_B));
vec3 prevFog = vec3(smoothNetherFogR, smoothNetherFogG, smoothNetherFogB);
float fogLerpSpeed = (length(prevFog) < 0.001) ? 1.0 : 0.03;
vec3 newFog = mix(prevFog, targetFog, fogLerpSpeed);
smoothNetherFogR = newFog.r;
smoothNetherFogG = newFog.g;
smoothNetherFogB = newFog.b;

memoryBarrierBuffer();
}

float coverageBrightness = mix(0.0, 2.0, smoothedMask);

coverageBrightness = mix(coverageBrightness, max(coverageBrightness, 1.5), nightFactor);

if (biome_swamp > 0.001) {

baseFogColor = mix(baseFogColor, vec3(144.0, 199.0, 90.0) / 255.0, biome_swamp);

coverageBrightness = mix(coverageBrightness, mix(1.20, 1.90, smoothedMask), biome_swamp);
}

float finalCoverage = mix(coverageBrightness, 1.5, nightFactor);
vec3 fogLitColor = baseFogColor * ATMO_FOG_BRIGHTNESS * timeBrightness * finalCoverage;

vec3 shaftLitColor = mix(
baseFogColor * ATMO_FOG_BRIGHTNESS * timeBrightness * max(coverageBrightness, 1.0),
fogLitColor,
nightFactor
);

float playerSkylight = float(eyeBrightnessSmooth.y) / 240.0;
float playerBlocklight = float(eyeBrightnessSmooth.x) / 240.0;
float smoothedScreenSkylight = storedScreenSkylight;
if (gl_FragCoord.x < 1.0 && gl_FragCoord.y < 1.0) {
float rawScreenSkylight = 0.0;
for (int sy = 0; sy < 4; sy++) {
for (int sx = 0; sx < 4; sx++) {
vec2 sampleUV = (vec2(float(sx), float(sy)) + 0.5) / 4.0;
float sd = texture(depthtex0, sampleUV).r;
float sl = (sd >= 1.0) ? 1.0 : texture(colortex1, sampleUV).b;
rawScreenSkylight += sl;
}
}
rawScreenSkylight /= 16.0;
float prev = storedScreenSkylight;
if (prev >= 0.0 && prev <= 1.0) {
smoothedScreenSkylight = mix(prev, rawScreenSkylight, 0.02);
} else {
smoothedScreenSkylight = rawScreenSkylight;
}
storedScreenSkylight = smoothedScreenSkylight;
}

float dustFactor = 1.0 - smoothstep(0.60, 0.65, playerSkylight);

if (dustFactor > 0.001) {

dustFactor *= 1.0 - smoothstep(0.3, 0.6, smoothedScreenSkylight);
}

vec3 dustColor = min(baseFogColor * timeBrightness * 3.0, vec3(1.0));

vec3 lightDirWorld = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

float marchStart = maxDist;
#ifdef ATMO_FOG_ENABLED
if (hasAtmoSegment) marchStart = min(marchStart, tEntry);
#endif

float marchEnd = 0.0;
#ifdef ATMO_FOG_ENABLED
if (hasAtmoSegment) marchEnd = max(marchEnd, tExit);
#endif

if (marchEnd <= marchStart + 0.0001) {
gl_FragData[0] = vec4(0.0);
return;
}

float marchLength = marchEnd - marchStart;
float stepSize = marchLength / float(ATMO_FOG_STEPS);
float density = max(ATMO_FOG_DENSITY + rainStrength * 0.5, 0.01);

vec3  fogAccum = vec3(0.0);
float transmittance = 1.0;

float noiseThreshold = mix(0.25, 0.10, biome_swamp);

for (int i = 0; i < ATMO_FOG_STEPS; i++) {
float t = marchStart + (float(i) + dither) * stepSize;
vec3 samplePos = cameraPosition + rayDir * t;

float extinction = 0.0;

float shadow = 0.0;
vec3 shadowTint = vec3(1.0);
#ifdef SHADOWS_ENABLED
{
vec3 scenePos = samplePos - cameraPosition;
vec4 shadowViewPos = shadowModelView * vec4(scenePos, 1.0);
vec4 shadowClipPos = shadowProjection * shadowViewPos;
vec3 shadowNDC = distortShadowClipPos(shadowClipPos.xyz);
vec3 shadowScreenPos = shadowNDC * 0.5 + 0.5;
shadowScreenPos.z -= 0.0005;

vec2 edgeDist2 = min(shadowScreenPos.xy, 1.0 - shadowScreenPos.xy);
float edgeFade = smoothstep(0.0, 0.05, min(edgeDist2.x, edgeDist2.y));

if (shadowScreenPos.x > 0.0 && shadowScreenPos.x < 1.0 &&
shadowScreenPos.y > 0.0 && shadowScreenPos.y < 1.0 &&
shadowScreenPos.z > 0.0 && shadowScreenPos.z < 1.0 &&
edgeFade > 0.001) {

float shadow0 = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
shadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);

shadow0 *= edgeFade;
shadow  *= edgeFade;

if (shadow0 < 1.0 && shadow > 0.0) {
vec2 shadowTexelSize = 1.0 / vec2(textureSize(shadowcolor0, 0));

vec3 shCol  = texture(shadowcolor0, shadowScreenPos.xy).rgb * 4.0;
shCol += texture(shadowcolor0, shadowScreenPos.xy + vec2( 1.0,  0.0) * shadowTexelSize).rgb * 2.0;
shCol += texture(shadowcolor0, shadowScreenPos.xy + vec2(-1.0,  0.0) * shadowTexelSize).rgb * 2.0;
shCol += texture(shadowcolor0, shadowScreenPos.xy + vec2( 0.0,  1.0) * shadowTexelSize).rgb * 2.0;
shCol += texture(shadowcolor0, shadowScreenPos.xy + vec2( 0.0, -1.0) * shadowTexelSize).rgb * 2.0;
shCol += texture(shadowcolor0, shadowScreenPos.xy + vec2( 1.0,  1.0) * shadowTexelSize).rgb;
shCol += texture(shadowcolor0, shadowScreenPos.xy + vec2(-1.0,  1.0) * shadowTexelSize).rgb;
shCol += texture(shadowcolor0, shadowScreenPos.xy + vec2( 1.0, -1.0) * shadowTexelSize).rgb;
shCol += texture(shadowcolor0, shadowScreenPos.xy + vec2(-1.0, -1.0) * shadowTexelSize).rgb;
shCol *= (1.0 / 16.0);
shCol *= shCol;
shadowTint = shCol * shadow + shadow0;
shadow = max(max(shadowTint.r, shadowTint.g), shadowTint.b);
shadowTint = (shadow > 0.001) ? shadowTint / shadow : vec3(1.0);
}
}
}
#endif

float tintMin = min(shadowTint.r, min(shadowTint.g, shadowTint.b));
float tintMax = max(shadowTint.r, max(shadowTint.g, shadowTint.b));
bool hasColorTint = (tintMax - tintMin) > 0.15;
if (hasColorTint) {
float shaftDensity = stepSize * 0.012;
float shaftExtinction = min(shaftDensity, 0.03);
float shaftStepT = exp(-shaftExtinction);
float shaftWeight = (shaftExtinction > 0.0001)
? (1.0 - shaftStepT) / shaftExtinction
: 1.0;
float shaftBoost = mix(8.0, 1.0, nightFactor);
fogAccum += shaftLitColor * shadowTint * shaftDensity * shaftWeight * transmittance * shaftBoost;
extinction += shaftExtinction;
}

#ifdef ATMO_FOG_ENABLED
if (hasAtmoSegment && t >= tEntry && t <= tExit) {
vec3 noiseCoord = (samplePos + windOffset) * ATMO_FOG_SCALE;
float noiseSample = afFogDensity(noiseCoord);
float heightFrac = (samplePos.y - fogBottom) / max(fogTop - fogBottom, 1.0);
float heightFade = smoothstep(1.0, 0.7, heightFrac);
float distFade = 1.0 - smoothstep(float(ATMO_FOG_DISTANCE) * 0.5, float(ATMO_FOG_DISTANCE), t);

float smoothWidth = mix(0.45, 0.65, biome_swamp);
float fogPresence = smoothstep(noiseThreshold, noiseThreshold + smoothWidth, noiseSample);
if (fogPresence > 0.001) {
float localDensity = density * fogPresence * heightFade * distFade * stepSize * 0.006;
float nightAmbient = max(shadow, nightFactor * 0.6);
float scatterAmount = min(localDensity * coverageBrightness * nightAmbient, 0.06);

float fogExtinction = isSky
? scatterAmount
: min(localDensity * coverageBrightness, 0.06);

float stepTransmittance = exp(-fogExtinction);
float integratedWeight = (fogExtinction > 0.0001)
? (1.0 - stepTransmittance) / fogExtinction
: 1.0;
fogAccum += fogLitColor * scatterAmount * integratedWeight * transmittance;
extinction += fogExtinction;
}
}
#endif

transmittance *= exp(-extinction);

if (transmittance < 0.01) break;
}

float fogOpacity = 1.0 - transmittance;

float pxSkylight = isSky ? 1.0 : texture(colortex1, texcoord).b;

if (false && dustFactor > 0.001 && !isSky) {

float dustMaxDist = min(maxDist - 4.0, 32.0);
if (dustMaxDist < 1.0) dustMaxDist = 0.0;
float dustStep = dustMaxDist / 32.0;
float dustAccum = 0.0;

for (int d = 0; d < 32; d++) {
float dt = (float(d) + dither) * dustStep;
vec3 dustPos = cameraPosition + rayDir * dt;

if (dustPos.y < float(SEA_LEVEL_OFFSET)) continue;

vec3 dustScenePos = dustPos - cameraPosition;
vec4 dsv = shadowModelView * vec4(dustScenePos, 1.0);
vec4 dsc = shadowProjection * dsv;
vec3 dsn = distortShadowClipPos(dsc.xyz);
vec3 dss = dsn * 0.5 + 0.5;
dss.z -= 0.0005;

float dustShadow = 0.0;
if (dss.x > 0.0 && dss.x < 1.0 && dss.y > 0.0 && dss.y < 1.0 &&
dss.z > 0.0 && dss.z < 1.0) {
dustShadow = step(dss.z, texture(shadowtex0, dss.xy).r);
}

dustAccum += dustShadow;
}

float flatDust = smoothstep(0.0, 4.0, dustAccum);

float dustOpacity = flatDust * dustFactor * ATMO_DUST_MAX_BRIGHTNESS;
fogAccum = mix(fogAccum, dustColor, dustOpacity);
fogOpacity = mix(fogOpacity, 1.0, dustOpacity);
}

if (false && dustFactor > 0.001 && pxSkylight > 0.4) {
float hazeFactor = smoothstep(0.4, 0.8, pxSkylight) * dustFactor;

float distHaze = smoothstep(4.0, 24.0, maxDist);
float hazeOpacity = hazeFactor * distHaze * ATMO_DUST_MAX_BRIGHTNESS * 0.2;
fogAccum = mix(fogAccum, dustColor * 0.1, hazeOpacity);
fogOpacity = mix(fogOpacity, 1.0, hazeOpacity);
}

if (false && dustFactor > 0.001 && !isSky && pxSkylight < 0.5) {

vec4 clipPos = vec4(texcoord * 2.0 - 1.0, depth0 * 2.0 - 1.0, 1.0);
vec4 viewPos = gbufferProjectionInverse * clipPos;
viewPos /= viewPos.w;
vec3 surfaceScenePos = (gbufferModelViewInverse * viewPos).xyz;

vec4 ssv = shadowModelView * vec4(surfaceScenePos, 1.0);
vec4 ssc = shadowProjection * ssv;
vec3 ssn = distortShadowClipPos(ssc.xyz);
vec3 sss = ssn * 0.5 + 0.5;
sss.z -= 0.001;

float surfaceShadow = 0.0;
if (sss.x > 0.0 && sss.x < 1.0 && sss.y > 0.0 && sss.y < 1.0 &&
sss.z > 0.0 && sss.z < 1.0) {
float sMapD = texture(shadowtex0, sss.xy).r;
surfaceShadow = step(sss.z, sMapD);
}

if (surfaceShadow > 0.0) {

float surfaceDustOpacity = surfaceShadow * dustFactor * ATMO_DUST_MAX_BRIGHTNESS * 0.1;
fogAccum = mix(fogAccum, dustColor, surfaceDustOpacity);
fogOpacity = mix(fogOpacity, 1.0, surfaceDustOpacity);
}
}

gl_FragData[0] = vec4(fogAccum, fogOpacity);
}

#else

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

uniform float biome_beach;
uniform float biome_swamp;
uniform float biome_jungle;
uniform float biome_snowy;
uniform float biome_arid;
uniform float biome_ocean;

in vec2 texcoord;

void main() {
if (gl_FragCoord.x < 1.0 && gl_FragCoord.y < 1.0) {
smoothBeach  = biome_beach;
smoothSwamp  = biome_swamp;
smoothJungle = biome_jungle;
smoothSnowy  = biome_snowy;
smoothArid   = biome_arid;
smoothOcean  = biome_ocean;

memoryBarrierBuffer();
}
gl_FragData[0] = vec4(0.0);
}

#endif
