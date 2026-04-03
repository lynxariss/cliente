// ============================================================================
// =====                          WATER                                   =====
// ============================================================================

// Sea level offset (moves shader world up/down)
#define SEA_LEVEL_OFFSET 63// [-254 -65 -64 -63 -62 -61 -60 0 60 61 62 63 64 65 254]

// ============================================================================
// =====                         GLASS FILTER                              =====
// ============================================================================

// Enforce stained-glass style color filtering on everything seen through glass.
// This uses the per-pixel glass tint buffer (colortex4) written by the translucent pass.
#define GLASS_FILTER_ENABLED

// Overall strength multiplier (0 = off, 1 = default, >1 = stronger)
#define GLASS_FILTER_STRENGTH 0.75 // [0.00 0.10 0.25 0.50 0.75 1.00 1.25 1.35 1.50 1.75 2.00]

// 0 = mostly multiply (subtle), 1 = luminance-based enforcement (strong, like your screenshots)
#define GLASS_FILTER_ENFORCEMENT 0.50 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

// Saturation boost for the glass tint color itself
#define GLASS_FILTER_SATURATION 1.25 // [0.50 0.75 1.00 1.25 1.50 1.80 2.00 2.50 3.00]

// ----------------------------------------------------------------------------
//   Water Surface (Above Water View)
// ----------------------------------------------------------------------------

// Water surface color (RGB)
#define WATER_COLOR_R 0.05 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40]
#define WATER_COLOR_G 0.40 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50]
#define WATER_COLOR_B 0.50 // [0.20 0.30 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.80]

// Water saturation - increases vibrancy of water color in all biomes
#define WATER_SATURATION 1.75 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00 4.00 5.00 7.50 10.00 15.00 20.00]

// DH/Voxy water saturation
#define WATER_DH_SATURATION 3.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00 4.00 5.00 7.50 10.00 15.00 20.00]

// Night-time saturation multiplier for water surface. Applied on top of base saturation at night.
// <1.0 = desaturate at night, 1.0 = no change, >1.0 = boost color at night.
#define WATER_NIGHT_SATURATION 0.60 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.25 1.50 2.00 2.50 3.00]

// Water brightness multiplier for chunk water
#define WATER_BRIGHTNESS 1.75 // [0.10 0.25 0.50 0.75 1.00 1.05 1.25 1.35 1.50 1.75 2.00 2.50 3.00 4.00 5.00]

// Water brightness multiplier for DH/Voxy LOD water
#define WATER_DH_BRIGHTNESS 1.40 // [0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.05 1.10 1.20 1.30 1.35 1.40 1.50 1.60 1.70 1.80 1.90 2.00 2.10 2.20 2.30 2.40 2.50 2.60 2.70 2.80 2.90 3.00 3.50 4.00 5.00]

// Water shadow opacity - controls shadow darkness on water (separate from terrain)
#define WATER_SHADOW_OPACITY 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

// Water reflection fade brightness - controls the fresnel fade edge brightness
#define WATER_REFLECTION_FADE 1.0 // [0.3 0.5 0.7 1.0 1.3 1.5 2.0 2.5 3.0]

// Water specular (sun/moon reflection intensity)
#define WATER_SPECULAR_INTENSITY 1.50// [0.00 0.25 0.50 0.75 1.00 1.50 2.00 3.00 4.00 5.00 10.00 20.00]

