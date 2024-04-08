// tomocy

#include "Coordinate.h"
#include "Prelight.h"
#include <metal_stdlib>

namespace Prelight {
    kernel void compute(
        const uint2 id [[thread_position_in_grid]],
        constant Args& args [[buffer(0)]]
    ) {
        struct {
            Coordinate::InScreen inScreen;
        } coordinates = {
            .inScreen = Coordinate::InScreen(id),
        };

        const auto inFace = args.target.coordinateInFace(coordinates.inScreen);
        const auto inUV = Coordinate::InUV::from(inFace, args.target.size());
        const auto inNDC = Coordinate::InNDC::from(inUV, args.target.faceFor(coordinates.inScreen));

        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        const auto direction = metal::normalize(inNDC.value());

        const auto color = args.source.raw().sample(sampler, direction);

        args.target.writeInFace(color, coordinates.inScreen);
    }
}
