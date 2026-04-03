// ============================================================================
// =====                        LIGHTING                                  =====
// ============================================================================

// ----------------------------------------------------------------------------
//   Shadows
// ----------------------------------------------------------------------------

// Enable directional shadows (sun/moon shadows)
#define SHADOWS_ENABLED


// Shadow map resolution (lower is faster, Quartic Distortion keeps detail high)
const int shadowMapResolution = 4096; // [512 1024 2048 3072 4096 6144 8192 12288 16384]

// Shadow render distance (blocks)
#define SHADOW_DISTANCE 512.0// [32.0 48.0 64.0 80.0 96.0 112.0 128.0 144.0 160.0 176.0 192.0 224.0 256.0 320.0 384.0 512.0 640.0 768.0 1024.0 1280.0 1536.0 2000.0 2500.0 3000.0 4000.0 5000.0 6000.0 8000.0 10000.0]

// Shadow distortion factor (balance between resolution and edge quality)
// Lower values = more uniform coverage (better for long distance), higher = more detail at center
#define SHADOW_DISTORTION 0.10// [0.02 0.03 0.04 0.05 0.08 0.10 0.12 0.15 0.20 0.25 0.30 0.40 0.50 0.60 0.70 0.85]

// Photon-style shadow depth scale (internal)
#define SHADOW_DEPTH_SCALE 0.2

// Normal bias scale (reduces shadow acne)
#define SHADOW_NORMAL_BIAS 2.0 // [0.00 0.50 1.00 1.50 2.00 2.50 3.00 4.00 5.00]

// Shadow opacity (0 = no shadows, 1 = full dark shadows)
#define SHADOW_OPACITY 0.50// [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

// Shadow color tint (0 = no tint, positive = cool/blue, negative = warm/orange)
#define SHADOW_HUE 45.0// [-180.0 -165.0 -150.0 -135.0 -120.0 -105.0 -90.0 -75.0 -60.0 -45.0 -30.0 -15.0 0.0 15.0 30.0 45.0 60.0 75.0 90.0 105.0 120.0 135.0 150.0 165.0 180.0]

// Shadow color saturation (0 = subtle/washed out, 1 = vivid/saturated, higher = oversaturated)
#define SHADOW_SATURATION 1.75// [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.25 1.50 1.75 2.00 2.50 3.00 4.00 5.00]

// How much blocklight can override/cancel directional shadows around light sources.
// 0 = no override, 1 = full override near strong blocklight.
#define BLOCKLIGHT_SHADOW_OVERRIDE 1.00// [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// Lightmap shadow settings (for areas beyond shadow map distance)
// These control the darkness/color of areas with low skylight
#define LIGHTMAP_SATURATION 0.30// [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// Skylight darkness levels. Subtracts fixed levels from skylight 14..1 (15 untouched).
// 0 = no change, 13 = strongest darkening.
#define SKYLIGHT_DARKNESS_LEVELS 0 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13]

// Skylight darkness increment curve (Z):
// 0.0 = gentle progression (x1, x1.1, x1.2...), 1.0 = steep progression (x1, x2, x3...).
#define SKYLIGHT_DARKNESS_Z 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

// Shadow filter style: Sharp uses hardware-bilinear, Soft uses Blue Noise PCF
#define SHARP_SHADOWS // Sharp shadows use less GPU and look crisper. Comment out for Soft shadows.

// PCF filter radius for soft shadows (only used when SHARP_SHADOWS is disabled).
// Higher values blur shadow edges more.
#define SHADOW_PCF_RADIUS 2.5 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 5.0 6.0 8.0]

// Enable underground cave shadow map support from the Caz-Toon Iris addon mod.
//#define CAVE_SHADOWS_ENABLED

// Enable block casters in the cave shadow map (separate from entity casters).
//#define CAVE_SHADOW_BLOCKS_ENABLED

// Use nearby minecraft:light blocks as cave shadow sources (multi-source mode).
// Disable for one global 45-degree cave shadow source.
//#define CAVE_SHADOW_LIGHT_BLOCK_SOURCES

