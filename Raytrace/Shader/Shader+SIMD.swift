// tomocy

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
    init(_ other: SIMD3<Float>) {
        self.init(
            .init(elements: (other.x, other.y, other.z))
        )
    }
}
