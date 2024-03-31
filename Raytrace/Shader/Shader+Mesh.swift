// tomocy

import Foundation
import ModelIO
import Metal
import MetalKit

extension Shader {
    struct Mesh {
        var positions: Positions
        var pieces: [Piece]
        var accelerator: (any MTLAccelerationStructure)?

        var instances: [Instance]
    }
}

extension Shader.Mesh {
    struct Positions {
        var buffer: any MTLBuffer
        var format: MTLAttributeFormat
        var stride: Int
    }
}

extension Shader.Mesh {
    struct Piece {
        var type: MTLPrimitiveType
        var indices: Indices
        var data: Shader.Primitive.Data
        var material: Shader.Material?
    }
}

extension Shader.Mesh {
    struct Instance {
        var transform: Shader.Transform
    }
}

extension Shader.Mesh {
    struct Indices {
        var buffer: any MTLBuffer
        var type: MTLIndexType
        var count: Int
    }
}

extension MDLMesh {
    static func load(url: URL, with device: some MTLDevice) throws -> [MDLMesh] {
        let asset = MDLAsset.init(
            url: url,
            vertexDescriptor: Self.Layout.PNT.describe(),
            bufferAllocator: MTKMeshBufferAllocator.init(device: device)
        )

        asset.loadTextures()

        return asset.childObjects(of: Self.self) as! [Self]
    }
}

extension MDLMesh {
    convenience init(_ other: MDLMesh, indexType: MDLIndexBitDepth) {
        self.init(
            vertexBuffers: other.vertexBuffers,
            vertexCount: other.vertexCount,
            descriptor: other.vertexDescriptor,
            submeshes: other.defaultSubmeshes!.map { .init($0, indexType: indexType) }
        )
    }
}

extension MDLMesh {
    var defaultSubmeshes: [MDLSubmesh]? { submeshes as? [MDLSubmesh] }
}

extension MDLMesh {
    func toP_NT(with device: some MTLDevice, indexType: MDLIndexBitDepth) -> Self {
        assert(
            vertexDescriptor.defaultLayouts![0].stride == MemoryLayout<Layout.PNT>.stride
        )

        let vertices: [Layout.PNT] = vertexBuffers.first!.contents().toArray(count: vertexCount)
        let buffers = Layout.P_NT.layOut(vertices, with: MTKMeshBufferAllocator.init(device: device))

        return .init(
            vertexBuffers: buffers,
            vertexCount: vertexCount,
            descriptor: Layout.P_NT.describe(),
            submeshes: defaultSubmeshes!.map { .init($0, indexType: indexType) }
        )
    }

    func toP_N_T(with device: some MTLDevice, indexType: MDLIndexBitDepth) -> Self {
        assert(
            vertexDescriptor.defaultLayouts![0].stride == MemoryLayout<Layout.PNT>.stride
        )

        let vertices: [Layout.PNT] = vertexBuffers.first!.contents().toArray(count: vertexCount)
        let buffers = Layout.P_N_T.layOut(vertices, with: MTKMeshBufferAllocator.init(device: device))

        return .init(
            vertexBuffers: buffers,
            vertexCount: vertexCount,
            descriptor: Layout.P_N_T.describe(),
            submeshes: defaultSubmeshes!.map { .init($0, indexType: indexType) }
        )
    }
}

extension MDLMesh {
    func toMesh(with device: some MTLDevice, instances: [Shader.Mesh.Instance]) throws -> Shader.Mesh {
        assert(
            vertexDescriptor.defaultLayouts![0].stride == MemoryLayout<Layout.PNT>.stride
        )

        let vertices: [Layout.PNT] = vertexBuffers.first!.contents().toArray(count: vertexCount)

        let positions = Shader.Mesh.Positions.init(
            buffer: vertices.map { $0.position }.toBuffer(with: device, options: .storageModeShared)!,
            format: .float3,
            stride: MemoryLayout<SIMD3<Float>.Packed>.stride
        )

        let pieces = try defaultSubmeshes!.map { submesh in
            assert(submesh.geometryType == .triangles)
            assert(submesh.indexType == .uint16)

            let indices: [UInt16] = submesh.indexBuffer.contents().toArray(count: submesh.indexCount)

            var data: [Shader.Primitive.Triangle] = []
            let primitiveCount = indices.count / 3
            for primitiveI in 0..<primitiveCount {
                var datum = Shader.Primitive.Datum.init(
                    normals: [],
                    textureCoordinates: []
                )

                for vertexI in 0..<3 {
                    let i = Int(indices[primitiveI * 3 + vertexI])
                    let v = vertices[i]

                    datum.normals.append(v.normal)
                    datum.textureCoordinates.append(v.textureCoordinate)
                }

                data.append(.init(datum))
            }

            return Shader.Mesh.Piece.init(
                type: .triangle,
                indices: .init(
                    buffer: indices.toBuffer(with: device, options: .storageModeShared)!,
                    type: .uint16,
                    count: indices.count
                ),
                data: .init(
                    buffer: data.toBuffer(with: device, options: .storageModeShared)!,
                    stride: MemoryLayout<Shader.Primitive.Triangle>.stride
                ),
                material: try .init(submesh.material, device: device)
            )
        }

        return .init(
            positions: positions,
            pieces: pieces,
            instances: instances
        )
    }
}

