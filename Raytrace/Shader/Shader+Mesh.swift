// tomocy

import ModelIO
import Metal
import MetalKit

extension MTKMesh {
    static func useOnlyPositions(of mesh: MTKMesh, with device: some MTLDevice) throws -> Self {
        // Support only Vertex.Default layout.

        let sourceBuffer = mesh.vertexBuffers.first!.buffer

        let count = sourceBuffer.length / mesh.vertexDescriptor.defaultLayouts!.first!.stride

        let allocator = MTKMeshBufferAllocator.init(device: device)
        let vertices: [Vertex.OnlyPositions] = (
            sourceBuffer.contents().toArray(count: count) as [Vertex.Default]
        ).map {
            .init(position: $0.position)
        }
        let buffer = vertices.withUnsafeBytes { bytes in
            allocator.newBuffer(
                with: .init(bytes: bytes.baseAddress!, count: bytes.count),
                type: .vertex
            )
        }

        return try .init(
            mesh: .init(
                vertexBuffer: buffer,
                vertexCount: count,
                descriptor: Vertex.OnlyPositions.describe(),
                submeshes: mesh.submeshes.map { .init($0) }
            ),
            device: device
        )
    }
}

extension MDLVertexDescriptor {
    var defaultAttributes: [MDLVertexAttribute]? { attributes as? [MDLVertexAttribute] }
    var defaultLayouts: [MDLVertexBufferLayout]? { layouts as? [MDLVertexBufferLayout] }
}

extension MDLSubmesh {
    convenience init(_ other: MTKSubmesh) {
        self.init(
            name: other.name,
            indexBuffer: other.indexBuffer,
            indexCount: other.indexCount,
            indexType: .init(other.indexType)!,
            geometryType: .init(other.primitiveType)!,
            material: nil
        )
    }
}

extension MDLIndexBitDepth {
    init?(_ other: MTLIndexType) {
        switch other {
        case .uint16:
            self = .uInt16
        case .uint32:
            self = .uint32
        default:
            return nil
        }
    }
}

extension MDLGeometryType {
    init?(_ other: MTLPrimitiveType) {
        switch other {
        case .point:
            self = .points
        case .line:
            self = .lines
        case .triangle:
            self = .triangles
        case .triangleStrip:
            self = .triangleStrips
        default:
            return nil
        }
    }
}

extension MTKMesh {
    enum Vertex {}
}

extension MTKMesh.Vertex {
    struct Default {
        var position: SIMD3<Float>.Packed
        var normal: SIMD3<Float>.Packed
        var textureCoordinate: SIMD2<Float>
    }

    struct OnlyPositions {
        var position: SIMD3<Float>.Packed
    }
}

extension MTKMesh.Vertex.OnlyPositions {
    static func describe() -> MDLVertexDescriptor {
        let desc = MDLVertexDescriptor.init()

        var stride = 0

        do {
            let attrs = desc.defaultAttributes!

            attrs[0].name = MDLVertexAttributePosition
            attrs[0].format = .float3
            attrs[0].offset = stride
            attrs[0].bufferIndex = 0
            stride += MemoryLayout<SIMD3<Float>.Packed>.stride
        }

        do {
            let layouts = desc.defaultLayouts!

            layouts[0].stride = stride
        }

        return desc
    }
}

