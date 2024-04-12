// tomocy

#include "../../Shader/Distribution.h"
#include "../../Shader/Geometry/Geometry+Normalized.h"
#include "../../Shader/Geometry/Geometry.h"
#include "../../Shader/Sample.h"
#include "../../Shader/Sequence/Sequence+Halton.h"
#include "Raytrace+Acceleration.h"
#include "Raytrace+Background.h"
#include "Raytrace+Env.h"
#include "Raytrace+Frame.h"
#include "Raytrace+Intersect.h"
#include "Raytrace+Mesh.h"
#include "Raytrace+Primitive.h"
#include "Raytrace+Surface.h"
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
            *intersection.pieceIn(intersector.acceleration)
        );

        TraceResult result = {};

        {
            const struct {
                Shader::Geometry::Normalized<float3> light;
                Shader::Geometry::Normalized<float3> view;
            } dirs = {
                .light = -directionalLight.direction.value(),
                .view = Shader::Geometry::normalize(view.position - intersection.position()),
            };

            result.color = surface.colorWith(dirs.light, dirs.view);

            result.color += env.colorWith(
                surface.albedo(),
                surface.roughness(),
                surface.normal(), dirs.view
            );
        }

        {
            result.hasIncident = true;

            result.incidentRay.origin = intersection.position();
            result.incidentRay.min_distance = 1e-3;
            result.incidentRay.max_distance = INFINITY;

            if (!surface.material().isMetalicAt(surface.textureCoordinate())) {
                const auto v = float2(
                    Shader::Sequence::Halton::at(bounceCount * 5 + 5, seed + frame.id),
                    Shader::Sequence::Halton::at(bounceCount * 5 + 6, seed + frame.id)
                );

                result.incidentRay.direction = Shader::Sample::CosineWeighted::sample(v, surface.normal());
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
    Env env;

    Intersector intersector;

    struct {
        Shader::Geometry::Normalized<float3> direction;
        float3 color;
    } directionalLight;

    struct {
        float3 position;
    } view;
};
}

namespace Raytrace {
struct Args {
public:
    metal::texture2d<float, metal::access::write> target;
    constant Frame& frame;
    metal::texture2d<uint32_t> seeds;
    constant Background& background;
    constant Env& env;
    constant Acceleration& acceleration;
};

kernel void compute(
    const uint2 id [[thread_position_in_grid]],
    constant Args& args [[buffer(0)]]
)
{
    namespace raytracing = metal::raytracing;

    // We know size of the target texture for now.
    const auto size = uint2(1600, 1200);

    // We know the camera for now.
    const struct {
        Shader::Geometry::Normalized<float3> forward;
        Shader::Geometry::Normalized<float3> right;
        Shader::Geometry::Normalized<float3> up;
        float3 position;
    } camera = {
        .forward = float3(0, 0, 1),
        .right = float3(1, 0, 0),
        .up = float3(0, 1, 0),
        .position = float3(0, 0.5, -2),
    };

    const auto seed = args.seeds.read(id).r;

    // Map Screen (0...width, 0...height) to UV (0...1, 0...1),
    // then UV to NDC (-1...1, 1...-1).
    const auto inScreen = Shader::Coordinate::InScreen(id);
    const auto inUV = Shader::Coordinate::InUV::from(inScreen, size);
    const auto inNDC = Shader::Coordinate::InNDC::from(inUV, 1);

    const auto tracer = Tracer {
        .maxTraceCount = 3,
        .frame = args.frame,
        .seed = seed,
        .background = args.background,
        .env = args.env,
        .intersector = Intersector(args.acceleration),
        .directionalLight = {
            .direction = Shader::Geometry::normalize(float3(-1, -1, 1)),
            .color = float3(1) * M_PI_F,
        },
        .view = {
            .position = camera.position,
        },
    };

    const auto ray = raytracing::ray(
        camera.position,
        Shader::Geometry::normalize(
            Shader::Geometry::alignAs(inNDC.value(), camera.forward, camera.right, camera.up)
        )
            .value()
    );

    const auto color = tracer.trace(ray);

    args.target.write(float4(color, 1), inScreen.value());
}
}
