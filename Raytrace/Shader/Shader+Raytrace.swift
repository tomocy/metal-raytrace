// tomocy

import Metal

extension Shader {
    struct Raytrace {
        var target: Target
        var pipelineStates: PipelineStates
    }
}

extension Shader.Raytrace {
    init(device: some MTLDevice, size: CGSize, format: MTLPixelFormat) throws {
        target = Self.makeTarget(with: device, size: size, format: format)!

        pipelineStates = .init(
            compute: try PipelineStates.make(with: device)
        )
    }
}

extension Shader.Raytrace {
    static func makeTarget(
        with device: some MTLDevice,
        size: CGSize,
        format: MTLPixelFormat
    ) -> Target? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: .init(size.width), height: .init(size.height),
            mipmapped: false
        )

        desc.storageMode = .private
        desc.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        return .init(size: size, texture: texture)
    }
}

extension Shader.Raytrace {
    func encode(to buffer: some MTLCommandBuffer, accelerator: some MTLAccelerationStructure) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        encoder.setTexture(target.texture, index: 0)
        encoder.setAccelerationStructure(accelerator, bufferIndex: 0)

        do {
            let threadsPerGroup = MTLSize.init(width: 8, height: 8, depth: 1)

            encoder.dispatchThreadgroups(
                .init(
                    width: Int(target.size.width).align(by: threadsPerGroup.width) / threadsPerGroup.width,
                    height: Int(target.size.height).align(by: threadsPerGroup.height) / threadsPerGroup.height,
                    depth: threadsPerGroup.depth
                ),
                threadsPerThreadgroup: threadsPerGroup
            )
        }
    }
}

extension Shader.Raytrace {
    struct Target {
        var size: CGSize
        var texture: any MTLTexture
    }
}

extension Shader.Raytrace {
    struct PipelineStates {
        var compute: any MTLComputePipelineState
    }
}

extension Shader.Raytrace.PipelineStates {
    static func make(with device: some MTLDevice) throws -> some MTLComputePipelineState {
        let lib = device.makeDefaultLibrary()!

        return try device.makeComputePipelineState(
            function: lib.makeFunction(name: "Raytrace::compute")!
        )
    }
}
