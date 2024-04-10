// tomocy

#pragma once

#include "../ShaderX/Texture/Texture+Cube.h"
#include <metal_stdlib>

namespace Prelight {
struct Args {
public:
    ShaderX::Texture::Cube<float, metal::access::sample> source;
    metal::texture2d<float, metal::access::write> target;
};
}
