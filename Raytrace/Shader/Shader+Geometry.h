// tomocy

#pragma once

#include <metal_stdlib>

namespace Geometry {
float3 alignAs(const float3 v, const float3 forward, const float3 right, const float3 up)
{
    return v.x * right + v.y * up + v.z * forward;
}

float3 alignAsUp(const float3 v, const float3 up)
{
    const float3 right = metal::normalize(
        metal::cross(
            up,
            float3(0.0072, 1.0, 0.0034) // arbitrary but perpendicular to the up
        )
    );

    const float3 forward = metal::cross(right, up);

    return alignAs(v, forward, right, up);
}
}
