// tomocy

#pragma once

#include "Raytrace+Mesh.h"
#include "Raytrace+Primitive.h"
#include <metal_stdlib>

namespace Raytrace {
struct Acceleration {
public:
    metal::raytracing::instance_acceleration_structure structure;
    constant Mesh* meshes;
    constant Primitive::Instance* instances;
};
}
