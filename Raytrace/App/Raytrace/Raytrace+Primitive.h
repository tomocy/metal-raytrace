// tomocy

#pragma once

#include "../../Shader/Geometry/Geometry+Normalized.h"
#include "../../Shader/Interpolate.h"
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
    static Primitive from(const thread Triangle& triangle, const thread float2& position)
    {
        Primitive primitive = {};

        {
            primitive.normal = Shader::Geometry::normalize(
                Shader::Interpolate::linear(
                    float3(triangle.normals[0]),
                    float3(triangle.normals[1]),
                    float3(triangle.normals[2]),
                    position
                )
            );
        }

        {
            primitive.textureCoordinate = Shader::Interpolate::linear(
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
    Shader::Geometry::Normalized<float3> normal;
    float2 textureCoordinate;
};
}
