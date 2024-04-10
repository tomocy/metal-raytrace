// tomocy

#pragma once

#include "Sequence/Sequence+VanDerCorput.h"

namespace Shader {
namespace Distribution {
struct Hammersley {
public:
    static float2 distribute(const uint32_t n, const uint32_t i)
    {
        return { float(i) / float(n), Sequence::VanDerCorput::at(i) };
    }
};
}
}
