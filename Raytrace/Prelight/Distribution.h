// tomocy

#pragma once

#include "../ShaderX/Sequence.h"

namespace Distribution {
struct Hammersley {
public:
    static float2 distribute(const uint32_t n, const uint32_t i)
    {
        return { float(i) / float(n), ShaderX::Sequence::VanDerCorput::at(i) };
    }
};
}
