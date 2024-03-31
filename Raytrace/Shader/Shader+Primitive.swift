// tomocy

import Metal

extension Shader {
    struct Primitive {
        var positions: Positions
        var pieces: [Piece]
        var accelerator: (any MTLAccelerationStructure)?

        var instances: [Instance]
    }
}

extension Shader.Primitive {
    struct Positions {
        var buffer: any MTLBuffer
        var format: MTLAttributeFormat
        var stride: Int
    }
}

extension Shader.Primitive {
    struct Piece {
        var type: MTLPrimitiveType
        var indices: Indices
        var data: Data
        var material: Shader.Material?
    }
}

extension Shader.Primitive {
    struct Instance {
        var transform: Shader.Transform
    }
}

extension Shader.Primitive {
    struct Indices {
        var buffer: any MTLBuffer
        var type: MTLIndexType
        var count: Int
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
