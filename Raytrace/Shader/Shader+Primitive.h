// tomocy

#pragma once

#include "Shader+Math.h"
#include <metal_stdlib>

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
    static Primitive from(const Triangle triangle, const float2 position)
    {
        Primitive primitive = {};

        {
            primitive.normal = metal::normalize(
                interpolate(
                    triangle.normals[0],
                    triangle.normals[1],
                    triangle.normals[2],
                    position
                )
            );
        }

        {
            primitive.textureCoordinate = interpolate(
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
    packed_float3 normal;
    float2 textureCoordinate;
};
