// tomocy

#pragma once

#include <metal_stdlib>

namespace PBR {
struct CookTorrance {
public:
    struct G {
    public:
        static float compute(
            const float roughness,
            const thread float3& normal,
            const thread float3& light,
            const thread float3& view
        )
        {
            return schlick(roughness, normal, light) * schlick(roughness, normal, view);
        }

        static float schlick(
            const float roughness,
            const thread float3& normal,
            const thread float3& v
        )
        {
            const auto alpha = roughness;
            const auto k = metal::pow(alpha, 2) / 2;

            const auto dotNV = metal::saturate(
                metal::dot(normal, v)
            );

            return dotNV / (dotNV * (1 - k) + k);
        }
    };

public:
    struct F {
    public:
        static float3 compute(
            const thread float3& albedo,
            const thread float3& view,
            const thread float3& halfway
        )
        {
            const auto dotVH = metal::saturate(
                metal::dot(view, halfway)
            );

            return albedo + (1 - albedo) * metal::pow(1 - dotVH, 5);
        }
    };
};
}
