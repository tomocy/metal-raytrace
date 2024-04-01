// tomocy

#include "Shader+Mesh.h"
#include "Shader+Primitive.h"
#include <metal_stdlib>

namespace Raytrace {
kernel void kernelMain(
    const uint2 id [[thread_position_in_grid]],
    const metal::texture2d<float, metal::access::write> target [[texture(0)]],
    const metal::raytracing::instance_acceleration_structure accelerator [[buffer(0)]],
    constant Primitive::Instance* instances [[buffer(1)]],
    constant Mesh* meshes [[buffer(2)]]
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
    ray.origin = float3(0, 0.5, -2); // We know the camera position for now.
    ray.direction = metal::normalize(inNDC.x * right + inNDC.y * up + forward);
    ray.max_distance = INFINITY;

    using Intersector = typename raytracing::intersector<raytracing::instancing, raytracing::triangle_data>;
    using Intersection = typename Intersector::result_type;

    const auto intersector = Intersector();
    float4 color = float4(0, 0, 0, 1);

    for (int i = 0; i < 1; i++) {
        const uint32_t mask = 0xff;
        const Intersection intersection = intersector.intersect(ray, accelerator, mask);

        if (intersection.type == raytracing::intersection_type::none) {
            color = float4(0, 0.5, 0.95, 1);
            break;
        }

        constexpr auto sampler = metal::sampler(
            metal::min_filter::nearest,
            metal::mag_filter::nearest,
            metal::mip_filter::none
        );

        const auto primitive = *(const device Primitive::Triangle*)intersection.primitive_data;
        const auto centric = intersection.triangle_barycentric_coord;
        auto coordinate = (1 - centric.x - centric.y) * primitive.textureCoordinates[0]
            + centric.x * primitive.textureCoordinates[1]
            + centric.y * primitive.textureCoordinates[2];
        coordinate.y = 1 - coordinate.y;

        const auto instance = instances[intersection.instance_id];
        const auto mesh = meshes[instance.meshID];
        const auto piece = mesh.pieces[intersection.geometry_id];

        color = piece.material.albedo.sample(sampler, coordinate);
    }

    target.write(color, inScreen);
}
}
