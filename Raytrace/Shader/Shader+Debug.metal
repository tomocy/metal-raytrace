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
    constant metal::float4x4& matrix [[buffer(1)]]
)
{
    return {
        .position = matrix * float4(v.position, 1),
    };
}
}
