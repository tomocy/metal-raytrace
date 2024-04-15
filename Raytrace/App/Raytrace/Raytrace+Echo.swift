// tomocy

import Metal

extension Raytrace {
    struct Echo {
        var pipelineStates: PipelineStates
    }
}

extension Raytrace.Echo {
    init(device: some MTLDevice, format: MTLPixelFormat) throws {
        pipelineStates = .init(
            render: try PipelineStates.make(with: device, format: format)
        )
    }
}

extension Raytrace.Echo {
    func encode(
        to buffer: some MTLCommandBuffer,
        as descriptor: MTLRenderPassDescriptor,
        source: some MTLTexture
    ) {
        let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor)!
        defer { encoder.endEncoding() }

        encoder.label = "Echo"

        encoder.setRenderPipelineState(pipelineStates.render)

        encoder.setFragmentTexture(source, index: 0)

        // Fullscreen in NDC
        let vertices: [SIMD2<Float>] = [
            .init(-1, 1),
            .init(1, 1),
            .init(1, -1),
            .init(-1, -1),
        ]

        do {
            let buffer = Raytrace.Metal.bufferBuildable(vertices).build(
                with: encoder.device,
                label: "Vertices",
                options: .storageModeShared
            )!

            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        }

        let indices: [UInt16] = [
            0, 1, 2,
            2, 3, 0,
        ]

        do {
            let buffer = Raytrace.Metal.bufferBuildable(indices).build(
                with: encoder.device,
                label: "Indices",
                options: .storageModeShared
            )!

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

extension Raytrace.Echo {
    struct PipelineStates {
        var render: any MTLRenderPipelineState
    }
}

extension Raytrace.Echo.PipelineStates {
    static func make(with device: some MTLDevice, format: MTLPixelFormat) throws -> some MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor.init()

        do {
            let lib = device.makeDefaultLibrary()!

            desc.vertexFunction = lib.makeFunction(name: "Raytrace::Echo::Vertex::compute")!
            desc.fragmentFunction = lib.makeFunction(name: "Raytrace::Echo::Fragment::compute")!
        }

        desc.colorAttachments[0].pixelFormat = format

        return try device.makeRenderPipelineState(descriptor: desc)
    }
}
