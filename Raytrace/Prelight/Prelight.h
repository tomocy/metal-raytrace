// tomocy

#pragma once

#include "Texture.h"
#include <metal_stdlib>

namespace Prelight {
struct Args {
public:
    Texture::Cube<float, metal::access::sample> source;
    Texture::Cube<float, metal::access::write> target;
};
}