extension MDLMeshBuffer {
    func contents() -> UnsafeMutableRawPointer { map().bytes }
}

extension Array {
    func toBuffer(with device: some MTLDevice, options: MTLResourceOptions) -> (any MTLBuffer)? {
        return withUnsafeBytes { bytes in
            device.makeBuffer(
                bytes: bytes.baseAddress!,
                length: bytes.count,
                options: options
            )
        }
    }

    func toBuffer(with allocator: some MDLMeshBufferAllocator, type: MDLMeshBufferType) -> any MDLMeshBuffer {
        return withUnsafeBytes { bytes in
            allocator.newBuffer(
                with: .init(bytes: bytes.baseAddress!, count: bytes.count),
                type: type
            )
        }
    }
}

extension MDLSubmesh {
    convenience init(_ other: MDLSubmesh, indexType: MDLIndexBitDepth) {
        self.init(
            name: other.name,
            indexBuffer: other.indexBuffer(asIndexType: indexType),
            indexCount: other.indexCount,
            indexType: indexType,
            geometryType: other.geometryType,
            material: other.material
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

        struct P {
            var position: SIMD3<Float>.Packed
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
    static func layOut(
        _ vertices: [MDLMesh.Layout.PNT],
        with allocator: some MDLMeshBufferAllocator
    ) -> [some MDLMeshBuffer] {
        return [
            vertices.toBuffer(with: allocator, type: .vertex)
        ]
    }
}

extension MDLMesh.Layout.PNT {
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

            layouts[0].stride = stride
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

            layouts[0].stride = stride
        }

        return desc
    }
}

extension MDLMesh.Layout.P {
    static func layOut(
        _ vertices: [MDLMesh.Layout.PNT],
        with allocator: some MDLMeshBufferAllocator
    ) -> [some MDLMeshBuffer] {
        return [
            vertices.map({ $0.position }).toBuffer(with: allocator, type: .vertex)
        ]
    }
}

extension MDLMesh.Layout.P {
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

        return desc
    }
}


extension MDLMesh.Layout.P_NT {
    static func layOut(
        _ vertices: [MDLMesh.Layout.PNT],
        with allocator: some MDLMeshBufferAllocator
    ) -> [some MDLMeshBuffer] {
        let (p, nt): (p: [P], nt: [NT]) = vertices.reduce(
            into: ([], [])
        ) { result, v in
            result.p.append(
                .init(position: v.position)
            )

            result.nt.append(
                .init(
                    normal: v.normal,
                    textureCoordinate: v.textureCoordinate
                )
            )
        }

        return [
            p.toBuffer(with: allocator, type: .vertex),
            nt.toBuffer(with: allocator, type: .vertex),
        ]
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
    static func layOut(
        _ vertices: [MDLMesh.Layout.PNT],
        with allocator: some MDLMeshBufferAllocator
    ) -> [some MDLMeshBuffer] {
        let (p, n, t): (p: [P], n: [N], t: [T]) = vertices.reduce(
            into: ([], [], [])
        ) { result, v in
            result.p.append(
                .init(position: v.position)
            )
            result.n.append(
                .init(normal: v.normal)
            )
            result.t.append(
                .init(textureCoordinate: v.textureCoordinate)
            )
        }

        return [
            p.toBuffer(with: allocator, type: .vertex),
            n.toBuffer(with: allocator, type: .vertex),
            t.toBuffer(with: allocator, type: .vertex)
        ]
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
