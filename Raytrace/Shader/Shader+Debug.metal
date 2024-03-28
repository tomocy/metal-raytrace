// tomocy

#include <metal_stdlib>

namespace Debug {
struct Vertex {
public:
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float3 textureCoordinate [[attribute(2)]];
};

struct Raster {
public:
    float4 position [[position]];
};
}

namespace Debug {
vertex Raster vertexMain(
    const Vertex v [[stage_in]],
    constant metal::float4x4& matrix [[buffer(3)]]
)
{
    return {
        .position = matrix * float4(v.position, 1),
    };
}
}
