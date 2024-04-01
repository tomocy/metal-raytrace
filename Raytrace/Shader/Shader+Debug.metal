// tomocy

#include <metal_stdlib>

namespace Debug {
struct Vertex {
public:
    float3 position [[attribute(0)]];
};

struct Raster {
public:
    float4 position [[position]];
};
}

namespace Debug {
vertex Raster vertexMain(
    const Vertex v [[stage_in]],
    constant metal::float4x4& aspect [[buffer(1)]],
    constant metal::float4x4* instances [[buffer(2)]],
    const uint16_t id [[instance_id]]
)
{
    // const auto transform = instances[id];

    return {
        .position = aspect/* * transform */ * float4(v.position, 1),
    };
}
}
