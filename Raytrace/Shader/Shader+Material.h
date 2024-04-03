// tomocy

#include <metal_stdlib>

struct Material {
public:
    float4 albedoAt(const float2 coordinate) const
    {
        constexpr auto sampler = metal::sampler(
            metal::min_filter::nearest,
            metal::mag_filter::nearest,
            metal::mip_filter::none
        );

        return albedo.sample(sampler, coordinate);
    }

public:
    metal::texture2d<float> albedo;
};
