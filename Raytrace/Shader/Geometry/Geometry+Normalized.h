// tomocy

#pragma once

#include <metal_stdlib>

namespace Shader {
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
Normalized<T> normalize(const thread T& value) { return { metal::normalize(value) }; }
}
}
