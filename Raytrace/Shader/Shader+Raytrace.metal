// tomocy

#include <metal_stdlib>

namespace Raytrace {
kernel void compute(
    const uint2 id [[thread_position_in_grid]],
    const metal::texture2d<float, metal::access::write> target [[texture(0)]],
    const metal::raytracing::primitive_acceleration_structure accelerator [[buffer(0)]]
) {
    namespace raytracing = metal::raytracing;

    // We know size of the target texture for now.
    const float width = 1600;
    const float height = 1200;

    const auto up = float3(0, 1, 0);
    const auto forward = float3(0, 0, 1);
    const auto right = float3(1, 0, 0);

    // Map Screen (0...width, 0...height) to UV (0...1, 0...1),
    // then UV to NDC (-1...1, 1...-1).
    const auto inScreen = id;
    const auto inUV = float2(inScreen) / float2(width, height);
    const auto inNDC = float2(
        inUV.x * 2 - 1,
        inUV.y * -2 + 1
    );

    raytracing::ray ray = {};
    ray.origin = float3(0, 0, -1); // We know the camera position for now.
    ray.direction = metal::normalize(inNDC.x * right + inNDC.y * up + forward);
    ray.max_distance = INFINITY;

    using Intersector = typename raytracing::intersector<raytracing::triangle_data>;
    const auto intersector = Intersector();

    using Intersection = typename Intersector::result_type;
    const Intersection intersection = intersector.intersect(ray, accelerator);

    const auto color = intersection.type != raytracing::intersection_type::none
        ? float4(0.98, 0.72, 0.4, 1)
        : float4(0, 0, 0, 1);

    target.write(color, inScreen);
}
}
