// tomocy

import Metal

extension Raytrace {
    enum Primitive {}
}

extension Raytrace.Primitive {
    struct Instance {
        var meshID: UInt16
    }
}

extension Raytrace.Primitive {
    struct Data {
        var buffer: any MTLBuffer
        var stride: Int
    }

    struct Datum {
        var normals: [SIMD3<Float>.Packed]
        var textureCoordinates: [SIMD2<Float>]
    }
}

extension Raytrace.Primitive {
    struct Triangle {
        var normals: (SIMD3<Float>.Packed, SIMD3<Float>.Packed, SIMD3<Float>.Packed)
        var textureCoordinates: (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)
    }
}

extension Raytrace.Primitive.Triangle {
    init(_ other: Raytrace.Primitive.Datum) {
        self.init(
            normals: (other.normals[0], other.normals[1], other.normals[2]),
            textureCoordinates: (other.textureCoordinates[0], other.textureCoordinates[1], other.textureCoordinates[2])
        )
    }
}
