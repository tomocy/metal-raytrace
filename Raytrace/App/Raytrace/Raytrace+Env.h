// tomocy

#pragma once

#include "../../ShaderX/Geometry/Geometry+Normalized.h"
#include "../../ShaderX/PBR/PBR+IBL.h"
#include "../../ShaderX/PBR/PBR+Material.h"
#include "../../ShaderX/Texture/Texture+Cube.h"
#include <metal_stdlib>

namespace Raytrace {
struct Env {
public:
    float3 colorWith(
        const thread ShaderX::PBR::Material::Albedo& albedo,
        const float roughness,
        const thread ShaderX::Geometry::Normalized<float3>& normal,
        const thread ShaderX::Geometry::Normalized<float3>& view
    ) const
    {
        return ShaderX::PBR::IBL::compute(
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
