// tomocy

#pragma once

#include "Geometry+Normalized.h"

namespace Shader {
namespace Geometry {
inline float3 alignAs(
    const thread float3& v,
    const thread Normalized<float3>& forward,
    const thread Normalized<float3>& right,
    const thread Normalized<float3>& up
)
{
    return v.x * right.value() + v.y * up.value() + v.z * forward.value();
}

inline float3 alignFromTangent(const thread float3& v, const thread Normalized<float3>& normal)
{
    const auto up = metal::abs(normal.value().z) < 0.999
        ? float3(0, 0, 1)
        : float3(1, 0, 0);

    const auto x = metal::normalize(metal::cross(up, normal.value()));
    const auto y = metal::cross(normal.value(), x);

    return alignAs(v, normal, x, y);
}
}
}
