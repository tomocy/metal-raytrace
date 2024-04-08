// tomocy

#include "Prelight.h"
#include <metal_stdlib>

namespace Prelight {
    kernel void compute(
        const uint2 id [[thread_position_in_grid]],
        constant Args& args [[buffer(0)]]
    ) {
        struct {
            uint2 inScreen;
        } coordinates = {
            .inScreen = id,
        };

        const auto color = args.source.readInFace(coordinates.inScreen);
        args.target.writeInFace(color, coordinates.inScreen);
    }
}
