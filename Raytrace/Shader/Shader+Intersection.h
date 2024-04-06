// tomocy

#pragma once

#include "Shader+Mesh.h"
#include "Shader+Primitive.h"
#include <metal_stdlib>

struct Intersection {
public:
    using Raw = metal::raytracing::intersector<
        metal::raytracing::instancing, metal::raytracing::triangle_data>::result_type;

public:
    Intersection(const metal::raytracing::ray ray, const Raw raw)
        : raw_(raw)
        , ray_(ray)
    {
    }

public:
    bool has() const
    {
        return raw_.type != metal::raytracing::intersection_type::none;
    }

public:
    float3 position() const
    {
        return ray().origin + ray().direction * raw_.distance;
    }

public:
    Primitive toPrimitive() const
    {
        return Primitive::from(
            *(const device Primitive::Triangle*)raw_.primitive_data,
            raw_.triangle_barycentric_coord
        );
    }

public:
    constant Mesh::Piece* pieceIn(constant Primitive::Instance* const instances, constant Mesh* const meshes) const
    {
        const auto instance = instances[raw_.instance_id];
        const auto mesh = meshes[instance.meshID];

        return &mesh.pieces[raw_.geometry_id];
    }

public:
    const thread metal::raytracing::ray& ray() const { return ray_; }

private:
    metal::raytracing::ray ray_;
    Raw raw_;
};

struct Intersector {
public:
    using Raw = typename metal::raytracing::intersector<
        metal::raytracing::instancing, metal::raytracing::triangle_data>;

    using Accelerator = metal::raytracing::instance_acceleration_structure;

public:
    Intersector(const Accelerator accelerator)
        : accelerator(accelerator)
    {
    }

public:
    Intersection intersectAlong(const metal::raytracing::ray ray, const uint32_t mask = 0) const
    {
        const auto intersection = raw_.intersect(ray, accelerator, mask);
        return { ray, intersection };
    }

public:
    metal::raytracing::instance_acceleration_structure accelerator;

private:
    Raw raw_;
};
