// tomocy

namespace Debug {
struct Vertex {
public:
    float3 position [[attribute(0)]];
};
}

namespace Debug {
vertex float4 vertexMain(const Vertex v [[stage_in]])
{
    return float4(v.position, 1);
}
}
