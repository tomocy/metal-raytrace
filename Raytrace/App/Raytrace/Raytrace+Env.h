// tomocy

#pragma once

#include "../../Shader/Geometry/Geometry+Normalized.h"
#include "../../Shader/PBR/PBR+IBL.h"
#include "../../Shader/PBR/PBR+Material.h"
#include "../../Shader/Texture/Texture+Cube.h"
#include <metal_stdlib>

namespace Raytrace {
struct Env {
public:
    float3 colorWith(
        const thread Shader::PBR::Material::Albedo& albedo,
        const float roughness,
        const thread Shader::Geometry::Normalized<float3>& normal,
        const thread Shader::Geometry::Normalized<float3>& view
    ) const
    {
        return Shader::PBR::IBL::compute(
            diffuse, specular, lut,
            albedo, roughness, normal, view
        );
    }

public:
    metal::texturecube<float, metal::access::sample> diffuse [[texture(3)]];
    metal::texturecube<float, metal::access::sample> specular [[texture(4)]];
    metal::texture2d<float, metal::access::sample> lut [[texture(5)]];
};
}
