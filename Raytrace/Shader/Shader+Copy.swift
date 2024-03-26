// tomocy

import Metal

extension Shader {
    struct Copy {
        var pipelineStates: PipelineStates
    }
}

extension Shader.Copy {
    init(device: some MTLDevice, format: MTLPixelFormat) throws {
        pipelineStates = .init(
            render: try PipelineStates.make(with: device, format: format)
        )
    }
}

extension Shader.Copy {
    func encode(
        to buffer: some MTLCommandBuffer,
        as descriptor: MTLRenderPassDescriptor,
        source: some MTLTexture
    ) {
        let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor)!
        defer { encoder.endEncoding() }

        encoder.setRenderPipelineState(pipelineStates.render)

        encoder.setFragmentTexture(source, index: 0)

        // Fullscreen in NDC
        let vertices: [SIMD2<Float>] = [
            .init(-1, 1),
            .init(1, 1),
            .init(1, -1),
            .init(-1, -1),
        ]

        vertices.withUnsafeBytes { bytes in
            let buffer = encoder.device.makeBuffer(
                bytes: bytes.baseAddress!,
                length: bytes.count,
                options: .storageModeShared
            )!
            buffer.label = "Vertices"

            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        }

        let indices: [UInt16] = [
            0, 1, 2,
            2, 3, 0,
        ]

        indices.withUnsafeBytes { bytes in
            let buffer = encoder.device.makeBuffer(
                bytes: bytes.baseAddress!,
                length: bytes.count,
                options: .storageModeShared
            )!
            buffer.label = "Indices"

            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: indices.count,
                indexType: .uint16,
                indexBuffer: buffer,
                indexBufferOffset: 0
            )
        }
    }
}

extension Shader.Copy {
    struct PipelineStates {
        var render: any MTLRenderPipelineState
    }
}

extension Shader.Copy.PipelineStates {
    static func make(with device: some MTLDevice, format: MTLPixelFormat) throws -> some MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor.init()

        do {
            let lib = device.makeDefaultLibrary()

            desc.vertexFunction = lib?.makeFunction(name: "Copy::vertexMain")!
            desc.fragmentFunction = lib?.makeFunction(name: "Copy::fragmentMain")!
        }

        desc.colorAttachments[0].pixelFormat = format

        return try device.makeRenderPipelineState(descriptor: desc)
    }
}