// --- Water Foam/Edge Effect ---
// Adds a lighter foam-like effect where water meets blocks
#define WATER_FOAM_ENABLED
#define WATER_FOAM_INTENSITY 1.0 // [0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WATER_FOAM_WIDTH 2.0 //  Depth in blocks[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0 5.1 5.2 5.3 5.4 5.5 5.6 5.7 5.8 5.9 6.0 6.1 6.2 6.3 6.4 6.5 6.6 6.7 6.8 6.9 7.0 7.1 7.2 7.3 7.4 7.5 7.6 7.7 7.8 7.9 8.0 8.1 8.2 8.3 8.4 8.5 8.6 8.7 8.8 8.9 9.0 9.1 9.2 9.3 9.4 9.5 9.6 9.7 9.8 9.9 10.0 10.1 10.2 10.3 10.4 10.5 10.6 10.7 10.8 10.9 11.0 11.1 11.2 11.3 11.4 11.5 11.6 11.7 11.8 11.9 12.0 12.1 12.2 12.3 12.4 12.5 12.6 12.7 12.8 12.9 13.0 13.1 13.2 13.3 13.4 13.5 13.6 13.7 13.8 13.9 14.0 14.1 14.2 14.3 14.4 14.5 14.6 14.7 14.8 14.9 15.0 15.1 15.2 15.3 15.4 15.5 15.6 15.7 15.8 15.9 16.0 16.1 16.2 16.3 16.4 16.5 16.6 16.7 16.8 16.9 17.0 17.1 17.2 17.3 17.4 17.5 17.6 17.7 17.8 17.9 18.0 18.1 18.2 18.3 18.4 18.5 18.6 18.7 18.8 18.9 19.0 19.1 19.2 19.3 19.4 19.5 19.6 19.7 19.8 19.9 20.0 20.1 20.2 20.3 20.4 20.5 20.6 20.7 20.8 20.9 21.0 21.1 21.2 21.3 21.4 21.5 21.6 21.7 21.8 21.9 22.0 22.1 22.2 22.3 22.4 22.5 22.6 22.7 22.8 22.9 23.0 23.1 23.2 23.3 23.4 23.5 23.6 23.7 23.8 23.9 24.0 24.1 24.2 24.3 24.4 24.5 24.6 24.7 24.8 24.9 25.0 25.1 25.2 25.3 25.4 25.5 25.6 25.7 25.8 25.9 26.0 26.1 26.2 26.3 26.4 26.5 26.6 26.7 26.8 26.9 27.0 27.1 27.2 27.3 27.4 27.5 27.6 27.7 27.8 27.9 28.0 28.1 28.2 28.3 28.4 28.5 28.6 28.7 28.8 28.9 29.0 29.1 29.2 29.3 29.4 29.5 29.6 29.7 29.8 29.9 30.0]
#define WATER_FOAM_COLOR_R 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0]
#define WATER_FOAM_COLOR_G 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0]
#define WATER_FOAM_COLOR_B 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0]

// --- Player Water Foam ---
// Churning foam splash around the player when in/near water
#define WATER_PLAYER_FOAM_ENABLED
#define WATER_PLAYER_FOAM_RADIUS 1.5 // [0.5 0.75 1.0 1.5 2.0 2.5 3.0]
#define WATER_PLAYER_FOAM_INTENSITY 0.6 // [0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

// --- Water Opacity ---
// Water opacity for all chunks (0 = transparent, 1 = solid)
#define WATER_OPACITY 0.35 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

// --- Swamp Snake Light ---
// Bioluminescent snake-like light swimming under swamp water
#define SWAMP_SNAKE_LIGHT_ENABLED // [On] [Off]

// --- Water Blur ---
// Distance (blocks) where chunk water starts blurring into LOD water
#define WATER_BLUR_START 50.0 // [16.0 24.0 32.0 40.0 50.0 64.0 80.0 96.0 112.0 128.0 160.0 192.0 256.0]

// Distance (blocks) where chunk water blur reaches full strength
#define WATER_BLUR_END 160.0 // [48.0 64.0 80.0 96.0 112.0 128.0 160.0 192.0 256.0 320.0 384.0 512.0]


// ----------------------------------------------------------------------------
//   Water Reflections (ILV-style)
// ----------------------------------------------------------------------------

// Enable water reflections (screen-space reflections)
#define WATER_REFLECTIONS_ENABLED

// Debug mode - makes water pink to verify detection
//#define WATER_REFLECTION_DEBUG

// ILV Reflection Settings
// SSR ray march steps — more = reflects farther objects, costs more GPU. If distant terrain
// only reflects when near screen edges, increase this.
#define REFLECTION_ITERATIONS 150 // [20 30 40 50 60 80 100 150 200 300 400 500]
#define REFLECTION_DITHER_AMOUNT 0.25 // [0.0 0.25 0.5 0.75 1.0]
#define REFLECTION_FRESNEL 0.5 // [0.0 0.25 0.5 0.75 1.0]

// Water reflection strength (how reflective water is)
#define WATER_REFLECTION_AMOUNT 0.70 // [0.10 0.20 0.30 0.35 0.40 0.50 0.60 0.70 0.80 0.90 1.00]

#define WATER_SKY_REFLECTION 1.0 // [0.00 0.20 0.40 0.60 0.70 0.80 0.90 1.00]

// Sky reflection brightness during the day
#define WATER_SKY_BRIGHTNESS_DAY 7.50 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 2.50 3.00 4.00 5.00 7.50 10.00]

// Sky reflection brightness during the night
#define WATER_SKY_BRIGHTNESS_NIGHT 7.50 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 2.50 3.00 4.00 5.00 7.50 10.00]

// SSR (terrain) reflection brightness during the day
#define WATER_REFLECTION_BRIGHTNESS_DAY 3.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 2.50 3.00 4.00 5.00 7.50 10.00]

// SSR (terrain) reflection brightness during the night
#define WATER_REFLECTION_BRIGHTNESS_NIGHT 7.50 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 2.50 3.00 4.00 5.00 7.50 10.00]

