// tomocy

#pragma once

#include "../ShaderX/Geometry/Geometry+Normalized.h"
#include "Shader+Material.h"
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
            const thread ShaderX::Geometry::Normalized<float3>& normal,
            const thread ShaderX::Geometry::Normalized<float3>& halfway
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
            const thread ShaderX::Geometry::Normalized<float3>& normal,
            const thread ShaderX::Geometry::Normalized<float3>& light,
            const thread ShaderX::Geometry::Normalized<float3>& view
        )
        {
            return schlick(roughness, light, normal) * schlick(roughness, view, normal);
        }

        static float schlick(
            const float roughness,
            const thread ShaderX::Geometry::Normalized<float3>& v,
            const thread ShaderX::Geometry::Normalized<float3>& normal
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
            const thread ShaderX::Geometry::Normalized<float3>& view,
            const thread ShaderX::Geometry::Normalized<float3>& halfway
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
        const thread ShaderX::Geometry::Normalized<float3>& normal,
        const thread ShaderX::Geometry::Normalized<float3>& light,
        const thread ShaderX::Geometry::Normalized<float3>& view
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

namespace PBR {
struct IBL {
public:
    struct Diffuse {
    public:
        static float3 compute(
            const thread metal::texturecube<float, metal::access::sample>& source,
            const thread float3& albedo,
            const thread ShaderX::Geometry::Normalized<float3>& normal
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
            const thread ShaderX::Geometry::Normalized<float3>& normal,
            const thread ShaderX::Geometry::Normalized<float3>& view
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
        const thread ShaderX::Geometry::Normalized<float3>& normal,
        const thread ShaderX::Geometry::Normalized<float3>& view
    )
    {
        return Diffuse::compute(diffuse, albedo.diffuse, normal)
            + Specular::compute(specular, lut, albedo.specular, roughness, normal, view);
    }
};
}
