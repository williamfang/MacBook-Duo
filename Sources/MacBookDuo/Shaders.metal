#include <metal_stdlib>
using namespace metal;

struct VertexOut { float4 position [[position]]; float2 uv; };
struct Uniforms { float progress; float blur; float darkness; float tint; float aspect; };

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

    // Keep every desktop pixel locked to the same screen coordinate. The physical
    // lid supplies the motion; software only changes the glass treatment.
    float2 sampleUV = uv;

    float coverage = smoothstep(-0.2, 0.2, u.progress - uv.y);
    float onset = smoothstep(0.0, 0.35, u.progress);
    float lod = u.blur * coverage * onset;
    float2 texel = exp2(lod) / float2(image.get_width(), image.get_height()) * 0.55;
    float4 color = image.sample(s, sampleUV, level(lod)) * 0.40;
    color += image.sample(s, sampleUV + float2( texel.x,  texel.y), level(lod)) * 0.15;
    color += image.sample(s, sampleUV + float2(-texel.x,  texel.y), level(lod)) * 0.15;
    color += image.sample(s, sampleUV + float2( texel.x, -texel.y), level(lod)) * 0.15;
    color += image.sample(s, sampleUV + float2(-texel.x, -texel.y), level(lod)) * 0.15;

    color.rgb = mix(color.rgb, float3(0.48, 0.70, 0.88), u.tint);
    float localDarkness = u.darkness * mix(0.15, 1.0, coverage);
    color.rgb *= 1.0 - localDarkness;
    return float4(color.rgb, 1);
}
