// tomocy

#pragma once

#include "Shader+Geometry.h"
#include <metal_stdlib>

namespace PBR {
struct Lambertian {
public:
    static float3 compute(const thread float3& albedo)
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
        static float compute(
            const float roughness,
            const thread Geometry::Normalized<float3>& normal,
            const thread Geometry::Normalized<float3>& light,
            const thread Geometry::Normalized<float3>& view
        )
        {
            return schlick(roughness, light, normal) * schlick(roughness, view, normal);
        }

        static float schlick(
            const float roughness,
            const thread Geometry::Normalized<float3>& v,
            const thread Geometry::Normalized<float3>& normal
        )
        {
            const auto k = metal::pow(roughness + 1, 2) / 8.0;

            const auto dotNV = metal::clamp(
                metal::dot(normal.value(), v.value()),
                1e-3, 1.0
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
