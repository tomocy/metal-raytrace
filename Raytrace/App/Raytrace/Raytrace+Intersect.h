// tomocy

#pragma once

#include "Raytrace+Acceleration.h"
#include "Raytrace+Mesh.h"
#include "Raytrace+Primitive.h"
#include <metal_stdlib>

namespace Raytrace {
struct Intersection {
public:
    using Raw = metal::raytracing::intersector<metal::raytracing::instancing, metal::raytracing::triangle_data>::result_type;

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
        const auto triangle = *(const device Primitive::Triangle*)raw_.primitive_data;

        return Primitive::from(
            triangle,
            raw_.triangle_barycentric_coord
        );
    }

public:
    constant Mesh::Piece* pieceIn(const thread Acceleration& acceleration) const
    {
        const auto primitive = acceleration.primitives[raw_.instance_id];
        const auto mesh = acceleration.meshes[primitive.meshID];

        return &mesh.pieces[raw_.geometry_id];
    }

public:
    const thread metal::raytracing::ray& ray() const { return ray_; }

private:
    metal::raytracing::ray ray_;
    Raw raw_;
};
}

namespace Raytrace {
struct Intersector {
public:
    using Raw = typename metal::raytracing::intersector<metal::raytracing::instancing, metal::raytracing::triangle_data>;

    using Accelerator = metal::raytracing::instance_acceleration_structure;

public:
    Intersector(const Acceleration acceleration)
        : acceleration(acceleration)
    {
    }

public:
    Intersection intersectAlong(const thread metal::raytracing::ray& ray, const uint32_t mask = 0) const
    {
        const auto intersection = raw_.intersect(ray, acceleration.structure, mask);
        return { ray, intersection };
    }

public:
    Acceleration acceleration;

private:
    Raw raw_;
};
}
