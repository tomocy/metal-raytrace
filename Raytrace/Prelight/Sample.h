// tomocy

#pragma once

#include "Geometry.h"

namespace Sample {
struct CosineWeighted {
public:
    static float3 sample(const thread float2& v, const thread float3& normal)
    {
        const auto r = metal::sqrt(v.x);
        const auto phi = 2.0 * M_PI_F * v.y;

        const auto x = r * metal::cos(phi);
        const auto y = r * metal::sin(phi);
        const auto z = metal::sqrt(1 - v.x);

        return Geometry::alignFromTangent(float3(x, y, z), normal);
    }
};
}
