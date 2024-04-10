// tomocy

#pragma once

#include "../ShaderX/PBR/PBR+Material.h"
#include <metal_stdlib>

struct Mesh {
public:
    struct Piece {
    public:
        ShaderX::PBR::Material material;
    };

public:
    constant Piece* pieces;
};
