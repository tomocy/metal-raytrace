// tomocy

#include "Geometry.h"
#include <metal_stdlib>

float3 Geometry::alignAs(
    const thread float3& v,
    const thread float3& forward,
    const thread float3& right,
    const thread float3& up
)
{
    return v.x * right + v.y * up + v.z * forward;
}

float3 Geometry::alignFromTangent(const thread float3& v, const thread float3& normal)
{
    const auto arbitary = metal::abs(normal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);

    const auto x = metal::normalize(metal::cross(arbitary, normal));
    const auto y = metal::cross(normal, x);

    return alignAs(v, normal, x, y);
}
