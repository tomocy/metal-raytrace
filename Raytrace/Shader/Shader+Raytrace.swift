// tomocy

import ModelIO
import Metal
import MetalKit

extension Shader {
    struct Raytrace {
        var target: Target
        var pipelineStates: PipelineStates
    }
}

extension Shader.Raytrace {
    init(device: some MTLDevice, resolution: CGSize, format: MTLPixelFormat) throws {
        target = Self.makeTarget(with: device, resolution: resolution, format: format)!

        pipelineStates = .init(
            compute: try PipelineStates.make(with: device)
        )
    }
}

extension Shader.Raytrace {
    static func makeTarget(
        with device: some MTLDevice,
        resolution: CGSize,
        format: MTLPixelFormat
    ) -> Target? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: .init(resolution.width), height: .init(resolution.height),
            mipmapped: false
        )

        desc.storageMode = .private
        desc.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        return .init(resolution: resolution, texture: texture)
    }
}

extension Shader.Raytrace {
    func encode(
        to buffer: some MTLCommandBuffer,
        accelerator: some MTLAccelerationStructure,
        albedoTexture: some MTLTexture
    ) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        encoder.setTexture(target.texture, index: 0)
        encoder.setAccelerationStructure(accelerator, bufferIndex: 0)

        encoder.setTexture(albedoTexture, index: 1)

        do {
            let threadsPerGroup = MTLSize.init(width: 8, height: 8, depth: 1)

            encoder.dispatchThreadgroups(
                .init(
                    width: Int(target.resolution.width).align(by: threadsPerGroup.width) / threadsPerGroup.width,
                    height: Int(target.resolution.height).align(by: threadsPerGroup.height) / threadsPerGroup.height,
                    depth: threadsPerGroup.depth
                ),
                threadsPerThreadgroup: threadsPerGroup
            )
        }
    }
}

extension Shader.Raytrace {
    struct Target {
        var resolution: CGSize
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
            function: lib.makeFunction(name: "Raytrace::kernelMain")!
        )
    }
}
