// tomocy

#include <metal_stdlib>

namespace Copy {
struct Raster {
public:
    struct Positions {
        float4 inClip [[position]];
        float2 inUV;
    };

public:
    Positions position;
};
}

namespace Copy {
vertex Raster vertexMain(
    constant float2* vertices [[buffer(0)]],
    const ushort id [[vertex_id]]
) {
    const auto inNDC = vertices[id];
    const auto inClip = float4(inNDC, 0, 1);
    const auto inUV = inNDC * 0.5 + 0.5;

    return {
        .position = {
            .inClip = inClip,
            .inUV = inUV,
        },
    };
}

fragment float4 fragmentMain(const Raster r [[stage_in]], const metal::texture2d<float> source) {
    constexpr auto sampler = metal::sampler(
        metal::min_filter::nearest,
        metal::mag_filter::nearest,
        metal::mip_filter::none
    );

    return source.sample(sampler, r.position.inUV);
}
}
