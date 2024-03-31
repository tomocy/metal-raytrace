// tomocy

import ModelIO
import Metal
import MetalKit

extension Shader {
    struct Raytrace {
        var target: Target
        var pipelineStates: PipelineStates
        var argumentEncoders: ArgumentEncoders
    }
}

extension Shader.Raytrace {
    init(device: some MTLDevice, resolution: CGSize, format: MTLPixelFormat) throws {
        target = Self.makeTarget(with: device, resolution: resolution, format: format)!

        pipelineStates = .init(
            compute: try PipelineStates.make(with: device)
        )

        argumentEncoders = .init(
            meshes: ArgumentEncoders.makeMeshes(with: device)
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
        _ meshes: [Shader.Mesh],
        to buffer: some MTLCommandBuffer,
        accelerator: some MTLAccelerationStructure
    ) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        encoder.setTexture(target.texture, index: 0)
        encoder.setAccelerationStructure(accelerator, bufferIndex: 0)

        do {
            let buffer = build(
                with: .init(
                    compute: encoder,
                    argument: argumentEncoders.meshes
                ),
                for: meshes
            )
            buffer.label = "Meshes"

            encoder.setBuffer(buffer, offset: 0, index: 1)
        }

        do {
            let threadsSizePerGroup = MTLSize.init(width: 8, height: 8, depth: 1)
            let threadsGroupSize = MTLSize.init(
                width: Int(target.resolution.width).align(by: threadsSizePerGroup.width) / threadsSizePerGroup.width,
                height: Int(target.resolution.height).align(by: threadsSizePerGroup.height) / threadsSizePerGroup.height,
                depth: threadsSizePerGroup.depth
            )

            encoder.dispatchThreadgroups(
                threadsGroupSize,
                threadsPerThreadgroup: threadsSizePerGroup
            )
        }
    }

    private func build(with encoder: BuildArgumentEncoder, for meshes: [Shader.Mesh]) -> some MTLBuffer {
        let buffer = encoder.compute.device.makeBuffer(
            length: encoder.argument.encodedLength * meshes.count
        )!

        encoder.compute.useResource(buffer, usage: .read)

        meshes.enumerated().forEach { i, mesh in
            encoder.argument.setArgumentBuffer(
                buffer,
                offset: encoder.argument.encodedLength * i
            )

            do {
                let buffer = build(
                    with: .init(
                        compute: encoder.compute,
                        argument: encoder.argument.makeArgumentEncoderForBuffer(atIndex: 0)!
                    ),
                    for: mesh.pieces
                )
                buffer.label = "Pieces"

                encoder.argument.setBuffer(buffer, offset: 0, index: 0)
            }
        }

        return buffer
    }

    private func build(with encoder: BuildArgumentEncoder, for pieces: [Shader.Mesh.Piece]) -> some MTLBuffer {
        let buffer = encoder.compute.device.makeBuffer(
            length: encoder.argument.encodedLength * pieces.count
        )!

        encoder.compute.useResource(buffer, usage: .read)

        pieces.enumerated().forEach { i, piece in
            encoder.argument.setArgumentBuffer(
                buffer,
                offset: encoder.argument.encodedLength * i
            )

            if let texture = piece.material?.albedo {
                encoder.compute.useResource(texture, usage: .read)
                encoder.argument.setTexture(texture, index: 0)
            }
        }

        return buffer
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

extension Shader.Raytrace {
    struct ArgumentEncoders {
        var meshes: any MTLArgumentEncoder
    }
}

extension Shader.Raytrace.ArgumentEncoders {
    static func makeMeshes(with device: some MTLDevice) -> MTLArgumentEncoder {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Raytrace::kernelMain")!

        return fn.makeArgumentEncoder(bufferIndex: 1)
    }
}

extension Shader.Raytrace {
    struct BuildArgumentEncoder {
        var compute: any MTLComputeCommandEncoder
        var argument: any MTLArgumentEncoder
    }
}
