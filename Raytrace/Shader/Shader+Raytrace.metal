// tomocy

#include <metal_stdlib>

namespace Raytrace {
kernel void compute(
    const metal::texture2d<float, metal::access::write> target [[texture(0)]],
    const uint2 id [[thread_position_in_grid]]
) {
    // We know for now the size of the target texture.
    const float width = 1600;
    const float height = 1200;

    const auto coordinate = id;
    target.write(float4(float(id.x) / width, float(id.y) / height, 0.4, 1), coordinate);
}
}
