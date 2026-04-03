#ifndef INCLUDE_BIOME_OVERRIDES_GLSL
#define INCLUDE_BIOME_OVERRIDES_GLSL

bool isForcedDesertBiome(int b) {
bool m = false;
#ifdef BIOME_DESERT
m = m || (b == BIOME_DESERT);
#endif
#ifdef BIOME_BADLANDS
m = m || (b == BIOME_BADLANDS);
#endif
#ifdef BIOME_ERODED_BADLANDS
m = m || (b == BIOME_ERODED_BADLANDS);
#endif
#ifdef BIOME_WOODED_BADLANDS
m = m || (b == BIOME_WOODED_BADLANDS);
#endif
return m;
}

bool isForcedSwampyBiome(int b) {
bool m = false;
#ifdef BIOME_SWAMP
m = m || (b == BIOME_SWAMP);
#endif
#ifdef BIOME_MANGROVE_SWAMP
m = m || (b == BIOME_MANGROVE_SWAMP);
#endif
return m;
}

bool isForcedJungleBiome(int b) {
bool m = false;
#ifdef BIOME_JUNGLE
m = m || (b == BIOME_JUNGLE);
#endif
#ifdef BIOME_BAMBOO_JUNGLE
m = m || (b == BIOME_BAMBOO_JUNGLE);
#endif
#ifdef BIOME_SPARSE_JUNGLE
m = m || (b == BIOME_SPARSE_JUNGLE);
#endif
return m;
}

bool isForcedSavannaBiome(int b) {
bool m = false;
#ifdef BIOME_SAVANNA
m = m || (b == BIOME_SAVANNA);
#endif
#ifdef BIOME_SAVANNA_PLATEAU
m = m || (b == BIOME_SAVANNA_PLATEAU);
#endif
#ifdef BIOME_WINDSWEPT_SAVANNA
m = m || (b == BIOME_WINDSWEPT_SAVANNA);
#endif
return m;
}

bool isForcedSnowyBiome(int b) {
bool m = false;
#ifdef BIOME_SNOWY_PLAINS
m = m || (b == BIOME_SNOWY_PLAINS);
#endif
#ifdef BIOME_SNOWY_TAIGA
m = m || (b == BIOME_SNOWY_TAIGA);
#endif
#ifdef BIOME_SNOWY_BEACH
m = m || (b == BIOME_SNOWY_BEACH);
#endif
#ifdef BIOME_SNOWY_SLOPES
m = m || (b == BIOME_SNOWY_SLOPES);
#endif
#ifdef BIOME_FROZEN_RIVER
m = m || (b == BIOME_FROZEN_RIVER);
#endif
#ifdef BIOME_FROZEN_OCEAN
m = m || (b == BIOME_FROZEN_OCEAN);
#endif
#ifdef BIOME_FROZEN_PEAKS
m = m || (b == BIOME_FROZEN_PEAKS);
#endif
#ifdef BIOME_ICE_SPIKES
m = m || (b == BIOME_ICE_SPIKES);
#endif
#ifdef BIOME_GROVE
m = m || (b == BIOME_GROVE);
#endif
return m;
}

bool isForcedNetherBiome(int b) {
bool m = false;
#ifdef BIOME_NETHER_WASTES
m = m || (b == BIOME_NETHER_WASTES);
#endif
#ifdef BIOME_CRIMSON_FOREST
m = m || (b == BIOME_CRIMSON_FOREST);
#endif
#ifdef BIOME_WARPED_FOREST
m = m || (b == BIOME_WARPED_FOREST);
#endif
#ifdef BIOME_SOUL_SAND_VALLEY
m = m || (b == BIOME_SOUL_SAND_VALLEY);
#endif
#ifdef BIOME_BASALT_DELTAS
m = m || (b == BIOME_BASALT_DELTAS);
#endif
return m;
}

bool isForcedEndBiome(int b) {
bool m = false;
#ifdef BIOME_THE_END
m = m || (b == BIOME_THE_END);
#endif
#ifdef BIOME_END_BARRENS
m = m || (b == BIOME_END_BARRENS);
#endif
#ifdef BIOME_END_HIGHLANDS
m = m || (b == BIOME_END_HIGHLANDS);
#endif
#ifdef BIOME_END_MIDLANDS
m = m || (b == BIOME_END_MIDLANDS);
#endif
#ifdef BIOME_SMALL_END_ISLANDS
m = m || (b == BIOME_SMALL_END_ISLANDS);
#endif
return m;
}

bool isCategoryDesert(int c) {

bool m = (c == 12) || (c == 4);
#ifdef CAT_DESERT
m = m || (c == CAT_DESERT);
#endif
#ifdef CAT_BADLANDS
m = m || (c == CAT_BADLANDS);
#endif
return m;
}

bool isCategorySwampy(int c) {

bool m = (c == 14);
#ifdef CAT_SWAMP
m = m || (c == CAT_SWAMP);
#endif
return m;
}

bool isCategoryJungle(int c) {

bool m = (c == 3);
#ifdef CAT_JUNGLE
m = m || (c == CAT_JUNGLE);
#endif
return m;
}

