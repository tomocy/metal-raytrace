// tomocy

#include "Shader+Background.h"
#include "Shader+Frame.h"
#include "Shader+Geometry.h"
#include "Shader+Intersection.h"
#include "Shader+Math.h"
#include "Shader+Mesh.h"
#include "Shader+PBR.h"
#include "Shader+Primitive.h"
#include "Shader+Random.h"
#include "Shader+Sample.h"
#include "Shader+Surface.h"
#include <metal_stdlib>

namespace Raytrace {
struct Tracer {
public:
    // For some reason, the metal compiler fails to compile recursive trace.
    // As a workaround, we implement tracing in a loop instead.
    float3 trace(const metal::raytracing::ray ray) const
    {
        if (maxTraceCount <= 0) {
            return 0;
        }

        struct {
            float3 color;
            metal::raytracing::ray incidentRay;
        } state = {
            .color = 1,
            .incidentRay = ray,
        };

        for (uint32_t bounceCount = 0;; bounceCount++) {
            const auto result = trace(state.incidentRay, bounceCount);

            state.color *= result.color;

            if (!result.hasIncident) {
                break;
            }

            state.incidentRay = result.incidentRay;
        }

        return state.color;
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
        if (bounceCount >= maxTraceCount) {
            return {
                .color = 1,
                .hasIncident = false,
            };
        }

        const auto intersection = intersector.intersectAlong(ray, 0xff);

        if (!intersection.has()) {
            auto color = background.colorFor(ray);

            if (bounceCount != 0) {
                color *= directionalLight.color;
            }

            return {
                .color = color,
                .hasIncident = false,
            };
        }

        const auto surface = Surface(
            intersection.toPrimitive(),
            *intersection.pieceIn(instances, meshes)
        );

        TraceResult result = {};

        result.color = surface.colorWith(
            -directionalLight.direction.value(),
            Geometry::normalize(view.position - intersection.position())
        );

        {
            result.hasIncident = true;

            result.incidentRay.origin = intersection.position();
            result.incidentRay.min_distance = 1e-3;
            result.incidentRay.max_distance = INFINITY;

            if (!surface.material().isMetalicAt(surface.textureCoordinate())) {
                const auto random = float2(
                    Random::Halton::generate(bounceCount * 5 + 5, seed + frame.id),
                    Random::Halton::generate(bounceCount * 5 + 6, seed + frame.id)
                );

                result.incidentRay.direction = Geometry::alignAsUp(
                    Sample::CosineWeightedHemisphere::sample(random),
                    surface.normal()
                );
            } else {
                result.incidentRay.direction = metal::reflect(ray.direction, surface.normal().value());
            }
        }

        return result;
    }

public:
    uint32_t maxTraceCount = 3;

    Frame frame;
    uint32_t seed;

    Background background;

    Intersector intersector;

    constant Primitive::Instance* instances;
    constant Mesh* meshes;

    struct {
        Geometry::Normalized<float3> direction;
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
    const metal::texturecube<float> background [[texture(2)]],
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
        Geometry::Normalized<float3> forward;
        Geometry::Normalized<float3> right;
        Geometry::Normalized<float3> up;
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
        .maxTraceCount = 3,
        .frame = frame,
        .seed = seed,
        .background = Background(background),
        .intersector = Intersector(accelerator),
        .instances = instances,
        .meshes = meshes,
        .directionalLight = {
            .direction = Geometry::normalize(float3(-1, -1, 1)),
            .color = float3(1) * M_PI_F,
        },
        .view = {
            .position = camera.position,
        },
    };

    const auto ray = raytracing::ray(
        camera.position,
        Geometry::normalize(
            Geometry::alignAs(float3(inNDC, 1), camera.forward, camera.right, camera.up)
        ).value()
    );

    const auto color = tracer.trace(ray);

    target.write(float4(color, 1), inScreen);
}
}
