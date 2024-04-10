// tomocy

import ModelIO
import Metal
import MetalKit

extension Raytrace {
    struct Raytrace {
        var pipelineStates: PipelineStates
        var args: Args
        var argumentEncoders: ArgumentEncoders

        var target: Target
        var seeds: any MTLTexture
        var background: any MTLTexture
        var env: Env
    }
}

extension Raytrace.Raytrace {
    init(device: some MTLDevice, resolution: CGSize) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Raytrace::compute")!


        pipelineStates = .init(
            compute: try PipelineStates.make(with: device, for: fn)
        )

        args = .init(
            encoder: Args.make(for: fn)
        )
        argumentEncoders = .init(
            meshes: ArgumentEncoders.makeMeshes(for: fn)
        )

        target = Self.make(with: device, resolution: resolution)!
        seeds = Self.makeSeeds(with: device, resolution: resolution)!

        background = try Self.makeBackground(with: device)
        env = try .init(device: device)
    }
}

extension Raytrace.Raytrace {
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

extension Raytrace.Raytrace {
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

extension Raytrace.Raytrace {
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

extension Raytrace.Raytrace {
    func encode(
        _ meshes: [Raytrace.Mesh],
        to buffer: some MTLCommandBuffer,
        frame: Raytrace.Frame,
        accelerator: some MTLAccelerationStructure,
        instances: [Raytrace.Primitive.Instance]
    ) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        do {
            let buffer = args.build(
                target: target.texture,
                with: encoder
            )!

            encoder.setBuffer(buffer, offset: 0, index: 0)
        }
        // encoder.setTexture(target.texture, index: 0)

        do {
            let buffer = Raytrace.Metal.bufferBuildable(frame).build(
                with: encoder.device,
                label: "Frame",
                options: .storageModeShared
            )!

            encoder.setBuffer(buffer, offset: 0, index: 1)
        }

        encoder.setTexture(seeds, index: 0)

        encoder.setTexture(background, index: 1)
        do {
            encoder.setTexture(env.diffuse, index: 2)
            encoder.setTexture(env.specular, index: 3)
            encoder.setTexture(env.lut, index: 4)
        }

        encoder.setAccelerationStructure(accelerator, bufferIndex: 2)

        do {
            let buffer = Raytrace.Metal.bufferBuildable(instances).build(
                with: encoder.device,
                label: "Instances?Count=\(instances.count)",
                options: .storageModeShared
            )!

            encoder.setBuffer(buffer, offset: 0, index: 3)
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

            encoder.setBuffer(buffer, offset: 0, index: 4)
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

    private func build(with encoder: BuildArgumentEncoder, for meshes: [Raytrace.Mesh], label: String) -> (any MTLBuffer)? {
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
        for pieces: [Raytrace.Mesh.Piece], of meshID: Int,
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

extension Raytrace.Raytrace {
    struct Target {
        var resolution: CGSize
        var texture: any MTLTexture
    }
}

extension Raytrace.Raytrace {
    struct PipelineStates {
        var compute: any MTLComputePipelineState
    }
}

extension Raytrace.Raytrace.PipelineStates {
    static func make(with device: some MTLDevice, for function: some MTLFunction) throws -> some MTLComputePipelineState {
        return try device.makeComputePipelineState(
            function: function
        )
    }
}

extension Raytrace.Raytrace {
    struct Args {
        var encoder: any MTLArgumentEncoder
    }
}

extension Raytrace.Raytrace.Args {
    static func make(for function: some MTLFunction) -> any MTLArgumentEncoder {
        return function.makeArgumentEncoder(bufferIndex: 0)
    }
}

extension Raytrace.Raytrace.Args {
    func build(
        target: some MTLTexture,
        with encoder: some MTLComputeCommandEncoder
    ) -> (any MTLBuffer)? {
        guard let buffer = encoder.device.makeBuffer(
            length: self.encoder.encodedLength
        ) else { return nil }

        buffer.label = "Raytrace/Args"

        self.encoder.setArgumentBuffer(buffer, offset: 0)

        do {
            encoder.useResource(target, usage: .write)
            self.encoder.setTexture(target, index: 0)
        }

        return buffer
    }
}

extension Raytrace.Raytrace {
    struct ArgumentEncoders {
        var meshes: any MTLArgumentEncoder
    }
}

extension Raytrace.Raytrace.ArgumentEncoders {
    static func makeMeshes(for function: some MTLFunction) -> MTLArgumentEncoder {
        return function.makeArgumentEncoder(bufferIndex: 4)
    }
}

extension Raytrace.Raytrace {
    struct BuildArgumentEncoder {
        var compute: any MTLComputeCommandEncoder
        var argument: any MTLArgumentEncoder
    }
}
