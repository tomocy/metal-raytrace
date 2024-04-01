// tomocy

#include "Shader+Math.h"
#include "Shader+Mesh.h"
#include "Shader+Primitive.h"
#include <metal_stdlib>

namespace Raytrace {
float4 skyFor(const float3 direction) {
    constexpr auto deep = float4(0, 0.5, 0.95, 1);
    constexpr auto shallow = float4(0.25, 0.5, 0.9, 1);

    const auto alpha = direction.y * 0.5 + 0.5;

    return interpolate(shallow, deep, alpha);
}


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

    // We know the camera for now.
    const auto cameraUp = float3(0, 1, 0);
    const auto cameraForward = float3(0, 0, 1);
    const auto cameraRight = float3(1, 0, 0);
    const auto cameraPosition = float3(0, 0.5, -2);

    // We know the lights for now.
    const auto ambientLightIntensity = 0.1;
    const auto directionalLightDirection = metal::normalize(float3(-1, -1, 1));
    const auto directionalLightIntensity = 1;

    // Map Screen (0...width, 0...height) to UV (0...1, 0...1),
    // then UV to NDC (-1...1, 1...-1).
    const auto inScreen = id;
    const auto inUV = float2(inScreen) / float2(width, height);
    const auto inNDC = float2(inUV.x * 2 - 1, inUV.y * -2 + 1);

    raytracing::ray ray = {};
    ray.origin = cameraPosition;
    ray.direction = metal::normalize(inNDC.x * cameraRight + inNDC.y * cameraUp + cameraForward);
    ray.max_distance = INFINITY;

    using Intersector = typename raytracing::intersector<raytracing::instancing, raytracing::triangle_data>;
    const auto intersector = Intersector();

    float4 color = float4(0, 0, 0, 1);

    do {
        const uint32_t mask = 0xff;
        const auto intersection = intersector.intersect(ray, accelerator, mask);

        if (intersection.type == raytracing::intersection_type::none) {
            color = skyFor(ray.direction);
            break;
        }

        constexpr auto sampler = metal::sampler(
            metal::min_filter::nearest,
            metal::mag_filter::nearest,
            metal::mip_filter::none
        );

        const auto primitive = *(const device Primitive::Triangle*)intersection.primitive_data;

        const auto instance = instances[intersection.instance_id];
        const auto mesh = meshes[instance.meshID];
        const auto piece = mesh.pieces[intersection.geometry_id];

        const auto normal = metal::normalize(
            interpolate(
                primitive.normals[0],
                primitive.normals[1],
                primitive.normals[2],
                intersection.triangle_barycentric_coord
            )
        );
        auto textureCoordinate = interpolate(
            primitive.textureCoordinates[0],
            primitive.textureCoordinates[1],
            primitive.textureCoordinates[2],
            intersection.triangle_barycentric_coord
        );
        textureCoordinate.y = 1 - textureCoordinate.y;

        const auto albedo = piece.material.albedo.sample(sampler, textureCoordinate);

        float3 rgb = {};

        {
            rgb += albedo.rgb * ambientLightIntensity;
        }
        {
            const auto howDiffuse = metal::saturate(
                metal::dot(-directionalLightDirection, normal)
            );

            rgb += albedo.rgb * directionalLightIntensity * howDiffuse;
        }

        color = float4(rgb * albedo.a, albedo.a);
    } while (0);

    target.write(color, inScreen);
}
}
