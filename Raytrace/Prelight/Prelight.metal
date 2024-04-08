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
        const auto inUV = float2(inFace.value()) / float(args.target.size());

        float3 inNDC = float3(
            float2(inUV.x * 2 - 1, inUV.y * -2 + 1),
            0
        );

        const auto face = args.target.faceFor(coordinates.inScreen);
        switch (face) {
            case 0:
                inNDC = float3(1, inNDC.y, -inNDC.x);
                break;
            case 1:
                inNDC = float3(-1, inNDC.y, inNDC.x);
                break;
            case 2:
                inNDC = float3(inNDC.x, 1, -inNDC.y);
                break;
            case 3:
                inNDC = float3(inNDC.x, -1, inNDC.y);
                break;
            case 4:
                inNDC = float3(inNDC.x, inNDC.y, 1);
                break;
            case 5:
                inNDC = float3(-inNDC.x, inNDC.y, -1);
                break;
            default:
                inNDC = 0;
                break;
        }

        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        const auto direction = metal::normalize(inNDC);

        const auto color = args.source.raw().sample(sampler, direction);

        args.target.writeInFace(color, coordinates.inScreen);
    }
}
