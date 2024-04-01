// tomocy

import Metal

extension Shader {
    enum Primitive {}
}

extension Shader.Primitive {
    struct Instance {
        var meshID: UInt16
    }
}

extension Shader.Primitive {
    struct Data {
        var buffer: any MTLBuffer
        var stride: Int
    }

    struct Datum {
        var normals: [SIMD3<Float>.Packed]
        var textureCoordinates: [SIMD2<Float>]
    }
}

extension Shader.Primitive {
    struct Triangle {
        var normals: (SIMD3<Float>.Packed, SIMD3<Float>.Packed, SIMD3<Float>.Packed)
        var textureCoordinates: (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)
    }
}

extension Shader.Primitive.Triangle {
    init(_ other: Shader.Primitive.Datum) {
        self.init(
            normals: (other.normals[0], other.normals[1], other.normals[2]),
            textureCoordinates: (other.textureCoordinates[0], other.textureCoordinates[1], other.textureCoordinates[2])
        )
    }
}
