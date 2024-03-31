// tomocy

#pragma once

#include "Shader+Material.h"
#include <metal_stdlib>

struct Mesh {
public:
    struct Piece {
    public:
        Material material;
    };

public:
    constant Piece* pieces;
};
