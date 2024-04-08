// tomocy

#pragma once

#include <metal_stdlib>

struct Background {
public:
    Background(const metal::texturecube<float> texture)
        : texture_(texture)
    {
    }

public:
    float3 colorFor(const thread metal::raytracing::ray& ray) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return texture_.sample(sampler, ray.direction).rgb;
    }

private:
    metal::texturecube<float, metal::access::sample> texture_ [[texture(2)]];
};
