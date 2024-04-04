// tomocy

#include "Shader+Frame.h"
#include "Shader+Geometry.h"
#include "Shader+Intersection.h"
#include "Shader+Math.h"
#include "Shader+Mesh.h"
#include "Shader+PBR.h"
#include "Shader+Primitive.h"
#include "Shader+Random.h"
#include "Shader+Sample.h"
#include <metal_stdlib>

namespace Raytrace {
struct Tracer {
public:
    float3 trace(const metal::raytracing::ray ray, const uint32_t bounceCount = 0) const
    {
        namespace raytracing = metal::raytracing;

        // If rays hit nothing, there is no emissive nor reflection.
        if (bounceCount >= 3) {
            return 0;
        }

        const auto intersection = intersector.intersectAlong(ray, 0xff);

        if (!intersection.has()) {
            auto color = backgroundColorFor(ray.direction);

            // Adhoc way to make the sky look blue.
            if (bounceCount == 0) {
                color /= directionalLight.color;
            }

            return color;
        }

        const Primitive primitive = intersection.to();
        const Mesh::Piece piece = *intersection.findIn(instances, meshes);

        struct {
            float3 normal;
            float3 light;
            float3 view;
            float3 halfway;
        } dirs = {
            .normal = primitive.normal,
            .light = -directionalLight.direction,
            .view = metal::normalize(view.position - intersection.positionWith(ray)),
        };
        dirs.halfway = metal::normalize(dirs.light + dirs.view);

        const auto dotNL = metal::clamp(
            metal::dot(dirs.normal, dirs.light),
            1e-3, 1.0
        );

        const auto metalness = piece.material.metalnessAt(primitive.textureCoordinate);

        struct {
            float4 raw;
            float3 diffuse;
            float3 specular;
        } albedo = {
            .raw = piece.material.albedoAt(primitive.textureCoordinate)
        };
        albedo.diffuse = metal::mix(0, albedo.raw.rgb, 1 - metalness);
        albedo.specular = metal::mix(0.04, albedo.raw.rgb, metalness);

        const auto fresnel = PBR::CookTorrance::F::compute(albedo.specular, dirs.view, dirs.halfway);

        float3 color = 0;

        // Diffuse
        {
            float3 contribution = 1;

            {
                const auto diffuse = PBR::Lambertian::compute(albedo.diffuse);
                contribution *= (1 - fresnel) * diffuse;
            }

            {
                // We are supposed to trace a ray here, but the compiler reports a strange error for some reason.
                // This requires us to use the background color directly.

                const auto random = float2(
                    Random::Halton::generate(2 + bounceCount * 5 + 3, seed + frame.id),
                    Random::Halton::generate(2 + bounceCount * 5 + 4, seed + frame.id)
                );

                const float3 direction = Geometry::alignAsUp(
                    Sample::CosineWeightedHemisphere::sample(random),
                    primitive.normal
                );

                contribution *= backgroundColorFor(direction) * dotNL;
            }

            color += contribution;
        }

        // Specular
        {
            float3 contribution = 1;

            {
                const auto roughness = 0.5;

                const auto distribution = PBR::CookTorrance::D::compute(roughness, dirs.normal, dirs.halfway);
                const auto occulusion = PBR::CookTorrance::G::compute(roughness, dirs.normal, dirs.light, dirs.view);

                const auto specular = PBR::CookTorrance::compute(
                    distribution, occulusion, fresnel,
                    dirs.normal, dirs.light, dirs.view
                );

                contribution *= specular;
            }

            {
                const auto direction = metal::reflect(-ray.direction, dirs.normal);

                contribution *= backgroundColorFor(direction) * dotNL;
            }

            color += contribution;
        }

        return color;
    }

public:
    float3 backgroundColorFor(const float3 direction) const { return skyColorFor(direction); }

    float3 skyColorFor(const float3 direction) const
    {
        constexpr auto shallow = float3(1);
        constexpr auto deep = float3(0.5, 0.7, 1);

        const auto alpha = direction.y * 0.5 + 0.5;

        return metal::mix(shallow, deep, alpha) * directionalLight.color;
    }

public:
    Frame frame;
    uint32_t seed;

    Intersector intersector;

    constant Primitive::Instance* instances;
    constant Mesh* meshes;

    struct {
        float3 direction;
        float3 color;
    } directionalLight;

    struct {
        float3 position;
    } view;
};
}

namespace Raytrace {
kernel void kernelMain(
    const uint2 id [[thread_position_in_grid]],
    const metal::texture2d<float, metal::access::write> target [[texture(0)]],
    constant Frame& frame [[buffer(0)]],
    const metal::texture2d<uint32_t> seeds [[texture(1)]],
    const metal::raytracing::instance_acceleration_structure accelerator [[buffer(1)]],
    constant Primitive::Instance* const instances [[buffer(2)]],
    constant Mesh* const meshes [[buffer(3)]]
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

    const auto tracer = Tracer {
        .frame = frame,
        .seed = seed,
        .intersector = Intersector(accelerator),
        .instances = instances,
        .meshes = meshes,
        .directionalLight = {
            .direction = metal::normalize(float3(-1, -1, 1)),
            .color = float3(1) * M_PI_F,
        },
        .view = {
            .position = camera.position,
        },
    };

    const auto ray = raytracing::ray(
        camera.position,
        metal::normalize(
            Geometry::alignAs(float3(inNDC, 1), camera.forward, camera.right, camera.up)
        )
    );

    const auto color = tracer.trace(ray);

    target.write(float4(color, 1), inScreen);
}
}
