/* RENDERTARGETS: 0,12 */

const bool colortex12Clear = false;

#include "/settings.glsl"

in vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex12;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform int frameCounter;

void main() {
vec4 currentSample = texture(colortex0, texcoord);
vec3 currentColor  = currentSample.rgb;
float cloudMask    = currentSample.a;
float cloudAmt     = 1.0 - cloudMask;

bool isCloud = cloudAmt >= 0.05;

vec4 localHistory = texture(colortex12, texcoord);
bool hasCloudHistory = (localHistory.a >= 0.5);

if (!isCloud && !hasCloudHistory) {
gl_FragData[0] = vec4(currentColor, cloudMask);
gl_FragData[1] = localHistory;
return;
}

float cloudY   = float(VANILLA_CLOUD_HEIGHT) + float(SEA_LEVEL_OFFSET)
+ float(VANILLA_CLOUD_THICKNESS) * 0.5;
vec4 vd4       = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
vec3 worldDir  = normalize(mat3(gbufferModelViewInverse) * (vd4.xyz / vd4.w));
vec2 prevTexcoord = texcoord;
if (abs(worldDir.y) > 0.001) {
float tc = (cloudY - cameraPosition.y) / worldDir.y;
if (tc > 0.0) {
vec3 cloudWorldPos = cameraPosition + worldDir * tc;
vec3 prevOffset    = cloudWorldPos - previousCameraPosition;
vec4 pv            = gbufferPreviousModelView * vec4(prevOffset, 1.0);
vec4 pc            = gbufferPreviousProjection * pv;
prevTexcoord       = (pc.xy / pc.w) * 0.5 + 0.5;
}
}

vec4 historySample = texture(colortex12, prevTexcoord);
bool validHistory  = prevTexcoord.x >= 0.0 && prevTexcoord.x <= 1.0 &&
prevTexcoord.y >= 0.0 && prevTexcoord.y <= 1.0 &&
historySample.a >= 0.5;
vec3 historyColor = validHistory ? historySample.rgb : currentColor;

float blend = isCloud ? TAA_BLEND : TAA_BLEND * 0.5;

vec3 result = mix(currentColor, historyColor, blend);

gl_FragData[0] = vec4(result, cloudMask);
gl_FragData[1] = vec4(result, 1.0);
}
