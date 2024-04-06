// tomocy

#pragma once

#include <metal_stdlib>

namespace Geometry {
template <typename T>
struct Normalized {
public:
    Normalized() = default;

    Normalized(const T value)
        : value_(value)
    {
        assert(value == metal::normalize(value));
    }

public:
    const thread T& value() const { return value_; }

private:
    T value_;
};

template <typename T>
Normalized<T> normalize(const T value) { return { metal::normalize(value) }; }
}

namespace Geometry {
float3 alignAs(
    const float3 v,
    const Normalized<float3> forward,
    const Normalized<float3> right,
    const Normalized<float3> up
)
{
    return v.x * right.value() + v.y * up.value() + v.z * forward.value();
}

float3 alignAsUp(const float3 v, const Normalized<float3> up)
{
    const auto right = normalize(
        metal::cross(
            up.value(),
            float3(0.0072, 1.0, 0.0034) // arbitrary but perpendicular to the up
        )
    );

    const auto forward = normalize(
        metal::cross(right.value(), up.value())
    );

    return alignAs(v, forward, right, up);
}
}
