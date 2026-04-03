#ifdef WATER_DEBUG_COLORS_ENABLED
color.rgb = vec3(1.0, 0.0, 0.0);
color.a = 0.35;
#else

{
float t = frameTimeCounter * 0.4;
vec3 np = vec3(worldPos.xz * 0.6, t);

float n1 = noise3D(np * 1.0 + vec3(t * 0.3, 0.0, 0.0));
float n2 = noise3D(np * 2.0 - vec3(0.0, t * 0.2, 0.0));
float n = n1 * 0.6 + n2 * 0.4;

vec3 deepColor = vec3(0.01, 0.03, 0.08);
vec3 waveColor = vec3(0.06, 0.14, 0.22);
color.rgb = mix(deepColor, waveColor, n);

float ceilingSkyDim = mix(0.15, 1.0, skylight);
color.rgb *= ceilingSkyDim;
}
color.a = WATER_OPACITY;

waterReflData.y = 1.0;
waterReflData.z = 0.5;
waterReflData.w = 1.0;
#endif
