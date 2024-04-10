// tomocy

#pragma once

#include "../Geometry/Geometry+Normalized.h"
#include <metal_stdlib>

namespace Shader {
namespace PBR {
struct CookTorrance {
public:
    struct D {
    public:
        static float compute(
            const float roughness,
            const thread Geometry::Normalized<float3>& normal,
            const thread Geometry::Normalized<float3>& halfway
        )
        {
            const float alpha = metal::pow(roughness, 2);
            const float alpha2 = metal::pow(alpha, 2);

            const auto dotNH = metal::saturate(
                metal::dot(normal.value(), halfway.value())
            );

            const float d = (metal::pow(dotNH, 2) * (alpha2 - 1) + 1);

            return alpha2 / (M_PI_F * metal::pow(d, 2));
        }
    };

public:
    struct G {
    public:
        enum class Usage {
            analytic,
            holomorphic,
        };

    public:
        static float compute(
            const float roughness,
            const thread Geometry::Normalized<float3>& normal,
            const thread Geometry::Normalized<float3>& light,
            const thread Geometry::Normalized<float3>& view,
            const Usage usage
        )
        {
            return schlick(roughness, normal, light, usage) * schlick(roughness, normal, view, usage);
        }

        static float schlick(
            const float roughness,
            const thread Geometry::Normalized<float3>& normal,
            const thread Geometry::Normalized<float3>& v,
            const Usage usage
        )
        {
            const auto alpha = roughness;

            float k = 0;
            switch (usage) {
            case Usage::analytic:
                k = metal::pow(alpha + 1, 2) / 8.0;
                break;
            case Usage::holomorphic:
                k = metal::pow(alpha, 2) / 2;
                break;
            }

            const auto dotNV = metal::saturate(
                metal::dot(normal.value(), v.value())
            );

            return dotNV / (dotNV * (1 - k) + k);
        }
    };

public:
    struct F {
    public:
        static float3 compute(
            const thread float3& albedo,
            const thread Geometry::Normalized<float3>& view,
            const thread Geometry::Normalized<float3>& halfway
        )
        {
            const auto dotVH = metal::saturate(
                metal::dot(view.value(), halfway.value())
            );

            return albedo + (1 - albedo) * metal::pow(1 - dotVH, 5);
        }
    };

public:
    static float3 compute(
        const float d, const float g, const thread float3& f,
        const thread Geometry::Normalized<float3>& normal,
        const thread Geometry::Normalized<float3>& light,
        const thread Geometry::Normalized<float3>& view
    )
    {
        const auto dotNL = metal::clamp(
            metal::dot(normal.value(), light.value()),
            1e-3, 1.0
        );
        const auto dotNV = metal::clamp(
            metal::dot(normal.value(), view.value()),
            1e-3, 1.0
        );

        return d * g * f / (4 * dotNL * dotNV);
    }
};
}
}
