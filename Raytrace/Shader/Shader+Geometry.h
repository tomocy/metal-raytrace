// tomocy

#pragma once

#include "../ShaderX/Geometry/Geometry+Normalized.h"
#include <metal_stdlib>

namespace Geometry {
float3 alignAs(
    const thread float3& v,
    const thread ShaderX::Geometry::Normalized<float3>& forward,
    const thread ShaderX::Geometry::Normalized<float3>& right,
    const thread ShaderX::Geometry::Normalized<float3>& up
)
{
    return v.x * right.value() + v.y * up.value() + v.z * forward.value();
}

float3 alignAsUp(const thread float3& v, const thread ShaderX::Geometry::Normalized<float3>& up)
{
    const auto right = ShaderX::Geometry::normalize(
        metal::cross(
            up.value(),
            float3(0.0072, 1.0, 0.0034) // arbitrary but perpendicular to the up
        )
    );

    const auto forward = ShaderX::Geometry::normalize(
        metal::cross(right.value(), up.value())
    );

    return alignAs(v, forward, right, up);
}
}