// Max distance (blocks) for screen-space reflections. Beyond this, water uses sky reflection only.
#define SSR_RENDER_DISTANCE 20480 // [32 48 64 96 128 192 256 384 512 768 1024 1536 2048 3072 4096 6144 8192 12288 16384 20480]

// Wave distortion on water reflections
#define WATER_WAVES_ENABLED
#define WATER_WAVE_SCALE 0.20 // [0.10 0.20 0.30 0.40 0.50 0.60 0.80 1.00 1.50 2.00 3.00 4.00 5.00]
#define WATER_WAVE_SPEED 0.8 // [0.4 0.6 0.8 1.0 1.2 1.5 2.0 3.0 4.0]
#define WATER_WAVE_STRENGTH 0.60 // [0.05 0.10 0.15 0.20 0.25 0.30 0.40 0.50 0.60 0.80 1.00]

// Ocean wave parameters (exp-sin octave system, ocean biome only)
#define OCEAN_WAVE_DRAG 0.38 // [0.0 0.1 0.2 0.3 0.38 0.5 0.7 1.0]
#define OCEAN_WAVE_ITERS 8 // [4 6 8 10 12]
#define OCEAN_WAVE_ITERS_FAST 5 // [3 4 5 6 8]
#define OCEAN_WAVE_ITERS_NORMAL 36 // [12 18 24 30 36 48]

// How much to blur water SSR reflections (pixel radius). 0 = sharp.
#define WATER_REFLECTION_BLUR 3.0 // [0.0 1.0 2.0 3.0 4.0 5.0 6.0 8.0 10.0 12.0 16.0]

// ----------------------------------------------------------------------------
//   Material Reflections (SSR on polished/smooth/glazed blocks)
// ----------------------------------------------------------------------------
#define MATERIAL_REFLECTIONS_ENABLED
#define MATERIAL_REFLECTION_AMOUNT 0.80// [0.05 0.10 0.15 0.20 0.25 0.30 0.40 0.50 0.60 0.70 0.80]

// Fresnel strength (edge reflection boost)
#define MATERIAL_REFLECTION_FRESNEL 0.6// [0.0 0.2 0.4 0.6 0.8 1.0]

// ============================================================================
// =====                    ANIMATION                                     =====
// ============================================================================

// ----------------------------------------------------------------------------
//   Waving Foliage
// ----------------------------------------------------------------------------

// Enable when using a 3D grass resource pack. When OFF, grass_block behaves
// like a normal solid block: casts/receives shadows, has outlines, face shading.
#define GRASS_3D_RP_MODE

// Enable waving plants
#define WAVING_PLANTS

// Enable waving leaves
#define WAVING_LEAVES

// Waving style: 0 = Photon-style, 1 = Custom
#define WAVING_STYLE 1 // [0 1]

// Enable player plant interaction
#define PLAYER_PLANT_INTERACTION

// Enable swaying lanterns
#define SWAYING_LANTERNS

// --- General Waving ---
// Global waving speed
#define WAVING_SPEED 0.50// [0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.75 2.00 2.50 3.00]

// Global waving intensity
#define WAVING_INTENSITY 1.30// [0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.75 2.00 2.50 3.00]

// --- Grass Specific ---
// Grass waving speed multiplier
#define GRASS_WAVING_SPEED 1.0// [0.25 0.50 0.75 1.00 1.25 1.35 1.50 1.75 2.00 2.25 2.50 3.00]

// Grass waving intensity multiplier
#define GRASS_WAVING_INTENSITY 1.8// [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 3.00]

// --- Lantern Sway ---
// Lantern sway speed
#define LANTERN_SWAY_SPEED 1.5// [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00]

// Lantern sway intensity
#define LANTERN_SWAY_INTENSITY 1.8// [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00]

// --- Distance Boost ---
// Maximum distance boost multiplier
#define WAVING_DISTANCE_BOOST_MAX 4.0// [1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.50 4.00]

// Distance boost start (blocks)
#define WAVING_DISTANCE_BOOST_START 24 // [0.0 8.0 16.0 24.0 32.0 48.0 64.0 80.0 96.0]

// Distance boost end (blocks)
#define WAVING_DISTANCE_BOOST_END 320// [64.0 80.0 96.0 112.0 128.0 160.0 192.0 224.0 256.0 320.0]

// --- Player Interaction ---
// General interaction intensity
#define PLAYER_INTERACTION_INTENSITY 1.5// [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00]

// Grass interaction intensity
#define GRASS_INTERACTION_INTENSITY 2.2// [0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 3.00]

// Grass interaction radius (blocks)
#define GRASS_INTERACTION_RADIUS 4.0// [1.00 1.50 2.00 2.50 2.75 3.00 3.50 4.00 5.00]

