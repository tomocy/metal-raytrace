// tomocy

#pragma once

#include "../../ShaderX/PBR/PBR+Material.h"
#include <metal_stdlib>

namespace Raytrace {
struct Mesh {
public:
    struct Piece {
    public:
        ShaderX::PBR::Material material;
    };

public:
    constant Piece* pieces;
};
}
