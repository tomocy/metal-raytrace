// tomocy

#pragma once

#include <metal_stdlib>

namespace Geometry {
float3 alignAs(
    const thread float3& v,
    const thread float3& forward,
    const thread float3& right,
    const thread float3& up
)
{
    return v.x * right + v.y * up + v.z * forward;
}

float3 alignAsUp(const thread float3& v, const thread float3& up)
{
    const auto arbitary = metal::abs(up.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);

    const auto right = metal::normalize(metal::cross(arbitary, up));
    const auto forward = metal::cross(up, right);

    return alignAs(v, forward, right, up);
}
}
