// tomocy

#pragma once

#include "../../Shader/PBR/PBR+Material.h"
#include <metal_stdlib>

namespace Raytrace {
struct Mesh {
public:
    struct Piece {
    public:
        Shader::PBR::Material material;
    };
};
}
