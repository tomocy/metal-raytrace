// tomocy

#include <metal_stdlib>

namespace Raytrace {
namespace Echo {
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
}

namespace Raytrace {
namespace Echo {
namespace Vertex {
vertex Raster compute(
    constant float2* vertices [[buffer(0)]],
    const ushort id [[vertex_id]]
)
{
    const auto inNDC = vertices[id];
    const auto inClip = float4(inNDC, 0, 1);

    // Map NDC (-1...1, -1...1) to UV (0...1, 1...0).
    const auto inUV = float2(
        inNDC.x * 0.5 + 0.5,
        -inNDC.y * 0.5 + 0.5
    );

    return {
        .position = {
            .inClip = inClip,
            .inUV = inUV,
        },
    };
}
}
}
}

namespace Raytrace {
namespace Echo {
namespace Fragment {
fragment float4 compute(const Raster r [[stage_in]], const metal::texture2d<float> source)
{
    constexpr auto sampler = metal::sampler(
        metal::min_filter::nearest,
        metal::mag_filter::nearest,
        metal::mip_filter::none
    );

    return source.sample(sampler, r.position.inUV);
}
}
}
}
