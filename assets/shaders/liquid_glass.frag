#version 320 es
// Optical Liquid Glass lens refraction, edge dispersion, and specular rim shader.
// Designed for Flutter ImageFilter.shader inside BackdropFilter.

#include <flutter/runtime_effect.glsl>

// Required first uniform: bound backdrop texture dimensions in pixels.
uniform vec2 uSize;
// Rounded box corner radius in pixels.
uniform float uCornerRadius;
// Width of curved lens meniscus bezel in pixels.
uniform float uBezelWidth;
// Peak optical UV displacement at the curved perimeter in pixels.
uniform float uRefraction;
// Softness kernel radius in pixels.
uniform float uBlurRadius;
// Edge chromatic dispersion offset in pixels.
uniform float uChromatic;
// Specular rim & caustic highlight intensity (0..1).
uniform float uHighlight;
// Base translucent glass tint (linear sRGB + opacity).
uniform vec4 uTint;

// Required backdrop texture sampler.
uniform sampler2D uTexture;

out vec4 fragColor;

float sdRoundedBox(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - (halfSize - vec2(radius));
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

vec2 roundedBoxGradient(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - (halfSize - vec2(radius));
  vec2 signP = vec2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
  if (q.x > 0.0 && q.y > 0.0) {
    float len = max(length(q), 0.0001);
    return signP * (q / len);
  }
  if (q.x > q.y) {
    return vec2(signP.x, 0.0);
  }
  return vec2(0.0, signP.y);
}

vec2 toSamplerUv(vec2 normUv) {
  vec2 clamped = clamp(normUv, vec2(0.002), vec2(0.998));
  #ifdef IMPELLER_TARGET_OPENGLES
  clamped.y = 1.0 - clamped.y;
  #endif
  return clamped;
}

vec3 sampleBlurred(vec2 centerUv, vec2 texelStep, float blurPx) {
  if (blurPx <= 0.25) {
    return texture(uTexture, toSamplerUv(centerUv)).rgb;
  }
  vec2 r = texelStep * blurPx;
  vec3 acc = texture(uTexture, toSamplerUv(centerUv)).rgb * 0.28;
  acc += texture(uTexture, toSamplerUv(centerUv + vec2( r.x,  0.0))).rgb * 0.14;
  acc += texture(uTexture, toSamplerUv(centerUv + vec2(-r.x,  0.0))).rgb * 0.14;
  acc += texture(uTexture, toSamplerUv(centerUv + vec2( 0.0,  r.y))).rgb * 0.14;
  acc += texture(uTexture, toSamplerUv(centerUv + vec2( 0.0, -r.y))).rgb * 0.14;
  acc += texture(uTexture, toSamplerUv(centerUv + vec2( r.x * 0.7,  r.y * 0.7))).rgb * 0.04;
  acc += texture(uTexture, toSamplerUv(centerUv + vec2(-r.x * 0.7,  r.y * 0.7))).rgb * 0.04;
  acc += texture(uTexture, toSamplerUv(centerUv + vec2( r.x * 0.7, -r.y * 0.7))).rgb * 0.04;
  acc += texture(uTexture, toSamplerUv(centerUv + vec2(-r.x * 0.7, -r.y * 0.7))).rgb * 0.04;
  return acc;
}

void main() {
  vec2 safeSize = max(uSize, vec2(1.0));
  vec2 texel = vec2(1.0) / safeSize;
  vec2 uv = FlutterFragCoord().xy * texel;

  vec2 halfSize = safeSize * 0.5;
  vec2 localPos = (uv - 0.5) * safeSize;
  float maxRadius = min(halfSize.x, halfSize.y);
  float radius = clamp(uCornerRadius, 0.0, maxRadius);
  float bezel = clamp(uBezelWidth, 2.0, max(maxRadius, 2.0));

  float dist = sdRoundedBox(localPos, halfSize, radius);
  vec2 outNormal = roundedBoxGradient(localPos, halfSize, radius);

  // Positive distance inward from the glass boundary.
  float edgeDist = max(-dist, 0.0);
  float t = clamp(edgeDist / bezel, 0.0, 1.0);
  // Meniscus dome steepness: strongest refraction near rim, smoothly flat inside.
  float edgeBend = pow(1.0 - t, 2.15);

  // Pull background radially into the curved bezel + gentle center magnification.
  vec2 centerMagnify = -(uv - 0.5) * (0.022 * (1.0 - edgeBend * 0.4));
  vec2 bezelRefract = -outNormal * (edgeBend * uRefraction) * texel;
  vec2 refractedUv = uv + bezelRefract + centerMagnify;

  // Prismatic chromatic dispersion strongest along curved edge.
  vec2 dispShift = outNormal * (edgeBend * uChromatic) * texel;
  float effectiveBlur = uBlurRadius * mix(0.65, 1.15, edgeBend);

  float rChan = sampleBlurred(refractedUv + dispShift, texel, effectiveBlur).r;
  float gChan = sampleBlurred(refractedUv, texel, effectiveBlur).g;
  float bChan = sampleBlurred(refractedUv - dispShift, texel, effectiveBlur).b;
  vec3 refractedColor = vec3(rChan, gChan, bChan);

  // Blend subtle translucent glass body tint without turning milky opaque.
  vec3 glassColor = mix(refractedColor, uTint.rgb, clamp(uTint.a, 0.0, 0.92));

  // Studio top-left specular highlight and opposite caustic rim bounce.
  vec2 lightDir = normalize(vec2(-0.56, -0.83));
  float rimFactor = 1.0 - smoothstep(0.0, max(bezel * 0.42, 2.5), edgeDist);
  float hairRim = 1.0 - smoothstep(0.0, 2.4, edgeDist);
  float primarySpec = pow(max(dot(-outNormal, lightDir), 0.0), 2.3);
  float bounceSpec = pow(max(dot(outNormal, lightDir), 0.0), 3.0) * 0.42;

  float rimGlow =
      (rimFactor * (0.30 + 0.70 * (primarySpec + bounceSpec)) +
          hairRim * 0.48) *
      clamp(uHighlight, 0.0, 1.5);

  // Subtle top sheen across glass interior.
  float topSheen = (1.0 - uv.y) * 0.045 * clamp(uHighlight, 0.0, 1.2);
  glassColor += vec3(rimGlow + topSheen);

  fragColor = vec4(clamp(glassColor, 0.0, 1.0), 1.0);
}
