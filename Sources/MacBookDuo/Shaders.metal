#include <metal_stdlib>
using namespace metal;

struct VertexOut { float4 position [[position]]; float2 uv; };
struct Uniforms { float progress; float verticalScale; float blur; float darkness; float tint; float aspect; };

vertex VertexOut foldVertex(uint id [[vertex_id]]) {
    float2 positions[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
    float2 uvs[3] = { float2(0,1), float2(2,1), float2(0,-1) };
    return { float4(positions[id], 0, 1), uvs[id] };
}

fragment float4 foldFragment(VertexOut in [[stage_in]],
                             texture2d<float> image [[texture(0)]],
                             constant Uniforms& u [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = in.uv;

    // The bottom edge remains fixed while the upper edge falls toward the hinge.
    float projectedY = 1.0 - (1.0 - uv.y) / max(u.verticalScale, 0.035);
    float perspective = (1.0 - u.progress * 0.22) + u.progress * 0.22 * uv.y;
    float2 sampleUV = float2((uv.x - 0.5) / perspective + 0.5, projectedY);
    bool outside = sampleUV.y < 0.0 || sampleUV.y > 1.0 || sampleUV.x < 0.0 || sampleUV.x > 1.0;

    float2 texel = 1.0 / float2(image.get_width(), image.get_height());
    float radius = u.blur * (0.35 + 0.65 * (1.0 - uv.y));
    float2 dx = float2(texel.x * radius, 0);
    float2 dy = float2(0, texel.y * radius);
    float4 color = image.sample(s, sampleUV) * 0.28;
    color += image.sample(s, sampleUV + dx) * 0.12;
    color += image.sample(s, sampleUV - dx) * 0.12;
    color += image.sample(s, sampleUV + dy) * 0.12;
    color += image.sample(s, sampleUV - dy) * 0.12;
    color += image.sample(s, sampleUV + dx + dy) * 0.06;
    color += image.sample(s, sampleUV - dx - dy) * 0.06;
    color += image.sample(s, sampleUV + dx - dy) * 0.06;
    color += image.sample(s, sampleUV - dx + dy) * 0.06;

    float rim = pow(saturate(1.0 - abs(sampleUV.y - 0.04) * 14.0), 5.0) * u.progress;
    color.rgb = mix(color.rgb, float3(0.48, 0.70, 0.88), u.tint);
    color.rgb += rim * float3(0.32, 0.52, 0.68);
    color.rgb *= 1.0 - u.darkness;
    if (outside) color = float4(0, 0, 0, 1);
    return float4(color.rgb, 1);
}
