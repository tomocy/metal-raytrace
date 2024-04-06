// tomocy

#pragma once

template <typename T>
T mix(
    const thread T& origin, // origin
    const thread T& x,
    const thread T& y,
    const thread float2& alpha
)
{
    return (1 - alpha.x - alpha.y) * origin + alpha.x * x + alpha.y * y;
}
