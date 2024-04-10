// tomocy

#include "../ShaderX/Coordinate.h"
#include "../ShaderX/Sample.h"
#include "Distribution.h"
#include "PBR.h"
#include <metal_stdlib>

namespace Prelight {
namespace Env {
struct Integral {
public:
    float2 integrate(const float roughness, const float dotNV) const
    {
        const auto normal = float3(0, 0, 1);

        const auto view = float3(
            metal::sqrt(1 - metal::pow(dotNV, 2)),
            0,
            dotNV
        );

        float2 brdf = 0;

        for (uint i = 0; i < sampleCount; i++) {
            const auto v = Distribution::Hammersley::distribute(sampleCount, i);
            const auto subject = ShaderX::Sample::GGX::sample(v, roughness, normal);
            const auto light = 2 * metal::dot(view, subject) * subject - view;

            const auto dotNL = metal::saturate(light.z);
            if (dotNL <= 0) {
                continue;
            }

            const auto dotNS = metal::saturate(subject.z);
            const auto dotVS = metal::saturate(metal::dot(view, subject));

            const auto occulusion = PBR::CookTorrance::G::compute(roughness, normal, light, view);
            const auto visibility = occulusion * dotVS / (dotNS * dotNV);
            const auto fresnel = metal::pow(1 - dotVS, 5);

            brdf.r += (1 - fresnel) * visibility;
            brdf.g += fresnel * visibility;
        }

        return brdf / sampleCount;
    }

public:
    uint sampleCount;
};
}
}

namespace Prelight {
namespace Env {
struct Args {
public:
    metal::texture2d<float, metal::access::write> target;
};

kernel void compute(
    const uint2 id [[thread_position_in_grid]],
    constant Args& args [[buffer(0)]]
)
{
    struct {
        ShaderX::Coordinate::InScreen inScreen;
        ShaderX::Coordinate::InUV inUV;
    } coordinates = {
        .inScreen = ShaderX::Coordinate::InScreen(id),
    };
    coordinates.inUV = ShaderX::Coordinate::InUV::from(
        coordinates.inScreen,
        uint2(args.target.get_width(), args.target.get_height())
    );

    const auto dotNV = coordinates.inUV.value().x;
    const auto roughness = 1 - coordinates.inUV.value().y;

    const auto integral = Integral {
        .sampleCount = 1024,
    };

    const auto color = integral.integrate(roughness, dotNV);

    args.target.write(float4(color, 0, 1), coordinates.inScreen.value());
}
}
}
