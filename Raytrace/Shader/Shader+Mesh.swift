// tomocy

import Foundation
import ModelIO
import Metal
import MetalKit

extension MTKMesh {
    static func load(url: URL, with device: some MTLDevice) throws -> [MTKMesh] {
        let asset = MDLAsset.init(
            url: url,
            vertexDescriptor: Vertex.Default.describe(),
            bufferAllocator: MTKMeshBufferAllocator.init(device: device)
        )

        let raws = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        return try raws.map {
            try .init(mesh: $0, device: device)
        }
    }
}

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

extension MTKMesh.Vertex {
    static func describe(
        to attribute: MDLVertexAttribute,
        name: String,
        format: MDLVertexFormat,
        offset: Int,
        bufferIndex: Int
    ) -> Int {
        attribute.name = name
        attribute.format = format
        attribute.offset = offset
        attribute.bufferIndex = bufferIndex

        switch format {
        case .float2:
            return MemoryLayout<SIMD2<Float>>.stride
        case .float3:
            return MemoryLayout<SIMD3<Float>.Packed>.stride
        default:
            return 0
        }
    }

    static func describe(
        to descriptor: MTLVertexAttributeDescriptor,
        format: MTLVertexFormat,
        offset: Int,
        bufferIndex: Int
    ) -> Int {
        descriptor.format = format
        descriptor.offset = offset
        descriptor.bufferIndex = bufferIndex

        switch format {
        case .float2:
            return MemoryLayout<SIMD2<Float>>.stride
        case .float3:
            return MemoryLayout<SIMD3<Float>.Packed>.stride
        default:
            return 0
        }
    }
}

extension MTKMesh.Vertex.Default {
    static func describe() -> MDLVertexDescriptor {
        let desc = MDLVertexDescriptor.init()

        var stride = 0

        do {
            let attrs = desc.defaultAttributes!

            stride += MTKMesh.Vertex.describe(
                to: attrs[0],
                name: MDLVertexAttributePosition,
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MTKMesh.Vertex.describe(
                to: attrs[1],
                name: MDLVertexAttributeNormal,
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MTKMesh.Vertex.describe(
                to: attrs[2],
                name: MDLVertexAttributeTextureCoordinate,
                format: .float2,
                offset: stride,
                bufferIndex: 0
            )
        }

        do {
            let layouts = desc.defaultLayouts!

            layouts[0].stride = stride
        }

        return desc
    }

    static func describe() -> MTLVertexDescriptor {
        let desc = MTLVertexDescriptor.init()

        var stride = 0

        do {
            let attrs = desc.attributes

            stride += MTKMesh.Vertex.describe(
                to: attrs[0],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MTKMesh.Vertex.describe(
                to: attrs[1],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MTKMesh.Vertex.describe(
                to: attrs[2],
                format: .float2,
                offset: stride,
                bufferIndex: 0
            )
        }

        do {
            let layouts = desc.layouts

            layouts[0].stride = stride
        }

        return desc
    }
}

extension MTKMesh.Vertex.OnlyPositions {
    static func describe() -> MDLVertexDescriptor {
        let desc = MDLVertexDescriptor.init()

        var stride = 0

        do {
            let attrs = desc.defaultAttributes!

            stride += MTKMesh.Vertex.describe(
                to: attrs[0],
                name: MDLVertexAttributePosition,
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )
        }

        do {
            let layouts = desc.defaultLayouts!

            layouts[0].stride = stride
        }

        return desc
    }

    static func describe() -> MTLVertexDescriptor {
        let desc = MTLVertexDescriptor.init()

        var stride = 0

        do {
            let attrs = desc.attributes

            stride += MTKMesh.Vertex.describe(
                to: attrs[0],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )
        }

        do {
            let layouts = desc.layouts

            layouts[0].stride = stride
        }

        return desc
    }

    static func describe(to descriptor: MTLAccelerationStructureTriangleGeometryDescriptor) {
        descriptor.vertexFormat = .float3
        descriptor.vertexStride = MemoryLayout<Self>.stride
    }
}
