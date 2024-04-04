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
    Intersection(const Raw raw)
        : raw(raw)
    {
    }

public:
    float3 positionWith(const metal::raytracing::ray ray) const
    {
        return ray.origin + ray.direction * raw.distance;
    }

public:
    bool has() const
    {
        return raw.type != metal::raytracing::intersection_type::none;
    }

public:
    Primitive::Primitive to() const
    {
        return Primitive::Primitive::from(
            *(const device Primitive::Triangle*)raw.primitive_data,
            raw.triangle_barycentric_coord
        );
    }

public:
    constant Mesh::Piece* findIn(constant Primitive::Instance* const instances, constant Mesh* const meshes) const
    {
        const auto instance = instances[raw.instance_id];
        const auto mesh = meshes[instance.meshID];

        return &mesh.pieces[raw.geometry_id];
    }

private:
    Raw raw;
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
        return { raw.intersect(ray, accelerator, mask) };
    }

public:
    Raw raw;
    metal::raytracing::instance_acceleration_structure accelerator;
};
