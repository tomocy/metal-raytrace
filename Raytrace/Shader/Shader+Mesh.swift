// tomocy

import Foundation
import ModelIO
import Metal
import MetalKit

extension MTKMesh {
    static func load(url: URL, with device: some MTLDevice) throws -> [MTKMesh] {
        let asset = MDLAsset.init(
            url: url,
            vertexDescriptor: Vertex.Interleaved.describe(),
            bufferAllocator: MTKMeshBufferAllocator.init(device: device)
        )

        let raws = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        return try raws.map {
            try .init(mesh: $0, device: device)
        }
    }
}

extension MTKMesh {
    func toNonInterleaved(with device: some MTLDevice) throws -> Self {
        // Assume that
        // the given mesh uses interleaved layout.
        assert(
            vertexDescriptor.defaultLayouts![0].stride == MemoryLayout<Vertex.Interleaved>.stride
        )

        let sourceBuffer = vertexBuffers.first!.buffer

        let count = sourceBuffer.length / vertexDescriptor.defaultLayouts!.first!.stride

        let vertices: (
            positions: [SIMD3<Float>.Packed],
            normals: [SIMD3<Float>.Packed],
            textureCoordinates: [SIMD2<Float>]
        ) = (
            sourceBuffer.contents().toArray(count: count) as [Vertex.Interleaved]
        ).reduce(
            into: ([], [], [])
        ) { result, v in
            result.positions.append(v.position)
            result.normals.append(v.normal)
            result.textureCoordinates.append(v.textureCoordinate)
        }

        let buffers: (
            positions: any MDLMeshBuffer,
            normals: any MDLMeshBuffer,
            textureCoordinates: any MDLMeshBuffer
        ) = ({
            let allocator = MTKMeshBufferAllocator.init(device: device)

            let positions = vertices.positions.withUnsafeBytes { bytes in
                allocator.newBuffer(
                    with: .init(bytes: bytes.baseAddress!, count: bytes.count),
                    type: .vertex
                )
            }

            let normals = vertices.normals.withUnsafeBytes { bytes in
                allocator.newBuffer(
                    with: .init(bytes: bytes.baseAddress!, count: bytes.count),
                    type: .vertex
                )
            }

            let textureCoordinates = vertices.textureCoordinates.withUnsafeBytes { bytes in
                allocator.newBuffer(
                    with: .init(bytes: bytes.baseAddress!, count: bytes.count),
                    type: .vertex
                )
            }

            return (positions, normals, textureCoordinates)
        }) ()


        return try .init(
            mesh: .init(
                vertexBuffers: [buffers.positions, buffers.normals, buffers.textureCoordinates],
                vertexCount: count,
                descriptor: Vertex.NonInterleaved.describe(),
                submeshes: submeshes.map {
                    .init(.init($0), indexType: .uInt16)
                }
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
    convenience init(_ other: MDLSubmesh, indexType: MDLIndexBitDepth) {
        self.init(
            name: other.name,
            indexBuffer: other.indexBuffer(asIndexType: indexType),
            indexCount: other.indexCount,
            indexType: indexType,
            geometryType: other.geometryType,
            material: nil
        )
    }

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
    struct Interleaved {
        var position: SIMD3<Float>.Packed
        var normal: SIMD3<Float>.Packed
        var textureCoordinate: SIMD2<Float>
    }

    struct NonInterleaved {}
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

extension MTKMesh.Vertex.Interleaved {
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

extension MTKMesh.Vertex.NonInterleaved {
    static func describe() -> MDLVertexDescriptor {
        let desc = MDLVertexDescriptor.init()

        let attrs = desc.defaultAttributes!
        let layouts = desc.defaultLayouts!

        do {
            let stride = MTKMesh.Vertex.describe(
                to: attrs[0],
                name: MDLVertexAttributePosition,
                format: .float3,
                offset: 0,
                bufferIndex: 0
            )

            layouts[0].stride = stride
        }
        do {
            let stride = MTKMesh.Vertex.describe(
                to: attrs[1],
                name: MDLVertexAttributeNormal,
                format: .float3,
                offset: 0,
                bufferIndex: 1
            )

            layouts[1].stride = stride
        }
        do {
            let stride = MTKMesh.Vertex.describe(
                to: attrs[2],
                name: MDLVertexAttributeTextureCoordinate,
                format: .float2,
                offset: 0,
                bufferIndex: 2
            )

            layouts[2].stride = stride
        }

        return desc
    }

    static func describe() -> MTLVertexDescriptor {
        let desc = MTLVertexDescriptor.init()

        let attrs = desc.attributes
        let layouts = desc.layouts

        do {
            let stride = MTKMesh.Vertex.describe(
                to: attrs[0],
                format: .float3,
                offset: 0,
                bufferIndex: 0
            )

            layouts[0].stride = stride
        }
        do {
            let stride = MTKMesh.Vertex.describe(
                to: attrs[1],
                format: .float3,
                offset: 0,
                bufferIndex: 1
            )

            layouts[1].stride = stride
        }
        do {
            let stride = MTKMesh.Vertex.describe(
                to: attrs[2],
                format: .float2,
                offset: 0,
                bufferIndex: 2
            )

            layouts[2].stride = stride
        }

        return desc
    }
}

extension MTLAttributeFormat {
    init?(_ other: MDLVertexFormat) {
        switch other {
        case .float3:
            self = .float3
        default:
            return nil
        }
    }
}
