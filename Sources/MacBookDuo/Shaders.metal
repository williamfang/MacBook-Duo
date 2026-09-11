#include <metal_stdlib>
using namespace metal;

struct VertexOut { float4 position [[position]]; float2 uv; };
struct Uniforms { float progress; float blur; float darkness; float tint; float aspect; float verticalDifference; float perspective; };

vertex VertexOut foldVertex(uint id [[vertex_id]]) {
    float2 positions[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
    float2 uvs[3] = { float2(0,1), float2(2,1), float2(0,-1) };
    return { float4(positions[id], 0, 1), uvs[id] };
}

fragment float4 foldFragment(VertexOut in [[stage_in]],
                             texture2d<float> image [[texture(0)]],
                             constant Uniforms& u [[buffer(0)]]) {
    constexpr sampler s(min_filter::linear, mag_filter::linear,
                        mip_filter::linear, address::clamp_to_edge);
    float2 uv = in.uv;

    float2 sampleUV = uv;
    float panelMask = 0.0;
    if (u.perspective > 0.0001) {
        float verticalCompression = u.perspective * 0.90;
        float panelY = clamp((uv.y - verticalCompression) / (1.0 - verticalCompression), 0.0, 1.0);
        float topInset = u.perspective * 0.55;
        float halfWidth = mix(0.5 - topInset, 0.5, panelY);
        float leftEdge = 0.5 - halfWidth;
        float rightEdge = 0.5 + halfWidth;
        float feather = 0.006 + u.perspective * 0.025;

        float verticalMask = smoothstep(verticalCompression - feather, verticalCompression + feather, uv.y);
        float leftMask = smoothstep(leftEdge - feather, leftEdge + feather, uv.x);
        float rightMask = 1.0 - smoothstep(rightEdge - feather, rightEdge + feather, uv.x);
        panelMask = verticalMask * leftMask * rightMask;

        float2 warpedUV = float2(
            clamp((uv.x - leftEdge) / max(rightEdge - leftEdge, 0.001), 0.0, 1.0),
            panelY
        );
        sampleUV = mix(uv, warpedUV, panelMask);
    }

    float onset = smoothstep(0.0, 0.35, u.progress);
    float verticalStrength = mix(1.0, 1.0 - u.verticalDifference, smoothstep(0.0, 1.0, uv.y));
    float lod = u.blur * verticalStrength * onset;
    float2 texel = exp2(lod) / float2(image.get_width(), image.get_height()) * 0.55;
    float4 color = image.sample(s, sampleUV, level(lod)) * 0.40;
    color += image.sample(s, sampleUV + float2( texel.x,  texel.y), level(lod)) * 0.15;
    color += image.sample(s, sampleUV + float2(-texel.x,  texel.y), level(lod)) * 0.15;
    color += image.sample(s, sampleUV + float2( texel.x, -texel.y), level(lod)) * 0.15;
    color += image.sample(s, sampleUV + float2(-texel.x, -texel.y), level(lod)) * 0.15;

    color.rgb = mix(color.rgb, float3(0.48, 0.70, 0.88), u.tint);
    float blackBackground = smoothstep(0.0, 0.025, u.perspective);
    float panelVisibility = mix(1.0, panelMask, blackBackground);
    color.rgb *= panelVisibility;
    float blackoutConvergence = smoothstep(0.82, 1.0, u.progress);
    float localDarkness = u.darkness * mix(verticalStrength, 1.0, blackoutConvergence);
    color.rgb *= 1.0 - localDarkness;
    return float4(color.rgb, 1);
}