// How strongly the cave shadow map darkens underground lighting.
#define CAVE_SHADOW_STRENGTH 5.00// [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.75 0.80 0.90 1.00 1.25 1.50 1.75 2.00 2.50 3.00 4.00 5.00 6.00 7.00 8.00 9.00 10.00]

// Rotates the underground shadow source direction in degrees.
#define CAVE_SHADOW_ROTATION 310.0 // [0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 55.0 60.0 65.0 70.0 75.0 80.0 85.0 90.0 95.0 100.0 105.0 110.0 115.0 120.0 125.0 130.0 135.0 140.0 145.0 150.0 155.0 160.0 165.0 170.0 175.0 180.0 185.0 190.0 195.0 200.0 205.0 210.0 215.0 220.0 225.0 230.0 235.0 240.0 245.0 250.0 255.0 260.0 265.0 270.0 275.0 280.0 285.0 290.0 295.0 300.0 305.0 310.0 315.0 320.0 325.0 330.0 335.0 340.0 345.0 350.0 355.0 360.0]

// Drive cave shadow source angle from nearest block light around the player.
//#define CAVE_SHADOW_DYNAMIC_ANGLE

// Anchor cave addon toggles in shader code so Iris exposes them in option menus.
#ifdef CAVE_SHADOW_BLOCKS_ENABLED
const bool CAVE_SHADOW_BLOCKS_ENABLED_ANCHOR = true;
#else
const bool CAVE_SHADOW_BLOCKS_ENABLED_ANCHOR = false;
#endif

#ifdef CAVE_SHADOW_LIGHT_BLOCK_SOURCES
const bool CAVE_SHADOW_LIGHT_BLOCK_SOURCES_ANCHOR = true;
#else
const bool CAVE_SHADOW_LIGHT_BLOCK_SOURCES_ANCHOR = false;
#endif

#ifdef CAVE_SHADOW_DYNAMIC_ANGLE
const bool CAVE_SHADOW_DYNAMIC_ANGLE_ANCHOR = true;
#else
const bool CAVE_SHADOW_DYNAMIC_ANGLE_ANCHOR = false;
#endif

// Tints direct shadowed areas bright red for debugging.
//#define SHADOW_DEBUG_TINT

// Visualizes cave/interior lighting terms after all shadowing.
//#define CAVE_LIGHT_DEBUG

// Shows the underground cave shadow contribution directly on terrain/water.
//#define CAVE_SHADOW_DEBUG_VIEW


// ----------------------------------------------------------------------------
//   Ambient & World Lighting
// ----------------------------------------------------------------------------

// Terrain brightness multiplier
#define TERRAIN_BRIGHTNESS 0.80// [0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20]

// Night ambient light (0 = pure darkness)
#define NIGHT_AMBIENT 0.35// [0.00 0.005 0.01 0.015 0.02 0.025 0.03 0.035 0.04 0.045 0.05 0.06 0.07 0.08 0.09 0.10 0.12 0.15 0.20 0.25 0.30 0.35 0.40 0.50 0.60 0.75 1.00]

// Cave/indoor ambient light
#define CAVE_AMBIENT 0.01 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.12 0.15 0.20]

// Blocklight brightness (torches, lanterns, etc.)
#define BLOCKLIGHT_BRIGHTNESS 0.65// [0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.10 1.20 1.30 1.40 1.50]

// Reduce blocklight when skylight is present.
// 0 = no reduction, 1 = full reduction at full skylight.
#define BLOCKLIGHT_SKYLIGHT_REDUCTION 0.50// [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// Entity brightness boost (0 = normal, 1 = fully bright)
#define ENTITY_BRIGHTNESS_BOOST 0.00// [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

// Ambient tint (negative = warm, 0 = neutral, positive = cool/blue)
#define AMBIENT_TINT 0.3 // [-1.00 -0.90 -0.80 -0.70 -0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// How strongly the sky colors tint world skylight (0 = neutral white skylight, 1 = fully sky-colored)
// This is what makes the world pick up the warm horizon glow at sunset.
#define SKYLIGHT_COLOR_TINT 0.25// [0.00 0.25 0.50 0.65 0.75 0.85 1.00 1.25 1.50 2.00]

