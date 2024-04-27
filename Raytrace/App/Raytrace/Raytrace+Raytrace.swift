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

        target = Self.make(with: device, resolution: resolution)!
        seeds = Self.makeSeeds(with: device, resolution: resolution)!
    }
}

extension Raytrace.Raytrace {
    static func make(
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
        var forGPU = ForGPU.init(
            target: target.gpuResourceID,
            frame: .init(),
            seeds: .init(),
            background: .init(),
            env: .init(),
            acceleration: .init()
        )

        do {
            let label = "\(label)/Frame"

            let buffer = resourcePool.buffers.take(at: label) {
                Raytrace.Metal.Buffer.buildable(frame).build(
                    with: encoder.device,
                    label: label
                )
            }!

            Raytrace.IO.writable(frame).write(to: buffer)

            encoder.useResource(buffer, usage: .read)
            forGPU.frame = buffer.gpuAddress
        }

        do {
            encoder.useResource(seeds, usage: .read)
            forGPU.seeds = seeds.gpuResourceID
        }

        do {
            let buffer = background.build(
                with: encoder,
                resourcePool: resourcePool,
                label: "\(label)/Background"
            )!

            encoder.useResource(buffer, usage: .read)
            forGPU.background = buffer.gpuAddress
        }

        do {
            let buffer = env.build(
                with: encoder,
                resourcePool: resourcePool,
                label: "\(label)/Env"
            )!

            encoder.useResource(buffer, usage: .read)
            forGPU.env = buffer.gpuAddress
        }

        do {
            let buffer = acceleration.build(
                with: encoder,
                resourcePool: resourcePool,
                label: "\(label)/Acceleration"
            )!

            encoder.useResource(buffer, usage: .read)
            forGPU.acceleration = buffer.gpuAddress
        }

        return resourcePool.buffers.take(at: label) {
            Raytrace.Metal.Buffer.buildable(forGPU).build(
                with: encoder.device,
                label: label,
                options: .storageModeShared
            )
        }
    }
}

extension Raytrace.Raytrace.Args {
    struct ForGPU {
        var target: MTLResourceID

        var frame: UInt64
        var seeds: MTLResourceID
        var background: UInt64
        var env: UInt64
        var acceleration: UInt64
    }
}
