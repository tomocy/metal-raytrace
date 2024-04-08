// tomocy

#pragma once

#include <metal_stdlib>

namespace Prelight {
struct Args {
public:
    metal::texturecube<float, metal::access::sample> source;
    metal::texturecube<float, metal::access::write> target;
};
}
