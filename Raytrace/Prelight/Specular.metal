// tomocy

#include "../Shader/Coordinate.h"
#include "../Shader/Distribution.h"
#include "../Shader/Sample.h"
#include "Prelight.h"
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
            const auto v = Shader::Distribution::Hammersley::distribute(sampleCount, i);
            const auto subject = Shader::Sample::GGX::sample(v, roughness, normal);
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
    Shader::Texture::Cube<float, metal::access::sample> source;
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
        Shader::Coordinate::InScreen inScreen;
        Shader::Coordinate::InFace inFace;
        Shader::Coordinate::InUV inUV;
        Shader::Coordinate::InNDC inNDC;
    } coordinates = {
        .inScreen = Shader::Coordinate::InScreen(id),
    };
    coordinates.inFace = args.source.coordinateInFace(coordinates.inScreen);
    coordinates.inUV = Shader::Coordinate::InUV::from(coordinates.inFace, args.source.size());
    coordinates.inNDC = Shader::Coordinate::InNDC::from(coordinates.inUV, args.source.faceFor(coordinates.inScreen));

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
