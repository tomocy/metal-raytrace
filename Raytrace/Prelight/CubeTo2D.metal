// tomocy

#include "Texture.h"
#include <metal_stdlib>

namespace CubeTo2D {
    struct Args {
    public:
        Texture::Cube<float, metal::access::sample> source;
        metal::texture2d<float, metal::access::write> target;
    };

    kernel void compute(
        const uint2 id [[thread_position_in_grid]],
        constant Args& args [[buffer(0)]]
    ) {
        struct {
            Coordinate::InScreen inScreen;
        } coordinates = {
            .inScreen = Coordinate::InScreen(id),
        };

        const auto color = args.source.readInFace(coordinates.inScreen);
        args.target.write(color, coordinates.inScreen.value());
    }
}
