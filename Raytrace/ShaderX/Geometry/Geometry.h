// tomocy

#pragma once

#include "Geometry+Normalized.h"

namespace ShaderX {
namespace Geometry {
float3 alignAs(
    const thread float3& v,
    const thread Normalized<float3>& forward,
    const thread Normalized<float3>& right,
    const thread Normalized<float3>& up
);

float3 alignFromTangent(const thread float3& v, const thread Normalized<float3>& normal);
}
}
