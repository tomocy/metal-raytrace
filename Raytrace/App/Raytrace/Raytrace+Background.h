// tomocy

#pragma once

#include <metal_stdlib>

namespace Raytrace {
struct Background {
public:
    float3 colorFor(const thread metal::raytracing::ray& ray) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return source.sample(sampler, ray.direction).rgb;
    }

public:
    metal::texturecube<float, metal::access::sample> source;
};
}
