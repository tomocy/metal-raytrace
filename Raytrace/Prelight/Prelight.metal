// tomocy

#include <metal_stdlib>

namespace Prelight {
    struct Args {
    public:
        metal::texture2d<float, metal::access::sample> source;
        metal::texture2d<float, metal::access::write> target;
    };

    kernel void compute(
        const uint2 id [[thread_position_in_grid]],
        device Args& arg [[buffer(0)]]
    ) {
        const auto color = arg.source.read(id);
        arg.target.write(color, id);
    }
}
