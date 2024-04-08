// tomocy

#include "Coordinate.h"
#include "Prelight.h"
#include <metal_stdlib>

namespace Prelight {
namespace Diffuse {
    kernel void compute(
        const uint2 id [[thread_position_in_grid]],
        constant Args& args [[buffer(0)]]
    ) {
        struct {
            Coordinate::InScreen inScreen;
            Coordinate::InFace inFace;
            Coordinate::InUV inUV;
            Coordinate::InNDC inNDC;
        } coordinates = {
            .inScreen = Coordinate::InScreen(id),
        };
        coordinates.inFace = args.target.coordinateInFace(coordinates.inScreen);
        coordinates.inUV = Coordinate::InUV::from(coordinates.inFace, args.target.size());
        coordinates.inNDC = Coordinate::InNDC::from(coordinates.inUV, args.target.faceFor(coordinates.inScreen));

        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        const auto direction = metal::normalize(coordinates.inNDC.value());

        const auto color = args.source.raw().sample(sampler, direction);

        args.target.writeInFace(color, coordinates.inScreen);
    }
}
}
