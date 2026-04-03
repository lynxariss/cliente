#include "/settings.glsl"
#define VOXY_PROGRAM
#include "/include/voxy_compat.glsl"
#include "/include/noise.glsl"

uniform int biome;

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

#include "/include/lava_crust.glsl"

layout(location = 0) out vec4 voxyOut0;
layout(location = 1) out vec4 voxyOut1;
layout(location = 2) out vec4 voxyOut2;

void voxy_emitFragment(VoxyFragmentParameters parameters) {
vec4 src = parameters.sampledColour * parameters.tinting;
vec3 color = max(src.rgb, vec3(0.0));

uint rawId = parameters.customId;
uint id = voxy_block_id(rawId);

vec2 voxyScreenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
vec3 voxyNdc = vec3(voxyScreenUV, gl_FragCoord.z) * 2.0 - 1.0;
vec4 voxyViewH = vxProjInv * vec4(voxyNdc, 1.0);
vec3 voxyViewPos = voxyViewH.xyz / voxyViewH.w;
vec3 voxyWorldPos = (gbufferModelViewInverse * vec4(voxyViewPos, 1.0)).xyz + cameraPosition;

float faceShade = (voxyWorldPos.y < float(SEA_LEVEL_OFFSET)) ? 1.0 : mix(1.0, voxy_face_shade(parameters.face), VOXY_SHADOW_OPACITY);
color *= faceShade;

if (id == 5u) color *= VOXY_LEAF_BRIGHTNESS;

#ifdef VOXY_OAK_LEAF_FACES
if (id == 82u) {
float oakMul = VOXY_LEAF_BRIGHTNESS;
uint f = parameters.face;
if      (f == 1u) oakMul *= VOXY_OAK_LEAF_TOP;
else if (f == 0u) oakMul *= VOXY_OAK_LEAF_BOTTOM;
else if (f == 2u) oakMul *= VOXY_OAK_LEAF_NORTH;
else if (f == 3u) oakMul *= VOXY_OAK_LEAF_SOUTH;
else if (f == 4u) oakMul *= VOXY_OAK_LEAF_WEST;
else              oakMul *= VOXY_OAK_LEAF_EAST;
color *= oakMul;
}
#else
if (id == 82u) color *= VOXY_LEAF_BRIGHTNESS;
#endif

if (id == 15u) color *= VOXY_GRASS_BRIGHTNESS;

float skylight = clamp(parameters.lightMap.y, 0.0, 1.0);

if (isEyeInWater == 1) {
skylight = max(skylight, 0.2);
}

float blocklight = clamp(parameters.lightMap.x, 0.0, 1.0);

bool isSculk = (rawId == 10046u || rawId == 10056u || rawId == 10057u);
bool isEmissive = (rawId >= 10020u && rawId <= 10059u) && !isSculk;
float emissive = isEmissive ? 1.0 : 0.0;
vec3 lightColor = vec3(0.0);

#if defined(VOXY_TILE_BLUR_ENABLED) && !defined(END_SHADER)

vec4 flatSample = voxy_tile_blur(parameters.uv, gl_FragCoord.z);
vec3 flatColor = max((flatSample * parameters.tinting).rgb, vec3(0.0));
flatColor *= faceShade;
if (id == 5u) flatColor *= VOXY_LEAF_BRIGHTNESS;
#ifdef VOXY_OAK_LEAF_FACES
if (id == 82u) {
float oakFlatMul = VOXY_LEAF_BRIGHTNESS;
uint ff = parameters.face;
if      (ff == 1u) oakFlatMul *= VOXY_OAK_LEAF_TOP;
else if (ff == 0u) oakFlatMul *= VOXY_OAK_LEAF_BOTTOM;
else if (ff == 2u) oakFlatMul *= VOXY_OAK_LEAF_NORTH;
else if (ff == 3u) oakFlatMul *= VOXY_OAK_LEAF_SOUTH;
else if (ff == 4u) oakFlatMul *= VOXY_OAK_LEAF_WEST;
else               oakFlatMul *= VOXY_OAK_LEAF_EAST;
flatColor *= oakFlatMul;
}
#else
if (id == 82u) flatColor *= VOXY_LEAF_BRIGHTNESS;
#endif
if (id == 15u) flatColor *= VOXY_GRASS_BRIGHTNESS;
float flatStrength = voxy_tile_blur_strength(gl_FragCoord.z);
#endif

if (!isEmissive) {
color = voxy_apply_chunk_like_lighting(color, sunAngle, skylight, blocklight);
if (isEyeInWater != 1) {
color = voxy_apply_color_adjust(color);
}

#if defined(VOXY_TILE_BLUR_ENABLED) && !defined(END_SHADER)
flatColor = voxy_apply_chunk_like_lighting(flatColor, sunAngle, skylight, blocklight);
if (isEyeInWater != 1) {
flatColor = voxy_apply_color_adjust(flatColor);
}
#endif

} else {
vec3 whiteGlow = vec3(1.0);
vec3 coloredGlow = src.rgb;
vec3 emissiveColor = mix(whiteGlow, coloredGlow, VOXY_EMISSIVE_COLOR_STRENGTH);
float cappedBrightness = min(EMISSIVE_BRIGHTNESS * VOXY_LOD_BRIGHTNESS, VOXY_EMISSIVE_BRIGHTNESS_CAP);
color = emissiveColor * cappedBrightness;

if (rawId == 10022u) {
lightColor = vec3(1.0, 0.4, 0.1);
} else {
float brightness = max(max(src.r, src.g), src.b);
if (brightness > 0.01) {
lightColor = normalize(src.rgb + 0.1) * 1.2;
} else {
lightColor = vec3(1.0, 0.85, 0.6);
}
}
lightColor *= VOXY_EMISSIVE_INTENSITY;

}

bool isLava = (rawId == 10039u || id == 39u);

#if defined(VOXY_TILE_BLUR_ENABLED) && !defined(END_SHADER)
if (!isLava) color = mix(color, flatColor, flatStrength);
#endif

#ifdef LAVA_CRUST_ENABLED
if (isLava) {
vec3 voxyN = voxy_face_normal(parameters.face);
color = applyLavaCrust(color, voxyWorldPos, voxyN);

#ifdef BIOME_SOUL_SAND_VALLEY
if (biome == BIOME_SOUL_SAND_VALLEY) {
float lavaLum = dot(color, vec3(0.299, 0.587, 0.114));
vec3 blueLava = vec3(1.0/255.0, 158.0/255.0, 210.0/255.0) * lavaLum * 2.0;
color = blueLava;
}
#endif
}
#endif

#if defined(END_SHADER) && defined(END_TERRAIN_PATCHES_ENABLED)
if (!isEmissive) {
vec3 patchPos3D = voxyWorldPos * END_TERRAIN_PATCH_SCALE;
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
color *= patchDark;
}
#endif

if (isEyeInWater == 1) {
color *= 1.4;
}

{
bool isMagma = (rawId == 10040u || id == 40u);

bool isSoulValley = (smoothNetherFogB > smoothNetherFogR * 1.5);
if ((isLava || isMagma) && isSoulValley) {
float bloomLum = dot(lightColor, vec3(0.299, 0.587, 0.114));
lightColor = vec3(1.0/255.0, 158.0/255.0, 210.0/255.0) * bloomLum * 2.0;

if (isMagma) {
float magmaWarmth = max(color.r - color.b, 0.0);
float magmaLum = dot(color, vec3(0.299, 0.587, 0.114));
vec3 blueMagma = vec3(1.0/255.0, 158.0/255.0, 210.0/255.0) * magmaLum * 2.0;
color = mix(color, blueMagma, smoothstep(0.05, 0.2, magmaWarmth));
}
}
}

voxyOut0 = vec4(color, 1.0);

voxyOut1 = vec4(1.0, emissive * VOXY_EMISSIVE_INTENSITY, skylight, 1.0);
voxyOut2 = vec4(lightColor, 1.0);
}
