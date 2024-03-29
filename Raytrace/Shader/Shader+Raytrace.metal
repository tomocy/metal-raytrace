// tomocy

#include <metal_stdlib>

namespace Raytrace {
kernel void kernelMain(
    const uint2 id [[thread_position_in_grid]],
    const metal::texture2d<float, metal::access::write> target [[texture(0)]],
    const metal::raytracing::primitive_acceleration_structure accelerator [[buffer(0)]],
    constant uint16_t* indices [[buffer(1)]],
    constant float2* textureCoordinates [[buffer(2)]],
    const metal::texture2d<float> albedoTexture [[texture(1)]]
)
{
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
    const auto inNDC = float2(inUV.x * 2 - 1, inUV.y * -2 + 1);

    raytracing::ray ray = {};
    ray.origin = float3(0, 0, -2); // We know the camera position for now.
    ray.direction = metal::normalize(inNDC.x * right + inNDC.y * up + forward);
    ray.max_distance = INFINITY;

    using Intersector = typename raytracing::intersector<raytracing::triangle_data>;
    const auto intersector = Intersector();

    using Intersection = typename Intersector::result_type;
    const Intersection intersection = intersector.intersect(ray, accelerator);

    if (intersection.type == raytracing::intersection_type::none) {
        target.write(float4(0, 0, 0, 1), inScreen);
        return;
    }

    constexpr auto sampler = metal::sampler(
        metal::min_filter::nearest,
        metal::mag_filter::nearest,
        metal::mip_filter::none
    );

    const auto primitiveID = intersection.primitive_id;
    const auto index0 = indices[primitiveID * 3 + 0];
    const auto index1 = indices[primitiveID * 3 + 1];
    const auto index2 = indices[primitiveID * 3 + 2];
    const auto centric = intersection.triangle_barycentric_coord;
    const auto coordinate0 = textureCoordinates[index0];
    const auto coordinate1 = textureCoordinates[index1];
    const auto coordinate2 = textureCoordinates[index2];
    auto coordinate = (1 - centric.x - centric.y) * coordinate0
        + centric.x * coordinate1
        + centric.y * coordinate2;
    coordinate.y = 1 - coordinate.y;

    const auto color = albedoTexture.sample(sampler, coordinate);
    target.write(color, inScreen);
}
}
