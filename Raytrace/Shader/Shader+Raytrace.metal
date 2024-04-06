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
    // For some reason, the metal compiler fails to compile recursive trace.
    // As a workaround, we implement tracing in a loop instead.
    float3 trace(const metal::raytracing::ray ray) const
    {
        float3 color = 1;
        auto incidentRay = ray;

        for (uint32_t bounceCount = 0;; bounceCount++) {
            const auto result = trace(incidentRay, bounceCount);

            color *= result.color;

            if (!result.hasIncident) {
                break;
            }

            incidentRay = result.incidentRay;
        }

        return color;
    }

private:
    struct TraceResult {
    public:
        float3 color;

        bool hasIncident;
        metal::raytracing::ray incidentRay;
    };

    TraceResult trace(const metal::raytracing::ray ray, const uint32_t bounceCount) const
    {
        if (bounceCount >= maxBounceCount) {
            return {
                .color = 1,
                .hasIncident = false,
            };
        }

        const auto intersection = intersector.intersectAlong(ray, 0xff);

        if (!intersection.has()) {
            auto color = envColorFor(ray.direction);
            if (bounceCount != 0) {
                color *= directionalLight.color;
            }

            return {
                .color = color,
                .hasIncident = false,
            };
        }

        const auto intersectionPosition = intersection.positionWith(ray);

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
            .view = metal::normalize(view.position - intersectionPosition),
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

        TraceResult result = {
            .color = 0,
        };

        {
            // Diffuse
            {
                const auto diffuse = PBR::Lambertian::compute(albedo.diffuse);
                result.color += (1 - fresnel) * diffuse * dotNL;
            }

            // Specular
            {
                const auto roughness = piece.material.roughnessAt(primitive.textureCoordinate);

                const auto distribution = PBR::CookTorrance::D::compute(roughness, dirs.normal, dirs.halfway);
                const auto occulusion = PBR::CookTorrance::G::compute(roughness, dirs.normal, dirs.light, dirs.view);

                const auto specular = PBR::CookTorrance::compute(
                    distribution, occulusion, fresnel,
                    dirs.normal, dirs.light, dirs.view
                );

                result.color += specular * dotNL;
            }
        }

        {
            result.hasIncident = true;

            result.incidentRay.origin = intersectionPosition;
            result.incidentRay.min_distance = 1e-3;
            result.incidentRay.max_distance = INFINITY;

            if (metalness == 0) {
                const auto random = float2(
                    Random::Halton::generate(bounceCount * 5 + 5, seed + frame.id),
                    Random::Halton::generate(bounceCount * 5 + 6, seed + frame.id)
                );

                result.incidentRay.direction = Geometry::alignAsUp(
                    Sample::CosineWeightedHemisphere::sample(random),
                    primitive.normal
                );
            } else {
                result.incidentRay.direction = metal::reflect(ray.direction, dirs.normal);
            }
        }

        return result;
    }

public:
    float3 envColorFor(const float3 direction) const {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return env.sample(sampler, direction).rgb;
    }

public:
    uint32_t maxBounceCount = 3;

    Frame frame;
    uint32_t seed;

    metal::texturecube<float> env;

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
    const metal::texturecube<float> env [[texture(2)]],
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
        .maxBounceCount = 3,
        .frame = frame,
        .seed = seed,
        .env = env,
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
