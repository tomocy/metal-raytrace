// tomocy

#pragma once

#include "../Geometry/Geometry+Normalized.h"
#include "../Texture/Texture+Cube.h"
#include "PBR+Material.h"

namespace ShaderX {
namespace PBR {
struct IBL {
public:
    struct Diffuse {
    public:
        static float3 compute(
            const thread metal::texturecube<float, metal::access::sample>& source,
            const thread float3& albedo,
            const thread Geometry::Normalized<float3>& normal
        )
        {
            constexpr auto sampler = metal::sampler(
                metal::filter::linear
            );

            const auto color = source.sample(sampler, normal.value()).rgb;

            return albedo * color;
        }
    };

public:
    struct Specular {
    public:
        static float3 compute(
            const thread metal::texturecube<float, metal::access::sample>& source,
            const thread metal::texture2d<float, metal::access::sample>& lut,
            const thread float3& albedo,
            const float roughness,
            const thread Geometry::Normalized<float3>& normal,
            const thread Geometry::Normalized<float3>& view
        )
        {
            constexpr auto sampler = metal::sampler(
                metal::filter::linear
            );

            const auto reflect = metal::reflect(view.value(), normal.value());

            const auto color = source.sample(sampler, reflect).rgb;

            const auto dotNV = metal::saturate(
                metal::dot(normal.value(), view.value())
            );
            const auto brdf = lut.sample(
                sampler,
                float2(dotNV, roughness)
            );

            return (albedo * brdf.r + brdf.g) * color;
        }
    };

public:
    static float3 compute(
        const thread metal::texturecube<float, metal::access::sample>& diffuse,
        const thread metal::texturecube<float, metal::access::sample>& specular,
        const thread metal::texture2d<float, metal::access::sample>& lut,
        const thread Material::Albedo& albedo,
        const float roughness,
        const thread Geometry::Normalized<float3>& normal,
        const thread Geometry::Normalized<float3>& view
    )
    {
        return Diffuse::compute(diffuse, albedo.diffuse, normal)
            + Specular::compute(specular, lut, albedo.specular, roughness, normal, view);
    }
};
}
}
