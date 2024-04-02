// tomocy

#pragma once

#include <metal_stdlib>

namespace Sample {
struct CosineWeightedHemisphere {
public:
    static float3 sample(const float2 seed)
    {
        struct SinCos {
            float sin;
            float cos;
        };

        struct SinCos phi = {};
        phi.sin = metal::sincos(2.0f * M_PI_F * seed.x, phi.cos);

        struct SinCos theta = {};
        theta.cos = metal::sqrt(seed.y);
        theta.sin = metal::sqrt(1.0f - theta.cos * theta.cos);

        return { theta.sin * phi.cos, theta.cos, theta.sin * phi.sin };
    }
};
}
