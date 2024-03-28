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
    func encode(_ mesh: MTKMesh, to buffer: MTLCommandBuffer) {
        let encoder = buffer.makeRenderCommandEncoder(
            descriptor: describe()
        )!
        defer { encoder.endEncoding() }

        encoder.setCullMode(.back)

        encoder.setRenderPipelineState(pipelineStates.render)
        encoder.setDepthStencilState(pipelineStates.depthStencil)

        do {
            mesh.vertexBuffers.forEach { buffer in
                encoder.setVertexBuffer(
                    buffer.buffer,
                    offset: buffer.offset,
                    index: 0
                )
            }

            let projection = Shader.Transform.identity
            let view = Shader.Transform.translate(
                .init(0, 0, 2)
            )
            let matrix = projection * view

            withUnsafeBytes(of: matrix) { bytes in
                let buffer = encoder.device.makeBuffer(
                    bytes: bytes.baseAddress!,
                    length: bytes.count,
                    options: .storageModeShared
                )

                encoder.setVertexBuffer(buffer, offset: 0, index: 1)
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

        do {
            attach.loadAction = .clear
            attach.clearDepth = 1
        }
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

        desc.vertexDescriptor = MTKMesh.Vertex.OnlyPositions.describe()

        return try device.makeRenderPipelineState(descriptor: desc)
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
