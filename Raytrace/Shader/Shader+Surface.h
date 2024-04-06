// tomocy

#pragma once

#include "Shader+Mesh.h"
#include "Shader+Primitive.h"
#include <metal_stdlib>

struct Surface {
public:
    Surface(const Primitive primitive, const Mesh::Piece piece)
        : primitive_(primitive)
        , piece_(piece)
    {
    }

public:
    float3 colorWith(const float3 light, const float3 view) const
    {
        float3 color = 0;

        const auto normal = this->normal();
        const float3 halfway = metal::normalize(light + view);

        const auto dotNL = metal::saturate(
            metal::dot(normal, light)
        );

        const auto albedo = this->albedo();
        const auto fresnel = PBR::CookTorrance::F::compute(albedo.specular, view, halfway);

        // Diffuse
        {
            const auto diffuse = PBR::Lambertian::compute(albedo.diffuse);
            color += (1 - fresnel) * diffuse * dotNL;
        }

        // Specular
        {
            const auto roughness = this->roughness();

            const auto distribution = PBR::CookTorrance::D::compute(roughness, normal, halfway);
            const auto occulusion = PBR::CookTorrance::G::compute(roughness, normal, light, view);

            const auto specular = PBR::CookTorrance::compute(
                distribution, occulusion, fresnel,
                normal, light, view
            );

            color += specular * dotNL;
        }

        return color;
    }

public:
    const thread Primitive& primitive() const { return primitive_; }

    const thread Mesh::Piece& piece() const { return piece_; }

public:
    float3 normal() const { return primitive().normal; }

    float2 textureCoordinate() const { return primitive().textureCoordinate; }

public:
    const thread Material& material() const { return piece().material; }

    Material::Albedo albedo() const { return material().albedoAt(textureCoordinate()); }

    bool isMetallic() const { return material().isMetalicAt(textureCoordinate()); }

    float metalness() const { return material().metalnessAt(textureCoordinate()); }

    float roughness() const { return material().roughnessAt(textureCoordinate()); }

private:
    Primitive primitive_;
    Mesh::Piece piece_;
};