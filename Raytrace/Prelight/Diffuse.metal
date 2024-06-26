// tomocy

#include "../Shader/Coordinate.h"
#include "../Shader/Distribution.h"
#include "../Shader/Geometry/Geometry+Normalized.h"
#include "../Shader/Sample.h"
#include "../Shader/Texture/Texture+Cube.h"
#include "Prelight.h"
#include <metal_stdlib>

namespace Prelight {
namespace Diffuse {
struct Integral {
public:
    float3 integrate(const thread Shader::Geometry::Normalized<float3>& normal) const
    {
        float3 color = 0;

        for (uint i = 0; i < sampleCount; i++) {
            const auto v = Shader::Distribution::Hammersley::distribute(sampleCount, i);
            const auto subject = Shader::Sample::CosineWeighted::sample(v, normal);

            color += colorFor(subject).rgb;
        }

        return color / float(sampleCount);
    }

public:
    float4 colorFor(const thread Shader::Geometry::Normalized<float3>& direction) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::nearest
        );

        return source.raw().sample(sampler, direction.value()) * M_PI_F;
    }

public:
    uint sampleCount;
    Shader::Texture::Cube<float, metal::access::sample> source;
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