bool isCategorySnowy(int c) {

bool m = (c == 7);
#ifdef CAT_ICY
m = m || (c == CAT_ICY);
#endif
#ifdef CAT_SNOWY
m = m || (c == CAT_SNOWY);
#endif
return m;
}

bool isCategorySavanna(int c) {

bool m = (c == 6);
#ifdef CAT_SAVANNA
m = m || (c == CAT_SAVANNA);
#endif
return m;
}

vec3 getForcedBiomeFogColor(int biomeId, vec3 fallbackFog) {

#ifdef END_FOG_ENABLED
if (isForcedEndBiome(biomeId)) return vec3(END_FOG_R, END_FOG_G, END_FOG_B);
#endif

#ifdef BIOME_CRIMSON_FOREST
if (biomeId == BIOME_CRIMSON_FOREST) return vec3(0.75, 0.12, 0.08);
#endif
#ifdef BIOME_BASALT_DELTAS
if (biomeId == BIOME_BASALT_DELTAS) return vec3(0.38, 0.38, 0.40);
#endif
#if defined(BIOME_WARPED_FOREST) || defined(BIOME_SOUL_SAND_VALLEY)
#ifdef BIOME_WARPED_FOREST
if (biomeId == BIOME_WARPED_FOREST) return vec3(0.09, 0.83, 1.00);
#endif
#ifdef BIOME_SOUL_SAND_VALLEY
if (biomeId == BIOME_SOUL_SAND_VALLEY) return vec3(0.10, 0.72, 0.76);
#endif
#endif

if (isForcedNetherBiome(biomeId)) return fallbackFog;

if (isForcedSnowyBiome(biomeId)) return vec3(0.92, 0.94, 0.96);
if (isForcedDesertBiome(biomeId)) return vec3(235.0, 213.0, 185.0) / 255.0;
if (isForcedSwampyBiome(biomeId)) return vec3(0.32, 0.42, 0.28);
if (isForcedJungleBiome(biomeId)) return vec3(0.36, 0.62, 0.28);
return fallbackFog;
}

vec3 getForcedBiomeSkyColor(int biomeId, vec3 fallbackSky) {
#ifdef END_SKY_ENABLED
if (isForcedEndBiome(biomeId)) return vec3(END_SKY_ZENITH_R, END_SKY_ZENITH_G, END_SKY_ZENITH_B);
#endif
if (isForcedSnowyBiome(biomeId)) return vec3(0.85, 0.90, 0.98);
if (isForcedDesertBiome(biomeId)) return vec3(191.0, 198.0, 255.0) / 255.0;
if (isForcedSavannaBiome(biomeId)) return vec3(191.0, 198.0, 255.0) / 255.0;
if (isForcedSwampyBiome(biomeId)) return vec3(0.45, 0.55, 0.42);
if (isForcedJungleBiome(biomeId)) return vec3(0.28, 0.56, 0.24);

return fallbackSky;
}

vec3 getForcedBiomeFogColorCat(int biomeId, int biomeCategory, vec3 fallbackFog) {

if (isForcedSnowyBiome(biomeId) || isCategorySnowy(biomeCategory)) return vec3(0.92, 0.94, 0.96);
if (isForcedJungleBiome(biomeId) || isCategoryJungle(biomeCategory)) return vec3(81.0, 189.0, 92.0) / 255.0;
if (isForcedSwampyBiome(biomeId) || isCategorySwampy(biomeCategory)) return vec3(66.0, 128.0, 75.0) / 255.0;
if (isForcedSavannaBiome(biomeId) || isCategorySavanna(biomeCategory) || isForcedDesertBiome(biomeId) || isCategoryDesert(biomeCategory)) {

return vec3(235.0, 213.0, 185.0) / 255.0;
}
return fallbackFog;
}

vec3 getForcedBiomeSkyColorCat(int biomeId, int biomeCategory, vec3 fallbackSky) {

if (isForcedSnowyBiome(biomeId) || isCategorySnowy(biomeCategory)) return vec3(0.75, 0.85, 0.95);
if (isForcedJungleBiome(biomeId) || isCategoryJungle(biomeCategory)) return vec3(122.0, 211.0, 255.0) / 255.0;
if (isForcedSwampyBiome(biomeId) || isCategorySwampy(biomeCategory)) return vec3(144.0, 199.0, 90.0) / 255.0;
if (isForcedSavannaBiome(biomeId) || isCategorySavanna(biomeCategory) || isForcedDesertBiome(biomeId) || isCategoryDesert(biomeCategory)) {
return vec3(191.0, 198.0, 255.0) / 255.0;
}
return fallbackSky;
}

