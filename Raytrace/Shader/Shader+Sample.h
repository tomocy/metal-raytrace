// tomocy

#pragma once

#include <metal_stdlib>

namespace Sample {
struct CosineWeightedHemisphere {
public:
    static float3 sample(const thread float2& uv)
    {
        struct SinCos {
            float sin;
            float cos;
        };

        struct SinCos theta = {};
        theta.cos = metal::sqrt(uv.y);
        theta.sin = metal::sqrt(1.0 - theta.cos * theta.cos);

        struct SinCos phi = {};
        phi.sin = metal::sincos(2.0 * M_PI_F * uv.x, phi.cos);

        return { theta.sin * phi.cos, theta.cos, theta.sin * phi.sin };
    }
};
}
