// tomocy

#include "../ShaderX/Coordinate.h"
#include "../ShaderX/Geometry/Geometry+Normalized.h"
#include "../ShaderX/Sample.h"
#include "Distribution.h"
#include "Prelight.h"
#include <metal_stdlib>

namespace Prelight {
namespace Diffuse {
struct Integral {
public:
    float3 integrate(const thread ShaderX::Geometry::Normalized<float3>& normal) const
    {
        float3 color = 0;

        for (uint i = 0; i < sampleCount; i++) {
            const auto v = Distribution::Hammersley::distribute(sampleCount, i);
            const auto direction = ShaderX::Sample::CosineWeighted::sample(v, normal);

            color += colorFor(direction).rgb;
        }

        return color / float(sampleCount);
    }

public:
    float4 colorFor(const thread ShaderX::Geometry::Normalized<float3>& direction) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::nearest
        );

        return source.raw().sample(sampler, direction.value()) * M_PI_F;
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
