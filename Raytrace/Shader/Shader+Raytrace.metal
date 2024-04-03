// tomocy

#include "Shader+Frame.h"
#include "Shader+Geometry.h"
#include "Shader+Math.h"
#include "Shader+Mesh.h"
#include "Shader+PBR.h"
#include "Shader+Primitive.h"
#include "Shader+Random.h"
#include "Shader+Sample.h"
#include <metal_stdlib>

namespace Raytrace {
struct Context {
public:
    Frame frame;
};
}

namespace Raytrace {
float3 skyColorFor(const float3 direction)
{
    constexpr auto deep = float3(0, 0.5, 0.95);
    constexpr auto shallow = float3(0.25, 0.5, 0.9);

    const auto alpha = direction.y * 0.5 + 0.5;

    return interpolate(shallow, deep, alpha);
}

// Returns the Light = Emissive + Reflection.
float3 trace(
    constant Context& context,
    const uint32_t seed,
    const metal::raytracing::ray ray,
    const metal::raytracing::instance_acceleration_structure accelerator,
    constant Primitive::Instance* instances,
    constant Mesh* meshes,
    const uint32_t bounceCount
)
{
    namespace raytracing = metal::raytracing;

    // If rays hit nothing, there is no emissive nor reflection.
    if (bounceCount >= 3) {
        return { 0 };
    }

    // We know the directional light for now.
    const struct {
        float3 direction;
        float3 intensity;
    } directionalLight = {
        .direction = metal::normalize(float3(-1, -1, 1)),
        .intensity = float3(1, 1, 1),
    };

    using Intersector = typename raytracing::intersector<raytracing::instancing, raytracing::triangle_data>;
    const auto intersector = Intersector();

    const uint32_t mask = 0xff;
    const auto intersection = intersector.intersect(ray, accelerator, mask);

    if (intersection.type == raytracing::intersection_type::none) {
        if (bounceCount == 0) {
            return skyColorFor(ray.direction) * M_PI_F;
        }

        return {
            // Multiply PI to un-normalize this intensity.
            directionalLight.intensity * M_PI_F,
        };
    }

    const auto primitive = Primitive::Primitive::from(
        *(const device Primitive::Triangle*)intersection.primitive_data,
        intersection.triangle_barycentric_coord
    );

    auto color = float3(1);

    const auto instance = instances[intersection.instance_id];
    const auto mesh = meshes[instance.meshID];
    const auto piece = mesh.pieces[intersection.geometry_id];

    const auto albedo = piece.material.albedoAt(primitive.textureCoordinate);

    const auto dotNL = metal::saturate(
        metal::dot(
            primitive.normal,
            -directionalLight.direction
        )
    );

    {
        const auto diffuse = PBR::Lambertian::compute(albedo.rgb);
        color *= diffuse * dotNL;

        {
            const auto random = float2(
                Random::Halton::generate(2 + bounceCount * 5 + 3, seed + context.frame.id),
                Random::Halton::generate(2 + bounceCount * 5 + 4, seed + context.frame.id)
            );

            const float3 direction = Geometry::alignAsUp(
                Sample::CosineWeightedHemisphere::sample(random),
                primitive.normal
            );

            const auto incidentRay = raytracing::ray(
                ray.origin + ray.direction * intersection.distance,
                direction,
                1e-3, // To avoid an intersection with the same primitive again.
                ray.max_distance
            );

            color *= trace(context, seed, incidentRay, accelerator, instances, meshes, bounceCount + 1);
        }
    }

    return color;
}

kernel void kernelMain(
    const uint2 id [[thread_position_in_grid]],
    const metal::texture2d<float, metal::access::write> target [[texture(0)]],
    const metal::texture2d<uint32_t> seeds [[texture(1)]],
    constant Context& context [[buffer(0)]],
    const metal::raytracing::instance_acceleration_structure accelerator [[buffer(1)]],
    constant Primitive::Instance* instances [[buffer(2)]],
    constant Mesh* meshes [[buffer(3)]]
)
{
    namespace raytracing = metal::raytracing;

    // We know size of the target texture for now.
    const struct {
        float width;
        float height;
    } size = {
        .width = 1600,
        .height = 1200,
    };

    // We know the camera for now.
    const struct {
        float3 forward;
        float3 right;
        float3 up;
        float3 position;
    } camera = {
        .forward = float3(0, 0, 1),
        .right = float3(1, 0, 0),
        .up = float3(0, 1, 0),
        .position = float3(0, 0.5, -2),
    };

    const auto seed = seeds.read(id).r;

    // Map Screen (0...width, 0...height) to UV (0...1, 0...1),
    // then UV to NDC (-1...1, 1...-1).
    const auto inScreen = id;
    const auto inUV = float2(inScreen) / float2(size.width, size.height);
    const auto inNDC = float2(inUV.x * 2 - 1, inUV.y * -2 + 1);

    const auto ray = raytracing::ray(
        camera.position,
        metal::normalize(
            Geometry::alignAs(float3(inNDC, 1), camera.forward, camera.right, camera.up)
        )
    );

    const auto color = trace(
        context,
        seed,
        ray,
        accelerator,
        instances,
        meshes,
        0
    );

    target.write(float4(color, 1), inScreen);
}
}
