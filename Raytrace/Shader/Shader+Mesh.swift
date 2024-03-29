// tomocy

import Foundation
import ModelIO
import Metal
import MetalKit

extension MDLMesh {
    static func load(url: URL, with device: some MTLDevice) throws -> [MDLMesh] {
        let asset = MDLAsset.init(
            url: url,
            vertexDescriptor: Self.Layout.PNT.describe(),
            bufferAllocator: MTKMeshBufferAllocator.init(device: device)
        )

        return asset.childObjects(of: Self.self) as! [Self]
    }
}

extension MDLMesh {
    var defaultSubmeshes: [MDLSubmesh]? { submeshes as? [MDLSubmesh] }
}

extension MDLMesh {
    func toP_N_T(with device: some MTLDevice, indexType: MDLIndexBitDepth) -> Self {
        // Assume that
        // the given mesh uses PNT layout.
        assert(
            vertexDescriptor.defaultLayouts![0].stride == MemoryLayout<Layout.PNT>.stride
        )

        let sourceBuffer = vertexBuffers.first!

        let count = sourceBuffer.length / vertexDescriptor.defaultLayouts!.first!.stride

        let vertices: (
            positions: [SIMD3<Float>.Packed],
            normals: [SIMD3<Float>.Packed],
            textureCoordinates: [SIMD2<Float>]
        ) = (
            sourceBuffer.contents().toArray(count: count) as [Layout.PNT]
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


        return .init(
            vertexBuffers: [buffers.positions, buffers.normals, buffers.textureCoordinates],
            vertexCount: count,
            descriptor: Layout.P_N_T.describe(),
            submeshes: defaultSubmeshes!.map { .init($0, indexType: indexType) }
        )
    }
}

extension MDLMeshBuffer {
    func contents() -> UnsafeMutableRawPointer { map().bytes }
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

extension MDLVertexDescriptor {
    var defaultAttributes: [MDLVertexAttribute]? { attributes as? [MDLVertexAttribute] }
    var defaultLayouts: [MDLVertexBufferLayout]? { layouts as? [MDLVertexBufferLayout] }
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

extension MDLMesh {
    enum Layout {
        struct PNT {
            var position: SIMD3<Float>.Packed
            var normal: SIMD3<Float>.Packed
            var textureCoordinate: SIMD2<Float>
        }

        enum P_NT {
            struct P {
                var position: SIMD3<Float>.Packed
            }

            struct NT {
                var normal: SIMD3<Float>.Packed
                var textureCoordinate: SIMD2<Float>
            }
        }

        enum P_N_T {
            struct P {
                var position: SIMD3<Float>.Packed
            }

            struct N {
                var normal: SIMD3<Float>.Packed
            }

            struct T {
                var textureCoordinate: SIMD2<Float>
            }
        }
    }
}

extension MDLMesh.Layout {
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

extension MDLMesh.Layout.PNT {
    static func describe() -> MDLVertexDescriptor {
        let desc = MDLVertexDescriptor.init()

        var stride = 0

        do {
            let attrs = desc.defaultAttributes!

            stride += MDLMesh.Layout.describe(
                to: attrs[0],
                name: MDLVertexAttributePosition,
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MDLMesh.Layout.describe(
                to: attrs[1],
                name: MDLVertexAttributeNormal,
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MDLMesh.Layout.describe(
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

            stride += MDLMesh.Layout.describe(
                to: attrs[0],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MDLMesh.Layout.describe(
                to: attrs[1],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MDLMesh.Layout.describe(
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

extension MDLMesh.Layout.P_NT {
    static func describe() -> MDLVertexDescriptor {
        let desc = MDLVertexDescriptor.init()

        let attrs = desc.defaultAttributes!
        let layouts = desc.defaultLayouts!

        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[0],
                name: MDLVertexAttributePosition,
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            layouts[0].stride = stride
        }

        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[1],
                name: MDLVertexAttributeNormal,
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MDLMesh.Layout.describe(
                to: attrs[2],
                name: MDLVertexAttributeTextureCoordinate,
                format: .float2,
                offset: stride,
                bufferIndex: 0
            )

            layouts[1].stride = stride
        }

        return desc
    }

    static func describe() -> MTLVertexDescriptor {
        let desc = MTLVertexDescriptor.init()

        let attrs = desc.attributes
        let layouts = desc.layouts

        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[0],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            layouts[0].stride = stride
        }

        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[1],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            stride += MDLMesh.Layout.describe(
                to: attrs[2],
                format: .float2,
                offset: stride,
                bufferIndex: 0
            )

            layouts[1].stride = stride
        }

        return desc
    }
}


extension MDLMesh.Layout.P_N_T {
    static func describe() -> MDLVertexDescriptor {
        let desc = MDLVertexDescriptor.init()

        let attrs = desc.defaultAttributes!
        let layouts = desc.defaultLayouts!

        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[0],
                name: MDLVertexAttributePosition,
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            layouts[0].stride = stride
        }
        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[1],
                name: MDLVertexAttributeNormal,
                format: .float3,
                offset: stride,
                bufferIndex: 1
            )

            layouts[1].stride = stride
        }
        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[2],
                name: MDLVertexAttributeTextureCoordinate,
                format: .float2,
                offset: stride,
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
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[0],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            layouts[0].stride = stride
        }
        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[1],
                format: .float3,
                offset: stride,
                bufferIndex: 1
            )

            layouts[1].stride = stride
        }
        do {
            var stride = 0

            stride += MDLMesh.Layout.describe(
                to: attrs[2],
                format: .float2,
                offset: stride,
                bufferIndex: 2
            )

            layouts[2].stride = stride
        }

        return desc
    }
}
