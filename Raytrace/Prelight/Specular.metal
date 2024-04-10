// tomocy

#include "../ShaderX/Coordinate.h"
#include "Distribution.h"
#include "Prelight.h"
#include "Sample.h"
#include <metal_stdlib>

namespace Prelight {
namespace Specular {
struct Integral {
public:
    float3 integrate(const float roughness, const thread float3& reflect) const
    {
        // Assume normal == reflect.
        const auto normal = reflect;

        float3 color = 0;
        float weight = 0;

        for (uint i = 0; i < sampleCount; i++) {
            const auto v = Distribution::Hammersley::distribute(sampleCount, i);
            const auto subject = Sample::GGX::sample(v, roughness, normal);
            const auto light = 2 * metal::dot(reflect, subject) * subject - reflect;

            const auto dotNL = metal::saturate(metal::dot(normal, light));
            if (dotNL <= 0) {
                continue;
            }

            color += colorFor(light).rgb * dotNL;
            weight += dotNL;
        }

        return color / metal::max(weight, 1e-4);
    }

public:
    float4 colorFor(const thread float3& direction) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return source.raw().sample(sampler, direction) * M_PI_F;
    }

public:
    uint sampleCount;
    Texture::Cube<float, metal::access::sample> source;
};
}
}

namespace Prelight {
namespace Specular {
kernel void compute(
    const uint2 id [[thread_position_in_grid]],
    constant Args& args [[buffer(0)]]
)
{
    struct {
        ShaderX::Coordinate::InScreen inScreen;
        ShaderX::Coordinate::InFace inFace;
        ShaderX::Coordinate::InUV inUV;
        ShaderX::Coordinate::InNDC inNDC;
    } coordinates = {
        .inScreen = ShaderX::Coordinate::InScreen(id),
    };
    coordinates.inFace = args.source.coordinateInFace(coordinates.inScreen);
    coordinates.inUV = ShaderX::Coordinate::InUV::from(coordinates.inFace, args.source.size());
    coordinates.inNDC = ShaderX::Coordinate::InNDC::from(coordinates.inUV, args.source.faceFor(coordinates.inScreen));

    const auto reflect = metal::normalize(coordinates.inNDC.value());

    const auto integral = Integral {
        .sampleCount = 1024,
        .source = args.source,
    };

    const auto color = integral.integrate(0.2, reflect);

    args.target.write(float4(color, 1), coordinates.inScreen.value());
}
}
}
