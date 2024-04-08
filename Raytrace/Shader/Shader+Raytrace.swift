// tomocy

import ModelIO
import Metal
import MetalKit

extension Shader {
    struct Raytrace {
        var pipelineStates: PipelineStates
        var argumentEncoders: ArgumentEncoders

        var target: Target
        var seeds: any MTLTexture
        var background: any MTLTexture
        var env: Env
    }
}

extension Shader.Raytrace {
    init(device: some MTLDevice, resolution: CGSize) throws {
        pipelineStates = .init(
            compute: try PipelineStates.make(with: device)
        )

        argumentEncoders = .init(
            meshes: ArgumentEncoders.makeMeshes(with: device)
        )

        target = Self.make(with: device, resolution: resolution)!
        seeds = Self.makeSeeds(with: device, resolution: resolution)!

        background = try Self.makeBackground(with: device)
        env = try .init(device: device)
    }
}

extension Shader.Raytrace {
    static func make(
        with device: some MTLDevice,
        resolution: CGSize
    ) -> Target? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: .init(resolution.width), height: .init(resolution.height),
            mipmapped: false
        )

        desc.storageMode = .private
        desc.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        texture.label = "Target"

        return .init(resolution: resolution, texture: texture)
    }
}

extension Shader.Raytrace {
    static func makeSeeds(
        with device: some MTLDevice,
        resolution: CGSize
    ) -> (any MTLTexture)? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Uint,
            width: .init(resolution.width), height: .init(resolution.height),
            mipmapped: false
        )

        desc.storageMode = .managed
        desc.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        texture.label = "Seeds"

        let count = desc.width * desc.height

        var seeds: [UInt32] = []
        seeds.reserveCapacity(count)

        for _ in 0..<count {
            seeds.append(.random(in: 0...UInt32.max))
        }

        seeds.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, desc.width, desc.height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: MemoryLayout<UInt32>.stride * desc.width
            )
        }

        return texture
    }
}

extension Shader.Raytrace {
    static func makeBackground(with device: some MTLDevice) throws -> any MTLTexture {
        // We know the background texture for now.
        return try MTKTextureLoader.init(device: device).newTexture(
            URL: Bundle.main.url(forResource: "Env", withExtension: "png", subdirectory: "Farm/Env")!,
            options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .cubeLayout: MTKTextureLoader.CubeLayout.vertical.rawValue,
                .generateMipmaps: true,
            ]
        )
    }
}

extension Shader.Raytrace {
    func encode(
        _ meshes: [Shader.Mesh],
        to buffer: some MTLCommandBuffer,
        frame: Shader.Frame,
        accelerator: some MTLAccelerationStructure,
        instances: [Shader.Primitive.Instance]
    ) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        encoder.setTexture(target.texture, index: 0)

        do {
            let buffer = Shader.Metal.bufferBuildable(frame).build(
                with: encoder.device,
                label: "Frame",
                options: .storageModeShared
            )!

            encoder.setBuffer(buffer, offset: 0, index: 0)
        }

        encoder.setTexture(seeds, index: 1)

        encoder.setTexture(background, index: 2)
        do {
            encoder.setTexture(env.diffuse, index: 3)
            encoder.setTexture(env.specular, index: 4)
            encoder.setTexture(env.lut, index: 5)
        }

        encoder.setAccelerationStructure(accelerator, bufferIndex: 1)

        do {
            let buffer = Shader.Metal.bufferBuildable(instances).build(
                with: encoder.device,
                label: "Instances?Count=\(instances.count)",
                options: .storageModeShared
            )!

            encoder.setBuffer(buffer, offset: 0, index: 2)
        }

        do {
            let buffer = build(
                with: .init(
                    compute: encoder,
                    argument: argumentEncoders.meshes
                ),
                for: meshes,
                label: "Meshes?Count=\(meshes.count)"
            )!

            encoder.setBuffer(buffer, offset: 0, index: 3)
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

    private func build(with encoder: BuildArgumentEncoder, for meshes: [Shader.Mesh], label: String) -> (any MTLBuffer)? {
        guard let buffer = encoder.compute.device.makeBuffer(
            length: encoder.argument.encodedLength * meshes.count
        ) else { return nil }

        buffer.label = label

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
                    for: mesh.pieces,
                    of: i,
                    label: "Pieces?Mesh=\(i)&Count=\(mesh.pieces.count)"
                )

                encoder.argument.setBuffer(buffer, offset: 0, index: 0)
            }
        }

        return buffer
    }

    private func build(
        with encoder: BuildArgumentEncoder,
        for pieces: [Shader.Mesh.Piece], of meshID: Int,
        label: String
    ) -> (any MTLBuffer)? {
        guard let buffer = encoder.compute.device.makeBuffer(
            length: encoder.argument.encodedLength * pieces.count
        ) else { return nil }

        buffer.label = label

        encoder.compute.useResource(buffer, usage: .read)

        pieces.enumerated().forEach { i, piece in
            encoder.argument.setArgumentBuffer(
                buffer,
                offset: encoder.argument.encodedLength * i
            )

            if let texture = piece.material?.albedo {
                texture.label = "Albedo?Mesh=\(meshID)&Piece=\(i)"

                encoder.compute.useResource(texture, usage: .read)
                encoder.argument.setTexture(texture, index: 0)
            }

            if let texture = piece.material?.metalRoughness {
                texture.label = "MetalRoughness?Mesh=\(meshID)&Piece=\(i)"

                encoder.compute.useResource(texture, usage: .read)
                encoder.argument.setTexture(texture, index: 1)
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

        return fn.makeArgumentEncoder(bufferIndex: 3)
    }
}

extension Shader.Raytrace {
    struct BuildArgumentEncoder {
        var compute: any MTLComputeCommandEncoder
        var argument: any MTLArgumentEncoder
    }
}
