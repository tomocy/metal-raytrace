// tomocy

import ModelIO
import Metal
import MetalKit

extension Raytrace {
    struct Raytrace {
        var pipelineStates: PipelineStates
        var args: Args

        var target: Target
        var seeds: any MTLTexture
        var background: Background
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

        args = .init()

        target = Self.make(with: device, resolution: resolution)!
        seeds = Self.makeSeeds(with: device, resolution: resolution)!

        background = try .init(device: device)
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
        primitives: [Raytrace.Primitive.Instance]
    ) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        do {
            let forGPU = Args.ForGPU.init(
                encoder: encoder,
                target: target.texture,
                frame: frame,
                seeds: seeds,
                background: background,
                env: env,
                acceleration: .init(
                    structure: accelerator,
                    meshes: meshes,
                    primitives: primitives
                )
            )

            let buffer = Raytrace.Metal.bufferBuildable(forGPU).build(
                with: encoder.device,
                label: "Raytrace.ArgsX",
                options: .storageModeShared
            )!

            Raytrace.IO.writable(forGPU).write(to: buffer)

            encoder.setBuffer(buffer, offset: 0, index: 0)
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
    struct Args {}
}

extension Raytrace.Raytrace.Args {
    fileprivate struct ForGPU {
        var target: MTLResourceID
        var frame: UInt64
        var seeds: MTLResourceID
        var background: UInt64
        var env: UInt64
        var acceleration: UInt64
    }
}

extension Raytrace.Raytrace.Args.ForGPU {
    fileprivate struct Background {
        var source: MTLResourceID
    }

    fileprivate struct Env {
        var diffuse: MTLResourceID
        var specular: MTLResourceID
        var lut: MTLResourceID
    }

    fileprivate struct Acceleration {
        var structure: MTLResourceID
        var meshes: UInt64
        var primitives: UInt64
    }

    fileprivate struct Mesh {
        var pieces: UInt64
    }

    fileprivate struct Piece {
        var material: UInt64 = 0
    }

    fileprivate struct Material {
        var albedo: MTLResourceID = .init()
        var metalRoughness: MTLResourceID = .init()
    }

    init(
        encoder: some MTLComputeCommandEncoder,
        target: some MTLTexture,
        frame: Raytrace.Frame,
        seeds: some MTLTexture,
        background: Raytrace.Background,
        env: Raytrace.Env,
        acceleration: Raytrace.Acceleration
    ) {
        self.target = target.gpuResourceID

        do {
            let buffer = Raytrace.Metal.bufferBuildable(frame).build(
                with: encoder.device,
                label: "Raytrace/Args/Frame",
                options: .storageModeShared
            )!

            encoder.useResource(buffer, usage: .read)

            self.frame = buffer.gpuAddress
        }

        do {
            encoder.useResource(seeds, usage: .read)
            self.seeds = seeds.gpuResourceID
        }

        do {
            let forGPU = Background.init(
                source: background.source.gpuResourceID
            )

            let buffer = Raytrace.Metal.bufferBuildable(forGPU).build(
                with: encoder.device,
                label: "Raytrace/Args/Background",
                options: .storageModeShared
            )!

            encoder.useResource(buffer, usage: .read)

            self.background = buffer.gpuAddress
        }

        do {
            let forGPU = Env.init(
                diffuse: env.diffuse.gpuResourceID,
                specular: env.specular.gpuResourceID,
                lut: env.lut.gpuResourceID
            )

            let buffer = Raytrace.Metal.bufferBuildable(forGPU).build(
                with: encoder.device,
                label: "Raytrace/Args/Env",
                options: .storageModeShared
            )!

            encoder.useResource(buffer, usage: .read)

            self.env = buffer.gpuAddress
        }

        do {
            let meshes = ({
                let forGPU = acceleration.meshes.map { mesh in
                    let pieces = ({
                        let forGPU = mesh.pieces.map { piece in
                            let material = ({
                                var forGPU = Material.init()

                                if let texture = piece.material?.albedo {
                                    forGPU.albedo = texture.gpuResourceID
                                    encoder.useResource(texture, usage: .read)
                                }

                                if let texture = piece.material?.metalRoughness {
                                    forGPU.metalRoughness = texture.gpuResourceID
                                    encoder.useResource(texture, usage: .read)
                                }

                                let buffer = Raytrace.Metal.bufferBuildable(forGPU).build(
                                    with: encoder.device,
                                    label: "Raytrace/Args/Acceleration/Mesh/Piece/Material",
                                    options: .storageModeShared
                                )!

                                return buffer
                            }) ()

                            encoder.useResource(material, usage: .read)

                            return Piece.init(
                                material: material.gpuAddress
                            )
                        }

                        let buffer = Raytrace.Metal.bufferBuildable(forGPU).build(
                            with: encoder.device,
                            label: "Raytrace/Args/Acceleration/Mesh/Pieces",
                            options: .storageModeShared
                        )!

                        return buffer
                    }) ()

                    encoder.useResource(pieces, usage: .read)

                    return Mesh.init(
                        pieces: pieces.gpuAddress
                    )
                }

                let buffer = Raytrace.Metal.bufferBuildable(forGPU).build(
                    with: encoder.device,
                    label: "Raytrace/Args/Acceleration/Meshes",
                    options: .storageModeShared
                )!

                return buffer
            }) ()

            encoder.useResource(meshes, usage: .read)

            let primitives = Raytrace.Metal.bufferBuildable(acceleration.primitives).build(
                with: encoder.device,
                label: "Raytrace/Args/Acceleration/Primitives",
                options: .storageModeShared
            )!

            encoder.useResource(primitives, usage: .read)

            let forGPU = Acceleration.init(
                structure: acceleration.structure.gpuResourceID,
                meshes: meshes.gpuAddress,
                primitives: primitives.gpuAddress
            )

            let buffer = Raytrace.Metal.bufferBuildable(forGPU).build(
                with: encoder.device,
                label: "Raytrace/Args/Acceleration",
                options: .storageModeShared
            )!

            encoder.useResource(buffer, usage: .read)

            self.acceleration = buffer.gpuAddress
        }
    }
}
