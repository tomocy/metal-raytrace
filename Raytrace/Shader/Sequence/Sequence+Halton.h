// tomocy

#pragma once

namespace Shader {
namespace Sequence {
struct Halton {
private:
    static constexpr constant uint32_t primes[] = {
        2, 3, 5, 7, 11, 13, 17, 19, //
        23, 29, 31, 37, 41, 43, 47, 53, //
        59, 61, 67, 71, 73, 79, 83, 89, //
    };

    static constexpr constant uint32_t primeCount = sizeof(primes) / sizeof(primes[0]);

public:
    static float at(const uint32_t dimension, uint32_t i)
    {
        const auto base = primes[dimension % primeCount];
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
};
}
}