vec3 getForcedBiomeSkyHorizonCat(int biomeId, int biomeCategory, vec3 fallbackHorizon) {
if (isForcedSnowyBiome(biomeId) || isCategorySnowy(biomeCategory)) return vec3(0.92, 0.94, 0.96);
if (isForcedJungleBiome(biomeId) || isCategoryJungle(biomeCategory)) return vec3(81.0, 189.0, 92.0) / 255.0;
if (isForcedSwampyBiome(biomeId) || isCategorySwampy(biomeCategory)) return vec3(66.0, 128.0, 75.0) / 255.0;

if (isForcedSavannaBiome(biomeId) || isCategorySavanna(biomeCategory) || isForcedDesertBiome(biomeId) || isCategoryDesert(biomeCategory)) {
return vec3(235.0, 213.0, 185.0) / 255.0;
}
return fallbackHorizon;
}

vec3 getForcedBiomeSkyMidCat(int biomeId, int biomeCategory, vec3 fallbackMid) {
if (isForcedSnowyBiome(biomeId) || isCategorySnowy(biomeCategory)) return vec3(0.92, 0.94, 0.98);
if (isForcedJungleBiome(biomeId) || isCategoryJungle(biomeCategory)) return vec3(154.0, 194.0, 110.0) / 255.0;

if (isForcedSwampyBiome(biomeId) || isCategorySwampy(biomeCategory)) return vec3(83.0, 77.0, 102.0) / 255.0;
if (isForcedSavannaBiome(biomeId) || isCategorySavanna(biomeCategory) || isForcedDesertBiome(biomeId) || isCategoryDesert(biomeCategory)) {
return vec3(214.0, 206.0, 224.0) / 255.0;
}
return fallbackMid;
}

vec3 getForcedBiomeSkyZenithCat(int biomeId, int biomeCategory, vec3 fallbackZenith) {
if (isForcedSnowyBiome(biomeId) || isCategorySnowy(biomeCategory)) return vec3(0.75, 0.85, 0.95);
if (isForcedJungleBiome(biomeId) || isCategoryJungle(biomeCategory)) return vec3(122.0, 211.0, 255.0) / 255.0;
if (isForcedSwampyBiome(biomeId) || isCategorySwampy(biomeCategory)) return vec3(144.0, 199.0, 90.0) / 255.0;
if (isForcedSavannaBiome(biomeId) || isCategorySavanna(biomeCategory) || isForcedDesertBiome(biomeId) || isCategoryDesert(biomeCategory)) {
return vec3(191.0, 198.0, 255.0) / 255.0;
}
return fallbackZenith;
}

vec3 getSmoothBiomeFogColor(vec3 defaultFog, float wSnowy, float wJungle, float wSwamp, float wArid) {
vec3 result = defaultFog;
if (wSnowy  > 0.001) result = mix(result, vec3(0.92, 0.94, 0.96), wSnowy);
if (wJungle > 0.001) result = mix(result, vec3(81.0, 189.0, 92.0) / 255.0,  wJungle);
if (wSwamp  > 0.001) result = mix(result, vec3(66.0, 128.0, 75.0) / 255.0,  wSwamp);
if (wArid   > 0.001) result = mix(result, vec3(235.0, 213.0, 185.0) / 255.0, wArid);
return result;
}

vec3 getSmoothBiomeSkyZenith(vec3 defaultZenith, float wSnowy, float wJungle, float wSwamp, float wArid) {
vec3 result = defaultZenith;
if (wSnowy  > 0.001) result = mix(result, vec3(0.75, 0.85, 0.95), wSnowy);
if (wJungle > 0.001) result = mix(result, vec3(122.0, 211.0, 255.0) / 255.0, wJungle);
if (wSwamp  > 0.001) result = mix(result, vec3(144.0, 199.0, 90.0) / 255.0,  wSwamp);
if (wArid   > 0.001) result = mix(result, vec3(191.0, 198.0, 255.0) / 255.0, wArid);
return result;
}

vec3 getSmoothBiomeSkyHorizon(vec3 defaultHorizon, float wSnowy, float wJungle, float wSwamp, float wArid) {
vec3 result = defaultHorizon;
if (wSnowy  > 0.001) result = mix(result, vec3(0.92, 0.94, 0.96), wSnowy);
if (wJungle > 0.001) result = mix(result, vec3(81.0, 189.0, 92.0) / 255.0,  wJungle);
if (wSwamp  > 0.001) result = mix(result, vec3(66.0, 128.0, 75.0) / 255.0,  wSwamp);
if (wArid   > 0.001) result = mix(result, vec3(235.0, 213.0, 185.0) / 255.0, wArid);
return result;
}

vec3 getSmoothBiomeSkyMid(vec3 defaultMid, float wSnowy, float wJungle, float wSwamp, float wArid) {
vec3 result = defaultMid;
if (wSnowy  > 0.001) result = mix(result, vec3(0.92, 0.94, 0.98), wSnowy);
if (wJungle > 0.001) result = mix(result, vec3(154.0, 194.0, 110.0) / 255.0, wJungle);
if (wSwamp  > 0.001) result = mix(result, vec3(83.0, 77.0, 102.0) / 255.0,   wSwamp);
if (wArid   > 0.001) result = mix(result, vec3(214.0, 206.0, 224.0) / 255.0, wArid);
return result;
}

#endif
