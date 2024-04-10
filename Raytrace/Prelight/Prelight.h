// tomocy

#pragma once

#include "../Shader/Texture/Texture+Cube.h"
#include <metal_stdlib>

namespace Prelight {
struct Args {
public:
    Shader::Texture::Cube<float, metal::access::sample> source;
    metal::texture2d<float, metal::access::write> target;
};
}
