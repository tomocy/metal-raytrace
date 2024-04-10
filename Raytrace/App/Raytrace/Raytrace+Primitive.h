// tomocy

#pragma once

#include "../../ShaderX/Geometry/Geometry+Normalized.h"
#include "../../ShaderX/Interpolate.h"
#include <metal_stdlib>

namespace Raytrace {
struct Primitive {
public:
    struct Triangle {
    public:
        packed_float3 normals[3];
        float2 textureCoordinates[3];
    };

public:
    struct Instance {
    public:
        uint16_t meshID;
    };

public:
    static Primitive from(const thread Triangle& triangle, const thread float2& position)
    {
        Primitive primitive = {};

        {
            primitive.normal = ShaderX::Geometry::normalize(
                ShaderX::Interpolate::linear(
                    float3(triangle.normals[0]),
                    float3(triangle.normals[1]),
                    float3(triangle.normals[2]),
                    position
                )
            );
        }

        {
            primitive.textureCoordinate = ShaderX::Interpolate::linear(
                triangle.textureCoordinates[0],
                triangle.textureCoordinates[1],
                triangle.textureCoordinates[2],
                position
            );

            primitive.textureCoordinate.y = 1 - primitive.textureCoordinate.y;
        }

        return primitive;
    }

public:
    ShaderX::Geometry::Normalized<float3> normal;
    float2 textureCoordinate;
};
}