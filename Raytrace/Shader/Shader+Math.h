// tomocy

#pragma once

template <typename T>
T interpolate(
    const T a, // origin
    const T b,
    const float position
) {
    return (1 - position) * a + position * b;
}

template <typename T>
T interpolate(
    const T a, // origin
    const T b,
    const T c,
    const float2 position
) {
    return (1 - position.x - position.y) * a + position.x * b + position.y * c;
}

namespace Halton {
static constant uint32_t primes[] = {
    2,   3,  5,  7, 11, 13, 17, 19,
    23, 29, 31, 37, 41, 43, 47, 53,
    59, 61, 67, 71, 73, 79, 83, 89,
};

float generate(const uint32_t primer, uint32_t i) {
    const auto base = primes[primer];
    const float invBase = 1.0 / base;

    float f = 1;
    float r = 0;

    while (i > 0) {
        f = f * invBase;
        r = r + f * (i % base);
        i = i / base;
    }

    return r;
}
}
