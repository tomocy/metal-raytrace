// tomocy

import simd

extension Shader {
    struct Transform {}
}

extension Shader.Transform {
    static var identity: float4x4 { .identity }
}

extension Shader.Transform {
    static func translate(_ translate: SIMD3<Float>) -> float4x4 {
        return .init(
            rows: [
                .init(1, 0, 0, translate.x),
                .init(0, 1, 0, translate.y),
                .init(0, 0, 1, translate.z),
                .init(0, 0, 0, 1)
            ]
        )
    }
}
