// tomocy

#include <metal_stdlib>

struct Material {
public:
    float4 albedoAt(const float2 coordinate) const
    {
        constexpr auto sampler = metal::sampler(
            metal::min_filter::nearest,
            metal::mag_filter::nearest,
            metal::mip_filter::none
        );

        return albedo.sample(sampler, coordinate);
    }

public:
    metal::texture2d<float> albedo;

public:
    bool isMetalicAt(const float2 coordinate) const
    {
        return metalnessAt(coordinate) == 1;
    }

    float metalnessAt(const float2 coordinate) const {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return metalRoughness.sample(sampler, coordinate).r;
    }

public:
    float roughnessAt(const float2 coordinate) const {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return metal::max(metalRoughness.sample(sampler, coordinate).g, 0.04);
    }

public:
    // R for metalness, G for roughness.
    metal::texture2d<float> metalRoughness;
};
