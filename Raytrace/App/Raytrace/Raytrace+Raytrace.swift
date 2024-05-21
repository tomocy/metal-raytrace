// tomocy

import ModelIO
import Metal
import MetalKit

extension Raytrace {
    struct Raytrace {
        var pipelineStates: PipelineStates

        var resourcePool: ResourcePool

        var target: Target
        var seeds: any MTLTexture
    }
}

extension Raytrace.Raytrace {
    init(
        device: some MTLDevice,
        resolution: CGSize
    ) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Raytrace::compute")!

        pipelineStates = .init(
            compute: try PipelineStates.make(with: device, for: fn)
        )

        resourcePool = .init()

        target = Self.makeTarget(with: device, resolution: resolution)!
        seeds = Self.makeSeeds(with: device, resolution: resolution)!
    }
}

extension Raytrace.Raytrace {
    static func makeTarget(
        with device: some MTLDevice,
        resolution: CGSize
    ) -> Target? {
        guard let texture = Raytrace.Texture.make2D(
            with: device,
            label: "Target",
            format: .bgra8Unorm,
            size: .init(
                .init(resolution.width),
                .init(resolution.height)
            ),
            usage: [.shaderRead, .shaderWrite],
            storageMode: .private,
            mipmapped: false
        ) else { return nil }

        return .init(resolution: resolution, texture: texture)
    }
}

extension Raytrace.Raytrace {
    static func makeSeeds(
        with device: some MTLDevice,
        resolution: CGSize
    ) -> (any MTLTexture)? {
        guard let texture = Raytrace.Texture.make2D(
            with: device,
            label: "Seeds",
            format: .r32Uint,
            size: .init(
                .init(resolution.width),
                .init(resolution.height)
            ),
            usage: [.shaderRead, .shaderWrite],
            storageMode: .managed,
            mipmapped: false
        ) else { return nil }

        let count = texture.width * texture.height

        var seeds: [UInt32] = []
        seeds.reserveCapacity(count)

        for _ in 0..<count {
            seeds.append(.random(in: 0...UInt32.max))
        }

        seeds.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: MemoryLayout<UInt32>.stride * texture.width
            )
        }

        return texture
    }
}

extension Raytrace.Raytrace {
    func encode(
        to buffer: some MTLCommandBuffer,
        frame: Raytrace.Frame,
        background: Raytrace.Background,
        env: Raytrace.Env,
        acceleration: Raytrace.Acceleration
    ) {
        do {
            let encoder = buffer.makeComputeCommandEncoder()!
            defer { encoder.endEncoding() }

            encoder.label = "Raytrace"

            encoder.setComputePipelineState(pipelineStates.compute)

            do {
                let args = Args.init(
                    target: target.texture,
                    frame: frame,
                    seeds: seeds,
                    background: background,
                    env: env,
                    acceleration: acceleration
                )

                let buffer = args.build(with: encoder, resourcePool: resourcePool, label: "Args")!

                encoder.setBuffer(buffer, offset: 0, index: 0)
            }

            do {
                let threadsSizePerGroup = encoder.defaultThreadsSizePerGroup
                let threadsGroupSize = encoder.threadsGroupSize(
                    for: .init(target.texture.width, target.texture.height),
                    as: threadsSizePerGroup
                )

                encoder.dispatchThreadgroups(
                    threadsGroupSize,
                    threadsPerThreadgroup: threadsSizePerGroup
                )
            }
        }
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
    struct Target {
        var resolution: CGSize
        var texture: any MTLTexture
    }
}

extension Raytrace.Raytrace {
    struct Args {
        var target: any MTLTexture
        var frame: Raytrace.Frame
        var seeds: any MTLTexture
        var background: Raytrace.Background
        var env: Raytrace.Env
        var acceleration: Raytrace.Acceleration
    }
}

extension Raytrace.Raytrace.Args {
    func build(
        with encoder: some MTLComputeCommandEncoder,
        resourcePool: Raytrace.ResourcePool,
        label: String
    ) -> (any MTLBuffer)? {
        encoder.useResource(seeds, usage: .read)
        do {
            encoder.useResource(background.source, usage: .read)
        }
        do {
            encoder.useResource(env.diffuse, usage: .read)
            encoder.useResource(env.specular, usage: .read)
            encoder.useResource(env.lut, usage: .read)
        }
        do {
            encoder.useResource(acceleration.structure, usage: .read)
        }

        var forGPU = ForGPU.init(
            target: target.gpuResourceID,
            frame: frame,
            seeds: seeds.gpuResourceID,
            background: .init(
                source: background.source.gpuResourceID
            ),
            env: .init(
                diffuse: env.diffuse.gpuResourceID,
                specular: env.specular.gpuResourceID,
                lut: env.lut.gpuResourceID
            ),
            acceleration: .init(
                structure: acceleration.structure.gpuResourceID,
                pieces: 0
            )
        )

        do {
            let buffer = acceleration.meshes.pieces.build(
                with: encoder,
                resourcePool: resourcePool,
                label: "\(label)/Acceleration/Pieces"
            )!

            encoder.useResource(buffer, usage: .read)
            forGPU.acceleration.pieces = buffer.gpuAddress
        }

        let buffer = resourcePool.buffers.take(at: label) {
            Raytrace.Metal.Buffer.buildable(forGPU).build(
                with: encoder.device,
                label: label,
                options: .storageModeShared
            )
        }!

        Raytrace.IO.writable(forGPU).write(to: buffer)

        return buffer
    }
}

extension Raytrace.Raytrace.Args {
    struct ForGPU {
        var target: MTLResourceID

        var frame: Raytrace.Frame
        var seeds: MTLResourceID
        var background: Raytrace.Background.ForGPU
        var env: Raytrace.Env.ForGPU
        var acceleration: Raytrace.Acceleration.ForGPU
    }
}
