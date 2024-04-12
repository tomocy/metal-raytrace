// tomocy

#pragma once

#include "../AddressSpace.h"
#include "../Interpolate.h"
#include <metal_stdlib>

namespace Shader {
namespace PBR {
struct Material {
public:
    struct Albedo {
    public:
        float3 diffuse;
        float3 specular;
    };

    Albedo albedoAt(const thread float2& coordinate) const constant
    {
        return AddressSpace::Thread::from(*this).albedoAt(coordinate);
    }

    Albedo albedoAt(const thread float2& coordinate) const thread
    {
        const auto metalness = metalnessAt(coordinate);
        const auto raw = rawAlbedoAt(coordinate).rgb;

        return {
            .diffuse = Interpolate::linear(float3(0), raw, 1.0 - metalness),
            .specular = Interpolate::linear(float3(0.04), raw, metalness),
        };
    }

    float4 rawAlbedoAt(const thread float2& coordinate) const constant
    {
        return AddressSpace::Thread::from(*this).rawAlbedoAt(coordinate);
    }

    float4 rawAlbedoAt(const thread float2& coordinate) const thread
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return albedo.sample(sampler, coordinate);
    }

public:
    metal::texture2d<float> albedo;

public:
    bool isMetalicAt(const thread float2& coordinate) const constant
    {
        return AddressSpace::Thread::from(*this).isMetalicAt(coordinate);
    }

    bool isMetalicAt(const thread float2& coordinate) const thread
    {
        return metalnessAt(coordinate) == 1;
    }

    float metalnessAt(const thread float2& coordinate) const constant
    {
        return AddressSpace::Thread::from(*this).metalnessAt(coordinate);
    }

    float metalnessAt(const thread float2& coordinate) const thread
    {
        constexpr auto sampler = metal::sampler(
            metal::filter::linear
        );

        return metalRoughness.sample(sampler, coordinate).r;
    }

public:
    float roughnessAt(const thread float2& coordinate) const constant
    {
        return AddressSpace::Thread::from(*this).roughnessAt(coordinate);
    }

    float roughnessAt(const thread float2& coordinate) const thread
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

}
}
