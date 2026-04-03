vec2 FogReprojection(vec2 uv, sampler2D depthTex) {
float depth = texture(depthTex, uv).r;
vec3 pos = vec3(uv, depth) * 2.0 - 1.0;

vec4 viewPos = gbufferProjectionInverse * vec4(pos, 1.0);
viewPos /= viewPos.w;
viewPos = gbufferModelViewInverse * viewPos;

vec3 cameraOffset = cameraPosition - previousCameraPosition;
cameraOffset *= float(depth < 0.9999);

vec4 prevPos = viewPos + vec4(cameraOffset, 0.0);
prevPos = gbufferPreviousModelView * prevPos;
prevPos = gbufferPreviousProjection * prevPos;
return prevPos.xy / prevPos.w * 0.5 + 0.5;
}

vec4 FogTemporalAccumulate(vec4 current, sampler2D historyTex, sampler2D depthTex, vec2 uv) {
vec2 prevUV = FogReprojection(uv, depthTex);

bool validHistory = prevUV.x > 0.0 && prevUV.x < 1.0 &&
prevUV.y > 0.0 && prevUV.y < 1.0;

if (!validHistory) return current;

vec4 history = texture(historyTex, prevUV);

if (history == vec4(0.0)) return current;

float maxC = max(current.r, max(current.g, current.b));
float minC = min(current.r, min(current.g, current.b));
float saturation = (maxC > 0.001) ? (maxC - minC) / maxC : 0.0;
float fogBrightness = maxC;

float brightnessReduce = smoothstep(0.1, 0.5, fogBrightness) * 0.55;
brightnessReduce *= 1.0 - smoothstep(0.3, 0.7, saturation);
float blend = mix(0.85 - brightnessReduce, 0.95, smoothstep(0.3, 0.7, saturation));

float depth = texture(depthTex, uv).r;

if (depth < 0.56) return current;

if (depth >= 0.9999) blend *= mix(0.5, 1.0, smoothstep(0.3, 0.7, saturation));

return mix(current, history, blend);
}

vec4 FogTemporalAccumulate(sampler2D currentTex, sampler2D historyTex, sampler2D depthTex, vec2 uv) {
return FogTemporalAccumulate(texture(currentTex, uv), historyTex, depthTex, uv);
}
