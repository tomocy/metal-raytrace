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
        _ primitives: [Shader.Primitive],
        to buffer: some MTLCommandBuffer,
        accelerator: some MTLAccelerationStructure
    ) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        encoder.setTexture(target.texture, index: 0)
        encoder.setAccelerationStructure(accelerator, bufferIndex: 0)

        let threadsSizePerGroup = MTLSize.init(width: 8, height: 8, depth: 1)
        let threadsGroupSize = MTLSize.init(
            width: Int(target.resolution.width).align(by: threadsSizePerGroup.width) / threadsSizePerGroup.width,
            height: Int(target.resolution.height).align(by: threadsSizePerGroup.height) / threadsSizePerGroup.height,
            depth: threadsSizePerGroup.depth
        )

        primitives.forEach { primitive in
            primitive.pieces.forEach { piece in
                encoder.setTexture(piece.material?.albedo, index: 1)

                encoder.dispatchThreadgroups(
                    threadsGroupSize,
                    threadsPerThreadgroup: threadsSizePerGroup
                )
            }
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
