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

        args = .init(
            encoder: Args.make(for: fn)
        )

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
        instances: [Raytrace.Primitive.Instance]
    ) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        do {
            let buffer = args.encode(
                target: target.texture,
                frame: frame,
                seeds: seeds,
                background: background,
                env: env,
                acceleration: .init(
                    structure: accelerator,
                    meshes: meshes,
                    instances: instances
                ),
                with: encoder
            )!

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
    func encode(
        target: some MTLTexture,
        frame: Raytrace.Frame,
        seeds: some MTLTexture,
        background: Raytrace.Background,
        env: Raytrace.Env,
        acceleration: Raytrace.Acceleration,
        with encoder: some MTLComputeCommandEncoder
    ) -> (any MTLBuffer)? {
        let encoder = MTLComputeArgumentEncoder.init(
            compute: encoder,
            argument: self.encoder
        )

        guard let buffer = encoder.compute.device.makeBuffer(
            length: self.encoder.encodedLength
        ) else { return nil }

        buffer.label = "Raytrace/Args"

        encoder.argument.setArgumentBuffer(buffer, offset: 0)

        target.encode(with: encoder, at: 0, usage: .write)
        frame.encode(with: encoder, at: 1, label: "\(buffer.label!)/Frame", usage: .read)
        seeds.encode(with: encoder, at: 2, usage: .read)
        background.encode(with: encoder, at: 3, label: "\(buffer.label!)/Background", usage: .read)
        env.encode(with: encoder, at: 4, label: "\(buffer.label!)/Env", usage: .read)
        acceleration.encode(with: encoder, at: 5, label: "\(buffer.label!)/Acceleration", usage: .read)

        return buffer
    }
}
