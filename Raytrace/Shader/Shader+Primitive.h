// tomocy

#pragma once

namespace Primitive {
struct Triangle {
public:
    uint16_t meshID;
    uint16_t pieceID;
    packed_float3 normals[3];
    float2 textureCoordinates[3];
};
}
