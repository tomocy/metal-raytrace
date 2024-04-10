// tomocy

#pragma once

#include "Geometry/Geometry.h"

namespace Shader {
namespace Sample {
struct CosineWeighted {
public:
    static float3 sample(const thread float2& v, const thread Geometry::Normalized<float3>& normal)
    {
        const auto r = metal::sqrt(v.x);
        const auto phi = 2.0 * M_PI_F * v.y;

        const auto x = r * metal::cos(phi);
        const auto y = r * metal::sin(phi);
        const auto z = metal::sqrt(1 - v.x);

        return Shader::Geometry::alignFromTangent(float3(x, y, z), normal);
    }
};
}

namespace Sample {
struct GGX {
public:
    static float3 sample(const thread float2& v, const float roughness, const thread Geometry::Normalized<float3>& normal)
    {
        const auto alpha = roughness * roughness;
        const auto alpha2 = metal::pow(alpha, 2);

        struct {
            float cos;
            float sin;
        } theta = {};
        theta.cos = metal::sqrt((1 - v.y) / (1 + (alpha2 - 1) * v.y));
        theta.sin = metal::sqrt(1 - metal::pow(theta.cos, 2));

        const auto phi = 2.0 * M_PI_F * v.x;
        const auto x = theta.sin * metal::cos(phi);
        const auto y = theta.sin * metal::sin(phi);
        const auto z = theta.cos;

        return Shader::Geometry::alignFromTangent(float3(x, y, z), normal);
    }
};
}

}
