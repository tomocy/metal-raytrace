// tomocy

import ModelIO
import Metal
import MetalKit

extension Shader {
    struct Debug {
        var target: any MTLTexture
        var pipelineStates: PipelineStates
    }
}

extension Shader.Debug {
    init(device: any MTLDevice) {
        target = Self.makeTarget(with: device)!

        pipelineStates = .init(
            render: try! PipelineStates.make(with: device),
            depthStencil: PipelineStates.make(with: device)!
        )
    }
}

extension Shader.Debug {
    private static func makeTarget(with device: any MTLDevice) -> (any MTLTexture)? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: 2048, height: 2048,
            mipmapped: false
        )

        desc.storageMode = .private
        desc.usage = [.renderTarget, .shaderRead]

        return device.makeTexture(descriptor: desc)
    }
}

extension Shader.Debug {
    func encode(to buffer: MTLCommandBuffer) {
        let encoder = buffer.makeRenderCommandEncoder(
            descriptor: describe()
        )!
        defer { encoder.endEncoding() }

        encoder.setCullMode(.back)

        encoder.setRenderPipelineState(pipelineStates.render)
        encoder.setDepthStencilState(pipelineStates.depthStencil)

        do {
            let mesh = try! MTKMesh.useOnlyPositions(
                of: try! MTKMesh.init(
                    mesh: .init(
                        planeWithExtent: .init(1, 1, 0),
                        segments: .init(1, 1),
                        geometryType: .triangles,
                        allocator: MTKMeshBufferAllocator.init(device: encoder.device)
                    ),
                    device: encoder.device
                ),
                with: encoder.device
            )

            mesh.vertexBuffers.forEach { buffer in
                encoder.setVertexBuffer(
                    buffer.buffer,
                    offset: buffer.offset, index: 0
                )
            }

            mesh.submeshes.forEach { submesh in
                encoder.drawIndexedPrimitives(
                    type: submesh.primitiveType,
                    indexCount: submesh.indexCount,
                    indexType: submesh.indexType,
                    indexBuffer: submesh.indexBuffer.buffer,
                    indexBufferOffset: submesh.indexBuffer.offset
                )
            }
        }
    }

    private func describe() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor.init()

        let attach = desc.depthAttachment!

        attach.texture = target

        attach.loadAction = .clear
        attach.clearDepth = 1

        attach.storeAction = .store

        return desc
    }
}

extension Shader.Debug {
    struct PipelineStates {
        var render: any MTLRenderPipelineState
        var depthStencil: any MTLDepthStencilState
    }
}

extension Shader.Debug.PipelineStates {
    static func make(with device: any MTLDevice) throws -> any MTLRenderPipelineState {
        let desc: MTLRenderPipelineDescriptor = .init()

        desc.depthAttachmentPixelFormat = .depth32Float

        do {
            let lib = device.makeDefaultLibrary()!
            desc.vertexFunction = lib.makeFunction(name: "Debug::vertexMain")!
        }

        desc.vertexDescriptor = describe()

        return try device.makeRenderPipelineState(descriptor: desc)
    }

    static func describe() -> MTLVertexDescriptor {
            let desc = MTLVertexDescriptor.init()

            var stride = 0

            // float3 position
            stride += describe(
                to: desc.attributes[0],
                format: .float3,
                offset: stride,
                bufferIndex: 0
            )

            desc.layouts[0].stride = stride

            return desc
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

extension Shader.Debug.PipelineStates {
    static func make(with device: any MTLDevice) -> (any MTLDepthStencilState)? {
        let desc = MTLDepthStencilDescriptor.init()

        desc.isDepthWriteEnabled = true
        desc.depthCompareFunction = .less

        return device.makeDepthStencilState(descriptor: desc)
    }
}
