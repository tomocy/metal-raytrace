// tomocy

import ModelIO
import Metal
import MetalKit

extension Raytrace {
    struct Raytrace {
        var pipelineStates: PipelineStates

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
        let context = Args.Context.init(
            frame: frame,
            seeds: seeds,
            background: background,
            env: env,
            acceleration: acceleration
        ).build(to: buffer, label: "Args/Context")

        do {
            let encoder = buffer.makeComputeCommandEncoder()!
            defer { encoder.endEncoding() }

            encoder.label = "Raytrace"

            encoder.setComputePipelineState(pipelineStates.compute)

            do {
                encoder.useHeap(context.heap)

                let args = Args.init(
                    target: target.texture,
                    context: context
                )

                let buffer = args.build(with: encoder.device, label: "Args")!

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
        var context: MTLOnHeap<any MTLBuffer>
    }
}

extension Raytrace.Raytrace.Args {
    func build(with device: some MTLDevice, label: String) -> (any MTLBuffer)? {
        let forGPU = ForGPU.init(
            target: target.gpuResourceID,
            context: context.value.gpuAddress
        )

        return Raytrace.Metal.bufferBuildable(forGPU).build(
            with: device,
            label: label,
            options: .storageModeShared
        )
    }
}

extension Raytrace.Raytrace.Args {
    struct ForGPU {
        var target: MTLResourceID
        var context: UInt64
    }
}

extension Raytrace.Raytrace.Args {
    struct Context {
        var frame: Raytrace.Frame
        var seeds: any MTLTexture
        var background: Raytrace.Background
        var env: Raytrace.Env
        var acceleration: Raytrace.Acceleration
    }
}

extension Raytrace.Raytrace.Args.Context {
    func measureHeapSize(with device: some MTLDevice) -> Int {
        var size = 0

        size += MemoryLayout.stride(ofValue: frame)

        size += seeds.measureHeapSize(with: device)

        size += background.measureHeapSize(with: device)

        size += env.measureHeapSize(with: device)

        size += acceleration.measureHeapSize(with: device)

        size += MemoryLayout<ForGPU>.stride

        return size
    }

    func build(to buffer: some MTLCommandBuffer, label: String) -> MTLOnHeap<any MTLBuffer> {
        let encoder = buffer.makeBlitCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.label = "\(label)/Heap"

        let heap = ({
            let desc = MTLHeapDescriptor.init()

            desc.storageMode = .private
            desc.size = measureHeapSize(with: encoder.device)

            return encoder.device.makeHeap(descriptor: desc)
        }) ()!

        return .init(
            value: build(with: encoder, on: heap, label: label),
            heap: heap
        )
    }

    func build(
        with encoder: some MTLBlitCommandEncoder,
        on heap: some MTLHeap,
        label: String
    ) -> some MTLBuffer {
        let forGPU = ForGPU.init(
            frame: frame.build(
                with: encoder,
                on: heap,
                label: "\(label)/Frame"
            ).gpuAddress,

            seeds: seeds.copy(
                with: encoder,
                to: heap,
                label: "\(label)/Seeds"
            ).gpuResourceID,

            background: background.build(
                with: encoder,
                on: heap,
                label: "\(label)/Background"
            ).gpuAddress,

            env: env.build(
                with: encoder,
                on: heap,
                label: "\(label)/Env"
            ).gpuAddress,

            acceleration: acceleration.build(
                with: encoder,
                on: heap,
                label: "\(label)/Acceleration"
            ).gpuAddress
        )

        return Raytrace.Metal.bufferBuildable(forGPU).build(
            with: encoder,
            on: heap,
            label: label
        )!
    }
}

extension Raytrace.Raytrace.Args.Context {
    struct ForGPU {
        var frame: UInt64
        var seeds: MTLResourceID
        var background: UInt64
        var env: UInt64
        var acceleration: UInt64
    }
}