// Skylight tint saturation (applies to the sky-tinted lighting on blocks; 1.0 = unchanged)
#define SKYLIGHT_TINT_SATURATION 1.10// [0.00 0.25 0.50 0.75 1.00 1.10 1.25 1.50 1.75 2.00 2.50 3.00 4.00 5.00]

// Extra saturation applied mostly in bright/lit areas.
// 0 = keep lit areas closer to neutral, 1 = lit areas use full SKYLIGHT_TINT_SATURATION.
#define SKYLIGHT_TINT_LIGHT_SATURATION 0.50// [0.00 0.25 0.50 0.75 1.00 1.25 1.50 2.00 3.00]

// Extra tint/saturation boost at sunset and sunrise on terrain.
// 0 = no extra warmth beyond SKYLIGHT_COLOR_TINT, higher = stronger golden-hour glow on blocks.
#define SUNSET_TERRAIN_TINT 0.30// [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 1.00 1.10 1.20 1.30 1.40 1.50]

// ----------------------------------------------------------------------------
//   Weather (Rain)
// ----------------------------------------------------------------------------

// Rain transparency multiplier (0 = invisible rain, 1 = vanilla texture alpha)
#define RAIN_OPACITY 0.50// [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.75 0.80 0.90 1.00]

// Rain wind strength (slants/sways rain; 0 = straight down)
#define RAIN_WIND_STRENGTH 1.00// [0.00 0.10 0.20 0.30 0.35 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// Rain puddles on surfaces (requires water reflections to be enabled)
#define PUDDLES_ENABLED
// Overall puddle coverage/strength
#define PUDDLES_STRENGTH 1.00// [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.25 1.50 2.00]
// How reflective puddles are
#define PUDDLES_REFLECTION_STRENGTH 0.30// [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// Water runoff streaks on vertical surfaces during rain
#define WALL_RUNOFF_ENABLED
// Overall visibility/strength of runoff streaks
#define WALL_RUNOFF_STRENGTH 0.55 // [0.00 0.10 0.20 0.30 0.40 0.50 0.55 0.60 0.70 0.80 0.90 1.00]
// Speed of the downward flow
#define WALL_RUNOFF_SPEED 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 2.00 2.50 3.00]

// ----------------------------------------------------------------------------
//   Emissive Blocks
// ----------------------------------------------------------------------------

// Per-pixel emissive masking — only glowing parts of blocks emit (torch flame glows, stick doesn't)
#define EMISSIVE_MASKING

// Emissive block brightness multiplier
#define EMISSIVE_BRIGHTNESS 1.30 // [0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.40 1.50 1.75 2.00]
#define ENTITY_EMISSIVE_BRIGHTNESS 2.00 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.60 1.70 1.80 1.90 2.00 2.20 2.40 2.60 2.80 3.00 3.50 4.00 5.00 6.00]
#define ENTITY_EMISSIVE_BLOOM 5.00 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.60 1.70 1.80 1.90 2.00 2.20 2.40 2.60 2.80 3.00 3.50 4.00 5.00 6.00 8.00]

// Dynamic handheld light (held torches/lanterns/etc. light nearby world around player)
#define HANDHELD_LIGHT_ENABLED
#define HANDHELD_LIGHT_STRENGTH 0.50 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.20 1.40 1.60 1.80 2.00 2.50 3.00]
#define HANDHELD_LIGHT_RADIUS 12.0 // [4.0 6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0 24.0 28.0 32.0 40.0]

// Handheld 3D block bloom (for mods that render held items as terrain)
// Emission: brightness of the glowing texture on the held item
#define HELD_BLOOM_EMISSION 1.25 // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 4.0 5.0 6.0 8.0 10.0 15.0 20.0]
// Bloom strength: intensity of the bloom glow around the held item
#define HELD_BLOOM_STRENGTH 0.5 // [0.5 1.0 1.5 2.0 2.5 3.0 4.0 5.0 6.0 8.0 10.0 15.0 20.0 30.0 50.0]
// Detection radius: how close to the player (in blocks) items are detected
#define HELD_BLOOM_RADIUS 0.8 // [0.5 0.8 1.0 1.2 1.5 2.0 2.5 3.0]
// Luma threshold: minimum texture brightness to trigger bloom
#define HELD_BLOOM_THRESHOLD 0.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8]

