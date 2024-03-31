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
    func encode(_ meshes: [Shader.Mesh], to buffer: MTLCommandBuffer) {
        let encoder = buffer.makeRenderCommandEncoder(
            descriptor: describe()
        )!
        defer { encoder.endEncoding() }

        encoder.setCullMode(.back)

        encoder.setRenderPipelineState(pipelineStates.render)
        encoder.setDepthStencilState(pipelineStates.depthStencil)

        meshes.forEach { mesh in
            do {
                let projection = Shader.Transform.orthogonal(
                    top: 1, bottom: -1,
                    left: -1, right: 1,
                    near: 0, far: 10
                )
                let view = Shader.Transform.translate(
                    .init(0, 0.5 * -1, -2 * -1)
                )
                let aspect = projection * view

                let buffer = withUnsafeBytes(of: aspect) { bytes in
                    encoder.device.makeBuffer(
                        bytes: bytes.baseAddress!,
                        length: bytes.count,
                        options: .storageModeShared
                    )
                }

                encoder.setVertexBuffer(buffer, offset: 0, index: 1)
            }

            do {
                let instances = mesh.instances.map { $0.transform.resolve() }

                let buffer = instances.withUnsafeBytes { bytes in
                    encoder.device.makeBuffer(
                        bytes: bytes.baseAddress!,
                        length: bytes.count,
                        options: .storageModeShared
                    )
                }

                encoder.setVertexBuffer(buffer, offset: 0, index: 2)
            }

            encoder.setVertexBuffer(
                mesh.positions.buffer,
                offset: 0,
                index: 0
            )

            mesh.pieces.forEach { piece in
                encoder.drawIndexedPrimitives(
                    type: piece.type,
                    indexCount: piece.indices.count,
                    indexType: piece.indices.type,
                    indexBuffer: piece.indices.buffer,
                    indexBufferOffset: 0,
                    instanceCount: mesh.instances.count
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

        desc.vertexDescriptor = MDLMesh.Layout.P.describe()

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
