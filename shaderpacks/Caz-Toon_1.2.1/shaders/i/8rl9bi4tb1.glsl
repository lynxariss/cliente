#ifndef INCLUDE_WAVING_GLSL
#define INCLUDE_WAVING_GLSL

const float pi           = 3.14159265359;
const float tau          = 6.28318530718;
const float degree       = pi / 180.0;
const float golden_angle = 2.39996322973;

float sqr(float x) { return x * x; }
float clamp01(float x) { return clamp(x, 0.0, 1.0); }

#ifndef WAVING_STYLE
#define WAVING_STYLE 1
#endif

#ifndef IS_IRIS

uniform vec3 cameraPosition;
#define eyePosition cameraPosition
#else

uniform vec3 eyePosition;
#endif

#ifndef FRAME_TIME_COUNTER_DECLARED
#define FRAME_TIME_COUNTER_DECLARED
uniform float frameTimeCounter;
#endif

float get_waving_distance_boost(vec3 world_pos) {

float d = length(world_pos - eyePosition);
float t = smoothstep(WAVING_DISTANCE_BOOST_START, WAVING_DISTANCE_BOOST_END, d);
return mix(1.0, WAVING_DISTANCE_BOOST_MAX, t);
}

uniform float rainStrength;
uniform sampler2D noisetex;

const int BLOCK_SMALL_PLANTS      = 2;
const int BLOCK_TALL_PLANTS_LOWER = 3;
const int BLOCK_TALL_PLANTS_UPPER = 4;
const int BLOCK_LEAVES            = 5;
const int BLOCK_HANGING_LANTERN   = 6;
const int BLOCK_GRASS_BLOCK       = 15;
const int BLOCK_OAK_LEAVES        = 82;

vec3 rotate_x(vec3 p, float a) {
float s = sin(a);
float c = cos(a);
return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

vec3 rotate_z(vec3 p, float a) {
float s = sin(a);
float c = cos(a);
return vec3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

void swing_lantern(inout vec3 world_pos, vec3 mid_block_offset) {
vec3 center = world_pos + mid_block_offset / 64.0;
vec3 pivot = center;
pivot.y = floor(pivot.y + 1.0);

vec2 cell = floor(center.xz);
float n1 = texture(noisetex, (cell + vec2(0.5, 0.5)) / 256.0).r;
float n2 = texture(noisetex, (cell + vec2(1.5, 2.5)) / 256.0).r;

float strength = (0.08 + 0.12 * rainStrength) * LANTERN_SWAY_INTENSITY;
strength *= get_waving_distance_boost(center);
float t = frameTimeCounter * LANTERN_SWAY_SPEED;
float angle_x = sin(t * 1.2 + n1 * tau) * strength;
float angle_z = sin(t * 1.6 + n2 * tau) * strength * 0.8;

vec3 local_pos = world_pos - pivot;
local_pos = rotate_x(local_pos, angle_x);
local_pos = rotate_z(local_pos, angle_z);
world_pos = pivot + local_pos;
}

vec3 get_wind_displacement(vec3 world_pos, float wind_speed, float wind_strength, bool is_tall_plant_top_vertex) {
const float wind_angle = 30.0 * degree;
const vec2  wind_dir   = vec2(cos(wind_angle), sin(wind_angle));

float t = wind_speed * frameTimeCounter;

float gust_amount  = texture(noisetex, 0.05 * (world_pos.xz + wind_dir * t)).y;
gust_amount *= gust_amount;

vec3 gust = vec3(wind_dir * gust_amount, 0.1 * gust_amount).xzy;

world_pos = 32.0 * world_pos + 3.0 * t + vec3(0.0, golden_angle, 2.0 * golden_angle);
vec3 wobble = sin(world_pos) + 0.5 * sin(2.0 * world_pos) + 0.25 * sin(4.0 * world_pos);

if (is_tall_plant_top_vertex) { gust *= 2.0; wobble *= 0.5; }

return wind_strength * (gust + 0.1 * wobble);
}

vec3 get_player_displacement(vec3 world_pos) {
vec3 to_player = eyePosition - world_pos;
return vec3(
-6.0 * to_player.xz * exp2(-length(to_player * vec3(6.0, 2.0, 6.0))),
0.0
).xzy;
}

vec3 get_player_displacement_grass(vec3 world_pos) {

vec2 to_player_xz = (eyePosition - world_pos).xz;
float d = length(to_player_xz);
float t = 1.0 - smoothstep(0.0, GRASS_INTERACTION_RADIUS, d);

float yDist = abs(eyePosition.y - world_pos.y);
float yFade = 1.0 - smoothstep(1.0, 2.5, yDist);

vec2 dir = (d > 1e-4) ? (to_player_xz / d) : vec2(0.0);

float strength = t * t * yFade;
return vec3(-dir * (0.35 * strength), 0.0).xzy;
}

vec3 animate_vertex(vec3 world_pos, bool is_top_vertex, float skylight, int block_id, vec3 mid_block_offset) {
float wind_speed    = 0.3 * WAVING_SPEED;

float effectiveSkylight = max(skylight, 0.5);
float wind_strength = sqr(effectiveSkylight) * (0.25 + 0.66 * rainStrength) * WAVING_INTENSITY;

#if WAVING_STYLE == 0

vec3 player_disp = vec3(0.0);
#ifdef PLAYER_PLANT_INTERACTION
player_disp = get_player_displacement(world_pos) * PLAYER_INTERACTION_INTENSITY;
#endif

#ifdef WAVING_PLANTS
if (block_id == BLOCK_SMALL_PLANTS) {
return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, false) + player_disp) * float(is_top_vertex);
}
if (block_id == BLOCK_TALL_PLANTS_LOWER) {
return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, false) + player_disp) * float(is_top_vertex);
}
if (block_id == BLOCK_TALL_PLANTS_UPPER) {
return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, is_top_vertex) + player_disp);
}
if (block_id == BLOCK_GRASS_BLOCK) {
return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, false) + player_disp) * float(is_top_vertex);
}
#endif

