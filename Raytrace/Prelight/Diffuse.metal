// tomocy

#include "Coordinate.h"
#include "Distribution.h"
#include "Prelight.h"
#include "Sample.h"
#include <metal_stdlib>

namespace Prelight {
namespace Diffuse {
struct Integral {
public:
    float3 integrate(const thread float3& normal) const
    {
        float3 color = 0;

        for (uint i = 0; i < sampleCount; i++) {
            const auto v = Distribution::Hammersley::distribute(sampleCount, i);
            const auto direction = Sample::CosineWeighted::sample(v, normal);

            color += colorFor(direction).rgb;
        }

        return color / float(sampleCount);
    }

public:
    float4 colorFor(const thread float3& direction) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::nearest
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
namespace Diffuse {
kernel void compute(
    const uint2 id [[thread_position_in_grid]],
    constant Args& args [[buffer(0)]]
)
{
    struct {
        Coordinate::InScreen inScreen;
        Coordinate::InFace inFace;
        Coordinate::InUV inUV;
        Coordinate::InNDC inNDC;
    } coordinates = {
        .inScreen = Coordinate::InScreen(id),
    };
    coordinates.inFace = args.source.coordinateInFace(coordinates.inScreen);
    coordinates.inUV = Coordinate::InUV::from(coordinates.inFace, args.source.size());
    coordinates.inNDC = Coordinate::InNDC::from(coordinates.inUV, args.source.faceFor(coordinates.inScreen));

    const auto normal = metal::normalize(coordinates.inNDC.value());

    const auto integral = Integral {
        .sampleCount = 1024,
        .source = args.source,
    };

    const auto color = integral.integrate(normal);

    args.target.write(float4(color, 1), coordinates.inScreen.value());
}
}
}
