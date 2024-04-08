// tomocy

#pragma once

#include "Shader+Geometry.h"
#include "Shader+Material.h"
#include "Shader+PBR.h"
#include <metal_stdlib>

struct Env {
public:
    float3 colorWith(
        const thread Material::Albedo& albedo,
        const float roughness,
        const thread Geometry::Normalized<float3>& normal,
        const thread Geometry::Normalized<float3>& view
    ) const
    {
        return PBR::IBL::compute(
            diffuse_, specular_, lut_,
            albedo, roughness, normal, view
        );
    }

private:
    metal::texturecube<float, metal::access::sample> diffuse_ [[texture(3)]];
    metal::texturecube<float, metal::access::sample> specular_ [[texture(4)]];
    metal::texture2d<float, metal::access::sample> lut_ [[texture(5)]];
};
