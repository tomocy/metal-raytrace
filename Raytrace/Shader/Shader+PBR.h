// tomocy

#pragma once

#include <metal_stdlib>

namespace PBR {
struct Lambertian {
public:
    static float3 compute(const float3 albedo)
    {
        return albedo / M_PI_F;
    }
};
}
