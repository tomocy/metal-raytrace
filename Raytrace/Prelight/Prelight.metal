// tomocy

#include "Prelight.h"
#include <metal_stdlib>

namespace Prelight {
    kernel void compute(
        const uint2 id [[thread_position_in_grid]],
        constant Args& args [[buffer(0)]]
    ) {
        const uint32_t size = args.target.get_width();

        const auto face = id.y / size;
        const auto inFace = id % size;

        const auto color = args.source.read(inFace, face);
        args.target.write(color, inFace, face);
    }
}
