/* RENDERTARGETS: 11,15 */

const bool colortex15Clear = false;

#include "/settings.glsl"

in vec2 texcoord;

uniform sampler2D colortex11;
uniform sampler2D colortex15;
uniform sampler2D depthtex0;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

#ifdef WEATHER_FOG_ENABLED

#include "/include/fog_taa.glsl"

void main() {
vec4 result = FogTemporalAccumulate(colortex11, colortex15, depthtex0, texcoord);
gl_FragData[0] = result;
gl_FragData[1] = result;
}

#else

void main() {
gl_FragData[0] = vec4(0.0);
gl_FragData[1] = vec4(0.0);
}

#endif
