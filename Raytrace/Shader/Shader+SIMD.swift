// tomocy

import simd
import Metal

extension SIMD3<Float> {
    typealias Packed = MTLPackedFloat3
}

extension SIMD3<Float> {
    init(_ other: Packed) {
        self.init(other.x, other.y, other.z)
    }
}

extension SIMD3<Float>.Packed {
    init(_ x: Float, _ y: Float, _ z: Float) {
        self.init(.init(x, y, z))
    }

    init(_ other: SIMD3<Float>) {
        self.init(
            .init(elements: (other.x, other.y, other.z))
        )
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> { .init(x, y, z) }
}

extension MTLPackedFloat4x3 {
    init(_ other: float4x4) {
        self.init(
            columns: (
                .init(other.columns.0.xyz),
                .init(other.columns.1.xyz),
                .init(other.columns.2.xyz),
                .init(other.columns.3.xyz)
            )
        )
    }
}

extension float4x4 {
    static var identity: Self { .init(1) }
}
