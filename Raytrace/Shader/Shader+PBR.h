// tomocy

#pragma once

#include <metal_stdlib>

namespace PBR {
struct Lambertian {
public:
    static float3 compute(const float3 albedo)
    {
        return albedo / M_PI_F;
    }
};
}

namespace PBR {
struct CookTorrance {
public:
    struct D {
    public:
        static float compute(const float roughness, const float3 normal, const float3 halfway)
        {
            const float alpha = metal::pow(roughness, 2);
            const float alpha2 = metal::pow(alpha, 2);

            const auto dotNH = metal::saturate(
                metal::dot(normal, halfway)
            );

            const float d = (metal::pow(dotNH, 2) * (alpha2 - 1) + 1);

            return alpha2 / (M_PI_F * metal::pow(d, 2));
        }
    };

public:
    struct G {
    public:
        static float compute(const float roughness, const float3 normal, const float3 light, const float3 view)
        {
            return schlick(roughness, normal, light) * schlick(roughness, normal, view);
        }

        static float schlick(const float roughness, const float3 normal, const float3 v)
        {
            const auto k = metal::pow(roughness + 1, 2) / 8.0;

            const auto dotNV = metal::clamp(
                metal::dot(normal, v),
                1e-3, 1.0
            );

            return dotNV / (dotNV * (1 - k) + k);
        }
    };

public:
    struct F {
    public:
        static float3 compute(const float3 albedo, const float3 view, const float3 halfway)
        {
            const auto dotVH = metal::saturate(
                metal::dot(view, halfway)
            );

            return albedo + (1 - albedo) * metal::pow(1 - dotVH, 5);
        }
    };

public:
    static float3 compute(
        const float d, const float g, const float3 f,
        const float3 normal, const float3 light, const float3 view
    )
    {
        const auto dotNL = metal::clamp(
            metal::dot(normal, light),
            1e-3, 1.0
        );
        const auto dotNV = metal::clamp(
            metal::dot(normal, view),
            1e-3, 1.0
        );

        return d * g * f / (4 * dotNL * dotNV);
    }
};
}