#ifdef WAVING_LEAVES
if (block_id == BLOCK_LEAVES || block_id == BLOCK_OAK_LEAVES) {
return world_pos + get_wind_displacement(world_pos, wind_speed, wind_strength * 0.5, false);
}
#endif

return world_pos;
#else

wind_strength *= get_waving_distance_boost(world_pos);

vec3 player_disp = vec3(0.0);
vec3 player_disp_grass = vec3(0.0);
#ifdef PLAYER_PLANT_INTERACTION
player_disp = get_player_displacement(world_pos) * PLAYER_INTERACTION_INTENSITY;
player_disp_grass = get_player_displacement_grass(world_pos) * GRASS_INTERACTION_INTENSITY;
#endif

#ifdef WAVING_PLANTS
if (block_id == BLOCK_SMALL_PLANTS) {
return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, false) + player_disp) * float(is_top_vertex);
}
if (block_id == BLOCK_TALL_PLANTS_LOWER) {
return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, false) + player_disp) * float(is_top_vertex);
}
if (block_id == BLOCK_TALL_PLANTS_UPPER) {
return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, is_top_vertex) + player_disp);
}
if (block_id == BLOCK_GRASS_BLOCK) {

float grass_speed = wind_speed * GRASS_WAVING_SPEED;
float grass_strength = wind_strength * GRASS_WAVING_INTENSITY;
return world_pos + (get_wind_displacement(world_pos, grass_speed, grass_strength, false) + player_disp_grass) * float(is_top_vertex);
}
#endif

#ifdef WAVING_LEAVES
if (block_id == BLOCK_LEAVES || block_id == BLOCK_OAK_LEAVES) {
return world_pos + get_wind_displacement(world_pos, wind_speed, wind_strength * 1.5, false);
}
#endif

#ifdef SWAYING_LANTERNS
if (block_id == BLOCK_HANGING_LANTERN) {
swing_lantern(world_pos, mid_block_offset);
return world_pos;
}
#endif

return world_pos;
#endif
}

#endif
