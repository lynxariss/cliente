/* RENDERTARGETS: 0 */

#include "/settings.glsl"

in vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;

uniform float viewWidth;
uniform float viewHeight;
uniform vec3 cameraPosition;

uniform int isEyeInWater;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D dhDepthTex;
uniform float far;
uniform float dhFarPlane;
uniform float near;
uniform vec3 fogColor;
uniform float sunAngle;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform sampler2D shadowtex0;

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

void main() {
vec4 sceneData = texture(colortex0, texcoord);
vec3 color = sceneData.rgb;
float originalAlpha = sceneData.a;

float depthOpaque = texture(depthtex1, texcoord).r;
float depthNoHand = texture(depthtex2, texcoord).r;
float depthAll = texture(depthtex0, texcoord).r;
vec4 maskData = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
bool isSky = (depthOpaque >= 0.9999);

bool isHandPixel = (depthAll < depthNoHand - 0.000001) && (abs(depthAll - depthOpaque) < 0.000001);

if (isHandPixel) {
gl_FragData[0] = vec4(color, originalAlpha);
return;
}

bool isUnderwaterSurface = false;

bool entityInFront = !isHandPixel && (maskData.a > 0.01 && maskData.a < 0.99);

vec4 waterData = texelFetch(colortex5, ivec2(gl_FragCoord.xy), 0);
vec4 glassTintC17 = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0);
bool isGlassC17 = (glassTintC17.a > 0.45);
bool particleOverSky = isSky && (depthAll < 0.9999) && (waterData.y < 0.5) && !isGlassC17;
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
if (cloudData.a > 0.001 && !entityInFront && !particleOverSky) {
color = color * (1.0 - cloudData.a) + cloudData.rgb;
}
}

#ifdef OVERWORLD_FOG_ENABLED

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
#endif

#if defined(ATMO_FOG_ENABLED) || defined(UNDERWATER_FOG_ENABLED)
if (isEyeInWater != 1) {
vec4 atmoFog = max(texture(colortex9, texcoord), vec4(0.0));
if (atmoFog.a > 0.001) {
color = atmoFog.rgb + color * (1.0 - atmoFog.a);
}
}
#endif

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

gl_FragData[0] = vec4(color, originalAlpha);
}
