// tomocy

import simd

extension Shader {
    struct Transform {}
}

extension Shader.Transform {
    static var identity: float4x4 { .identity }
}

extension Shader.Transform {
    static func orthogonal(
        top: Float, bottom: Float,
        left: Float, right: Float,
        near: Float, far: Float
    ) -> float4x4 {
        // Note that
        // in Metal, unlike x and y axes where values are mapped into -1...1,
        // values on z-axis is into 0...1.

        let translate: SIMD3<Float> = .init(
            (right + left) / (right - left),
            (top + bottom) / (top - bottom),
            near / (far - near)
        )

        let scale: SIMD3<Float> = .init(
            (1 - -1)  / (right - left),
            (1 - -1) / (top - bottom),
            (1 - 0) / (far - near)
        )

        return Self.translate(translate)
            * Self.scale(scale)
    }
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

    static func scale(_ scale: SIMD3<Float>) -> float4x4 {
        return .init(
            rows: [
                .init(scale.x, 0, 0, 0),
                .init(0, scale.y, 0, 0),
                .init(0, 0, scale.z, 0),
                .init(0, 0, 0, 1)
            ]
        )
    }
}
