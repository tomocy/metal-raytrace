// tomocy

#pragma once

#include <metal_stdlib>

namespace Shader {
namespace Interpolate {
template <typename T>
T linear(
    const thread T& origin, // origin
    const thread T& other,
    const thread float& alpha
)
{
    return metal::mix(origin, other, alpha);
}

template <typename T>
T linear(
    const thread T& origin, // origin
    const thread T& x,
    const thread T& y,
    const thread float2& alpha
)
{
    return (1 - alpha.x - alpha.y) * origin + alpha.x * x + alpha.y * y;
}
}
}
