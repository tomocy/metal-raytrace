// tomocy

#pragma once

namespace Shader {
namespace PBR {
struct Lambertian {
public:
    static float3 compute(const thread float3& albedo)
    {
        return albedo / M_PI_F;
    }
};
}
}
