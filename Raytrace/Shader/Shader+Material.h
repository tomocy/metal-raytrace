// tomocy

#pragma once

#include <metal_stdlib>

struct Material {
public:
    struct Albedo {
    public:
        float3 diffuse;
        float3 specular;
    };

    Albedo albedoAt(const thread float2& coordinate) const
    {
        const auto metalness = metalnessAt(coordinate);
        const auto raw = rawAlbedoAt(coordinate).rgb;

        return {
            .diffuse = metal::mix(0, raw, 1 - metalness),
            .specular = metal::mix(0.04, raw, metalness),
        };
    }

    float4 rawAlbedoAt(const thread float2& coordinate) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return albedo.sample(sampler, coordinate);
    }

public:
    metal::texture2d<float> albedo;

public:
    bool isMetalicAt(const thread float2& coordinate) const
    {
        return metalnessAt(coordinate) == 1;
    }

    float metalnessAt(const thread float2& coordinate) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return metalRoughness.sample(sampler, coordinate).r;
    }

public:
    float roughnessAt(const thread float2& coordinate) const
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return metal::max(metalRoughness.sample(sampler, coordinate).g, 0.04);
    }

public:
    // R for metalness, G for roughness.
    metal::texture2d<float> metalRoughness;
};
