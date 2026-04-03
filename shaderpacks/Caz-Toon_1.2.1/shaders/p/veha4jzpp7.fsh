/* RENDERTARGETS: 9,13 */

const bool colortex13Clear = false;

#include "/settings.glsl"

in vec2 texcoord;

uniform sampler2D colortex9;
uniform sampler2D colortex13;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform int isEyeInWater;

#if defined(ATMO_FOG_ENABLED) || defined(UNDERWATER_FOG_ENABLED)

#include "/include/fog_taa.glsl"

void main() {
vec4 current = texture(colortex9, texcoord);
if (isEyeInWater == 1) {

gl_FragData[0] = current;
gl_FragData[1] = current;
} else {
vec4 result = FogTemporalAccumulate(colortex9, colortex13, depthtex0, texcoord);
gl_FragData[0] = result;
gl_FragData[1] = result;
}
}

#else

void main() {
gl_FragData[0] = vec4(0.0);
gl_FragData[1] = vec4(0.0);
}

#endif
