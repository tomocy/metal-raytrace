// tomocy

#pragma once

template <typename T>
T mix(
    const T origin, // origin
    const T x,
    const T y,
    const float2 alpha
)
{
    return (1 - alpha.x - alpha.y) * origin + alpha.x * x + alpha.y * y;
}
