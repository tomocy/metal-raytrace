// tomocy

#pragma once

#include <metal_stdlib>

namespace Geometry {
float3 alignAs(
    const thread float3& v,
    const thread float3& forward,
    const thread float3& right,
    const thread float3& up
);

float3 alignFromTangent(const thread float3& v, const thread float3& normal);
}
