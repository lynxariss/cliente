#ifdef WATER_DEBUG_COLORS_ENABLED
color.rgb = vec3(0.0, 0.0, 1.0);
color.a = 0.35;
#else
color.rgb = waterLitColor(color.rgb, sunAngle, skylight);
#endif

{
float flowAmount = smoothstep(0.0, 0.8, waterBlockFracY);

if (false && flowAmount > 0.01) {
#define WF_TH3(p) fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453)

float foamTime = frameTimeCounter * 1.2;
float drift = frameTimeCounter * 3.0;

vec3 fP1 = worldPos * vec3(2.5, 0.15, 2.5) + vec3(drift * 0.3, 0.0, -drift * 0.25);
fP1.y += floor(foamTime);
vec3 _i1 = floor(fP1); vec3 _f1 = fract(fP1);
float _x1 = smoothstep(0.0,1.0,_f1.x), _y1 = smoothstep(0.0,1.0,_f1.y), _z1 = smoothstep(0.0,1.0,_f1.z);
float n1A = mix(mix(mix(WF_TH3(_i1),WF_TH3(_i1+vec3(1,0,0)),_x1),mix(WF_TH3(_i1+vec3(0,1,0)),WF_TH3(_i1+vec3(1,1,0)),_x1),_y1),
mix(mix(WF_TH3(_i1+vec3(0,0,1)),WF_TH3(_i1+vec3(1,0,1)),_x1),mix(WF_TH3(_i1+vec3(0,1,1)),WF_TH3(_i1+vec3(1,1,1)),_x1),_y1),_z1);
fP1.y += 1.0;
_i1 = floor(fP1); _f1 = fract(fP1);
_x1 = smoothstep(0.0,1.0,_f1.x); _y1 = smoothstep(0.0,1.0,_f1.y); _z1 = smoothstep(0.0,1.0,_f1.z);
float n1B = mix(mix(mix(WF_TH3(_i1),WF_TH3(_i1+vec3(1,0,0)),_x1),mix(WF_TH3(_i1+vec3(0,1,0)),WF_TH3(_i1+vec3(1,1,0)),_x1),_y1),
mix(mix(WF_TH3(_i1+vec3(0,0,1)),WF_TH3(_i1+vec3(1,0,1)),_x1),mix(WF_TH3(_i1+vec3(0,1,1)),WF_TH3(_i1+vec3(1,1,1)),_x1),_y1),_z1);
float n1 = mix(n1A, n1B, smoothstep(0.0, 1.0, fract(foamTime)));

vec3 fP2 = worldPos * vec3(4.0, 0.2, 4.0) + vec3(-drift * 0.2, 0.0, drift * 0.3) + vec3(17.0);
fP2.y += floor(foamTime * 1.4);
vec3 _i2 = floor(fP2); vec3 _f2 = fract(fP2);
float _x2 = smoothstep(0.0,1.0,_f2.x), _y2 = smoothstep(0.0,1.0,_f2.y), _z2 = smoothstep(0.0,1.0,_f2.z);
float n2A = mix(mix(mix(WF_TH3(_i2),WF_TH3(_i2+vec3(1,0,0)),_x2),mix(WF_TH3(_i2+vec3(0,1,0)),WF_TH3(_i2+vec3(1,1,0)),_x2),_y2),
mix(mix(WF_TH3(_i2+vec3(0,0,1)),WF_TH3(_i2+vec3(1,0,1)),_x2),mix(WF_TH3(_i2+vec3(0,1,1)),WF_TH3(_i2+vec3(1,1,1)),_x2),_y2),_z2);
fP2.y += 1.0;
_i2 = floor(fP2); _f2 = fract(fP2);
_x2 = smoothstep(0.0,1.0,_f2.x); _y2 = smoothstep(0.0,1.0,_f2.y); _z2 = smoothstep(0.0,1.0,_f2.z);
float n2B = mix(mix(mix(WF_TH3(_i2),WF_TH3(_i2+vec3(1,0,0)),_x2),mix(WF_TH3(_i2+vec3(0,1,0)),WF_TH3(_i2+vec3(1,1,0)),_x2),_y2),
mix(mix(WF_TH3(_i2+vec3(0,0,1)),WF_TH3(_i2+vec3(1,0,1)),_x2),mix(WF_TH3(_i2+vec3(0,1,1)),WF_TH3(_i2+vec3(1,1,1)),_x2),_y2),_z2);
float n2 = mix(n2A, n2B, smoothstep(0.0, 1.0, fract(foamTime * 1.4)));

vec3 fP3 = worldPos * vec3(7.0, 0.3, 7.0) + vec3(drift * 0.15, 0.0, drift * 0.15) + vec3(31.0);
fP3.y += floor(foamTime * 1.8);
vec3 _i3 = floor(fP3); vec3 _f3 = fract(fP3);
float _x3 = smoothstep(0.0,1.0,_f3.x), _y3 = smoothstep(0.0,1.0,_f3.y), _z3 = smoothstep(0.0,1.0,_f3.z);
float n3A = mix(mix(mix(WF_TH3(_i3),WF_TH3(_i3+vec3(1,0,0)),_x3),mix(WF_TH3(_i3+vec3(0,1,0)),WF_TH3(_i3+vec3(1,1,0)),_x3),_y3),
mix(mix(WF_TH3(_i3+vec3(0,0,1)),WF_TH3(_i3+vec3(1,0,1)),_x3),mix(WF_TH3(_i3+vec3(0,1,1)),WF_TH3(_i3+vec3(1,1,1)),_x3),_y3),_z3);
fP3.y += 1.0;
_i3 = floor(fP3); _f3 = fract(fP3);
_x3 = smoothstep(0.0,1.0,_f3.x); _y3 = smoothstep(0.0,1.0,_f3.y); _z3 = smoothstep(0.0,1.0,_f3.z);
float n3B = mix(mix(mix(WF_TH3(_i3),WF_TH3(_i3+vec3(1,0,0)),_x3),mix(WF_TH3(_i3+vec3(0,1,0)),WF_TH3(_i3+vec3(1,1,0)),_x3),_y3),
mix(mix(WF_TH3(_i3+vec3(0,0,1)),WF_TH3(_i3+vec3(1,0,1)),_x3),mix(WF_TH3(_i3+vec3(0,1,1)),WF_TH3(_i3+vec3(1,1,1)),_x3),_y3),_z3);
float n3 = mix(n3A, n3B, smoothstep(0.0, 1.0, fract(foamTime * 1.8)));

float foam = smoothstep(0.20, 0.50, n1) * 0.4
+ smoothstep(0.25, 0.55, n2) * 0.35
+ smoothstep(0.30, 0.60, n3) * 0.25;

vec3 flowColor = vec3(mix(0.55, 0.75, foam));
color.rgb = mix(color.rgb, flowColor, flowAmount);
color.a = mix(color.a, 1.0, flowAmount);

#undef WF_TH3
}
}

waterReflData = vec4(waveHeight, 1.0, waterWorldNormal.x * 0.5 + 0.5, waterWorldNormal.y * 0.5 + 0.5);
